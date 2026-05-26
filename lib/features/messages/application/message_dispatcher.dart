import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/sse_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../channels/application/conversation_providers.dart';
import '../../channels/application/pinned_chats_provider.dart';
import '../../channels/domain/pin_chat_models.dart';
import '../../contacts/application/presence_provider.dart';
import '../domain/message_models.dart';
import 'chat_controller.dart';
import 'reactions_provider.dart';

part 'message_dispatcher.g.dart';

/// Long-lived listener that routes every incoming SSE chat event to:
///   1. the conversations list (so previews update on the left),
///   2. the per-target ChatController (so the chat screen has the message
///      ready the moment it's opened, even if it had never been opened
///      before — and stays in sync while it's in the background), and
///   3. the presence / show-online-status providers (so DM avatars reflect
///      the actual online state, mirroring the web client's `useStreaming`
///      handler for `users_state` / `users_state_changed` /
///      `server_config_changed`).
///
/// Kept alive for the entire app lifetime so it does NOT depend on any
/// screen being mounted.
@Riverpod(keepAlive: true)
class MessageDispatcher extends _$MessageDispatcher {
  @override
  void build() {
    ref.listen(sseEventsProvider, (_, next) {
      next.whenData((event) {
        if (event is ChatEventChat) {
          final msg = event.message;

          // Reaction events arrive as chat messages with type=reaction.
          // Route them to the reactions provider; do NOT add them to chat
          // history (they're not displayable on their own — they mutate the
          // target message's reaction set).
          final detail = msg.detail;
          if (detail is ReactionMessageDetail) {
            _handleReaction(msg, detail);
            return;
          }

          // Update the conversation list preview/timestamp.
          ref
              .read(conversationsProvider.notifier)
              .applyIncomingMessage(msg);

          // NOTE: We intentionally do NOT touch chatControllerProvider here.
          // Each ChatController.build() already does `ref.listen(
          // sseEventsProvider, ...)` for its target, so any mounted chat
          // screen receives the message directly from SSE. Forcing
          // `ref.read(chatControllerProvider(msg.target).notifier)` for
          // every incoming message would spawn a fresh controller for every
          // target that ever appeared in an SSE replay — on a cold start
          // with `after_mid` catch-up that replays hundreds of messages
          // across dozens of targets, this snowballs into hundreds of
          // concurrent provider builds, each awaiting messageCache + disk
          // reads, and saturates the microtask queue until the UI hangs.
          // A fresh controller will catch up via getHistory on first open.
          return;
        }
        if (event is ChatEventServerConfigChanged) {
          final flag = event.data['show_user_online_status'];
          if (flag is bool) {
            ref.read(showOnlineStatusProvider.notifier).set(flag);
          }
          return;
        }
        if (event is ChatEventUserSettings) {
          _applyPinnedChatsSnapshot(event.data);
          return;
        }
        if (event is ChatEventUserSettingsChanged) {
          _applyPinnedChatsDelta(event.data);
          return;
        }
        if (event is ChatEventUnknown) {
          switch (event.type) {
            case 'users_state':
              final decoded = _decode(event.raw);
              final users = decoded?['users'];
              if (users is List) {
                ref.read(presenceProvider.notifier).applySnapshot(
                      users
                          .whereType<Map>()
                          .map((m) => Map<String, dynamic>.from(m))
                          .toList(),
                    );
              }
              break;
            case 'users_state_changed':
              final decoded = _decode(event.raw);
              if (decoded == null) break;
              final uid = (decoded['uid'] as num?)?.toInt();
              if (uid == null) break;
              final online = decoded['online'] == true;
              ref.read(presenceProvider.notifier).applyChange(uid, online);
              break;
          }
        }
      });
    });
  }

  /// Initial `user_settings` snapshot: replace the pinned-chats list with
  /// whatever the server says. Mirrors the web reference's
  /// `upsertPinChats({ pins, override: true })`.
  void _applyPinnedChatsSnapshot(Map<String, dynamic> data) {
    final raw = data['pinned_chats'];
    if (raw is! List) return;
    final pins = raw
        .whereType<Map>()
        .map((m) => PinChat.fromJson(Map<String, dynamic>.from(m)))
        .whereType<PinChat>()
        .toList();
    ref.read(pinnedChatsProvider.notifier).setAll(pins);
  }

  /// Delta `user_settings_changed`: apply `add_pin_chats` / `remove_pin_chats`
  /// without touching the rest of the pinned list.
  void _applyPinnedChatsDelta(Map<String, dynamic> data) {
    final add = data['add_pin_chats'];
    if (add is List && add.isNotEmpty) {
      final pins = add
          .whereType<Map>()
          .map((m) => PinChat.fromJson(Map<String, dynamic>.from(m)))
          .whereType<PinChat>()
          .toList();
      if (pins.isNotEmpty) {
        ref.read(pinnedChatsProvider.notifier).upsertAll(pins);
      }
    }
    final remove = data['remove_pin_chats'];
    if (remove is List && remove.isNotEmpty) {
      final targets = remove
          .whereType<Map>()
          .map((m) => PinChatTarget.fromJson(Map<String, dynamic>.from(m)))
          .whereType<PinChatTarget>()
          .toList();
      if (targets.isNotEmpty) {
        ref.read(pinnedChatsProvider.notifier).removeAll(targets);
      }
    }
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return null;
  }

  /// Dispatch a reaction-type chat message:
  ///   - `like` → toggle the emoji on the target message
  ///   - `delete` → remove the target message from chat + strip its reactions
  ///   - `edit` → patch the target message's content in chat
  void _handleReaction(ChatMessage msg, ReactionMessageDetail detail) {
    final inner = detail.detail;
    final type = inner['type'];
    // Resolve the *conversation-scoped* target for ChatController. In DMs,
    // `msg.target` is always the recipient, so when an edit/delete echo
    // arrives for the other end of the conversation we'd otherwise route to a
    // ChatController keyed on our own uid — which isn't the one the chat
    // screen is mounted against. Translate to the peer's uid when we are the
    // recipient. Group targets are already symmetric and don't need this.
    final chatTarget = _conversationTargetFor(msg);
    if (type == 'like') {
      final action = inner['action'];
      if (action is String && action.isNotEmpty) {
        ref.read(reactionsProvider.notifier).applyLike(
              reactionMid: msg.mid,
              targetMid: detail.mid,
              fromUid: msg.fromUid,
              emoji: action,
            );
      }
    } else if (type == 'delete') {
      ref.read(reactionsProvider.notifier).removeFor(detail.mid);
      ref
          .read(chatControllerProvider(chatTarget).notifier)
          .applyDeleteEcho(detail.mid);
      ref
          .read(conversationsProvider.notifier)
          .applyDeleteEcho(msg.target, detail.mid, fromUid: msg.fromUid);
    } else if (type == 'edit') {
      final content = inner['content'];
      final contentType = inner['content_type'];
      if (content is String && contentType is String) {
        ref
            .read(chatControllerProvider(chatTarget).notifier)
            .applyEditEcho(detail.mid, content, contentType);
        ref
            .read(conversationsProvider.notifier)
            .applyEditEcho(msg.target, detail.mid, content,
                fromUid: msg.fromUid);
      }
    }
  }

  /// Translate a server-perspective [ChatMessage.target] into the
  /// conversation-scoped target the chat screen mounts against. Group targets
  /// pass through unchanged; DM targets are flipped to the peer's uid when
  /// the recipient is ourselves (i.e. an incoming event), matching the same
  /// rule used by `ChatController.applyIncomingMessage` and the conversation
  /// list peer-resolution logic.
  MessageTarget _conversationTargetFor(ChatMessage msg) {
    return msg.target.map(
      user: (t) {
        final authState = ref.read(authControllerProvider).valueOrNull;
        final currentUid =
            authState is AuthStateAuthenticated ? authState.user.uid : null;
        final peerUid =
            currentUid != null && msg.fromUid != currentUid && t.uid == currentUid
                ? msg.fromUid
                : t.uid;
        return MessageTarget.user(uid: peerUid);
      },
      group: (t) => MessageTarget.group(gid: t.gid),
    );
  }
}
