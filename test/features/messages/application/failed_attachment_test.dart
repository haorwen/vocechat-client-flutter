import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/messages/application/burn_after_read_provider.dart';
import 'package:vocechat_client/features/messages/application/chat_controller.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/messages/domain/message_status.dart';

import 'chat_expiry_test.dart' show MemoryCache, OfflineAuth, target, message;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZ1sAAAAASUVORK5CYII=');
  late ProviderContainer container;
  late ChatController controller;
  late MemoryCache cache;
  late bool uploadFails;
  late List<RequestOptions> requests;
  Completer<void>? uploadGate;
  late Completer<void> uploadStarted;
  List<ChatMessage> rows() =>
      container.read(chatControllerProvider(target)).requireValue;

  setUp(() async {
    uploadFails = true;
    uploadGate = null;
    uploadStarted = Completer<void>();
    requests = [];
    cache = MemoryCache([message(1)]);
    final dio = Dio();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      requests.add(request);
      if (request.path.endsWith('/upload')) {
        if (!uploadStarted.isCompleted) uploadStarted.complete();
        await uploadGate?.future;
      }
      if (request.path.endsWith('/upload') && uploadFails) {
        handler.reject(DioException(requestOptions: request));
        return;
      }
      handler.resolve(Response<dynamic>(
          requestOptions: request,
          data: request.path.endsWith('/prepare')
              ? 'id'
              : request.path.endsWith('/upload')
                  ? {'path': 'photo.jpg'}
                  : request.method == 'POST'
                      ? 100
                      : []));
    }));
    container = ProviderContainer(overrides: [
      messageCacheProvider.overrideWith((ref) async => cache),
      messageApiProvider.overrideWith((ref) => MessageApi(dio)),
      sseEventsProvider.overrideWith((ref) => const Stream<ChatEvent>.empty()),
      authControllerProvider.overrideWith(OfflineAuth.new),
    ]);
    addTearDown(() {
      container.dispose();
      dio.close(force: true);
    });
    await container.read(authControllerProvider.future);
    await container.read(chatControllerProvider(target).future);
    controller = container.read(chatControllerProvider(target).notifier);
  });

  Future<int> failUpload() async {
    await controller.sendImage(bytes: png, filename: 'photo.png');
    final mid = rows().firstWhere((row) => row.mid < 0).mid;
    expect(controller.statusFor(mid), MessageSendStatus.failed);
    return mid;
  }

  test('new text and SSE messages pass failed upload even with clock skew',
      () async {
    final mid = await failUpload();
    expect(controller.localBytesFor(mid), png);
    await controller.sendText('new text');
    expect(rows().map((row) => row.mid), [100, mid, 1]);
    controller.applyIncomingMessage(message(101, createdAt: 1));
    await Future<void>.delayed(Duration.zero);
    expect(rows().map((row) => row.mid), [101, 100, mid, 1]);
  });

  test('failed ephemeral upload expires and releases preview and retry state',
      () async {
    container.read(burnAfterReadProvider.notifier).applySnapshot({}, {42: 1});
    final mid = await failUpload();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(rows().map((row) => row.mid), [1]);
    expect(controller.localBytesFor(mid), isNull);
    expect(controller.statusFor(mid), isNull);
    expect(cache.deleted, contains(mid));
    final count = requests.length;
    await controller.retrySend(mid);
    expect(requests.length, count);
  });

  test('a slow upload moves behind newer text as soon as it fails', () async {
    uploadGate = Completer<void>();
    final upload = controller.sendImage(bytes: png, filename: 'photo.png');
    await uploadStarted.future;
    final mid = rows().first.mid;
    expect(controller.statusFor(mid), MessageSendStatus.sending);
    await controller.sendText('sent while the photo was uploading');
    expect(rows().map((row) => row.mid), [mid, 100, 1]);
    uploadGate!.complete();
    await upload;
    expect(controller.statusFor(mid), MessageSendStatus.failed);
    expect(rows().map((row) => row.mid), [100, mid, 1]);
  });

  test('failed local upload can be deleted without a server delete', () async {
    final mid = await failUpload();
    await controller.deleteMessage(mid);
    expect(rows().map((row) => row.mid), [1]);
    expect(controller.localBytesFor(mid), isNull);
    expect(controller.statusFor(mid), isNull);
    expect(requests.any((request) => request.method == 'DELETE'), isFalse);
  });

  test('retry confirms file and starts normal expiry without SSE', () async {
    container.read(burnAfterReadProvider.notifier).applySnapshot({}, {42: 1});
    final mid = await failUpload();
    uploadFails = false;
    await controller.retrySend(mid);
    expect(rows().map((row) => row.mid), [100, 1]);
    expect(rows().first.displayContent, jsonEncode({'path': 'photo.jpg'}));
    expect(controller.localBytesFor(mid), isNull);
    expect(rows().first.expiresAt, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(rows().map((row) => row.mid), [1]);
  });
}
