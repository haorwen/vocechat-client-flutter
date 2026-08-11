import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/media_cache.dart';
import '../../../core/utils/app_log.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Shared helpers for displaying files — used by both the pre-send staging
/// preview (`_StagedPreviewRow`) and rendered `vocechat/file` messages
/// (`file_message_content.dart`). Keeping these in one place avoids drift
/// between the two surfaces.

/// Human-readable byte size, e.g. `2.5 MB`. Returns an empty string for
/// non-positive sizes.
String formatBytes(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

/// A representative icon for a MIME content type (used when no image
/// thumbnail is available).
IconData iconForContentType(String type) {
  if (type.startsWith('video')) return Icons.movie_outlined;
  if (type.startsWith('audio')) return Icons.audiotrack_outlined;
  if (type.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (type.contains('zip') || type.contains('compressed')) {
    return Icons.folder_zip_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

/// Subfolder name under the platform's shared Downloads directory that
/// Android attachment downloads are saved into (`Downloads/vocechat/...`).
const String _kDownloadAppFolder = 'vocechat';

bool _mediaStoreReady = false;

Future<void> _ensureMediaStoreReady() async {
  if (_mediaStoreReady) return;
  MediaStore.appFolder = _kDownloadAppFolder;
  await MediaStore.ensureInitialized();
  _mediaStoreReady = true;
}

String _safeDownloadFilename(String filename) {
  final safe = filename.trim().replaceAll(RegExp(r'[/\\]'), '_');
  return safe.isEmpty || safe == '.' || safe == '..' ? 'download' : safe;
}

Future<Uint8List> _downloadBytes(
  ProviderContainer container,
  String url,
  File? localFile,
) async {
  if (localFile != null) {
    try {
      final data = await localFile.readAsBytes();
      if (data.isNotEmpty) return data;
    } on FileSystemException {
      // An LRU eviction racing this read is a normal network-cache miss.
    }
  }

  final dio = container.read(dioProvider);
  final response = await dio.get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = response.data;
  if (bytes == null || bytes.isEmpty) throw Exception('empty response');
  return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

Future<void> _downloadToFile(
  ProviderContainer container,
  String url,
  File target,
  File? localFile,
) async {
  if (localFile != null) {
    try {
      await localFile.copy(target.path);
      if (await target.length() > 0) return;
    } on FileSystemException {
      // Fall through when the cache is evicted during the copy.
    }
  }

  await container.read(dioProvider).download(url, target.path);
  if (!await target.exists() || await target.length() == 0) {
    throw Exception('empty response');
  }
}

/// Downloads [url] via the app's Dio client and saves the file.
///
/// If [cachedFile] is available, or [cacheKey] resolves to a completed local
/// media file, those bytes are reused instead of re-fetching over the network.
///
/// - Android: writes straight into `Downloads/vocechat` via [MediaStore] —
///   no SAF picker, no permission prompt on API 29+.
/// - iOS / desktop: no direct "Downloads" folder equivalent is exposed to
///   apps, so this falls back to file_picker's native save-file dialog
///   (document picker on iOS, save dialog on desktop).
///
/// Shows a snackbar on success or failure.
Future<void> downloadAndSave(
  BuildContext context,
  ProviderContainer container,
  String url,
  String filename, {
  String? cacheKey,
  File? cachedFile,
}) async {
  final l = AppL10n.of(context);
  try {
    final localFile = cachedFile ??
        (cacheKey == null ? null : await MediaCache.fileForKey(cacheKey));

    if (!kIsWeb && Platform.isAndroid) {
      await _ensureMediaStoreReady();
      // MediaStore copies then deletes its source. A unique subdirectory keeps
      // simultaneous same-name downloads separate without changing the name
      // shown in Downloads/vocechat.
      final tempDir = await getTemporaryDirectory();
      final stagingDir = await tempDir.createTemp('voce_download_');
      try {
        final tempFile = File(
          '${stagingDir.path}/${_safeDownloadFilename(filename)}',
        );
        await _downloadToFile(container, url, tempFile, localFile);
        final saveInfo = await MediaStore().saveFile(
          tempFilePath: tempFile.path,
          dirType: DirType.download,
          dirName: DirName.download,
        );
        if (saveInfo == null) throw Exception('MediaStore save returned null');
      } finally {
        try {
          if (await stagingDir.exists()) {
            await stagingDir.delete(recursive: true);
          }
        } on FileSystemException {
          // The OS may still be finishing the MediaStore copy.
        }
      }
    } else if (kIsWeb || Platform.isIOS) {
      final data = await _downloadBytes(container, url, localFile);
      await FilePicker.platform.saveFile(fileName: filename, bytes: data);
    } else {
      // Desktop: saveFile returns the chosen path; copy or stream into it.
      final path = await FilePicker.platform.saveFile(fileName: filename);
      if (path == null) return; // user cancelled
      await _downloadToFile(container, url, File(path), localFile);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.downloadSaved)));
    }
  } catch (e, st) {
    AppLog.e(LogTag.general, () => 'download failed url=$url', error: e, stackTrace: st);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.downloadFailed)));
    }
  }
}
