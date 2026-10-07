import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/domain/auth_models.dart';
import '../../../shared/models/avo_params.dart';

part 'user_api.g.dart';

/// The active server does not expose a compatible Avo save endpoint.
class AvoUnsupportedException implements Exception {
  const AvoUnsupportedException({this.serverVersion});

  final String? serverVersion;

  @override
  String toString() => 'Server does not support saving Avo';
}

/// API for editing the current account (name, avatar, password).
///
/// Endpoints verified against the web reference
/// (`src/app/services/user.ts`, `src/app/services/auth.ts`) and the Rust
/// server (`vocechat-server/src/api/user.rs`):
///
///   PUT  /api/user                — update_user: body is a partial
///                                    `{name?, gender?, language?, birthday?,
///                                    msg_smtp_notify_enable?}`; only send
///                                    fields being changed (server 400s on an
///                                    entirely-empty body). Returns the fresh
///                                    `UserInfo` on 200; 409 on name conflict
///                                    (`{"reason":"name_conflict"}`) — surface
///                                    via the `ApiException.status == 409`
///                                    that the shared Dio error interceptor
///                                    already produces.
///   POST /api/user/avatar         — upload_avatar: raw image bytes body,
///                                    `content-type: image/png` (server
///                                    decodes any format and re-encodes as
///                                    PNG, so no client-side re-encoding is
///                                    needed). 413 if over
///                                    `upload_avatar_limit`.
///   POST /api/user/change_password — body `{old_password, new_password}`.
///                                    Server accepts either raw or
///                                    MD5-hashed(32-hex-char) values; we send
///                                    MD5 hex via `AuthApi.hashPassword` for
///                                    consistency with the login flow.
class UserApi {
  UserApi(this._dio);
  final Dio _dio;

  /// Update the current user's display name. Only `name` is supported today
  /// (the only field editable from the account pane) — omit it and this is a
  /// no-op call the caller should avoid making.
  Future<VoceUser> updateInfo({String? name}) async {
    final resp = await _dio.put(
      '/api/user',
      data: {
        if (name != null) 'name': name,
      },
    );
    return VoceUser.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<AvoParams> getAvo({String fallbackName = 'guest'}) async {
    try {
      final resp = await _dio.get('/api/user/avo');
      final data = resp.data is Map
          ? Map<String, dynamic>.from(resp.data as Map)
          : <String, dynamic>{};
      final raw = data.containsKey('avo_params') ? data['avo_params'] : data;
      return raw is Map && raw.isNotEmpty
          ? AvoParams.normalize(Map<String, dynamic>.from(raw),
              fallbackName: fallbackName)
          : AvoParams.fromName(fallbackName);
    } on DioException {
      // Older servers may only expose the field through /api/user/me.
      final resp = await _dio.get('/api/user/me');
      final data = resp.data is Map
          ? Map<String, dynamic>.from(resp.data as Map)
          : <String, dynamic>{};
      final name = data['name'] as String? ?? fallbackName;
      final raw = data['avo_params'];
      return raw is Map && raw.isNotEmpty
          ? AvoParams.normalize(Map<String, dynamic>.from(raw),
              fallbackName: name)
          : AvoParams.fromName(name);
    }
  }

  Future<void> updateAvo(AvoParams params) async {
    // There is no published minimum Avo server version. Probe the dedicated
    // endpoint instead: legacy servers can route "avo" to /api/user/:uid or
    // return their web page for unknown API paths.
    try {
      final current = await _dio.get('/api/user/avo');
      if (!_isAvoResponse(current.data, allowUnset: true)) {
        await _throwAvoUnsupported();
      }
    } on DioException catch (error) {
      if (!_isMissingAvoEndpoint(error)) rethrow;
      await _throwAvoUnsupported();
    }

    final Response response;
    try {
      response = await _dio.put('/api/user/avo', data: params.toJson());
    } on DioException catch (error) {
      if (!_isMissingAvoEndpoint(error)) rethrow;
      await _throwAvoUnsupported();
    }

    // The protocol returns saved parameters, while some servers return a
    // user or no content. The caller refreshes /me for account metadata, so
    // none of these responses needs to be cast to a complete VoceUser.
    if (response.statusCode == 204 || _isAvoResponse(response.data)) return;
    final data = response.data;
    final user = data is Map && data['user'] is Map ? data['user'] : data;
    if (user is Map && user['uid'] is num && user['name'] is String) return;
    await _throwAvoUnsupported();
  }

  static bool _isAvoResponse(Object? data, {bool allowUnset = false}) {
    if (data is! Map) return false;
    if (data.containsKey('avo_params')) {
      final params = data['avo_params'];
      return (allowUnset && (params == null || params is Map)) ||
          _isCompleteAvoParams(params);
    }
    return _isCompleteAvoParams(data);
  }

  static bool _isCompleteAvoParams(Object? data) {
    if (data is! Map) return false;
    return data['name'] is String &&
        data['variant'] is num &&
        data['hue'] is num &&
        data['style'] is String &&
        data['energy'] is num;
  }

  static bool _isMissingAvoEndpoint(DioException error) {
    if (error.requestOptions.path != '/api/user/avo') return false;
    final status = error.response?.statusCode;
    if (const {404, 405, 501}.contains(status)) return true;
    final body = error.response?.data;
    // The legacy /api/user/:uid route captures GET /api/user/avo and rejects
    // "avo" as an integer. Other 400s remain ordinary request errors.
    return status == 400 &&
        error.requestOptions.method == 'GET' &&
        body is String &&
        body.contains('failed to parse path `uid`') &&
        body.contains('integer(int64)') &&
        body.contains('invalid digit found in string');
  }

  Future<Never> _throwAvoUnsupported() async {
    String? version;
    try {
      final response = await _dio.get<String>(
        '/api/admin/system/version',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'accept': 'text/plain'},
        ),
      );
      final value = response.data?.trim();
      // Ignore web fallbacks and malformed version responses in the message.
      if (value != null &&
          RegExp(r'^v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$').hasMatch(value)) {
        version = value;
      }
    } catch (_) {
      // Version details are optional; a failed lookup must not hide the
      // already-established lack of Avo support.
    }
    throw AvoUnsupportedException(serverVersion: version);
  }

  /// Upload a new avatar. Raw bytes, not multipart — matches the server's
  /// `UploadAvatarRequest::Image` handler.
  Future<void> uploadAvatar(Uint8List bytes,
      {String contentType = 'image/png'}) async {
    await _dio.post(
      '/api/user/avatar',
      data: bytes,
      options: Options(contentType: contentType),
    );
  }

  /// Change the current user's password. Both values are MD5-hashed before
  /// sending, mirroring `AuthApi.login`'s convention.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.post(
      '/api/user/change_password',
      data: {
        'old_password': AuthApi.hashPassword(oldPassword),
        'new_password': AuthApi.hashPassword(newPassword),
      },
    );
  }
}

@riverpod
UserApi userApi(Ref ref) {
  final dio = ref.watch(dioProvider);
  return UserApi(dio);
}
