import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../domain/auth_models.dart';

part 'auth_api.g.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// Hash password with MD5 hex per server contract.
  static String hashPassword(String raw) {
    final bytes = utf8.encode(raw);
    return md5.convert(bytes).toString();
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final resp = await _dio.post(
      '/api/token/login',
      data: request.toJson(),
      // A 401 here means wrong credentials, not an expired access token —
      // skip the auth interceptor's refresh-and-retry so the real error
      // (ApiException) reaches the caller instead of a generic one.
      options: Options(extra: {kSkipRefreshOn401: true}),
    );
    return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
    String? magicToken,
  }) async {
    final resp = await _dio.post(
      '/api/user/register',
      data: {
        'email': email,
        'password': hashPassword(password),
        'name': name,
        if (magicToken != null) 'magic_token': magicToken,
      },
    );
    return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Re-mints a registration magic token bound to [email]/[password]. On a
  /// server with SMTP confirmation disabled this returns a fresh,
  /// already-confirmed token usable immediately with [register]; with SMTP
  /// enabled it instead emails a confirmation link and withholds the token
  /// (`mailIsSent: true, newMagicToken: ""`) — that flow isn't implemented by
  /// this client yet.
  ///
  /// [password] is hashed the same way as [register]'s — the server embeds
  /// it verbatim as `extra_password` and later feeds it through the exact
  /// same hashing path `register` uses for its own `password` field, so the
  /// two must be in the same (MD5-hex) format or the account ends up with a
  /// password that doesn't match what the user typed.
  Future<SendRegMagicTokenResponse> sendRegMagicLink({
    required String magicToken,
    required String email,
    required String password,
  }) async {
    final resp = await _dio.post(
      '/api/user/send_reg_magic_link',
      data: {
        'magic_token': magicToken,
        'email': email,
        'password': hashPassword(password),
      },
    );
    return SendRegMagicTokenResponse.fromJson(
        resp.data as Map<String, dynamic>);
  }

  Future<RenewResponse> renew(String refreshToken) async {
    final resp = await _dio.post(
      '/api/token/renew',
      data: {'refresh_token': refreshToken},
    );
    return RenewResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> updateDeviceToken(String deviceToken) async {
    await _dio.put(
      '/api/token/device_token',
      data: {'device_token': deviceToken},
    );
  }

  Future<void> logout() async {
    await _dio.get('/api/token/logout');
  }

  Future<VoceUser> me() async {
    final resp = await _dio.get('/api/user/me');
    return VoceUser.fromJson(resp.data as Map<String, dynamic>);
  }
}

@riverpod
AuthApi authApi(Ref ref) {
  return AuthApi(ref.watch(dioProvider));
}
