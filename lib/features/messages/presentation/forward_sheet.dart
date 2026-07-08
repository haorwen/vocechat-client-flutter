import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../channels/application/conversation_providers.dart';
import '../data/message_api.dart';
import '../domain/message_models.dart';

// ---------------------------------------------------------------------------
// Forward sheet — target picker for forwarding one or more messages.
//
// Web behavior (ForwardModal/index.tsx + useForwardMessage.ts `forwardMessage`):
// bundle the selected mids into a single server-side archive
// (POST /api/resource/archive), then send the returned archive id to each
// chosen target with content-type `vocechat/archive`. No optimistic UI —
// the forwarded card appears via the normal SSE echo, matching web (which
// also doesn't optimistically insert a row for the forward action itself).
//
// Styled after chat_tool_panels.dart's `_ToolCard`/`_ToolHeader` template:
// wide screens get a right-anchored dialog (radius 16, 480px), narrow
// screens get a bottom sheet (radius 16 top corners, 92% height).
// ---------------------------------------------------------------------------

/// Shows the forward target-picker for [mids]. Returns after the sheet is
/// dismissed (whether messages were sent or the user cancelled).
Future<void> showForwardSheet(BuildContext context, {required List<int> mids}) {
  final size = MediaQuery.sizeOf(context);
  final isWide = size.width >= 700;
  final title = AppL10n.of(context).forwardSheetTitle;

  Widget body() => _ForwardBody(mids: mids);

  if (isWide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppL10n.of(context).actionClose,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      pageBuilder: (ctx, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 76, top: 16, bottom: 16),
              child: Material(
                color: Colors.transparent,
                child: _ForwardCard(title: title, child: body()),
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

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (ctx) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: _ForwardCard(title: title, narrow: true, child: body()),
      );
    },
  );
}

class _ForwardCard extends StatelessWidget {
  const _ForwardCard({
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
            SizedBox(
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
                      icon: Icon(Icons.close, size: 18, color: AppTokens.gray500),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: AppTokens.gray200),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _ForwardBody extends ConsumerStatefulWidget {
  const _ForwardBody({required this.mids});
  final List<int> mids;

  @override
  ConsumerState<_ForwardBody> createState() => _ForwardBodyState();
}

class _ForwardBodyState extends ConsumerState<_ForwardBody> {
  final Set<ConversationKey> _selected = {};
  bool _sending = false;

  void _toggle(ConversationKey key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    final api = ref.read(messageApiProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppL10n.of(context);
    try {
      final archiveId = await api.createArchive(widget.mids);
      final targets = _selected.map((key) {
        return switch (key) {
          GroupConversationKey(:final gid) => MessageTarget.group(gid: gid),
          UserConversationKey(:final uid) => MessageTarget.user(uid: uid),
        };
      }).toList();
      for (final target in targets) {
        await api.sendArchive(target, archiveId);
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l.forwardMessageSent)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l.forwardFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final convsAsync = ref.watch(conversationsProvider);

    return Column(
      children: [
        Expanded(
          child: convsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Text('$e', style: TextStyle(color: AppTokens.gray500)),
            ),
            data: (convs) {
              if (convs.isEmpty) {
                return Center(
                  child: Text(
                    l.forwardNoConversations,
                    style: TextStyle(color: AppTokens.gray500),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: convs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppTokens.gray200, indent: 64),
                itemBuilder: (ctx, i) {
                  final conv = convs[i];
                  final checked = _selected.contains(conv.key);
                  return ListTile(
                    dense: true,
                    onTap: () => _toggle(conv.key),
                    leading: VoceAvatar(name: conv.name, size: 36),
                    title: Text(
                      safeText(conv.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.textHeading,
                      ),
                    ),
                    trailing: Checkbox(
                      value: checked,
                      onChanged: (_) => _toggle(conv.key),
                      activeColor: AppTokens.primary400,
                    ),
                  );
                },
              );
            },
          ),
        ),
        Divider(height: 1, color: AppTokens.gray200),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.forwardSelectedCount(_selected.length),
                  style: TextStyle(fontSize: 13, color: AppTokens.gray500),
                ),
              ),
              TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: Text(l.actionCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _selected.isEmpty || _sending ? null : _confirm,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.actionSend),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
