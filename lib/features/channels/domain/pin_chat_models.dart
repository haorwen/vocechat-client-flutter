// Pinned-chat wire model (mirrors `PinChat` / `PinChatTarget` on the server):
//   {"target": {"uid": 123}, "updated_at": 1717}
//   {"target": {"gid": 456}, "updated_at": 1717}
//
// Manual JSON because the server's poem-openapi `Union` has no discriminator —
// the variant is distinguished by which key exists on `target`. Same trick we
// use for `MessageTarget` in `message_models.dart`.

import '../application/conversation_providers.dart';

sealed class PinChatTarget {
  const PinChatTarget();

  ConversationKey get conversationKey;
  Map<String, dynamic> toJson();

  static PinChatTarget? fromJson(Map<String, dynamic> j) {
    final uid = (j['uid'] as num?)?.toInt();
    final gid = (j['gid'] as num?)?.toInt();
    if (uid != null) return PinChatTargetUser(uid);
    if (gid != null) return PinChatTargetGroup(gid);
    return null;
  }
}

class PinChatTargetUser extends PinChatTarget {
  const PinChatTargetUser(this.uid);
  final int uid;

  @override
  ConversationKey get conversationKey => UserConversationKey(uid);

  @override
  Map<String, dynamic> toJson() => {'uid': uid};

  @override
  bool operator ==(Object other) =>
      other is PinChatTargetUser && other.uid == uid;

  @override
  int get hashCode => Object.hash('pin-u', uid);
}

class PinChatTargetGroup extends PinChatTarget {
  const PinChatTargetGroup(this.gid);
  final int gid;

  @override
  ConversationKey get conversationKey => GroupConversationKey(gid);

  @override
  Map<String, dynamic> toJson() => {'gid': gid};

  @override
  bool operator ==(Object other) =>
      other is PinChatTargetGroup && other.gid == gid;

  @override
  int get hashCode => Object.hash('pin-g', gid);
}

class PinChat {
  const PinChat({required this.target, required this.updatedAt});

  final PinChatTarget target;

  /// Unix milliseconds. Server sends an i64 unix-ms (same convention as
  /// `ChatMessage.createdAt`); we mirror it raw so sorting newest-first is
  /// just a numeric compare.
  final int updatedAt;

  Map<String, dynamic> toJson() => {
        'target': target.toJson(),
        'updated_at': updatedAt,
      };

  static PinChat? fromJson(Map<String, dynamic> j) {
    final t = j['target'];
    if (t is! Map<String, dynamic>) return null;
    final target = PinChatTarget.fromJson(t);
    if (target == null) return null;
    final raw = j['updated_at'];
    final updatedAt = raw is num ? raw.toInt() : 0;
    return PinChat(target: target, updatedAt: updatedAt);
  }
}
