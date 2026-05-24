import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../application/reactions_provider.dart';
import '../data/message_api.dart';

/// Aggregated reaction chips for a single message. Mirrors the web reference's
/// `components/Message/Reaction.tsx`:
///   - one chip per emoji that has at least 1 reactor
///   - chip shows count when >1
///   - chip highlighted (cyan border) if the current user reacted
///   - tooltip lists reactor names + emoji name
///   - tapping a chip toggles the current user's reaction
class ReactionBar extends ConsumerWidget {
  const ReactionBar({
    super.key,
    required this.mid,
  });

  final int mid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions = ref.watch(messageReactionsProvider(mid));
    if (reactions == null || reactions.isEmpty) return const SizedBox.shrink();

    final authState = ref.watch(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : -1;

    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in entries)
            _ReactionChip(
              mid: mid,
              emoji: entry.key,
              uids: entry.value,
              reactedByCurrentUser: entry.value.contains(currentUid),
            ),
        ],
      ),
    );
  }
}

class _ReactionChip extends ConsumerWidget {
  const _ReactionChip({
    required this.mid,
    required this.emoji,
    required this.uids,
    required this.reactedByCurrentUser,
  });

  final int mid;
  final String emoji;
  final List<int> uids;
  final bool reactedByCurrentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final names = uids
        .map((id) => userDir[id]?.name ?? 'Deleted User')
        .toList(growable: false);
    final tooltip = names.length > 3
        ? '${names.take(3).join(', ')} and ${names.length - 3} others reacted with $emoji'
        : '${names.join(', ')} reacted with $emoji';

    final bg = reactedByCurrentUser ? AppTokens.primary50 : AppTokens.gray100;
    final border = reactedByCurrentUser
        ? AppTokens.primary500
        : AppTokens.borderSubtle;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _toggle(ref),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 14, height: 1.2),
              ),
              if (uids.length > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '${uids.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: reactedByCurrentUser
                        ? AppTokens.primary500
                        : AppTokens.gray700,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref) async {
    final authState = ref.read(authControllerProvider).valueOrNull;
    final uid =
        authState is AuthStateAuthenticated ? authState.user.uid : null;
    if (uid != null) {
      // Optimistic: flip the chip locally so the tap feels instant. The SSE
      // echo will arrive moments later but is deduped by reactionMid.
      ref
          .read(reactionsProvider.notifier)
          .toggleLocal(targetMid: mid, fromUid: uid, emoji: emoji);
    }
    try {
      await ref.read(messageApiProvider).reactMessage(mid, emoji);
    } catch (_) {
      // Roll back the optimistic toggle if the server rejected.
      if (uid != null) {
        ref
            .read(reactionsProvider.notifier)
            .toggleLocal(targetMid: mid, fromUid: uid, emoji: emoji);
      }
    }
  }
}

/// 8-emoji picker rendered as a small floating panel. Mirrors
/// `components/Message/ReactionPicker.tsx`.
class ReactionPicker extends ConsumerWidget {
  const ReactionPicker({
    super.key,
    required this.mid,
    required this.onPicked,
  });

  final int mid;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : -1;
    final reactions = ref.watch(messageReactionsProvider(mid)) ?? const {};

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final emoji in kReactionEmojis)
            _PickerCell(
              emoji: emoji,
              reacted:
                  (reactions[emoji] ?? const []).contains(currentUid),
              onTap: () async {
                onPicked();
                final uid = currentUid > 0 ? currentUid : null;
                if (uid != null) {
                  ref.read(reactionsProvider.notifier).toggleLocal(
                        targetMid: mid,
                        fromUid: uid,
                        emoji: emoji,
                      );
                }
                try {
                  await ref
                      .read(messageApiProvider)
                      .reactMessage(mid, emoji);
                } catch (_) {
                  if (uid != null) {
                    ref.read(reactionsProvider.notifier).toggleLocal(
                          targetMid: mid,
                          fromUid: uid,
                          emoji: emoji,
                        );
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}

class _PickerCell extends StatelessWidget {
  const _PickerCell({
    required this.emoji,
    required this.reacted,
    required this.onTap,
  });

  final String emoji;
  final bool reacted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: reacted ? AppTokens.primary50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 20, height: 1.2),
        ),
      ),
    );
  }
}
