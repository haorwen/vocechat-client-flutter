import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reactions_provider.g.dart';

/// Supported emojis — matches the web reference's `ReactionItem` set, in the
/// same display order used by the picker.
const List<String> kReactionEmojis = [
  '\u{1F44D}', // 👍 thumb up
  '\u{1F44E}', // 👎 thumb down
  '\u{1F604}', // 😄 smile
  '\u{1F440}', // 👀 eyes
  '\u{1F680}', // 🚀 rocket
  '\u{2764}\u{FE0F}', // ❤️ heart
  '\u{1F641}', // 🙁 unhappy
  '\u{1F389}', // 🎉 party
];

/// Per-message reaction state: { mid -> { emoji -> [uid, ...] } }.
///
/// Mirrors the web client's `message.reaction.ts` slice. We keep this as a
/// dedicated provider (separate from `ChatController`) for two reasons:
///   1. Reactions are global to the workspace: a reaction on a message in
///      channel A may arrive while channel B is open. The lookup is by `mid`,
///      not by target.
///   2. `ChatController` lists are partial (we only have the recent window).
///      Reaction events for older messages still need somewhere to land so
///      they're correct if the user scrolls back.
@Riverpod(keepAlive: true)
class Reactions extends _$Reactions {
  /// Set of reaction message ids we've already applied. The server delivers
  /// reactions as their own chat messages; on SSE reconnect they can be
  /// replayed. Tracking the reaction's own mid (the OUTER `mid` of the
  /// MessageDetail.reaction wrapper) gives us idempotency.
  final Set<int> _appliedReactionMids = {};

  /// Local optimistic toggles awaiting their SSE echo. Key encodes
  /// (targetMid, fromUid, emoji). When the matching echo arrives, we consume
  /// the marker instead of re-applying the toggle — otherwise the chip would
  /// flicker back to its previous state.
  final Set<String> _pendingLocalToggles = {};

  String _pendingKey(int targetMid, int fromUid, String emoji) =>
      '$targetMid|$fromUid|$emoji';

  @override
  Map<int, Map<String, List<int>>> build() => {};

  /// Toggle a reaction triggered by a "like"-type reaction message.
  ///
  /// [reactionMid] — the SSE-delivered reaction message's own mid (used to
  /// dedupe replays).
  /// [targetMid]   — the original message being reacted to.
  /// [fromUid]     — the user who reacted.
  /// [emoji]       — the reaction action string (an emoji codepoint).
  void applyLike({
    required int reactionMid,
    required int targetMid,
    required int fromUid,
    required String emoji,
  }) {
    if (_appliedReactionMids.contains(reactionMid)) return;
    _appliedReactionMids.add(reactionMid);

    // If we've already toggled this (uid, targetMid, emoji) locally via the
    // optimistic UI path, the SSE echo would flip it back. Consume the pending
    // marker instead so the visible state stays in sync with reality.
    final pendingKey = _pendingKey(targetMid, fromUid, emoji);
    if (_pendingLocalToggles.remove(pendingKey)) return;

    state = _applyToggle(state, targetMid, fromUid, emoji);
  }

  /// Drop reactions associated with a deleted message.
  void removeFor(int targetMid) {
    if (!state.containsKey(targetMid)) return;
    final next = _cloneState();
    next.remove(targetMid);
    state = next;
  }

  /// Optimistic local toggle: the user just tapped a reaction in the UI; we
  /// flip it immediately and let the SSE echo confirm (dedupe via the pending
  /// marker so the echo doesn't flip it back).
  void toggleLocal({
    required int targetMid,
    required int fromUid,
    required String emoji,
  }) {
    final key = _pendingKey(targetMid, fromUid, emoji);
    // If a pending marker already exists, this is the rollback path: we're
    // un-doing our own optimistic toggle, so clear the marker too — otherwise
    // the SSE echo (if it eventually lands) would be silently swallowed.
    if (!_pendingLocalToggles.remove(key)) {
      _pendingLocalToggles.add(key);
    }
    state = _applyToggle(state, targetMid, fromUid, emoji);
  }

  Map<int, Map<String, List<int>>> _applyToggle(
    Map<int, Map<String, List<int>>> current,
    int targetMid,
    int fromUid,
    String emoji,
  ) {
    final next = _cloneState();
    final perMessage = Map<String, List<int>>.from(next[targetMid] ?? const {});
    final uids = List<int>.from(perMessage[emoji] ?? const []);
    final idx = uids.indexOf(fromUid);
    if (idx >= 0) {
      uids.removeAt(idx);
    } else {
      uids.add(fromUid);
    }
    if (uids.isEmpty) {
      perMessage.remove(emoji);
    } else {
      perMessage[emoji] = uids;
    }
    if (perMessage.isEmpty) {
      next.remove(targetMid);
    } else {
      next[targetMid] = perMessage;
    }
    return next;
  }

  Map<int, Map<String, List<int>>> _cloneState() {
    return {
      for (final e in state.entries)
        e.key: {
          for (final r in e.value.entries) r.key: List<int>.from(r.value),
        },
    };
  }
}

/// Convenience selector — reactions for a single message id (returns null if
/// none, so widgets can early-return without rebuilding on unrelated changes).
@riverpod
Map<String, List<int>>? messageReactions(Ref ref, int mid) {
  final all = ref.watch(reactionsProvider);
  return all[mid];
}
