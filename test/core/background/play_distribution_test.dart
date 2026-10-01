import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/background/background_preferences.dart';
import 'package:vocechat_client/core/background/background_runtime.dart';
import 'package:vocechat_client/core/config/distribution.dart';
import 'package:vocechat_client/features/app_update/application/app_update_controller.dart';
import 'package:vocechat_client/features/app_update/application/app_update_provider.dart';
import 'package:vocechat_client/features/app_update/presentation/app_update_gate.dart';
import 'package:vocechat_client/features/settings/presentation/background_settings_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android feature availability follows distribution', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(isAndroidBackgroundSupported, !isPlayDistribution);
    expect(container.read(androidUpdateSupportedProvider), !isPlayDistribution);
  });

  testWidgets('Play hides background settings and never initializes update UI',
      (tester) async {
    try {
      var checks = 0;
      var taps = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appUpdateControllerProvider.overrideWith(() {
            checks++;
            throw StateError('Play must not initialize the update controller');
          }),
        ],
        child: MaterialApp(
          home: AppUpdateGate(
            child: Scaffold(
              body: Column(children: [
                const BackgroundSettingsCard(),
                TextButton(onPressed: () => taps++, child: const Text('Chat')),
              ]),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('background-enabled')), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.tap(find.text('Chat'));
      expect(taps, 1);
      expect(checks, 0);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: !isPlayDistribution);

  test('Play ignores saved background opt-in and never checks update API',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, (call) async {
      calls.add(call);
      return {'enabled': true, 'running': true};
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, null));
    var apiBuilds = 0;
    final container = ProviderContainer(overrides: [
      androidUpdateApiProvider.overrideWith((ref) {
        apiBuilds++;
        throw StateError('Play must not initialize the update API');
      }),
      installedAndroidVersionCodeProvider.overrideWith((ref) async => 1),
    ]);
    addTearDown(container.dispose);
    container.read(backgroundRuntimeProvider);
    final preferences =
        await container.read(backgroundPreferencesProvider.future);
    expect(preferences.enabled, isFalse);
    await container
        .read(backgroundPreferencesProvider.notifier)
        .setEnabled(true);
    await container
        .read(backgroundPreferencesProvider.notifier)
        .openBatterySettings();
    expect(await container.read(startupAndroidUpdateProvider.future), isNull);
    expect(calls, isEmpty);
    expect(apiBuilds, 0);
  }, skip: !isPlayDistribution);
}
