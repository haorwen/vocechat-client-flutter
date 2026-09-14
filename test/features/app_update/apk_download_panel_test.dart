import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/app_update/data/android_update_installer.dart';
import 'package:vocechat_client/features/app_update/domain/android_release.dart';
import 'package:vocechat_client/features/app_update/presentation/apk_download_panel.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

final release = AndroidRelease(
    version: '0.3.24',
    versionCode: 24,
    timestamp: 1,
    forceUpdate: true,
    updateUrl: Uri.parse('https://update.voce.chat/app.apk'));

Widget _app(_Installer installer) => ProviderScope(
        overrides: [
          androidUpdateInstallerProvider.overrideWithValue(installer),
        ],
        child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Scaffold(body: ApkDownloadPanel(release: release))));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('channel sends only APK URL and expected version, never credentials',
      () async {
    const channel = MethodChannel('vocechat/android_update');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'install') return 'permission_required';
      return {'state': 'downloading', 'received': 50, 'total': 100};
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final installer = AndroidUpdateInstaller();
    expect((await installer.start(release)).progress, .5);
    expect(calls.single.arguments,
        {'version_code': 24, 'url': release.updateUrl.toString()});
    expect(await installer.install(release), 'permission_required');
    expect(calls.last.arguments, {'version_code': 24});
    for (final url in [
      'https://downloads.example.com/download/12345',
      'https://downloads.example.com/release.bin',
      'https://downloads.example.com/file?id=24&signature=a%2Fb%2Bc%3D&expires=1800000000',
    ]) {
      final metadata = AndroidRelease.fromJson({
        ...release.toJson(),
        'update_url': url,
      });
      await installer.start(metadata);
      expect(calls.last.arguments, {'version_code': 24, 'url': url},
          reason:
              'Preserve endpoint and signature; only the local file uses .apk');
    }
  });

  testWidgets('shows progress and opens native installer once on completion',
      (tester) async {
    final installer = _Installer();
    await tester.pumpWidget(_app(installer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载更新'));
    await tester.pump();
    expect(find.text('正在下载… 50%'), findsOneWidget);
    installer.value = const ApkDownload('ready');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(installer.installs, 1);
    expect(find.text('安装更新'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(installer.installs, 1);
    await tester.tap(find.text('安装更新'));
    await tester.pumpAndSettle();
    expect(installer.installs, 2);
  });

  testWidgets('cancel removes transfer and permits a new download',
      (tester) async {
    final installer = _Installer();
    await tester.pumpWidget(_app(installer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载更新'));
    await tester.pump();
    await tester.tap(find.text('取消下载'));
    await tester.pumpAndSettle();
    expect(installer.cancels, 1);
    expect(find.text('下载更新'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(installer.installs, 0);
  });

  testWidgets(
      'permission denial stays retryable and grant continues installation',
      (tester) async {
    final installer = _Installer()
      ..value = const ApkDownload('ready')
      ..result = 'permission_required';
    await tester.pumpWidget(_app(installer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('安装更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('允许安装'));
    await tester.pumpAndSettle();
    expect(installer.permissions, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('允许安装'), findsOneWidget);
    await tester.tap(find.text('允许安装'));
    await tester.pumpAndSettle();
    installer.result = 'opened';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('安装更新'), findsOneWidget);
    expect(installer.installs, 3);
  });

  testWidgets('invalid APK returns to download and shows a useful error',
      (tester) async {
    final installer = _Installer()
      ..value = const ApkDownload('ready')
      ..result = 'invalid_apk';
    await tester.pumpWidget(_app(installer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('安装更新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不是本应用的有效更新'), findsOneWidget);
    expect(find.text('下载更新'), findsOneWidget);
  });

  testWidgets(
      'restores unknown-length transfer and waits for foreground to install',
      (tester) async {
    final installer = _Installer()
      ..value = const ApkDownload('downloading', received: 1048576);
    await tester.pumpWidget(_app(installer));
    await tester.pump();
    expect(find.text('正在下载… 1.0 MB'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    installer.value = const ApkDownload('ready');
    await tester.pump(const Duration(seconds: 3));
    expect(installer.installs, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(installer.installs, 1);
  });

  testWidgets('failed native download permits retry without bypassing update',
      (tester) async {
    final installer = _Installer()..value = const ApkDownload('failed');
    await tester.pumpWidget(_app(installer));
    await tester.pumpAndSettle();
    expect(find.textContaining('下载失败'), findsOneWidget);
    await tester.tap(find.text('下载更新'));
    await tester.pump();
    expect(find.text('正在下载… 50%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(installer.installs, 0);
  });
}

class _Installer extends AndroidUpdateInstaller {
  ApkDownload value = const ApkDownload('idle');
  String result = 'opened';
  int installs = 0, cancels = 0, permissions = 0;
  @override
  Future<ApkDownload> status(AndroidRelease release) async => value;
  @override
  Future<ApkDownload> start(AndroidRelease release) async =>
      value = const ApkDownload('downloading', received: 50, total: 100);
  @override
  Future<void> cancel(AndroidRelease release) async {
    cancels++;
    value = const ApkDownload('idle');
  }

  @override
  Future<String> install(AndroidRelease release) async {
    installs++;
    return result;
  }

  @override
  Future<void> requestPermission(AndroidRelease release) async {
    permissions++;
  }
}
