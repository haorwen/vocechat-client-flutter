import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../application/burn_after_read_provider.dart';
import '../application/chat_tools_provider.dart';
import '../domain/message_models.dart';

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

enum ChatTool { pin, saved, members, autoDelete }

Future<void> showChatToolOverlay(
  BuildContext context, {
  required ChatTool tool,
  required int targetId,
  required bool isChannel,
}) {
  final l = AppL10n.of(context);
  final String title = switch (tool) {
    ChatTool.pin => l.chatToolPin,
    ChatTool.saved => l.chatToolSaved,
    ChatTool.members => l.chatToolMembers,
    ChatTool.autoDelete => l.chatAutoDeleteTitle,
  };

  final Widget body = switch (tool) {
    ChatTool.pin => _PinListPanel(gid: targetId),
    ChatTool.saved => _FavListPanel(targetId: targetId, isChannel: isChannel),
    ChatTool.members => _MembersListPanel(gid: targetId),
    ChatTool.autoDelete =>
      _AutoDeletePanel(targetId: targetId, isChannel: isChannel),
  };

  return _showToolCardOverlay(context, title: title, body: body);
}

Future<void> _showToolCardOverlay(
  BuildContext context, {
  required String title,
  required Widget body,
}) {
  final size = MediaQuery.sizeOf(context);
  final isWide = size.width >= 700;
  final l = AppL10n.of(context);

  if (isWide) {
    // Anchored right-side popover.
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l.actionClose,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      pageBuilder: (ctx, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 76, top: 16, bottom: 16),
              child: Material(
                color: Colors.transparent,
                child: _ToolCard(title: title, child: body),
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
        child: _ToolCard(title: title, narrow: true, child: body),
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
            Divider(height: 1, color: AppTokens.gray200),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTokens.textHeading,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: AppL10n.of(context).actionClose,
              icon: Icon(Icons.close,
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
    final groupsAsync = ref.watch(groupDirectoryProvider);
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};

    // While the directory is loading, show a spinner instead of flashing the
    // "no pins" empty state.
    if (groupsAsync.isLoading && !groupsAsync.hasValue) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final group = groupsAsync.valueOrNull?[gid];
    final pins = group?.pinnedMessages ?? const [];

    if (pins.isEmpty) {
      return _EmptyState(label: l.chatToolPinEmpty);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: pins.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppTokens.gray200),
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
            icon: Icon(Icons.close,
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
// Favorite list — reads favoritesProvider.
//
// Web reference: routes/chat/FavList.tsx + hooks/useFavMessage.ts (chat
// scope) and routes/favs/index.tsx (global scope). When [targetId] is set,
// an archive is shown only when every bundled message's `source` matches
// this channel (gid) or DM peer (uid); when null all favorites are shown,
// each with a source line ("# channel" / "From user"). Author name/avatar
// come from the archive's own denormalized `users` list — the avatar is an
// archive attachment served by
// GET /api/favorite/attachment/:uid/:id/:attachment_id (uid = the favoriting
// user, i.e. the current user).
// ---------------------------------------------------------------------------

/// Standalone favorites overlay (all favorites, ungated by conversation) —
/// used by the desktop left rail's "Saved" destination.
Future<void> showFavoritesOverlay(BuildContext context) {
  return _showToolCardOverlay(
    context,
    title: AppL10n.of(context).chatToolSaved,
    body: const _FavListPanel(targetId: null, isChannel: null),
  );
}

class _FavListPanel extends ConsumerWidget {
  const _FavListPanel({required this.targetId, required this.isChannel});

  /// Conversation filter — null shows every favorite (global view).
  final int? targetId;
  final bool? isChannel;

  bool _matchesConversation(FavoriteArchive fav) {
    final id = targetId;
    if (id == null) return true;
    final messages = fav.archive.messages;
    if (messages.isEmpty) return false;
    return messages.every((m) {
      final source = m.source;
      if (source == null) return false;
      return source.map(
        user: (s) => isChannel == false && s.uid == id,
        group: (s) => isChannel == true && s.gid == id,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final favsAsync = ref.watch(favoritesProvider);

    final authState = ref.watch(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : 0;

    return favsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => _EmptyState(label: l.errorPrefix(e.toString())),
      data: (all) {
        final favs = all.where(_matchesConversation).toList(growable: false);
        if (favs.isEmpty) {
          return _EmptyState(label: l.chatToolSavedEmpty);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: favs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) => _FavArchiveCard(
            fav: favs[i],
            currentUid: currentUid,
            showSource: targetId == null,
          ),
        );
      },
    );
  }
}

/// One favorite archive rendered as a card: bundled messages with the
/// archive's own author info, save date, and a remove button.
class _FavArchiveCard extends ConsumerWidget {
  const _FavArchiveCard({
    required this.fav,
    required this.currentUid,
    this.showSource = false,
  });

  final FavoriteArchive fav;
  final int currentUid;
  final bool showSource;

  String? _attachmentUrl(WidgetRef ref, int? attachmentId) {
    if (attachmentId == null || currentUid <= 0) return null;
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    final server = serverState?.servers
        .where((s) => s.id == serverState.currentServerId)
        .firstOrNull;
    final base = server?.baseUrl ?? '';
    if (base.isEmpty) return null;
    return '$base/api/favorite/attachment/$currentUid/${fav.id}/$attachmentId';
  }

  String _preview(AppL10n l, ArchiveMessageBody body) {
    final ct = body.contentType;
    if (ct == 'text/plain' || ct == 'text/markdown') {
      return (body.content ?? '').trim();
    }
    if (ct == 'vocechat/file') {
      final fileType =
          (body.properties?['content_type'] as String?) ?? '';
      final name = body.properties?['name'] as String?;
      if (fileType.startsWith('image/')) {
        return name == null ? l.previewImage : '${l.previewImage} $name';
      }
      return name ?? l.previewFile;
    }
    if (ct == 'vocechat/archive') return l.archiveForwardedLabel;
    return '[${ct.split('/').last}]';
  }

  String _formatDate(int createdAt) {
    if (createdAt == 0) return '';
    final dt =
        DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true).toLocal();
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mo-$d';
  }

  /// "# channel-name" / "From user-name" line for the global view, derived
  /// from the first bundled message's source (mirrors web routes/favs).
  Widget? _sourceLabel(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final source = fav.archive.messages.firstOrNull?.source;
    if (source == null) return null;
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};
    final groupDir = ref.watch(groupDirectoryProvider).valueOrNull ?? {};
    final (IconData icon, String label) = source.map(
      user: (s) => (
        Icons.person_outline,
        userDir[s.uid]?.name ?? l.chatUserFallback(s.uid),
      ),
      group: (s) => (
        Icons.tag,
        groupDir[s.gid]?.name ?? l.chatGroupFallback(s.gid),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTokens.gray400),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            safeText(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTokens.gray500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final archive = fav.archive;
    final sourceLabel = showSource ? _sourceLabel(context, ref) : null;

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.canvasAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (sourceLabel != null) ...[
                Flexible(child: sourceLabel),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  _formatDate(fav.createdAt),
                  style: TextStyle(fontSize: 12, color: AppTokens.gray400),
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: l.chatToolRemoveFav,
                  icon: Icon(Icons.close, size: 16, color: AppTokens.gray500),
                  onPressed: () async {
                    final ok = await ref
                        .read(favoritesProvider.notifier)
                        .remove(fav.id);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l.chatToolRemoveFavFail),
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
          for (var i = 0; i < archive.messages.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _favMessageRow(context, ref, archive, archive.messages[i]),
          ],
        ],
      ),
    );
  }

  Widget _favMessageRow(
    BuildContext context,
    WidgetRef ref,
    Archive archive,
    ArchiveMessage message,
  ) {
    final l = AppL10n.of(context);
    final user =
        (message.fromUser >= 0 && message.fromUser < archive.users.length)
            ? archive.users[message.fromUser]
            : null;
    final name = user?.name ?? '';
    final avatarUrl = _attachmentUrl(ref, user?.avatar);

    // Image favorites render the actual thumbnail (served straight from the
    // archive attachment endpoint); everything else gets a text preview.
    final body = message.content;
    final fileType = (body.properties?['content_type'] as String?) ?? '';
    final isImage = body.contentType == 'vocechat/file' &&
        fileType.startsWith('image/') &&
        body.fileId != null;
    final imageUrl =
        isImage ? _attachmentUrl(ref, body.thumbnailId ?? body.fileId) : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VoceAvatar(name: name, imageUrl: avatarUrl, size: 32),
        const SizedBox(width: 10),
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.textHeading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(message.createdAt),
                    style: TextStyle(fontSize: 11, color: AppTokens.gray400),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 220, maxHeight: 160),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        l.previewImage,
                        style: TextStyle(
                            fontSize: 13, color: AppTokens.gray600),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  safeText(_preview(l, body)),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTokens.gray600,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ],
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
    final groupsAsync = ref.watch(groupDirectoryProvider);
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};

    if (groupsAsync.isLoading && !groupsAsync.hasValue) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final group = groupsAsync.valueOrNull?[gid];

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
          Divider(height: 1, color: AppTokens.gray200, indent: 64),
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTokens.textHeading,
            ),
          ),
          subtitle: isOwner
              ? Text(l.memberRoleOwner,
                  style: TextStyle(
                      fontSize: 12, color: AppTokens.gray500))
              : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-delete (burn-after-read) settings — radio picker + save.
//
// Server contract: POST /api/user/burn-after-reading with
// {"users":[{"uid","expires_in"}]} or {"groups":[{"gid","expires_in"}]}.
// Options mirror the web reference's AutoDeleteMessages.tsx exactly: Off (0),
// 5 min (300), 10 min (600), 1 hour (3600), 1 day (86400), 1 week (604800).
// No countdown/deletion animation here — the task scopes that out even
// though the web reference's ExpireTimer.tsx implements a live countdown;
// this panel only sets the sender-side setting, which the server then stamps
// onto subsequently-sent messages' `expires_in` automatically.
// ---------------------------------------------------------------------------

class _AutoDeletePanel extends ConsumerStatefulWidget {
  const _AutoDeletePanel({required this.targetId, required this.isChannel});
  final int targetId;
  final bool isChannel;

  @override
  ConsumerState<_AutoDeletePanel> createState() => _AutoDeletePanelState();
}

class _AutoDeletePanelState extends ConsumerState<_AutoDeletePanel> {
  static const _options = <int>[0, 300, 600, 3600, 86400, 604800];

  String _labelFor(AppL10n l, int value) {
    return switch (value) {
      0 => l.chatAutoDeleteOff,
      300 => l.chatAutoDelete5Min,
      600 => l.chatAutoDelete10Min,
      3600 => l.chatAutoDelete1Hour,
      86400 => l.chatAutoDelete1Day,
      604800 => l.chatAutoDelete1Week,
      _ => '$value',
    };
  }

  late int _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(burnAfterReadProvider);
    _selected = widget.isChannel
        ? state.groupExpiresIn(widget.targetId)
        : state.userExpiresIn(widget.targetId);
    if (!_options.contains(_selected)) _selected = 0;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notifier = ref.read(burnAfterReadProvider.notifier);
    final ok = widget.isChannel
        ? await notifier.setGroup(widget.targetId, _selected)
        : await notifier.setUser(widget.targetId, _selected);
    if (!mounted) return;
    final l = AppL10n.of(context);
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l.chatAutoDeleteSaved : l.chatAutoDeleteSaveFailed),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _options.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppTokens.gray200),
            itemBuilder: (ctx, i) {
              final value = _options[i];
              return RadioListTile<int>(
                value: value,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v ?? 0),
                activeColor: AppTokens.primary400,
                title: Text(
                  _labelFor(l, value),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTokens.textHeading,
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, color: AppTokens.gray200),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.chatEditSave),
            ),
          ),
        ),
      ],
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.textHeading,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(),
                      style: TextStyle(
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
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTokens.gray600,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTokens.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_outlined,
                  size: 22, color: AppTokens.gray400),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTokens.gray500),
            ),
          ],
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

// ---------------------------------------------------------------------------
// Search overlay — web-style 320px dropdown anchored to the search icon.
// Narrow screens: anchored to top of screen, full-width minus 16px gutter.
// ---------------------------------------------------------------------------

Future<void> showSearchOverlay(
  BuildContext context, {
  required GlobalKey anchorKey,
  required List<ChatMessage> messages,
  required Map<int, UserSummary> userDir,
  required String? Function(int uid, int? avatarUpdatedAt) avatarUrlBuilder,
  required Future<void> Function(int mid) onLocate,
}) {
  final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final screen = MediaQuery.sizeOf(context);
  final isWide = screen.width >= 700;

  // Compute anchor position so the dropdown opens right-aligned under the
  // search icon (web behaviour: `top-full right-0`).
  Offset anchorOffset = Offset.zero;
  Size anchorSize = const Size(32, 32);
  if (renderBox != null && renderBox.attached) {
    anchorOffset = renderBox.localToGlobal(Offset.zero);
    anchorSize = renderBox.size;
  }

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppL10n.of(context).actionClose,
    barrierColor: Colors.transparent,
    pageBuilder: (ctx, _, __) {
      final width = isWide ? 320.0 : screen.width - 16.0;
      final left = isWide
          ? (anchorOffset.dx + anchorSize.width - width)
              .clamp(8.0, screen.width - width - 8.0)
          : 8.0;
      final top = isWide
          ? (anchorOffset.dy + anchorSize.height + 6)
          : MediaQuery.viewPaddingOf(ctx).top + 8.0;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Material(
              color: Colors.transparent,
              child: _SearchPopover(
                messages: messages,
                userDir: userDir,
                avatarUrlBuilder: avatarUrlBuilder,
                onLocate: (mid) async {
                  Navigator.of(ctx).pop();
                  await onLocate(mid);
                },
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 140),
  );
}

class _SearchPopover extends StatefulWidget {
  const _SearchPopover({
    required this.messages,
    required this.userDir,
    required this.avatarUrlBuilder,
    required this.onLocate,
  });

  final List<ChatMessage> messages;
  final Map<int, UserSummary> userDir;
  final String? Function(int uid, int? avatarUpdatedAt) avatarUrlBuilder;
  final ValueChanged<int> onLocate;

  @override
  State<_SearchPopover> createState() => _SearchPopoverState();
}

class _SearchPopoverState extends State<_SearchPopover> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<ChatMessage> _results() {
    if (_query.trim().isEmpty) return const [];
    final q = _query.toLowerCase();
    final matches = widget.messages.where((m) {
      final d = m.detail;
      final text = switch (d) {
        NormalMessageDetail() => d.content,
        ReplyMessageDetail() => d.content,
        _ => '',
      };
      // Plain text / markdown only — mirrors web's MessageSearch.
      final ct = switch (d) {
        NormalMessageDetail() => d.contentType,
        ReplyMessageDetail() => d.contentType,
        _ => '',
      };
      if (ct != 'text/plain' && ct != 'text/markdown') return false;
      return text.toLowerCase().contains(q);
    }).toList();
    matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches.length > 50 ? matches.sublist(0, 50) : matches;
  }

  String _formatTime(int createdAt) {
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
    final l = AppL10n.of(context);
    final results = _results();
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTokens.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTokens.gray100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                          fontSize: 14, color: AppTokens.textHeading),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: l.chatSearchHint,
                        hintStyle: TextStyle(
                            fontSize: 14, color: AppTokens.gray400),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.actionClose,
                  icon: Icon(Icons.close,
                      size: 18, color: AppTokens.gray500),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTokens.gray200),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 384),
            child: _query.trim().isEmpty
                ? const SizedBox.shrink()
                : results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l.chatSearchEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppTokens.gray500),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: results.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, color: AppTokens.gray100, indent: 60),
                        itemBuilder: (ctx, i) {
                          final msg = results[i];
                          final user = widget.userDir[msg.fromUid];
                          final name = user?.name ??
                              l.chatUserFallback(msg.fromUid);
                          final content = switch (msg.detail) {
                            NormalMessageDetail() =>
                              (msg.detail as NormalMessageDetail).content,
                            ReplyMessageDetail() =>
                              (msg.detail as ReplyMessageDetail).content,
                            _ => '',
                          };
                          return InkWell(
                            onTap: () => widget.onLocate(msg.mid),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 10, 12, 10),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  VoceAvatar(
                                    name: name,
                                    imageUrl: widget.avatarUrlBuilder(
                                        msg.fromUid, user?.avatarUpdatedAt),
                                    size: 32,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                safeText(name),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: AppTokens.textHeading,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatTime(msg.createdAt),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTokens.gray400),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          safeText(content),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppTokens.gray600,
                                              height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
