import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_token_store.dart';
import '../storage/server_store.dart';
import '../utils/app_log.dart';
import '../utils/safe_text.dart';

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
// Redacting log printer — strips sensitive headers/fields
// ---------------------------------------------------------------------------

void _redactingLogPrint(Object msg) {
  if (!AppLog.isEnabled(LogTag.network)) return;
  final s = msg.toString();
  const sensitive = ['X-API-Key', 'password', 'refresh_token'];
  for (final keyword in sensitive) {
    if (s.contains(keyword)) {
      AppLog.d(LogTag.network, () => '[REDACTED — contains $keyword]');
      return;
    }
  }
  AppLog.d(LogTag.network, () => s);
}

// ---------------------------------------------------------------------------
// Recursive JSON UTF-16 sanitizer
// ---------------------------------------------------------------------------

Object? _sanitize(Object? node) {
  if (node is String) return safeText(node);
  if (node is List) return node.map(_sanitize).toList();
  if (node is Map) {
    return <String, dynamic>{
      for (final entry in node.entries)
        entry.key.toString(): _sanitize(entry.value),
    };
  }
  return node;
}

// ---------------------------------------------------------------------------
// VoceDioClient — wraps a Dio instance with interceptors
// ---------------------------------------------------------------------------

class VoceDioClient {
  VoceDioClient({required String baseUrl, required Ref ref})
      : _ref = ref,
        _dio = Dio(
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
        logPrint: _redactingLogPrint,
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
    // The full request/response body dump is the single biggest source of
    // log spam during message sync. Only attach it when the user explicitly
    // turns the network tag on (AppLog.enable(LogTag.network)).
    if (AppLog.isEnabled(LogTag.network)) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: _redactingLogPrint,
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
  Completer<void>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // The server's license check rejects requests with an empty Referer
    // (HTTP 451 "License error: Referer is empty."). Browsers normally
    // populate this from window.location, but on non-web platforms (and on
    // some web builds) Dio sends no Referer at all. Inject one derived from
    // the configured baseUrl so the server accepts the request.
    if (options.headers['Referer'] == null &&
        options.headers['referer'] == null) {
      final baseUrl = options.baseUrl;
      if (baseUrl.isNotEmpty) {
        final uri = Uri.tryParse(baseUrl);
        if (uri != null && uri.host.isNotEmpty) {
          options.headers['Referer'] = '${uri.scheme}://${uri.authority}/';
        }
      }
    }

    final serverId = _ref.read(serverStoreProvider).valueOrNull?.currentServerId;
    if (serverId != null) {
      final store = _ref.read(secureTokenStoreProvider(serverId));
      final tokens = await store.readTokens();
      if (tokens != null) {
        options.headers['X-API-Key'] = tokens.accessToken;
      }
      AppLog.d(
        LogTag.network,
        () =>
            '🌐 ${options.method} ${options.path} hasToken=${tokens != null} tokenLen=${tokens?.accessToken.length ?? 0}',
      );
    } else {
      AppLog.d(
        LogTag.network,
        () => '🌐 ${options.method} ${options.path} NO_SERVER',
      );
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    AppLog.d(
      LogTag.network,
      () =>
          '✅ ${response.requestOptions.method} ${response.requestOptions.path} → ${response.statusCode}',
    );
    // Sanitize any String anywhere in the JSON body to be valid UTF-16, so
    // TextPainter doesn't throw on user-generated content with broken
    // surrogate pairs (broken emoji, control chars, etc).
    response.data = _sanitize(response.data);
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    AppLog.d(
      LogTag.network,
      () =>
          '❌ ${err.requestOptions.method} ${err.requestOptions.path} → ${err.type} status=$statusCode body=${err.response?.data}',
    );

    if (statusCode == 401) {
      final serverId =
          _ref.read(serverStoreProvider).valueOrNull?.currentServerId;
      if (serverId == null) {
        handler.next(err);
        return;
      }
      final store = _ref.read(secureTokenStoreProvider(serverId));

      // If a refresh is already in progress, await it then retry
      if (_refreshing != null) {
        try {
          await _refreshing!.future;
          final tokens = await store.readTokens();
          if (tokens != null) {
            final retryOptions = err.requestOptions;
            retryOptions.headers['X-API-Key'] = tokens.accessToken;
            final retryResponse = await _dio.fetch(retryOptions);
            handler.resolve(retryResponse);
            return;
          }
        } catch (_) {
          // refresh failed; fall through to reject
        }
        handler.next(err);
        return;
      }

      final tokens = await store.readTokens();
      if (tokens == null) {
        handler.next(err);
        return;
      }

      _refreshing = Completer<void>();
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
        _refreshing!.complete();
        _refreshing = null;

        // Retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['X-API-Key'] = newAccess;
        final retryResponse = await _dio.fetch(retryOptions);
        handler.resolve(retryResponse);
        return;
      } on DioException catch (retryErr) {
        _refreshing!.completeError(retryErr);
        _refreshing = null;
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
      String message = 'HTTP $statusCode';
      String? code;
      if (data is Map<String, dynamic>) {
        message = (data['msg'] as String?) ??
            (data['message'] as String?) ??
            (data['error'] as String?) ??
            message;
        code = data['code'] as String?;
      } else if (data is String && data.isNotEmpty) {
        message = data;
      }
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: ApiException(
            status: statusCode,
            code: code,
            message: message,
          ),
          response: err.response,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }

    // Network/timeout/cancel errors — surface a friendly message
    final friendly = switch (err.type) {
      DioExceptionType.connectionTimeout =>
        'Connection timed out. Check your network or server URL.',
      DioExceptionType.receiveTimeout =>
        'Server took too long to respond.',
      DioExceptionType.connectionError =>
        'Cannot reach server. Verify the URL is correct and reachable.',
      DioExceptionType.badCertificate =>
        'TLS certificate is invalid for this server.',
      _ => err.message ?? 'Network error',
    };
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: ApiException(status: 0, message: friendly),
        type: err.type,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
VoceDioClient dioClient(Ref ref) {
  // Only rebuild the client when the resolved baseUrl actually changes.
  // Watching the whole serverStoreProvider would tear down the Dio instance
  // (and any in-flight requests / refresh lock) on unrelated state edits.
  final baseUrl = ref.watch(
    serverStoreProvider.select((async) {
      final state = async.valueOrNull;
      final current = state?.servers
          .where((s) => s.id == state.currentServerId)
          .firstOrNull;
      return current?.baseUrl ?? VoceDioClient._baseUrl;
    }),
  );
  return VoceDioClient(baseUrl: baseUrl, ref: ref);
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  return ref.watch(dioClientProvider).dio;
}
