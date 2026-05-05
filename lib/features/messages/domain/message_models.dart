import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_models.freezed.dart';
part 'message_models.g.dart';

// ---------------------------------------------------------------------------
// MessageTarget
// ---------------------------------------------------------------------------

@freezed
sealed class MessageTarget with _$MessageTarget {
  const factory MessageTarget.user({required int uid}) = MessageTargetUser;
  const factory MessageTarget.group({required int gid}) = MessageTargetGroup;

  factory MessageTarget.fromJson(Map<String, dynamic> json) =>
      _$MessageTargetFromJson(json);
}

// ---------------------------------------------------------------------------
// MessageDetail (sealed)
// ---------------------------------------------------------------------------

@freezed
sealed class MessageDetail with _$MessageDetail {
  const factory MessageDetail.normal({
    @JsonKey(name: 'content_type') required String contentType,
    required String content,
    Map<String, dynamic>? properties,
  }) = NormalMessageDetail;

  const factory MessageDetail.reaction({
    required int mid,
    required String action,
    Map<String, dynamic>? extra,
  }) = ReactionMessageDetail;

  const factory MessageDetail.reply({
    required int mid,
    @JsonKey(name: 'content_type') required String contentType,
    required String content,
    Map<String, dynamic>? properties,
  }) = ReplyMessageDetail;

  factory MessageDetail.fromJson(Map<String, dynamic> json) =>
      _$MessageDetailFromJson(json);
}

// ---------------------------------------------------------------------------
// ChatMessage
// ---------------------------------------------------------------------------

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required int mid,
    @JsonKey(name: 'from_uid') required int fromUid,
    @JsonKey(name: 'created_at') required String createdAt,
    required MessageTarget target,
    required MessageDetail detail,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}

// ---------------------------------------------------------------------------
// ChatEvent (sealed SSE events)
// ---------------------------------------------------------------------------

@freezed
sealed class ChatEvent with _$ChatEvent {
  const factory ChatEvent.ready() = ChatEventReady;

  const factory ChatEvent.heartbeat({String? time}) = ChatEventHeartbeat;

  const factory ChatEvent.chat({required ChatMessage message}) = ChatEventChat;

  const factory ChatEvent.kick({String? reason}) = ChatEventKick;

  const factory ChatEvent.usersSnapshot({
    required List<Map<String, dynamic>> users,
    required int version,
  }) = ChatEventUsersSnapshot;

  const factory ChatEvent.groupChanged(
      {required Map<String, dynamic> data}) = ChatEventGroupChanged;

  const factory ChatEvent.userJoinedGroup({
    required int gid,
    required List<int> uid,
  }) = ChatEventUserJoinedGroup;

  const factory ChatEvent.userLeavedGroup({
    required int gid,
    required List<int> uid,
  }) = ChatEventUserLeavedGroup;

  const factory ChatEvent.serverConfigChanged(
      {required Map<String, dynamic> data}) = ChatEventServerConfigChanged;

  const factory ChatEvent.unknown({
    required String type,
    required String raw,
  }) = ChatEventUnknown;
}

// ---------------------------------------------------------------------------
// SSE event parser
// ---------------------------------------------------------------------------

ChatEvent parseSseEvent(String eventType, String rawData) {
  try {
    switch (eventType) {
      case 'ready':
        return const ChatEvent.ready();
      case 'heartbeat':
        final decoded = _decodeMap(rawData) ?? {};
        return ChatEvent.heartbeat(time: decoded['time'] as String?);
      case 'chat':
        final map = _decodeMap(rawData);
        if (map != null) {
          return ChatEvent.chat(message: ChatMessage.fromJson(map));
        }
      case 'kick':
        final decoded = _decodeMap(rawData) ?? {};
        return ChatEvent.kick(reason: decoded['reason'] as String?);
      case 'users_snapshot':
        final decoded = _decodeMap(rawData) ?? {};
        return ChatEvent.usersSnapshot(
          users: (decoded['users'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>(),
          version: (decoded['version'] as num?)?.toInt() ?? 0,
        );
      case 'group_changed':
        final decoded = _decodeMap(rawData) ?? {};
        return ChatEvent.groupChanged(data: decoded);
      case 'user_joined_group':
        final decoded = _decodeMap(rawData) ?? {};
        return ChatEvent.userJoinedGroup(
          gid: (decoded['gid'] as num).toInt(),
          uid: (decoded['uid'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
        );
      case 'user_leaved_group':
        final decoded = _decodeMap(rawData) ?? {};
        return ChatEvent.userLeavedGroup(
          gid: (decoded['gid'] as num).toInt(),
          uid: (decoded['uid'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
        );
      case 'server_config_changed':
        final decoded = _decodeMap(rawData) ?? {};
        return ChatEvent.serverConfigChanged(data: decoded);
    }
  } catch (_) {
    // Fall through to unknown
  }
  return ChatEvent.unknown(type: eventType, raw: rawData);
}

Map<String, dynamic>? _decodeMap(String s) {
  try {
    final decoded = jsonDecode(s);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  } catch (_) {
    return null;
  }
}
