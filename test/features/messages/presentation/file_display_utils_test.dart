import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/messages/presentation/file_display_utils.dart';

void main() {
  group('classifyDownloadFile', () {
    test('prefers image and video MIME types', () {
      expect(
        classifyDownloadFile('attachment.bin', 'image/jpeg'),
        DownloadFileKind.image,
      );
      expect(
        classifyDownloadFile('attachment.bin', 'video/mp4; charset=binary'),
        DownloadFileKind.video,
      );
    });

    test('falls back to a case-insensitive filename extension', () {
      expect(
        classifyDownloadFile('photo.HEIC', null),
        DownloadFileKind.image,
      );
      expect(
        classifyDownloadFile('clip.MOV?download=true', ''),
        DownloadFileKind.video,
      );
    });

    test('classifies non-media files as other', () {
      expect(
        classifyDownloadFile('report.pdf', 'application/pdf'),
        DownloadFileKind.other,
      );
      expect(
        classifyDownloadFile('archive', null),
        DownloadFileKind.other,
      );
    });
  });
}
