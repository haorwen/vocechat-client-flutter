import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_token_store.dart';
import '../storage/server_store.dart';

part 'dio_client.g.dart';

// ---------------------------------------------------------------------------
// ApiException
// ---------------------------------------------------------------------------

class ApiException implements Exception {
  const ApiException({
    required this.status,
    this.code,
    required this.message,
  });

  final int status;
  final String? code;
  final String message;

  @override
  String toString() => 'ApiException($status): $message';
}

// ---------------------------------------------------------------------------
// VoceDioClient — wraps a Dio instance with interceptors
// ---------------------------------------------------------------------------

class VoceDioClient {
  VoceDioClient({required String baseUrl, required this._ref})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _configure();
  }

  final Dio _dio;
  final Ref _ref;

  Dio get dio => _dio;

  static String _baseUrl = '';

  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  void _configure() {
    _dio.interceptors.add(_AuthInterceptor(_dio, _ref));
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: (msg) => Logger().d(msg),
        retries: 2,
        retryDelays: const [
          Duration(milliseconds: 500),
          Duration(milliseconds: 1500),
        ],
        retryEvaluator: (error, attempt) =>
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.receiveTimeout ||
            (error.response?.statusCode != null &&
                error.response!.statusCode! >= 500),
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => Logger().d(o.toString()),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// AuthInterceptor
// ---------------------------------------------------------------------------

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final serverId = _ref.read(serverStoreProvider).valueOrNull?.currentServerId;
    if (serverId != null) {
      final store = _ref.read(secureTokenStoreProvider(serverId));
      final tokens = await store.readTokens();
      if (tokens != null) {
        options.headers['X-API-Key'] = tokens.accessToken;
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;

    if (statusCode == 401 && !_isRefreshing) {
      final serverId =
          _ref.read(serverStoreProvider).valueOrNull?.currentServerId;
      if (serverId == null) {
        handler.next(err);
        return;
      }
      final store = _ref.read(secureTokenStoreProvider(serverId));
      final tokens = await store.readTokens();
      if (tokens == null) {
        handler.next(err);
        return;
      }

      _isRefreshing = true;
      try {
        final renewResp = await _dio.post(
          '/api/token/renew',
          data: {'refresh_token': tokens.refreshToken},
          options: Options(headers: {'X-API-Key': null}),
        );
        final newAccess = renewResp.data['token'] as String;
        final newRefresh = renewResp.data['refresh_token'] as String;
        final expiredIn = renewResp.data['expired_in'] as int;
        await store.saveTokens(
          access: newAccess,
          refresh: newRefresh,
          expiresAt: DateTime.now().add(Duration(seconds: expiredIn)),
        );

        // Retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['X-API-Key'] = newAccess;
        final retryResponse = await _dio.fetch(retryOptions);
        _isRefreshing = false;
        handler.resolve(retryResponse);
        return;
      } on DioException catch (retryErr) {
        _isRefreshing = false;
        if (retryErr.response?.statusCode == 401) {
          // Second 401 – clear auth
          await store.clear();
        }
        handler.next(retryErr);
        return;
      }
    }

    // Convert non-2xx to ApiException
    if (statusCode != null && statusCode >= 400) {
      final data = err.response?.data;
      final message = (data is Map<String, dynamic>)
          ? (data['error'] as String? ?? 'Unknown error')
          : 'HTTP $statusCode';
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: ApiException(
            status: statusCode,
            message: message,
          ),
          response: err.response,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }

    handler.next(err);
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

@riverpod
VoceDioClient dioClient(Ref ref) {
  final serverState = ref.watch(serverStoreProvider).valueOrNull;
  final currentServer = serverState?.servers
      .where((s) => s.id == serverState.currentServerId)
      .firstOrNull;
  final baseUrl = currentServer?.baseUrl ?? VoceDioClient._baseUrl;
  return VoceDioClient(baseUrl: baseUrl, ref: ref);
}

@riverpod
Dio dio(Ref ref) {
  return ref.watch(dioClientProvider).dio;
}
