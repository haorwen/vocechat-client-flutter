import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';

part 'group_api.g.dart';

/// API for channel (group) management.
///
/// Endpoints verified against the web reference
/// (`src/app/services/channel.ts`) and the Rust server
/// (`vocechat-server/src/api/group.rs`):
///
///   POST   /api/group                                — create channel
///   PUT    /api/group/{gid}                           — update name/description
///   DELETE /api/group/{gid}                           — delete channel
///   POST   /api/group/{gid}/change_type               — change public/private
///   POST   /api/group/{gid}/members/add                — add members (raw int[])
///   POST   /api/group/{gid}/members/remove             — remove members (raw int[])
///   POST   /api/group/{gid}/avatar                    — upload avatar (raw image bytes)
///   GET    /api/group/create_reg_magic_link            — public channel invite link
///   GET    /api/group/create_invite_private_magic_link — private channel invite link
class GroupApi {
  GroupApi(this._dio);
  final Dio _dio;

  /// Create a new channel. [members] is only meaningful for private channels
  /// — the server rejects a non-empty `members` list on a public channel
  /// (400), mirroring the web client which strips `members` before submit
  /// when `isPublic` is true.
  Future<int> createChannel({
    required String name,
    String description = '',
    required bool isPublic,
    List<int> members = const [],
  }) async {
    final resp = await _dio.post('/api/group', data: {
      'name': name,
      'description': description,
      'is_public': isPublic,
      if (!isPublic) 'members': members,
    });
    return (resp.data['gid'] as num).toInt();
  }

  /// Update channel name/description.
  Future<void> updateChannel(
    int gid, {
    String? name,
    String? description,
  }) async {
    await _dio.put('/api/group/$gid', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  /// Delete a channel. Owner/admin only (enforced server-side).
  Future<void> deleteChannel(int gid) async {
    await _dio.delete('/api/group/$gid');
  }

  /// Change a channel's visibility. When switching private→public, [members]
  /// is ignored by the server. When switching public→private, [members]
  /// (if non-empty) becomes the new member list; otherwise the server
  /// defaults to all non-guest users.
  Future<void> changeType({
    required int gid,
    required bool isPublic,
    List<int> members = const [],
  }) async {
    await _dio.post('/api/group/$gid/change_type', data: {
      'is_public': isPublic,
      'members': members,
    });
  }

  /// Add members to a private channel. Body is a raw JSON array of uids.
  Future<void> addMembers(int gid, List<int> uids) async {
    await _dio.post('/api/group/$gid/members/add', data: uids);
  }

  /// Remove members from a private channel. Body is a raw JSON array of uids.
  Future<void> removeMembers(int gid, List<int> uids) async {
    await _dio.post('/api/group/$gid/members/remove', data: uids);
  }

  /// Upload a channel avatar/icon. Raw image bytes, not multipart — matches
  /// the server's `UploadAvatarRequest::Image` handler.
  Future<void> uploadAvatar(int gid, List<int> bytes,
      {String contentType = 'image/png'}) async {
    await _dio.post(
      '/api/group/$gid/avatar',
      data: bytes,
      options: Options(contentType: contentType),
    );
  }

  /// Create a registration/invite link for a **public** channel (or generic
  /// registration link if [gid] is omitted). Returns a plain-text URL.
  Future<String> createInviteLink({
    int? gid,
    int? expiredIn,
    int? maxTimes,
  }) async {
    final resp = await _dio.get('/api/group/create_reg_magic_link',
        queryParameters: {
          if (gid != null) 'gid': gid,
          if (expiredIn != null) 'expired_in': expiredIn,
          if (maxTimes != null) 'max_times': maxTimes,
        });
    return resp.data as String;
  }

  /// Create an invite link for a **private** channel. Requires owner/admin.
  /// Returns a plain-text URL.
  Future<String> createPrivateInviteLink({
    required int gid,
    int? expiredIn,
    int? maxTimes,
  }) async {
    final resp = await _dio.get(
        '/api/group/create_invite_private_magic_link',
        queryParameters: {
          'gid': gid,
          if (expiredIn != null) 'expired_in': expiredIn,
          if (maxTimes != null) 'max_times': maxTimes,
        });
    return resp.data as String;
  }
}

@riverpod
GroupApi groupApi(Ref ref) {
  final dio = ref.watch(dioProvider);
  return GroupApi(dio);
}
