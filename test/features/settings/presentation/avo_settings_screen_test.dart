import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/settings/data/user_api.dart';
import 'package:vocechat_client/features/settings/presentation/avo_settings_screen.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';
import 'package:vocechat_client/shared/models/avo_params.dart';

void main() {
  for (final version in <String?>[null, '0.5.22']) {
    testWidgets(
        'unsupported Avo save reports server support (version=$version)',
        (tester) async {
      final api = _SaveUserApi(
        failure: AvoUnsupportedException(serverVersion: version),
      );
      addTearDown(api.close);
      final auth = _TestAuthController();
      await _pumpEditor(tester, api, auth);

      await _save(tester);

      expect(
        find.text(version == null
            ? '服务端不支持保存 Avo 形象。'
            : '当前服务端（版本 $version）不支持保存 Avo 形象。'),
        findsOneWidget,
      );
      expect(find.text('Avo 已保存'), findsNothing);
      expect(auth.refreshCalls, 0);
      expect(api.updateCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('successful Avo save refreshes the profile and reports success',
      (tester) async {
    final api = _SaveUserApi();
    addTearDown(api.close);
    final auth = _TestAuthController();
    await _pumpEditor(tester, api, auth);
    await tester.enterText(find.byKey(const Key('avo-name')), '张三');
    await tester.pump();

    await _save(tester);

    expect(api.savedParams, AvoParams.fromName('张三'));
    expect(api.updateCalls, 1);
    expect(auth.refreshCalls, 1);
    expect(find.text('Avo 已保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network failures keep the generic Avo save error',
      (tester) async {
    final failure = DioException(
      requestOptions: RequestOptions(path: '/api/user/avo'),
      type: DioExceptionType.connectionError,
      message: 'Network unavailable',
    );
    final api = _SaveUserApi(failure: failure);
    addTearDown(api.close);
    final auth = _TestAuthController();
    await _pumpEditor(tester, api, auth);

    await _save(tester);

    expect(find.text('无法保存 Avo：$failure'), findsOneWidget);
    expect(find.text('服务端不支持保存 Avo 形象。'), findsNothing);
    expect(find.text('Avo 已保存'), findsNothing);
    expect(auth.refreshCalls, 0);
    expect(api.updateCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpEditor(
    WidgetTester tester, _SaveUserApi api, _TestAuthController auth) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => auth),
      accountStoreProvider.overrideWith(_EmptyAccountStore.new),
      userApiProvider.overrideWithValue(api),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Consumer(
        builder: (context, ref, child) {
          // The settings shell watches auth in the app. Retain it here too so
          // the auto-disposed notifier stays alive for the profile refresh.
          ref.watch(authControllerProvider);
          return const Scaffold(
            body: SingleChildScrollView(child: AvoSettingsCard()),
          );
        },
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byKey(const Key('avo-name')), findsOneWidget);
  expect(find.text('保存'), findsOneWidget);
}

Future<void> _save(WidgetTester tester) async {
  final save = find.text('保存');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pump();
  // Avo animates continuously, so allow the snack bar transition with bounded
  // frames instead of waiting for all scheduled frames to settle.
  await tester.pump(const Duration(milliseconds: 300));
}

class _SaveUserApi extends UserApi {
  _SaveUserApi({Object? failure}) : this._(Dio(), failure);

  _SaveUserApi._(this.dio, this.failure) : super(dio);

  final Dio dio;
  final Object? failure;
  int updateCalls = 0;
  AvoParams? savedParams;

  @override
  Future<void> updateAvo(AvoParams params) async {
    updateCalls++;
    savedParams = params;
    if (failure != null) throw failure!;
  }

  void close() => dio.close();
}

class _TestAuthController extends AuthController {
  int refreshCalls = 0;

  @override
  Future<AuthState> build() async => const AuthState.authenticated(
        user: VoceUser(uid: 7, name: 'Regular user'),
      );

  @override
  Future<void> refreshUser() async {
    refreshCalls++;
  }
}

class _EmptyAccountStore extends AccountStore {
  @override
  Future<AccountState> build() async => const AccountState();
}
