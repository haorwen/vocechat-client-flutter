import 'package:flutter/material.dart';

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
