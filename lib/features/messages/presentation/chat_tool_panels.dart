import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../contacts/application/user_directory_provider.dart';
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
              Divider(height: 1, color: AppTokens.gray200),
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
                icon: Icon(Icons.close,
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
              ? Text('Owner',
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
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTokens.gray500),
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
    barrierLabel: 'dismiss',
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
                          final name =
                              user?.name ?? 'uid:${msg.fromUid}';
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
