import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_log.dart';

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
    FirebaseMessaging.instance
        .getToken()
        .then((t) {
          if (!completer.isCompleted) completer.complete(t ?? '');
        })
        .catchError((Object _) {
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

String? _parseChatTarget(RemoteMessage message) {
  final data = message.data;
  if (data.containsKey('vocechat_to_gid')) {
    final gid = int.tryParse(data['vocechat_to_gid'] as String? ?? '');
    if (gid != null) return 'g-$gid';
  } else if (data.containsKey('vocechat_from_uid')) {
    final uid = int.tryParse(data['vocechat_from_uid'] as String? ?? '');
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
  if (!_isMobile || !_firebaseReady) return;

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // App was launched from a *terminated* state by tapping a notification.
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    final target = _parseChatTarget(initial);
    if (target != null) {
      AppLog.d(LogTag.general, () => '📲 FCM initial message → $target');
      ref.read(fcmPendingChatTargetProvider.notifier).state = target;
    }
  }

  // App was in the *background*; user tapped the notification.
  final backgroundSub =
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final target = _parseChatTarget(message);
    if (target != null) {
      AppLog.d(LogTag.general, () => '📲 FCM background tap → $target');
      ref.read(fcmPendingChatTargetProvider.notifier).state = target;
    }
  });

  // Foreground messages — the SSE stream already delivers the payload, so we
  // only log here. Add local-notification display if needed in the future.
  final foregroundSub = FirebaseMessaging.onMessage.listen((message) {
    AppLog.d(LogTag.general, () => '📲 FCM foreground: ${message.data}');
  });

  ref.onDispose(() {
    backgroundSub.cancel();
    foregroundSub.cancel();
  });
}
