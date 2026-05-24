import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/sse_client.dart';
import '../../channels/application/conversation_providers.dart';
import '../../contacts/application/presence_provider.dart';
import '../domain/message_models.dart';
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

  Map<String, dynamic>? _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return null;
  }

  /// Dispatch a reaction-type chat message:
  ///   - `like` → toggle the emoji on the target message
  ///   - `delete` → strip reactions for the deleted target
  ///   - `edit` → ignored here (chat content edits live in ChatController)
  void _handleReaction(ChatMessage msg, ReactionMessageDetail detail) {
    final inner = detail.detail;
    final type = inner['type'];
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
    }
  }
}
