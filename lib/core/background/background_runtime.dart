import '../../features/channels/application/muted_chats_provider.dart';
import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/voice/application/voice_controller.dart';
import '../notifications/fcm_service.dart';
import '../storage/account_store.dart';
import '../utils/app_log.dart';
import 'background_lifecycle.dart';
import 'background_preferences.dart';

/// One app-scoped coordinator. Only starts foreground services from a visible
/// activity; Android 12+ forbids arbitrary service starts from the background.
final backgroundRuntimeProvider = Provider<void>((ref) {
  if (!isAndroidBackgroundSupported) return;
  var disposed = false;
  Future<void> queue = Future.value();
  String? lastRequest;
  var revision = 0;

  Future<void> takeTap() async {
    if (disposed ||
        ref.read(authControllerProvider).isLoading ||
        ref.read(accountStoreProvider).isLoading) {
      return;
    }
    Map<dynamic, dynamic>? data;
    try {
      data = await backgroundChannel.invokeMapMethod('takeTap');
    } catch (error) {
      AppLog.w(LogTag.general,
          () => 'Background notification tap unavailable: $error');
      return;
    }
    if (disposed || data == null) return;
    if (data['session'] !=
        ref.read(accountStoreProvider).valueOrNull?.currentAccountId) {
      return;
    }
    final target = data['target'];
    if (target is String && RegExp(r'^[ug]-\d+$').hasMatch(target)) {
      ref.read(fcmPendingChatTargetProvider.notifier).state = target;
    }
  }

  Future<void> sync() async {
    if (disposed) return;
    final generation = revision;
    final auth = ref.read(authControllerProvider);
    // Token renewal must not tear down a live service.
    if (auth.isLoading) return;
    final enabled =
        ref.read(backgroundPreferencesProvider).valueOrNull?.enabled == true;
    final session = auth.valueOrNull is AuthStateAuthenticated
        ? ref.read(accountStoreProvider).valueOrNull?.currentAccountId ?? ''
        : '';
    final muted = ref.read(mutedChatsProvider);
    await backgroundChannel.invokeMethod('configureNotifications', {
      'session': session,
      'muted': [
        ...muted.mutedUsers.map((id) => 'u-$id'),
        ...muted.mutedGroups.map((id) => 'g-$id'),
      ],
    });
    if (disposed || generation != revision) return;
    final voice = ref.read(voiceControllerProvider);
    final calling = voice != null && !voice.joining;
    final background = ref.read(androidBackgroundedProvider);
    final request = '$enabled/$session/$calling';
    if (request == lastRequest) return;
    final status = ref.read(backgroundPreferencesProvider).valueOrNull;
    // Existing services may drop microphone access in the background, but
    // a new service or microphone access needs a visible activity.
    if (background &&
        enabled &&
        session.isNotEmpty &&
        (status?.running != true || calling)) {
      return;
    }
    try {
      if (disposed || generation != revision) return;
      await backgroundChannel.invokeMethod('sync', {
        'session': enabled ? session : '',
        'calling': calling,
        'background': background,
      });
      lastRequest = request;
      // startForegroundService is asynchronous; do not claim it is running
      // based only on the start request.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!disposed) {
        await ref.read(backgroundPreferencesProvider.notifier).refresh();
      }
    } catch (error) {
      AppLog.w(LogTag.general, () => 'Background service unavailable: $error');
    }
  }

  void schedule() {
    revision++;
    queue = queue.then((_) async {
      try {
        await sync();
        await takeTap();
      } catch (error) {
        AppLog.w(LogTag.general,
            () => 'Notification configuration unavailable: $error');
      }
    });
  }

  ref.listen(
      backgroundPreferencesProvider.select((s) => s.valueOrNull?.enabled),
      (_, __) => schedule());
  ref.listen(authControllerProvider, (_, __) => schedule());
  ref.listen(accountStoreProvider, (_, __) => schedule());
  ref.listen(mutedChatsProvider, (_, __) => schedule());
  ref.listen(voiceControllerProvider.select((s) => s != null && !s.joining),
      (_, __) => schedule());
  ref.listen(androidBackgroundedProvider, (_, background) {
    if (background && ref.read(voiceControllerProvider) == null) {
      PaintingBinding.instance.imageCache.clear();
    }
    if (!background) {
      lastRequest = null;
      unawaited(ref.read(backgroundPreferencesProvider.notifier).refresh());
    }
    schedule();
  });

  backgroundChannel.setMethodCallHandler((call) async {
    if (call.method == 'notificationTap') await takeTap();
  });
  unawaited(takeTap());
  schedule();
  ref.onDispose(() {
    disposed = true;
    backgroundChannel.setMethodCallHandler(null);
  });
});
