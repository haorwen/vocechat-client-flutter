import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/message_api.dart';
import '../data/message_cache.dart';

part 'read_index_provider.g.dart';

/// Per-conversation "read up to this mid" markers, keyed by peer uid (DMs) and
/// gid (channels). Mirrors the web client's `footprint.readUsers` /
/// `readChannels`. The conversation-list unread badge and the chat screen's
/// read-up-to logic both derive from this.
///
/// Disk, server snapshots/deltas, and local reads are max-merged: reconnecting
/// must never make an already-read conversation unread again. Local reads are
/// persisted and synced independently of the chat screen's lifetime.
///
/// Kept alive for the whole app lifetime — it's tiny and read by every tile.
class ReadIndexState {
  const ReadIndexState({this.users = const {}, this.groups = const {}});

  /// peer uid -> highest read mid
  final Map<int, int> users;

  /// gid -> highest read mid
  final Map<int, int> groups;

  int readUser(int uid) => users[uid] ?? 0;
  int readGroup(int gid) => groups[gid] ?? 0;

  /// Highest read mid for a DM peer, or null if no baseline has been
  /// established yet (distinct from "read up to mid 0").
  int? readUserOrNull(int uid) => users[uid];
  int? readGroupOrNull(int gid) => groups[gid];

  ReadIndexState copyWith({Map<int, int>? users, Map<int, int>? groups}) =>
      ReadIndexState(users: users ?? this.users, groups: groups ?? this.groups);

  ReadIndexState merge(Map<int, int> users, Map<int, int> groups) {
    Map<int, int> mergeMap(Map<int, int> current, Map<int, int> incoming) {
      final result = Map<int, int>.of(current);
      incoming.forEach((id, mid) {
        if (mid >= 0 && (!result.containsKey(id) || mid > result[id]!)) {
          result[id] = mid;
        }
      });
      return result;
    }

    return ReadIndexState(
      users: mergeMap(this.users, users),
      groups: mergeMap(this.groups, groups),
    );
  }
}

@Riverpod(keepAlive: true)
class ReadIndex extends _$ReadIndex {
  MessageCache? _cache;
  ReadIndexState _current = const ReadIndexState();
  ReadIndexState _confirmed = const ReadIndexState();
  final _pendingUsers = <int, int>{};
  final _pendingGroups = <int, int>{};
  Timer? _syncTimer;
  bool _syncing = false;
  int _generation = 0;
  int _retrySeconds = 1;
  Future<void> _writes = Future.value();

  @override
  Future<ReadIndexState> build() async {
    final generation = ++_generation;
    _cache = null;
    _current = const ReadIndexState();
    _confirmed = const ReadIndexState();
    _pendingUsers.clear();
    _pendingGroups.clear();
    _syncing = false;
    _retrySeconds = 1;
    _writes = Future.value();
    _syncTimer?.cancel();
    _syncTimer = null;
    ref.onDispose(() {
      ++_generation;
      _syncTimer?.cancel();
    });

    final cache = await ref.watch(messageCacheProvider.future);
    final saved = await Future.wait([
      cache.readReadIndexUsers(),
      cache.readReadIndexGroups(),
      cache.readPendingReadIndexUsers(),
      cache.readPendingReadIndexGroups(),
    ]);
    if (generation != _generation) return const ReadIndexState();
    _cache = cache;

    // A snapshot or local read can arrive while SQLite is loading. Preserve
    // both, and do not leak the previous account's retained AsyncValue data.
    _current = _current.merge(saved[0], saved[1]).merge(saved[2], saved[3]);
    _mergePending(_pendingUsers, saved[2]);
    _mergePending(_pendingGroups, saved[3]);
    _acknowledge(_confirmed.users, _confirmed.groups);
    _persist();
    _scheduleSync();
    return _current;
  }

  void applySnapshot(Map<int, int> users, Map<int, int> groups) {
    applyDelta(users, groups);
  }

  /// Server echoes acknowledge queued reads, but stale echoes cannot undo
  /// newer local reads (including updates made during a reconnect).
  void applyDelta(Map<int, int> users, Map<int, int> groups) {
    if (users.isEmpty && groups.isEmpty) return;
    _confirmed = _confirmed.merge(users, groups);
    _current = _current.merge(users, groups);
    _acknowledge(users, groups);
    state = AsyncData(_current);
    _persist();
  }

  /// Clear the local badge immediately; debounce only the network request.
  void setUser(int uid, int mid) {
    if (mid <= 0) return;
    _current = _current.merge({uid: mid}, const {});
    if (mid > _confirmed.readUser(uid)) {
      _mergePending(_pendingUsers, {uid: mid});
    }
    state = AsyncData(_current);
    _persist();
    _scheduleSync();
  }

  void setGroup(int gid, int mid) {
    if (mid <= 0) return;
    _current = _current.merge(const {}, {gid: mid});
    if (mid > _confirmed.readGroup(gid)) {
      _mergePending(_pendingGroups, {gid: mid});
    }
    state = AsyncData(_current);
    _persist();
    _scheduleSync();
  }

  /// A baseline suppresses historical unread badges on first entry, but is
  /// not a user read and must not be sent to the server.
  void baselineUser(int uid, int mid) {
    if (mid <= 0 || _current.users.containsKey(uid)) return;
    _current = _current.merge({uid: mid}, const {});
    state = AsyncData(_current);
    _persist();
  }

  void baselineGroup(int gid, int mid) {
    if (mid <= 0 || _current.groups.containsKey(gid)) return;
    _current = _current.merge(const {}, {gid: mid});
    state = AsyncData(_current);
    _persist();
  }

  static void _mergePending(Map<int, int> pending, Map<int, int> updates) {
    updates.forEach((id, mid) {
      if (mid > (pending[id] ?? 0)) pending[id] = mid;
    });
  }

  void _acknowledge(Map<int, int> users, Map<int, int> groups) {
    _pendingUsers.removeWhere((id, mid) => mid <= (users[id] ?? 0));
    _pendingGroups.removeWhere((id, mid) => mid <= (groups[id] ?? 0));
  }

  bool get _hasPending => _pendingUsers.isNotEmpty || _pendingGroups.isNotEmpty;

  void _scheduleSync([Duration delay = const Duration(milliseconds: 500)]) {
    if (_cache == null || _syncing || !_hasPending || _syncTimer != null) {
      return;
    }
    // A bounded coalescing window also makes progress during continuous scroll.
    _syncTimer = Timer(delay, () {
      _syncTimer = null;
      unawaited(_sync());
    });
  }

  Future<void> _sync() async {
    if (!_hasPending || _syncing) return;
    final generation = _generation;
    final users = Map<int, int>.of(_pendingUsers);
    final groups = Map<int, int>.of(_pendingGroups);
    _syncing = true;
    var nextDelay = const Duration(milliseconds: 500);
    try {
      await ref.read(messageApiProvider).readMessage(
        users: [for (final e in users.entries) (uid: e.key, mid: e.value)],
        groups: [for (final e in groups.entries) (gid: e.key, mid: e.value)],
      );
      if (generation != _generation) return;
      _confirmed = _confirmed.merge(users, groups);
      // Only remove the values actually sent. A newer visible message may
      // have queued another read while this request was in flight.
      _acknowledge(users, groups);
      _retrySeconds = 1;
      _persist();
    } catch (_) {
      if (generation != _generation) return;
      // Keep the optimistic state and persisted queue, retry with capped
      // backoff, and let a relaunch resume any still-unacknowledged reads.
      nextDelay = Duration(seconds: _retrySeconds);
      _retrySeconds = (_retrySeconds * 2).clamp(1, 30);
    } finally {
      if (generation == _generation) {
        _syncing = false;
        _scheduleSync(nextDelay);
      }
    }
  }

  void _persist() {
    final cache = _cache;
    if (cache == null) return;
    final current = _current;
    final users = Map<int, int>.of(_pendingUsers);
    final groups = Map<int, int>.of(_pendingGroups);
    // Serialize snapshots so a slower earlier write cannot restore an old
    // marker or resurrect a queue entry that has already been acknowledged.
    _writes = _writes.then((_) async {
      await cache.writePendingReadIndexUsers(users);
      await cache.writePendingReadIndexGroups(groups);
      await cache.writeReadIndexUsers(current.users);
      await cache.writeReadIndexGroups(current.groups);
    }).catchError((_) {});
  }
}
