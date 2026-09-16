import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/background/background_preferences.dart';
import 'package:vocechat_client/features/settings/presentation/background_settings_card.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

void backgroundTestWidgets(
    String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var enabled = false;
  var notifications = true;
  var battery = true;
  var batteryVisited = false;
  var failBatterySettings = false;
  var failWrite = false;
  final calls = <MethodCall>[];
  setUp(() {
    enabled = false;
    notifications = true;
    battery = true;
    batteryVisited = false;
    failBatterySettings = false;
    failWrite = false;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, (call) async {
      calls.add(call);
      if (call.method == 'status') {
        return {
          'enabled': enabled,
          'running': enabled,
          'notifications': notifications,
          'batteryExempt': battery,
          'batterySettingsVisited': batteryVisited,
        };
      }
      if (call.method == 'batterySettings') {
        batteryVisited = true;
        if (failBatterySettings) {
          throw PlatformException(code: 'no_settings_activity');
        }
      }
      if (call.method == 'setEnabled') {
        if (failWrite) throw PlatformException(code: 'write_failed');
        enabled = (call.arguments as Map)['enabled'] == true;
      }
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, null);
  });
  Future<void> mount(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride ??= TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const Scaffold(
          body: SingleChildScrollView(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: BackgroundSettingsCard()))),
    )));
    await tester.pumpAndSettle();
  }

  backgroundTestWidgets(
      'off by default, explicit enable persists and can be disabled',
      (tester) async {
    await mount(tester);
    expect(enabled, isFalse);
    expect(calls.where((c) => c.method == 'setEnabled'), isEmpty);
    await tester.tap(find.byKey(const Key('background-enabled')));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(find.text('Background service is running'), findsOneWidget);
    await tester.tap(find.byKey(const Key('background-enabled')));
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
  });
  for (final missing in ['notifications', 'battery']) {
    backgroundTestWidgets('cannot enable before $missing is allowed',
        (tester) async {
      notifications = missing != 'notifications';
      battery = missing != 'battery';
      await mount(tester);
      await tester.tap(find.byKey(const Key('background-enabled')));
      await tester.pumpAndSettle();
      expect(enabled, isFalse);
      expect(calls.where((c) => c.method == 'setEnabled'), isEmpty);
    });
  }
  for (final settingsFail in [false, true]) {
    backgroundTestWidgets(
        'battery tap allows enabling despite OEM false (settingsFail=$settingsFail)',
        (tester) async {
      battery = false;
      failBatterySettings = settingsFail;
      await mount(tester);
      await tester.tap(find.text('Disable battery optimization'));
      await tester.pumpAndSettle();
      expect(batteryVisited, isTrue);
      expect(enabled, isFalse); // visiting never enables automatically
      await tester.tap(find.byKey(const Key('background-enabled')));
      await tester.pumpAndSettle();
      expect(enabled, isTrue);
    });
  }
  backgroundTestWidgets(
      'saved battery visit survives remount and still requires notifications',
      (tester) async {
    battery = false;
    await mount(tester);
    await tester.tap(find.text('Disable battery optimization'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    notifications = false;
    await mount(tester);
    await tester.tap(find.byKey(const Key('background-enabled')));
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    notifications = true;
    await mount(tester);
    await tester.tap(find.byKey(const Key('background-enabled')));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
  });
  backgroundTestWidgets('failed persistence does not turn switch on',
      (tester) async {
    failWrite = true;
    await mount(tester);
    await tester.tap(find.byKey(const Key('background-enabled')));
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
    expect(find.text('Unable to update background settings. Please try again.'),
        findsOneWidget);
  });
  backgroundTestWidgets('system settings are opened only on tap',
      (tester) async {
    await mount(tester);
    await tester.tap(find.text('Disable battery optimization'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'batterySettings').length, 1);
    expect(calls.where((c) => c.method == 'setEnabled'), isEmpty);
  });
  backgroundTestWidgets('non-Android has no switch and no native calls',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await mount(tester);
    expect(find.byKey(const Key('background-enabled')), findsNothing);
    expect(calls, isEmpty);
  });
}
