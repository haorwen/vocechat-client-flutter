import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/sse_client.dart';
import '../../../core/utils/app_log.dart';
import '../../../features/auth/application/auth_controller.dart';
import 'burn_after_read_provider.dart';
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
  Timer? _expiryTimer;
  bool _loadingMore = false;
  bool _hasMore = true;
  int? _historyBeforeMid;
  int _generation = 0;
  // Riverpod retains previous AsyncValue data during dependency reloads.
  // Track this account's rows separately so a new cache cannot merge them.
  List<ChatMessage>? _messages;

  void _publish(List<ChatMessage> messages) {
    _messages = messages;
    state = AsyncData(messages);
  }

  int? _outgoingExpiresIn() {
    final settings = ref.read(burnAfterReadProvider);
    final seconds = target.map(
      user: (t) => settings.userExpiresIn(t.uid),
      group: (t) => settings.groupExpiresIn(t.gid),
    );
    return seconds > 0 ? seconds : null;
  }

  void _scheduleExpiry(List<ChatMessage>? messages) {
    _expiryTimer?.cancel();
    int? earliest;
    for (final message in messages ?? const <ChatMessage>[]) {
      final deadline = message.expiresAt;
      if (deadline != null && (earliest == null || deadline < earliest)) {
        earliest = deadline;
      }
    }
    if (earliest == null) return;
    final delay = earliest - DateTime.now().millisecondsSinceEpoch;
    _expiryTimer =
        Timer(Duration(milliseconds: delay > 0 ? delay : 0), _expireMessages);
  }

  void _expireMessages() {
    final current = _messages;
    if (current == null) return;
    final next = _withoutExpired(current);
    if (next.length != current.length) {
      _publish(next);
      _persist(next);
    }
    _scheduleExpiry(next);
  }

  List<ChatMessage> _withoutExpired(List<ChatMessage> messages) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return messages.where((m) {
      if (!m.isExpiredAt(now)) return true;
      _seenMids.remove(m.mid);
      _statuses.remove(m.mid);
      _localAttachments.remove(m.mid);
      _pendingFiles.remove(m.mid);
      _progress.remove(m.mid);
      _cache?.deleteMid(target, m.mid);
      return false;
    }).toList();
  }

  /// UI-only send status keyed by mid (negative for optimistic, then real mid).
  final Map<int, MessageSendStatus> _statuses = {};

  /// Local image/file bytes for optimistic `vocechat/file` rows, keyed by the
  /// row's current mid. Lets the UI render a preview from memory before the
  /// upload finishes. Migrated tempMid → realMid on confirm, dropped once the
  /// server row (with a real resource URL) lands so we stop holding the bytes.
  final Map<int, Uint8List> _localAttachments = {};

  /// Pending file uploads kept for retry, keyed by tempMid. Holds the raw bytes
  /// + metadata so [retrySend] can re-run the upload without re-picking.
  final Map<int, _PendingFile> _pendingFiles = {};

  /// Upload progress (0.0–1.0) for in-flight file rows, keyed by the row's
  /// current mid. Present only while uploading; cleared on confirm/failure.
  final Map<int, double> _progress = {};

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

  /// Local bytes for an optimistic file row (null once uploaded/confirmed or
  /// for messages from the server). Used by the UI to preview before upload.
  Uint8List? localBytesFor(int mid) => _localAttachments[mid];

  /// Upload progress (0.0–1.0) for an in-flight file row, or null when not
  /// uploading. Drives the percent overlay on the optimistic image bubble.
  double? progressFor(int mid) => _progress[mid];

  /// Public entry point so external listeners (e.g. the global SSE
  /// dispatcher) can feed an incoming message directly.
  ///
  /// Coalesces bursts: SSE replay on reconnect can deliver dozens of
  /// messages back-to-back, and emitting state per message hitches the UI.
  ///
  /// Multi-device note: messages authored by the current user MUST NOT be
  /// dropped here just because `fromUid == currentUid`. The same account
  /// can be logged in on web + mobile + desktop simultaneously; a message
  /// sent from another client must still appear locally. We rely on
  /// [_flushPendingApply] to merge with any optimistic row (same target +
  /// content, negative temp mid) so a local `sendText` echo upgrades the
  /// placeholder instead of duplicating it.
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
          final peerUid = currentUid != null && msg.fromUid != currentUid
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

    final current = _messages;
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

    final current = _messages;
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

    final next = _mergeIncoming(current, batch);
    if (listEquals(next, current)) return;
    _publish(next);
    _persist(next);
    final maxMid = batch.fold<int>(0, (mid, m) => m.mid > mid ? m.mid : mid);
    if (maxMid > 0) _cache?.setCursor(maxMid);
  }

  List<ChatMessage> _mergeIncoming(
      List<ChatMessage> current, List<ChatMessage> batch,
      {bool matchOptimistic = true}) {
    final currentUid = _currentUid();

    // Merge against the rows themselves so cache, history and repeated live
    // events share the same deduplication and optimistic confirmation rules.
    final updated = List<ChatMessage>.from(current);
    for (final m in batch) {
      if (m.detail is ReactionMessageDetail) continue;
      final existingIndex = updated.indexWhere((row) => row.mid == m.mid);
      if (m.mid > 0 && existingIndex >= 0) {
        // HTTP acknowledgements only return a mid. Keep the authoritative
        // SSE timestamp/expiry even when that mid was already confirmed.
        updated[existingIndex] = m.copyWith(
          editedContent: updated[existingIndex].editedContent,
          editedContentType: updated[existingIndex].editedContentType,
        );
        continue;
      }

      // Optimistic-merge path: this is OUR send, echoed back via SSE. Find
      // a same-target placeholder row (negative mid, same content, status
      // sending/sent) and replace it in place so we don't duplicate.
      bool mergedInPlace = false;
      if ((matchOptimistic || _localIdOf(m) != null) &&
          currentUid != null &&
          m.fromUid == currentUid &&
          m.mid > 0) {
        final idx = _findOptimisticMatch(updated, m, currentUid);
        if (idx >= 0) {
          final placeholder = updated[idx];
          final placeholderMid = placeholder.mid;
          updated[idx] = m;
          if (placeholderMid < 0) {
            _statuses.remove(placeholderMid);
            _statuses[m.mid] = MessageSendStatus.sent;
            // The server row carries a real resource path now; drop the local
            // preview bytes + pending-retry entry + progress for the placeholder.
            _localAttachments.remove(placeholderMid);
            _pendingFiles.remove(placeholderMid);
            _progress.remove(placeholderMid);
          }
          mergedInPlace = true;
        }
      }

      if (!mergedInPlace) updated.add(m);
    }
    final next = _sortedNewestFirst(updated);
    _seenMids
      ..clear()
      ..addAll(next.where((m) => m.mid > 0).map((m) => m.mid));
    return next;
  }

  /// Find the index of an optimistic placeholder row that [echo] should
  /// replace. Match criteria, in order:
  ///   1. Same author (already filtered by caller).
  ///   2. Negative mid (placeholder; real rows have positive mids).
  ///   3. The sender-generated local_id echoed in properties must match.
  ///      Content/reply matching is only used for legacy rows without an id.
  /// Returns -1 if no candidate found.
  int _findOptimisticMatch(
      List<ChatMessage> rows, ChatMessage echo, int currentUid) {
    final echoContent = echo.displayContent;
    final echoContentType = echo.displayContentType;
    final echoReplyMid = switch (echo.detail) {
      ReplyMessageDetail(mid: final m) => m,
      _ => null,
    };
    final echoLocalId = _localIdOf(echo);

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.mid >= 0) continue;
      if (r.fromUid != currentUid) continue;
      if (r.displayContentType != echoContentType) continue;
      if (echoLocalId != null) {
        if (_localIdOf(r) != echoLocalId) continue;
        return i;
      }
      // A message sent from another device with the same text is a distinct
      // send. It cannot acknowledge one of this client's identified rows.
      if (_localIdOf(r) != null) continue;
      if (r.displayContent != echoContent) continue;
      final rReplyMid = switch (r.detail) {
        ReplyMessageDetail(mid: final m) => m,
        _ => null,
      };
      if (rReplyMid != echoReplyMid) continue;
      return i;
    }
    return -1;
  }

  /// Extract the `local_id` property (sender-generated dedup key) from a
  /// message, if present.
  static int? _localIdOf(ChatMessage m) {
    final props = switch (m.detail) {
      NormalMessageDetail(properties: final p) => p,
      ReplyMessageDetail(properties: final p) => p,
      _ => null,
    };
    return (props?['local_id'] as num?)?.toInt();
  }

  @override
  Future<List<ChatMessage>> build(MessageTarget target) async {
    final generation = ++_generation;
    _cache = null;
    _messages = null;
    _loadingMore = false;
    _hasMore = true;
    _historyBeforeMid = null;
    // The cache dependency changes when switching accounts. Previous rows
    // must not become the base for the new account's initial history merge.
    state = const AsyncLoading();
    _pendingIncoming.clear();
    _pendingApply.clear();
    _seenMids.clear();
    _statuses.clear();
    _localAttachments.clear();
    _pendingFiles.clear();
    _progress.clear();
    listenSelf((_, next) => _scheduleExpiry(next.valueOrNull));
    final lifecycle = AppLifecycleListener(onResume: _expireMessages);
    ref.onDispose(() {
      ++_generation;
      _expiryTimer?.cancel();
      _pendingIncoming.clear();
      _pendingApply.clear();
      lifecycle.dispose();
    });

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
    if (generation != _generation) return const [];
    _cache = cache;

    // 1. Seed from disk (single async query — sqlite is fast).
    // Reaction-type messages (edit/delete/like echoes) may have leaked into
    // the cache from earlier builds; strip them on read so they never reach
    // the chat list as "unsupported" rows.
    final cachedRaw = await cache.read(target);
    if (generation != _generation) return const [];
    final cached = _withoutExpired(cachedRaw)
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
      final drained = _drainPending(cached);
      _publish(drained);
      _backgroundRefresh(cache);
      // Persist the filtered snapshot so the cache stops carrying reaction
      // rows forward across launches.
      if (cachedRaw.length != cached.length) {
        cache.scheduleWrite(target, drained);
      }
      return drained;
    }

    // 2. No cache: fetch history from server.
    final messagesRaw = await _loadHistory();
    if (generation != _generation) return const [];
    final messages = _withoutExpired(messagesRaw)
        .where((m) => m.detail is! ReactionMessageDetail)
        .toList(growable: false);
    _seenMids.addAll(messages.where((m) => m.mid > 0).map((m) => m.mid));

    // Drain pending SSE messages that arrived during the await.
    final merged = _drainPending(messages);
    _messages = merged;
    if (merged.isNotEmpty) cache.scheduleWrite(target, merged);
    return merged;
  }

  /// Best-effort refresh after we already painted from cache. We only need
  /// the head of the history (anything newer than what we have); SSE
  /// `after_mid` already covers most of this, so this is purely a safety
  /// net for missed deltas.
  Future<void> _backgroundRefresh(MessageCache cache) async {
    final generation = _generation;
    try {
      final freshRaw = await ref
          .read(messageApiProvider)
          .getHistory(target, limit: _initialLimit);
      if (generation != _generation) return;
      if (freshRaw.isEmpty) return;
      // Strip reaction rows: they're sidecar events, not displayable history.
      // The dispatcher applies their effect (edit content / delete row) via
      // applyEditEcho/applyDeleteEcho instead.
      final fresh = freshRaw
          .where((m) => m.detail is! ReactionMessageDetail)
          .toList(growable: false);
      if (fresh.isEmpty) return;

      final current = _messages ?? const <ChatMessage>[];
      final next = _mergeIncoming(current, fresh, matchOptimistic: false);
      if (listEquals(next, current)) return;
      _publish(next);
      cache.scheduleWrite(target, next);
      final maxMid = fresh
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
  Future<void> editText(int mid, String newText,
      {bool markdown = false}) async {
    final generation = _generation;
    if (mid <= 0) return;
    final current = _messages;
    if (current == null) return;
    final idx = current.indexWhere((m) => m.mid == mid);
    if (idx < 0) return;

    final api = ref.read(messageApiProvider);
    if (markdown) {
      await api.editMessageMarkdown(mid, newText);
    } else {
      await api.editMessage(mid, newText);
    }
    if (generation != _generation) return;
    applyEditEcho(
      mid,
      newText,
      markdown ? 'text/markdown' : 'text/plain',
    );
  }

  /// Delete a message. On success the row is removed locally and persisted.
  /// Treats a 404 as already-deleted (still removes locally).
  Future<void> deleteMessage(int mid) async {
    final generation = _generation;
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
    if (generation != _generation) return;
    applyDeleteEcho(mid);
  }

  /// Send a reply to [targetMid]. Optimistically inserts a reply row with a
  /// temp mid; replaces it with the server-confirmed mid on success.
  Future<void> sendReply(
    int targetMid,
    String text, {
    bool markdown = false,
    List<int>? mentions,
  }) async {
    final generation = _generation;
    if (targetMid <= 0) return;
    final currentUid = _currentUid() ?? -1;
    final tempMid = -DateTime.now().microsecondsSinceEpoch;
    final properties = <String, dynamic>{
      'local_id': -tempMid,
      if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
    };

    final optimistic = ChatMessage(
      mid: tempMid,
      fromUid: currentUid,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      target: target,
      detail: MessageDetail.reply(
        mid: targetMid,
        contentType: markdown ? 'text/markdown' : 'text/plain',
        content: text,
        properties: properties,
        expiresIn: _outgoingExpiresIn(),
      ),
    );

    final current = _messages ?? [];
    _statuses[tempMid] = MessageSendStatus.sending;
    _publish([optimistic, ...current]);

    try {
      final realMid = await ref.read(messageApiProvider).replyMessage(
          targetMid, text,
          markdown: markdown, mentions: mentions, localId: -tempMid);
      if (generation != _generation) return;

      _confirmSent(
          tempMid,
          optimistic.copyWith(
              mid: realMid, createdAt: DateTime.now().millisecondsSinceEpoch));
    } catch (_) {
      if (generation != _generation) return;
      _statuses[tempMid] = MessageSendStatus.failed;
      final snapshot = _messages;
      if (snapshot != null) _publish(List.from(snapshot));
      rethrow;
    }
  }

  /// Apply an edit echo (from SSE or local optimistic). Idempotent: re-applying
  /// the same edit is a no-op.
  void applyEditEcho(int targetMid, String content, String contentType) {
    final current = _messages;
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
    _publish(updated);
    _persist(updated);
  }

  /// Apply a delete echo (from SSE or local optimistic). Idempotent.
  void applyDeleteEcho(int targetMid) {
    final current = _messages;
    if (current == null) return;
    final idx = current.indexWhere((m) => m.mid == targetMid);
    if (idx < 0) return;
    final updated = List<ChatMessage>.from(current)..removeAt(idx);
    _publish(updated);
    _seenMids.remove(targetMid);
    _statuses.remove(targetMid);
    _persist(updated);
    _cache?.deleteMid(target, targetMid);
  }

  List<ChatMessage> _drainPending(List<ChatMessage> base) {
    // A send or live event may already have published state while disk or
    // history was loading. Merge into that latest state, never overwrite it.
    final history =
        _mergeIncoming(_messages ?? const [], base, matchOptimistic: false);
    final next =
        _mergeIncoming(history, [..._pendingIncoming, ..._pendingApply]);
    _pendingIncoming.clear();
    _pendingApply.clear();
    return next;
  }

  /// Single source of truth for chat-list ordering. The whole app (the
  /// `reverse:true` ListView, the date-separator logic, pagination cursors)
  /// assumes index 0 is the newest message. Every merge point — cache seed,
  /// background refresh, SSE flush, pagination — funnels its result through
  /// here so the list is *globally* ordered regardless of which source the
  /// rows came from. Without this, interleaving cache/history/SSE batches can
  /// land an older day's message below a newer one (e.g. a 5/28 row beneath
  /// 5/29).
  ///
  /// Ordering key, newest-first:
  ///   - Confirmed rows (positive, server-assigned `mid`) sort by `mid`
  ///     descending. `mid` is the server's monotonic sequence and the
  ///     authoritative order — it matches the cache layer's `ORDER BY mid DESC`
  ///     and is immune to clock skew between `created_at` values.
  ///   - Optimistic rows (negative temp `mid`, not yet acked) always sit at the
  ///     very top (they're the just-sent messages) and tie-break among
  ///     themselves by `createdAt` descending.
  /// The sort is stable, so equal keys keep their relative input order.
  List<ChatMessage> _sortedNewestFirst(List<ChatMessage> input) {
    final out = _withoutExpired(input);
    out.sort((a, b) {
      final aOptimistic = a.mid < 0;
      final bOptimistic = b.mid < 0;
      if (aOptimistic && bOptimistic) {
        return b.createdAt.compareTo(a.createdAt);
      }
      // Optimistic (unsent) rows always rank above confirmed ones.
      if (aOptimistic) return -1;
      if (bOptimistic) return 1;
      return b.mid.compareTo(a.mid);
    });
    return out;
  }

  void _confirmSent(int tempMid, ChatMessage confirmed) {
    _statuses.remove(tempMid);
    _statuses[confirmed.mid] = MessageSendStatus.sent;
    final current = _messages ?? const <ChatMessage>[];
    if (!current.any((m) => m.mid == tempMid)) return;
    // History or SSE may already carry the authoritative row. Preserve it,
    // remove the placeholder, and sort by server mid after HTTP confirmation.
    final rows = current.where((m) => m.mid != tempMid).toList();
    if (!rows.any((m) => m.mid == confirmed.mid)) rows.add(confirmed);
    final next = _sortedNewestFirst(rows);
    _seenMids.add(confirmed.mid);
    _publish(next);
    _persist(next);
    _cache?.setCursor(confirmed.mid);
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
  /// [mentions] (uids referenced via ` @{uid} ` tokens, group chats only) is
  /// carried in `properties.mentions` for both the optimistic row and the
  /// outgoing request.
  Future<void> sendText(
    String text, {
    List<int>? mentions,
    bool markdown = false,
  }) async {
    final generation = _generation;
    final currentUid = _currentUid() ?? -1;
    final tempMid = -DateTime.now().microsecondsSinceEpoch;
    final properties = <String, dynamic>{
      'local_id': -tempMid,
      if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
    };

    final optimistic = ChatMessage(
      mid: tempMid,
      fromUid: currentUid,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      target: target,
      detail: MessageDetail.normal(
        contentType: markdown ? 'text/markdown' : 'text/plain',
        content: text,
        properties: properties,
        expiresIn: _outgoingExpiresIn(),
      ),
    );

    final current = _messages ?? [];
    _statuses[tempMid] = MessageSendStatus.sending;
    _publish([optimistic, ...current]);
    AppLog.d(
      LogTag.chat,
      () =>
          '💬 sendText optimistic: tempMid=$tempMid uid=$currentUid count=${current.length + 1}',
    );

    try {
      final int realMid;
      if (markdown) {
        realMid = await ref
            .read(messageApiProvider)
            .sendMarkdown(target, text, mentions: mentions, localId: -tempMid);
      } else {
        realMid = await ref
            .read(messageApiProvider)
            .sendText(target, text, mentions: mentions, localId: -tempMid);
      }

      // Replace placeholder with server-confirmed mid.
      if (generation != _generation) return;
      _confirmSent(
          tempMid,
          optimistic.copyWith(
              mid: realMid, createdAt: DateTime.now().millisecondsSinceEpoch));
    } catch (_) {
      if (generation != _generation) return;
      _statuses[tempMid] = MessageSendStatus.failed;
      // Notify listeners that statuses changed (state value unchanged).
      final snapshot = _messages;
      if (snapshot != null) _publish(List.from(snapshot));
    }
  }

  /// Optimistically insert an image/file message backed by local [bytes];
  /// upload + send in the background, then upgrade the placeholder to the
  /// server-confirmed mid + path. Mirrors [sendText]'s optimistic pattern but
  /// for `vocechat/file` content.
  Future<void> sendImage({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final generation = _generation;
    final currentUid = _currentUid() ?? -1;
    final tempMid = -DateTime.now().microsecondsSinceEpoch;
    // local_id doubles as the dedup key the server echoes back via X-Properties
    // (see _findOptimisticMatch). Use a stable positive int.
    final localId = -tempMid;

    // Always resolve a concrete content_type: the optimistic row renders by
    // properties['content_type'], and a missing/empty value makes _isImage()
    // false → the image would wrongly render as a generic file card until the
    // server echo arrives. Infer from filename + magic bytes when not given.
    final resolvedType =
        contentType ?? MessageApi.inferContentType(filename, bytes: bytes);

    filename = MessageApi.resolveFilename(
      filename,
      bytes: bytes,
      contentType: resolvedType,
    );

    final dims = await _decodeImageSize(bytes);
    if (generation != _generation) return;

    final properties = <String, dynamic>{
      'name': filename,
      'content_type': resolvedType,
      'size': bytes.length,
      if (dims != null) 'width': dims.$1,
      if (dims != null) 'height': dims.$2,
      'local_id': localId,
    };

    final optimistic = ChatMessage(
      mid: tempMid,
      fromUid: currentUid,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      target: target,
      detail: MessageDetail.normal(
        contentType: 'vocechat/file',
        // Placeholder content; the real {"path": ...} arrives via the echo.
        content: jsonEncode({'path': 'local:$localId'}),
        properties: properties,
        expiresIn: _outgoingExpiresIn(),
      ),
    );

    _localAttachments[tempMid] = bytes;
    _pendingFiles[tempMid] = _PendingFile(
      bytes: bytes,
      filename: filename,
      contentType: resolvedType,
      localId: localId,
      width: dims?.$1,
      height: dims?.$2,
    );

    final current = _messages ?? [];
    _statuses[tempMid] = MessageSendStatus.sending;
    _progress[tempMid] = 0.0;
    _publish([optimistic, ...current]);

    await _runFileUpload(tempMid, _pendingFiles[tempMid]!);
  }

  /// Shared upload+confirm path used by [sendImage] and [retrySend] for files.
  Future<void> _runFileUpload(int tempMid, _PendingFile pending) async {
    final generation = _generation;
    // Throttle progress emissions: byte-level callbacks fire very often and a
    // full state rebuild per byte would hitch the list. Only emit when the
    // rounded percentage advances.
    int lastPct = -1;
    void onProgress(int sent, int total) {
      if (generation != _generation) return;
      if (total <= 0) return;
      final ratio = sent / total;
      final pct = (ratio * 100).floor();
      if (pct == lastPct) return;
      lastPct = pct;
      // Cap optimistic progress at 0.99 — the row only flips to "sent" once the
      // follow-up send request returns, so never show a full 100% mid-flight.
      _progress[tempMid] = ratio.clamp(0.0, 0.99);
      final snap = _messages;
      if (snap != null) _publish(List.from(snap));
    }

    try {
      final result = await ref.read(messageApiProvider).uploadBytesAndSend(
            target,
            bytes: pending.bytes,
            filename: pending.filename,
            contentType: pending.contentType,
            width: pending.width,
            height: pending.height,
            localId: pending.localId,
            onSendProgress: onProgress,
          );

      // Upgrade placeholder → confirmed. Swap content to the real server path
      // and DROP the local preview bytes + progress so the row now renders via
      // the network-backed _ImageBubble — identical to a received image
      // (tap-to-fullscreen, thumbnail, etc.). The brief thumbnail load is
      // covered by _ImageBubble's own spinner placeholder.
      if (generation != _generation) return;
      _statuses.remove(tempMid);
      _statuses[result.mid] = MessageSendStatus.sent;
      final after = _messages ?? [];
      final idx = after.indexWhere((m) => m.mid == tempMid);
      if (idx >= 0) {
        final placeholder = after[idx];
        final confirmed = placeholder.copyWith(
          mid: result.mid,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          detail: MessageDetail.normal(
            contentType: 'vocechat/file',
            content: jsonEncode({'path': result.path}),
            properties: _propertiesOf(placeholder),
            expiresIn: _outgoingExpiresIn(),
          ),
        );
        _localAttachments.remove(tempMid);
        _pendingFiles.remove(tempMid);
        _progress.remove(tempMid);
        _confirmSent(tempMid, confirmed);
      }
      _progress.remove(tempMid);
    } catch (_) {
      if (generation != _generation) return;
      _statuses[tempMid] = MessageSendStatus.failed;
      _progress.remove(tempMid);
      final snapshot = _messages;
      if (snapshot != null) _publish(List.from(snapshot));
    }
  }

  static Map<String, dynamic>? _propertiesOf(ChatMessage m) {
    return switch (m.detail) {
      NormalMessageDetail(properties: final p) => p,
      ReplyMessageDetail(properties: final p) => p,
      _ => null,
    };
  }

  /// Decode image pixel dimensions from raw bytes via dart:ui (no extra dep).
  /// Returns null for non-images / undecodable bytes.
  Future<(int, int)?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (w <= 0 || h <= 0) return null;
      return (w, h);
    } catch (_) {
      return null;
    }
  }

  /// Retry a previously failed send identified by [tempMid].
  Future<void> retrySend(int tempMid) async {
    final generation = _generation;
    // File retry: re-run the upload from the cached bytes.
    final pendingFile = _pendingFiles[tempMid];
    if (pendingFile != null) {
      _statuses[tempMid] = MessageSendStatus.sending;
      _progress[tempMid] = 0.0;
      final snap = _messages;
      if (snap != null) _publish(List.from(snap));
      await _runFileUpload(tempMid, pendingFile);
      return;
    }

    final current = _messages ?? [];
    final msg = current.firstWhere(
      (m) => m.mid == tempMid,
      orElse: () => throw StateError('Message $tempMid not found'),
    );
    final detail = msg.detail;
    if (detail is! NormalMessageDetail) return;

    _statuses[tempMid] = MessageSendStatus.sending;
    final snapshot = _messages;
    if (snapshot != null) _publish(List.from(snapshot));

    try {
      final isMarkdown = detail.contentType == 'text/markdown';
      final localId = _localIdOf(msg);
      final mentions = (detail.properties?['mentions'] as List?)
          ?.whereType<num>()
          .map((uid) => uid.toInt())
          .toList();
      final int realMid;
      if (isMarkdown) {
        realMid = await ref.read(messageApiProvider).sendMarkdown(
            target, detail.content,
            mentions: mentions, localId: localId);
      } else {
        realMid = await ref.read(messageApiProvider).sendText(
            target, detail.content,
            mentions: mentions, localId: localId);
      }

      if (generation != _generation) return;
      _confirmSent(
          tempMid,
          msg.copyWith(
              mid: realMid, createdAt: DateTime.now().millisecondsSinceEpoch));
    } catch (_) {
      if (generation != _generation) return;
      _statuses[tempMid] = MessageSendStatus.failed;
      final snapshot2 = _messages;
      if (snapshot2 != null) _publish(List.from(snapshot2));
    }
  }

  /// Load older messages (pull-up pagination).
  Future<void> loadMore() async {
    final generation = _generation;
    if (_loadingMore || !_hasMore) return;
    final current = _messages ?? [];
    if (current.isEmpty) return;

    final oldestMid = current.where((m) => m.mid > 0).fold<int?>(
        null, (prev, m) => prev == null || m.mid < prev ? m.mid : prev);
    if (oldestMid == null) return;
    final beforeMid =
        _historyBeforeMid != null && _historyBeforeMid! < oldestMid
            ? _historyBeforeMid!
            : oldestMid;
    _loadingMore = true;
    try {
      // A failed request must remain retryable; only a successful empty page
      // means we have reached the start of the conversation.
      final olderRaw = await ref
          .read(messageApiProvider)
          .getHistory(target, beforeMid: beforeMid, limit: _initialLimit);
      if (generation != _generation) return;
      if (olderRaw.isEmpty) {
        _hasMore = false;
        return;
      }
      _historyBeforeMid = olderRaw.fold<int>(
          beforeMid, (mid, m) => m.mid > 0 && m.mid < mid ? m.mid : mid);
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
          // Older rows append at the tail, but re-sort the whole list so the
          // pagination boundary can't leave an out-of-order seam.
          final latest = _messages ?? const <ChatMessage>[];
          final next = _sortedNewestFirst([...latest, ...fresh]);
          _publish(next);
          _persist(next);
        }
      }
    } catch (_) {
      // awaits live server; falls back gracefully
    } finally {
      if (generation == _generation) _loadingMore = false;
    }
  }
}

/// Cached pending file upload for optimistic send + retry.
class _PendingFile {
  const _PendingFile({
    required this.bytes,
    required this.filename,
    required this.contentType,
    required this.localId,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String filename;
  final String? contentType;
  final int localId;
  final int? width;
  final int? height;
}
