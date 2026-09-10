import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PreparedAttachment {
  const PreparedAttachment(this.bytes, this.filename, this.contentType);

  final Uint8List bytes;
  final String filename;
  final String? contentType;
}

/// Convert Apple camera originals before previewing or uploading them. Renaming
/// a HEIC file alone does not make its bytes readable by the server or clients.
class AttachmentPreparer {
  static const _channel = MethodChannel('vocechat/image_conversion');

  static Future<PreparedAttachment> prepare({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final extension = filename.split('.').last.toLowerCase();
    final type = contentType?.split(';').first.trim().toLowerCase();
    final appleName = extension == 'heic' || extension == 'heif';
    final appleType = type == 'image/heic' ||
        type == 'image/heif' ||
        type == 'image/heic-sequence' ||
        type == 'image/heif-sequence';
    final appleBytes = _isHeif(bytes);
    if (!appleName && !appleType && !appleBytes) {
      return PreparedAttachment(bytes, filename, contentType);
    }

    // Some pickers already transcode the bytes but retain the original name.
    final existingFormat = _commonFormat(bytes);
    if (existingFormat != null) {
      return PreparedAttachment(
          bytes, _rename(filename, existingFormat.$1), existingFormat.$2);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final jpeg = await _channel.invokeMethod<Uint8List>('heifToJpeg', bytes);
      if (jpeg == null || _commonFormat(jpeg)?.$2 != 'image/jpeg') {
        throw StateError('Could not convert the photo to JPEG');
      }
      return PreparedAttachment(jpeg, _rename(filename, 'jpg'), 'image/jpeg');
    }

    // Other platforms may provide a HEIF decoder through the Flutter engine.
    // PNG is universally readable and does not require another native plugin.
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        final png =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) throw StateError('Could not convert the photo to PNG');
        return PreparedAttachment(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            _rename(filename, 'png'),
            'image/png');
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static String _rename(String name, String extension) {
    final dot = name.lastIndexOf('.');
    final stem = (dot > 0 ? name.substring(0, dot) : name).trim();
    return '${stem.isEmpty ? 'image' : stem}.$extension';
  }

  static (String, String)? _commonFormat(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return ('jpg', 'image/jpeg');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return ('png', 'image/png');
    }
    return null;
  }

  static bool _isHeif(Uint8List bytes) {
    if (bytes.length < 16 ||
        String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
      return false;
    }
    final size = ByteData.sublistView(bytes).getUint32(0);
    final end = size < bytes.length ? size : bytes.length;
    final brands = <String>{};
    for (var offset = 8; offset + 4 <= end; offset += 4) {
      if (offset != 12) {
        brands.add(String.fromCharCodes(bytes.sublist(offset, offset + 4)));
      }
    }
    // AVIF shares the mif1 container brand but is not an Apple HEIF photo.
    if (brands.contains('avif') || brands.contains('avis')) return false;
    return brands.any(const {
      'heic',
      'heix',
      'hevc',
      'hevx',
      'heim',
      'heis',
      'hevm',
      'hevs',
      'mif1',
      'msf1'
    }.contains);
  }
}
