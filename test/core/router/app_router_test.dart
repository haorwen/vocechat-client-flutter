import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocechat_client/core/notifications/fcm_service.dart';
import 'package:vocechat_client/core/router/app_router.dart';
import 'package:vocechat_client/core/recovery/app_recovery.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

class _Auth extends AuthController {
  _Auth(this.signedIn);
  final bool signedIn;
  @override
  Future<AuthState> build() async => signedIn
      ? const AuthState.authenticated(user: VoceUser(uid: 1, name: 'Me'))
      : const AuthState.unauthenticated();
  void signIn() => state = const AsyncData(
      AuthState.authenticated(user: VoceUser(uid: 1, name: 'Me')));
}

class _Servers extends ServerStore {
  @override
  Future<ServerState> build() async => const ServerState(servers: [
        ServerConfig(
            id: 'server', name: 'server', baseUrl: 'https://server.test')
      ], currentServerId: 'server');
}

void main() {
  testWidgets(
      'stalled splash offers a scope restart without clearing stored data',
      (tester) async {
    final recovery = AppRecoveryController();
    addTearDown(recovery.dispose);
    var scopes = 0;
    await tester.pumpWidget(AppRecoveryHost(
        controller: recovery,
        builder: (_) {
          scopes++;
          return const ProviderScope(
              child: MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: SplashScreen(),
          ));
        }));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    expect(find.byType(AppRecoveryPage), findsOneWidget);
    await tester
        .tap(find.byWidgetPredicate((widget) => widget is FilledButton));
    await tester.pump();
    expect(scopes, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  Future<({ProviderContainer container, GoRouter router, _Auth auth})> mount(
      WidgetTester tester,
      {String? pending,
      bool signedIn = true}) async {
    final auth = _Auth(signedIn);
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(() => auth),
      serverStoreProvider.overrideWith(_Servers.new),
      appRoutesProvider.overrideWithValue([
        for (final path in ['/splash', '/login', '/register', '/server-picker'])
          GoRoute(path: path, builder: (_, __) => Scaffold(body: Text(path))),
        GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('home')),
            routes: [
              GoRoute(
                  path: 'chat/:id',
                  builder: (_, state) => Scaffold(
                      body: Text('chat ${state.pathParameters['id']}')))
            ]),
      ]),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(serverStoreProvider.future);
      await container.read(authControllerProvider.future);
    });
    if (pending != null) {
      container.read(fcmPendingChatTargetProvider.notifier).state = pending;
    }
    final router = container.read(goRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales)));
    await tester.pumpAndSettle();
    return (container: container, router: router, auth: auth);
  }

  testWidgets(
      'cold notification is consumed without provider writes during build',
      (tester) async {
    final app = await mount(tester, pending: 'g-1');
    expect(tester.takeException(), isNull);
    expect(find.text('chat g-1'), findsOneWidget);
    expect(app.container.read(fcmPendingChatTargetProvider), isNull);
  });

  testWidgets('warm and rapid notifications land on the most recent chat',
      (tester) async {
    final app = await mount(tester);
    final pending = app.container.read(fcmPendingChatTargetProvider.notifier);
    pending.state = 'g-1';
    pending.state = 'u-2';
    pending.state = 'g-3';
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('chat g-3'), findsOneWidget);
    expect(pending.state, isNull);
    pending.state = 'g-3';
    await tester.pumpAndSettle();
    expect(find.text('chat g-3'), findsOneWidget);
    expect(pending.state, isNull);
  });

  testWidgets('tap remains pending while login is required', (tester) async {
    final app = await mount(tester, pending: 'u-7', signedIn: false);
    expect(find.text('/login'), findsOneWidget);
    expect(app.container.read(fcmPendingChatTargetProvider), 'u-7');
    app.auth.signIn();
    await tester.pumpAndSettle();
    expect(find.text('chat u-7'), findsOneWidget);
    expect(app.container.read(fcmPendingChatTargetProvider), isNull);
  });

  testWidgets('duplicate native notification URI retains the current chat',
      (tester) async {
    final app = await mount(tester, pending: 'g-1');
    await app.router.routeInformationProvider.didPushRouteInformation(
        RouteInformation(
            uri: Uri.parse('vocechat-notification://open/server%3A%3A1/g-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('chat g-1'), findsOneWidget);
    expect(app.router.routerDelegate.currentConfiguration.isError, isFalse);
  });

  testWidgets(
      'invalid target does not trap routing and unknown page can recover',
      (tester) async {
    final app = await mount(tester, pending: 'g-bad/child');
    expect(find.text('home'), findsOneWidget);
    expect(app.container.read(fcmPendingChatTargetProvider), isNull);
    app.router.go('/missing-page');
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
    final recoveryButton =
        find.byWidgetPredicate((widget) => widget is FilledButton);
    expect(recoveryButton, findsOneWidget);
    await tester.tap(recoveryButton);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
