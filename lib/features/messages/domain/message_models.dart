// ignore_for_file: invalid_annotation_target
import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_models.freezed.dart';
part 'message_models.g.dart';

// ---------------------------------------------------------------------------
// MessageTarget
// ---------------------------------------------------------------------------
//
// Server uses poem-openapi Union WITHOUT discriminator_name, so it serializes
// as a plain object: {"uid": 123} for user, {"gid": 456} for group.
// Freezed's default unionKey-based fromJson won't work; we write a manual
// factory that inspects the keys.

@freezed
sealed class MessageTarget with _$MessageTarget {
  const factory MessageTarget.user({required int uid}) = MessageTargetUser;
  const factory MessageTarget.group({required int gid}) = MessageTargetGroup;

  /// Manual fromJson: server sends {"uid":123} or {"gid":456} with no type key.
  factory MessageTarget.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('uid')) {
      return MessageTarget.user(uid: (json['uid'] as num).toInt());
    } else if (json.containsKey('gid')) {
      return MessageTarget.group(gid: (json['gid'] as num).toInt());
    }
    throw FormatException('Unknown MessageTarget shape: $json');
  }
}

// Manual toJson for MessageDetail
Map<String, dynamic> _messageDetailToJson(MessageDetail detail) {
  return detail.map(
    normal: (d) => {
      'type': 'normal',
      'content_type': d.contentType,
      'content': d.content,
      if (d.properties != null) 'properties': d.properties,
      if (d.expiresIn != null) 'expires_in': d.expiresIn,
    },
    reaction: (d) => {
      'type': 'reaction',
      'mid': d.mid,
      'detail': d.detail,
    },
    reply: (d) => {
      'type': 'reply',
      'mid': d.mid,
      'content_type': d.contentType,
      'content': d.content,
      if (d.properties != null) 'properties': d.properties,
      if (d.expiresIn != null) 'expires_in': d.expiresIn,
    },
  );
}

MessageDetail _messageDetailFromJson(Map<String, dynamic> json) =>
    MessageDetail.fromJson(json);
Map<String, dynamic> _messageTargetToJson(MessageTarget target) {
  return target.map(
    user: (t) => {'uid': t.uid},
    group: (t) => {'gid': t.gid},
  );
}

MessageTarget _messageTargetFromJson(Map<String, dynamic> json) =>
    MessageTarget.fromJson(json);

// ---------------------------------------------------------------------------
// MessageDetail (sealed)
// ---------------------------------------------------------------------------
//
// Server uses #[oai(discriminator_name = "type")] with mappings:
//   "normal"   -> MessageNormal   { content_type, content, properties?, expires_in? }
//   "reply"    -> MessageReply    { mid, content_type, content, properties?, expires_in? }
//   "reaction" -> MessageReaction { mid, detail: { type: "edit"|"like"|"delete", ... } }
//   "command"  -> MessageCommand  { ... }  (ignored)
//
// Note: MessageNormal/MessageReply flatten ChatMessageContent, so content_type
// and content appear at the same level as the variant fields.

@freezed
sealed class MessageDetail with _$MessageDetail {
  // type = "normal"
  const factory MessageDetail.normal({
    @JsonKey(name: 'content_type') required String contentType,
    required String content,
    Map<String, dynamic>? properties,
    @JsonKey(name: 'expires_in') int? expiresIn,
  }) = NormalMessageDetail;

  // type = "reaction" — detail sub-object carries type + action fields
  const factory MessageDetail.reaction({
    required int mid,
    required Map<String, dynamic> detail,
  }) = ReactionMessageDetail;

  // type = "reply"
  const factory MessageDetail.reply({
    required int mid,
    @JsonKey(name: 'content_type') required String contentType,
    required String content,
    Map<String, dynamic>? properties,
    @JsonKey(name: 'expires_in') int? expiresIn,
  }) = ReplyMessageDetail;

  /// Manual fromJson: dispatch on "type" discriminator.
  factory MessageDetail.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'normal':
        return MessageDetail.normal(
          contentType: json['content_type'] as String,
          content: json['content'] as String,
          properties: json['properties'] as Map<String, dynamic>?,
          expiresIn: (json['expires_in'] as num?)?.toInt(),
        );
      case 'reply':
        return MessageDetail.reply(
          mid: (json['mid'] as num).toInt(),
          contentType: json['content_type'] as String,
          content: json['content'] as String,
          properties: json['properties'] as Map<String, dynamic>?,
          expiresIn: (json['expires_in'] as num?)?.toInt(),
        );
      case 'reaction':
        return MessageDetail.reaction(
          mid: (json['mid'] as num).toInt(),
          detail: json['detail'] as Map<String, dynamic>,
        );
      default:
        // Treat unknown/command types as normal with empty content to avoid crashes.
        return MessageDetail.normal(
          contentType: 'text/plain',
          content: '',
        );
    }
  }
}

// ---------------------------------------------------------------------------
// ChatMessage
// ---------------------------------------------------------------------------
//
// Server: ChatMessage { mid, #[flatten] payload: ChatMessagePayload }
// ChatMessagePayload { from_uid, created_at (i64 unix-ms), target, detail }
// All fields are at the top level due to the flatten.
// created_at is serialized as i64 unix milliseconds by poem-openapi DateTime.

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required int mid,
    @JsonKey(name: 'from_uid') required int fromUid,
    // Server serializes DateTime as i64 unix milliseconds, not ISO string.
    @JsonKey(name: 'created_at') required int createdAt,
    @JsonKey(
      fromJson: _messageTargetFromJson,
      toJson: _messageTargetToJson,
    )
    required MessageTarget target,
    @JsonKey(
      fromJson: _messageDetailFromJson,
      toJson: _messageDetailToJson,
    )
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
