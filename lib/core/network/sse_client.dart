import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
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

  /// Returns a broadcast [Stream<ChatEvent>] with auto-reconnect.
  Stream<ChatEvent> events() {
    final controller = StreamController<ChatEvent>.broadcast();
    _connect(controller, const Duration(seconds: 1));
    return controller.stream;
  }

  void _connect(
      StreamController<ChatEvent> controller, Duration currentDelay) {
    if (controller.isClosed) return;

    final encodedKey = Uri.encodeComponent(apiKey);
    final query = StringBuffer('api-key=$encodedKey');
    if (_highWaterMid != null) {
      query.write('&after_mid=${_highWaterMid!}');
    }
    final url = '$baseUrl/api/user/events?$query';

    final sseStream = SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: url,
      header: {
        'X-API-Key': apiKey,
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      },
    );

    bool firstEvent = true;
    sseStream.listen(
      (sseEvent) async {
        if (controller.isClosed) return;
        final eventType = (sseEvent.event ?? '').trim();
        final rawData = (sseEvent.data ?? '').trim();

        // Heartbeats / ready / kick are tiny — parse on-thread to avoid the
        // isolate hop overhead. Everything else (notably chat / users_snapshot
        // with potentially heavy JSON) goes to a background isolate so the UI
        // thread stays free.
        ChatEvent chatEvent;
        if (eventType == 'ready' ||
            eventType == 'heartbeat' ||
            eventType == 'kick') {
          chatEvent = parseSseEvent(eventType, rawData);
        } else {
          try {
            chatEvent = await compute(
              _parseSseEventInIsolate,
              [eventType, rawData],
              debugLabel: 'parseSseEvent',
            );
          } catch (_) {
            chatEvent = ChatEvent.unknown(type: eventType, raw: rawData);
          }
          if (controller.isClosed) return;
        }

        if (chatEvent is ChatEventChat) {
          final mid = chatEvent.message.mid;
          if (mid > 0 && (_highWaterMid == null || mid > _highWaterMid!)) {
            _highWaterMid = mid;
          }
        }
        if (firstEvent) {
          firstEvent = false;
          currentDelay = const Duration(seconds: 1);
        }
        controller.add(chatEvent);
      },
      onError: (_) {
        _scheduleReconnect(controller, currentDelay);
      },
      onDone: () {
        _scheduleReconnect(controller, currentDelay);
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect(
      StreamController<ChatEvent> controller, Duration delay) {
    if (controller.isClosed) return;
    Future.delayed(delay, () {
      final nextDelay = delay * 2;
      final capped =
          nextDelay > _maxBackoff ? _maxBackoff : nextDelay;
      _connect(controller, capped);
    });
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

@riverpod
Stream<ChatEvent> sseEvents(Ref ref) async* {
  // Only stream when authenticated
  final authState =
      await ref.watch(authControllerProvider.future);

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
