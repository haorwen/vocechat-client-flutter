// Voice/video call domain models (Agora RTC).
//
// Server contract (vocechat-server/src/api/admin_agora.rs):
//   POST /admin/agora/token  body: {"uid": N} | {"gid": N}
//     -> { agora_token, app_id, uid, channel_name, expired_in }
//   GET  /admin/agora/channel/:page_no/:page_size
//     -> { success, data: { channels: [{channel_name, user_count}], total_size } }
//   Channel naming: "vocechat:dm:{uid}" for a DM, "vocechat:group:{gid}" for a
//   channel — mirrors the web reference's `channel_name.split(":").slice(-2)`.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../messages/domain/message_models.dart';

part 'voice_models.freezed.dart';

/// Mirrors Agora's `ConnectionStateType` without tying the domain layer to
/// the plugin package. [VoiceController] maps the SDK enum onto this one.
enum VoiceConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Per-call state for the call the current device is in (or joining).
/// [context] identifies the DM peer or channel via the same `MessageTarget`
/// shape used for chat targets — a voice call is scoped to exactly one DM
/// peer or one channel, same as a `MessageTarget`.
@freezed
class VoicingInfo with _$VoicingInfo {
  const factory VoicingInfo({
    required MessageTarget context,
    @Default(false) bool joining,
    VoiceConnectionState? connectionState,
    int? downlinkNetworkQuality,
    @Default(false) bool muted,
    @Default(false) bool deafen,
    @Default(false) bool video,
    @Default(false) bool shareScreen,
  }) = _VoicingInfo;
}

/// Per-remote-member state within the active call (speaking volume, mute,
/// video/share-screen flags). Keyed by uid in [VoicingMembers.byId].
@freezed
class VoicingMemberInfo with _$VoicingMemberInfo {
  const factory VoicingMemberInfo({
    @Default(0) int speakingVolume,
    @Default(false) bool muted,
    @Default(false) bool video,
    @Default(false) bool shareScreen,
  }) = _VoicingMemberInfo;
}

/// Roster of everyone currently in the joined channel, plus an optional
/// pinned uid for the fullscreen spotlight view.
@freezed
class VoicingMembers with _$VoicingMembers {
  const factory VoicingMembers({
    @Default(<int>[]) List<int> ids,
    @Default(<int, VoicingMemberInfo>{}) Map<int, VoicingMemberInfo> byId,
    int? pin,
  }) = _VoicingMembers;
}

/// Returns the only remote video uid that is eligible for picture-in-picture.
///
/// PiP is intentionally limited to one-to-one calls. Group calls, incomplete
/// rosters, duplicate ids, and remote screen sharing without camera video are
/// excluded.
int? remoteVideoUidForPictureInPicture({
  required VoicingInfo? call,
  required VoicingMembers members,
  required int? localUid,
}) {
  if (call == null ||
      call.joining ||
      call.connectionState != VoiceConnectionState.connected ||
      localUid == null ||
      call.context is! MessageTargetUser ||
      members.ids.length != 2 ||
      members.ids.toSet().length != 2 ||
      !members.ids.contains(localUid)) {
    return null;
  }

  final remoteUid = members.ids.firstWhere((uid) => uid != localUid);
  return members.byId[remoteUid]?.video == true ? remoteUid : null;
}

/// Response from `POST /admin/agora/token`.
class AgoraTokenResponse {
  const AgoraTokenResponse({
    required this.agoraToken,
    required this.appId,
    required this.uid,
    required this.channelName,
    required this.expiredIn,
  });

  final String agoraToken;
  final String appId;
  final int uid;
  final String channelName;
  final int expiredIn;

  factory AgoraTokenResponse.fromJson(Map<String, dynamic> json) =>
      AgoraTokenResponse(
        agoraToken: json['agora_token'] as String,
        appId: json['app_id'] as String,
        uid: (json['uid'] as num).toInt(),
        channelName: json['channel_name'] as String,
        expiredIn: (json['expired_in'] as num).toInt(),
      );
}

/// One entry from the `/admin/agora/channel/:page/:size` active-channel list
/// — used to discover incoming DM calls by polling (mirrors the web
/// reference's `getAgoraChannels` + `upsertVoiceList`, since the server's
/// `UserCalling` push event is not actually wired up server-side).
class ActiveVoiceChannel {
  const ActiveVoiceChannel({
    required this.channelName,
    required this.userCount,
    required this.context,
  });

  final String channelName;
  final int userCount;

  /// Parsed from [channelName]: `vocechat:dm:{uid}` -> `MessageTarget.user`,
  /// `vocechat:group:{gid}` -> `MessageTarget.group`. Null if the name
  /// doesn't match the expected shape (defensive against unrelated channels).
  final MessageTarget? context;

  static ActiveVoiceChannel fromJson(Map<String, dynamic> j) {
    final channelName = j['channel_name'] as String? ?? '';
    final userCount = (j['user_count'] as num?)?.toInt() ?? 0;
    return ActiveVoiceChannel(
      channelName: channelName,
      userCount: userCount,
      context: _parseChannelName(channelName),
    );
  }

  static MessageTarget? _parseChannelName(String channelName) {
    final parts = channelName.split(':');
    if (parts.length < 3) return null;
    final kind = parts[parts.length - 2];
    final id = int.tryParse(parts[parts.length - 1]);
    if (id == null) return null;
    switch (kind) {
      case 'dm':
        return MessageTarget.user(uid: id);
      case 'group':
        return MessageTarget.group(gid: id);
      default:
        return null;
    }
  }
}

/// Ringing state for an incoming/outgoing DM call invite, discovered either
/// by polling `/admin/agora/channel/:p/:s` (the primary path — the server's
/// `UserCalling` push event is not currently wired up) or by a
/// `ChatEvent.userCalling` SSE event should the server start sending it.
/// Mirrors the web reference's `callingFrom`/`callingTo`/`calling` fields on
/// the `voice` redux slice.
@freezed
class IncomingCallState with _$IncomingCallState {
  const factory IncomingCallState({
    @Default(0) int fromUid,
    @Default(0) int toUid,
    @Default(false) bool calling,
  }) = _IncomingCallState;
}
