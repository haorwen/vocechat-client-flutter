import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/android_release.dart';

class AndroidUpdateApi {
  AndroidUpdateApi(this._dio);

  final Dio _dio;
  static const endpoint = 'https://update.voce.chat/client/android';

  Future<AndroidRelease> check() async {
    final response = await _dio.get<Object?>(
      endpoint,
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 10),
        followRedirects: false,
        validateStatus: (status) => status == 200,
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          // This public, fixed-origin endpoint must never receive chat tokens.
          'X-API-Key': null,
          'Referer': 'https://update.voce.chat/',
        },
        extra: {kSkipRefreshOn401: true},
      ),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected an Android update JSON object');
    }
    return AndroidRelease.fromJson(data);
  }
}
