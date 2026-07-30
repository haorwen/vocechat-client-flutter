import 'package:dio/dio.dart';

/// Validates an invitation magic token against the server it targets.
///
/// Uses a disposable [Dio] instance rather than [dioClientProvider] — the
/// target server may not be the currently-selected one (or there may be no
/// selected server at all yet), mirroring the "test connection" probe in
/// `server_picker_screen.dart`'s `_AddServerSheet`.
class InviteLinkApi {
  InviteLinkApi(this.serverBaseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: serverBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  final String serverBaseUrl;
  final Dio _dio;

  /// `POST /api/user/check_magic_token` — returns whether the token is still
  /// valid (not expired, not already consumed).
  Future<bool> checkMagicToken(String magicToken) async {
    final resp = await _dio.post(
      '/api/user/check_magic_token',
      data: {'magic_token': magicToken},
    );
    return resp.data == true;
  }
}
