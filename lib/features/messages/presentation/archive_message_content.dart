import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/account_store.dart';
import '../../../core/storage/media_cache.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../data/message_api.dart';
import '../domain/message_models.dart';
import 'file_display_utils.dart';
import 'file_message_content.dart' show ImagePreviewScreen;

part 'archive_message_content.g.dart';

// ---------------------------------------------------------------------------
// Archive (forwarded-message) rendering.
//
// Web reference: components/Message/ForwardedMessage.tsx + utils.tsx
// `normalizeArchiveData`. A `vocechat/archive` message's `content` is the
// archive's file-path id (e.g. "2026/7/8/<uuid>"); fetch the index via
// GET /api/resource/archive?file_path=... to get the bundled messages, then
// render each with its denormalized author (archive.users[fromUser] — an
// INDEX, not a uid).
//
// The in-bubble card is a compact PREVIEW (first few messages, truncated).
// Tapping it pushes a full-screen detail page that renders every bundled
// message in full: complete text/markdown, inline image attachments (tap →
// full-screen viewer), and file cards with a download action. Attachments
// resolve via GET /api/resource/archive/attachment?file_path=..&attachment_id=..
// (no auth token required server-side; Referer still sent for license check).
// ---------------------------------------------------------------------------

@riverpod
Future<Archive> archiveContent(Ref ref, String filePath) {
  return ref.watch(messageApiProvider).getArchive(filePath);
}

/// How many bundled messages the in-bubble preview card shows before
/// collapsing into a "+N more" footer.
const _kPreviewMessageCount = 3;

String? _currentBaseUrl(WidgetRef ref) {
  final serverState = ref.read(serverStoreProvider).valueOrNull;
  final server = serverState?.servers
      .where((s) => s.id == serverState.currentServerId)
      .firstOrNull;
  final base = server?.baseUrl ?? '';
  return base.isEmpty ? null : base;
}

String? _currentCacheNamespace(WidgetRef ref) =>
    ref.watch(accountStoreProvider).valueOrNull?.currentAccountId;

/// Builds the `/api/resource/archive/attachment` URL for [attachmentId] in
/// the archive identified by [filePath]. Mirrors
/// `file_message_content.dart`'s `_buildResourceUrls` pattern.
String? _archiveAttachmentUrl(
  WidgetRef ref,
  String filePath,
  int attachmentId, {
  bool download = false,
}) {
  final base = _currentBaseUrl(ref);
  if (base == null) return null;
  final encodedPath = Uri.encodeQueryComponent(filePath);
  final suffix = download ? '&download=true' : '';
  return '$base/api/resource/archive/attachment?file_path=$encodedPath&attachment_id=$attachmentId$suffix';
}

/// The archive attachment endpoint is unauthenticated server-side, but the
/// license check still wants a Referer (see dio_client.dart).
Map<String, String> _refererHeaders(String? baseUrl) {
  if (baseUrl == null || baseUrl.isEmpty) return const {};
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.host.isEmpty) return const {};
  return {'Referer': '${uri.scheme}://${uri.authority}/'};
}

// Archive attachment avatars need no auth headers. VoceAvatar's disk cache is
// disabled when the containing burn-after-read archive is ephemeral.

/// Renders a forwarded-message card for a `vocechat/archive` message whose
/// [content] is the archive file-path id. The card previews the first few
/// bundled messages; tapping opens [_ArchiveDetailScreen] with everything.
class ArchiveMessageContent extends ConsumerWidget {
  const ArchiveMessageContent({
    super.key,
    required this.filePath,
    this.cacheMedia = true,
  });
  final String filePath;
  final bool cacheMedia;

  void _openDetail(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ArchiveDetailScreen(
          filePath: filePath,
          cacheMedia: cacheMedia,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(archiveContentProvider(filePath));
    final l = AppL10n.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: archiveAsync.hasValue ? () => _openDetail(context) : null,
      child: Container(
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
                Icon(Icons.forward_outlined,
                    size: 16, color: AppTokens.gray500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.archiveForwardedLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.gray500,
                    ),
                  ),
                ),
                if (archiveAsync.hasValue)
                  Icon(Icons.chevron_right, size: 16, color: AppTokens.gray400),
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
                l.archiveLoadFailed,
                style: TextStyle(fontSize: 12, color: AppTokens.gray500),
              ),
              data: (archive) {
                final shown =
                    archive.messages.take(_kPreviewMessageCount).toList();
                final remaining = archive.messages.length - shown.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _ArchivePreviewRow(
                        archive: archive,
                        message: shown[i],
                        filePath: filePath,
                        cacheMedia: cacheMedia,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      remaining > 0
                          ? l.archiveViewAll(archive.messages.length)
                          : l.archiveTapToView,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTokens.primary500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivePreviewRow extends ConsumerWidget {
  const _ArchivePreviewRow({
    required this.archive,
    required this.message,
    required this.filePath,
    required this.cacheMedia,
  });

  final Archive archive;
  final ArchiveMessage message;
  final String filePath;
  final bool cacheMedia;

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
    final user =
        (message.fromUser >= 0 && message.fromUser < archive.users.length)
            ? archive.users[message.fromUser]
            : null;
    final name = user?.name ?? '';
    final avatarUrl = user?.avatar != null
        ? _archiveAttachmentUrl(ref, filePath, user!.avatar!)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VoceAvatar(
          name: name,
          imageUrl: avatarUrl,
          size: 20,
          cacheImage: cacheMedia,
        ),
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

// ---------------------------------------------------------------------------
// Full detail page
// ---------------------------------------------------------------------------

class _ArchiveDetailScreen extends ConsumerWidget {
  const _ArchiveDetailScreen({
    required this.filePath,
    required this.cacheMedia,
  });
  final String filePath;
  final bool cacheMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(archiveContentProvider(filePath));
    final l = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppTokens.canvas,
      appBar: AppBar(
        title:
            Text(l.archiveForwardedLabel, style: const TextStyle(fontSize: 16)),
      ),
      body: archiveAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            l.archiveLoadFailed,
            style: TextStyle(fontSize: 13, color: AppTokens.gray500),
          ),
        ),
        data: (archive) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: archive.messages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) => _ArchiveDetailRow(
            archive: archive,
            message: archive.messages[i],
            filePath: filePath,
            cacheMedia: cacheMedia,
          ),
        ),
      ),
    );
  }
}

class _ArchiveDetailRow extends ConsumerWidget {
  const _ArchiveDetailRow({
    required this.archive,
    required this.message,
    required this.filePath,
    required this.cacheMedia,
  });

  final Archive archive;
  final ArchiveMessage message;
  final String filePath;
  final bool cacheMedia;

  String _formatTime() {
    if (message.createdAt == 0) return '';
    final dt =
        DateTime.fromMillisecondsSinceEpoch(message.createdAt, isUtc: true)
            .toLocal();
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$mo/$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        (message.fromUser >= 0 && message.fromUser < archive.users.length)
            ? archive.users[message.fromUser]
            : null;
    final name = user?.name ?? '';
    final avatarUrl = user?.avatar != null
        ? _archiveAttachmentUrl(ref, filePath, user!.avatar!)
        : null;
    final time = _formatTime();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VoceAvatar(
          name: name,
          imageUrl: avatarUrl,
          size: 32,
          cacheImage: cacheMedia,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
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
                  if (time.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(fontSize: 11, color: AppTokens.gray400),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              _ArchiveDetailBody(
                message: message,
                filePath: filePath,
                cacheMedia: cacheMedia,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArchiveDetailBody extends ConsumerWidget {
  const _ArchiveDetailBody({
    required this.message,
    required this.filePath,
    required this.cacheMedia,
  });

  final ArchiveMessage message;
  final String filePath;
  final bool cacheMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = message.content;

    if (c.contentType == 'text/markdown') {
      return MarkdownBody(
        data: safeText(c.content ?? ''),
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontSize: 14,
            color: AppTokens.textBody,
            height: 20 / 14,
          ),
        ),
      );
    }

    if (c.contentType == 'vocechat/file') {
      return _ArchiveAttachment(
        message: message,
        filePath: filePath,
        cacheMedia: cacheMedia,
      );
    }

    // text/plain and anything unknown-but-textual — show the full content,
    // selectable so long forwarded texts can be copied out.
    return SelectableText(
      safeText(c.content ?? ''),
      style: TextStyle(
        fontSize: 14,
        color: AppTokens.textBody,
        height: 20 / 14,
      ),
    );
  }
}

/// A `vocechat/file` entry inside an archive: inline image (tap → viewer)
/// when the attachment is an image, otherwise a file card with download.
class _ArchiveAttachment extends ConsumerWidget {
  const _ArchiveAttachment({
    required this.message,
    required this.filePath,
    required this.cacheMedia,
  });

  final ArchiveMessage message;
  final String filePath;
  final bool cacheMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = message.content;
    final props = c.properties ?? const <String, dynamic>{};
    final name = (props['name'] as String?) ?? '';
    final contentType = (props['content_type'] as String?) ?? '';
    final size = (props['size'] as num?)?.toInt() ?? 0;

    final baseUrl = _currentBaseUrl(ref);
    final fileUrl = c.fileId != null
        ? _archiveAttachmentUrl(ref, filePath, c.fileId!)
        : null;
    final downloadUrl = c.fileId != null
        ? _archiveAttachmentUrl(ref, filePath, c.fileId!, download: true)
        : null;

    final isImage = contentType.startsWith('image/') &&
        contentType != 'image/x-sony-arw' &&
        fileUrl != null;

    if (isImage) {
      final headers = _refererHeaders(baseUrl);
      final cacheNamespace = _currentCacheNamespace(ref);
      final shouldCache = cacheMedia && cacheNamespace != null;
      final originCacheKey = cacheNamespace == null
          ? null
          : MediaCache.scopedKey(cacheNamespace, fileUrl);
      // Thumbnail attachment when the archive bundled one, else the original.
      final thumbUrl = c.thumbnailId != null
          ? _archiveAttachmentUrl(ref, filePath, c.thumbnailId!) ?? fileUrl
          : fileUrl;
      final thumbnailCacheKey = cacheNamespace == null
          ? null
          : MediaCache.scopedKey(cacheNamespace, thumbUrl);
      final natW = (props['width'] as num?)?.toDouble();
      final natH = (props['height'] as num?)?.toDouble();
      const maxSize = 240.0;
      const minSize = 80.0;
      double w = maxSize, h = maxSize;
      if (natW != null && natH != null && natW > 0 && natH > 0) {
        final ratio = natW / natH;
        if (ratio >= 1) {
          h = (maxSize / ratio).clamp(minSize, maxSize);
        } else {
          w = (maxSize * ratio).clamp(minSize, maxSize);
        }
      }
      return GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => ImagePreviewScreen(
                originUrl: fileUrl,
                cacheKey: shouldCache ? originCacheKey : null,
                cacheMedia: shouldCache,
                downloadUrl: downloadUrl ?? fileUrl,
                headers: headers,
                title: name,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: w,
            height: h,
            child: shouldCache
                ? CachedNetworkImage(
                    imageUrl: thumbUrl,
                    cacheKey: thumbnailCacheKey,
                    httpHeaders: headers,
                    fit: BoxFit.cover,
                    placeholder: (context, _) => _imagePlaceholder(),
                    errorWidget: (context, url, error) => _imageError(),
                  )
                : Image.network(
                    thumbUrl,
                    headers: headers,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : _imagePlaceholder(),
                    errorBuilder: (context, error, stackTrace) => _imageError(),
                  ),
          ),
        ),
      );
    }

    // Non-image file card with download button.
    final sizeLabel = formatBytes(size);
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTokens.gray200),
      ),
      child: Row(
        children: [
          Icon(iconForContentType(contentType),
              color: AppTokens.primary500, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  safeText(name.isEmpty ? '[File]' : name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray700,
                  ),
                ),
                if (sizeLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sizeLabel,
                    style: TextStyle(fontSize: 11, color: AppTokens.gray500),
                  ),
                ],
              ],
            ),
          ),
          if (downloadUrl != null)
            IconButton(
              tooltip: AppL10n.of(context).tooltipDownload,
              icon: Icon(
                Icons.download_outlined,
                color: AppTokens.gray500,
                size: 22,
              ),
              onPressed: () => downloadAndSave(
                context,
                ProviderScope.containerOf(context, listen: false),
                downloadUrl,
                name.isEmpty ? '[file]' : name,
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: AppTokens.gray100,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  Widget _imageError() => Container(
        color: AppTokens.gray100,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: AppTokens.gray400,
          size: 32,
        ),
      );
}
