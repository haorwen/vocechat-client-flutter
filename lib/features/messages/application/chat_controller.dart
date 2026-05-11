import 'package:riverpod_annotation/riverpod_annotation.dart';

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
      // Still loading — re-queue to wait until build() finishes.
      _applyScheduled = true;
      Future.microtask(_flushPendingApply);
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
    final cached = await cache.read(target);
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
      return _drainPending(cached);
    }

    // 2. No cache: fetch history from server.
    final messages = await _loadHistory();
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
      final fresh = await ref
          .read(messageApiProvider)
          .getHistory(target, limit: _initialLimit);
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
      final older = await _loadHistory(beforeMid: oldestMid);
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
