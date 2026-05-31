import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';

part 'session_actions_api.g.dart';

/// API helpers for chat-list context-menu actions beyond pin/unpin.
///
/// Endpoints (from the web reference `src/app/services/user.ts` and
/// `src/app/services/channel.ts`):
///
///   POST /api/user/read-index   — mark conversations as read
///   POST /api/user/mute         — mute/unmute channels or DMs
///   GET  /api/group/{gid}/leave — leave a channel
class SessionActionsApi {
  SessionActionsApi(this._dio);
  final Dio _dio;

  /// Mark a DM as read up to [mid].
  Future<void> markReadUser(int uid, int mid) async {
    await _dio.post('/api/user/read-index', data: {
      'users': [
        {'uid': uid, 'mid': mid}
      ],
    });
  }

  /// Mark a channel as read up to [mid].
  Future<void> markReadGroup(int gid, int mid) async {
    await _dio.post('/api/user/read-index', data: {
      'groups': [
        {'gid': gid, 'mid': mid}
      ],
    });
  }

  /// Mute a channel.
  Future<void> muteGroup(int gid) async {
    await _dio.post('/api/user/mute', data: {
      'add_groups': [
        {'gid': gid}
      ],
    });
  }

  /// Unmute a channel.
  Future<void> unmuteGroup(int gid) async {
    await _dio.post('/api/user/mute', data: {
      'remove_groups': [gid],
    });
  }

  /// Mute a DM.
  Future<void> muteUser(int uid) async {
    await _dio.post('/api/user/mute', data: {
      'add_users': [
        {'uid': uid}
      ],
    });
  }

  /// Unmute a DM.
  Future<void> unmuteUser(int uid) async {
    await _dio.post('/api/user/mute', data: {
      'remove_users': [uid],
    });
  }

  /// Leave a channel. The server removes the user from the group.
  Future<void> leaveGroup(int gid) async {
    await _dio.get('/api/group/$gid/leave');
  }
}

@riverpod
SessionActionsApi sessionActionsApi(Ref ref) {
  final dio = ref.watch(dioProvider);
  return SessionActionsApi(dio);
}
