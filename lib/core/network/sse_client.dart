import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/account_store.dart';
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

/// Hard cap on a single `WebSocket.connect` handshake. On a silently-dropped
/// idle link (NAT/firewall reaped the TCP flow without an RST) the SYN of a
/// reconnect goes nowhere and the handshake hangs *forever* — there is no
/// default timeout on `WebSocket.connect`. Without this, a watchdog-driven
/// reconnect can deadlock the whole stream: the old socket never errored, the
/// new one never completes, and no further reconnect is ever scheduled. This
/// timeout converts that hang into a normal "connect failed → backoff retry".
const Duration _kConnectTimeout = Duration(seconds: 15);

class VoceSseClient {
  VoceSseClient({
    required this.baseUrl,
    required String apiKey,
    int? initialAfterMid,
    this.refreshToken,
    this.preferInlineParsing,
    this.onStatus,
  })  : _apiKey = apiKey,
        _highWaterMid = initialAfterMid;

  final String baseUrl;
  final void Function(SseStatus)? onStatus;

  /// Small background messages do not need a new isolate for each event.
  final bool Function()? preferInlineParsing;

  /// Called at the start of every (re)connect attempt. If it returns a
  /// non-null, non-empty string the returned value replaces [_apiKey] before
  /// the WebSocket URL is built. Returning null means "no change / renew
  /// failed; continue with current key".
  final Future<String?> Function()? refreshToken;

  /// The access token used in the WebSocket query string and header. Mutated
  /// by [refreshToken] on every connect so reconnects always use a fresh key.
  String _apiKey;

  static const Duration _maxBackoff = Duration(seconds: 30);

  /// Highest message id observed so far. Sent as `after_mid` on every
  /// (re)connect so the server replays anything we missed during a gap.
  int? _highWaterMid;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;

  /// Dead-man's-switch: if no event arrives within [_kSseWatchdog] we
  /// assume the link is dead and force a reconnect.
  Timer? _watchdog;
  Timer? _reconnectTimer;
  StreamController<ChatEvent>? _controller;
  Future<String?>? _tokenRefreshTask;

  /// Monotonic connection generation. Bumped on every [_cleanup]. Each
  /// connect attempt captures the generation it was started under; any
  /// callback (onDone/onError/listen/connect-completion) that fires for a
  /// stale generation is ignored. This is what prevents a torn-down socket's
  /// late `onDone` from racing the watchdog's fresh reconnect and spawning a
  /// second, competing reconnect chain (two sockets, two watchdogs clobbering
  /// each other's fields).
  int _generation = 0;

  /// Set when the consumer (provider dispose) tears us down explicitly —
  /// suppresses any in-flight reconnect schedules.
  bool _disposed = false;

  /// Returns a broadcast [Stream<ChatEvent>] with auto-reconnect.
  Stream<ChatEvent> events() {
    final controller = StreamController<ChatEvent>.broadcast(
      onCancel: dispose,
    );
    _controller = controller;
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

    // Capture the generation this attempt belongs to. _cleanup() bumps
    // _generation, so any callback below that fires after a teardown sees a
    // mismatch and bails — no stale reconnect chains.
    final myGen = _generation;
    bool isStale() => _disposed || controller.isClosed || myGen != _generation;

    onStatus?.call(SseStatus.connecting);
    WebSocket socket;
    try {
      // Credential storage and renewal can fail or hang too. They must share
      // the handshake's retry path, rather than silently ending the stream.
      if (refreshToken != null) {
        final task = _tokenRefreshTask ??= Future<String?>.sync(refreshToken!)
            .whenComplete(() => _tokenRefreshTask = null);
        final fresh = await task.timeout(_kConnectTimeout);
        if (isStale()) return;
        if (fresh != null && fresh.isNotEmpty) _apiKey = fresh;
      }

      final query = StringBuffer('api-key=${Uri.encodeComponent(_apiKey)}');
      if (_highWaterMid != null) query.write('&after_mid=$_highWaterMid');
      final wsBase = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final pending = WebSocket.connect(
        '$wsBase/api/user/events_ws?$query',
        headers: {'X-API-Key': _apiKey},
      );
      socket = await pending.timeout(_kConnectTimeout, onTimeout: () {
        // Future.timeout cannot cancel a handshake. Close a late connection
        // so it cannot survive as another session for the same device.
        unawaited(pending.then<void>((late) async {
          await late.close();
        }).catchError((Object _) {}));
        throw TimeoutException('WebSocket handshake timed out');
      });
    } catch (e) {
      if (isStale()) return;
      AppLog.w(LogTag.sse, () => 'SSE connection preparation failed: $e');
      _scheduleReconnect(controller, currentDelay);
      return;
    }

    // We may have been torn down (dispose / connectivity invalidate / a newer
    // reconnect) while awaiting the handshake. If so, this socket is an
    // orphan: close it and bail without wiring listeners or touching shared
    // fields, otherwise it would clobber the live connection's _socket/_sub.
    if (isStale()) {
      socket.close().catchError((_) {});
      return;
    }

    // WebSocket-protocol-level ping. Lower-cost than the business-layer
    // watchdog but doesn't catch app-layer hangs — both work together.
    socket.pingInterval = const Duration(seconds: 30);
    _socket = socket;
    controller.add(const ChatEvent.connectionOpened());

    bool firstFrame = true;
    Future<void> frames = Future.value();
    _armWatchdog(controller);
    _sub = socket.listen(
      (frame) {
        if (isStale()) return;
        // Any frame at all means the link is alive. Reset the watchdog.
        _armWatchdog(controller);
        // Decode frames in wire order. Independent compute() calls can finish
        // out of order and apply a snapshot before its privacy configuration.
        frames = frames.then((_) async {
          if (isStale()) return;
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
              if (trimmed.length <= 16384 &&
                  (preferInlineParsing?.call() ?? true)) {
                chatEvent = parseSseEvent(eventType, trimmed);
              } else {
                chatEvent = await compute(
                  _parseSseEventInIsolate,
                  [eventType, trimmed],
                  debugLabel: 'parseSseEvent',
                ).timeout(_kSseWatchdog);
              }
            } on TimeoutException {
              // A stalled worker must not block every later chat/heartbeat.
              chatEvent = parseSseEvent(eventType, trimmed);
            } catch (_) {
              chatEvent = ChatEvent.unknown(type: eventType, raw: trimmed);
            }
            if (isStale()) return;
          }

          if (chatEvent is ChatEventChat) {
            final mid = chatEvent.message.mid;
            if (mid > 0 && (_highWaterMid == null || mid > _highWaterMid!)) {
              _highWaterMid = mid;
            }
          }
          if (chatEvent is ChatEventReady) onStatus?.call(SseStatus.connected);
          controller.add(chatEvent);
        }).catchError((Object e) {
          AppLog.w(LogTag.sse, () => 'SSE frame failed: $e');
        });
      },
      onError: (e) {
        AppLog.w(LogTag.sse, () => '⚠️ SSE socket error: $e');
        if (isStale()) return;
        _scheduleReconnect(controller, currentDelay);
      },
      onDone: () {
        AppLog.w(LogTag.sse, () => '🔌 SSE socket closed');
        if (isStale()) return;
        _scheduleReconnect(controller, currentDelay);
      },
      cancelOnError: false,
    );
  }

  void _armWatchdog(StreamController<ChatEvent> controller) {
    _watchdog?.cancel();
    _watchdog = Timer(_kSseWatchdog, () {
      AppLog.w(
          LogTag.sse,
          () =>
              '⏱️ SSE watchdog fired — no events for ${_kSseWatchdog.inSeconds}s, reconnecting');
      _cleanup();
      // Reset backoff: this is a heartbeat-miss, not a hard error.
      _connect(controller, const Duration(seconds: 1));
    });
  }

  void _scheduleReconnect(
      StreamController<ChatEvent> controller, Duration delay) {
    if (_disposed || controller.isClosed) return;
    _cleanup();
    onStatus?.call(SseStatus.reconnecting);
    final generation = _generation;
    _reconnectTimer = Timer(delay, () {
      if (_disposed || controller.isClosed || generation != _generation) return;
      final nextDelay = delay * 2;
      final capped = nextDelay > _maxBackoff ? _maxBackoff : nextDelay;
      _connect(controller, capped);
    });
  }

  /// Explicit teardown is required on provider rebuild. Cancelling an async*
  /// wrapper alone can wait forever for the next frame on a dead connection.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cleanup();
    unawaited(_controller?.close());
  }

  void _cleanup() {
    // Invalidate the current generation so any in-flight connect attempt and
    // any still-queued onDone/onError/listen callback from the socket we're
    // tearing down become no-ops (see isStale() in _connect).
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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
Stream<ChatEvent> sseEvents(Ref ref) {
  // Profile/privacy updates must not reopen the connection.
  final uid = ref.watch(authControllerProvider.select((value) {
    final auth = value.valueOrNull;
    return auth is AuthStateAuthenticated ? auth.user.uid : null;
  }));
  final accountId = ref.watch(accountStoreProvider.select(
    (value) => value.valueOrNull?.currentAccountId,
  ));
  final baseUrl = ref.watch(serverStoreProvider.select((value) {
    final servers = value.valueOrNull;
    return servers?.servers
        .where((s) => s.id == servers.currentServerId)
        .firstOrNull
        ?.baseUrl;
  }));
  if (uid == null || accountId == null || baseUrl == null) {
    return const Stream.empty();
  }

  final events = StreamController<ChatEvent>();
  final store = ref.read(secureTokenStoreProvider(accountId));
  VoceSseClient? client;
  StreamSubscription<ChatEvent>? subscription;
  Timer? retry;
  var disposed = false;
  var retryDelay = const Duration(seconds: 1);
  ref.onDispose(() {
    disposed = true;
    retry?.cancel();
    client?.dispose();
    unawaited(subscription?.cancel());
    unawaited(events.close());
  });

  void setStatus(SseStatus status) {
    if (!disposed) ref.read(sseConnectionStatusProvider.notifier).set(status);
  }

  Future<String?> refreshToken() async {
    final current = await store.readTokens();
    if (disposed) return null;
    if (current == null) throw StateError('Session credentials unavailable');
    if (current.expiresAt
        .isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      final renewed =
          await ref.read(authControllerProvider.notifier).renewIfPossible();
      if (disposed) return null;
      if (renewed) return (await store.readTokens())?.accessToken;
    }
    return current.accessToken;
  }

  Future<void> start() async {
    if (disposed) return;
    setStatus(SseStatus.connecting);
    try {
      // Failures before creating the transport used to terminate this provider
      // permanently. Retry preparation even when the token itself is unchanged.
      final tokens = await store.readTokens().timeout(_kConnectTimeout);
      if (disposed) return;
      if (tokens == null) throw StateError('Session credentials unavailable');
      if (ref.read(messageCacheProvider).hasError) {
        ref.invalidate(messageCacheProvider);
      }
      final cache =
          await ref.read(messageCacheProvider.future).timeout(_kConnectTimeout);
      if (disposed) return;
      final cursor = await cache.getCursor().timeout(_kConnectTimeout);
      if (disposed) return;
      client = VoceSseClient(
        baseUrl: baseUrl,
        apiKey: tokens.accessToken,
        initialAfterMid: cursor,
        refreshToken: refreshToken,
        onStatus: setStatus,
      );
      subscription = client!.events().listen((event) {
        if (!disposed) events.add(event);
      });
    } catch (error) {
      if (disposed) return;
      AppLog.w(LogTag.sse, () => 'SSE initialization will retry: $error');
      setStatus(SseStatus.reconnecting);
      retry = Timer(retryDelay, start);
      retryDelay = Duration(seconds: (retryDelay.inSeconds * 2).clamp(1, 30));
    }
  }

  unawaited(Future<void>.microtask(start));
  return events.stream;
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
