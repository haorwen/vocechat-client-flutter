import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocechat_client/core/router/app_router.dart';
import 'package:vocechat_client/core/router/deep_link_listener.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}

class _Servers extends ServerStore {
  Completer<void>? gate;
  bool failNext = false;
  final added = <String>[];

  @override
  Future<ServerState> build() async => const ServerState();

  @override
  Future<void> addServer(ServerConfig server) async {
    added.add(server.baseUrl);
    await gate?.future;
    if (failNext) {
      failNext = false;
      throw StateError('temporary storage failure');
    }
    final current = await future;
    state = AsyncData(current.copyWith(servers: [...current.servers, server]));
  }

  @override
  Future<void> selectServer(String id) async {
    state = AsyncData((await future).copyWith(currentServerId: id));
  }
}

class _Accounts extends AccountStore {
  @override
  Future<AccountState> build() async => const AccountState();
  @override
  Future<void> clearCurrentAccount() async {}
}

void main() {
  testWidgets(
      'invitation stream serializes taps, recovers failures and stops on dispose',
      (tester) async {
    const events = MethodChannel('com.llfbandit.app_links/events');
    const messages = MethodChannel('com.llfbandit.app_links/messages');
    final messenger = tester.binding.defaultBinaryMessenger;
    var initialReads = 0;
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(messages, (_) async {
      initialReads++;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(events, null);
      messenger.setMockMethodCallHandler(messages, null);
    });
    final servers = _Servers();
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, __) => const Text('home')),
      GoRoute(
          path: '/register',
          builder: (_, state) => Text('invite ${state.extra}')),
    ]);
    addTearDown(router.dispose);
    final container = ProviderContainer(overrides: [
      goRouterProvider.overrideWithValue(router),
      serverStoreProvider.overrideWith(() => servers),
      accountStoreProvider.overrideWith(_Accounts.new),
      authControllerProvider.overrideWith(_Auth.new),
    ]);
    container.listen(serverStoreProvider, (_, __) {});
    container.listen(accountStoreProvider, (_, __) {});
    container.listen(authControllerProvider, (_, __) {});
    await tester.runAsync(() async {
      await container.read(serverStoreProvider.future);
      await container.read(accountStoreProvider.future);
      await container.read(authControllerProvider.future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp.router(routerConfig: router)));
    container.read(deepLinkListenerProvider);
    await tester.pump();

    Future<void> emit(String host, String token) async {
      final uri = Uri(scheme: 'vocechat', host: 'open', queryParameters: {
        'link': 'https://$host/?magic_token=$token',
      });
      await messenger.handlePlatformMessage(
          events.name,
          const StandardMethodCodec().encodeSuccessEnvelope(uri.toString()),
          (_) {});
      await tester.pump();
    }

    // app_links delivers the initial intent on its stream. Duplicate events
    // while storage is busy must share one operation and preserve tap order.
    servers.gate = Completer<void>();
    await emit('first.test', 'first');
    await emit('first.test', 'first');
    await emit('second.test', 'second');
    expect(servers.added, ['https://first.test']);
    servers.gate!.complete();
    servers.gate = null;
    await tester.pumpAndSettle();
    expect(servers.added, ['https://first.test', 'https://second.test']);
    expect(find.text('invite second'), findsOneWidget);
    expect(initialReads, 0);

    // A failed operation must not poison the future chain for later links.
    servers.failNext = true;
    await emit('failed.test', 'failed');
    await emit('recovered.test', 'recovered');
    await tester.pumpAndSettle();
    expect(find.text('invite recovered'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Closing the app scope with an in-flight store write must prevent any
    // subsequent ref access or navigation from its completion.
    servers.gate = Completer<void>();
    await emit('late.test', 'late');
    container.dispose();
    servers.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('invite recovered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
