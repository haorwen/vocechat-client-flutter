import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

Map<String, dynamic> _properties(RequestOptions request) => jsonDecode(
        utf8.decode(base64Decode(request.headers['X-Properties'] as String)))
    as Map<String, dynamic>;

void main() {
  late MessageApi api;
  late List<RequestOptions> requests;

  setUp(() {
    requests = [];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      handler.resolve(Response<int>(
        requestOptions: request,
        statusCode: 200,
        data: 101,
      ));
    }));
    api = MessageApi(dio);
    addTearDown(() => dio.close(force: true));
  });

  test('text sends local ID and mentions together without changing the body',
      () async {
    final mid = await api.sendText(
      const MessageTarget.group(gid: 42),
      '你好 @8',
      mentions: [8, 9],
      localId: 1788912000000123,
    );
    final request = requests.single;
    expect(mid, 101);
    expect(request.method, 'POST');
    expect(request.path, '/api/group/42/send');
    expect(request.contentType, 'text/plain');
    expect(request.data, '你好 @8');
    expect(_properties(request), {
      'mentions': [8, 9],
      'local_id': 1788912000000123,
    });
  });

  test('Markdown uses the same property header for direct messages', () async {
    final mid = await api.sendMarkdown(
      const MessageTarget.user(uid: 8),
      '**hello**',
      mentions: [8],
      localId: 123,
    );
    final request = requests.single;
    expect(mid, 101);
    expect(request.path, '/api/user/8/send');
    expect(request.contentType, 'text/markdown');
    expect(request.data, '**hello**');
    expect(_properties(request), {
      'mentions': [8],
      'local_id': 123,
    });
  });

  test('local ID is sent even without mentions', () async {
    await api.sendText(
      const MessageTarget.group(gid: 42),
      'hello',
      mentions: [],
      localId: 123,
    );
    expect(_properties(requests.single), {'local_id': 123});
  });

  test('existing calls without metadata omit X-Properties', () async {
    await api.sendText(const MessageTarget.group(gid: 42), 'text');
    await api.sendMarkdown(const MessageTarget.user(uid: 8), '**text**',
        mentions: []);
    await api.replyMessage(77, 'reply');
    expect(requests, hasLength(3));
    for (final request in requests) {
      expect(request.headers.containsKey('X-Properties'), isFalse);
    }
  });

  test('existing mentions-only calls retain the original property payload',
      () async {
    await api.sendText(const MessageTarget.group(gid: 42), '@8', mentions: [8]);
    expect(_properties(requests.single), {
      'mentions': [8],
    });
  });

  for (final markdown in [false, true]) {
    test('reply sends local ID and mentions with markdown=$markdown', () async {
      final mid = await api.replyMessage(
        77,
        'reply @8',
        markdown: markdown,
        mentions: [8],
        localId: 456,
      );
      final request = requests.single;
      expect(mid, 101);
      expect(request.method, 'POST');
      expect(request.path, '/api/message/77/reply');
      expect(request.contentType, markdown ? 'text/markdown' : 'text/plain');
      expect(request.data, 'reply @8');
      expect(_properties(request), {
        'mentions': [8],
        'local_id': 456,
      });
    });
  }
}
