import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/background/background_preferences.dart';
import 'package:vocechat_client/core/background/background_runtime.dart';
import 'package:vocechat_client/core/config/distribution.dart';
import 'package:vocechat_client/core/notifications/fcm_service.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/voice/application/voice_controller.dart';
import 'package:vocechat_client/features/voice/domain/voice_models.dart';

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 1, name: 'Me'));
}

class _Accounts extends AccountStore {
  @override
  Future<AccountState> build() async =>
      const AccountState(currentAccountId: 'server::1');
}

class _Voice extends VoiceController {
  @override
  VoicingInfo? build() => null;
}

class _Preferences extends BackgroundPreferences {
  @override
  Future<BackgroundStatus> build() async => const BackgroundStatus();
  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets(
      'disposing an old scope retains the new native notification handler',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger = tester.binding.defaultBinaryMessenger;
    Map<String, String>? pendingTap;
    messenger.setMockMethodCallHandler(backgroundChannel, (call) async {
      if (call.method == 'takeTap') {
        final tap = pendingTap;
        pendingTap = null;
        return tap;
      }
      return null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(backgroundChannel, null));

    Future<ProviderContainer> start() async {
      final container = ProviderContainer(overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        accountStoreProvider.overrideWith(_Accounts.new),
        voiceControllerProvider.overrideWith(_Voice.new),
        backgroundPreferencesProvider.overrideWith(_Preferences.new),
      ]);
      container.read(backgroundRuntimeProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      return container;
    }

    Future<ByteData?> notify() async {
      ByteData? response;
      await messenger.handlePlatformMessage(
          backgroundChannel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('notificationTap')),
          (reply) => response = reply);
      await tester.pump();
      return response;
    }

    final previous = await start();
    // Mirrors KeyedSubtree replacement: the new scope mounts while the old
    // scope is still alive, and only then does Flutter unmount the old tree.
    final current = await start();
    previous.dispose();
    pendingTap = {'session': 'server::1', 'target': 'g-9'};
    final response = await notify();
    expect(response, isNotNull);
    expect(current.read(fcmPendingChatTargetProvider), 'g-9');
    expect(pendingTap, isNull);

    // The current owner's disposal still removes its own handler.
    current.dispose();
    pendingTap = {'session': 'server::1', 'target': 'g-10'};
    expect(await notify(), isNull);
    expect(pendingTap?['target'], 'g-10');
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  }, skip: isPlayDistribution);
}
