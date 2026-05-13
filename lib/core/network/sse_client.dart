import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_token_store.dart';
import '../storage/server_store.dart';
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

  /// Returns a broadcast [Stream<ChatEvent>] with auto-reconnect.
  Stream<ChatEvent> events() {
    final controller = StreamController<ChatEvent>.broadcast(
      onCancel: () => _cleanup(),
    );
    _connect(controller, const Duration(seconds: 1));
    return controller.stream;
  }

  Future<void> _connect(
      StreamController<ChatEvent> controller, Duration currentDelay) async {
    if (controller.isClosed) return;

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
    } catch (_) {
      _scheduleReconnect(controller, currentDelay);
      return;
    }
    _socket = socket;

    bool firstFrame = true;
    _sub = socket.listen(
      (frame) async {
        if (controller.isClosed) return;
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
      onError: (_) => _scheduleReconnect(controller, currentDelay),
      onDone: () => _scheduleReconnect(controller, currentDelay),
      cancelOnError: false,
    );
  }

  void _scheduleReconnect(
      StreamController<ChatEvent> controller, Duration delay) {
    if (controller.isClosed) return;
    _cleanup();
    Future.delayed(delay, () {
      final nextDelay = delay * 2;
      final capped = nextDelay > _maxBackoff ? _maxBackoff : nextDelay;
      _connect(controller, capped);
    });
  }

  void _cleanup() {
    _sub?.cancel();
    _sub = null;
    _socket?.close().catchError((_) {});
    _socket = null;
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

@riverpod
Stream<ChatEvent> sseEvents(Ref ref) async* {
  // Only stream when authenticated
  final authState = await ref.watch(authControllerProvider.future);

  if (authState is! AuthStateAuthenticated) return;

  final serverState = ref.read(serverStoreProvider).valueOrNull;
  final serverId = serverState?.currentServerId;
  if (serverId == null) return;

  final currentServer =
      serverState!.servers.where((s) => s.id == serverId).firstOrNull;
  if (currentServer == null) return;

  final tokenStore = ref.read(secureTokenStoreProvider(serverId));
  final tokens = await tokenStore.readTokens();
  if (tokens == null) return;

  // Resume from the highest mid we've ever persisted so the server only
  // replays the delta on (re)connect — incremental message fetch.
  final cache = await ref.read(messageCacheProvider.future);
  final cursor = await cache.getCursor();

  final client = VoceSseClient(
    baseUrl: currentServer.baseUrl,
    apiKey: tokens.accessToken,
    initialAfterMid: cursor,
  );

  yield* client.events();
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
