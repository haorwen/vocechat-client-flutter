import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'sse_client.dart';
import '../storage/secure_token_store.dart';
import '../storage/server_store.dart';
import '../utils/app_log.dart';
import '../../features/auth/application/auth_controller.dart';

part 'sse_lifecycle.g.dart';

/// Reconnect the SSE stream when the device comes back online or the app
/// resumes after being backgrounded longer than this. Mirrors the web
/// reference's 1-day visibility threshold but tightened — mobile sockets
/// die in minutes, not days.
const Duration _kForceReconnectAfterBackground = Duration(minutes: 2);

// ---------------------------------------------------------------------------
// SSE token watcher
// ---------------------------------------------------------------------------
//
// dio's auth interceptor refreshes the access token transparently and writes
// it to [SecureTokenStore], but the SSE WebSocket is a long-lived connection
// that captured the OLD token at handshake time. When the server eventually
// rotates the key and rejects the old one, we'd see the socket die and
// reconnect — but on the SAME stale token, looping forever.
//
// This watcher polls the access-token cipher and `expiresAt` for the current
// server every 30s. When either changes (refresh just landed), it
// invalidates [sseEventsProvider] so Riverpod tears down the old WebSocket
// and re-runs the async generator — which reads the fresh token from the
// store and opens a new connection.
//
// Polling instead of streaming because [SecureTokenStore] doesn't expose a
// change-stream and adding one would touch a lot of surface area. A 30s
// poll is cheap (single Keychain/SharedPrefs read) and doesn't keep the
// device awake.

@Riverpod(keepAlive: true)
class SseTokenWatcher extends _$SseTokenWatcher {
  Timer? _timer;
  String? _lastAccess;
  DateTime? _lastExpiresAt;

  @override
  void build() {
    ref.onDispose(_stop);

    // React to login/logout and server switch by restarting the poll loop
    // against the right token-store key.
    final authState = ref.watch(authControllerProvider).valueOrNull;
    if (authState is! AuthStateAuthenticated) {
      _stop();
      return;
    }
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final serverId = serverState?.currentServerId;
    if (serverId == null) {
      _stop();
      return;
    }

    _start(serverId);
  }

  void _start(String serverId) {
    _stop();
    final tokenStore = ref.read(secureTokenStoreProvider(serverId));
    // Seed the baseline so we don't trip an invalidate on first tick.
    Future<void> seed() async {
      final t = await tokenStore.readTokens();
      _lastAccess = t?.accessToken;
      _lastExpiresAt = t?.expiresAt;
    }
    seed();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final t = await tokenStore.readTokens();
      if (t == null) return;
      if (t.accessToken != _lastAccess ||
          (_lastExpiresAt != null && t.expiresAt != _lastExpiresAt)) {
        AppLog.w(LogTag.sse,
            () => '🔑 SSE token changed → invalidating sseEventsProvider');
        _lastAccess = t.accessToken;
        _lastExpiresAt = t.expiresAt;
        ref.invalidate(sseEventsProvider);
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lastAccess = null;
    _lastExpiresAt = null;
  }
}

// ---------------------------------------------------------------------------
// SSE connectivity watcher — reconnect on network state change
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class SseConnectivityWatcher extends _$SseConnectivityWatcher {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOffline = false;

  @override
  void build() {
    ref.onDispose(_stop);

    final authState = ref.watch(authControllerProvider).valueOrNull;
    if (authState is! AuthStateAuthenticated) {
      _stop();
      return;
    }

    _start();
  }

  void _start() {
    _stop();
    final connectivity = Connectivity();
    _sub = connectivity.onConnectivityChanged.listen((results) {
      // results is a list because devices can have multiple active
      // interfaces (e.g. WiFi + cellular). "online" = anything except `none`.
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online) {
        AppLog.w(LogTag.sse, () => '📵 connectivity lost');
        _wasOffline = true;
        ref.read(sseConnectionStatusProvider.notifier).set(SseStatus.disconnected);
        return;
      }
      if (_wasOffline) {
        AppLog.w(LogTag.sse,
            () => '📶 connectivity restored → reconnecting SSE');
        _wasOffline = false;
        ref.read(sseConnectionStatusProvider.notifier).set(SseStatus.reconnecting);
        ref.invalidate(sseEventsProvider);
      }
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }
}

// ---------------------------------------------------------------------------
// SSE app-lifecycle watcher — reconnect on long background → foreground
// ---------------------------------------------------------------------------
//
// The OS aggressively suspends background apps; the WebSocket can be killed
// without any onError/onDone firing until the app resumes. Force a reconnect
// when we come back from a long pause.

@Riverpod(keepAlive: true)
class SseLifecycleWatcher extends _$SseLifecycleWatcher {
  _LifecycleObserver? _observer;

  @override
  void build() {
    ref.onDispose(_stop);

    final authState = ref.watch(authControllerProvider).valueOrNull;
    if (authState is! AuthStateAuthenticated) {
      _stop();
      return;
    }

    _start();
  }

  void _start() {
    _stop();
    _observer = _LifecycleObserver(
      onResumeAfterLongPause: () {
        AppLog.w(LogTag.sse,
            () => '⏰ app resumed after long pause → reconnecting SSE');
        ref.read(sseConnectionStatusProvider.notifier).set(SseStatus.reconnecting);
        ref.invalidate(sseEventsProvider);
      },
    );
    WidgetsBinding.instance.addObserver(_observer!);
  }

  void _stop() {
    final obs = _observer;
    if (obs != null) {
      WidgetsBinding.instance.removeObserver(obs);
    }
    _observer = null;
  }
}

class _LifecycleObserver with WidgetsBindingObserver {
  _LifecycleObserver({required this.onResumeAfterLongPause});

  final VoidCallback onResumeAfterLongPause;

  DateTime? _pausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _pausedAt = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final pausedAt = _pausedAt;
        _pausedAt = null;
        if (pausedAt == null) return;
        final elapsed = DateTime.now().difference(pausedAt);
        if (elapsed >= _kForceReconnectAfterBackground) {
          onResumeAfterLongPause();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
