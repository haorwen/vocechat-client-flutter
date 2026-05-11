import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../messages/data/message_api.dart';
import '../../messages/data/message_cache.dart';
import '../../messages/domain/message_models.dart';

part 'conversation_providers.g.dart';

// ---------------------------------------------------------------------------
// ConversationKey — discriminated union for channel vs DM
// ---------------------------------------------------------------------------

sealed class ConversationKey {
  const ConversationKey();
}

class GroupConversationKey extends ConversationKey {
  const GroupConversationKey(this.gid);
  final int gid;

  @override
  bool operator ==(Object other) =>
      other is GroupConversationKey && other.gid == gid;

  @override
  int get hashCode => Object.hash('group', gid);
}

class UserConversationKey extends ConversationKey {
  const UserConversationKey(this.uid);
  final int uid;

  @override
  bool operator ==(Object other) =>
      other is UserConversationKey && other.uid == uid;

  @override
  int get hashCode => Object.hash('user', uid);
}

// ---------------------------------------------------------------------------
// ConversationItem — unified channel/DM representation for the list
// ---------------------------------------------------------------------------

class ConversationItem {
  const ConversationItem({
    required this.key,
    required this.name,
    required this.isChannel,
    this.lastMid,
    this.lastAt,
    this.lastPreview,
    this.lastFromUid,
  });

  final ConversationKey key;
  final String name;
  final bool isChannel;

  /// mid of the most recent message in this conversation (null if none).
  final int? lastMid;

  /// `created_at` (unix ms) of the most recent message.
  final int? lastAt;

  /// Short preview text derived from the latest message.
  final String? lastPreview;

  /// Sender uid of the latest message.
  final int? lastFromUid;

  ConversationItem copyWith({
    int? lastMid,
    int? lastAt,
    String? lastPreview,
    int? lastFromUid,
  }) =>
      ConversationItem(
        key: key,
        name: name,
        isChannel: isChannel,
        lastMid: lastMid ?? this.lastMid,
        lastAt: lastAt ?? this.lastAt,
        lastPreview: lastPreview ?? this.lastPreview,
        lastFromUid: lastFromUid ?? this.lastFromUid,
      );

  Map<String, dynamic> toJson() {
    return {
      'kind': key is GroupConversationKey ? 'group' : 'user',
      'id': key is GroupConversationKey
          ? (key as GroupConversationKey).gid
          : (key as UserConversationKey).uid,
      'name': name,
      'isChannel': isChannel,
      'lastMid': lastMid,
      'lastAt': lastAt,
      'lastPreview': lastPreview,
      'lastFromUid': lastFromUid,
    };
  }

  static ConversationItem? fromJson(Map<String, dynamic> j) {
    final kind = j['kind'] as String?;
    final id = (j['id'] as num?)?.toInt();
    if (kind == null || id == null) return null;
    final ConversationKey key = kind == 'group'
        ? GroupConversationKey(id)
        : UserConversationKey(id);
    return ConversationItem(
      key: key,
      name: j['name'] as String? ?? 'Unknown',
      isChannel: j['isChannel'] as bool? ?? (kind == 'group'),
      lastMid: (j['lastMid'] as num?)?.toInt(),
      lastAt: (j['lastAt'] as num?)?.toInt(),
      lastPreview: j['lastPreview'] as String?,
      lastFromUid: (j['lastFromUid'] as num?)?.toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// GroupInfo / UserInfo — minimal JSON shapes for list endpoints
// ---------------------------------------------------------------------------

class _GroupInfo {
  const _GroupInfo({required this.gid, required this.name});
  final int gid;
  final String name;

  factory _GroupInfo.fromJson(Map<String, dynamic> j) => _GroupInfo(
        gid: (j['gid'] as num).toInt(),
        name: j['name'] as String? ?? 'Unnamed',
      );
}

class _UserInfo {
  const _UserInfo({required this.uid, required this.name});
  final int uid;
  final String name;

  factory _UserInfo.fromJson(Map<String, dynamic> j) => _UserInfo(
        uid: (j['uid'] as num).toInt(),
        name: j['name'] as String? ?? 'Unknown',
      );
}

// ---------------------------------------------------------------------------
// Preview helper — convert a ChatMessage into a 1-line preview string
// ---------------------------------------------------------------------------

String _previewFor(ChatMessage msg) {
  return msg.detail.map(
    normal: (d) {
      final ct = d.contentType;
      if (ct == 'text/plain' || ct == 'text/markdown') {
        return d.content.replaceAll('\n', ' ').trim();
      }
      if (ct == 'vocechat/file') return '[File]';
      if (ct == 'vocechat/audio') return '[Voice]';
      if (ct == 'vocechat/archive') return '[Archive]';
      if (ct.startsWith('image/')) return '[Image]';
      return '[${ct.split('/').last}]';
    },
    reply: (d) => d.content.replaceAll('\n', ' ').trim(),
    reaction: (d) => '[Reaction]',
  );
}

// ---------------------------------------------------------------------------
// conversationsRefreshing — surface a "refresh in flight" boolean to the UI
// so it can show the translucent loading capsule over cached data.
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class ConversationsRefreshing extends _$ConversationsRefreshing {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

// ---------------------------------------------------------------------------
// Conversations notifier — exposes the chat list and lets SSE patch it.
//
// Cold-start sequence:
//   1. Read cached snapshot from MessageCache (single sqlite query).
//      → emit immediately so the UI paints with no spinner.
//   2. Kick a background refresh that hits /api/group, /api/user, and
//      per-conversation history. When it returns we overlay the new state
//      and persist it. Errors leave the cached snapshot in place.
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class Conversations extends _$Conversations {
  MessageCache? _cache;

  /// Pending SSE-driven patches keyed by conversation. We coalesce bursts
  /// (e.g. SSE replay on reconnect) into a single state update per frame
  /// so the chat list doesn't rebuild dozens of times in one tick.
  final Map<ConversationKey, ChatMessage> _pendingPatches = {};
  bool _patchScheduled = false;

  @override
  Future<List<ConversationItem>> build() async {
    final cache = await ref.watch(messageCacheProvider.future);
    _cache = cache;

    // Step 1: paint from disk.
    final cachedRaw = await cache.readConversations();
    List<ConversationItem>? cached;
    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      cached = cachedRaw
          .map(ConversationItem.fromJson)
          .whereType<ConversationItem>()
          .toList();
    }

    if (cached != null && cached.isNotEmpty) {
      // Schedule refresh, return cached state.
      Future.microtask(() => _refreshFromNetwork(cache));
      return _sorted(cached);
    }

    // Step 2: no cache — must wait on network so the UI has something to show.
    final fresh = await _fetchFromNetwork();
    if (fresh.isNotEmpty) {
      _persist(cache, fresh);
    }
    return _sorted(fresh);
  }

  /// Public: ask the notifier to re-pull the list from the network without
  /// dropping the current state.
  Future<void> refresh() async {
    final MessageCache cache =
        _cache ?? await ref.read(messageCacheProvider.future);
    _cache = cache;
    await _refreshFromNetwork(cache);
  }

  Future<void> _refreshFromNetwork(MessageCache cache) async {
    ref.read(conversationsRefreshingProvider.notifier).set(true);
    try {
      final fresh = await _fetchFromNetwork();
      if (fresh.isEmpty) return;
      // Merge: prefer network metadata, but keep last-message preview from
      // the existing state when network omitted it (e.g. a getHistory call
      // failed) so the UI doesn't lose data.
      final current = state.valueOrNull ?? const <ConversationItem>[];
      final byKey = {for (final c in current) c.key: c};
      final merged = fresh
          .map((item) {
            final existing = byKey[item.key];
            if (existing == null) return item;
            // Network item wins for name + (when present) preview/timestamp.
            return item.copyWith(
              lastMid: item.lastMid ?? existing.lastMid,
              lastAt: item.lastAt ?? existing.lastAt,
              lastPreview: item.lastPreview ?? existing.lastPreview,
              lastFromUid: item.lastFromUid ?? existing.lastFromUid,
            );
          })
          .toList();
      final sorted = _sorted(merged);
      state = AsyncData(sorted);
      _persist(cache, sorted);
    } catch (_) {
      // ignore — cached state stays valid
    } finally {
      ref.read(conversationsRefreshingProvider.notifier).set(false);
    }
  }

  Future<List<ConversationItem>> _fetchFromNetwork() async {
    final dio = ref.read(dioProvider);
    final api = ref.read(messageApiProvider);

    final List<ConversationItem> base = [];

    try {
      final groupResp = await dio.get('/api/group');
      final groups = (groupResp.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_GroupInfo.fromJson)
          .toList();
      for (final g in groups) {
        base.add(ConversationItem(
          key: GroupConversationKey(g.gid),
          name: g.name,
          isChannel: true,
        ));
      }
    } on DioException {
      // offline: fall through with whatever we have
    }

    try {
      final userResp = await dio.get('/api/user');
      final users = (userResp.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_UserInfo.fromJson)
          .toList();
      for (final u in users) {
        base.add(ConversationItem(
          key: UserConversationKey(u.uid),
          name: u.name,
          isChannel: false,
        ));
      }
    } on DioException {
      // offline: fall through
    }

    if (base.isEmpty) return base;

    // Reconcile the in-memory state with the freshly fetched roster as
    // early as possible — this gives the UI an updated name list the
    // instant /api/group + /api/user complete, BEFORE we start chasing
    // per-conversation history. Prevents a long history-fetch fan-out
    // from delaying the visible refresh.
    final cached = state.valueOrNull;
    if (cached != null) {
      final cachedByKey = {for (final c in cached) c.key: c};
      final preview = base
          .map((item) =>
              cachedByKey[item.key]?.copyWith() != null
                  ? item.copyWith(
                      lastMid: cachedByKey[item.key]!.lastMid,
                      lastAt: cachedByKey[item.key]!.lastAt,
                      lastPreview: cachedByKey[item.key]!.lastPreview,
                      lastFromUid: cachedByKey[item.key]!.lastFromUid,
                    )
                  : item)
          .toList();
      state = AsyncData(_sorted(preview));
    }

    // Fetch the latest message for each conversation with a small concurrency
    // cap. Hitting all conversations at once on a big workspace (50+ chats)
    // saturates the connection pool and forces the main isolate to decode N
    // payloads in a single tick — visible UI hitch. A 4-wide window keeps the
    // network busy without starving the UI thread.
    const int kHistoryConcurrency = 4;
    final enriched = List<ConversationItem>.from(base);
    int idx = 0;
    Future<void> worker() async {
      while (true) {
        final mine = idx;
        if (mine >= base.length) return;
        idx++;
        final item = base[mine];
        final target = switch (item.key) {
          GroupConversationKey(gid: final gid) => MessageTarget.group(gid: gid),
          UserConversationKey(uid: final uid) => MessageTarget.user(uid: uid),
        };
        try {
          final msgs = await api.getHistory(target, limit: 1);
          if (msgs.isNotEmpty) {
            final last = msgs.first;
            enriched[mine] = item.copyWith(
              lastMid: last.mid,
              lastAt: last.createdAt,
              lastPreview: _previewFor(last),
              lastFromUid: last.fromUid,
            );
          }
        } on DioException {
          // keep the un-enriched entry
        }
      }
    }

    await Future.wait(
      List.generate(kHistoryConcurrency, (_) => worker()),
    );

    return enriched;
  }

  void _persist(MessageCache cache, List<ConversationItem> items) {
    cache.writeConversations(items.map((e) => e.toJson()).toList());
  }

  /// Apply a freshly received chat message: patch the matching conversation
  /// item with its preview + timestamp and re-sort.
  ///
  /// Coalesces bursts into a single per-frame state update — SSE catch-up
  /// can replay dozens of messages in one tick, and rebuilding the entire
  /// chat list per message visibly hitches the UI.
  void applyIncomingMessage(ChatMessage msg) {
    // DM session id is always the OTHER user's uid:
    //   - outgoing  → msg.target.uid is the peer
    //   - incoming  → msg.target.uid is OURSELF; the peer is msg.fromUid
    // Mirrors web `chat.handler.ts`: `id = self ? target.uid : from_uid`.
    final authState = ref.read(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : null;

    final targetKey = msg.target.map<ConversationKey>(
      user: (t) {
        final peerUid = currentUid != null && msg.fromUid != currentUid
            ? msg.fromUid
            : t.uid;
        return UserConversationKey(peerUid);
      },
      group: (t) => GroupConversationKey(t.gid),
    );

    final existing = _pendingPatches[targetKey];
    if (existing == null || msg.mid > existing.mid) {
      _pendingPatches[targetKey] = msg;
    }

    if (_patchScheduled) return;
    _patchScheduled = true;
    Future.microtask(_flushPendingPatches);
  }

  void _flushPendingPatches() {
    _patchScheduled = false;
    if (_pendingPatches.isEmpty) return;

    final current = state.valueOrNull;
    if (current == null) {
      // Still bootstrapping — leave the patches queued.
      _patchScheduled = true;
      Future.microtask(_flushPendingPatches);
      return;
    }

    final patches = Map.of(_pendingPatches);
    _pendingPatches.clear();

    bool needsRefresh = false;
    final next = List<ConversationItem>.from(current);

    for (final entry in patches.entries) {
      final targetKey = entry.key;
      final msg = entry.value;
      final idx = next.indexWhere((c) => c.key == targetKey);
      if (idx < 0) {
        needsRefresh = true;
        continue;
      }
      final old = next[idx];
      if (old.lastMid != null && msg.mid <= old.lastMid!) continue;
      next[idx] = old.copyWith(
        lastMid: msg.mid,
        lastAt: msg.createdAt,
        lastPreview: _previewFor(msg),
        lastFromUid: msg.fromUid,
      );
    }

    final sorted = _sorted(next);
    state = AsyncData(sorted);

    final cache = _cache;
    if (cache != null) _persist(cache, sorted);

    if (needsRefresh) {
      // Unknown conversation appeared (e.g. brand-new DM). Ask the network
      // for a fresh roster — non-blocking.
      final c = _cache;
      if (c != null) {
        Future.microtask(() => _refreshFromNetwork(c));
      }
    }
  }

  static List<ConversationItem> _sorted(List<ConversationItem> items) {
    final sorted = List<ConversationItem>.from(items);
    sorted.sort((a, b) {
      // Items with messages first, sorted by recency desc.
      // Items without messages last, sorted by name asc.
      final aHas = a.lastAt != null;
      final bHas = b.lastAt != null;
      if (aHas && bHas) return b.lastAt!.compareTo(a.lastAt!);
      if (aHas) return -1;
      if (bHas) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }
}

// ---------------------------------------------------------------------------
// unreadCountProvider — placeholder returning 0; will be replaced by SSE-derived state later
// ---------------------------------------------------------------------------

@riverpod
int unreadCount(Ref ref, ConversationKey key) {
  return 0;
}
