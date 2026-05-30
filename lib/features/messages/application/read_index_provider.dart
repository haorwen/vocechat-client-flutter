import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/message_cache.dart';

part 'read_index_provider.g.dart';

/// Per-conversation "read up to this mid" markers, keyed by peer uid (DMs) and
/// gid (channels). Mirrors the web client's `footprint.readUsers` /
/// `readChannels`. The conversation-list unread badge and the chat screen's
/// read-up-to logic both derive from this.
///
/// Sources, in order of authority:
///   - disk (cold start, so a read chat doesn't flash unread on relaunch)
///   - SSE `user_settings` snapshot (`applySnapshot`, authoritative replace)
///   - SSE `user_settings_changed` delta (`applyDelta`, max-merge)
///   - local optimistic updates when the user views a chat (`setUser`/`setGroup`)
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

  ReadIndexState copyWith({Map<int, int>? users, Map<int, int>? groups}) =>
      ReadIndexState(users: users ?? this.users, groups: groups ?? this.groups);
}

@Riverpod(keepAlive: true)
class ReadIndex extends _$ReadIndex {
  MessageCache? _cache;

  @override
  Future<ReadIndexState> build() async {
    final cache = await ref.watch(messageCacheProvider.future);
    _cache = cache;
    final users = await cache.readReadIndexUsers();
    final groups = await cache.readReadIndexGroups();
    return ReadIndexState(users: users, groups: groups);
  }

  ReadIndexState get _current => state.valueOrNull ?? const ReadIndexState();

  /// Authoritative snapshot from `user_settings`: replace wholesale.
  void applySnapshot(Map<int, int> users, Map<int, int> groups) {
    final next = ReadIndexState(users: users, groups: groups);
    state = AsyncData(next);
    _persist(next);
  }

  /// Delta from `user_settings_changed`: max-merge so we never move a marker
  /// backwards.
  void applyDelta(Map<int, int> users, Map<int, int> groups) {
    if (users.isEmpty && groups.isEmpty) return;
    final cur = _current;
    final mergedUsers = Map<int, int>.from(cur.users);
    users.forEach((k, v) {
      if (v > (mergedUsers[k] ?? 0)) mergedUsers[k] = v;
    });
    final mergedGroups = Map<int, int>.from(cur.groups);
    groups.forEach((k, v) {
      if (v > (mergedGroups[k] ?? 0)) mergedGroups[k] = v;
    });
    final next = ReadIndexState(users: mergedUsers, groups: mergedGroups);
    state = AsyncData(next);
    _persist(next);
  }

  /// Local optimistic update when the user views a DM. Only ever moves forward.
  void setUser(int uid, int mid) {
    final cur = _current;
    if (mid <= cur.readUser(uid)) return;
    final next =
        cur.copyWith(users: {...cur.users, uid: mid});
    state = AsyncData(next);
    _persist(next);
  }

  /// Local optimistic update when the user views a channel.
  void setGroup(int gid, int mid) {
    final cur = _current;
    if (mid <= cur.readGroup(gid)) return;
    final next =
        cur.copyWith(groups: {...cur.groups, gid: mid});
    state = AsyncData(next);
    _persist(next);
  }

  void _persist(ReadIndexState s) {
    final cache = _cache;
    if (cache == null) return;
    // Fire-and-forget; both writers are best-effort.
    cache.writeReadIndexUsers(s.users);
    cache.writeReadIndexGroups(s.groups);
  }
}
