import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../shared/widgets/loading_capsule.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../../features/contacts/application/presence_provider.dart';
import '../../../features/contacts/application/user_directory_provider.dart';
import '../../../features/messages/presentation/chat_screen.dart';
import '../application/conversation_providers.dart';

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
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      final asyncConvs = ref.watch(conversationsProvider);
      final refreshing = ref.watch(conversationsRefreshingProvider);

      Widget listPanel = Container(
        width: isWide ? 268 : double.infinity,
        decoration: BoxDecoration(
          color: AppTokens.surface,
          border: isWide
              ? const Border(
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
                    loading: () => const Center(
                      child: LoadingCapsule(label: 'Loading chats…'),
                    ),
                    error: (e, _) =>
                        Center(child: Text(safeText('Error: $e'))),
                    data: (conversations) {
                      final lowerQuery = _query.toLowerCase();
                      final filtered = lowerQuery.isEmpty
                          ? conversations
                          : conversations
                              .where((c) =>
                                  c.name.toLowerCase().contains(lowerQuery))
                              .toList();
                      if (conversations.isEmpty) {
                        return const _EmptyState(
                            message: 'No conversations yet');
                      }
                      if (filtered.isEmpty) {
                        return _EmptyState(
                            message: 'No results for "$_query"');
                      }
                      return RefreshIndicator(
                        onRefresh: () async => ref
                            .read(conversationsProvider.notifier)
                            .refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) =>
                              _buildTile(context, filtered[i]),
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
                      label: 'Updating…',
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
    });
  }

  Widget _buildTile(BuildContext context, ConversationItem item) {
    final unread = ref.watch(unreadCountProvider(item.key));

    String routeId;
    switch (item.key) {
      case UserConversationKey(uid: final uid):
        routeId = 'u-$uid';
      case GroupConversationKey(gid: final gid):
        routeId = 'g-$gid';
    }

    final isWide = MediaQuery.of(context).size.width >= 700;
    final isSelected = isWide && _selectedId == routeId;

    // Look up the per-target avatar metadata (uid/gid → avatar_updated_at)
    // and turn it into a real URL on the active server. The directory
    // providers serve from cache first so this is synchronous on warm start.
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final groupDir = ref.watch(groupDirectoryProvider).valueOrNull ?? const {};
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final baseUrl = serverState?.servers
            .where((s) => s.id == serverState.currentServerId)
            .firstOrNull
            ?.baseUrl ??
        '';

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

    return _ConversationTile(
      item: item,
      unread: unread,
      isSelected: isSelected,
      avatarUrl: avatarUrl,
      onTap: () {
        if (isWide) {
          setState(() => _selectedId = routeId);
        } else {
          context.go('/home/chat/$routeId');
        }
      },
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(
          bottom: BorderSide(color: AppTokens.gray200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0x14000000), // black 8%
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTokens.gray700,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(
                    color: AppTokens.gray400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: AppTokens.gray400),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 36, minHeight: 36),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add, size: 22, color: AppTokens.gray500),
            onPressed: () {},
            tooltip: 'New chat',
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
    required this.isSelected,
    required this.onTap,
    this.avatarUrl,
  });

  final ConversationItem item;
  final int unread;
  final bool isSelected;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = isSelected ? AppTokens.selected : Colors.transparent;

    final showStatus = ref.watch(showOnlineStatusProvider);
    final presence = ref.watch(presenceProvider);
    int? dmUid;
    if (!item.isChannel) {
      final key = item.key;
      if (key is UserConversationKey) dmUid = key.uid;
    }
    final isOnline = dmUid != null && (presence[dmUid] ?? false);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
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
                        child: const Icon(Icons.tag,
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
                            style: const TextStyle(
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
                              _formatRelativeTime(item.lastAt!),
                              style: const TextStyle(
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTokens.zinc500,
                              height: 18 / 12,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            constraints:
                                const BoxConstraints(minWidth: 16),
                            height: 16,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTokens.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unread > 99 ? '99' : unread.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFamily: 'monospace',
                                height: 1,
                              ),
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
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTokens.gray500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder();

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.chat_bubble_rounded,
                size: 30, color: AppTokens.primary500),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTokens.gray700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick a chat from the left panel to start messaging',
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

String _formatRelativeTime(int unixMs) {
  final ts = DateTime.fromMillisecondsSinceEpoch(unixMs);
  final now = DateTime.now();
  final diff = now.difference(ts);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';

  final mo = ts.month.toString().padLeft(2, '0');
  final d = ts.day.toString().padLeft(2, '0');
  if (ts.year == now.year) return '$mo/$d';
  return '${ts.year}/$mo/$d';
}
