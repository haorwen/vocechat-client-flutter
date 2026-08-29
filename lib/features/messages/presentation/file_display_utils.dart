import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

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

/// Subfolder used for VoceChat files in Android shared storage.
const String _kDownloadAppFolder = 'vocechat';

enum DownloadFileKind { image, video, other }

const _imageExtensions = <String>{
  'avif',
  'bmp',
  'dng',
  'gif',
  'heic',
  'heif',
  'jpeg',
  'jpg',
  'png',
  'svg',
  'tif',
  'tiff',
  'webp',
};

const _videoExtensions = <String>{
  '3g2',
  '3gp',
  'avi',
  'm2ts',
  'm4v',
  'mkv',
  'mov',
  'mp4',
  'mpeg',
  'mpg',
  'mts',
  'ogv',
  'ts',
  'webm',
};

@visibleForTesting
DownloadFileKind classifyDownloadFile(String filename, String? contentType) {
  final mime = contentType?.trim().toLowerCase() ?? '';
  if (mime.startsWith('image/')) return DownloadFileKind.image;
  if (mime.startsWith('video/')) return DownloadFileKind.video;

  final safeName = filename.split(RegExp(r'[?#]')).first.toLowerCase();
  final dot = safeName.lastIndexOf('.');
  final extension = dot < 0 ? '' : safeName.substring(dot + 1);
  if (_imageExtensions.contains(extension)) return DownloadFileKind.image;
  if (_videoExtensions.contains(extension)) return DownloadFileKind.video;
  return DownloadFileKind.other;
}

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

Future<void> _withStagedDownload(
  ProviderContainer container,
  String url,
  String filename,
  File? localFile,
  Future<void> Function(File file) save,
) async {
  final tempDir = await getTemporaryDirectory();
  final stagingDir = await tempDir.createTemp('voce_download_');
  try {
    final tempFile = File('${stagingDir.path}/$filename');
    await _downloadToFile(container, url, tempFile, localFile);
    await save(tempFile);
  } finally {
    try {
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    } catch (e, st) {
      AppLog.w(
        LogTag.general,
        () => 'download staging cleanup failed path=${stagingDir.path}',
        error: e,
        stackTrace: st,
      );
    }
  }
}

Future<void> _saveToAndroidSharedStorage(
  ProviderContainer container,
  String url,
  String filename,
  DownloadFileKind kind,
  File? localFile,
) async {
  await _ensureMediaStoreReady();
  final (dirType, dirName) = switch (kind) {
    DownloadFileKind.image => (DirType.photo, DirName.dcim),
    DownloadFileKind.video => (DirType.video, DirName.dcim),
    DownloadFileKind.other => (DirType.download, DirName.download),
  };

  await _withStagedDownload(
    container,
    url,
    filename,
    localFile,
    (tempFile) async {
      final mediaStore = MediaStore();
      final saveInfo = await mediaStore.saveFile(
        tempFilePath: tempFile.path,
        dirType: dirType,
        dirName: dirName,
      );
      if (saveInfo != null) return;

      // Version 0.1.3 can save successfully but fail to decode SaveInfo in
      // release builds, so verify the final MediaStore entry before failing.
      final savedUri = await mediaStore.getFileUri(
        fileName: filename,
        dirType: dirType,
        dirName: dirName,
      );
      if (savedUri == null) {
        throw Exception('MediaStore save returned null');
      }
    },
  );
}

Future<void> _saveToIosPhotoLibrary(
  ProviderContainer container,
  String url,
  String filename,
  DownloadFileKind kind,
  File? localFile,
) async {
  final permission = await PhotoManager.requestPermissionExtend(
    requestOption: const PermissionRequestOption(
      iosAccessLevel: IosAccessLevel.addOnly,
    ),
  );
  if (!permission.hasAccess) {
    throw Exception('Photo library add permission denied');
  }

  await _withStagedDownload(
    container,
    url,
    filename,
    localFile,
    (tempFile) async {
      switch (kind) {
        case DownloadFileKind.image:
          await PhotoManager.editor.saveImageWithPath(
            tempFile.path,
            title: filename,
          );
        case DownloadFileKind.video:
          await PhotoManager.editor.saveVideo(tempFile, title: filename);
        case DownloadFileKind.other:
          throw StateError('Non-media files cannot be saved to Photos');
      }
    },
  );
}

/// Downloads [url] via the app's Dio client and saves the file.
///
/// If [cachedFile] is available, or [cacheKey] resolves to a completed local
/// media file, those bytes are reused instead of re-fetching over the network.
/// [contentType] is preferred for media classification; the filename extension
/// is used as a fallback.
///
/// - Android images/videos: `DCIM/vocechat` via MediaStore.
/// - Android other files: `Download/vocechat` via MediaStore.
/// - iOS images/videos: the system Photos library.
/// - iOS other files and desktop: the native save-file dialog.
///
/// Shows a snackbar on success or failure.
Future<void> downloadAndSave(
  BuildContext context,
  ProviderContainer container,
  String url,
  String filename, {
  String? contentType,
  String? cacheKey,
  File? cachedFile,
}) async {
  final l = AppL10n.of(context);
  try {
    final safeFilename = _safeDownloadFilename(filename);
    final kind = classifyDownloadFile(safeFilename, contentType);
    final localFile = cachedFile ??
        (cacheKey == null ? null : await MediaCache.fileForKey(cacheKey));

    if (!kIsWeb && Platform.isAndroid) {
      await _saveToAndroidSharedStorage(
        container,
        url,
        safeFilename,
        kind,
        localFile,
      );
    } else if (!kIsWeb && Platform.isIOS && kind != DownloadFileKind.other) {
      await _saveToIosPhotoLibrary(
        container,
        url,
        safeFilename,
        kind,
        localFile,
      );
    } else if (kIsWeb || Platform.isIOS) {
      final data = await _downloadBytes(container, url, localFile);
      final path = await FilePicker.platform.saveFile(
        fileName: safeFilename,
        bytes: data,
      );
      if (path == null && !kIsWeb) return;
    } else {
      final path = await FilePicker.platform.saveFile(fileName: safeFilename);
      if (path == null) return;
      await _downloadToFile(container, url, File(path), localFile);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.downloadSaved)));
    }
  } catch (e, st) {
    AppLog.e(LogTag.general, () => 'download failed url=$url',
        error: e, stackTrace: st);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.downloadFailed)));
    }
  }
}
