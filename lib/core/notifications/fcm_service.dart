import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

/// Returns the FCM device token, or an empty string on non-mobile / failure.
/// Applies a 3-second timeout to avoid blocking login on slow Play Services.
Future<String> getFcmDeviceToken() async {
  if (!_isMobile || !_firebaseReady) return '';
  try {
    final completer = Completer<String>();
    FirebaseMessaging.instance.getToken().then((t) {
      if (!completer.isCompleted) completer.complete(t ?? '');
    }).catchError((Object _) {
      if (!completer.isCompleted) completer.complete('');
    });
    return await completer.future.timeout(
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
  if (!_isMobile ||
      !ref.watch(firebaseInitializedProvider) ||
      !_firebaseReady) {
    return;
  }
  var disposed = false;
  var receivedWarmTap = false;
  void deliver(RemoteMessage message) {
    if (disposed) return;
    final target = parseFcmChatTarget(message.data);
    if (target != null) {
      ref.read(fcmPendingChatTargetProvider.notifier).state = target;
    }
  }

  Future<void> syncDeviceToken([String? refreshed]) async {
    try {
      if (disposed ||
          ref.read(authControllerProvider).isLoading ||
          ref.read(authControllerProvider).valueOrNull
              is! AuthStateAuthenticated) {
        return;
      }
      final accountId =
          ref.read(accountStoreProvider).valueOrNull?.currentAccountId;
      if (accountId == null) return;
      final api = ref.read(authApiProvider);
      final token = refreshed ?? await getFcmDeviceToken();
      if (disposed ||
          token.isEmpty ||
          ref.read(authControllerProvider).isLoading ||
          ref.read(accountStoreProvider).valueOrNull?.currentAccountId !=
              accountId ||
          ref.read(authControllerProvider).valueOrNull
              is! AuthStateAuthenticated) {
        return;
      }
      await api.updateDeviceToken(token);
    } catch (error) {
      AppLog.w(LogTag.general, () => 'FCM token sync deferred: $error');
    }
  }

  // App was in the *background*; user tapped the notification.
  final backgroundSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
    receivedWarmTap = true;
    deliver(message);
  });

  // Foreground messages — the SSE stream already delivers the payload, so we
  // only log here. Add local-notification display if needed in the future.
  final foregroundSub = FirebaseMessaging.onMessage.listen((message) {
    AppLog.d(LogTag.general, () => '📲 FCM foreground: ${message.data}');
  });
  final tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(
    (token) => unawaited(syncDeviceToken(token)),
    onError: (Object error) =>
        AppLog.w(LogTag.general, () => 'FCM token refresh unavailable: $error'),
  );
  // Firebase may initialize after an existing session has already restored.
  ref.listen(authControllerProvider, (_, next) {
    if (!next.isLoading && next.valueOrNull is AuthStateAuthenticated) {
      unawaited(syncDeviceToken());
    }
  }, fireImmediately: true);

  ref.onDispose(() {
    disposed = true;
    backgroundSub.cancel();
    foregroundSub.cancel();
    tokenSub.cancel();
  });

  // Permission UI or slow Play Services must not delay tap subscriptions.
  unawaited(FirebaseMessaging.instance
      .requestPermission(
    alert: true,
    badge: true,
    sound: true,
  )
      .then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {
    AppLog.w(
        LogTag.general, () => 'FCM permission request unavailable: $error');
  }));
  try {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && !receivedWarmTap) deliver(initial);
  } catch (error) {
    AppLog.w(
        LogTag.general, () => 'FCM initial notification unavailable: $error');
  }
}
