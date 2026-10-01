import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/messages/application/chat_controller.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/messages/domain/message_status.dart';

import 'chat_expiry_test.dart' show MemoryCache;

const _target = MessageTarget.group(gid: 42);
final _provider = chatControllerProvider(_target);

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 7, name: 'Sender'));
}

Map<String, dynamic> _properties(RequestOptions request) => jsonDecode(
        utf8.decode(base64Decode(request.headers['X-Properties'] as String)))
    as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112]);
  late ProviderContainer container;
  late ChatController controller;
  late List<RequestOptions> sends;
  late bool sendFails;
  late Completer<void> sendStarted;
  Completer<void>? sendGate;

  List<ChatMessage> rows() => container.read(_provider).requireValue;

  setUp(() async {
    sends = [];
    sendFails = false;
    sendStarted = Completer<void>();
    sendGate = null;
    final dio = Dio();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      if (request.path.endsWith('/send')) {
        sends.add(request);
        if (!sendStarted.isCompleted) sendStarted.complete();
        await sendGate?.future;
        if (sendFails) {
          handler.reject(DioException(requestOptions: request));
          return;
        }
      }
      handler.resolve(Response<dynamic>(
        requestOptions: request,
        data: request.path.endsWith('/prepare')
            ? 'file-id'
            : request.path.endsWith('/upload')
                ? {'path': '2026/10/1/recording-id'}
                : request.path.endsWith('/send')
                    ? 100
                    : [],
      ));
    }));
    container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      messageCacheProvider.overrideWith((ref) async => MemoryCache([])),
      messageApiProvider.overrideWith((ref) => MessageApi(dio)),
      sseEventsProvider.overrideWith((ref) => const Stream<ChatEvent>.empty()),
    ]);
    addTearDown(() {
      container.dispose();
      dio.close(force: true);
    });
    container.listen(authControllerProvider, (_, __) {});
    await container.read(authControllerProvider.future);
    await container.read(_provider.future);
    controller = container.read(_provider.notifier);
  });

  ChatMessage echo(RequestOptions request) => ChatMessage(
        mid: 100,
        fromUid: 7,
        createdAt: 123456,
        target: _target,
        detail: MessageDetail.normal(
          contentType: 'vocechat/audio',
          // The server converts the outgoing JSON body into a bare path.
          content: '2026/10/1/recording-id',
          properties: _properties(request),
        ),
      );

  test('recording stays a voice message from optimistic row to HTTP ack',
      () async {
    sendGate = Completer<void>();
    final sending =
        controller.sendVoiceMessage(bytes: bytes, filename: 'voice_123.m4a');
    await sendStarted.future;
    final optimistic = rows().single;
    expect(optimistic.mid, isNegative);
    expect(optimistic.displayContentType, 'vocechat/audio');
    expect(controller.statusFor(optimistic.mid), MessageSendStatus.sending);
    expect(controller.localBytesFor(optimistic.mid), bytes);
    expect(sends.single.contentType, 'vocechat/audio');
    expect(_properties(sends.single)['content_type'], 'audio/mp4');

    sendGate!.complete();
    await sending;
    expect(rows().single.mid, 100);
    expect(rows().single.displayContentType, 'vocechat/audio');
    expect(jsonDecode(rows().single.displayContent),
        {'path': '2026/10/1/recording-id'});
    expect(controller.localBytesFor(optimistic.mid), isNull);
    expect(controller.statusFor(100), MessageSendStatus.sent);
  });

  test('picking the same named audio stays an ordinary file', () async {
    await controller.sendImage(
        bytes: bytes, filename: 'voice_123.m4a', contentType: 'audio/mp4');
    expect(rows().single.displayContentType, 'vocechat/file');
    expect(sends.single.contentType, 'vocechat/file');
    expect(_properties(sends.single)['content_type'], 'audio/mp4');
  });

  test('failed recording retries with the same voice type and local ID',
      () async {
    sendFails = true;
    await controller.sendVoiceMessage(bytes: bytes, filename: 'voice_123.m4a');
    final failed = rows().single;
    final localId = _properties(sends.single)['local_id'];
    expect(failed.displayContentType, 'vocechat/audio');
    expect(controller.statusFor(failed.mid), MessageSendStatus.failed);

    sendFails = false;
    await controller.retrySend(failed.mid);
    expect(sends, hasLength(2));
    expect(sends.last.contentType, 'vocechat/audio');
    expect(_properties(sends.last)['local_id'], localId);
    expect(rows().single.mid, 100);
    expect(rows().single.displayContentType, 'vocechat/audio');
    expect(controller.statusFor(100), MessageSendStatus.sent);
  });

  for (final echoFirst in [true, false]) {
    test('SSE confirmation preserves one voice row with echoFirst=$echoFirst',
        () async {
      sendGate = Completer<void>();
      final sending =
          controller.sendVoiceMessage(bytes: bytes, filename: 'voice_123.m4a');
      await sendStarted.future;
      final tempMid = rows().single.mid;
      final serverMessage = echo(sends.single);
      if (!echoFirst) {
        sendGate!.complete();
        await sending;
      }
      controller.applyIncomingMessage(serverMessage);
      await Future<void>.delayed(Duration.zero);
      expect(rows(), [serverMessage]);
      if (echoFirst) {
        sendGate!.complete();
        await sending;
      }
      expect(rows(), [serverMessage]);
      expect(rows().single.displayContentType, 'vocechat/audio');
      expect(controller.statusFor(tempMid), isNull);
      expect(controller.localBytesFor(tempMid), isNull);
      expect(controller.statusFor(100), MessageSendStatus.sent);
    });
  }
}
