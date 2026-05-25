import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/contacts/application/presence_provider.dart';
import '../../../features/contacts/application/user_directory_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/loading_capsule.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../application/chat_controller.dart';
import '../application/chat_tools_provider.dart';
import '../domain/message_models.dart';
import '../domain/message_status.dart';
import 'chat_tool_panels.dart';
import 'reaction_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String id;
  const ChatScreen({super.key, required this.id});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _editCtrl = TextEditingController();
  final _searchAnchorKey = GlobalKey();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _canSend = false;
  int? _highlightMid;
  Timer? _highlightTimer;
  int? _editingMid;
  int? _replyToMid;
  ChatMessage? _replyTarget;

  late MessageTarget _target;

  @override
  void initState() {
    super.initState();
    _target = _parseTarget(widget.id);

    _textCtrl.addListener(() {
      final hasText = _textCtrl.text.trim().isNotEmpty;
      if (hasText != _canSend) setState(() => _canSend = hasText);
    });

    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      setState(() {
        _target = _parseTarget(widget.id);
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _editCtrl.dispose();
    _highlightTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    // List is reverse: index 0 is the newest. The "older" end of the visible
    // window is the max trailing edge — when it's within 5 items of the
    // bottom of the dataset, fetch older history.
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    if (messages.isEmpty) return;
    final maxIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);
    if (maxIndex >= messages.length - 5) {
      ref.read(chatControllerProvider(_target).notifier).loadMore();
    }
  }

  static MessageTarget _parseTarget(String id) {
    if (id.startsWith('u-')) {
      final uid = int.tryParse(id.substring(2)) ?? 0;
      return MessageTarget.user(uid: uid);
    } else if (id.startsWith('g-')) {
      final gid = int.tryParse(id.substring(2)) ?? 0;
      return MessageTarget.group(gid: gid);
    }
    final gid = int.tryParse(id) ?? 0;
    return MessageTarget.group(gid: gid);
  }

  Future<void> _sendMessage() async {
    if (!_canSend) return;
    final text = _textCtrl.text.trim();
    final l = AppL10n.of(context);
    final replyMid = _replyToMid;
    _textCtrl.clear();
    setState(() {
      _canSend = false;
      _replyToMid = null;
      _replyTarget = null;
    });
    try {
      final notifier = ref.read(chatControllerProvider(_target).notifier);
      if (replyMid != null) {
        await notifier.sendReply(replyMid, text);
      } else {
        await notifier.sendText(text);
      }
    } catch (e) {
      if (mounted) {
        final msg = replyMid != null
            ? l.chatReplyFailed(_friendlyError(e))
            : l.chatSendFailed(_friendlyError(e));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(msg))));
      }
    }
  }

  void _startReply(ChatMessage msg) {
    setState(() {
      _replyToMid = msg.mid;
      _replyTarget = msg;
      _editingMid = null;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMid = null;
      _replyTarget = null;
    });
  }

  void _startEdit(ChatMessage msg) {
    final text = msg.displayContent;
    _editCtrl.text = text;
    // Place the caret at the end so editing picks up where the message left
    // off; default selection of a freshly-assigned value is offset 0.
    _editCtrl.selection =
        TextSelection.collapsed(offset: _editCtrl.text.length);
    setState(() {
      _editingMid = msg.mid;
      _replyToMid = null;
      _replyTarget = null;
    });
  }

  void _cancelEdit() {
    setState(() => _editingMid = null);
    _editCtrl.clear();
  }

  Future<void> _saveEdit() async {
    final mid = _editingMid;
    if (mid == null) return;
    final newText = _editCtrl.text.trim();
    if (newText.isEmpty) {
      _cancelEdit();
      return;
    }
    final l = AppL10n.of(context);
    // Preserve the original content-type rather than sniffing markdown from
    // the edited text (sniffing would silently upgrade "5 > 3" to markdown).
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    final original = messages.firstWhere(
      (m) => m.mid == mid,
      orElse: () => messages.first,
    );
    final isMarkdown = original.displayContentType == 'text/markdown';
    try {
      await ref
          .read(chatControllerProvider(_target).notifier)
          .editText(mid, newText, markdown: isMarkdown);
      if (mounted) setState(() => _editingMid = null);
      _editCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(safeText(l.chatEditFailed(_friendlyError(e))))));
      }
    }
  }

  Future<void> _confirmDelete(ChatMessage msg) async {
    final l = AppL10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.chatDeleteConfirmTitle),
        content: Text(l.chatDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.chatActionDelete,
                style: TextStyle(color: AppTokens.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(chatControllerProvider(_target).notifier)
          .deleteMessage(msg.mid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(safeText(l.chatDeleteFailed(_friendlyError(e))))));
      }
    }
  }

  /// Extract a short user-safe error message from a thrown error. `Dio` and
  /// the redacting interceptor scrub headers from logs, but `.toString()` on a
  /// `DioException` still contains the request URL, status line, and raw
  /// response body — too verbose for a snackbar, and a leak risk if
  /// screenshots get shared.
  static String _friendlyError(Object e) {
    if (e is DioException) {
      final inner = e.error;
      if (inner is ApiException) return inner.message;
      return e.message ?? 'Request failed';
    }
    return 'Request failed';
  }

  bool _showDateSeparator(List<ChatMessage> msgs, int index) {
    if (index == msgs.length - 1) return true;
    final current = msgs[index];
    final older = msgs[index + 1];
    final currentDate =
        DateTime.fromMillisecondsSinceEpoch(current.createdAt, isUtc: true);
    final olderDate =
        DateTime.fromMillisecondsSinceEpoch(older.createdAt, isUtc: true);
    return currentDate.day != olderDate.day;
  }

  String? _avatarUrl(int uid, int? avatarUpdatedAt) {
    if ((avatarUpdatedAt ?? 0) == 0) return null;
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    final server = serverState?.servers
        .where((s) => s.id == serverState.currentServerId)
        .firstOrNull;
    final base = server?.baseUrl ?? '';
    if (base.isEmpty) return null;
    return '$base/api/resource/avatar?uid=$uid';
  }

  String? _groupAvatarUrl(int gid, int? avatarUpdatedAt) {
    if ((avatarUpdatedAt ?? 0) == 0) return null;
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    final server = serverState?.servers
        .where((s) => s.id == serverState.currentServerId)
        .firstOrNull;
    final base = server?.baseUrl ?? '';
    if (base.isEmpty) return null;
    return '$base/api/resource/group_avatar?gid=$gid';
  }

  Future<void> _openSearchOverlay() async {
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    await showSearchOverlay(
      context,
      anchorKey: _searchAnchorKey,
      messages: messages,
      userDir: ref.read(userDirectoryProvider).valueOrNull ?? const {},
      avatarUrlBuilder: _avatarUrl,
      onLocate: _scrollToMid,
    );
  }

  Future<void> _scrollToMid(int mid) async {
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    final index = messages.indexWhere((m) => m.mid == mid);
    if (index < 0) return;
    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        // 0.0 puts the item flush with the leading edge — for a reverse list
        // that's the bottom; 0.3 nudges it a third of the way up.
        alignment: 0.3,
      );
    }
    if (!mounted) return;
    setState(() => _highlightMid = mid);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _highlightMid = null);
    });
  }

  void _showToolPanel(ChatTool tool) {
    final id = _target.map<int>(
      user: (t) => t.uid,
      group: (t) => t.gid,
    );
    final isChannel = _target.map<bool>(
      user: (_) => false,
      group: (_) => true,
    );
    showChatToolOverlay(
      context,
      tool: tool,
      targetId: id,
      isChannel: isChannel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final messagesAsync = ref.watch(chatControllerProvider(_target));

    final authState = ref.watch(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : -1;

    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};
    final groupDir = ref.watch(groupDirectoryProvider).valueOrNull ?? {};

    final showStatus = ref.watch(showOnlineStatusProvider);
    final presence = ref.watch(presenceProvider);
    final int? dmUid = _target.maybeMap<int?>(
      user: (t) => t.uid,
      orElse: () => null,
    );
    final dmOnline = dmUid != null && (presence[dmUid] ?? false);

    final (
      String title,
      String? subtitle,
      String? avatarUrl,
      bool isChannel
    ) = _target.map(
      user: (t) {
        final u = userDir[t.uid];
        final name = u?.name ?? l.chatUserFallback(t.uid);
        return (
          name,
          showStatus ? (dmOnline ? l.chatStatusOnline : l.chatStatusOffline) : null,
          u != null ? _avatarUrl(t.uid, u.avatarUpdatedAt) : null,
          false,
        );
      },
      group: (t) {
        final g = groupDir[t.gid];
        final name = g?.name ?? l.chatGroupFallback(t.gid);
        return (
          name,
          l.chatGroupIntro,
          g != null ? _groupAvatarUrl(t.gid, g.avatarUpdatedAt) : null,
          true,
        );
      },
    );

    final statuses =
        ref.watch(chatControllerProvider(_target).notifier).statuses;

    return Container(
      color: AppTokens.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _ChatHeader(
                      title: title,
                      subtitle: subtitle,
                      avatarUrl: avatarUrl,
                      isChannel: isChannel,
                      canPop: Navigator.of(context).canPop(),
                      isOnline: dmOnline,
                      showStatus: showStatus,
                      showMoreMenu: !isWide,
                      searchAnchorKey: _searchAnchorKey,
                      onSearch: _openSearchOverlay,
                      onPin: isChannel
                          ? () => _showToolPanel(ChatTool.pin)
                          : null,
                      onSaved: () => _showToolPanel(ChatTool.saved),
                      onMembers: isChannel
                          ? () => _showToolPanel(ChatTool.members)
                          : null,
                    ),
                    Expanded(
                      child: messagesAsync.when(
                        loading: () => Center(
                          child: LoadingCapsule(label: l.chatLoadingMessages),
                        ),
                        error: (e, _) => Center(
                            child:
                                Text(safeText(l.errorPrefix(e.toString())))),
                        data: (messages) {
                          if (messages.isEmpty) {
                            return const _EmptyConversation();
                          }
                          return ScrollablePositionedList.builder(
                            itemScrollController: _itemScrollController,
                            itemPositionsListener: _itemPositionsListener,
                            reverse: true,
                            padding:
                                const EdgeInsets.fromLTRB(8, 16, 8, 16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final showSep =
                                  _showDateSeparator(messages, index);
                              // reverse:true → Column children render top→bottom
                              // visually above→below the row. Date separator
                              // belongs ABOVE the day's first message (oldest
                              // of that day), so it must come BEFORE the row
                              // in the Column.
                              return Column(
                                key: ValueKey<int>(msg.mid),
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  if (showSep)
                                    _DateSeparator(
                                        createdAt: msg.createdAt),
                                  _MessageRow(
                                    message: msg,
                                    currentUid: currentUid,
                                    status: statuses[msg.mid],
                                    userDir: userDir,
                                    avatarUrlBuilder: _avatarUrl,
                                    target: _target,
                                    highlighted:
                                        msg.mid == _highlightMid,
                                    isEditing: _editingMid == msg.mid,
                                    editController: _editCtrl,
                                    onEditSave: _saveEdit,
                                    onEditCancel: _cancelEdit,
                                    onReply: () => _startReply(msg),
                                    onEdit: () => _startEdit(msg),
                                    onDelete: () => _confirmDelete(msg),
                                    onRetry: msg.mid < 0 &&
                                            statuses[msg.mid] ==
                                                MessageSendStatus.failed
                                        ? () => ref
                                            .read(chatControllerProvider(
                                                    _target)
                                                .notifier)
                                            .retrySend(msg.mid)
                                        : null,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    _SendBox(
                      controller: _textCtrl,
                      canSend: _canSend,
                      onSend: _sendMessage,
                      placeholder: isChannel
                          ? l.chatMessagePlaceholderChannel(title)
                          : l.chatMessagePlaceholderUser(title),
                      replyTarget: _replyTarget,
                      replyTargetName: _replyTarget == null
                          ? null
                          : (userDir[_replyTarget!.fromUid]?.name ??
                              l.chatUserFallback(_replyTarget!.fromUid)),
                      onCancelReply: _cancelReply,
                    ),
                  ],
                ),
              ),
              if (isWide)
                _ChatSideRail(
                  isChannel: isChannel,
                  onPin: isChannel
                      ? () => _showToolPanel(ChatTool.pin)
                      : null,
                  onSaved: () => _showToolPanel(ChatTool.saved),
                  onMembers: isChannel
                      ? () => _showToolPanel(ChatTool.members)
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChatHeader — channel/dm header (Figma "Main / Header"). 52px tall, white
// background, bottom border #EAECF0, Inter Bold 16 title + Inter 16 subtitle.
// ---------------------------------------------------------------------------

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.isChannel,
    required this.canPop,
    this.isOnline = false,
    this.showStatus = true,
    this.showMoreMenu = false,
    this.searchAnchorKey,
    this.onSearch,
    this.onPin,
    this.onSaved,
    this.onMembers,
  });

  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final bool isChannel;
  final bool canPop;
  final bool isOnline;
  final bool showStatus;
  final bool showMoreMenu;
  final Key? searchAnchorKey;
  final VoidCallback? onSearch;
  final VoidCallback? onPin;
  final VoidCallback? onSaved;
  final VoidCallback? onMembers;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border(
          bottom: BorderSide(color: AppTokens.gray200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: Icon(Icons.arrow_back,
                  size: 20, color: AppTokens.gray700),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          if (isChannel)
            Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.tag,
                  size: 20, color: AppTokens.textHeading),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  VoceAvatar(
                      name: title, imageUrl: avatarUrl, size: 28),
                  if (showStatus)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? AppTokens.successDot
                              : AppTokens.gray400,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTokens.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    safeText(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.textHeading,
                      height: 24 / 16,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      safeText(subtitle!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTokens.gray500,
                        height: 24 / 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: searchAnchorKey,
            icon: Icon(Icons.search,
                size: 20, color: AppTokens.gray500),
            onPressed: onSearch,
            tooltip: l.actionSearch,
          ),
          if (showMoreMenu)
            PopupMenuButton<ChatTool>(
              icon: Icon(Icons.more_horiz,
                  size: 20, color: AppTokens.gray500),
              tooltip: l.actionMore,
              onSelected: (tool) {
                switch (tool) {
                  case ChatTool.pin:
                    onPin?.call();
                  case ChatTool.saved:
                    onSaved?.call();
                  case ChatTool.members:
                    onMembers?.call();
                }
              },
              itemBuilder: (context) => [
                if (isChannel)
                  PopupMenuItem(
                    value: ChatTool.pin,
                    child: _ChatToolMenuRow(
                      icon: Icons.push_pin_outlined,
                      label: l.chatToolPin,
                    ),
                  ),
                PopupMenuItem(
                  value: ChatTool.saved,
                  child: _ChatToolMenuRow(
                    icon: Icons.bookmark_outline,
                    label: l.chatToolSaved,
                  ),
                ),
                if (isChannel)
                  PopupMenuItem(
                    value: ChatTool.members,
                    child: _ChatToolMenuRow(
                      icon: Icons.people_outline,
                      label: l.chatToolMembers,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChatToolMenuRow extends StatelessWidget {
  const _ChatToolMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTokens.gray500),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                fontSize: 14, color: AppTokens.gray700)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ChatSideRail — Figma/Web "aside" column. A 56px-wide vertical rail to the
// right of the chat surface, surfacing Pin (channels only), Saved, and
// Members (channels only). On narrow screens these collapse into the header's
// "more" overflow menu.
// ---------------------------------------------------------------------------

class _ChatSideRail extends StatelessWidget {
  const _ChatSideRail({
    required this.isChannel,
    this.onPin,
    this.onSaved,
    this.onMembers,
  });

  final bool isChannel;
  final VoidCallback? onPin;
  final VoidCallback? onSaved;
  final VoidCallback? onMembers;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border(
          left: BorderSide(color: AppTokens.gray200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (isChannel) ...[
            _RailButton(
              icon: Icons.push_pin_outlined,
              tooltip: l.chatToolPin,
              onPressed: onPin ?? () {},
            ),
            const SizedBox(height: 12),
          ],
          _RailButton(
            icon: Icons.bookmark_outline,
            tooltip: l.chatToolSaved,
            onPressed: onSaved ?? () {},
          ),
          if (isChannel) ...[
            const SizedBox(height: 12),
            _RailButton(
              icon: Icons.people_outline,
              tooltip: l.chatToolMembers,
              onPressed: onMembers ?? () {},
            ),
          ],
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: AppTokens.gray500),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DateSeparator — Figma "Timestamp": horizontal line with centered white
// pill carrying the date.
// ---------------------------------------------------------------------------

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.createdAt});
  final int createdAt;

  String _formatDate() {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true)
        .toLocal();
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 1,
            color: AppTokens.borderSubtle,
          ),
          Container(
            color: AppTokens.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              _formatDate(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTokens.gray500,
                height: 18 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MessageRow — Figma "Main / Comment". 40px avatar, cyan name + gray time
// header, body text in #374151. Hovering reveals a reply-actions cluster on
// the right of the row (Emoji / Reply / Bookmark / More).
// ---------------------------------------------------------------------------

class _MessageRow extends ConsumerStatefulWidget {
  const _MessageRow({
    required this.message,
    required this.currentUid,
    required this.userDir,
    required this.avatarUrlBuilder,
    required this.target,
    this.status,
    this.onRetry,
    this.highlighted = false,
    this.isEditing = false,
    this.editController,
    this.onEditSave,
    this.onEditCancel,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  final ChatMessage message;
  final int currentUid;
  final MessageSendStatus? status;
  final Map<int, UserSummary> userDir;
  final String? Function(int uid, int? avatarUpdatedAt) avatarUrlBuilder;
  final MessageTarget target;
  final VoidCallback? onRetry;
  final bool highlighted;
  final bool isEditing;
  final TextEditingController? editController;
  final VoidCallback? onEditSave;
  final VoidCallback? onEditCancel;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends ConsumerState<_MessageRow> {
  bool _hovered = false;
  final GlobalKey _toolbarKey = GlobalKey();

  bool get _isPinned {
    final p = (widget.message.detail is NormalMessageDetail)
        ? (widget.message.detail as NormalMessageDetail).properties
        : null;
    return p != null && (p['pinned'] == true || p['is_pinned'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final msg = widget.message;
    final sender = widget.userDir[msg.fromUid];
    final senderName = sender?.name ?? 'uid:${msg.fromUid}';
    final senderAvatarUrl = sender != null
        ? widget.avatarUrlBuilder(msg.fromUid, sender.avatarUpdatedAt)
        : null;

    final date =
        DateTime.fromMillisecondsSinceEpoch(msg.createdAt, isUtc: true)
            .toLocal();
    final dateLabel =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    final detail = msg.detail;
    final displayContent = msg.displayContent;
    final displayContentType = msg.displayContentType;
    Widget content;
    if (widget.isEditing && widget.editController != null) {
      content = _EditForm(
        controller: widget.editController!,
        onSave: widget.onEditSave ?? () {},
        onCancel: widget.onEditCancel ?? () {},
      );
    } else if (detail is NormalMessageDetail || msg.isEdited) {
      if (displayContentType == 'text/markdown') {
        content = MarkdownBody(
          data: safeText(displayContent),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: 14,
              color: AppTokens.gray700,
              height: 20 / 14,
            ),
          ),
        );
      } else {
        content = Text(
          safeText(displayContent),
          style: TextStyle(
            fontSize: 14,
            color: AppTokens.gray700,
            height: 20 / 14,
          ),
        );
      }
    } else if (detail is ReplyMessageDetail) {
      // Try to resolve the original message from the current chat list so we
      // can render a real preview ("↩ replying to <name>: <snippet>") instead
      // of a bare mid. Falls back to the mid alone if we don't have history.
      final chatMessages =
          ref.watch(chatControllerProvider(widget.target)).valueOrNull ??
              const <ChatMessage>[];
      final original = chatMessages
          .where((m) => m.mid == detail.mid)
          .firstOrNull;
      final originalAuthor = original != null
          ? widget.userDir[original.fromUid]
          : null;
      final originalName = originalAuthor?.name ?? '#${detail.mid}';
      final originalSnippet = original?.displayContent
              .replaceAll('\n', ' ')
              .trim() ??
          '';
      final clippedSnippet = originalSnippet.length > 80
          ? '${originalSnippet.substring(0, 80)}…'
          : originalSnippet;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTokens.gray50,
              borderRadius: BorderRadius.circular(6),
              border: Border(
                left: BorderSide(color: AppTokens.primary500, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.reply, size: 12, color: AppTokens.gray400),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        safeText(originalName),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.primary600,
                          height: 18 / 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (clippedSnippet.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    safeText(clippedSnippet),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.gray500,
                      height: 18 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            safeText(displayContent),
            style: TextStyle(
              fontSize: 14,
              color: AppTokens.gray700,
              height: 20 / 14,
            ),
          ),
        ],
      );
    } else {
      content = Text(
        l.chatUnsupported,
        style: TextStyle(fontSize: 13, color: AppTokens.gray500),
      );
    }

    final pinned = _isPinned;
    final highlighted = widget.highlighted;
    final rowBg = highlighted
        ? AppTokens.gray200
        : (pinned ? AppTokens.primary50 : Colors.transparent);

    final mainRow = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: pinned
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pinned)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.push_pin,
                      size: 12, color: AppTokens.gray400),
                  const SizedBox(width: 4),
                  Text(
                    l.chatPinned,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.gray400,
                      height: 18 / 12,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VoceAvatar(
                  name: senderName,
                  imageUrl: senderAvatarUrl,
                  size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          safeText(senderName),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTokens.primary600,
                            height: 20 / 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTokens.gray400,
                            height: 18 / 12,
                          ),
                        ),
                        if (msg.isEdited) ...[
                          const SizedBox(width: 6),
                          Text(
                            l.chatEditMarker,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppTokens.gray400,
                              height: 18 / 12,
                            ),
                          ),
                        ],
                        if (widget.status ==
                            MessageSendStatus.sending) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.access_time,
                              size: 12, color: AppTokens.gray400),
                        ] else if (widget.status ==
                            MessageSendStatus.failed) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.error_outline,
                              size: 12, color: AppTokens.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    content,
                    if (msg.mid > 0) ReactionBar(mid: msg.mid),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    Widget row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          mainRow,
          if (_hovered)
            Positioned(
              // Anchor toolbar to the top-right of the message row so it
              // stays inside the MouseRegion's hit-test bounds. Floating
              // it above the row (negative top) makes the cursor exit
              // the MouseRegion when it moves up, which causes the
              // toolbar to jump to the previous message.
              top: 0,
              right: 10,
              child: _ReplyActionsBar(
                key: _toolbarKey,
                onEmojiTap: widget.message.mid > 0
                    ? () => _openReactionPicker()
                    : null,
              ),
            ),
        ],
      ),
    );

    // Optimistic / failed rows can't be acted on yet.
    if (widget.message.mid > 0) {
      row = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (details) => _openContextMenu(details.globalPosition),
        onSecondaryTapDown: (details) =>
            _openContextMenu(details.globalPosition),
        child: row,
      );
    }

    if (widget.onRetry != null) {
      row = GestureDetector(onTap: widget.onRetry, child: row);
    }
    return row;
  }

  Future<void> _openReactionPicker() async {
    final mid = widget.message.mid;
    if (mid <= 0) return;
    // Anchor the picker to the floating toolbar so it appears flush
    // beneath it (matches the web reference's Tippy popover that hugs
    // its trigger). Falling back to the row bounds would place it
    // far below the message — visually disconnected from the toolbar.
    final anchorContext =
        _toolbarKey.currentContext ?? context;
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    const pickerWidth = 220.0;
    const pickerHeight = 220.0;
    const gap = 4.0;
    final rightEdge = offset.dx + box.size.width;
    await showDialog<void>(
      context: anchorContext,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            // Transparent overlay that dismisses the picker on outside tap.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              // Right-align with the toolbar's right edge.
              left: (rightEdge - pickerWidth)
                  .clamp(8.0, overlay.size.width - pickerWidth - 8)
                  .toDouble(),
              // Place flush beneath the toolbar with a small gap.
              top: (offset.dy + box.size.height + gap)
                  .clamp(8.0, overlay.size.height - pickerHeight - 8)
                  .toDouble(),
              width: pickerWidth,
              child: Material(
                color: Colors.transparent,
                child: ReactionPicker(
                  mid: mid,
                  onPicked: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openContextMenu(Offset globalPos) async {
    final l = AppL10n.of(context);
    final isChannel = widget.target.map<bool>(
      user: (_) => false,
      group: (_) => true,
    );
    final msg = widget.message;
    final isMine = msg.fromUid == widget.currentUid && widget.currentUid > 0;
    final detail = msg.detail;
    final canEdit = isMine &&
        (detail is NormalMessageDetail || detail is ReplyMessageDetail) &&
        (msg.displayContentType == 'text/plain' ||
            msg.displayContentType == 'text/markdown');
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPos, globalPos),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'react',
          child: Row(children: [
            Icon(Icons.emoji_emotions_outlined,
                size: 18, color: AppTokens.gray500),
            const SizedBox(width: 12),
            Text(l.chatActionReact),
          ]),
        ),
        PopupMenuItem(
          value: 'reply',
          child: Row(children: [
            Icon(Icons.reply_outlined,
                size: 18, color: AppTokens.gray500),
            const SizedBox(width: 12),
            Text(l.chatActionReply),
          ]),
        ),
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined,
                  size: 18, color: AppTokens.gray500),
              const SizedBox(width: 12),
              Text(l.chatActionEdit),
            ]),
          ),
        if (isChannel)
          PopupMenuItem(
            value: 'pin',
            child: Row(children: [
              Icon(Icons.push_pin_outlined,
                  size: 18, color: AppTokens.gray500),
              const SizedBox(width: 12),
              Text(l.chatToolPin),
            ]),
          ),
        PopupMenuItem(
          value: 'fav',
          child: Row(children: [
            Icon(Icons.bookmark_outline,
                size: 18, color: AppTokens.gray500),
            const SizedBox(width: 12),
            Text(l.chatToolSaved),
          ]),
        ),
        if (isMine)
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline,
                  size: 18, color: AppTokens.error),
              const SizedBox(width: 12),
              Text(l.chatActionDelete,
                  style: TextStyle(color: AppTokens.error)),
            ]),
          ),
      ],
    );
    if (!mounted || selection == null) return;
    if (selection == 'react') {
      _openReactionPicker();
    } else if (selection == 'reply') {
      widget.onReply?.call();
    } else if (selection == 'edit') {
      widget.onEdit?.call();
    } else if (selection == 'delete') {
      widget.onDelete?.call();
    } else if (selection == 'pin') {
      final gid = widget.target.map<int>(
        user: (_) => 0,
        group: (t) => t.gid,
      );
      final ok = await ref
          .read(chatToolsProvider)
          .pin(gid: gid, mid: widget.message.mid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? l.chatToolPinAdded : l.chatToolPinFail),
      ));
    } else if (selection == 'fav') {
      final ok = await ref
          .read(favoritesProvider.notifier)
          .add([widget.message.mid]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? l.chatToolSavedAdded : l.chatToolSaveFail),
      ));
    }
  }
}

// ---------------------------------------------------------------------------
// _ReplyActionsBar — Figma "Replies / Icons" cluster.
// ---------------------------------------------------------------------------

class _ReplyActionsBar extends StatelessWidget {
  const _ReplyActionsBar({super.key, this.onEmojiTap});

  final VoidCallback? onEmojiTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReplyIcon(
            icon: Icons.emoji_emotions_outlined,
            onTap: onEmojiTap,
          ),
          const _ReplyIcon(icon: Icons.reply_outlined),
          const _ReplyIcon(icon: Icons.bookmark_add_outlined),
          const _ReplyIcon(icon: Icons.more_horiz),
        ],
      ),
    );
  }
}

class _ReplyIcon extends StatelessWidget {
  const _ReplyIcon({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: AppTokens.gray500),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SendBox — matches the web client `Send` component:
//   • outer `bg-gray-200` rounded pill, 8px radius
//   • emoji picker pinned bottom-left (absolute), input padded behind it
//   • right-side toolbar: markdown, attach (+), send (zoom-in when text)
//   • icons are flat gray — no IconButton ripple boxes, no primary fill
// ---------------------------------------------------------------------------

class _SendBox extends StatelessWidget {
  const _SendBox({
    required this.controller,
    required this.canSend,
    required this.onSend,
    required this.placeholder,
    this.replyTarget,
    this.replyTargetName,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;
  final String placeholder;
  final ChatMessage? replyTarget;
  final String? replyTargetName;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    // Web: outer wrapper is `px-2 py-0 md:p-4` (16px desktop padding all
    // sides), Send itself is `w-full bg-gray-200 rounded-lg` with no extra
    // margin. Inner: `px-4 py-3.5` = 16px / 14px. We match that here.
    return Container(
      color: AppTokens.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTarget != null)
            _ReplyChip(
              target: replyTarget!,
              targetName: replyTargetName ?? '',
              onCancel: onCancelReply ?? () {},
            ),
          Container(
            decoration: BoxDecoration(
              color: AppTokens.borderSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SendIcon(
                  icon: Icons.emoji_emotions_outlined,
                  tooltip: l.chatEmoji,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: CallbackShortcuts(
                      bindings: <ShortcutActivator, VoidCallback>{
                        const SingleActivator(LogicalKeyboardKey.enter): () {
                          if (canSend) onSend();
                        },
                        const SingleActivator(LogicalKeyboardKey.numpadEnter):
                            () {
                          if (canSend) onSend();
                        },
                      },
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorColor: AppTokens.primary500,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTokens.gray700,
                          height: 20 / 14,
                        ),
                        decoration: InputDecoration(
                          hintText: placeholder,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppTokens.gray400,
                            height: 20 / 14,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                _SendIcon(
                  icon: Icons.code,
                  tooltip: l.chatMarkdown,
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                _SendIcon(
                  icon: Icons.add_circle,
                  tooltip: l.chatAttach,
                  onTap: () {},
                ),
                ClipRect(
                  child: AnimatedAlign(
                    alignment: Alignment.centerRight,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    widthFactor: canSend ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: AnimatedScale(
                        scale: canSend ? 1 : 0.6,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: canSend ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: _SendIcon(
                            icon: Icons.send_rounded,
                            tooltip: l.actionSend,
                            onTap: canSend ? onSend : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyChip extends StatelessWidget {
  const _ReplyChip({
    required this.target,
    required this.targetName,
    required this.onCancel,
  });

  final ChatMessage target;
  final String targetName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final preview = target.displayContent.replaceAll('\n', ' ').trim();
    final clipped = preview.length > 80 ? '${preview.substring(0, 80)}…' : preview;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.gray50,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: AppTokens.primary500, width: 3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.reply, size: 14, color: AppTokens.gray500),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    safeText(l.chatReplyingTo(targetName)),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.primary600,
                      height: 18 / 12,
                    ),
                  ),
                  if (clipped.isNotEmpty)
                    Text(
                      safeText(clipped),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTokens.gray500,
                        height: 18 / 12,
                      ),
                    ),
                ],
              ),
            ),
            InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: AppTokens.gray500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTokens.gray200, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.enter): onSave,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): onSave,
              const SingleActivator(LogicalKeyboardKey.escape): onCancel,
            },
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontSize: 14,
                color: AppTokens.gray700,
                height: 20 / 14,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onCancel,
              child: Text(l.chatEditCancel),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: onSave,
              child: Text(l.chatEditSave),
            ),
          ],
        ),
      ],
    );
  }
}

// Flat gray icon used inside the send pill. No ripple box, tight hit area
// (28px) so the icons sit close together like the web toolbar.
class _SendIcon extends StatelessWidget {
  const _SendIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22, color: AppTokens.gray500);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        containedInkWell: false,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyConversation — placeholder when there are no messages yet.
// ---------------------------------------------------------------------------

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTokens.primary50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline,
                size: 24, color: AppTokens.primary500),
          ),
          const SizedBox(height: 12),
          Text(
            l.chatEmpty,
            style: TextStyle(
              fontSize: 14,
              color: AppTokens.gray500,
            ),
          ),
        ],
      ),
    );
  }
}
