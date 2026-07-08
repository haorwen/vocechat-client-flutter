import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../data/message_api.dart';
import '../domain/message_models.dart';

part 'archive_message_content.g.dart';

// ---------------------------------------------------------------------------
// Archive (forwarded-message) rendering.
//
// Web reference: components/Message/ForwardedMessage.tsx + utils.tsx
// `normalizeArchiveData`. A `vocechat/archive` message's `content` is the
// archive's file-path id (e.g. "2026/7/8/<uuid>"); fetch the index via
// GET /api/resource/archive?file_path=... to get the bundled messages, then
// render each with its denormalized author (archive.users[fromUser] — an
// INDEX, not a uid) and a text/file preview. Minimal per task spec: no
// nested archive-in-archive rendering, no rich media playback — file
// attachments show as a name line only.
// ---------------------------------------------------------------------------

@riverpod
Future<Archive> archiveContent(Ref ref, String filePath) {
  return ref.watch(messageApiProvider).getArchive(filePath);
}

/// Builds the `/api/resource/archive/attachment` URL for [attachmentId] in
/// the archive identified by [filePath]. Mirrors
/// `file_message_content.dart`'s `_buildResourceUrls` pattern.
String? _archiveAttachmentUrl(WidgetRef ref, String filePath, int attachmentId) {
  final serverState = ref.read(serverStoreProvider).valueOrNull;
  final server = serverState?.servers
      .where((s) => s.id == serverState.currentServerId)
      .firstOrNull;
  final base = server?.baseUrl ?? '';
  if (base.isEmpty) return null;
  final encodedPath = Uri.encodeQueryComponent(filePath);
  return '$base/api/resource/archive/attachment?file_path=$encodedPath&attachment_id=$attachmentId';
}

// Note: archive attachment avatars are rendered via VoceAvatar, which (like
// the existing avatar rendering in chat_tool_panels.dart's _userAvatarUrl)
// does not support custom auth headers on its underlying image widget. This
// mirrors the codebase's existing avatar-loading pattern rather than adding
// authenticated-image plumbing that no other avatar path uses.

/// Renders a forwarded-message card for a `vocechat/archive` message whose
/// [content] is the archive file-path id.
class ArchiveMessageContent extends ConsumerWidget {
  const ArchiveMessageContent({super.key, required this.filePath});
  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(archiveContentProvider(filePath));

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTokens.canvasAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.forward_outlined, size: 16, color: AppTokens.gray500),
              const SizedBox(width: 6),
              Text(
                AppL10n.of(context).archiveForwardedLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.gray500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          archiveAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text(
              AppL10n.of(context).archiveLoadFailed,
              style: TextStyle(fontSize: 12, color: AppTokens.gray500),
            ),
            data: (archive) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < archive.messages.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ArchiveMessageRow(
                    archive: archive,
                    message: archive.messages[i],
                    filePath: filePath,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveMessageRow extends ConsumerWidget {
  const _ArchiveMessageRow({
    required this.archive,
    required this.message,
    required this.filePath,
  });

  final Archive archive;
  final ArchiveMessage message;
  final String filePath;

  String _preview() {
    final c = message.content;
    if (c.contentType == 'text/plain' || c.contentType == 'text/markdown') {
      return (c.content ?? '').replaceAll('\n', ' ').trim();
    }
    if (c.contentType == 'vocechat/file') {
      final name = c.properties?['name'] as String?;
      return name ?? '[File]';
    }
    return '[${c.contentType.split('/').last}]';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = (message.fromUser >= 0 && message.fromUser < archive.users.length)
        ? archive.users[message.fromUser]
        : null;
    final name = user?.name ?? '';
    final avatarUrl = user?.avatar != null
        ? _archiveAttachmentUrl(ref, filePath, user!.avatar!)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VoceAvatar(name: name, imageUrl: avatarUrl, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                safeText(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textHeading,
                ),
              ),
              Text(
                safeText(_preview()),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppTokens.textBody),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
