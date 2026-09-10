import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/messages/data/attachment_preparer.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

Uint8List heif({String brand = 'heic'}) => Uint8List.fromList([
      0,
      0,
      0,
      24,
      ...ascii.encode('ftyp$brand'),
      0,
      0,
      0,
      0,
      ...ascii.encode('mif1$brand'),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('vocechat/image_conversion');
  final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
  late int conversions;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    conversions = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'heifToJpeg');
      conversions++;
      return jpeg;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final name in ['IMG_1234.HEIC', 'photo.heif', '', 'wrong.jpg']) {
    test('HEIF bytes convert even with missing or misleading name: $name',
        () async {
      final result = await AttachmentPreparer.prepare(
          bytes: heif(),
          filename: name,
          contentType: 'application/octet-stream');
      expect(result.bytes, jpeg);
      expect(result.contentType, 'image/jpeg');
      expect(result.filename,
          name.isEmpty ? 'image.jpg' : '${name.split('.').first}.jpg');
      expect(conversions, 1);
    });
  }

  test('picker-transcoded JPEG gets a matching name without another conversion',
      () async {
    final result = await AttachmentPreparer.prepare(
        bytes: jpeg, filename: 'image.heic', contentType: 'image/heic');
    expect(result.filename, 'image.jpg');
    expect(result.contentType, 'image/jpeg');
    expect(identical(result.bytes, jpeg), isTrue);
    expect(conversions, 0);
  });

  test('ordinary JPEG, GIF, video and AVIF pass through unchanged', () async {
    for (final entry in [
      ('photo.jpg', jpeg),
      ('animation.gif', Uint8List.fromList(ascii.encode('GIF89a'))),
      (
        'video.mp4',
        heif(brand: 'mp42')..setRange(16, 20, ascii.encode('mp42'))
      ),
      ('photo.avif', heif(brand: 'avif')),
    ]) {
      final result =
          await AttachmentPreparer.prepare(bytes: entry.$2, filename: entry.$1);
      expect(identical(result.bytes, entry.$2), isTrue);
      expect(result.filename, entry.$1);
    }
    expect(conversions, 0);
  });

  test('prepare, multipart and message properties all describe converted bytes',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      handler.resolve(Response<dynamic>(
          requestOptions: request,
          data: request.path.endsWith('/prepare')
              ? 'file-id'
              : request.path.endsWith('/upload')
                  ? {
                      'path': '2026/photo',
                      'image_properties': {'width': 10, 'height': 20}
                    }
                  : 123));
    }));
    await MessageApi(dio).uploadBytesAndSend(const MessageTarget.group(gid: 42),
        bytes: heif(),
        filename: 'image.heic',
        contentType: 'image/heic',
        localId: 456);
    expect(requests.first.data,
        {'filename': 'image.jpg', 'content_type': 'image/jpeg'});
    final file = (requests[1].data as FormData).files.single.value;
    expect(file.filename, 'image.jpg');
    expect(await file.finalize().expand((chunk) => chunk).toList(), jpeg);
    final properties = jsonDecode(utf8
        .decode(base64Decode(requests.last.headers['X-Properties'] as String)));
    expect(properties, {
      'name': 'image.jpg',
      'content_type': 'image/jpeg',
      'size': jpeg.length,
      'width': 10,
      'height': 20,
      'local_id': 456
    });
    expect(conversions, 1);
  });

  test('conversion failure stops before preparing or uploading a resource',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel,
            (_) async => throw PlatformException(code: 'decode_failed'));
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
        InterceptorsWrapper(onRequest: (_, __) => fail('Unexpected upload')));
    await expectLater(
        MessageApi(dio).uploadBytesAndSend(const MessageTarget.group(gid: 42),
            bytes: heif(), filename: 'image.heic'),
        throwsA(isA<PlatformException>()));
  });
}
