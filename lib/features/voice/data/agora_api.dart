import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../domain/voice_models.dart';

part 'agora_api.g.dart';

/// API for Agora-backed voice/video calling.
///
/// Endpoints verified against the web reference
/// (`src/app/services/server.ts`) and the Rust server
/// (`vocechat-server/src/api/admin_agora.rs`):
///
///   GET  /api/admin/agora/enabled                       — feature flag (no auth)
///   POST /api/admin/agora/token                          — {uid}|{gid} -> token
///   GET  /api/admin/agora/channel/:page_no/:page_size    — active channel list
///   GET  /api/admin/agora/channel/user/:channel_name/:hosts_only — users in channel
class AgoraApi {
  AgoraApi(this._dio);
  final Dio _dio;

  /// Whether the admin has configured + enabled Agora on this server.
  Future<bool> isEnabled() async {
    final resp = await _dio.get('/api/admin/agora/enabled');
    return resp.data == true;
  }

  /// Request an RTC token for a DM (pass [uid]) or channel (pass [gid]).
  /// Exactly one of the two must be provided — mirrors the server's
  /// `AgoraTarget` union.
  Future<AgoraTokenResponse> generateToken({int? uid, int? gid}) async {
    assert((uid == null) != (gid == null),
        'generateToken requires exactly one of uid/gid');
    final resp = await _dio.post(
      '/api/admin/agora/token',
      data: uid != null ? {'uid': uid} : {'gid': gid},
    );
    return AgoraTokenResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Active voice/video channels across the server — used to discover
  /// incoming DM calls by polling, since the server does not (currently)
  /// push a call-invite event. Returns an empty list on any parse failure
  /// rather than throwing, so a transient bad response doesn't spam errors
  /// on every poll tick.
  Future<List<ActiveVoiceChannel>> getActiveChannels({
    int pageNo = 0,
    int pageSize = 100,
  }) async {
    final resp = await _dio.get('/api/admin/agora/channel/$pageNo/$pageSize');
    final data = resp.data;
    if (data is! Map<String, dynamic> || data['success'] != true) return [];
    final channels = data['data']?['channels'];
    if (channels is! List) return [];
    return channels
        .whereType<Map<String, dynamic>>()
        .map(ActiveVoiceChannel.fromJson)
        .toList(growable: false);
  }

  /// Uids currently present in [channelName]. Returns an empty list if the
  /// channel doesn't exist or the response can't be parsed.
  Future<List<int>> getChannelUsers(String channelName) async {
    final encoded = Uri.encodeComponent(channelName);
    final resp = await _dio.get('/api/admin/agora/channel/user/$encoded/false');
    final data = resp.data;
    if (data is! Map<String, dynamic> || data['success'] != true) return [];
    final inner = data['data'];
    if (inner is! Map<String, dynamic> || inner['channel_exist'] != true) {
      return [];
    }
    final users = inner['users'];
    if (users is! List) return [];
    return users.whereType<num>().map((n) => n.toInt()).toList(growable: false);
  }
}

@Riverpod(keepAlive: true)
AgoraApi agoraApi(Ref ref) {
  return AgoraApi(ref.watch(dioProvider));
}
