import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/contacts/application/user_directory_provider.dart';
import '../../../shared/widgets/voce_avatar.dart';

// ---------------------------------------------------------------------------
// Mention overlay — "@" member-picker dropdown for the composer.
//
// Web behavior (MessageInput/plate-ui/mention/combobox.tsx): typing "@" in a
// GROUP chat (mentions are disabled for DMs — `enableMention: members.length
// > 0`) opens a filtered member list; selecting inserts the mention token.
// Styled after chat_tool_panels.dart's `showSearchOverlay` anchored-dropdown
// pattern, but implemented as a live-updating `OverlayEntry` (rather than a
// `showGeneralDialog` route) since the filtered list must update on every
// keystroke without re-pushing a route each time.
// ---------------------------------------------------------------------------

/// Handle returned by [showMentionOverlay]; the caller updates the filter
/// query as the user keeps typing after "@", and removes the overlay once
/// the mention is resolved or cancelled.
class MentionOverlayHandle {
  MentionOverlayHandle._(this._entry, this._query);

  final OverlayEntry _entry;
  final ValueNotifier<String> _query;
  bool _removed = false;

  void updateQuery(String query) => _query.value = query;

  void remove() {
    if (_removed) return;
    _removed = true;
    _entry.remove();
    _query.dispose();
  }
}

/// Shows the mention member-picker anchored above the widget identified by
/// [anchorKey] (typically the composer). [onSelect] fires with the chosen
/// user's uid + name; the caller is responsible for inserting the token and
/// calling [MentionOverlayHandle.remove].
MentionOverlayHandle showMentionOverlay(
  BuildContext context, {
  required GlobalKey anchorKey,
  required int gid,
  required void Function(int uid, String name) onSelect,
}) {
  final query = ValueNotifier<String>('');
  late final MentionOverlayHandle handle;
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (overlayContext) {
      final renderBox =
          anchorKey.currentContext?.findRenderObject() as RenderBox?;
      final screen = MediaQuery.sizeOf(overlayContext);
      const width = 260.0;
      Offset anchorOffset = Offset.zero;
      if (renderBox != null && renderBox.attached) {
        anchorOffset = renderBox.localToGlobal(Offset.zero);
      }
      final left =
          anchorOffset.dx.clamp(8.0, (screen.width - width - 8.0).clamp(8.0, screen.width));

      return Positioned(
        left: left,
        bottom: (screen.height - anchorOffset.dy + 8).clamp(0.0, screen.height),
        width: width,
        child: Material(
          color: Colors.transparent,
          child: ValueListenableBuilder<String>(
            valueListenable: query,
            builder: (ctx, q, _) => _MentionPopover(
              gid: gid,
              query: q,
              onSelect: (uid, name) {
                handle.remove();
                onSelect(uid, name);
              },
            ),
          ),
        ),
      );
    },
  );

  handle = MentionOverlayHandle._(entry, query);
  Overlay.of(context).insert(entry);
  return handle;
}

class _MentionPopover extends ConsumerWidget {
  const _MentionPopover({
    required this.gid,
    required this.query,
    required this.onSelect,
  });

  final int gid;
  final String query;
  final void Function(int uid, String name) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupDirectoryProvider);
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};
    final group = groupsAsync.valueOrNull?[gid];

    // Public channel → everyone is a candidate. Private → group.members only
    // (mirrors _MembersListPanel in chat_tool_panels.dart).
    final uids = group == null
        ? const <int>[]
        : (group.isPublic ? userDir.keys.toList(growable: false) : group.members);

    final q = query.toLowerCase();
    final filtered = uids.where((uid) {
      final name = userDir[uid]?.name ?? '';
      return q.isEmpty || name.toLowerCase().contains(q);
    }).toList(growable: false)
      ..sort((a, b) => (userDir[a]?.name ?? '').compareTo(userDir[b]?.name ?? ''));

    if (filtered.isEmpty) return const SizedBox.shrink();

    final shown = filtered.length > 8 ? filtered.sublist(0, 8) : filtered;

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: shown.length,
        itemBuilder: (ctx, i) {
          final uid = shown[i];
          final name = userDir[uid]?.name ?? '$uid';
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: VoceAvatar(name: name, size: 24),
            title: Text(
              name,
              style: TextStyle(fontSize: 13, color: AppTokens.textHeading),
            ),
            onTap: () => onSelect(uid, name),
          );
        },
      ),
    );
  }
}
