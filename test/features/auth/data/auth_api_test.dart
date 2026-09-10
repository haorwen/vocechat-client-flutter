import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/features/auth/data/auth_api.dart';

void main() {
  group('password login compatibility', () {
    const email = 'admin@example.com';
    const password = '  demo-密码🔑  ';

    Future<void> signIn(Dio dio) async {
      await AuthApi(dio).loginWithPassword(
        email: email,
        password: password,
        device: 'flutter',
        deviceToken: 'test-device-token',
      );
    }

    test('uses one request when the MD5 credential succeeds', () async {
      final adapter = _LoginAdapter([200]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);

      await signIn(dio);

      expect(adapter.passwords, [AuthApi.hashPassword(password)]);
    });

    test('401 retries once with the exact original password and same device',
        () async {
      final adapter = _LoginAdapter([401, 200]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);

      await signIn(dio);

      expect(adapter.passwords, [AuthApi.hashPassword(password), password]);
      for (final request in adapter.requests) {
        expect(request.path, '/api/token/login');
        expect(request.method, 'POST');
        expect(request.extra[kSkipRefreshOn401], isTrue);
      }
      for (final body in adapter.bodies) {
        expect(body['credential']['email'], email);
        expect(body['credential']['type'], 'password');
        expect(body['device'], 'flutter');
        expect(body['device_token'], 'test-device-token');
      }
    });

    test('a rejected original password stops after two requests', () async {
      final adapter = _LoginAdapter([401, 401]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);

      await expectLater(
        signIn(dio),
        throwsA(isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          401,
        )),
      );
      expect(adapter.passwords, [AuthApi.hashPassword(password), password]);
    });

    for (final status in [403, 404, 423, 429, 500]) {
      test('$status does not send the original password', () async {
        final adapter = _LoginAdapter([status]);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(dio.close);

        await expectLater(
          signIn(dio),
          throwsA(isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            status,
          )),
        );
        expect(adapter.passwords, [AuthApi.hashPassword(password)]);
      });
    }

    test('connection timeout does not send the original password', () async {
      final adapter = _LoginAdapter([null]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);

      await expectLater(
        signIn(dio),
        throwsA(isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.connectionTimeout,
        )),
      );
      expect(adapter.passwords, [AuthApi.hashPassword(password)]);
    });
  });

  test('deleteCurrentAccount sends DELETE to the current-user endpoint',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://chat.example.com/api'));
    late RequestOptions request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 204),
          );
        },
      ),
    );

    await AuthApi(dio).deleteCurrentAccount();

    expect(request.method, 'DELETE');
    expect(request.path, '/api/user/delete');
  });
}

class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter(this.statuses);

  final List<int?> statuses;
  final requests = <RequestOptions>[];
  final bodies = <Map<String, dynamic>>[];

  List<String> get passwords => [
        for (final body in bodies) body['credential']['password'] as String,
      ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = <int>[];
    await for (final chunk in requestStream!) {
      bytes.addAll(chunk);
    }
    bodies.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    final status = statuses[requests.length - 1];
    if (status == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    }
    return ResponseBody.fromString(
      status == 200
          ? jsonEncode({
              'server_id': 'test-server',
              'token': 'test-access-token',
              'refresh_token': 'test-refresh-token',
              'expired_in': 3600,
              'user': {'uid': 1, 'name': 'Admin', 'is_admin': true},
            })
          : '',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
