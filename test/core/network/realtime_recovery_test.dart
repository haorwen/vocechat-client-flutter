import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/core/network/sse_lifecycle.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/chat_controller.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

const accountId = 'server::1';

class Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 1, name: 'Self'));
}

class Accounts extends AccountStore {
  @override
  Future<AccountState> build() async => const AccountState(accounts: [
        AccountConfig(
            accountId: accountId, serverId: 'server', uid: 1, name: 'Self')
      ], currentAccountId: accountId);
}

class Servers extends ServerStore {
  Servers(this.port);
  final int port;
  @override
  Future<ServerState> build() async =>
      ServerState(currentServerId: 'server', servers: [
        ServerConfig(
            id: 'server', name: 'Server', baseUrl: 'http://127.0.0.1:$port')
      ]);
}

class Tokens extends SecureTokenStore {
  Tokens() : super(id: accountId);
  int reads = 0;
  bool fail = true;
  bool missing = false;
  @override
  Future<TokenData?> readTokens() async {
    reads++;
    if (fail) throw StateError('temporary secure storage failure');
    if (missing) return null;
    return TokenData(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(days: 1)));
  }
}

class Cache implements MessageCache {
  int cursorReads = 0;
  @override
  Future<int?> getCursor() async {
    cursorReads++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Groups extends GroupDirectory {
  @override
  Future<Map<int, GroupSummary>> build() async => {};
}

const target = MessageTarget.group(gid: 42);
ChatMessage message(int mid, {int from = 2}) => ChatMessage(
    mid: mid,
    fromUid: from,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    target: target,
    detail: MessageDetail.normal(
        contentType: 'text/plain', content: 'message $mid'));

class ConversationCache extends Cache {
  int cursor = 100;
  List<ChatMessage> rows = [message(100)];
  @override
  Future<int?> getCursor() async => cursor;
  @override
  Future<void> setCursor(int mid) async {
    if (mid > cursor) cursor = mid;
  }

  @override
  Future<List<ChatMessage>> read(MessageTarget target,
          {int limit = 500}) async =>
      List.of(rows);
  @override
  void scheduleWrite(MessageTarget target, List<ChatMessage> messages) {
    rows = List.of(messages);
  }

  @override
  Future<void> deleteMid(MessageTarget target, int mid) async {
    rows.removeWhere((m) => m.mid == mid);
  }
}

class HistoryApi extends MessageApi {
  HistoryApi() : super(Dio());
  final history = <ChatMessage>[message(100)];
  @override
  Future<List<ChatMessage>> getHistory(MessageTarget target,
          {int? beforeMid, int limit = 30}) async =>
      List.of(history);
  @override
  Future<int> sendText(MessageTarget target, String text,
      {List<int>? mentions, int? localId}) async {
    history.add(message(102, from: 1));
    return 102;
  }
}

Future<void> waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition did not become true');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final missing in [false, true]) {
    test(
        'temporary credential ${missing ? 'absence' : 'errors'} recover without invalidation',
        () async {
      SharedPreferences.setMockInitialValues({});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.add(jsonEncode({'type': 'ready'}));
      });
      final tokens = Tokens()
        ..fail = !missing
        ..missing = missing;
      final container = ProviderContainer(overrides: [
        authControllerProvider.overrideWith(Auth.new),
        accountStoreProvider.overrideWith(Accounts.new),
        serverStoreProvider.overrideWith(() => Servers(server.port)),
        secureTokenStoreProvider(accountId).overrideWith((ref) => tokens),
        messageCacheProvider.overrideWith((ref) async => Cache()),
      ]);
      addTearDown(() async {
        container.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      });
      container.listen(authControllerProvider, (_, __) {});
      await container.read(authControllerProvider.future);
      await container.read(accountStoreProvider.future);
      await container.read(serverStoreProvider.future);
      container.listen(sseEventsProvider, (_, __) {});
      await waitFor(() => tokens.reads > 0);
      expect(sockets, isEmpty);
      tokens.fail = false;
      tokens.missing = false;
      await waitFor(() =>
          container.read(sseEventsProvider).valueOrNull is ChatEventReady);
      expect(container.read(sseConnectionStatusProvider), SseStatus.connected);
      expect(sockets, hasLength(1));
    });
  }

  test('disposing during initialization stops late cache work', () async {
    final gate = Completer<MessageCache>();
    final cache = Cache();
    final tokens = Tokens()..fail = false;
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(Auth.new),
      accountStoreProvider.overrideWith(Accounts.new),
      serverStoreProvider.overrideWith(() => Servers(1)),
      secureTokenStoreProvider(accountId).overrideWith((ref) => tokens),
      messageCacheProvider.overrideWith((ref) => gate.future),
    ]);
    container.listen(authControllerProvider, (_, __) {});
    await container.read(authControllerProvider.future);
    await container.read(accountStoreProvider.future);
    await container.read(serverStoreProvider.future);
    container.listen(sseEventsProvider, (_, __) {});
    await waitFor(() => tokens.reads > 0);
    container.dispose();
    gate.complete(cache);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cache.cursorReads, 0);
  });

  test('Wi-Fi to cellular reconnects even without an offline event', () async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast();
    var connections = 0;
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(Auth.new),
      connectivityChangesProvider.overrideWith((ref) => changes.stream),
      sseEventsProvider.overrideWith((ref) {
        connections++;
        return const Stream<ChatEvent>.empty();
      }),
    ]);
    addTearDown(container.dispose);
    addTearDown(changes.close);
    container.listen(authControllerProvider, (_, __) {});
    await container.read(authControllerProvider.future);
    container.listen(sseEventsProvider, (_, __) {});
    container.read(sseConnectivityWatcherProvider);
    changes.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(connections, 1);
    changes.add([ConnectivityResult.mobile]);
    await waitFor(() => connections == 2);
    changes.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    expect(connections, 2);
    changes.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    changes.add([ConnectivityResult.mobile]);
    await waitFor(() => connections == 3);
  });

  test('preconnect callback errors retry without an unhandled exception',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.add(jsonEncode({'type': 'ready'}));
    });
    addTearDown(() async {
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    var attempts = 0;
    final client = VoceSseClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'access',
      refreshToken: () async {
        attempts++;
        if (attempts == 1) throw StateError('temporary secure storage failure');
        return 'access';
      },
    );
    addTearDown(client.dispose);
    final events = await client
        .events()
        .take(2)
        .toList()
        .timeout(const Duration(seconds: 5));
    expect(events.last, isA<ChatEventReady>());
    expect(attempts, 2);
    expect(sockets, hasLength(1));
  });

  test('disposing a transport cancels pending reconnects', () async {
    var attempts = 0;
    final client = VoceSseClient(
      baseUrl: 'http://127.0.0.1:1',
      apiKey: 'access',
      refreshToken: () async {
        attempts++;
        throw StateError('temporary secure storage failure');
      },
    );
    final subscription = client.events().listen((_) {});
    await waitFor(() => attempts == 1);
    client.dispose();
    await subscription.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(attempts, 1);
  });

  test('hung credential renewal times out without starting another renewal',
      () async {
    final renewal = Completer<String?>();
    final retrying = Completer<void>();
    final statuses = <SseStatus>[];
    var renewals = 0;
    final client = VoceSseClient(
      baseUrl: 'http://127.0.0.1:1',
      apiKey: 'access',
      onStatus: (status) {
        statuses.add(status);
        if (status == SseStatus.reconnecting && !retrying.isCompleted) {
          retrying.complete();
        }
      },
      refreshToken: () {
        renewals++;
        return renewal.future;
      },
    );
    addTearDown(client.dispose);
    final subscription = client.events().listen((_) {});
    await retrying.future.timeout(const Duration(seconds: 20));
    expect(statuses.last, SseStatus.reconnecting);
    await waitFor(() => statuses.last == SseStatus.connecting);
    expect(renewals, 1);
    expect(statuses.last, SseStatus.connecting);
    client.dispose();
    renewal.complete('fresh-token');
    await subscription.cancel();
  });

  test(
      'group replay still includes incoming messages missed before an HTTP send',
      () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final requestedCursors = <int>[];
    final api = HistoryApi();
    server.listen((request) async {
      final after = int.parse(request.uri.queryParameters['after_mid']!);
      requestedCursors.add(after);
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      for (final item in api.history.where((m) => m.mid > after)) {
        socket.add(jsonEncode({'type': 'chat', ...item.toJson()}));
      }
      socket.add(jsonEncode({'type': 'ready'}));
    });
    final cache = ConversationCache();
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(Auth.new),
      accountStoreProvider.overrideWith(Accounts.new),
      serverStoreProvider.overrideWith(() => Servers(server.port)),
      secureTokenStoreProvider(accountId)
          .overrideWith((ref) => Tokens()..fail = false),
      messageCacheProvider.overrideWith((ref) async => cache),
      messageApiProvider.overrideWith((ref) => api),
      groupDirectoryProvider.overrideWith(Groups.new),
    ]);
    addTearDown(() async {
      container.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    container.listen(authControllerProvider, (_, __) {});
    await container.read(authControllerProvider.future);
    await container.read(accountStoreProvider.future);
    await container.read(serverStoreProvider.future);
    final chat = chatControllerProvider(target);
    container.listen(chat, (_, __) {});
    await container.read(chat.future);
    for (var i = 0; i < 100; i++) {
      if (container.read(sseEventsProvider).valueOrNull is ChatEventReady) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(requestedCursors, [100]);
    // While the stream has a gap, the peer's message is stored by the server
    // and our own subsequent HTTP send still succeeds.
    api.history.add(message(101));
    await container.read(chat.notifier).sendText('our reply');
    expect(cache.cursor, 100);
    expect(container.read(chat).requireValue.map((m) => m.mid), [102, 100]);
    // Simulate provider recreation (network-restored/token/lifecycle watcher).
    container.invalidate(sseEventsProvider);
    container.read(sseEventsProvider);
    for (var i = 0; i < 100; i++) {
      if (requestedCursors.length == 2 &&
          container.read(sseEventsProvider).valueOrNull is ChatEventReady) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(requestedCursors, [100, 100]);
    await waitFor(
        () => container.read(chat).requireValue.any((m) => m.mid == 101));
    expect(
        container.read(chat).requireValue.map((m) => m.mid), [102, 101, 100]);
  });
}
