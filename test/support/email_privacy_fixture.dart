import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/contacts/application/contacts_provider.dart';
import 'package:vocechat_client/features/messages/application/message_dispatcher.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

const self = AccountConfig(
    accountId: 'server::1',
    serverId: 'server',
    uid: 1,
    name: 'Self',
    email: 'self@example.com');
const other = AccountConfig(
    accountId: 'other::2',
    serverId: 'other',
    uid: 2,
    name: 'Other',
    email: 'other@example.com');

Future<void> flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class TestAuth extends AuthController {
  @override
  Future<bool> checkServerIdentity([String? requestedBaseUrl]) async => false;
}

class Tokens extends SecureTokenStore {
  Tokens(String id) : super(id: id);
  int clears = 0;
  RememberedCredential? remembered;
  @override
  Future<RememberedCredential?> readRememberedCredential() async => remembered;
  @override
  Future<void> clearRememberedCredential() async {
    remembered = null;
  }

  @override
  Future<TokenData?> readTokens() async => TokenData(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAt: DateTime.now().add(const Duration(days: 1)));
  @override
  Future<void> clear() async {
    clears++;
  }
}

class Cache implements MessageCache {
  List<Map<String, dynamic>>? users;
  @override
  Future<List<Map<String, dynamic>>?> readUserDirectory() async => users;
  @override
  Future<void> writeUserDirectory(List<Map<String, dynamic>> users) async {
    this.users = users;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Fixture {
  late ProviderContainer container;
  final events = StreamController<ChatEvent>();
  final dio = Dio();
  final tokens = Tokens(self.accountId);
  final remembered = Tokens('server')
    ..remembered = const RememberedCredential(
        email: 'login-input@example.com', password: 'remembered-password');
  final gates = <String, Queue<Completer<void>>>{};
  final requests = <String, int>{};
  bool hidden = false;
  bool admin = false;
  bool fail = false;
  int uid = 1;

  Map<String, dynamic> get me => {
        'uid': uid,
        'name': uid == 1 ? 'Self' : 'Other',
        'email': hidden && !admin
            ? null
            : uid == 1
                ? self.email
                : other.email,
        'is_admin': admin
      };
  List<Map<String, dynamic>> get users => [
        me,
        {
          'uid': 7,
          'name': 'Helper',
          'email': hidden && !admin ? null : 'helper@example.com',
          'is_bot': true
        }
      ];

  AuthController get auth => container.read(authControllerProvider.notifier);
  String? get email => (container.read(authControllerProvider).requireValue
          as AuthStateAuthenticated)
      .user
      .email;
  List<ContactInfo> get contacts =>
      container.read(contactsProvider).requireValue;
  AccountConfig get saved => container
      .read(accountStoreProvider)
      .requireValue
      .accounts
      .firstWhere((a) => a.accountId == self.accountId);

  Completer<void> gate(String path) {
    final gate = Completer<void>();
    (gates[path] ??= Queue()).add(gate);
    return gate;
  }

  Future<void> start(
      {bool isAdmin = false, bool initiallyHidden = false}) async {
    admin = isAdmin;
    hidden = initiallyHidden;
    SharedPreferences.setMockInitialValues({
      'voce_accounts': [
        jsonEncode(self.copyWith(isAdmin: admin).toJson()),
        jsonEncode(other.toJson())
      ],
      'voce_current_account': self.accountId,
      'voce_servers': [
        for (final id in ['server', 'other'])
          jsonEncode(ServerConfig(id: id, baseUrl: 'https://$id.test', name: id)
              .toJson())
      ],
      'voce_current_server': 'server',
    });
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      requests.update(options.path, (n) => n + 1, ifAbsent: () => 1);
      // Capture the old response BEFORE awaiting, to model an in-flight reply.
      final body =
          jsonDecode(jsonEncode(options.path == '/api/user/me' ? me : users));
      final failed = fail;
      final queue = gates[options.path];
      if (queue != null && queue.isNotEmpty) await queue.removeFirst().future;
      if (failed) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionError));
      } else {
        handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: body));
      }
    }));
    container = ProviderContainer(overrides: [
      dioProvider.overrideWith((ref) => dio),
      authControllerProvider.overrideWith(TestAuth.new),
      secureTokenStoreProvider('server').overrideWith((ref) => remembered),
      secureTokenStoreProvider(self.accountId).overrideWith((ref) => tokens),
      secureTokenStoreProvider(other.accountId)
          .overrideWith((ref) => Tokens(other.accountId)),
      secureTokenStoreProvider('server::2')
          .overrideWith((ref) => Tokens('server::2')),
      messageCacheProvider.overrideWith((ref) async => Cache()),
      sseEventsProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(() async {
      container.dispose();
      await events.close();
      dio.close();
    });
    container.listen(accountStoreProvider, (_, __) {});
    container.listen(serverStoreProvider, (_, __) {});
    await container.read(accountStoreProvider.future);
    await container.read(serverStoreProvider.future);
    container.listen(authControllerProvider, (_, __) {});
    await container.read(authControllerProvider.future);
    container.listen(contactsProvider, (_, __) {});
    container.read(messageDispatcherProvider);
    await flush();
  }

  Future<void> config(bool flag) async {
    hidden = flag;
    events.add(ChatEvent.serverConfigChanged(data: {'hide_user_email': flag}));
    await flush();
  }

  Future<void> snapshot({List<Map<String, dynamic>> extra = const []}) async {
    events
        .add(ChatEvent.usersSnapshot(version: 1, users: [...users, ...extra]));
    await flush();
  }
}
