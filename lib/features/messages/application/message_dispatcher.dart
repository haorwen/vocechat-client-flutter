import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/sse_client.dart';
import '../../channels/application/conversation_providers.dart';
import '../domain/message_models.dart';
import 'chat_controller.dart';

part 'message_dispatcher.g.dart';

/// Long-lived listener that routes every incoming SSE chat event to:
///   1. the conversations list (so previews update on the left), and
///   2. the per-target ChatController (so the chat screen has the message
///      ready the moment it's opened, even if it had never been opened
///      before — and stays in sync while it's in the background).
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
        }
      });
    });
  }
}
