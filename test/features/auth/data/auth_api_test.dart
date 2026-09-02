import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocechat_client/features/auth/data/auth_api.dart';

void main() {
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
