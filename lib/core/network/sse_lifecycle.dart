import '../background/background_lifecycle.dart';
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'sse_client.dart';
import 'resume_reconnect_observer.dart';
import '../storage/account_store.dart';
import '../storage/secure_token_store.dart';
import '../utils/app_log.dart';
import '../../features/auth/application/auth_controller.dart';

part 'sse_lifecycle.g.dart';

final connectivityChangesProvider = Provider<Stream<List<ConnectivityResult>>>(
  (ref) => Connectivity().onConnectivityChanged,
);

int? _authenticatedUid(AsyncValue<AuthState> value) {
  final auth = value.valueOrNull;
  return auth is AuthStateAuthenticated ? auth.user.uid : null;
}

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
  int _generation = 0;

  @override
  void build() {
    ref.onDispose(_stop);

    if (ref.watch(androidBackgroundedProvider)) {
      _stop();
      return;
    }

    // React to login/logout and account switch by restarting the poll loop
    // against the right token-store key.
    final uid = ref.watch(authControllerProvider.select(_authenticatedUid));
    if (uid == null) {
      _stop();
      return;
    }
    final accountId = ref.watch(accountStoreProvider.select(
      (value) => value.valueOrNull?.currentAccountId,
    ));
    if (accountId == null) {
      _stop();
      return;
    }

    _start(accountId);
  }

  void _start(String accountId) {
    _stop();
    final generation = _generation;
    final tokenStore = ref.read(secureTokenStoreProvider(accountId));
    Future<TokenData?> readTokens() async {
      try {
        return await tokenStore
            .readTokens()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        // A locked iOS Keychain can recover on the next poll after unlock.
        AppLog.d(LogTag.token, () => 'token polling deferred: $e');
        return null;
      }
    }

    // Seed the baseline so we don't trip an invalidate on first tick.
    Future<void> seed() async {
      final t = await readTokens();
      if (generation != _generation) return;
      _lastAccess = t?.accessToken;
      _lastExpiresAt = t?.expiresAt;
    }

    seed();
    var polling = false;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (polling) return;
      polling = true;
      final t = await readTokens();
      polling = false;
      if (generation != _generation || t == null) return;
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
    _generation++;
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
  Set<ConnectivityResult>? _interfaces;

  @override
  void build() {
    ref.onDispose(_stop);

    final uid = ref.watch(authControllerProvider.select(_authenticatedUid));
    if (uid == null) {
      _stop();
      return;
    }

    _start();
  }

  void _start() {
    _stop();
    _sub = ref.read(connectivityChangesProvider).listen((results) {
      // results is a list because devices can have multiple active
      // interfaces (e.g. WiFi + cellular). "online" = anything except `none`.
      final interfaces =
          results.where((r) => r != ConnectivityResult.none).toSet();
      final previous = _interfaces;
      _interfaces = interfaces;
      final online = interfaces.isNotEmpty;
      if (!online) {
        AppLog.w(LogTag.sse, () => '📵 connectivity lost');
        _wasOffline = true;
        ref
            .read(sseConnectionStatusProvider.notifier)
            .set(SseStatus.disconnected);
        return;
      }
      // Wi-Fi -> cellular can arrive without an intermediate `none` event.
      // The old socket still belongs to the previous network in that case.
      final changed = previous != null &&
          (previous.length != interfaces.length ||
              !previous.containsAll(interfaces));
      if (_wasOffline || changed) {
        AppLog.w(
            LogTag.sse, () => '📶 connectivity restored → reconnecting SSE');
        _wasOffline = false;
        ref
            .read(sseConnectionStatusProvider.notifier)
            .set(SseStatus.reconnecting);
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
  ResumeReconnectObserver? _observer;

  @override
  void build() {
    ref.onDispose(_stop);

    final uid = ref.watch(authControllerProvider.select(_authenticatedUid));
    if (uid == null) {
      _stop();
      return;
    }

    _start();
  }

  void _start() {
    _stop();
    _observer = ResumeReconnectObserver(
      initialState: WidgetsBinding.instance.lifecycleState,
      onReconnect: () {
        AppLog.w(LogTag.sse,
            () => '⏰ app resumed after long pause → reconnecting SSE');
        ref
            .read(sseConnectionStatusProvider.notifier)
            .set(SseStatus.reconnecting);
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
