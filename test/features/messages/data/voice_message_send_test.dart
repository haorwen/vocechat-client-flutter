import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

void main() {
  final bytes = Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112]);

  for (final isVoiceMessage in [false, true]) {
    for (final target in [
      const MessageTarget.user(uid: 8),
      const MessageTarget.group(gid: 42),
    ]) {
      test('audio attachment sends voice=$isVoiceMessage to $target', () async {
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
                    ? {'path': '2026/10/1/recording-id'}
                    : 101,
          ));
        }));

        final result = await MessageApi(dio).uploadBytesAndSend(
          target,
          bytes: bytes,
          filename: 'voice_123.m4a',
          contentType: 'audio/mp4',
          isVoiceMessage: isVoiceMessage,
          localId: 123,
        );

        expect(result.mid, 101);
        expect(result.path, '2026/10/1/recording-id');
        expect(requests, hasLength(3));
        expect(requests.first.data, {
          'content_type': 'audio/mp4',
          'filename': 'voice_123.m4a',
        });
        final upload = requests[1].data as FormData;
        expect(upload.files.single.value.filename, 'voice_123.m4a');
        final sent = requests.last;
        expect(
            sent.path,
            target is MessageTargetUser
                ? '/api/user/8/send'
                : '/api/group/42/send');
        expect(sent.contentType,
            isVoiceMessage ? 'vocechat/audio' : 'vocechat/file');
        expect(jsonDecode(sent.data as String), {
          'path': '2026/10/1/recording-id',
        });
        expect(
          jsonDecode(utf8
              .decode(base64Decode(sent.headers['X-Properties'] as String))),
          {
            'name': 'voice_123.m4a',
            'content_type': 'audio/mp4',
            'size': bytes.length,
            'local_id': 123,
          },
        );
      });
    }
  }
}
