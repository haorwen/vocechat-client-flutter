import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/sse_client.dart';
import '../../channels/application/conversation_providers.dart';
import '../../contacts/application/presence_provider.dart';
import '../domain/message_models.dart';
import 'chat_controller.dart';

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

          // Update the conversation list preview/timestamp.
          ref
              .read(conversationsProvider.notifier)
              .applyIncomingMessage(msg);

          // Hand the message to the per-target chat controller. This both
          // builds the controller if needed (so subsequent navigation finds
          // it ready) and appends the message to its in-memory list.
          ref
              .read(chatControllerProvider(msg.target).notifier)
              .applyIncomingMessage(msg);
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
}
