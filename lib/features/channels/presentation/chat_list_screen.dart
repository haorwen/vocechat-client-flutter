import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../../shared/widgets/section_header.dart';

// TODO(wire): replace with riverpod controller
class _ChatItem {
  final String id;
  final String name;
  final String lastMessage;
  final String timestamp;
  final int unreadCount;
  final bool isChannel;
  final String? imageUrl;

  const _ChatItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isChannel = false,
    this.imageUrl,
  });
}

const _sampleChats = [
  _ChatItem(
    id: 'c1',
    name: '# general',
    lastMessage: 'Alice: Hey everyone, stand-up in 5 min!',
    timestamp: '9:41 AM',
    unreadCount: 3,
    isChannel: true,
  ),
  _ChatItem(
    id: 'c2',
    name: '# engineering',
    lastMessage: 'Bob: PR #42 is ready for review',
    timestamp: 'Yesterday',
    unreadCount: 0,
    isChannel: true,
  ),
  _ChatItem(
    id: 'c3',
    name: '# design',
    lastMessage: 'Carol: Figma link updated',
    timestamp: 'Mon',
    unreadCount: 1,
    isChannel: true,
  ),
  _ChatItem(
    id: 'c4',
    name: '# announcements',
    lastMessage: 'Admin: Server maintenance tonight at 11 PM',
    timestamp: 'Sun',
    unreadCount: 0,
    isChannel: true,
  ),
  _ChatItem(
    id: 'd1',
    name: 'Alice Nguyen',
    lastMessage: 'Sure, let me check that for you',
    timestamp: '10:02 AM',
    unreadCount: 2,
    isChannel: false,
  ),
  _ChatItem(
    id: 'd2',
    name: 'Bob Chen',
    lastMessage: "Thanks! I'll push the fix now",
    timestamp: 'Yesterday',
    unreadCount: 0,
    isChannel: false,
  ),
  _ChatItem(
    id: 'd3',
    name: 'Carol Smith',
    lastMessage: 'See you at the all-hands!',
    timestamp: 'Mon',
    unreadCount: 0,
    isChannel: false,
  ),
  _ChatItem(
    id: 'd4',
    name: 'David Park',
    lastMessage: 'Can you review my changes?',
    timestamp: 'Mon',
    unreadCount: 5,
    isChannel: false,
  ),
  _ChatItem(
    id: 'd5',
    name: 'Eva Martinez',
    lastMessage: 'Great work on the release!',
    timestamp: 'Sun',
    unreadCount: 0,
    isChannel: false,
  ),
  _ChatItem(
    id: 'd6',
    name: 'Frank Wilson',
    lastMessage: 'Any updates on the timeline?',
    timestamp: 'Fri',
    unreadCount: 0,
    isChannel: false,
  ),
];

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // TODO(wire): replace with riverpod controller
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _refreshing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_ChatItem> get _filtered {
    if (_query.isEmpty) return _sampleChats;
    final q = _query.toLowerCase();
    return _sampleChats
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.lastMessage.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    // TODO(wire): replace with riverpod controller
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _refreshing = false);
  }

  Widget _buildChatTile(_ChatItem item) {
    final theme = Theme.of(context);
    return ListTile(
      leading: item.isChannel
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.tag,
                  size: 18, color: theme.colorScheme.onSecondaryContainer),
            )
          : VoceAvatar(name: item.name, size: 44),
      title: Text(
        item.name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: item.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        item.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: item.unreadCount > 0
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
          fontWeight:
              item.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            item.timestamp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: item.unreadCount > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          if (item.unreadCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.unreadCount.toString(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/chat/${item.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = _filtered.where((c) => c.isChannel).toList();
    final dms = _filtered.where((c) => !c.isChannel).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final listContent = Scaffold(
          appBar: AppBar(
            title: const Text('Chats'),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search channels and messages…',
                  leading: const Icon(Icons.search, size: 20),
                  trailing: _query.isNotEmpty
                      ? [
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        ]
                      : null,
                  onChanged: (v) => setState(() => _query = v),
                  padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 12)),
                ),
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              children: [
                if (channels.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Channels',
                    trailing: IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () {},
                      tooltip: 'Browse channels',
                    ),
                  ),
                  ...channels.map(_buildChatTile),
                ],
                if (dms.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Direct Messages',
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () {},
                      tooltip: 'New message',
                    ),
                  ),
                  ...dms.map(_buildChatTile),
                ],
                if (_filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'No results for "$_query"',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        if (isWide) {
          // Master-detail layout on wide screens
          return Row(
            children: [
              SizedBox(width: 320, child: listContent),
              VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant),
              const Expanded(
                child: Center(
                  child: Text('Select a conversation'),
                ),
              ),
            ],
          );
        }

        return listContent;
      },
    );
  }
}
