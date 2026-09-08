import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/messages/application/burn_after_read_provider.dart';
import 'package:vocechat_client/features/messages/application/chat_controller.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

const target = MessageTarget.group(gid: 42);

ChatMessage message(int mid,
        {int? seconds, int? createdAt, bool reply = false}) =>
    ChatMessage(
      mid: mid,
      fromUid: 7,
      createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
      target: target,
      detail: reply
          ? MessageDetail.reply(
              mid: 9,
              contentType: 'text/plain',
              content: 'hello',
              expiresIn: seconds)
          : MessageDetail.normal(
              contentType: 'text/plain', content: 'hello', expiresIn: seconds),
    );

class MemoryCache implements MessageCache {
  MemoryCache(this.rows);
  List<ChatMessage> rows;
  final deleted = <int>[];
  @override
  Future<List<ChatMessage>> read(MessageTarget target,
          {int limit = 500}) async =>
      List.of(rows);
  @override
  void scheduleWrite(MessageTarget target, List<ChatMessage> messages) {
    rows = List.of(messages);
  }

  @override
  Future<void> deleteMid(MessageTarget target, int mid) async {
    deleted.add(mid);
    rows.removeWhere((m) => m.mid == mid);
  }

  @override
  Future<void> setCursor(int mid) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OfflineAuth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> setup(MemoryCache cache,
      {List<ChatMessage> history = const []}) async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response<dynamic>(
          requestOptions: options,
          data: options.method == 'POST'
              ? 100
              : history.map((m) => m.toJson()).toList()));
    }));
    final container = ProviderContainer(overrides: [
      messageCacheProvider.overrideWith((ref) async => cache),
      messageApiProvider.overrideWith((ref) => MessageApi(dio)),
      sseEventsProvider.overrideWith((ref) => const Stream<ChatEvent>.empty()),
      authControllerProvider.overrideWith(OfflineAuth.new),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container.read(chatControllerProvider(target).future);
    return container;
  }

  test('received normal and reply messages expire without another event',
      () async {
    final cache = MemoryCache([message(1)]);
    final container = await setup(cache);
    final controller = container.read(chatControllerProvider(target).notifier);
    controller.applyIncomingMessage(message(2, seconds: 1));
    controller.applyIncomingMessage(message(3, seconds: 1, reply: true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
        container.read(chatControllerProvider(target)).requireValue.length, 3);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
        container
            .read(chatControllerProvider(target))
            .requireValue
            .map((m) => m.mid),
        [1]);
    expect(cache.deleted, containsAll([2, 3]));
  });

  test('expired cache/history replay is not displayed again', () async {
    final expired = message(2,
        seconds: 1, createdAt: DateTime.now().millisecondsSinceEpoch - 2000);
    final cache = MemoryCache([message(1), expired]);
    final container = await setup(cache);
    container
        .read(chatControllerProvider(target).notifier)
        .applyIncomingMessage(expired);
    await Future<void>.delayed(Duration.zero);
    expect(
        container
            .read(chatControllerProvider(target))
            .requireValue
            .map((m) => m.mid),
        [1]);
    expect(cache.deleted, contains(2));
  });

  test('HTTP-first send retains expiry without waiting for SSE', () async {
    final cache = MemoryCache([message(1)]);
    final container = await setup(cache);
    container.read(burnAfterReadProvider.notifier).applySnapshot({}, {42: 1});
    await container
        .read(chatControllerProvider(target).notifier)
        .sendText('hello');
    final sent =
        container.read(chatControllerProvider(target)).requireValue.first;
    expect(sent.mid, 100);
    expect(sent.expiresAt, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
        container
            .read(chatControllerProvider(target))
            .requireValue
            .map((m) => m.mid),
        [1]);
  });

  test('SSE for an HTTP-confirmed mid restores authoritative expiry', () async {
    final cache = MemoryCache([message(1)]);
    final container = await setup(cache);
    final controller = container.read(chatControllerProvider(target).notifier);
    await controller.sendText('hello');
    controller.applyEditEcho(100, 'edited', 'text/plain');
    controller.applyIncomingMessage(message(100, seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final rows = container.read(chatControllerProvider(target)).requireValue;
    expect(rows.where((m) => m.mid == 100).length, 1);
    expect(rows.first.expiresAt, isNotNull);
    expect(rows.first.displayContent, 'edited');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
        container
            .read(chatControllerProvider(target))
            .requireValue
            .map((m) => m.mid),
        [1]);
  });

  test('history repairs expiry missing from an old confirmed cache row',
      () async {
    final cache = MemoryCache([message(1), message(2)]);
    final container = await setup(cache, history: [
      message(2,
          seconds: 1, createdAt: DateTime.now().millisecondsSinceEpoch - 2000)
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
        container
            .read(chatControllerProvider(target))
            .requireValue
            .map((m) => m.mid),
        [1]);
    expect(cache.deleted, contains(2));
  });

  test('sent replies retain expiry after HTTP confirmation', () async {
    final container = await setup(MemoryCache([message(1)]));
    container.read(burnAfterReadProvider.notifier).applySnapshot({}, {42: 1});
    await container
        .read(chatControllerProvider(target).notifier)
        .sendReply(1, 'reply');
    expect(
        container
            .read(chatControllerProvider(target))
            .requireValue
            .first
            .expiresAt,
        isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
        container
            .read(chatControllerProvider(target))
            .requireValue
            .map((m) => m.mid),
        [1]);
  });

  test('disabled expiry and unsent rows never expire', () {
    final now = DateTime.now().millisecondsSinceEpoch + 100000;
    for (final row in [
      message(1),
      message(2, seconds: 0),
      message(3, seconds: -1),
      message(-1, seconds: 1)
    ]) {
      expect(row.isExpiredAt(now), isFalse);
    }
    final row = message(4, seconds: 1, createdAt: 1000);
    expect(row.isExpiredAt(1999), isFalse);
    expect(row.isExpiredAt(2000), isTrue);
  });
}
