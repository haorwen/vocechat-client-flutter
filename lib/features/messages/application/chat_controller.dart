import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/sse_client.dart';
import '../../../core/utils/app_log.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../data/message_api.dart';
import '../data/message_cache.dart';
import '../domain/message_models.dart';
import '../domain/message_status.dart';

part 'chat_controller.g.dart';

// ---------------------------------------------------------------------------
// ChatController — manages message list for one target (user or group)
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class ChatController extends _$ChatController {
  static const _initialLimit = 50;

  /// UI-only send status keyed by mid (negative for optimistic, then real mid).
  final Map<int, MessageSendStatus> _statuses = {};

  /// Set of mids currently in [state] for O(1) dedup. Kept in sync with state.
  final Set<int> _seenMids = <int>{};

  /// Messages that arrived via SSE before [build] finished its history fetch.
  final List<ChatMessage> _pendingIncoming = [];

  /// Cached cache instance once resolved (kept here so hot writes don't have
  /// to await it every time).
  MessageCache? _cache;

  /// Burst-coalescing buffer: SSE catch-up can replay dozens of messages in
  /// one tick. We accumulate them and flush once per microtask so the chat
  /// list rebuilds at most once per frame.
  final List<ChatMessage> _pendingApply = [];
  bool _applyScheduled = false;

  /// Expose statuses for the UI layer.
  Map<int, MessageSendStatus> get statuses => Map.unmodifiable(_statuses);

  /// Return the send status for a given mid (null if unknown / from others).
  MessageSendStatus? statusFor(int mid) => _statuses[mid];

  /// Public entry point so external listeners (e.g. the global SSE
  /// dispatcher) can feed an incoming message directly.
  ///
  /// Coalesces bursts: SSE replay on reconnect can deliver dozens of
  /// messages back-to-back, and emitting state per message hitches the UI.
  void applyIncomingMessage(ChatMessage msg) {
    // Reactions are sidecar events on existing messages, not their own row.
    // They're handled by MessageDispatcher → ReactionsNotifier.
    if (msg.detail is ReactionMessageDetail) return;

    final currentUid = _currentUid();

    // DM session id is always the OTHER user's uid:
    //   - outgoing  → msg.target.uid is the peer
    //   - incoming  → msg.target.uid is OURSELF; the peer is msg.fromUid
    // Mirrors web `chat.handler.ts`: `id = self ? target.uid : from_uid`.
    final matches = msg.target.map(
      user: (t) => target.map(
        user: (tt) {
          final peerUid =
              currentUid != null && msg.fromUid != currentUid
                  ? msg.fromUid
                  : t.uid;
          return tt.uid == peerUid;
        },
        group: (_) => false,
      ),
      group: (t) =>
          target.map(user: (_) => false, group: (tt) => tt.gid == t.gid),
    );
    if (!matches) return;

    if (currentUid != null && msg.fromUid == currentUid) return;

    if (msg.mid > 0 && _seenMids.contains(msg.mid)) return;

    final current = state.valueOrNull;
    if (current == null) {
      _pendingIncoming.add(msg);
      return;
    }

    _pendingApply.add(msg);
    if (_applyScheduled) return;
    _applyScheduled = true;
    Future.microtask(_flushPendingApply);
  }

  void _flushPendingApply() {
    _applyScheduled = false;
    if (_pendingApply.isEmpty) return;

    final current = state.valueOrNull;
    if (current == null) {
      // Still bootstrapping (build() hasn't resolved yet). DO NOT
      // self-reschedule — microtasks have priority over normal events, and a
      // self-reschedule loop while build() awaits the network/disk will
      // starve the event loop indefinitely. Leave items in _pendingApply;
      // build()'s own `_drainPending` call will absorb them once state lands.
      return;
    }

    final batch = List<ChatMessage>.from(_pendingApply);
    _pendingApply.clear();

    final fresh = <ChatMessage>[];
    int maxMid = 0;
    for (final m in batch) {
      if (m.mid > 0 && _seenMids.contains(m.mid)) continue;
      fresh.add(m);
      if (m.mid > 0) {
        _seenMids.add(m.mid);
        if (m.mid > maxMid) maxMid = m.mid;
      }
    }
    if (fresh.isEmpty) return;

    // Newest message at index 0 (matches reverse:true ListView contract).
    fresh.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final next = <ChatMessage>[...fresh, ...current];

    state = AsyncData(next);
    _persist(next);
    if (maxMid > 0) {
      _cache?.setCursor(maxMid);
    }
  }

  @override
  Future<List<ChatMessage>> build(MessageTarget target) async {
    // Subscribe to SSE for live updates.
    ref.listen(sseEventsProvider, (_, next) {
      next.whenData((event) {
        if (event is ChatEventChat) {
          applyIncomingMessage(event.message);
        }
      });
    });

    // Resolve cache (single-shot await — provider is keepAlive).
    final cache = await ref.watch(messageCacheProvider.future);
    _cache = cache;

    // 1. Seed from disk (single async query — sqlite is fast).
    // Reaction-type messages (edit/delete/like echoes) may have leaked into
    // the cache from earlier builds; strip them on read so they never reach
    // the chat list as "unsupported" rows.
    final cachedRaw = await cache.read(target);
    final cached = cachedRaw
        .where((m) => m.detail is! ReactionMessageDetail)
        .toList(growable: false);
    _seenMids
      ..clear()
      ..addAll(cached.where((m) => m.mid > 0).map((m) => m.mid));
    if (cached.isNotEmpty) {
      // Publish cached state immediately, then refresh from network in the
      // background. The state is observably "data" so the UI can show it
      // right away; the network fetch will overlay newer items via SSE +
      // pagination as needed.
      state = AsyncData(cached);
      _backgroundRefresh(cache);
      // Drain any SSE events that arrived during this await.
      final drained = _drainPending(cached);
      // Persist the filtered snapshot so the cache stops carrying reaction
      // rows forward across launches.
      if (cachedRaw.length != cached.length) {
        cache.scheduleWrite(target, drained);
      }
      return drained;
    }

    // 2. No cache: fetch history from server.
    final messagesRaw = await _loadHistory();
    final messages = messagesRaw
        .where((m) => m.detail is! ReactionMessageDetail)
        .toList(growable: false);
    _seenMids.addAll(messages.where((m) => m.mid > 0).map((m) => m.mid));

    // Drain pending SSE messages that arrived during the await.
    final merged = _drainPending(messages);
    if (merged.isNotEmpty) cache.scheduleWrite(target, merged);
    return merged;
  }

  /// Best-effort refresh after we already painted from cache. We only need
  /// the head of the history (anything newer than what we have); SSE
  /// `after_mid` already covers most of this, so this is purely a safety
  /// net for missed deltas.
  Future<void> _backgroundRefresh(MessageCache cache) async {
    try {
      final freshRaw = await ref
          .read(messageApiProvider)
          .getHistory(target, limit: _initialLimit);
      if (freshRaw.isEmpty) return;
      // Strip reaction rows: they're sidecar events, not displayable history.
      // The dispatcher applies their effect (edit content / delete row) via
      // applyEditEcho/applyDeleteEcho instead.
      final fresh = freshRaw
          .where((m) => m.detail is! ReactionMessageDetail)
          .toList(growable: false);
      if (fresh.isEmpty) return;

      final current = state.valueOrNull ?? const <ChatMessage>[];
      final additions = <ChatMessage>[];
      for (final m in fresh) {
        if (m.mid > 0 && _seenMids.contains(m.mid)) continue;
        additions.add(m);
        if (m.mid > 0) _seenMids.add(m.mid);
      }
      if (additions.isEmpty) return;

      // Merge: new items go to the front (server returned newest first).
      final next = <ChatMessage>[...additions, ...current];
      state = AsyncData(next);
      cache.scheduleWrite(target, next);
      final maxMid = additions
          .map((m) => m.mid)
          .where((m) => m > 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (maxMid > 0) cache.setCursor(maxMid);
    } catch (_) {
      // ignore — cache is still valid
    }
  }

  // ---------------------------------------------------------------------------
  // edit / delete / reply
  // ---------------------------------------------------------------------------

  /// Edit a previously-sent text/markdown message authored by the current user.
  /// On success the row is mutated in place and persisted; the server will also
  /// fan out an edit-reaction event, but [applyEditEcho] is idempotent.
  Future<void> editText(int mid, String newText, {bool markdown = false}) async {
    if (mid <= 0) return;
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((m) => m.mid == mid);
    if (idx < 0) return;

    final api = ref.read(messageApiProvider);
    if (markdown) {
      await api.editMessageMarkdown(mid, newText);
    } else {
      await api.editMessage(mid, newText);
    }
    applyEditEcho(
      mid,
      newText,
      markdown ? 'text/markdown' : 'text/plain',
    );
  }

  /// Delete a message. On success the row is removed locally and persisted.
  /// Treats a 404 as already-deleted (still removes locally).
  Future<void> deleteMessage(int mid) async {
    if (mid <= 0) return;
    try {
      await ref.read(messageApiProvider).deleteMessage(mid);
    } on DioException catch (e) {
      final status = e.response?.statusCode ??
          (e.error is ApiException ? (e.error as ApiException).status : null);
      if (status != 404) rethrow;
      // 404 = already gone on the server; fall through to local removal so
      // our state catches up.
    }
    applyDeleteEcho(mid);
  }

  /// Send a reply to [targetMid]. Optimistically inserts a reply row with a
  /// temp mid; replaces it with the server-confirmed mid on success.
  Future<void> sendReply(
    int targetMid,
    String text, {
    bool markdown = false,
  }) async {
    if (targetMid <= 0) return;
    final currentUid = _currentUid() ?? -1;
    final tempMid = -DateTime.now().microsecondsSinceEpoch;

    final optimistic = ChatMessage(
      mid: tempMid,
      fromUid: currentUid,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      target: target,
      detail: MessageDetail.reply(
        mid: targetMid,
        contentType: markdown ? 'text/markdown' : 'text/plain',
        content: text,
      ),
    );

    final current = state.valueOrNull ?? [];
    _statuses[tempMid] = MessageSendStatus.sending;
    state = AsyncData([optimistic, ...current]);

    try {
      final realMid = await ref
          .read(messageApiProvider)
          .replyMessage(targetMid, text, markdown: markdown);

      final after = state.valueOrNull ?? [];
      final idx = after.indexWhere((m) => m.mid == tempMid);
      if (idx >= 0) {
        final confirmed = optimistic.copyWith(mid: realMid);
        final updated = List<ChatMessage>.from(after);
        updated[idx] = confirmed;
        state = AsyncData(updated);
        _seenMids.add(realMid);
        _persist(updated);
        _cache?.setCursor(realMid);
      }
      _statuses.remove(tempMid);
      _statuses[realMid] = MessageSendStatus.sent;
    } catch (_) {
      _statuses[tempMid] = MessageSendStatus.failed;
      final snapshot = state.valueOrNull;
      if (snapshot != null) state = AsyncData(List.from(snapshot));
      rethrow;
    }
  }

  /// Apply an edit echo (from SSE or local optimistic). Idempotent: re-applying
  /// the same edit is a no-op.
  void applyEditEcho(int targetMid, String content, String contentType) {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((m) => m.mid == targetMid);
    if (idx < 0) return;
    final existing = current[idx];
    if (existing.editedContent == content &&
        existing.editedContentType == contentType) {
      return;
    }
    final updated = List<ChatMessage>.from(current);
    updated[idx] = existing.copyWith(
      editedContent: content,
      editedContentType: contentType,
    );
    state = AsyncData(updated);
    _persist(updated);
  }

  /// Apply a delete echo (from SSE or local optimistic). Idempotent.
  void applyDeleteEcho(int targetMid) {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((m) => m.mid == targetMid);
    if (idx < 0) return;
    final updated = List<ChatMessage>.from(current)..removeAt(idx);
    state = AsyncData(updated);
    _seenMids.remove(targetMid);
    _statuses.remove(targetMid);
    _persist(updated);
  }

  List<ChatMessage> _drainPending(List<ChatMessage> base) {
    if (_pendingIncoming.isEmpty) return base;
    final extras = <ChatMessage>[];
    for (final m in _pendingIncoming.reversed) {
      if (m.mid > 0 && _seenMids.contains(m.mid)) continue;
      extras.add(m);
      if (m.mid > 0) _seenMids.add(m.mid);
    }
    _pendingIncoming.clear();
    return extras.isEmpty ? base : [...extras, ...base];
  }

  void _persist(List<ChatMessage> snapshot) {
    _cache?.scheduleWrite(target, snapshot);
  }

  int? _currentUid() {
    final authState = ref.read(authControllerProvider).valueOrNull;
    if (authState is AuthStateAuthenticated) return authState.user.uid;
    return null;
  }

  Future<List<ChatMessage>> _loadHistory({int? beforeMid}) async {
    try {
      return await ref
          .read(messageApiProvider)
          .getHistory(target, beforeMid: beforeMid, limit: _initialLimit);
    } catch (_) {
      // awaits live server; falls back to empty list when offline
      return [];
    }
  }

  /// Optimistically insert a sent message; flip status on server ack or failure.
  Future<void> sendText(String text) async {
    final currentUid = _currentUid() ?? -1;
    final tempMid = -DateTime.now().microsecondsSinceEpoch;

    final optimistic = ChatMessage(
      mid: tempMid,
      fromUid: currentUid,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      target: target,
      detail: MessageDetail.normal(
        contentType: 'text/plain',
        content: text,
      ),
    );

    final current = state.valueOrNull ?? [];
    _statuses[tempMid] = MessageSendStatus.sending;
    state = AsyncData([optimistic, ...current]);
    AppLog.d(
      LogTag.chat,
      () =>
          '💬 sendText optimistic: tempMid=$tempMid uid=$currentUid count=${current.length + 1}',
    );

    try {
      final isMarkdown = text.startsWith('>') ||
          text.contains('**') ||
          text.contains('```');
      final int realMid;
      if (isMarkdown) {
        realMid = await ref.read(messageApiProvider).sendMarkdown(target, text);
      } else {
        realMid = await ref.read(messageApiProvider).sendText(target, text);
      }

      // Replace placeholder with server-confirmed mid.
      final after = state.valueOrNull ?? [];
      final idx = after.indexWhere((m) => m.mid == tempMid);
      if (idx >= 0) {
        final confirmed = optimistic.copyWith(mid: realMid);
        final updated = List<ChatMessage>.from(after);
        updated[idx] = confirmed;
        state = AsyncData(updated);
        _seenMids.add(realMid);
        _persist(updated);
        _cache?.setCursor(realMid);
      }
      _statuses.remove(tempMid);
      _statuses[realMid] = MessageSendStatus.sent;
    } catch (_) {
      _statuses[tempMid] = MessageSendStatus.failed;
      // Notify listeners that statuses changed (state value unchanged).
      final snapshot = state.valueOrNull;
      if (snapshot != null) state = AsyncData(List.from(snapshot));
    }
  }

  /// Retry a previously failed send identified by [tempMid].
  Future<void> retrySend(int tempMid) async {
    final current = state.valueOrNull ?? [];
    final msg = current.firstWhere(
      (m) => m.mid == tempMid,
      orElse: () => throw StateError('Message $tempMid not found'),
    );
    final detail = msg.detail;
    if (detail is! NormalMessageDetail) return;

    _statuses[tempMid] = MessageSendStatus.sending;
    final snapshot = state.valueOrNull;
    if (snapshot != null) state = AsyncData(List.from(snapshot));

    try {
      final isMarkdown = detail.contentType == 'text/markdown';
      final int realMid;
      if (isMarkdown) {
        realMid =
            await ref.read(messageApiProvider).sendMarkdown(target, detail.content);
      } else {
        realMid = await ref.read(messageApiProvider).sendText(target, detail.content);
      }

      final after = state.valueOrNull ?? [];
      final idx = after.indexWhere((m) => m.mid == tempMid);
      if (idx >= 0) {
        final confirmed = msg.copyWith(mid: realMid);
        final updated = List<ChatMessage>.from(after);
        updated[idx] = confirmed;
        state = AsyncData(updated);
        _seenMids.add(realMid);
        _persist(updated);
        _cache?.setCursor(realMid);
      }
      _statuses.remove(tempMid);
      _statuses[realMid] = MessageSendStatus.sent;
    } catch (_) {
      _statuses[tempMid] = MessageSendStatus.failed;
      final snapshot2 = state.valueOrNull;
      if (snapshot2 != null) state = AsyncData(List.from(snapshot2));
    }
  }

  /// Load older messages (pull-up pagination).
  Future<void> loadMore() async {
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;

    final oldestMid = current
        .where((m) => m.mid > 0)
        .fold<int?>(
            null, (prev, m) => prev == null || m.mid < prev ? m.mid : prev);
    if (oldestMid == null) return;

    try {
      final olderRaw = await _loadHistory(beforeMid: oldestMid);
      final older = olderRaw
          .where((m) => m.detail is! ReactionMessageDetail)
          .toList(growable: false);
      if (older.isNotEmpty) {
        // Filter out any older messages already in state (the SSE replay /
        // history boundary can overlap). Track new mids in the dedup set.
        final fresh = <ChatMessage>[];
        for (final m in older) {
          if (m.mid > 0 && _seenMids.contains(m.mid)) continue;
          fresh.add(m);
          if (m.mid > 0) _seenMids.add(m.mid);
        }
        if (fresh.isNotEmpty) {
          final next = [...current, ...fresh];
          state = AsyncData(next);
          _persist(next);
        }
      }
    } catch (_) {
      // awaits live server; falls back gracefully
    }
  }
}
