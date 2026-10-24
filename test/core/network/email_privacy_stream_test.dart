import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

import '../../support/email_privacy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'WebSocket preserves config/snapshot order across isolate and inline decoding',
      () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    addTearDown(() async {
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      // Force the first event through compute(), while the following small
      // events decode inline. Concurrent decoding used to reorder these.
      socket.add(jsonEncode({
        'type': 'server_config_changed',
        'hide_user_email': true,
        'padding': 'x' * 20000
      }));
      socket.add(jsonEncode({
        'type': 'users_snapshot',
        'version': 1,
        'users': [
          {'uid': 1, 'name': 'Self', 'email': null}
        ]
      }));
      socket.add(jsonEncode({'type': 'ready'}));
    });
    final client = VoceSseClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        apiKey: 'access',
        preferInlineParsing: () => true);
    final events = await client
        .events()
        .take(4)
        .toList()
        .timeout(const Duration(seconds: 10));
    expect(events[0], isA<ChatEventConnectionOpened>());
    expect(events[1], isA<ChatEventServerConfigChanged>());
    expect(events[2], isA<ChatEventUsersSnapshot>());
    expect(events[3], isA<ChatEventReady>());
  });

  test(
      'profile and account display writes leave the active WebSocket connected',
      () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final connected = Completer<void>();
    addTearDown(() async {
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.add(jsonEncode({'type': 'ready'}));
      if (!connected.isCompleted) connected.complete();
    });
    // Exercise the production stream provider with the real transport and
    // stable identity; only auth startup and on-disk message IO are replaced.
    final container = ProviderContainer(overrides: [
      serverStoreProvider.overrideWith(() => _Servers(server.port)),
      accountStoreProvider.overrideWith(_Accounts.new),
      authControllerProvider.overrideWith(_Auth.new),
      secureTokenStoreProvider(self.accountId)
          .overrideWith((ref) => Tokens(self.accountId)),
      messageCacheProvider.overrideWith((ref) async => _Cache()),
    ]);
    addTearDown(container.dispose);
    container.listen(serverStoreProvider, (_, __) {});
    container.listen(accountStoreProvider, (_, __) {});
    container.listen(authControllerProvider, (_, __) {});
    await container.read(serverStoreProvider.future);
    await container.read(accountStoreProvider.future);
    await container.read(authControllerProvider.future);
    container.listen(sseEventsProvider, (_, __) {});
    await connected.future.timeout(const Duration(seconds: 10));
    await flush();
    (container.read(authControllerProvider.notifier) as _Auth).changeProfile();
    await container
        .read(accountStoreProvider.notifier)
        .updateAccount(self.accountId, (saved) => saved.copyWith(email: null));
    await flush();
    expect(sockets, hasLength(1));
    expect(container.read(sseConnectionStatusProvider), SseStatus.connected);
  });
}

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.authenticated(
      user: VoceUser(uid: 1, name: 'Self', email: 'self@example.com'));
  void changeProfile() {
    state = const AsyncData(AuthState.authenticated(
        user: VoceUser(uid: 1, name: 'Self', email: null)));
  }
}

class _Accounts extends AccountStore {
  @override
  Future<AccountState> build() async =>
      const AccountState(accounts: [self], currentAccountId: 'server::1');
}

class _Servers extends ServerStore {
  _Servers(this.port);
  final int port;
  @override
  Future<ServerState> build() async =>
      ServerState(currentServerId: 'server', servers: [
        ServerConfig(
            id: 'server', name: 'Server', baseUrl: 'http://127.0.0.1:$port'),
      ]);
}

class _Cache extends Cache {
  @override
  Future<int?> getCursor() async => 0;
}
