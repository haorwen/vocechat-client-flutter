import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/data/auth_api.dart';

const _account = AccountConfig(
  accountId: 'server::7',
  serverId: 'server',
  uid: 7,
  name: 'Saved name',
  email: 'saved@example.com',
);
const _server = ServerConfig(
  id: 'server',
  baseUrl: 'https://chat.example.com',
  name: 'Chat',
);
const _me = {'uid': 7, 'name': 'Current name', 'email': 'saved@example.com'};
const _renewed = {
  'token': 'new-access',
  'refresh_token': 'new-refresh',
  'expired_in': 3600,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('temporarily locked Keychain preserves account through cold start',
      () async {
    final fixture = await _Fixture.create((request) async => _json(_me));
    fixture.tokens.readError = PlatformException(code: '-25308');

    final state = await fixture.restore();
    expect((state as AuthStateAuthenticated).user.name, 'Saved name');
    expect(fixture.tokens.clearCount, 0);

    fixture.tokens.readError = null;
    await fixture.controller.bootstrap();
    expect(fixture.container.read(authControllerProvider).requireValue,
        isA<AuthStateAuthenticated>());
  });

  test('Keychain read failure rejects requests promptly without sending them',
      () async {
    var requests = 0;
    final fixture = await _Fixture.create((request) async {
      requests++;
      return _json(_me);
    });
    fixture.tokens.readError = PlatformException(code: '-25308');

    await expectLater(AuthApi(fixture.dio).me(), throwsA(isA<DioException>()));
    expect(requests, 0);
    expect(fixture.tokens.clearCount, 0);
  });

  test('cold start retries connection timeouts before restoring the session',
      () async {
    var requests = 0;
    final fixture = await _Fixture.create((request) async {
      expect(request.path, '/api/user/me');
      requests++;
      if (requests < 3) {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionTimeout,
        );
      }
      return _json(_me);
    });

    final state = await fixture.restore();

    expect((state as AuthStateAuthenticated).user.name, 'Current name');
    expect(requests, 3);
    expect(fixture.tokens.clearCount, 0);
  });

  test('unreachable server preserves saved session without needless renewal',
      () async {
    var requests = 0;
    final fixture = await _Fixture.create((request) async {
      expect(request.path, '/api/user/me');
      requests++;
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
    });

    final state = await fixture.restore();

    expect((state as AuthStateAuthenticated).user.name, 'Saved name');
    expect(requests, 3);
    expect(fixture.tokens.tokens?.refreshToken, 'saved-refresh');
    expect(fixture.tokens.clearCount, 0);
  });

  test('expired token survives renewal timeouts and recovers when online',
      () async {
    var online = false;
    var renewRequests = 0;
    final fixture = await _Fixture.create((request) async {
      if (request.path == '/api/token/renew') {
        renewRequests++;
        expect(request.headers['X-API-Key'], isNull);
        if (!online) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.sendTimeout,
          );
        }
        return _json(_renewed);
      }
      return _json(_me);
    }, expired: true);

    expect(await fixture.restore(), isA<AuthStateAuthenticated>());
    expect(renewRequests, 3);
    expect(fixture.tokens.tokens?.refreshToken, 'saved-refresh');

    online = true;
    expect(await fixture.controller.renewIfPossible(), isTrue);
    await fixture.controller.refreshUser();
    expect(fixture.tokens.tokens?.accessToken, 'new-access');
    final state = fixture.container.read(authControllerProvider).requireValue;
    expect((state as AuthStateAuthenticated).user.name, 'Current name');
  });

  test('401 followed by renewal outage is not mistaken for invalid auth',
      () async {
    var renewRequests = 0;
    final fixture = await _Fixture.create((request) async {
      if (request.path == '/api/user/me') return _json({}, status: 401);
      renewRequests++;
      return _json({'message': 'temporarily unavailable'}, status: 503);
    });

    expect(await fixture.restore(), isA<AuthStateAuthenticated>());
    expect(renewRequests, 3);
    expect(fixture.tokens.tokens?.refreshToken, 'saved-refresh');
    expect(fixture.tokens.clearCount, 0);
  });

  test('rejected proactive renewal clears credentials and requires login',
      () async {
    var renewRequests = 0;
    final fixture = await _Fixture.create((request) async {
      expect(request.path, '/api/token/renew');
      renewRequests++;
      return _json({}, status: 401);
    }, expired: true);

    expect(await fixture.restore(), isA<AuthStateUnauthenticated>());
    expect(renewRequests, 1);
    expect(fixture.tokens.tokens, isNull);
  });

  test('rejected renewal after offline recovery ends the saved session',
      () async {
    var rejectRenewal = false;
    final fixture = await _Fixture.create((request) async {
      if (rejectRenewal) return _json({}, status: 401);
      return _json(_me);
    });

    expect(await fixture.restore(), isA<AuthStateAuthenticated>());
    rejectRenewal = true;

    expect(await fixture.controller.renewIfPossible(), isFalse);
    expect(fixture.container.read(authControllerProvider).requireValue,
        isA<AuthStateUnauthenticated>());
    expect(fixture.tokens.tokens, isNull);
  });

  test('a second 401 after renewal terminates instead of looping', () async {
    var meRequests = 0;
    var renewRequests = 0;
    final fixture = await _Fixture.create((request) async {
      if (request.path == '/api/token/renew') {
        renewRequests++;
        return _json(_renewed);
      }
      meRequests++;
      return _json({}, status: 401);
    });

    expect(await fixture.restore(), isA<AuthStateUnauthenticated>());
    expect(meRequests, 2);
    expect(renewRequests, 1);
    expect(fixture.tokens.tokens, isNull);
  });

  test('concurrent unauthorized requests share one renewal', () async {
    final bothUnauthorized = Completer<void>();
    var oldTokenRequests = 0;
    var renewRequests = 0;
    final fixture = await _Fixture.create((request) async {
      if (request.path == '/api/token/renew') {
        renewRequests++;
        await bothUnauthorized.future;
        return _json(_renewed);
      }
      if (request.headers['X-API-Key'] == 'saved-access') {
        oldTokenRequests++;
        if (oldTokenRequests == 2) bothUnauthorized.complete();
        return _json({}, status: 401);
      }
      return _json(_me);
    });

    final users = await Future.wait([
      AuthApi(fixture.dio).me(),
      AuthApi(fixture.dio).me(),
    ]);

    expect(users.map((user) => user.uid), [7, 7]);
    expect(renewRequests, 1);
    expect(fixture.tokens.tokens?.refreshToken, 'new-refresh');
  });

  test('malformed renewal releases the lock and preserves credentials',
      () async {
    var validRenewal = false;
    final fixture = await _Fixture.create((request) async {
      if (request.path == '/api/token/renew') {
        return _json(validRenewal ? _renewed : {'token': 123});
      }
      return request.headers['X-API-Key'] == 'saved-access'
          ? _json({}, status: 401)
          : _json(_me);
    });

    await expectLater(AuthApi(fixture.dio).me(), throwsA(isA<DioException>()));
    expect(fixture.tokens.tokens?.refreshToken, 'saved-refresh');
    validRenewal = true;
    expect((await AuthApi(fixture.dio).me()).uid, 7);
  });

  test('retrying startup reads does not replay timed-out message sends',
      () async {
    var requests = 0;
    final fixture = await _Fixture.create((request) async {
      requests++;
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
      );
    });

    await expectLater(
      fixture.dio.post('/api/user/9/send', data: 'hello'),
      throwsA(isA<DioException>()),
    );
    expect(requests, 1);
  });
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _Fixture {
  _Fixture(this.container, this.tokens, this.dio);

  final ProviderContainer container;
  final _MemoryTokenStore tokens;
  final Dio dio;

  AuthController get controller =>
      container.read(authControllerProvider.notifier);

  static Future<_Fixture> create(
    Future<ResponseBody> Function(RequestOptions) respond, {
    bool expired = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'voce_accounts': [jsonEncode(_account.toJson())],
      'voce_current_account': _account.accountId,
      'voce_servers': [jsonEncode(_server.toJson())],
      'voce_current_server': _server.id,
    });
    final tokens = _MemoryTokenStore(expired: expired);
    final container = ProviderContainer(overrides: [
      secureTokenStoreProvider(_account.accountId)
          .overrideWith((ref) => tokens),
      authControllerProvider.overrideWith(_TestAuthController.new),
    ]);
    addTearDown(container.dispose);
    container.listen(accountStoreProvider, (_, __) {});
    container.listen(serverStoreProvider, (_, __) {});
    await container.read(accountStoreProvider.future);
    await container.read(serverStoreProvider.future);
    final dio = container.read(dioProvider);
    dio.httpClientAdapter = _Adapter(respond);
    addTearDown(() => dio.close(force: true));
    return _Fixture(container, tokens, dio);
  }

  Future<AuthState> restore() {
    container.listen(authControllerProvider, (_, __) {});
    return container.read(authControllerProvider.future);
  }
}

class _TestAuthController extends AuthController {
  // Identity replacement is an independent startup concern. Exercise the
  // real auth/bootstrap + Dio stack without contacting the public org API.
  @override
  Future<bool> checkServerIdentity([String? baseUrl]) async => false;
}

class _MemoryTokenStore extends SecureTokenStore {
  _MemoryTokenStore({required bool expired}) : super(id: _account.accountId) {
    tokens = TokenData(
      accessToken: 'saved-access',
      refreshToken: 'saved-refresh',
      expiresAt: DateTime.now().add(Duration(hours: expired ? -1 : 1)),
    );
  }

  TokenData? tokens;
  Object? readError;
  int clearCount = 0;

  @override
  Future<TokenData?> readTokens() async {
    if (readError != null) throw readError!;
    return tokens;
  }

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
    required DateTime expiresAt,
  }) async {
    tokens = TokenData(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> clear() async {
    clearCount++;
    tokens = null;
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      respond(options);

  @override
  void close({bool force = false}) {}
}
