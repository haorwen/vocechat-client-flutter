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
    );
    return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final resp = await _dio.post(
      '/api/user/register',
      data: {
        'email': email,
        'password': hashPassword(password),
        'name': name,
      },
    );
    return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<RenewResponse> renew(String refreshToken) async {
    final resp = await _dio.post(
      '/api/token/renew',
      data: {'refresh_token': refreshToken},
    );
    return RenewResponse.fromJson(resp.data as Map<String, dynamic>);
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
