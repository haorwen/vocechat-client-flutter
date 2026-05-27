import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_token_store.dart';
import '../storage/server_store.dart';
import '../utils/app_log.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/messages/data/message_cache.dart';
import '../../features/messages/domain/message_models.dart';

part 'sse_client.g.dart';

// ---------------------------------------------------------------------------
// VoceSseClient
// ---------------------------------------------------------------------------
//
// We talk to `/api/user/events_ws` — the server's WebSocket twin of the SSE
// `/api/user/events` endpoint. Same JSON envelopes, but each message is its
// own WebSocket text frame, so there's no chunked-transfer + gzip + line-
// splitter dance. This avoids the Windows-desktop SSE buffering problem we
// hit with the HTTP-based clients.
//
// Liveness model: mirrors web `useStreaming.ts`. Server emits `heartbeat`
// events every ~15s; the client runs a 20s dead-man's-switch watchdog
// reset on every received event. When the watchdog fires, the socket is
// torn down and `onDone` triggers the normal reconnect path. This catches
// silent NAT/firewall drops where TCP keepalive hasn't yet surfaced the
// failure.

/// Watchdog timeout — must be at least the server's heartbeat period (15s)
/// plus jitter. Web uses 20s; mirror that.
const Duration _kSseWatchdog = Duration(seconds: 20);

class VoceSseClient {
  VoceSseClient({
    required this.baseUrl,
    required this.apiKey,
    int? initialAfterMid,
  }) : _highWaterMid = initialAfterMid;

  final String baseUrl;
  final String apiKey;

  static const Duration _maxBackoff = Duration(seconds: 30);

  /// Highest message id observed so far. Sent as `after_mid` on every
  /// (re)connect so the server replays anything we missed during a gap.
  int? _highWaterMid;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;

  /// Dead-man's-switch: if no event arrives within [_kSseWatchdog] we
  /// assume the link is dead and force a reconnect.
  Timer? _watchdog;

  /// Set when the consumer (provider dispose) tears us down explicitly —
  /// suppresses any in-flight reconnect schedules.
  bool _disposed = false;

  /// Returns a broadcast [Stream<ChatEvent>] with auto-reconnect.
  Stream<ChatEvent> events() {
    final controller = StreamController<ChatEvent>.broadcast(
      onCancel: () {
        _disposed = true;
        _cleanup();
      },
    );
    _connect(controller, const Duration(seconds: 1));
    return controller.stream;
  }

  /// Force an immediate reconnect (e.g. after network came back or app
  /// resumed from background). Safe to call from outside.
  void forceReconnect(StreamController<ChatEvent> controller) {
    if (_disposed) return;
    AppLog.w(LogTag.sse, () => '🔄 SSE forceReconnect');
    _cleanup();
    _connect(controller, const Duration(seconds: 1));
  }

  Future<void> _connect(
      StreamController<ChatEvent> controller, Duration currentDelay) async {
    if (_disposed || controller.isClosed) return;

    final encodedKey = Uri.encodeComponent(apiKey);
    final query = StringBuffer('api-key=$encodedKey');
    if (_highWaterMid != null) {
      query.write('&after_mid=${_highWaterMid!}');
    }

    // Convert https:// → wss:// (and http → ws). Server route is
    // `/api/user/events_ws`.
    final wsBase = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final url = '$wsBase/api/user/events_ws?$query';

    WebSocket socket;
    try {
      socket = await WebSocket.connect(
        url,
        headers: {'X-API-Key': apiKey},
      );
    } catch (e) {
      AppLog.w(LogTag.sse, () => '⚠️ SSE connect failed: $e');
      _scheduleReconnect(controller, currentDelay);
      return;
    }
    // WebSocket-protocol-level ping. Lower-cost than the business-layer
    // watchdog but doesn't catch app-layer hangs — both work together.
    socket.pingInterval = const Duration(seconds: 30);
    _socket = socket;

    bool firstFrame = true;
    _armWatchdog(controller);
    _sub = socket.listen(
      (frame) async {
        if (_disposed || controller.isClosed) return;
        // Any frame at all means the link is alive. Reset the watchdog.
        _armWatchdog(controller);
        if (firstFrame) {
          firstFrame = false;
          currentDelay = const Duration(seconds: 1);
        }
        final raw = frame is String
            ? frame
            : (frame is List<int> ? utf8.decode(frame) : frame.toString());
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return;

        final eventType = _peekTypeField(trimmed) ?? '';

        ChatEvent chatEvent;
        if (eventType == 'ready' ||
            eventType == 'heartbeat' ||
            eventType == 'kick') {
          chatEvent = parseSseEvent(eventType, trimmed);
        } else {
          try {
            chatEvent = await compute(
              _parseSseEventInIsolate,
              [eventType, trimmed],
              debugLabel: 'parseSseEvent',
            );
          } catch (_) {
            chatEvent = ChatEvent.unknown(type: eventType, raw: trimmed);
          }
          if (controller.isClosed) return;
        }

        if (chatEvent is ChatEventChat) {
          final mid = chatEvent.message.mid;
          if (mid > 0 && (_highWaterMid == null || mid > _highWaterMid!)) {
            _highWaterMid = mid;
          }
        }
        controller.add(chatEvent);
      },
      onError: (e) {
        AppLog.w(LogTag.sse, () => '⚠️ SSE socket error: $e');
        _scheduleReconnect(controller, currentDelay);
      },
      onDone: () {
        AppLog.w(LogTag.sse, () => '🔌 SSE socket closed');
        _scheduleReconnect(controller, currentDelay);
      },
      cancelOnError: false,
    );
  }

  void _armWatchdog(StreamController<ChatEvent> controller) {
    _watchdog?.cancel();
    _watchdog = Timer(_kSseWatchdog, () {
      AppLog.w(LogTag.sse,
          () => '⏱️ SSE watchdog fired — no events for ${_kSseWatchdog.inSeconds}s, reconnecting');
      _cleanup();
      // Reset backoff: this is a heartbeat-miss, not a hard error.
      _connect(controller, const Duration(seconds: 1));
    });
  }

  void _scheduleReconnect(
      StreamController<ChatEvent> controller, Duration delay) {
    if (_disposed || controller.isClosed) return;
    _cleanup();
    Future.delayed(delay, () {
      if (_disposed || controller.isClosed) return;
      final nextDelay = delay * 2;
      final capped = nextDelay > _maxBackoff ? _maxBackoff : nextDelay;
      _connect(controller, capped);
    });
  }

  void _cleanup() {
    _watchdog?.cancel();
    _watchdog = null;
    _sub?.cancel();
    _sub = null;
    _socket?.close().catchError((_) {});
    _socket = null;
  }
}

// ---------------------------------------------------------------------------
// SSE connection status — UI can show a "reconnecting…" capsule etc.
// ---------------------------------------------------------------------------

enum SseStatus { idle, connecting, connected, disconnected, reconnecting }

@Riverpod(keepAlive: true)
class SseConnectionStatus extends _$SseConnectionStatus {
  @override
  SseStatus build() => SseStatus.idle;

  // ignore: use_setters_to_change_properties
  void set(SseStatus value) => state = value;
}

// ---------------------------------------------------------------------------
// SSE provider
// ---------------------------------------------------------------------------
//
// `keepAlive: true` because [MessageDispatcher] is the canonical long-lived
// listener; AutoDispose would otherwise teardown/restart the WebSocket every
// time the listener set transiently empties.
//
// The provider rebuilds (closing the old WebSocket, opening a new one)
// whenever any of these change:
//   - auth state (sign-in / sign-out)
//   - current server
//   - stored tokens for the current server (token refresh)
// This is what makes "refresh → SSE picks up new token automatically" work.

@Riverpod(keepAlive: true)
Stream<ChatEvent> sseEvents(Ref ref) async* {
  // Only stream when authenticated. Watching authController makes the
  // provider rebuild on login/logout.
  final authState = await ref.watch(authControllerProvider.future);
  if (authState is! AuthStateAuthenticated) return;

  // Watching serverStore makes the provider rebuild on server switch.
  final serverState = await ref.watch(serverStoreProvider.future);
  final serverId = serverState.currentServerId;
  if (serverId == null) return;
  final currentServer =
      serverState.servers.where((s) => s.id == serverId).firstOrNull;
  if (currentServer == null) return;

  // Token. We READ rather than WATCH here because the token store doesn't
  // expose a stream; instead we manually invalidate this provider when a
  // refresh happens (see SseTokenWatcher below).
  final tokenStore = ref.read(secureTokenStoreProvider(serverId));
  var tokens = await tokenStore.readTokens();
  if (tokens == null) return;

  // Proactive renew: if the token is within 30s of expiring, refresh first.
  // Mirrors web `useStreaming.ts`'s 20s pre-expire renew (we give a bit more
  // headroom because mobile clients can have higher RTT).
  final aboutToExpire =
      tokens.expiresAt.isBefore(DateTime.now().add(const Duration(seconds: 30)));
  if (aboutToExpire) {
    AppLog.w(LogTag.sse, () => '🔑 SSE: token within 30s of expiry, renewing first');
    final renewed = await ref
        .read(authControllerProvider.notifier)
        .renewIfPossible();
    if (!renewed) {
      AppLog.w(LogTag.sse, () => '🔑 SSE: token renew failed, aborting connect');
      return;
    }
    tokens = await tokenStore.readTokens();
    if (tokens == null) return;
  }

  final cache = await ref.read(messageCacheProvider.future);
  final cursor = await cache.getCursor();

  final client = VoceSseClient(
    baseUrl: currentServer.baseUrl,
    apiKey: tokens.accessToken,
    initialAfterMid: cursor,
  );

  // Forward connection-status transitions to the UI provider.
  ref.read(sseConnectionStatusProvider.notifier).set(SseStatus.connecting);

  // Track first event so we know when "connecting" → "connected".
  bool sawFirstEvent = false;

  await for (final event in client.events()) {
    if (!sawFirstEvent) {
      sawFirstEvent = true;
      ref.read(sseConnectionStatusProvider.notifier).set(SseStatus.connected);
    }
    yield event;
  }

  // Stream exhausted (consumer cancelled / provider rebuilding).
  ref.read(sseConnectionStatusProvider.notifier).set(SseStatus.disconnected);
}

/// Top-level (must be top-level for `compute`) parser dispatched to a
/// background isolate so JSON decoding never blocks the UI thread.
ChatEvent _parseSseEventInIsolate(List<String> args) {
  return parseSseEvent(args[0], args[1]);
}

/// Read the top-level `"type"` field from a raw SSE/WS JSON envelope.
///
/// Important: chat envelopes embed a `detail.type` ("normal", "reply",
/// "edit", …) BEFORE the outer `"type":"chat"` in the wire order, so a
/// naive "first match" regex picks the wrong one. We instead do a real
/// JSON decode for the discriminator — small price for correctness, and
/// the heavy decode still happens later inside the isolate.
String? _peekTypeField(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final t = decoded['type'];
      if (t is String) return t;
    }
  } catch (_) {}
  return null;
}
