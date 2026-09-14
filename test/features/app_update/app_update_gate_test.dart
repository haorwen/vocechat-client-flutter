import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/features/app_update/application/app_update_controller.dart';
import 'package:vocechat_client/features/app_update/data/update_preferences_store.dart';
import 'package:vocechat_client/features/app_update/application/app_update_provider.dart';
import 'package:vocechat_client/features/app_update/data/android_update_installer.dart';
import 'package:vocechat_client/features/app_update/domain/android_release.dart';
import 'package:vocechat_client/features/app_update/presentation/app_update_gate.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

AndroidRelease release(bool force) => AndroidRelease(
      version: '0.3.23',
      versionCode: 23,
      timestamp: 1789056000000,
      forceUpdate: force,
      updateUrl: Uri.parse('https://update.voce.chat/downloads/app.apk'),
      announcement: '更新公告\n修复问题',
    );

Widget app({
  required Future<AndroidRelease?> Function() check,
  Future<bool> Function(Uri)? open,
  VoidCallback? onUnderlyingTap,
  Locale locale = const Locale('zh'),
  UpdatePreferencesStore? store,
}) =>
    ProviderScope(
      overrides: [
        startupAndroidUpdateProvider.overrideWith((ref) => check()),
        androidUpdateSupportedProvider.overrideWithValue(true),
        installedAndroidVersionCodeProvider.overrideWith((ref) async => 22),
        if (store != null)
          updatePreferencesStoreProvider.overrideWithValue(store),
        androidUpdateInstallerProvider.overrideWithValue(_Installer(open)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => AppUpdateGate(child: child!),
        home: Scaffold(
          body: TextButton(
              onPressed: onUnderlyingTap ?? () {}, child: const Text('聊天')),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('announcement follows interface language including live changes',
      (tester) async {
    final bilingual = AndroidRelease.fromJson({
      ...release(false).toJson(),
      'announcement': {'zh': '中文公告', 'en': 'English notes'}
    });
    for (final locale in [
      const Locale('zh'),
      const Locale('en'),
      const Locale('ja')
    ]) {
      await tester
          .pumpWidget(app(check: () async => bilingual, locale: locale));
      await tester.pumpAndSettle();
      expect(find.text(locale.languageCode == 'zh' ? '中文公告' : 'English notes'),
          findsOneWidget);
      expect(find.text(locale.languageCode == 'zh' ? 'English notes' : '中文公告'),
          findsNothing);
    }
  });

  testWidgets('emergency skip persists a 24 hour exemption before dismissing',
      (tester) async {
    await tester.pumpWidget(app(check: () async => release(true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应急跳过 1 天（剩余 3 次）'));
    await tester.pumpAndSettle();
    expect(find.text('下载更新'), findsNothing);
    final preferences = await UpdatePreferencesStore().read();
    expect(preferences.emergencySkipsUsed, 1);
    expect(
        preferences.emergencySkipUntilMs,
        greaterThan(DateTime.now()
            .add(const Duration(hours: 23))
            .millisecondsSinceEpoch));
  });

  testWidgets('ordinary skip version is persisted', (tester) async {
    await tester.pumpWidget(app(check: () async => release(false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳过此版本'));
    await tester.pumpAndSettle();
    expect(find.text('下载更新'), findsNothing);
    expect((await UpdatePreferencesStore().read()).skippedVersionCode, 23);
  });

  testWidgets('exhausted forced update has no skip controls', (tester) async {
    await UpdatePreferencesStore().write(const UpdatePreferences(
        requiredVersionCode: 23, emergencySkipsUsed: 3));
    await tester.pumpWidget(app(check: () async => release(true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('应急跳过'), findsNothing);
    expect(find.text('稍后再说'), findsNothing);
    expect(find.text('跳过此版本'), findsNothing);
    expect(find.text('下载更新'), findsOneWidget);
  });

  testWidgets('failed preference write keeps prompt and allows retry',
      (tester) async {
    final store = _FailingStore();
    await tester
        .pumpWidget(app(check: () async => release(true), store: store));
    await tester.pumpAndSettle();
    store.fail = true;
    await tester.tap(find.text('应急跳过 1 天（剩余 3 次）'));
    await tester.pumpAndSettle();
    expect(find.text('下载更新'), findsOneWidget);
    expect(find.textContaining('无法保存更新偏好'), findsOneWidget);
    expect((await store.read()).emergencySkipsUsed, 0);
    store.fail = false;
    await tester.tap(find.text('应急跳过 1 天（剩余 3 次）'));
    await tester.pumpAndSettle();
    expect(find.text('下载更新'), findsNothing);
  });
  testWidgets('showing and dismissing an update preserves the navigator',
      (tester) async {
    final response = Completer<AndroidRelease?>();
    await tester.pumpWidget(app(check: () => response.future));
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    response.complete(release(false));
    await tester.pumpAndSettle();
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)), same(navigator));
    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)), same(navigator));
  });

  testWidgets('optional update displays announcement and can be postponed',
      (tester) async {
    await tester.pumpWidget(app(check: () async => release(false)));
    await tester.pumpAndSettle();
    expect(find.text('更新公告\n修复问题'), findsOneWidget);
    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(find.text('下载更新'), findsNothing);
    expect(find.text('聊天'), findsOneWidget);
  });

  testWidgets(
      'forced update survives back, barrier taps and opening native installer',
      (tester) async {
    var taps = 0;
    final opened = <Uri>[];
    await tester.pumpWidget(app(
      check: () async => release(true),
      onUnderlyingTap: () => taps++,
      open: (uri) async {
        opened.add(uri);
        return true;
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('稍后再说'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('下载更新'), findsOneWidget);
    expect(taps, 0);
    await tester.tap(find.text('下载更新'));
    await tester.pumpAndSettle();
    expect(opened, [release(true).updateUrl]);
    expect(find.text('安装更新'), findsOneWidget);
  });

  testWidgets('failed native installer opening shows error and supports retry',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(app(
      check: () async => release(true),
      open: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('cannot open');
        return true;
      },
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载更新'));
    await tester.pumpAndSettle();
    expect(find.text('无法打开系统安装界面，请重试。'), findsOneWidget);
    await tester.tap(find.text('安装更新'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('无法打开系统安装界面，请重试。'), findsNothing);
    expect(find.text('安装更新'), findsOneWidget);
  });

  testWidgets(
      'failed startup check leaves app usable and does not retry on resume',
      (tester) async {
    var checks = 0;
    await tester.pumpWidget(app(check: () async {
      checks++;
      throw StateError('offline');
    }));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('下载更新'), findsNothing);
    expect(checks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long announcement fits a small screen and remains scrollable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = release(true).toJson();
    data['announcement'] = List.filled(60, '更新公告').join('\n');
    await tester
        .pumpWidget(app(check: () async => AndroidRelease.fromJson(data)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('下载更新'), 300);
    expect(tester.takeException(), isNull);
  });
}

class _FailingStore extends UpdatePreferencesStore {
  bool fail = false;

  @override
  Future<void> write(UpdatePreferences value) {
    if (fail) throw StateError('disk unavailable');
    return super.write(value);
  }
}

class _Installer extends AndroidUpdateInstaller {
  _Installer(this.open);
  final Future<bool> Function(Uri)? open;
  @override
  Future<ApkDownload> status(AndroidRelease release) async =>
      const ApkDownload('idle');
  @override
  Future<ApkDownload> start(AndroidRelease release) async =>
      const ApkDownload('ready');
  @override
  Future<String> install(AndroidRelease release) async =>
      await open?.call(release.updateUrl) == true ? 'opened' : 'failed';
}
