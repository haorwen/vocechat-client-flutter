import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a chat route id (`u-<uid>` / `g-<gid>`) that a non-home screen wants
/// the chat list to select on next build. The chat list reads it in
/// `didChangeDependencies`, applies it to its internal selected-id state, and
/// clears the request so navigating away and back does not re-trigger.
class PendingChatSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String routeId) => state = routeId;

  void clear() {
    if (state != null) state = null;
  }
}

final pendingChatSelectionProvider =
    NotifierProvider<PendingChatSelectionNotifier, String?>(
  PendingChatSelectionNotifier.new,
);
