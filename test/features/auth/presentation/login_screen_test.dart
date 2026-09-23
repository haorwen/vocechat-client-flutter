import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/presentation/login_screen.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

void main() {
  Future<void> mount(WidgetTester tester, _Credentials credentials,
      {AuthRestoreFailure? failure, _Auth? auth}) async {
    tester.view.physicalSize = const Size(450, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        serverStoreProvider.overrideWith(_Server.new),
        authControllerProvider.overrideWith(() => auth ?? _Auth()),
        secureTokenStoreProvider('server').overrideWith((ref) => credentials),
        authRestoreFailureProvider.overrideWith((ref) => failure),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: LoginScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  String field(WidgetTester tester, int index) => tester
      .widget<TextFormField>(find.byType(TextFormField).at(index))
      .controller!
      .text;

  for (final email in ['xx@vip.qq.com', 'user+tag@mail.example.co.uk']) {
    testWidgets('login submits $email after trimming surrounding spaces',
        (tester) async {
      final auth = _Auth();
      await mount(tester, _Credentials(() async => null), auth: auth);
      await tester.enterText(find.byType(TextFormField).first, '  $email  ');
      await tester.enterText(find.byType(TextFormField).last, 'test-password');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(auth.submittedEmail, email);
      expect(auth.submittedPassword, 'test-password');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('saved email/password and checkbox are restored on opening login',
      (tester) async {
    await mount(tester, _Credentials(() async => _saved));
    expect(field(tester, 0), _saved.email);
    expect(field(tester, 1), _saved.password);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('temporary secure storage failure can be retried in login',
      (tester) async {
    var fail = true;
    await mount(tester, _Credentials(() async {
      if (fail) throw PlatformException(code: 'locked');
      return _saved;
    }));
    expect(find.text('Retry saved password'), findsOneWidget);
    expect(tester.takeException(), isNull);
    fail = false;
    await tester.tap(find.text('Retry saved password'));
    await tester.pumpAndSettle();
    expect(field(tester, 1), _saved.password);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(find.text('Retry saved password'), findsNothing);
  });

  testWidgets('delayed password restore does not overwrite user input',
      (tester) async {
    final pending = Completer<RememberedCredential?>();
    await mount(tester, _Credentials(() => pending.future));
    await tester.enterText(
        find.byType(TextFormField).first, 'other@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'other-password');
    pending.complete(_saved);
    await tester.pumpAndSettle();
    expect(field(tester, 0), 'other@example.com');
    expect(field(tester, 1), 'other-password');
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets(
      'storage completion after leaving login does not access disposed ref',
      (tester) async {
    final pending = Completer<RememberedCredential?>();
    await mount(tester, _Credentials(() => pending.future));
    await tester.pumpWidget(const SizedBox());
    pending.complete(_saved);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final reason in AuthRestoreFailure.values) {
    testWidgets(
        'login shows restore reason $reason without clearing saved password',
        (tester) async {
      await mount(tester, _Credentials(() async => _saved), failure: reason);
      expect(find.byKey(const Key('auth-restore-reason')), findsOneWidget);
      expect(field(tester, 1), _saved.password);
    });
  }
}

const _saved =
    RememberedCredential(email: 'test@example.com', password: 'saved-password');

class _Credentials extends SecureTokenStore {
  _Credentials(this.read) : super(id: 'server');
  final Future<RememberedCredential?> Function() read;
  @override
  Future<RememberedCredential?> readRememberedCredential() => read();
}

class _Server extends ServerStore {
  @override
  Future<ServerState> build() async => const ServerState(
        servers: [
          ServerConfig(
              id: 'server', baseUrl: 'https://example.com', name: 'Test')
        ],
        currentServerId: 'server',
      );
}

class _Auth extends AuthController {
  String? submittedEmail;
  String? submittedPassword;

  @override
  Future<void> login(String email, String password,
      {bool rememberMe = false, String? serverUrl}) async {
    submittedEmail = email;
    submittedPassword = password;
  }

  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}
