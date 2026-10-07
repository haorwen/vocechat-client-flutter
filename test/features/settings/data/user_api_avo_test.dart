import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/settings/data/user_api.dart';
import 'package:vocechat_client/shared/models/avo_params.dart';

void main() {
  Dio mockApi(Object? data, {bool legacy = false}) {
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (legacy && options.path == '/api/user/avo') {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 404),
        ));
      } else {
        handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data));
      }
    }));
    return dio;
  }

  Dio mockSavingApi({
    required List<RequestOptions> requests,
    Object? preflightData = const {'avo_params': null},
    int preflightStatus = 200,
    DioExceptionType? preflightFailure,
    Object? saveData = const {'uid': 7, 'name': 'Alice'},
    int saveStatus = 200,
    DioExceptionType? saveFailure,
    Object? versionData = '0.5.22',
    int versionStatus = 200,
    DioExceptionType? versionFailure,
  }) {
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final Object? data;
      final int status;
      final DioExceptionType? failure;
      if (options.path == '/api/user/avo' && options.method == 'GET') {
        data = preflightData;
        status = preflightStatus;
        failure = preflightFailure;
      } else if (options.path == '/api/user/avo' && options.method == 'PUT') {
        data = saveData;
        status = saveStatus;
        failure = saveFailure;
      } else if (options.path == '/api/admin/system/version' &&
          options.method == 'GET') {
        data = versionData;
        status = versionStatus;
        failure = versionFailure;
      } else {
        handler.reject(DioException(
          requestOptions: options,
          error: StateError('Unexpected ${options.method} ${options.path}'),
        ));
        return;
      }

      if (failure != null || status >= 400) {
        handler.reject(DioException(
          requestOptions: options,
          type: failure ?? DioExceptionType.badResponse,
          response: failure == null
              ? Response(
                  requestOptions: options, statusCode: status, data: data)
              : null,
        ));
      } else {
        handler.resolve(
            Response(requestOptions: options, statusCode: status, data: data));
      }
    }));
    return dio;
  }

  List<String> requestSequence(List<RequestOptions> requests) =>
      requests.map((request) => '${request.method} ${request.path}').toList();

  for (final data in [
    null,
    <String, dynamic>{},
    {'avo_params': null},
    {'avo_params': {}}
  ]) {
    test('missing Avo ($data) generates from the current user name', () async {
      final params = await UserApi(mockApi(data)).getAvo(fallbackName: '张三');
      expect(params, AvoParams.fromName('张三'));
    });
  }

  test('older servers generate from the name returned by /me', () async {
    final api = UserApi(mockApi({'uid': 7, 'name': 'Alice'}, legacy: true));
    expect(await api.getAvo(fallbackName: 'Old name'),
        AvoParams.fromName('Alice'));
  });

  final custom = AvoParams.fromName('张三').copyWith(hue: 151, energy: .85);
  for (final wrapped in [false, true]) {
    test('saved custom parameters are preserved (wrapped=$wrapped)', () async {
      final data = wrapped ? {'avo_params': custom.toJson()} : custom.toJson();
      final api = UserApi(mockApi(data));
      expect(await api.getAvo(fallbackName: 'Alice'), custom);
    });
  }

  test('older servers preserve custom parameters returned by /me', () async {
    final api = UserApi(mockApi({
      'uid': 7,
      'name': 'Alice',
      'avo_params': custom.toJson(),
    }, legacy: true));
    expect(await api.getAvo(), custom);
  });

  test('profile reads preserve saved Avo in server and local JSON', () {
    final user = VoceUser.fromJson({
      'uid': 7,
      'name': 'Alice',
      'avo_params': custom.toJson(),
    });
    expect(user.avoParams, custom);
    expect(VoceUser.fromJson(user.toJson()).avoParams, custom);
  });

  test('saving checks support before sending the generated identity', () async {
    final generated = AvoParams.fromName('张三');
    final requests = <RequestOptions>[];
    final api = UserApi(mockSavingApi(
      requests: requests,
      saveData: {
        'uid': 7,
        'name': '张三',
        'avo_params': generated.toJson(),
      },
    ));

    await api.updateAvo(generated);

    expect(requestSequence(requests), [
      'GET /api/user/avo',
      'PUT /api/user/avo',
    ]);
    expect(requests.last.data, generated.toJson());
  });

  group('saving Avo', () {
    for (final preflight in {
      'null wrapped parameters': {'avo_params': null},
      'empty wrapped parameters': {'avo_params': <String, dynamic>{}},
      'wrapped parameters': {'avo_params': custom.toJson()},
      'bare parameters': custom.toJson(),
    }.entries) {
      test('recognizes ${preflight.key} as server support', () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          preflightData: preflight.value,
          saveData: custom.toJson(),
        ));

        await api.updateAvo(custom);

        expect(requestSequence(requests), [
          'GET /api/user/avo',
          'PUT /api/user/avo',
        ]);
      });
    }

    for (final response in {
      'bare parameters without a user uid': custom.toJson(),
      'wrapped parameters without a user uid': {'avo_params': custom.toJson()},
      'full user': {'uid': 7, 'name': 'Alice'},
      'wrapped user': {
        'user': {'uid': 7, 'name': 'Alice', 'avo_params': custom.toJson()},
      },
    }.entries) {
      test('accepts ${response.key} without parsing missing user fields',
          () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          saveData: response.value,
        ));

        await api.updateAvo(custom);

        expect(requestSequence(requests), [
          'GET /api/user/avo',
          'PUT /api/user/avo',
        ]);
      });
    }

    test('accepts an empty 204 response after support is confirmed', () async {
      final requests = <RequestOptions>[];
      final api = UserApi(mockSavingApi(
        requests: requests,
        saveStatus: 204,
        saveData: null,
      ));

      await api.updateAvo(custom);

      expect(requestSequence(requests), [
        'GET /api/user/avo',
        'PUT /api/user/avo',
      ]);
    });

    for (final status in [404, 405, 501]) {
      test('GET $status reports the server version and prevents saving',
          () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          preflightStatus: status,
          versionData: ' 0.5.22\n',
        ));

        await expectLater(
          api.updateAvo(custom),
          throwsA(isA<AvoUnsupportedException>().having(
              (error) => error.serverVersion, 'serverVersion', '0.5.22')),
        );

        expect(requestSequence(requests), [
          'GET /api/user/avo',
          'GET /api/admin/system/version',
        ]);
        expect(requests.last.responseType, ResponseType.plain);
        expect(requests.last.headers['accept'], 'text/plain');
      });

      test('PUT $status reports unsupported instead of a parsing error',
          () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          saveStatus: status,
        ));

        await expectLater(
            api.updateAvo(custom), throwsA(isA<AvoUnsupportedException>()));

        expect(requestSequence(requests), [
          'GET /api/user/avo',
          'PUT /api/user/avo',
          'GET /api/admin/system/version',
        ]);
      });
    }

    test('legacy GET uid parse error reports unsupported without a PUT',
        () async {
      final requests = <RequestOptions>[];
      final api = UserApi(mockSavingApi(
        requests: requests,
        preflightStatus: 400,
        preflightData: 'failed to parse path `uid`: '
            'failed to parse "integer(int64)": invalid digit found in string',
      ));

      await expectLater(
        api.updateAvo(custom),
        throwsA(isA<AvoUnsupportedException>()
            .having((error) => error.serverVersion, 'serverVersion', '0.5.22')),
      );

      expect(requestSequence(requests), [
        'GET /api/user/avo',
        'GET /api/admin/system/version',
      ]);
    });

    for (final response in {
      'null': null,
      'HTML': '<html>VoceChat</html>',
      'empty object': <String, dynamic>{},
      'unrelated object': {'uid': 7, 'name': 'Alice'},
      'incomplete bare parameters': {'name': 'Alice', 'hue': 151},
      'invalid wrapped parameters': {'avo_params': 'unsupported'},
    }.entries) {
      test('unrecognized GET ${response.key} prevents saving', () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          preflightData: response.value,
        ));

        await expectLater(
            api.updateAvo(custom), throwsA(isA<AvoUnsupportedException>()));

        expect(requestSequence(requests), [
          'GET /api/user/avo',
          'GET /api/admin/system/version',
        ]);
      });
    }

    for (final response in {
      'null': null,
      'HTML': '<html>VoceChat</html>',
      'empty object': <String, dynamic>{},
      'missing numeric user uid': {'name': 'Alice'},
      'null wrapped parameters': {'avo_params': null},
      'empty wrapped parameters': {'avo_params': <String, dynamic>{}},
      'unrelated wrapped parameters': {
        'avo_params': {'error': 'unsupported'},
      },
      'incomplete wrapped parameters': {
        'avo_params': {'name': 'Alice', 'hue': 151},
      },
    }.entries) {
      test('unrecognized PUT ${response.key} reports unsupported', () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          saveData: response.value,
        ));

        await expectLater(
            api.updateAvo(custom), throwsA(isA<AvoUnsupportedException>()));

        expect(requestSequence(requests), [
          'GET /api/user/avo',
          'PUT /api/user/avo',
          'GET /api/admin/system/version',
        ]);
      });
    }

    for (final status in [400, 401, 403, 500]) {
      test('GET $status preserves the error without version lookup or PUT',
          () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          preflightStatus: status,
          preflightData: {'reason': 'request_failed'},
        ));

        await expectLater(
          api.updateAvo(custom),
          throwsA(isA<DioException>().having(
              (error) => error.response?.statusCode, 'statusCode', status)),
        );

        expect(requestSequence(requests), ['GET /api/user/avo']);
      });
    }

    for (final status in [400, 401, 403, 500]) {
      test('PUT $status preserves the error without version lookup', () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          saveStatus: status,
          saveData: {'reason': 'request_failed'},
        ));

        await expectLater(
          api.updateAvo(custom),
          throwsA(isA<DioException>().having(
              (error) => error.response?.statusCode, 'statusCode', status)),
        );

        expect(requestSequence(requests), [
          'GET /api/user/avo',
          'PUT /api/user/avo',
        ]);
      });
    }

    test('GET connection failure prevents saving and preserves the error',
        () async {
      final requests = <RequestOptions>[];
      final api = UserApi(mockSavingApi(
        requests: requests,
        preflightFailure: DioExceptionType.connectionError,
      ));

      await expectLater(
        api.updateAvo(custom),
        throwsA(isA<DioException>().having(
            (error) => error.type, 'type', DioExceptionType.connectionError)),
      );

      expect(requestSequence(requests), ['GET /api/user/avo']);
    });

    test('token renewal 404 remains an error without version lookup or PUT',
        () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      addTearDown(dio.close);
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        requests.add(options);
        final renewal =
            RequestOptions(path: '/api/token/renew', method: 'POST');
        handler.reject(DioException(
          requestOptions: renewal,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: renewal, statusCode: 404),
        ));
      }));

      await expectLater(
        UserApi(dio).updateAvo(custom),
        throwsA(isA<DioException>().having(
            (error) => error.requestOptions.path, 'path', '/api/token/renew')),
      );

      expect(requestSequence(requests), ['GET /api/user/avo']);
    });

    test('PUT connection failure preserves the error without version lookup',
        () async {
      final requests = <RequestOptions>[];
      final api = UserApi(mockSavingApi(
        requests: requests,
        saveFailure: DioExceptionType.connectionError,
      ));

      await expectLater(
        api.updateAvo(custom),
        throwsA(isA<DioException>().having(
            (error) => error.type, 'type', DioExceptionType.connectionError)),
      );

      expect(requestSequence(requests), [
        'GET /api/user/avo',
        'PUT /api/user/avo',
      ]);
    });

    for (final status in [403, 500]) {
      test('version lookup $status does not replace the unsupported error',
          () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          preflightStatus: 404,
          versionStatus: status,
        ));

        await expectLater(
          api.updateAvo(custom),
          throwsA(isA<AvoUnsupportedException>()
              .having((error) => error.serverVersion, 'serverVersion', isNull)),
        );

        expect(requestSequence(requests), [
          'GET /api/user/avo',
          'GET /api/admin/system/version',
        ]);
      });
    }

    test('version connection failure does not replace the unsupported error',
        () async {
      final requests = <RequestOptions>[];
      final api = UserApi(mockSavingApi(
        requests: requests,
        preflightStatus: 404,
        versionFailure: DioExceptionType.connectionError,
      ));

      await expectLater(
        api.updateAvo(custom),
        throwsA(isA<AvoUnsupportedException>()
            .having((error) => error.serverVersion, 'serverVersion', isNull)),
      );

      expect(requestSequence(requests), [
        'GET /api/user/avo',
        'GET /api/admin/system/version',
      ]);
    });

    for (final version in {
      'null': null,
      'empty': '   \n',
      'object': {'version': '0.5.22'},
    }.entries) {
      test('invalid ${version.key} version still reports unsupported',
          () async {
        final requests = <RequestOptions>[];
        final api = UserApi(mockSavingApi(
          requests: requests,
          preflightStatus: 404,
          versionData: version.value,
        ));

        await expectLater(
          api.updateAvo(custom),
          throwsA(isA<AvoUnsupportedException>()
              .having((error) => error.serverVersion, 'serverVersion', isNull)),
        );
      });
    }
  });
}
