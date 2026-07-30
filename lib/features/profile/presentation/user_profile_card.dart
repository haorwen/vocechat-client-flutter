import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../channels/application/pending_chat_selection.dart';
import '../../contacts/application/contacts_provider.dart';
import '../../contacts/application/user_directory_provider.dart';

/// Opens a profile card for [uid] — mirrors the web reference's clickable
/// avatar popover (`components/Message/index.tsx` + `components/Profile`):
/// avatar, name, uid tag, email when known, and a Message action that opens
/// the DM. Shown as a centered card on wide layouts, a bottom sheet on
/// narrow ones.
Future<void> showUserProfileOverlay(BuildContext context, {required int uid}) {
  final isWide = MediaQuery.sizeOf(context).width >= 700;
  if (isWide) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: _UserProfileCard(uid: uid),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _UserProfileCard(uid: uid, narrow: true),
    ),
  );
}

class _UserProfileCard extends ConsumerWidget {
  const _UserProfileCard({required this.uid, this.narrow = false});

  final int uid;
  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final contacts = ref.watch(contactsProvider).valueOrNull ?? const [];
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final baseUrl = serverState?.servers
            .where((s) => s.id == serverState.currentServerId)
            .firstOrNull
            ?.baseUrl ??
        '';
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : -1;

    final user = userDir[uid];
    final name = user?.name ?? l.chatUserFallback(uid);
    String? avatarUrl;
    if (user != null && (user.avatarUpdatedAt ?? 0) > 0 && baseUrl.isNotEmpty) {
      avatarUrl =
          '$baseUrl/api/resource/avatar?uid=$uid&t=${user.avatarUpdatedAt}';
    }
    final email = contacts.where((c) => c.uid == uid).firstOrNull?.email;
    final canMessage = uid != currentUid && uid > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: narrow
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : BorderRadius.circular(16),
        boxShadow: narrow
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoceAvatar(name: safeText(name), imageUrl: avatarUrl, size: 80),
          const SizedBox(height: 12),
          Text(
            safeText(name),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTokens.gray800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '#$uid',
            style: TextStyle(fontSize: 13, color: AppTokens.gray400),
          ),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              safeText(email),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppTokens.gray400),
            ),
          ],
          if (canMessage) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _ProfileCardAction(
                    icon: Icons.chat_bubble_outline,
                    label: l.contactsMessage,
                    isPrimary: true,
                    onTap: () => _openChat(context, ref, uid),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _ProfileCardAction(
                    icon: Icons.call_outlined,
                    label: l.contactsCall,
                    onTap: () => _showComingSoon(context),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _ProfileCardAction(
                    icon: Icons.more_horiz,
                    label: l.actionMore,
                    onTap: () => _showComingSoon(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openChat(BuildContext context, WidgetRef ref, int uid) {
    Navigator.of(context).pop();
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    if (isWide) {
      ref.read(pendingChatSelectionProvider.notifier).request('u-$uid');
      context.go('/home');
    } else {
      context.go('/home/chat/u-$uid');
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppL10n.of(context).comingSoon),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ProfileCardAction extends StatelessWidget {
  const _ProfileCardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: AppTokens.hover,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 96, minWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? AppTokens.gray50 : AppTokens.gray100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppTokens.gray500),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTokens.gray500,
                height: 18 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
