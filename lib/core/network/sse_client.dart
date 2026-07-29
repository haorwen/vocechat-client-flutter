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
  })  : _apiKey = apiKey,
        _highWaterMid = initialAfterMid;

  final String baseUrl;

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

    // Capture the generation this attempt belongs to. _cleanup() bumps
    // _generation, so any callback below that fires after a teardown sees a
    // mismatch and bails — no stale reconnect chains.
    final myGen = _generation;
    bool isStale() =>
        _disposed || controller.isClosed || myGen != _generation;

    // Renew the access token before every (re)connect so reconnects after
    // expiry don't loop with a stale key. A null return means "keep current".
    if (refreshToken != null) {
      final fresh = await refreshToken!();
      if (isStale()) return;
      if (fresh != null && fresh.isNotEmpty) {
        _apiKey = fresh;
      }
    }

    final encodedKey = Uri.encodeComponent(_apiKey);
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
      // `.timeout` is the critical guard: a silently-dropped idle link makes
      // the handshake hang indefinitely (no default connect timeout). Bound
      // it so the hang becomes a normal "connect failed → backoff" instead of
      // a permanent dead stream.
      socket = await WebSocket.connect(
        url,
        headers: {'X-API-Key': _apiKey},
      ).timeout(_kConnectTimeout);
    } catch (e) {
      AppLog.w(LogTag.sse, () => '⚠️ SSE connect failed: $e');
      if (isStale()) return;
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

    bool firstFrame = true;
    _armWatchdog(controller);
    _sub = socket.listen(
      (frame) async {
        if (isStale()) return;
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
          if (isStale()) return;
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
    // Invalidate the current generation so any in-flight connect attempt and
    // any still-queued onDone/onError/listen callback from the socket we're
    // tearing down become no-ops (see isStale() in _connect).
    _generation++;
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

  // Watching accountStore makes the provider rebuild on account switch (same
  // or different server); watching serverStore makes it rebuild on server
  // switch too, since that's what resolves currentServer's baseUrl.
  final accountState = await ref.watch(accountStoreProvider.future);
  final accountId = accountState.currentAccountId;
  if (accountId == null) return;
  final serverState = await ref.watch(serverStoreProvider.future);
  final account =
      accountState.accounts.where((a) => a.accountId == accountId).firstOrNull;
  if (account == null) return;
  final currentServer =
      serverState.servers.where((s) => s.id == account.serverId).firstOrNull;
  if (currentServer == null) return;

  // Token. We READ rather than WATCH here because the token store doesn't
  // expose a stream; instead we manually invalidate this provider when a
  // refresh happens (see SseTokenWatcher below).
  final tokenStore = ref.read(secureTokenStoreProvider(accountId));
  final tokens = await tokenStore.readTokens();
  if (tokens == null) return;

  final cache = await ref.read(messageCacheProvider.future);
  final cursor = await cache.getCursor();

  // Callback invoked at the start of every (re)connect. Re-reads the current
  // token and proactively renews it if it is within 30s of expiry — mirroring
  // web `useStreaming.ts`'s per-connect renew. Returning null tells the client
  // to keep its existing key and proceed (preserves backoff/retry behaviour).
  Future<String?> tokenRefreshCallback() async {
    final store = ref.read(secureTokenStoreProvider(accountId));
    final current = await store.readTokens();
    if (current == null) return null;
    final aboutToExpire =
        current.expiresAt.isBefore(DateTime.now().add(const Duration(seconds: 30)));
    if (aboutToExpire) {
      AppLog.w(LogTag.sse, () => '🔑 SSE: token within 30s of expiry, renewing before connect');
      final renewed =
          await ref.read(authControllerProvider.notifier).renewIfPossible();
      if (!renewed) {
        AppLog.w(LogTag.sse, () => '🔑 SSE: token renew failed, proceeding with current key');
        return null;
      }
      final fresh = await store.readTokens();
      return fresh?.accessToken;
    }
    return current.accessToken;
  }

  final client = VoceSseClient(
    baseUrl: currentServer.baseUrl,
    apiKey: tokens.accessToken,
    initialAfterMid: cursor,
    refreshToken: tokenRefreshCallback,
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
