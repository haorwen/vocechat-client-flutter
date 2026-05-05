import 'dart:async';

import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_token_store.dart';
import '../storage/server_store.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/messages/domain/message_models.dart';

part 'sse_client.g.dart';

// ---------------------------------------------------------------------------
// VoceSseClient
// ---------------------------------------------------------------------------

class VoceSseClient {
  VoceSseClient({
    required this.baseUrl,
    required this.apiKey,
  });

  final String baseUrl;
  final String apiKey;

  static const Duration _maxBackoff = Duration(seconds: 30);

  /// Returns a broadcast [Stream<ChatEvent>] with auto-reconnect.
  Stream<ChatEvent> events() {
    final controller = StreamController<ChatEvent>.broadcast();
    _connect(controller, const Duration(seconds: 1));
    return controller.stream;
  }

  void _connect(
      StreamController<ChatEvent> controller, Duration currentDelay) {
    if (controller.isClosed) return;

    final url = '$baseUrl/api/user/events';

    final sseStream = SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: url,
      header: {
        'X-API-Key': apiKey,
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      },
    );

    sseStream.listen(
      (sseEvent) {
        if (controller.isClosed) return;
        final eventType = (sseEvent.event ?? '').trim();
        final rawData = (sseEvent.data ?? '').trim();
        final chatEvent = parseSseEvent(eventType, rawData);
        controller.add(chatEvent);
      },
      onError: (_) {
        // Auto-reconnect with exponential backoff
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

  final client = VoceSseClient(
    baseUrl: currentServer.baseUrl,
    apiKey: tokens.accessToken,
  );

  yield* client.events();
}
