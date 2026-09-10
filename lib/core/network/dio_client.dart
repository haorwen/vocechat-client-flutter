import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/account_store.dart';
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
        retryEvaluator: (error, attempt) {
          final request = error.requestOptions;
          // A send/upload may have reached the server before its response
          // timed out. Automatically replay only reads and token renewal,
          // whose server endpoint accepts the same refresh token again.
          final canReplay =
              const {'GET', 'HEAD', 'OPTIONS'}.contains(request.method) ||
                  request.path == '/api/token/renew';
          return canReplay &&
              (error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.sendTimeout ||
                  error.type == DioExceptionType.receiveTimeout ||
                  (error.response?.statusCode != null &&
                      error.response!.statusCode! >= 500));
        },
      ),
    );
    // Body dumps are intentionally OFF. A single /api/group or /api/user
    // response can be tens of KB, and synchronously print()-ing that on the
    // Windows desktop main isolate visibly freezes the UI (rotating cursor,
    // "Not Responding"). The request line + status code interceptor above
    // gives enough signal for routine debugging; flip the literal below to
    // `true` only while actively investigating a specific request.
    // ignore: dead_code
    if (false) {
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

/// Marker key set in `RequestOptions.extra` on the `/api/token/renew` call so
/// the interceptor can recognise the renew request and NOT recurse into the
/// refresh logic when the renew itself returns 401 (dead refresh token).
const String _kRenewRequest = '__voce_renew_request__';

/// A freshly renewed token must only be tried once. A second 401 should be
/// returned to the caller instead of starting an unbounded renewal loop.
const String _kRetriedAfterRefresh = '__voce_retried_after_refresh__';

/// Marker key set in `RequestOptions.extra` on requests where a 401 means a
/// definitive rejection (e.g. wrong credentials on `/api/token/login`)
/// rather than an expired access token. Without this, the interceptor would
/// try to silently refresh using an unrelated/absent refresh token and
/// retry the very same login POST, swallowing the real "wrong password"
/// error behind a generic refresh-failure error.
const String kSkipRefreshOn401 = '__voce_skip_refresh_on_401__';

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;
  Future<String>? _refreshing;

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

    final accountId =
        _ref.read(accountStoreProvider).valueOrNull?.currentAccountId;
    final skipAuthHeader = options.headers.containsKey('X-API-Key') &&
        options.headers['X-API-Key'] == null;
    if (accountId != null && !skipAuthHeader) {
      final store = _ref.read(secureTokenStoreProvider(accountId));
      final TokenData? tokens;
      try {
        tokens = await store.readTokens();
      } catch (e, stackTrace) {
        handler.reject(DioException(
          requestOptions: options,
          error: e,
          stackTrace: stackTrace,
        ));
        return;
      }
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
        () => '🌐 ${options.method} ${options.path} no auth header',
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
    // surrogate pairs (broken emoji, control chars, etc). Skip binary
    // responses (file downloads) — _sanitize's recursive List.map turns a
    // `List<int>` payload into `List<Object?>`, which then fails the
    // `response.data as T` cast dio does internally for typed requests
    // like `dio.get<List<int>>(..., responseType: ResponseType.bytes)`.
    final responseType = response.requestOptions.responseType;
    if (responseType != ResponseType.bytes &&
        responseType != ResponseType.stream) {
      response.data = _sanitize(response.data);
    }
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
      // CRITICAL: the renew call below is itself a Dio request and goes
      // through this same interceptor. When the refresh token is also dead,
      // `/api/token/renew` returns 401 (server: RenewTokenApiResponse maps
      // IllegalToken → 401). If we let that 401 re-enter the refresh logic it
      // sees `_refreshing != null` (the outer renew still holds the lock) and
      // awaits `_refreshing` — i.e. the renew awaits ITSELF and
      // deadlocks forever, wedging the whole client. So a 401 ON the renew
      // request must skip refresh handling entirely and fall through to the
      // normal error mapping.
      if (err.requestOptions.extra[_kRenewRequest] == true) {
        AppLog.w(LogTag.token,
            () => '🔑 renew request itself returned 401 — refresh token dead');
      } else if (err.requestOptions.extra[kSkipRefreshOn401] == true ||
          err.requestOptions.extra[_kRetriedAfterRefresh] == true) {
        // e.g. wrong email/password on login — nothing to refresh, and
        // retrying would just resend the same bad credentials.
      } else {
        final accountId =
            _ref.read(accountStoreProvider).valueOrNull?.currentAccountId;
        if (accountId == null) {
          handler.next(err);
          return;
        }
        final store = _ref.read(secureTokenStoreProvider(accountId));
        final TokenData? tokens;
        try {
          tokens = await store.readTokens();
        } catch (e, stackTrace) {
          handler.reject(DioException(
            requestOptions: err.requestOptions,
            error: e,
            stackTrace: stackTrace,
          ));
          return;
        }
        if (tokens == null) {
          handler.next(err);
          return;
        }

        // All concurrent 401s await the same success OR failure. In particular,
        // a timeout during renewal must not be reported as the original 401:
        // bootstrap would interpret that as invalid credentials and log out.
        final refreshing = _refreshing ??= _renewToken(store, tokens);
        late String newAccess;
        try {
          newAccess = await refreshing;
        } on DioException catch (renewErr) {
          // The renewal request has already exhausted the shared retries.
          // resolve/reject here must not run those retries a second time on
          // the original request with the renewal's RequestOptions.
          handler.reject(renewErr);
          return;
        } catch (e, stackTrace) {
          handler.reject(DioException(
            requestOptions: err.requestOptions,
            error: e,
            stackTrace: stackTrace,
          ));
          return;
        } finally {
          if (identical(_refreshing, refreshing)) _refreshing = null;
        }

        try {
          final retryOptions = err.requestOptions;
          retryOptions.headers['X-API-Key'] = newAccess;
          retryOptions.extra[_kRetriedAfterRefresh] = true;
          final retryResponse = await _dio.fetch(retryOptions);
          handler.resolve(retryResponse);
        } on DioException catch (retryErr) {
          handler.reject(retryErr);
        }
        return;
      } // end else (not the renew request's own 401)
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
      // Continue through the error chain so RetryInterceptor can handle
      // transient server failures. reject() would skip it entirely.
      handler.next(
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
      DioExceptionType.receiveTimeout => 'Server took too long to respond.',
      DioExceptionType.connectionError =>
        'Cannot reach server. Verify the URL is correct and reachable.',
      DioExceptionType.badCertificate =>
        'TLS certificate is invalid for this server.',
      _ => err.message ?? 'Network error',
    };
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        error: ApiException(status: 0, message: friendly),
        type: err.type,
      ),
    );
  }

  Future<String> _renewToken(SecureTokenStore store, TokenData tokens) async {
    try {
      final response = await _dio.post(
        '/api/token/renew',
        data: {'refresh_token': tokens.refreshToken},
        options: Options(
          headers: {'X-API-Key': null},
          extra: {_kRenewRequest: true},
        ),
      );
      final data = response.data;
      final access = data is Map ? data['token'] : null;
      final refresh = data is Map ? data['refresh_token'] : null;
      final expiredIn = data is Map ? data['expired_in'] : null;
      if (access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty ||
          expiredIn is! int) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: const FormatException('Invalid token renewal response'),
        );
      }
      await store.saveTokens(
        access: access,
        refresh: refresh,
        expiresAt: DateTime.now().add(Duration(seconds: expiredIn)),
      );
      return access;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await store.clear();
      rethrow;
    }
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
