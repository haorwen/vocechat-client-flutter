import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_api.dart';
import '../storage/account_store.dart';
import '../utils/app_log.dart';
import '../startup/app_startup.dart';

part 'fcm_service.g.dart';

// ---------------------------------------------------------------------------
// Pending chat navigation target
// ---------------------------------------------------------------------------

/// Set when the user taps a FCM notification. Format: `u-<uid>` for DMs,
/// `g-<gid>` for channels — matches GoRouter's `/home/chat/:id` parameter.
/// The router redirect reads and clears this on each evaluation.
final fcmPendingChatTargetProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// True only once [Firebase.initializeApp] has actually succeeded (see
/// main.dart, which swallows init failures so a CI build without real
/// credentials — or the checked-in firebase_options.dart placeholders —
/// doesn't crash the app). Every entry point into FirebaseMessaging must
/// check this first, since the plugin throws if no app was initialized.
bool get _firebaseReady => Firebase.apps.isNotEmpty;

final fcmMessagingProvider = Provider<FirebaseMessaging?>((ref) {
  if (!_isMobile ||
      !ref.watch(firebaseInitializedProvider) ||
      !_firebaseReady) {
    return null;
  }
  return FirebaseMessaging.instance;
});

/// Returns the FCM device token, or an empty string on non-mobile / failure.
/// Applies a 3-second timeout to avoid blocking login on slow Play Services.
Future<String> getFcmDeviceToken() async {
  if (!_isMobile || !_firebaseReady) return '';
  return _readDeviceToken(FirebaseMessaging.instance);
}

Future<String> _readDeviceToken(FirebaseMessaging messaging) async {
  try {
    return await (() async {
      // Apple registration is asynchronous. Calling getToken before APNs is
      // ready throws instead of waiting; the service must retry this later.
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        return '';
      }
      return await messaging.getToken() ?? '';
    })()
        .timeout(
      const Duration(seconds: 3),
      onTimeout: () => '',
    );
  } catch (_) {
    return '';
  }
}

@visibleForTesting
String? parseFcmChatTarget(Map<String, dynamic> data) {
  int? id(Object? value) {
    final parsed = value is int
        ? value
        : value is String
            ? int.tryParse(value)
            : null;
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  if (data.containsKey('vocechat_to_gid')) {
    final gid = id(data['vocechat_to_gid']);
    if (gid != null) return 'g-$gid';
  } else if (data.containsKey('vocechat_from_uid')) {
    final uid = id(data['vocechat_from_uid']);
    if (uid != null) return 'u-$uid';
  }
  return null;
}

// ---------------------------------------------------------------------------
// FcmService provider
// ---------------------------------------------------------------------------

/// Initialises Firebase Messaging on Android/iOS and wires up notification
/// tap handlers. keepAlive ensures listeners are never torn down for the app's
/// lifetime. No-op on all other platforms.
@Riverpod(keepAlive: true)
Future<void> fcmService(Ref ref) async {
  final messaging = ref.watch(fcmMessagingProvider);
  if (messaging == null) return;
  var disposed = false;
  var receivedWarmTap = false;
  var syncing = false;
  var syncAgain = false;
  String? refreshedToken;
  (String, String)? lastSynced;
  Timer? retry;
  bool foreground() => switch (WidgetsBinding.instance.lifecycleState) {
        AppLifecycleState.hidden ||
        AppLifecycleState.paused ||
        AppLifecycleState.detached =>
          false,
        _ => true,
      };

  String? authenticatedAccount() {
    final auth = ref.read(authControllerProvider);
    if (auth.isLoading || auth.valueOrNull is! AuthStateAuthenticated) {
      return null;
    }
    return ref.read(accountStoreProvider).valueOrNull?.currentAccountId;
  }

  void deliver(RemoteMessage message) {
    if (disposed) return;
    final target = parseFcmChatTarget(message.data);
    if (target != null) {
      ref.read(fcmPendingChatTargetProvider.notifier).state = target;
    }
  }

  Future<void> syncDeviceToken([String? refreshed]) async {
    if (disposed) return;
    if (refreshed != null) refreshedToken = refreshed;
    retry?.cancel();
    if (syncing) {
      syncAgain = true;
      return;
    }
    final accountId = authenticatedAccount();
    if (accountId == null) return;
    syncing = true;
    var succeeded = false;
    try {
      final api = ref.read(authApiProvider);
      final token = refreshedToken ?? await _readDeviceToken(messaging);
      if (disposed || token.isEmpty || authenticatedAccount() != accountId) {
        return;
      }
      if (lastSynced != (accountId, token)) {
        await api.updateDeviceToken(token);
        if (!disposed && authenticatedAccount() == accountId) {
          lastSynced = (accountId, token);
        }
      }
      succeeded = true;
    } catch (error) {
      AppLog.w(LogTag.general, () => 'FCM token sync deferred: $error');
    } finally {
      syncing = false;
      if (!disposed) {
        if (syncAgain) {
          syncAgain = false;
          unawaited(syncDeviceToken());
        } else if (!succeeded &&
            foreground() &&
            authenticatedAccount() != null) {
          // Includes APNs-not-ready, token timeouts, and failed server writes.
          // Retry until acknowledged; onTokenRefresh alone is insufficient
          // when a cached token stays unchanged after an app update.
          retry = Timer(const Duration(seconds: 10), syncDeviceToken);
        }
      }
    }
  }

  // App was in the *background*; user tapped the notification.
  final backgroundSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
    receivedWarmTap = true;
    deliver(message);
  });

  // WebSocket handles message data; iOS presentation options below let the
  // system also show the alert and play its sound while the app is open.
  final foregroundSub = FirebaseMessaging.onMessage.listen((message) {
    AppLog.d(LogTag.general, () => '📲 FCM foreground: ${message.data}');
  });
  final tokenSub = messaging.onTokenRefresh.listen(
    (token) => unawaited(syncDeviceToken(token)),
    onError: (Object error) =>
        AppLog.w(LogTag.general, () => 'FCM token refresh unavailable: $error'),
  );
  // Firebase may initialize after an existing session has already restored.
  ref.listen(authControllerProvider, (_, next) {
    lastSynced = null;
    if (!next.isLoading && next.valueOrNull is AuthStateAuthenticated) {
      unawaited(syncDeviceToken());
    } else {
      retry?.cancel();
    }
  }, fireImmediately: true);
  ref.listen(
      accountStoreProvider.select((s) => s.valueOrNull?.currentAccountId),
      (_, __) {
    lastSynced = null;
    unawaited(syncDeviceToken());
  });

  final lifecycle = AppLifecycleListener(
    onResume: () {
      lastSynced = null;
      refreshedToken = null;
      unawaited(syncDeviceToken());
    },
    onHide: () => retry?.cancel(),
    onPause: () => retry?.cancel(),
  );

  ref.onDispose(() {
    disposed = true;
    retry?.cancel();
    lifecycle.dispose();
    backgroundSub.cancel();
    foregroundSub.cancel();
    tokenSub.cancel();
  });

  // Permission UI or slow Play Services must not delay tap subscriptions.
  unawaited(messaging
      .requestPermission(
    alert: true,
    badge: true,
    sound: true,
  )
      .then<void>((_) {
    if (!disposed) unawaited(syncDeviceToken());
  }, onError: (Object error, StackTrace stackTrace) {
    AppLog.w(
        LogTag.general, () => 'FCM permission request unavailable: $error');
  }));
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    unawaited(messaging
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    )
        .catchError((Object error) {
      AppLog.w(
          LogTag.general, () => 'FCM foreground alerts unavailable: $error');
    }));
  }
  try {
    final initial = await messaging.getInitialMessage();
    if (initial != null && !receivedWarmTap) deliver(initial);
  } catch (error) {
    AppLog.w(
        LogTag.general, () => 'FCM initial notification unavailable: $error');
  }
}
