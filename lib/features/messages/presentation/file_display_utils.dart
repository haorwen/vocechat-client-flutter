import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
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

/// Downloads [url] via the app's Dio client and saves the file via the
/// platform's native save-file picker (SAF on Android, UIDocumentPicker on
/// iOS, system dialog on desktop). Shows a snackbar on success or failure.
Future<void> downloadAndSave(
  BuildContext context,
  ProviderContainer container,
  String url,
  String filename,
) async {
  final l = AppL10n.of(context);
  try {
    final dio = container.read(dioProvider);
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) throw Exception('empty response');

    final Uint8List data =
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      await FilePicker.platform.saveFile(fileName: filename, bytes: data);
    } else {
      // Desktop: saveFile returns the chosen path; write bytes ourselves.
      final path = await FilePicker.platform.saveFile(fileName: filename);
      if (path == null) return; // user cancelled
      await File(path).writeAsBytes(data, flush: true);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.downloadSaved)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.downloadFailed)));
    }
  }
}
