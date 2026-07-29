import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/loading_capsule.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../../shared/widgets/voce_context_menu.dart';
import '../../../features/contacts/application/presence_provider.dart';
import '../../../features/contacts/application/user_directory_provider.dart';
import '../../../features/messages/presentation/chat_screen.dart';
import '../../../features/messages/application/read_index_provider.dart';
import '../application/conversation_providers.dart';
import '../application/muted_chats_provider.dart';
import '../application/pending_chat_selection.dart';
import '../application/pinned_chats_provider.dart';
import '../data/pin_chat_api.dart';
import '../data/session_actions_api.dart';
import '../domain/pin_chat_models.dart';
import 'create_channel_dialog.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final m = RegExp(r'^/home/chat/(.+)$').firstMatch(location);
    if (m != null) {
      final id = m.group(1)!;
      if (_selectedId != id) _selectedId = id;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cross-screen selection request (e.g. from the contacts profile "message"
    // button on wide layouts). Listen here rather than in didChangeDependencies
    // because StatefulShellRoute keeps this branch's State alive between tab
    // switches, so didChangeDependencies will not fire when we revisit /home.
    ref.listen<String?>(pendingChatSelectionProvider, (prev, next) {
      if (next == null || next == _selectedId) return;
      setState(() => _selectedId = next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(pendingChatSelectionProvider.notifier).clear();
      });
    });
    // Also consume any pending value that was set before this widget mounted
    // (e.g. the very first time the user opens the home tab after tapping the
    // contacts "message" button). ref.listen only fires on subsequent changes.
    final initialPending = ref.read(pendingChatSelectionProvider);
    if (initialPending != null && _selectedId != initialPending) {
      _selectedId = initialPending;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(pendingChatSelectionProvider.notifier).clear();
      });
    }

    // Drive the breakpoint off MediaQuery so desktop window resizes flip the
    // single-pane / two-pane layout reliably (LayoutBuilder inside a Scaffold
    // body can lag behind window metrics during a drag on Windows/Linux).
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 700;
    final l = AppL10n.of(context);
    final asyncConvs = ref.watch(conversationsProvider);
    final refreshing = ref.watch(conversationsRefreshingProvider);
    final pinnedAsync = ref.watch(pinnedChatsProvider);
    final pinnedList = pinnedAsync.valueOrNull ?? const <PinChat>[];
    // Build an order map so the pinned section can render in the exact order
    // the pinned-chats provider holds (newest-pinned first, mirroring web).
    final pinOrder = <ConversationKey, int>{
      for (int i = 0; i < pinnedList.length; i++)
        pinnedList[i].target.conversationKey: i,
    };

    // Pre-compute the per-build context shared by every visible tile:
    // baseUrl + avatar metadata maps + the global "show online dots" flag.
    // Lifting this out of _ConversationTile.build means presence flicker
    // on user X no longer forces user Y's tile to re-watch 5 providers.
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final groupDir = ref.watch(groupDirectoryProvider).valueOrNull ?? const {};
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final baseUrl = serverState?.servers
            .where((s) => s.id == serverState.currentServerId)
            .firstOrNull
            ?.baseUrl ??
        '';
    final showStatus = ref.watch(showOnlineStatusProvider);

    Widget listPanel = Container(
      width: isWide ? 268 : double.infinity,
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: isWide
            ? Border(
                right: BorderSide(color: AppTokens.gray200, width: 1),
              )
            : null,
      ),
      child: Column(
        children: [
          _ChatListHeader(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: Stack(
              children: [
                asyncConvs.when(
                  // Cold-start (no cached snapshot yet) — show capsule
                  // centered while we await the first network paint.
                  loading: () => Center(
                    child: LoadingCapsule(label: l.chatListLoading),
                  ),
                  error: (e, _) =>
                      Center(child: Text(safeText(l.errorPrefix(e.toString())))),
                  data: (conversations) {
                    // Hide DM contacts with no message history — mirrors the
                    // web client, whose session list is built from
                    // userMessage.ids (only gains an id once a message
                    // exists) rather than the full /api/user roster. Channels
                    // are never filtered: membership alone makes them visible
                    // on web (store.channels.ids). Pinned DMs are exempt too:
                    // web's pinTmps renders every pinned target regardless of
                    // message history.
                    final visible = conversations
                        .where((c) =>
                            c.isChannel ||
                            c.lastAt != null ||
                            pinOrder.containsKey(c.key))
                        .toList();
                    final lowerQuery = _query.toLowerCase();
                    final filtered = lowerQuery.isEmpty
                        ? visible
                        : visible
                            .where((c) =>
                                c.name.toLowerCase().contains(lowerQuery))
                            .toList();
                    if (visible.isEmpty) {
                      return _EmptyState(
                          message: l.chatListEmpty);
                    }
                    if (filtered.isEmpty) {
                      return _EmptyState(
                          message: l.chatListNoResults(_query));
                    }

                    // Partition filtered conversations into pinned + normal
                    // and sort pinned by their pin-order index (newest pin
                    // at the top). Normal items keep the existing recency
                    // ordering from `conversationsProvider`.
                    final pinned = <ConversationItem>[];
                    final normal = <ConversationItem>[];
                    for (final c in filtered) {
                      if (pinOrder.containsKey(c.key)) {
                        pinned.add(c);
                      } else {
                        normal.add(c);
                      }
                    }
                    pinned.sort((a, b) =>
                        (pinOrder[a.key] ?? 0).compareTo(pinOrder[b.key] ?? 0));

                    return RefreshIndicator(
                      onRefresh: () async {
                        // Cap how long the pull-down spinner stays visible:
                        // the refresh itself (and the bottom-right "updating"
                        // capsule) keep running past this, but the spinner
                        // hiding early avoids it looking stuck on a slow
                        // network. `.timeout` still listens to the original
                        // future, so a late error/completion is discarded
                        // silently rather than reported as unhandled.
                        await ref
                            .read(conversationsProvider.notifier)
                            .refresh()
                            .timeout(const Duration(seconds: 1),
                                onTimeout: () {});
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 4),
                        // One slot for the pinned-section container (if any)
                        // plus one slot per normal item.
                        itemCount:
                            (pinned.isNotEmpty ? 1 : 0) + normal.length,
                        itemBuilder: (context, i) {
                          if (pinned.isNotEmpty && i == 0) {
                            return _PinnedSection(
                              items: pinned,
                              isWide: isWide,
                              userDir: userDir,
                              groupDir: groupDir,
                              baseUrl: baseUrl,
                              showStatus: showStatus,
                              buildTile: _buildTile,
                            );
                          }
                          final idx = pinned.isNotEmpty ? i - 1 : i;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _buildTile(
                              context,
                              normal[idx],
                              isWide: isWide,
                              userDir: userDir,
                              groupDir: groupDir,
                              baseUrl: baseUrl,
                              showStatus: showStatus,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                // Background-refresh capsule: visible only when we already
                // have cached data on screen and a network refresh is in
                // flight. Hidden during the initial cold-start spinner.
                if (asyncConvs.hasValue)
                  LoadingCapsuleOverlay(
                    visible: refreshing,
                    label: l.chatListUpdating,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!isWide) {
      return listPanel;
    }

    return Row(
      children: [
        listPanel,
        Expanded(
          child: _selectedId != null
              ? ChatScreen(id: _selectedId!)
              : const _EmptyChatPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    ConversationItem item, {
    required bool isWide,
    required Map<int, dynamic> userDir,
    required Map<int, dynamic> groupDir,
    required String baseUrl,
    required bool showStatus,
  }) {
    final unreadInfo = ref
            .watch(unreadInfoProvider(item.key))
            .valueOrNull ??
        (count: 0, mention: false);

    String routeId;
    switch (item.key) {
      case UserConversationKey(uid: final uid):
        routeId = 'u-$uid';
      case GroupConversationKey(gid: final gid):
        routeId = 'g-$gid';
    }

    final isSelected = isWide && _selectedId == routeId;

    // Resolve avatar URL up front using the pre-fetched directory maps so
    // we don't re-read three providers per tile per rebuild.
    String? avatarUrl;
    switch (item.key) {
      case UserConversationKey(uid: final uid):
        final u = userDir[uid];
        if (u != null && (u.avatarUpdatedAt ?? 0) > 0 && baseUrl.isNotEmpty) {
          avatarUrl =
              '$baseUrl/api/resource/avatar?uid=$uid&t=${u.avatarUpdatedAt}';
        }
      case GroupConversationKey(gid: final gid):
        final g = groupDir[gid];
        if (g != null && (g.avatarUpdatedAt ?? 0) > 0 && baseUrl.isNotEmpty) {
          avatarUrl =
              '$baseUrl/api/resource/group_avatar?gid=$gid&t=${g.avatarUpdatedAt}';
        }
    }

    // RepaintBoundary isolates each tile in its own layer so a hover state
    // or unread-count update doesn't repaint the whole list.
    return RepaintBoundary(
      child: _ConversationTile(
        item: item,
        unread: unreadInfo.count,
        mention: unreadInfo.mention,
        isSelected: isSelected,
        avatarUrl: avatarUrl,
        showStatus: showStatus,
        onTap: () {
          if (isWide) {
            setState(() => _selectedId = routeId);
          } else {
            context.go('/home/chat/$routeId');
          }
        },
        onLongPress: () => _showSessionMenu(context, item),
        onSecondaryTapDown: (pos) =>
            _showSessionMenu(context, item, globalPos: pos),
      ),
    );
  }

  /// Full context menu matching the web reference's SessionList/ContextMenu.
  ///
  /// DM items:  Pin/Unpin, Mark Read, Mute/Unmute, Hide (danger)
  /// Channel:   Pin/Unpin, Mark Read, Mute/Unmute, Leave (danger)
  Future<void> _showSessionMenu(
    BuildContext context,
    ConversationItem item, {
    Offset? globalPos,
  }) async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pinned = ref.read(pinnedChatsProvider.notifier);
    final pinTarget = switch (item.key) {
      UserConversationKey(uid: final uid) => PinChatTargetUser(uid),
      GroupConversationKey(gid: final gid) => PinChatTargetGroup(gid),
    };
    final isPinned = pinned.isPinned(pinTarget);

    // Check mute state to toggle the label/action.
    final muteNotifier = ref.read(mutedChatsProvider.notifier);
    final isMuted = switch (item.key) {
      UserConversationKey(uid: final uid) => muteNotifier.isUserMuted(uid),
      GroupConversationKey(gid: final gid) => muteNotifier.isGroupMuted(gid),
    };

    // Build menu items matching the web reference order.
    final items = <VoceContextMenuItem>[
      VoceContextMenuItem(
          'pin', isPinned ? l.chatListUnpin : l.chatListPin),
      VoceContextMenuItem('markRead', l.chatListMarkRead),
      VoceContextMenuItem('mute', isMuted ? l.chatListUnmute : l.chatListMute),
      if (item.isChannel)
        VoceContextMenuItem('settings', l.channelSettingsTitle),
      if (item.isChannel)
        VoceContextMenuItem('leave', l.chatListLeave, danger: true)
      else
        VoceContextMenuItem('hide', l.chatListHide, danger: true),
    ];

    // Wide screen + right-click → positioned popover; otherwise → bottom sheet.
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    String? selection;
    if (globalPos != null && isWide) {
      selection = await showVoceContextMenu(
        context: context,
        globalPos: globalPos,
        items: items,
      );
    } else {
      selection = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mi in items)
                  ListTile(
                    title: Text(
                      mi.label,
                      style: mi.danger
                          ? TextStyle(color: AppTokens.error)
                          : null,
                    ),
                    onTap: () => Navigator.of(ctx).pop(mi.value),
                  ),
              ],
            ),
          );
        },
      );
    }
    if (!mounted || selection == null) return;

    try {
      switch (selection) {
        case 'pin':
          final api = ref.read(pinChatApiProvider);
          if (isPinned) {
            await api.unpin(pinTarget);
          } else {
            await api.pin(pinTarget);
          }
        case 'markRead':
          final api = ref.read(sessionActionsApiProvider);
          final mid = item.lastMid;
          if (mid == null || mid <= 0) {
            // Nothing to mark — surface a clear message instead of silently
            // doing nothing (which reads as "failed" to the user).
            if (mounted) {
              messenger.showSnackBar(
                  SnackBar(content: Text(l.chatListMarkReadDone)));
            }
            break;
          }
          final readNotifier = ref.read(readIndexProvider.notifier);
          switch (item.key) {
            case UserConversationKey(uid: final uid):
              await api.markReadUser(uid, mid);
              readNotifier.setUser(uid, mid);
            case GroupConversationKey(gid: final gid):
              await api.markReadGroup(gid, mid);
              readNotifier.setGroup(gid, mid);
          }
          if (mounted) {
            messenger.showSnackBar(
                SnackBar(content: Text(l.chatListMarkReadDone)));
          }
        case 'mute':
          final api = ref.read(sessionActionsApiProvider);
          switch (item.key) {
            case UserConversationKey(uid: final uid):
              if (isMuted) {
                await api.unmuteUser(uid);
                muteNotifier.unmuteUser(uid);
              } else {
                await api.muteUser(uid);
                muteNotifier.muteUser(uid);
              }
            case GroupConversationKey(gid: final gid):
              if (isMuted) {
                await api.unmuteGroup(gid);
                muteNotifier.unmuteGroup(gid);
              } else {
                await api.muteGroup(gid);
                muteNotifier.muteGroup(gid);
              }
          }
          if (mounted) {
            messenger.showSnackBar(SnackBar(
                content: Text(
                    isMuted ? l.chatListUnmuteDone : l.chatListMuteDone)));
          }
        case 'hide':
          // Local-only: remove the DM from the conversation list state.
          ref.read(conversationsProvider.notifier).hideConversation(item.key);
          if (mounted) {
            messenger
                .showSnackBar(SnackBar(content: Text(l.chatListHideDone)));
          }
        case 'settings':
          final gid = (item.key as GroupConversationKey).gid;
          if (mounted) context.go('/home/chat/g-$gid/settings');
        case 'leave':
          final gid = (item.key as GroupConversationKey).gid;
          final api = ref.read(sessionActionsApiProvider);
          await api.leaveGroup(gid);
          // Remove from local list; SSE echo will also clean up.
          ref.read(conversationsProvider.notifier).hideConversation(item.key);
          if (mounted) {
            messenger
                .showSnackBar(SnackBar(content: Text(l.chatListLeaveDone)));
          }
      }
    } catch (e) {
      if (!mounted) return;
      final msg = switch (selection) {
        'pin' => isPinned
            ? l.chatListUnpinFailed(e.toString())
            : l.chatListPinFailed(e.toString()),
        'mute' => l.chatListMuteFailed(e.toString()),
        'leave' => l.chatListLeaveFailed(e.toString()),
        'markRead' => l.chatListMarkReadFailed,
        _ => e.toString(),
      };
      messenger.showSnackBar(SnackBar(content: Text(safeText(msg))));
    }
  }
}

// ---------------------------------------------------------------------------
// _PinnedSection — Figma-aligned sticky container for pinned chats. The web
// reference uses `bg-primary-500/10` (10% primary tint) wrapping a flex
// column. We match that with a tinted, rounded panel and reuse the same
// _ConversationTile that powers the normal list.
// ---------------------------------------------------------------------------

class _PinnedSection extends ConsumerWidget {
  const _PinnedSection({
    required this.items,
    required this.isWide,
    required this.userDir,
    required this.groupDir,
    required this.baseUrl,
    required this.showStatus,
    required this.buildTile,
  });

  final List<ConversationItem> items;
  final bool isWide;
  final Map<int, dynamic> userDir;
  final Map<int, dynamic> groupDir;
  final String baseUrl;
  final bool showStatus;
  final Widget Function(
    BuildContext context,
    ConversationItem item, {
    required bool isWide,
    required Map<int, dynamic> userDir,
    required Map<int, dynamic> groupDir,
    required String baseUrl,
    required bool showStatus,
  }) buildTile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.primary50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (final item in items)
            buildTile(
              context,
              item,
              isWide: isWide,
              userDir: userDir,
              groupDir: groupDir,
              baseUrl: baseUrl,
              showStatus: showStatus,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChatListHeader — pill search + add button (Figma's "Headers / Search").
// ---------------------------------------------------------------------------

class _ChatListHeader extends StatelessWidget {
  const _ChatListHeader({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border(
          bottom: BorderSide(color: AppTokens.gray200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTokens.gray100, // theme-aware search field fill
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTokens.gray700,
                ),
                decoration: InputDecoration(
                  hintText: l.chatListSearch,
                  hintStyle: TextStyle(
                    color: AppTokens.gray400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: AppTokens.gray400),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 0),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.add, size: 22, color: AppTokens.gray500),
            onPressed: () => showCreateChannelDialog(context),
            tooltip: l.chatListNewChat,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ConversationTile — Figma "List Item" with 40px avatar, status dot,
// title row with timestamp and unread badge.
// ---------------------------------------------------------------------------

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.item,
    required this.unread,
    required this.mention,
    required this.isSelected,
    required this.onTap,
    required this.showStatus,
    this.avatarUrl,
    this.onLongPress,
    this.onSecondaryTapDown,
  });

  final ConversationItem item;
  final int unread;
  final bool mention;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset>? onSecondaryTapDown;
  final String? avatarUrl;
  final bool showStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = isSelected ? AppTokens.selected : Colors.transparent;

    int? dmUid;
    if (!item.isChannel) {
      final key = item.key;
      if (key is UserConversationKey) dmUid = key.uid;
    }
    // Slice the presence map by THIS user's uid only — when someone else
    // toggles online, this select returns the same bool and skips rebuild.
    final isOnline = dmUid != null
        ? ref.watch(presenceProvider.select((m) => m[dmUid!] ?? false))
        : false;

    // Muted state drives the de-emphasized badge / bell-off indicator, matching
    // the web reference's SessionList row.
    final muted = ref.watch(mutedChatsProvider.select((s) {
      final key = item.key;
      return switch (key) {
        UserConversationKey(uid: final uid) => s.isUserMuted(uid),
        GroupConversationKey(gid: final gid) => s.isGroupMuted(gid),
      };
    }));
    // web: muted badges/icon are black/10 (light) or gray-500 (dark).
    final mutedTint = AppTokens.brightness == Brightness.dark
        ? AppTokens.gray500
        : const Color(0x1A000000);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      // Right-click is captured via GestureDetector (not InkWell, which only
      // exposes the position-less onSecondaryTap) so the wide-screen popover
      // can anchor at the cursor like the web client.
      child: GestureDetector(
        onSecondaryTapDown: onSecondaryTapDown == null
            ? null
            : (d) => onSecondaryTapDown!(d.globalPosition),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppTokens.hover,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  children: [
                    // Channels: prefer the actual group avatar if the server
                    // has one, fall back to the # tag chip otherwise. DMs:
                    // VoceAvatar handles network image with initials fallback.
                    if (item.isChannel && (avatarUrl == null))
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTokens.primary50,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(Icons.tag,
                            size: 20, color: AppTokens.primary500),
                      )
                    else
                      VoceAvatar(
                        name: safeText(item.name),
                        imageUrl: avatarUrl,
                        size: 40,
                      ),
                    if (!item.isChannel && showStatus)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppTokens.successDot
                                : AppTokens.gray400,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTokens.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            safeText(item.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.zinc600,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                        if (item.lastAt != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              _formatRelativeTime(context, item.lastAt!),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTokens.zinc500,
                                fontWeight: FontWeight.w500,
                                height: 18 / 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            safeText(item.lastPreview ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTokens.zinc500,
                              height: 18 / 12,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (mention)
                                  Container(
                                    margin:
                                        const EdgeInsets.only(right: 3),
                                    constraints: const BoxConstraints(
                                        minWidth: 16),
                                    height: 16,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5),
                                    decoration: BoxDecoration(
                                      // web: muted → faded gray badge.
                                      color: muted
                                          ? mutedTint
                                          : AppTokens.primary500,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '@',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1,
                                        // iOS SF font puts extra leading above
                                        // the baseline; even distribution keeps
                                        // the glyph vertically centered.
                                        leadingDistribution:
                                            TextLeadingDistribution.even,
                                      ),
                                    ),
                                  ),
                                Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 16),
                                  height: 16,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: muted
                                        ? mutedTint
                                        : AppTokens.primary500,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    unread > 99 ? '99+' : unread.toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      // Tabular figures give the monospace
                                      // digit width without relying on a
                                      // 'monospace' family iOS doesn't ship.
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                      height: 1,
                                      // iOS SF font puts extra leading above
                                      // the baseline; even distribution keeps
                                      // the digits vertically centered.
                                      leadingDistribution:
                                          TextLeadingDistribution.even,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        // web: no unreads but muted → show a bell-off icon
                        // in place of the badge.
                        else if (muted)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.notifications_off,
                              size: 12,
                              color: mutedTint,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTokens.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.forum_outlined,
                  size: 26, color: AppTokens.gray400),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTokens.gray500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      color: AppTokens.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTokens.primary50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_rounded,
                size: 30, color: AppTokens.primary500),
          ),
          const SizedBox(height: 16),
          Text(
            l.chatListSelectTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTokens.gray700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.chatListSelectSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTokens.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRelativeTime(BuildContext context, int unixMs) {
  final l = AppL10n.of(context);
  final ts = DateTime.fromMillisecondsSinceEpoch(unixMs);
  final now = DateTime.now();
  final diff = now.difference(ts);

  if (diff.inSeconds < 60) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.timeDaysAgo(diff.inDays);

  final mo = ts.month.toString().padLeft(2, '0');
  final d = ts.day.toString().padLeft(2, '0');
  if (ts.year == now.year) return '$mo/$d';
  return '${ts.year}/$mo/$d';
}
