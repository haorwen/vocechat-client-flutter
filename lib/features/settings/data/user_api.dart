import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/domain/auth_models.dart';
import '../../../shared/models/avo_params.dart';

part 'user_api.g.dart';

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

  Future<AvoParams> getAvo() async {
    try {
      final resp = await _dio.get('/api/user/avo');
      final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
      final raw = data['avo_params'] is Map ? data['avo_params'] as Map : data;
      return AvoParams.normalize(Map<String, dynamic>.from(raw));
    } on DioException {
      // Older servers may only expose the field through /api/user/me.
      final resp = await _dio.get('/api/user/me');
      final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
      return AvoParams.normalize(data['avo_params'] is Map ? Map<String, dynamic>.from(data['avo_params'] as Map) : null);
    }
  }

  Future<VoceUser> updateAvo(AvoParams params) async {
    final resp = await _dio.put('/api/user/avo', data: params.toJson());
    final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
    final userData = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : data;
    return VoceUser.fromJson(userData);
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
