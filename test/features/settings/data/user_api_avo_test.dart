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

  test('saving sends the generated identity and parses the saved profile',
      () async {
    final generated = AvoParams.fromName('张三');
    final dio = Dio();
    addTearDown(dio.close);
    late RequestOptions request;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      request = options;
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'uid': 7,
        'name': '张三',
        'avo_params': options.data,
      }));
    }));
    final user = await UserApi(dio).updateAvo(generated);
    expect(request.path, '/api/user/avo');
    expect(request.method, 'PUT');
    expect(request.data, generated.toJson());
    expect(user.avoParams, generated);
  });
}
