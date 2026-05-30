import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

    final currentUid = _currentUid();

    // Two output piles:
    //   - `merged` mutates `current` in place by upgrading an optimistic row
    //     to its server-confirmed mid (only ever fired when this client is
    //     the original sender).
    //   - `fresh` is prepended (newest-first).
    // We can mix both in one batch: optimistic-merge for SSE echoes of our
    // own `sendText`, fresh-insert for messages from other clients (incl.
    // the same account on a different device).
    final updated = List<ChatMessage>.from(current);
    final fresh = <ChatMessage>[];
    int maxMid = 0;

    for (final m in batch) {
      if (m.mid > 0 && _seenMids.contains(m.mid)) continue;

      // Optimistic-merge path: this is OUR send, echoed back via SSE. Find
      // a same-target placeholder row (negative mid, same content, status
      // sending/sent) and replace it in place so we don't duplicate.
      bool mergedInPlace = false;
      if (currentUid != null && m.fromUid == currentUid && m.mid > 0) {
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

      if (!mergedInPlace) fresh.add(m);

      if (m.mid > 0) {
        _seenMids.add(m.mid);
        if (m.mid > maxMid) maxMid = m.mid;
      }
    }

    if (fresh.isEmpty && identical(updated, current)) return;

    // Re-sort the whole list newest-first. `fresh` alone being ordered isn't
    // enough: an SSE batch can carry mids that interleave with rows already in
    // `updated`, so we order the merged result rather than just prepending.
    final next = _sortedNewestFirst([...fresh, ...updated]);

    state = AsyncData(next);
    _persist(next);
    if (maxMid > 0) {
      _cache?.setCursor(maxMid);
    }
  }

  /// Find the index of an optimistic placeholder row that [echo] should
  /// replace. Match criteria, in order:
  ///   1. Same author (already filtered by caller).
  ///   2. Negative mid (placeholder; real rows have positive mids).
  ///   3. Same surface content (text/markdown/file URL) and content-type —
  ///      this is the only signal we have since temp mids aren't echoed by
  ///      the server.
  ///   4. Reply target mid matches if [echo] is a reply.
  /// Returns -1 if no candidate found.
  int _findOptimisticMatch(
      List<ChatMessage> rows, ChatMessage echo, int currentUid) {
    final echoContent = echo.displayContent;
    final echoContentType = echo.displayContentType;
    final echoReplyMid = switch (echo.detail) {
      ReplyMessageDetail(mid: final m) => m,
      _ => null,
    };
    // For file messages the optimistic content is a local temp path while the
    // echo's content is the server `{"path": <serverPath>}` — they never match
    // by surface content. Instead match on the `local_id` we wrote into
    // X-Properties (which the server echoes back) so the placeholder upgrades
    // in place instead of duplicating.
    final echoLocalId =
        echoContentType == 'vocechat/file' ? _localIdOf(echo) : null;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.mid >= 0) continue;
      if (r.fromUid != currentUid) continue;
      if (echoLocalId != null) {
        if (r.displayContentType != 'vocechat/file') continue;
        if (_localIdOf(r) != echoLocalId) continue;
        return i;
      }
      if (r.displayContent != echoContent) continue;
      if (r.displayContentType != echoContentType) continue;
      final rReplyMid = switch (r.detail) {
        ReplyMessageDetail(mid: final m) => m,
        _ => null,
      };
      if (rReplyMid != echoReplyMid) continue;
      return i;
    }
    return -1;
  }

  /// Extract the `local_id` property (sender-generated dedup key) from a file
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

      // Merge new items with current, then re-sort so any interleaving with
      // existing rows lands in the right place (server "newest first" is not a
      // safe assumption once cache/history/SSE batches mix).
      final next = _sortedNewestFirst([...additions, ...current]);
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
    if (_pendingIncoming.isEmpty) return _sortedNewestFirst(base);
    final extras = <ChatMessage>[];
    for (final m in _pendingIncoming.reversed) {
      if (m.mid > 0 && _seenMids.contains(m.mid)) continue;
      extras.add(m);
      if (m.mid > 0) _seenMids.add(m.mid);
    }
    _pendingIncoming.clear();
    return _sortedNewestFirst(extras.isEmpty ? base : [...extras, ...base]);
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
    final out = List<ChatMessage>.from(input);
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

  /// Optimistically insert an image/file message backed by local [bytes];
  /// upload + send in the background, then upgrade the placeholder to the
  /// server-confirmed mid + path. Mirrors [sendText]'s optimistic pattern but
  /// for `vocechat/file` content.
  Future<void> sendImage({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final currentUid = _currentUid() ?? -1;
    final tempMid = -DateTime.now().microsecondsSinceEpoch;
    // local_id doubles as the dedup key the server echoes back via X-Properties
    // (see _findOptimisticMatch). Use a stable positive int.
    final localId = DateTime.now().millisecondsSinceEpoch;

    // Always resolve a concrete content_type: the optimistic row renders by
    // properties['content_type'], and a missing/empty value makes _isImage()
    // false → the image would wrongly render as a generic file card until the
    // server echo arrives. Infer from filename + magic bytes when not given.
    final resolvedType =
        contentType ?? MessageApi.inferContentType(filename, bytes: bytes);

    final dims = await _decodeImageSize(bytes);

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

    final current = state.valueOrNull ?? [];
    _statuses[tempMid] = MessageSendStatus.sending;
    _progress[tempMid] = 0.0;
    state = AsyncData([optimistic, ...current]);

    await _runFileUpload(tempMid, _pendingFiles[tempMid]!);
  }

  /// Shared upload+confirm path used by [sendImage] and [retrySend] for files.
  Future<void> _runFileUpload(int tempMid, _PendingFile pending) async {
    // Throttle progress emissions: byte-level callbacks fire very often and a
    // full state rebuild per byte would hitch the list. Only emit when the
    // rounded percentage advances.
    int lastPct = -1;
    void onProgress(int sent, int total) {
      if (total <= 0) return;
      final ratio = sent / total;
      final pct = (ratio * 100).floor();
      if (pct == lastPct) return;
      lastPct = pct;
      // Cap optimistic progress at 0.99 — the row only flips to "sent" once the
      // follow-up send request returns, so never show a full 100% mid-flight.
      _progress[tempMid] = ratio.clamp(0.0, 0.99);
      final snap = state.valueOrNull;
      if (snap != null) state = AsyncData(List.from(snap));
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
      final after = state.valueOrNull ?? [];
      final idx = after.indexWhere((m) => m.mid == tempMid);
      if (idx >= 0) {
        final placeholder = after[idx];
        final confirmed = placeholder.copyWith(
          mid: result.mid,
          detail: MessageDetail.normal(
            contentType: 'vocechat/file',
            content: jsonEncode({'path': result.path}),
            properties: _propertiesOf(placeholder),
          ),
        );
        final updated = List<ChatMessage>.from(after);
        updated[idx] = confirmed;
        state = AsyncData(updated);
        _seenMids.add(result.mid);
        _localAttachments.remove(tempMid);
        _pendingFiles.remove(tempMid);
        _progress.remove(tempMid);
        _persist(updated);
        _cache?.setCursor(result.mid);
      }
      _statuses.remove(tempMid);
      _progress.remove(tempMid);
      _statuses[result.mid] = MessageSendStatus.sent;
    } catch (_) {
      _statuses[tempMid] = MessageSendStatus.failed;
      _progress.remove(tempMid);
      final snapshot = state.valueOrNull;
      if (snapshot != null) state = AsyncData(List.from(snapshot));
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
    // File retry: re-run the upload from the cached bytes.
    final pendingFile = _pendingFiles[tempMid];
    if (pendingFile != null) {
      _statuses[tempMid] = MessageSendStatus.sending;
      _progress[tempMid] = 0.0;
      final snap = state.valueOrNull;
      if (snap != null) state = AsyncData(List.from(snap));
      await _runFileUpload(tempMid, pendingFile);
      return;
    }

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
          // Older rows append at the tail, but re-sort the whole list so the
          // pagination boundary can't leave an out-of-order seam.
          final next = _sortedNewestFirst([...current, ...fresh]);
          state = AsyncData(next);
          _persist(next);
        }
      }
    } catch (_) {
      // awaits live server; falls back gracefully
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
