import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/router/app_router.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/data/auth_api.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/server/presentation/server_picker_screen.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

const _alpha = ServerConfig(
    id: 'alpha', name: 'Alpha', baseUrl: 'https://alpha.example.com');
const _beta =
    ServerConfig(id: 'beta', name: 'Beta', baseUrl: 'https://beta.example.com');
const _accounts = [
  AccountConfig(accountId: 'alpha::1', serverId: 'alpha', uid: 1, name: 'A1'),
  AccountConfig(accountId: 'alpha::2', serverId: 'alpha', uid: 2, name: 'A2'),
  AccountConfig(accountId: 'beta::3', serverId: 'beta', uid: 3, name: 'B3'),
];

void main() {
  Future<_App> mount(WidgetTester tester,
      {bool empty = false, Locale locale = const Locale('en')}) async {
    SharedPreferences.setMockInitialValues({
      if (!empty) ...{
        'voce_servers': [
          jsonEncode(_alpha.toJson()),
          jsonEncode(_beta.toJson()),
        ],
        'voce_current_server': _alpha.id,
        'voce_accounts': _accounts.map((a) => jsonEncode(a.toJson())).toList(),
        'voce_current_account': 'alpha::1',
      },
    });
    final tokens = {
      for (final id in ['alpha', 'beta', ..._accounts.map((a) => a.accountId)])
        id: _Tokens(id),
    };
    final api = _OfflineApi();
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      authApiProvider.overrideWithValue(api),
      for (final entry in tokens.entries)
        secureTokenStoreProvider(entry.key).overrideWith((ref) => entry.value),
      appRoutesProvider.overrideWithValue([
        GoRoute(
            path: '/server-picker',
            builder: (_, __) => const ServerPickerScreen()),
        for (final path in ['/splash', '/login', '/home'])
          GoRoute(path: path, builder: (_, __) => Scaffold(body: Text(path))),
      ]),
    ]);
    addTearDown(container.dispose);
    container.listen(serverStoreProvider, (_, __) {});
    container.listen(accountStoreProvider, (_, __) {});
    await tester.runAsync(() async {
      await container.read(serverStoreProvider.future);
      await container.read(accountStoreProvider.future);
      container.listen(authControllerProvider, (_, __) {});
      await container.read(authControllerProvider.future);
    });
    final router = container.read(goRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    router.go('/server-picker');
    await tester.pumpAndSettle();
    return _App(container, tokens, api);
  }

  Future<void> requestRemoval(WidgetTester tester, int index) async {
    await tester.tap(find.byIcon(Icons.delete_outline).at(index));
    await tester.pumpAndSettle();
  }

  Future<void> confirmRemoval(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Remove server'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel keeps the server, saved accounts and credentials',
      (tester) async {
    final app = await mount(tester);
    await requestRemoval(tester, 0);
    expect(find.textContaining('Alpha (https://alpha.example.com)'),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(app.servers.servers, [_alpha, _beta]);
    expect(app.accounts.accounts, _accounts);
    expect(app.tokens.values.every((store) => store.clearCount == 0), isTrue);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'removing the selected other server allows continuing with current',
      (tester) async {
    final app = await mount(tester);
    await tester.tap(find.text('Beta'));
    await tester.pump();
    await requestRemoval(tester, 1);
    await confirmRemoval(tester);
    expect(find.text('Beta'), findsNothing);
    expect(app.servers.currentServerId, 'alpha');
    expect(app.accounts.currentAccountId, 'alpha::1');
    expect(app.container.read(authControllerProvider).requireValue,
        isA<AuthStateAuthenticated>());
    expect(app.tokens['alpha::1']!.clearCount, 0);
    expect(app.tokens['beta::3']!.clearCount, 1);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('/login'), findsOneWidget);
    expect(app.servers.currentServerId, 'alpha');
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing current server forgets all its sign-ins while offline',
      (tester) async {
    final app = await mount(tester);
    final requestsBeforeRemoval = app.api.requests;
    await requestRemoval(tester, 0);
    await confirmRemoval(tester);
    expect(app.api.requests, requestsBeforeRemoval);
    expect(app.servers.servers, [_beta]);
    expect(app.servers.currentServerId, isNull);
    expect(app.accounts.accounts, [_accounts.last]);
    expect(app.accounts.currentAccountId, isNull);
    expect(app.container.read(authControllerProvider).requireValue,
        isA<AuthStateUnauthenticated>());
    for (final id in ['alpha', 'alpha::1', 'alpha::2']) {
      expect(app.tokens[id]!.clearCount, 1);
    }
    expect(app.tokens['alpha']!.rememberedCleared, isTrue);
    expect(app.tokens['beta']!.rememberedCleared, isFalse);
    expect(app.tokens['beta::3']!.clearCount, 0);
    // A new provider scope reads persisted data rather than the screen's state.
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final savedServers = await restarted.read(serverStoreProvider.future);
    final savedAccounts = await restarted.read(accountStoreProvider.future);
    expect(savedServers.servers, [_beta]);
    expect(savedServers.currentServerId, isNull);
    expect(savedAccounts.accounts, [_accounts.last]);
    expect(savedAccounts.currentAccountId, isNull);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('/login'), findsOneWidget);
    expect(app.servers.currentServerId, 'beta');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newly added last server can be removed and added again',
      (tester) async {
    final app = await mount(tester, empty: true);
    final store = app.container.read(serverStoreProvider.notifier);
    await store.addServer(_alpha);
    await store.selectServer(_alpha.id);
    await tester.pumpAndSettle();
    await requestRemoval(tester, 0);
    await confirmRemoval(tester);
    expect(find.text('Connect to a VoceChat server'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(app.servers.servers, isEmpty);
    expect(app.servers.currentServerId, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('voce_servers'), isEmpty);
    expect(prefs.getString('voce_current_server'), isNull);
    await tester.tap(find.text('Add your first server'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage failure leaves the server visible and allows retry',
      (tester) async {
    final app = await mount(tester);
    app.tokens['alpha::1']!.failClear = true;
    await requestRemoval(tester, 0);
    await confirmRemoval(tester);
    expect(find.textContaining('storage unavailable'), findsOneWidget);
    expect(app.servers.servers, [_alpha, _beta]);
    expect(app.accounts.accounts, _accounts);
    expect(app.accounts.currentAccountId, 'alpha::1');
    app.tokens['alpha::1']!.failClear = false;
    await requestRemoval(tester, 0);
    await confirmRemoval(tester);
    expect(app.servers.servers, [_beta]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese removal controls and confirmation are localized',
      (tester) async {
    await mount(tester, locale: const Locale('zh'));
    expect(find.byTooltip('删除服务器'), findsNWidgets(2));
    await requestRemoval(tester, 0);
    expect(find.text('删除该服务器？'), findsOneWidget);
    expect(find.textContaining('Alpha'), findsWidgets);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
  });
}

class _App {
  _App(this.container, this.tokens, this.api);
  final ProviderContainer container;
  final Map<String, _Tokens> tokens;
  final _OfflineApi api;
  ServerState get servers => container.read(serverStoreProvider).requireValue;
  AccountState get accounts =>
      container.read(accountStoreProvider).requireValue;
}

class _Auth extends AuthController {
  @override
  Future<bool> checkServerIdentity([String? requestedBaseUrl]) async => false;
}

class _OfflineApi extends AuthApi {
  _OfflineApi() : super(Dio());
  int requests = 0;
  @override
  Future<VoceUser> me() async {
    requests++;
    throw StateError('server offline');
  }
}

class _Tokens extends SecureTokenStore {
  _Tokens(String id) : super(id: id);
  int clearCount = 0;
  bool rememberedCleared = false;
  bool failClear = false;
  @override
  Future<TokenData?> readTokens() async => clearCount > 0
      ? null
      : TokenData(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime(2100),
        );
  @override
  Future<void> clear() async {
    if (failClear) throw StateError('storage unavailable');
    clearCount++;
  }

  @override
  Future<void> clearRememberedCredential() async => rememberedCleared = true;
}
