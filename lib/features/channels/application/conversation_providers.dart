import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_log.dart';
import '../../auth/application/auth_controller.dart';
import '../../messages/data/message_api.dart';
import '../../messages/data/message_cache.dart';
import '../../messages/application/read_index_provider.dart';
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
    bootLog('20 Conversations.build: await messageCacheProvider');
    final cache = await ref.watch(messageCacheProvider.future);
    _cache = cache;

    // Step 1: paint from disk.
    bootLog('21 Conversations.build: readConversations from disk');
    final cachedRaw = await cache.readConversations();
    List<ConversationItem>? cached;
    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      cached = cachedRaw
          .map(ConversationItem.fromJson)
          .whereType<ConversationItem>()
          .toList();
    }

    if (cached != null && cached.isNotEmpty) {
      bootLog('22 Conversations.build: returning ${cached.length} cached items');
      // Schedule refresh, return cached state.
      Future.microtask(() => _refreshFromNetwork(cache));
      // Apply any SSE patches that arrived while we were reading from disk.
      Future.microtask(_drainPendingPatches);
      return _sorted(cached);
    }

    // Step 2: no cache — fetch the base roster (groups + users) and return
    // immediately so the UI paints. Preview enrichment (per-conversation
    // getHistory fan-out) continues in the background and pushes incremental
    // state updates. On low-end devices over a slow network, this turns a
    // multi-second freeze into a sub-second paint.
    bootLog('23 Conversations.build: no cache, awaiting _fetchBaseRoster');
    final base = await _fetchBaseRoster();
    bootLog('24 Conversations.build: _fetchBaseRoster returned ${base.length} items');
    if (base.isNotEmpty) {
      // Persist the un-enriched roster synchronously so a kill-and-relaunch
      // before enrichment finishes still gets cached names on next start.
      // Bypass the 400ms debounce — on a cleared cache the user is more
      // likely to bounce the app, and we must not lose this first write.
      _persist(cache, base, immediate: true);
      // Defer enrichment past first paint. `Future.microtask` runs before
      // build() resolves to Riverpod, so a 50+ workspace would saturate the
      // connection pool and starve the basic UI render. A short delay lets
      // the chat list paint first, then enrichment streams in.
      Future.delayed(const Duration(milliseconds: 50), () {
        _enrichPreviews(cache, base);
      });
    }
    // Drain SSE patches that piled up during _fetchBaseRoster.
    Future.microtask(_drainPendingPatches);
    return _sorted(base);
  }

  /// Public: ask the notifier to re-pull the list from the network without
  /// dropping the current state.
  Future<void> refresh() async {
    final MessageCache cache =
        _cache ?? await ref.read(messageCacheProvider.future);
    _cache = cache;
    await _refreshFromNetwork(cache);
  }

  /// Remove a conversation from the local list (hide session / leave channel).
  /// Does NOT call any server API — the caller is responsible for that.
  void hideConversation(ConversationKey key) {
    final current = state.valueOrNull ?? [];
    final filtered = current.where((c) => c.key != key).toList();
    state = AsyncData(filtered);
    if (_cache != null) _persist(_cache!, filtered);
  }

  Future<void> _refreshFromNetwork(MessageCache cache) async {
    ref.read(conversationsRefreshingProvider.notifier).set(true);
    try {
      final base = await _fetchBaseRoster();
      if (base.isEmpty) return;
      // Merge roster with current state, preserving existing previews while
      // network catches up. This gives the UI a fresh name/membership list
      // in 1 RTT, before any history fan-out completes.
      final current = state.valueOrNull ?? const <ConversationItem>[];
      final byKey = {for (final c in current) c.key: c};
      final merged = base.map((item) {
        final existing = byKey[item.key];
        if (existing == null) return item;
        return item.copyWith(
          lastMid: existing.lastMid,
          lastAt: existing.lastAt,
          lastPreview: existing.lastPreview,
          lastFromUid: existing.lastFromUid,
        );
      }).toList();
      final sorted = _sorted(merged);
      state = AsyncData(sorted);
      _persist(cache, sorted);

      // Background enrichment — preview updates flow incrementally.
      await _enrichPreviews(cache, base);
    } catch (_) {
      // ignore — cached state stays valid
    } finally {
      ref.read(conversationsRefreshingProvider.notifier).set(false);
    }
  }

  /// Single round-trip to fetch group + user roster. Cheap (2 requests, no
  /// per-conversation fan-out) so cold-start can paint after this returns.
  Future<List<ConversationItem>> _fetchBaseRoster() async {
    final dio = ref.read(dioProvider);
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

    return base;
  }

  /// Per-conversation preview enrichment — fans out getHistory(limit:1) with
  /// a bounded concurrency window and batches state updates so the UI gets
  /// "drip" updates instead of one big rebuild at the end. Runs in the
  /// background; never blocks first paint.
  Future<void> _enrichPreviews(
      MessageCache cache, List<ConversationItem> base) async {
    if (base.isEmpty) return;
    final api = ref.read(messageApiProvider);

    // Tunable: 3 keeps a phone's network + CPU comfortable. The previous
    // code used 4; on low-end devices 3 is a better default because each
    // response triggers a main-isolate JSON decode by dio.
    const int kHistoryConcurrency = 3;

    // Batched flushes: collect enrichments in a buffer and emit at most one
    // state update per ~120ms so we don't rebuild the list per response.
    final Map<ConversationKey, ConversationItem> pending = {};
    Timer? flushTimer;

    void schedule() {
      if (flushTimer != null) return;
      flushTimer = Timer(const Duration(milliseconds: 120), () {
        flushTimer = null;
        if (pending.isEmpty) return;
        final current = state.valueOrNull;
        if (current == null) return;
        final byKey = {for (final c in current) c.key: c};
        for (final entry in pending.entries) {
          byKey[entry.key] = entry.value;
        }
        pending.clear();
        final next = byKey.values.toList();
        final sorted = _sorted(next);
        state = AsyncData(sorted);
        _persist(cache, sorted);
      });
    }

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
            pending[item.key] = item.copyWith(
              lastMid: last.mid,
              lastAt: last.createdAt,
              lastPreview: _previewFor(last),
              lastFromUid: last.fromUid,
            );
            schedule();
          }
        } on DioException {
          // keep the un-enriched entry
        }
      }
    }

    await Future.wait(
      List.generate(kHistoryConcurrency, (_) => worker()),
    );

    // Final flush: cancel any pending timer and apply the leftover batch
    // synchronously so the persisted state matches what's on screen.
    flushTimer?.cancel();
    if (pending.isNotEmpty) {
      final current = state.valueOrNull;
      if (current != null) {
        final byKey = {for (final c in current) c.key: c};
        for (final entry in pending.entries) {
          byKey[entry.key] = entry.value;
        }
        final sorted = _sorted(byKey.values.toList());
        state = AsyncData(sorted);
        _persist(cache, sorted);
      }
    }
  }

  void _persist(MessageCache cache, List<ConversationItem> items,
      {bool immediate = false}) {
    // Coalesce bursts of state updates (SSE replay, preview enrichment) into
    // a single DB write. Each write triggers a jsonEncode pass (isolated via
    // compute, but still allocates) so it pays to skip redundant ones.
    //
    // `immediate` bypasses the debounce — used by the cold-start no-cache
    // path so the very first persist lands on disk even if the user kills
    // the app within the debounce window.
    _pendingPersistItems = items;
    _pendingPersistCache = cache;
    _persistTimer?.cancel();
    if (immediate) {
      _flushPersist();
      return;
    }
    _persistTimer = Timer(_persistDebounce, _flushPersist);
  }

  static const Duration _persistDebounce = Duration(milliseconds: 400);
  Timer? _persistTimer;
  List<ConversationItem>? _pendingPersistItems;
  MessageCache? _pendingPersistCache;

  void _flushPersist() {
    _persistTimer = null;
    final items = _pendingPersistItems;
    final cache = _pendingPersistCache;
    _pendingPersistItems = null;
    _pendingPersistCache = null;
    if (items == null || cache == null) return;
    cache.writeConversations(items.map((e) => e.toJson()).toList());
  }

  /// Apply a freshly received chat message: patch the matching conversation
  /// item with its preview + timestamp and re-sort.
  ///
  /// Coalesces bursts into a single per-frame state update — SSE catch-up
  /// can replay dozens of messages in one tick, and rebuilding the entire
  /// chat list per message visibly hitches the UI.
  void applyIncomingMessage(ChatMessage msg) {
    // Reactions are sidecar events: they don't bump the conversation preview
    // or recency. Match the web client which routes reaction messages to the
    // reaction slice but not the chat list.
    if (msg.detail is ReactionMessageDetail) return;

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
      // Still bootstrapping (build() hasn't resolved yet). DO NOT re-schedule
      // a microtask here — microtasks have priority over normal events, and
      // a self-rescheduling loop while the network roster is being awaited
      // will starve the event loop indefinitely (UI freezes, the awaited
      // dio response never gets delivered, build() never resolves → infinite
      // microtask spin). Leave the patches queued; the bootstrap path calls
      // `_drainPendingPatches()` once `state` is populated.
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

  /// Called by `build()` once `state` is populated, to apply any patches
  /// that arrived during bootstrap. Idempotent.
  void _drainPendingPatches() {
    if (_pendingPatches.isEmpty) return;
    if (_patchScheduled) return;
    _patchScheduled = true;
    Future.microtask(_flushPendingPatches);
  }

  /// Apply an edit echo: when the last message of a conversation is edited,
  /// refresh its preview text. If the edited message isn't the head of the
  /// conversation, this is a no-op (older messages don't drive the preview).
  ///
  /// [fromUid] is the uid of the user who authored the edit (i.e. the
  /// originator of the reaction message). For DMs, this is required to
  /// resolve which conversation the edit belongs to.
  void applyEditEcho(
    MessageTarget target,
    int editedMid,
    String newContent, {
    required int fromUid,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    final targetKey = _conversationKeyFor(target, fromUid);
    final idx = current.indexWhere((c) => c.key == targetKey);
    if (idx < 0) return;
    final item = current[idx];
    if (item.lastMid != editedMid) return; // not the visible preview
    final next = List<ConversationItem>.from(current);
    next[idx] = item.copyWith(
      lastPreview: newContent.replaceAll('\n', ' ').trim(),
    );
    state = AsyncData(next);
    final cache = _cache;
    if (cache != null) _persist(cache, next);
  }

  /// Apply a delete echo: if the deleted message drives the conversation
  /// preview, kick a background refresh so we get the next-most-recent
  /// message. Otherwise no-op.
  void applyDeleteEcho(
    MessageTarget target,
    int deletedMid, {
    required int fromUid,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    final targetKey = _conversationKeyFor(target, fromUid);
    final idx = current.indexWhere((c) => c.key == targetKey);
    if (idx < 0) return;
    final item = current[idx];
    if (item.lastMid != deletedMid) return;
    // The preview row was deleted — fall back to a refresh which re-pulls the
    // last message via getHistory(limit:1). Non-blocking.
    final cache = _cache;
    if (cache == null) return;
    Future.microtask(() => _refreshFromNetwork(cache));
  }

  ConversationKey _conversationKeyFor(MessageTarget target, int fromUid) {
    final authState = ref.read(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : null;
    return target.map<ConversationKey>(
      user: (t) {
        // DM peer resolution mirrors `applyIncomingMessage`:
        //   - outgoing  → t.uid is the peer (we're the originator)
        //   - incoming  → t.uid is OURSELF; the peer is fromUid
        final peerUid = currentUid != null && fromUid != currentUid
            ? fromUid
            : t.uid;
        return UserConversationKey(peerUid);
      },
      group: (t) => GroupConversationKey(t.gid),
    );
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
// unreadInfo — derive a conversation's unread count + @-mention flag from the
// locally cached messages and the read-index markers. Mirrors the web client's
// `getUnreadCount`: count messages newer than the read marker that we didn't
// send ourselves, and flag whether any of them mention us.
//
// Keyed by ConversationKey (family). Re-evaluates when:
//   - the read marker for this conversation changes (ref.watch readIndex), or
//   - this conversation's lastMid advances (a new message arrived) — sliced
//     via conversationsProvider.select so unrelated list churn doesn't refire.
// ---------------------------------------------------------------------------

typedef UnreadInfo = ({int count, bool mention});

@riverpod
Future<UnreadInfo> unreadInfo(Ref ref, ConversationKey key) async {
  // Resolve our own uid so we can exclude self-sent messages and detect
  // mentions of ourselves.
  final authState = ref.watch(authControllerProvider).valueOrNull;
  final currentUid =
      authState is AuthStateAuthenticated ? authState.user.uid : 0;

  // Re-run when this conversation's latest mid advances. Watching the whole
  // list would refire on every unrelated preview update.
  final lastMid = ref.watch(
    conversationsProvider.select(
      (async) => async.valueOrNull
          ?.firstWhere(
            (c) => c.key == key,
            orElse: () => const ConversationItem(
                key: GroupConversationKey(-1), name: '', isChannel: true),
          )
          .lastMid,
    ),
  );
  // Nothing in the conversation yet → nothing unread.
  if (lastMid == null || lastMid <= 0) return (count: 0, mention: false);

  final readState = await ref.watch(readIndexProvider.future);

  final (MessageTarget target, int readMid) = switch (key) {
    GroupConversationKey(gid: final gid) => (
        MessageTarget.group(gid: gid),
        readState.readGroup(gid),
      ),
    UserConversationKey(uid: final uid) => (
        MessageTarget.user(uid: uid),
        readState.readUser(uid),
      ),
  };

  // Already read up to the head → no badge (cheap short-circuit, avoids a DB
  // hit for the common all-read case).
  if (readMid >= lastMid) return (count: 0, mention: false);

  final cache = await ref.watch(messageCacheProvider.future);
  return cache.unreadSince(
    target,
    sinceMid: readMid,
    excludeFromUid: currentUid,
    mentionUid: currentUid,
  );
}
