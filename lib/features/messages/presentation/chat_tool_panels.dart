import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../application/chat_tools_provider.dart';

// ---------------------------------------------------------------------------
// Chat tool overlays — Pinned / Saved / Members
//
// Layout rules
// -----------
// Wide (>=700): show as a dialog-like popover anchored to the right side of
// the chat surface (480px wide, ~60% screen tall), with a subtle shadow and
// rounded corners.
// Narrow (<700): show as a near-full bottom sheet (90% of screen height).
// ---------------------------------------------------------------------------

enum ChatTool { pin, saved, members }

Future<void> showChatToolOverlay(
  BuildContext context, {
  required ChatTool tool,
  required int targetId,
  required bool isChannel,
}) {
  final size = MediaQuery.sizeOf(context);
  final isWide = size.width >= 700;
  final l = AppL10n.of(context);
  final String title = switch (tool) {
    ChatTool.pin => l.chatToolPin,
    ChatTool.saved => l.chatToolSaved,
    ChatTool.members => l.chatToolMembers,
  };

  Widget body() {
    switch (tool) {
      case ChatTool.pin:
        return _PinListPanel(gid: targetId);
      case ChatTool.saved:
        return _FavListPanel(targetId: targetId, isChannel: isChannel);
      case ChatTool.members:
        return _MembersListPanel(gid: targetId);
    }
  }

  if (isWide) {
    // Anchored right-side popover.
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      pageBuilder: (ctx, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 76, top: 16, bottom: 16),
              child: Material(
                color: Colors.transparent,
                child: _ToolCard(title: title, child: body()),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 160),
    );
  }

  // Narrow: full-height bottom sheet.
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (ctx) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: _ToolCard(title: title, narrow: true, child: body()),
      );
    },
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.child,
    this.narrow = false,
  });

  final String title;
  final Widget child;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: narrow
          ? const BoxConstraints.expand()
          : const BoxConstraints(maxWidth: 480, maxHeight: 720, minHeight: 420),
      child: Container(
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
        child: Column(
          children: [
            _ToolHeader(title: title),
            const Divider(height: 1, color: AppTokens.gray200),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _ToolHeader extends StatelessWidget {
  const _ToolHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close,
                  size: 18, color: AppTokens.gray500),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pin list — reads channel.pinned_messages from GroupSummary
// ---------------------------------------------------------------------------

class _PinListPanel extends ConsumerWidget {
  const _PinListPanel({required this.gid});
  final int gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final group = ref.watch(groupDirectoryProvider).valueOrNull?[gid];
    final pins = group?.pinnedMessages ?? const [];
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};

    if (pins.isEmpty) {
      return _EmptyState(label: l.chatToolPinEmpty);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: pins.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppTokens.gray200),
      itemBuilder: (ctx, i) {
        final p = pins[i];
        final user = userDir[p.createdBy];
        return _MessageListTile(
          name: user?.name ?? l.chatUserFallback(p.createdBy),
          avatarUrl: _userAvatarUrl(ref, p.createdBy, user?.avatarUpdatedAt),
          createdAt: p.createdAt,
          content: p.content,
          contentType: p.contentType,
          trailing: IconButton(
            tooltip: l.chatToolUnpin,
            icon: const Icon(Icons.close,
                size: 16, color: AppTokens.gray500),
            onPressed: () async {
              final ok = await ref
                  .read(chatToolsProvider)
                  .unpin(gid: gid, mid: p.mid);
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(
                    ok ? l.chatToolUnpinned : l.chatToolUnpinFail),
              ));
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Favorite list — reads favoritesProvider
// ---------------------------------------------------------------------------

class _FavListPanel extends ConsumerWidget {
  const _FavListPanel({required this.targetId, required this.isChannel});
  final int targetId;
  final bool isChannel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final favsAsync = ref.watch(favoritesProvider);
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};

    return favsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => _EmptyState(label: l.errorPrefix(e.toString())),
      data: (favs) {
        if (favs.isEmpty) {
          return _EmptyState(label: l.chatToolSavedEmpty);
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: favs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppTokens.gray200),
          itemBuilder: (ctx, i) {
            final fav = favs[i];
            final first =
                fav.messages.isNotEmpty ? fav.messages.first : null;
            final user = first != null ? userDir[first.fromUid] : null;
            return _MessageListTile(
              name: user?.name ??
                  (first != null
                      ? l.chatUserFallback(first.fromUid)
                      : '—'),
              avatarUrl:
                  _userAvatarUrl(ref, first?.fromUid ?? 0, user?.avatarUpdatedAt),
              createdAt: fav.createdAt,
              content: first?.content ?? '',
              contentType: first?.contentType ?? 'text/plain',
              trailing: IconButton(
                tooltip: l.chatToolRemoveFav,
                icon: const Icon(Icons.close,
                    size: 16, color: AppTokens.gray500),
                onPressed: () async {
                  final ok = await ref
                      .read(favoritesProvider.notifier)
                      .remove(fav.id);
                  if (!ctx.mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(l.chatToolRemoveFavFail),
                    ));
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Members list — reads channel.members or full user dir for public channels
// ---------------------------------------------------------------------------

class _MembersListPanel extends ConsumerWidget {
  const _MembersListPanel({required this.gid});
  final int gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final group = ref.watch(groupDirectoryProvider).valueOrNull?[gid];
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};

    if (group == null) {
      return _EmptyState(label: l.chatToolMembersEmpty);
    }

    // Public channel → everyone is a member. Private → use group.members.
    final uids = group.isPublic
        ? userDir.keys.toList(growable: false)
        : group.members;
    if (uids.isEmpty) {
      return _EmptyState(label: l.chatToolMembersEmpty);
    }

    // Owner first, then alphabetical by name.
    final sorted = [...uids]..sort((a, b) {
        if (a == group.owner) return -1;
        if (b == group.owner) return 1;
        final na = userDir[a]?.name ?? '';
        final nb = userDir[b]?.name ?? '';
        return na.compareTo(nb);
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppTokens.gray200, indent: 64),
      itemBuilder: (ctx, i) {
        final uid = sorted[i];
        final user = userDir[uid];
        final name = user?.name ?? l.chatUserFallback(uid);
        final isOwner = uid == group.owner;
        return ListTile(
          dense: true,
          leading: VoceAvatar(
            name: name,
            imageUrl: _userAvatarUrl(ref, uid, user?.avatarUpdatedAt),
            size: 36,
          ),
          title: Text(
            safeText(name),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C1E),
            ),
          ),
          subtitle: isOwner
              ? const Text('Owner',
                  style: TextStyle(
                      fontSize: 12, color: AppTokens.gray500))
              : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared message tile + helpers
// ---------------------------------------------------------------------------

class _MessageListTile extends StatelessWidget {
  const _MessageListTile({
    required this.name,
    required this.avatarUrl,
    required this.createdAt,
    required this.content,
    required this.contentType,
    this.trailing,
  });

  final String name;
  final String? avatarUrl;
  final int createdAt;
  final String content;
  final String contentType;
  final Widget? trailing;

  String _previewContent() {
    if (contentType.startsWith('text/')) return content;
    if (contentType.startsWith('image/')) return '[image]';
    if (contentType == 'vocechat/file') return '[file]';
    return content.isEmpty ? '[$contentType]' : content;
  }

  String _formatTime() {
    if (createdAt == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true)
        .toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (messageDay == today) return '$hh:$mm';
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$mo-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoceAvatar(name: name, imageUrl: avatarUrl, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        safeText(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTokens.gray400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  safeText(_previewContent()),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppTokens.gray500),
        ),
      ),
    );
  }
}

String? _userAvatarUrl(WidgetRef ref, int uid, int? avatarUpdatedAt) {
  if (uid == 0) return null;
  if ((avatarUpdatedAt ?? 0) == 0) return null;
  final serverState = ref.read(serverStoreProvider).valueOrNull;
  final server = serverState?.servers
      .where((s) => s.id == serverState.currentServerId)
      .firstOrNull;
  final base = server?.baseUrl ?? '';
  if (base.isEmpty) return null;
  return '$base/api/resource/avatar?uid=$uid';
}
