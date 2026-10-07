import 'dart:async';

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

const _target = MessageTarget.group(gid: 42);
final _provider = chatControllerProvider(_target);

ChatMessage _message(int mid,
        {String content = 'history',
        int fromUid = 8,
        int createdAt = 1000,
        int? localId,
        int? localOrderAnchor}) =>
    ChatMessage(
      mid: mid,
      fromUid: fromUid,
      createdAt: createdAt,
      localOrderAnchor: localOrderAnchor,
      target: _target,
      detail: MessageDetail.normal(
          contentType: 'text/plain',
          content: content,
          properties: localId == null ? null : {'local_id': localId}),
    );

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 7, name: 'Sender'));
}

class _Cache implements MessageCache {
  _Cache(this.rows, {this.readGate});
  List<ChatMessage> rows;
  final Completer<List<ChatMessage>>? readGate;
  final deleted = <int>[];
  @override
  Future<List<ChatMessage>> read(MessageTarget target,
          {int limit = 500}) async =>
      readGate == null ? List.of(rows) : await readGate!.future;
  @override
  void scheduleWrite(MessageTarget target, List<ChatMessage> messages) {
    rows = List.of(messages);
  }

  @override
  Future<void> setCursor(int mid) async {}
  @override
  Future<void> deleteMid(MessageTarget target, int mid) async {
    deleted.add(mid);
    rows.removeWhere((m) => m.mid == mid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends MessageApi {
  _Api() : super(Dio());
  final requests = <({int? before, Completer<List<ChatMessage>> result})>[];
  Completer<int>? sendResult;
  bool holdEachSend = false;
  final sends = <({int? localId, Completer<int> result})>[];
  @override
  Future<List<ChatMessage>> getHistory(MessageTarget target,
      {int? beforeMid, int limit = 30}) {
    final result = Completer<List<ChatMessage>>();
    requests.add((before: beforeMid, result: result));
    return result.future;
  }

  @override
  Future<int> sendText(MessageTarget target, String text,
      {List<int>? mentions, int? localId}) async {
    if (holdEachSend) {
      final result = Completer<int>();
      sends.add((localId: localId, result: result));
      return result.future;
    }
    return sendResult == null ? 100 : await sendResult!.future;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> setup(_Cache cache, _Api api,
      {bool finishHistory = true}) async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      messageCacheProvider.overrideWith((ref) async => cache),
      messageApiProvider.overrideWith((ref) => api),
      sseEventsProvider.overrideWith((ref) => const Stream<ChatEvent>.empty()),
    ]);
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, __) {});
    await container.read(authControllerProvider.future);
    container.read(_provider);
    await _flush();
    if (finishHistory) {
      api.requests.first.result.complete([]);
      await container.read(_provider.future);
      await _flush();
    }
    return container;
  }

  test('slow pagination retains sends, incoming messages, edits and deletes',
      () async {
    final api = _Api();
    final cache = _Cache([_message(20), _message(19)]);
    final container = await setup(cache, api);
    final controller = container.read(_provider.notifier);
    final loading = controller.loadMore();
    await controller.sendText('sent while paging');
    controller.applyIncomingMessage(_message(101, content: 'live'));
    controller.applyEditEcho(20, 'edited while paging', 'text/plain');
    controller.applyDeleteEcho(19);
    await _flush();
    api.requests.last.result.complete([_message(18)]);
    await loading;
    final rows = container.read(_provider).requireValue;
    expect(rows.map((m) => m.mid), [101, 100, 20, 18]);
    expect(rows.firstWhere((m) => m.mid == 20).displayContent,
        'edited while paging');
    expect(cache.rows, rows);
    // Replay must not be dropped by an out-of-sync dedup set.
    controller.applyIncomingMessage(_message(101, content: 'live'));
    await _flush();
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [101, 100, 20, 18]);
  });

  test('pagination coalesces concurrent requests and stops at an empty page',
      () async {
    final api = _Api();
    final container = await setup(_Cache([_message(20)]), api);
    final controller = container.read(_provider.notifier);
    final loading = controller.loadMore();
    await controller.loadMore();
    expect(api.requests.length, 2);
    api.requests.last.result.complete([]);
    await loading;
    await controller.loadMore();
    expect(api.requests.length, 2);
  });

  test('failed pagination can retry and expired-only pages advance cursor',
      () async {
    final api = _Api();
    final container = await setup(_Cache([_message(20)]), api);
    final controller = container.read(_provider.notifier);
    var loading = controller.loadMore();
    api.requests.last.result.completeError(StateError('offline'));
    await loading;
    loading = controller.loadMore();
    expect(api.requests.length, 3);
    api.requests.last.result.complete([
      _message(19).copyWith(
          detail: const MessageDetail.normal(
              contentType: 'text/plain', content: 'expired', expiresIn: 1)),
    ]);
    await loading;
    expect(container.read(_provider).requireValue.map((m) => m.mid), [20]);
    loading = controller.loadMore();
    expect(api.requests.last.before, 19);
    api.requests.last.result.complete([_message(18)]);
    await loading;
    expect(container.read(_provider).requireValue.map((m) => m.mid), [20, 18]);
  });

  test('initial history retains optimistic send and live rows while awaiting',
      () async {
    final api = _Api()..sendResult = Completer<int>();
    final container = await setup(_Cache([]), api, finishHistory: false);
    final controller = container.read(_provider.notifier);
    final sending = controller.sendText('new message');
    controller.applyIncomingMessage(_message(101, content: 'live'));
    await _flush();
    api.requests.first.result.complete([_message(20)]);
    await _flush();
    expect(container.read(_provider).requireValue.map((m) => m.displayContent),
        ['new message', 'live', 'history']);
    api.sendResult!.complete(100);
    await sending;
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [101, 100, 20]);
  });

  test('history and repeated live echoes confirm one optimistic row', () async {
    final api = _Api()..sendResult = Completer<int>();
    final container =
        await setup(_Cache([_message(20)]), api, finishHistory: false);
    final controller = container.read(_provider.notifier);
    final sending = controller.sendText('new message');
    final echo = _message(100, content: 'new message', fromUid: 7);
    api.requests.first.result.complete([echo]);
    await _flush();
    api.sendResult!.complete(100);
    await sending;
    var notifications = 0;
    final subscription =
        container.listen(_provider, (_, __) => notifications++);
    addTearDown(subscription.close);
    controller.applyIncomingMessage(echo);
    controller.applyIncomingMessage(echo);
    await _flush();
    expect(container.read(_provider).requireValue.map((m) => m.mid), [100, 20]);
    expect(controller.statusFor(100), MessageSendStatus.sent);
    expect(notifications, 0);
  });

  test('identical sends retain separate identities with out-of-order echoes',
      () async {
    final api = _Api()..holdEachSend = true;
    final container = await setup(_Cache([_message(20)]), api);
    final controller = container.read(_provider.notifier);
    final first = controller.sendText('same text');
    final second = controller.sendText('same text');
    expect(api.sends[0].localId, isNotNull);
    expect(api.sends[0].localId, isNot(api.sends[1].localId));
    controller.applyIncomingMessage(_message(101,
        content: 'same text', fromUid: 7, localId: api.sends[1].localId));
    controller.applyIncomingMessage(_message(100,
        content: 'same text', fromUid: 7, localId: api.sends[0].localId));
    await _flush();
    api.sends[0].result.complete(100);
    api.sends[1].result.complete(101);
    await Future.wait([first, second]);
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [101, 100, 20]);
  });

  test('same text from another device cannot confirm a local send', () async {
    final api = _Api()..sendResult = Completer<int>();
    final container = await setup(_Cache([_message(20)]), api);
    final controller = container.read(_provider.notifier);
    final sending = controller.sendText('same text');
    controller
        .applyIncomingMessage(_message(99, content: 'same text', fromUid: 7));
    await _flush();
    expect(container.read(_provider).requireValue.first.mid, isNegative);
    api.sendResult!.complete(100);
    await sending;
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [100, 99, 20]);
  });

  test('an older identical history message cannot consume a new send',
      () async {
    final api = _Api()..sendResult = Completer<int>();
    final container =
        await setup(_Cache([_message(20)]), api, finishHistory: false);
    final controller = container.read(_provider.notifier);
    final sending = controller.sendText('same text');
    api.requests.first.result.complete([
      _message(19, content: 'same text', fromUid: 7),
    ]);
    await _flush();
    expect(container.read(_provider).requireValue.first.mid, isNegative);
    api.sendResult!.complete(100);
    await sending;
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [100, 20, 19]);
  });

  test('old account history and sends cannot overwrite a rebuilt chat',
      () async {
    final api = _Api()..sendResult = Completer<int>();
    final cache = _Cache([_message(20)]);
    final container = await setup(cache, api, finishHistory: false);
    final controller = container.read(_provider.notifier);
    final sending = controller.sendText('old account send');
    final loading = controller.loadMore();
    final oldBackground = api.requests[0].result;
    final oldPage = api.requests[1].result;

    cache.rows = [_message(200, content: 'new account')];
    container.invalidate(messageCacheProvider);
    await _flush();
    await container.read(_provider.future);
    await _flush();
    final newBackground = api.requests[2].result;
    newBackground.complete([]);
    await _flush();
    final newLoading = controller.loadMore();
    final newPage = api.requests[3].result;

    oldBackground.complete([_message(21, content: 'old background')]);
    oldPage.complete([_message(19, content: 'old page')]);
    api.sendResult!.complete(100);
    await Future.wait([sending, loading]);
    await _flush();
    expect(container.read(_provider).requireValue.map((m) => m.mid), [200]);
    expect(cache.rows.map((m) => m.mid), [200]);
    await controller.loadMore();
    expect(api.requests.length, 4,
        reason: 'old request cannot release new lock');
    newPage.complete([]);
    await newLoading;
  });

  test('HTTP acknowledgement publishes the sent status with the confirmed row',
      () async {
    final api = _Api();
    final container = await setup(_Cache([_message(20)]), api);
    final controller = container.read(_provider.notifier);
    MessageSendStatus? publishedStatus;
    final subscription = container.listen(_provider, (_, next) {
      if (next.valueOrNull?.any((m) => m.mid == 100) ?? false) {
        publishedStatus = controller.statusFor(100);
      }
    });
    addTearDown(subscription.close);
    await controller.sendText('new message');
    expect(publishedStatus, MessageSendStatus.sent);
  });

  test('failed send keeps its place when cached chat is restored', () async {
    final api = _Api()..holdEachSend = true;
    final cache = _Cache([_message(20)]);
    final container = await setup(cache, api);
    final controller = container.read(_provider.notifier);
    final sending = controller.sendText('failed while offline');
    final tempMid = container.read(_provider).requireValue.first.mid;
    api.sends.single.result.completeError(StateError('offline'));
    await sending;
    expect(controller.statusFor(tempMid), MessageSendStatus.failed);
    expect(cache.rows.firstWhere((m) => m.mid == tempMid).localOrderAnchor, 20);

    controller.applyIncomingMessage(_message(101, content: 'after reconnect'));
    await _flush();
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [101, tempMid, 20]);

    // SQLite restores JSON payloads after a controller or app restart.
    cache.rows =
        cache.rows.map((m) => ChatMessage.fromJson(m.toJson())).toList();
    container.invalidate(_provider);
    await container.read(_provider.future);
    await _flush();
    api.requests.last.result.complete([]);
    await _flush();
    final restored = container.read(_provider.notifier);
    expect(restored.statusFor(tempMid), MessageSendStatus.failed);
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [101, tempMid, 20]);

    restored
        .applyIncomingMessage(_message(102, content: 'another new message'));
    await _flush();
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [102, 101, tempMid, 20]);
  });

  test('local ordering anchor round-trips through cached JSON', () {
    final local = _message(-44,
        content: 'failed', fromUid: 7, localId: 44, localOrderAnchor: 20);
    final json = local.toJson();
    expect(json['local_order_anchor'], 20);
    expect(ChatMessage.fromJson(json), local);

    final noPreviousMessage = local.copyWith(localOrderAnchor: 0);
    expect(
        ChatMessage.fromJson(noPreviousMessage.toJson()).localOrderAnchor, 0);
    json.remove('local_order_anchor');
    expect(ChatMessage.fromJson(json).localOrderAnchor, isNull);
  });

  test('legacy cached local row restores as failed at its attempted send time',
      () async {
    final cache = _Cache([
      _message(102, createdAt: 5000),
      _message(101, createdAt: 3000),
      _message(20, createdAt: 2000),
      _message(19, createdAt: 2400),
      _message(-44,
          content: 'legacy failed', fromUid: 7, createdAt: 2500, localId: 44),
    ]);
    final container = await setup(cache, _Api());
    final controller = container.read(_provider.notifier);
    expect(controller.statusFor(-44), MessageSendStatus.failed);
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [102, 101, -44, 20, 19]);
    expect(cache.rows.firstWhere((m) => m.mid == -44).localOrderAnchor, 20);

    // Server mids still define order when an incoming timestamp is skewed.
    controller.applyIncomingMessage(_message(103, createdAt: 500));
    await _flush();
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [103, 102, 101, -44, 20, 19]);
  });

  test('successful retry deletes the persisted temporary row', () async {
    final api = _Api()..holdEachSend = true;
    final cache = _Cache([_message(20)]);
    final container = await setup(cache, api);
    final controller = container.read(_provider.notifier);
    final sending = controller.sendText('retry me');
    final tempMid = container.read(_provider).requireValue.first.mid;
    api.sends.single.result.completeError(StateError('offline'));
    await sending;
    controller.applyIncomingMessage(_message(101));
    await _flush();

    final retry = controller.retrySend(tempMid);
    expect(api.sends, hasLength(2));
    expect(api.sends.last.localId, api.sends.first.localId);
    api.sends.last.result.complete(100);
    await retry;
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [101, 100, 20]);
    expect(controller.statusFor(tempMid), isNull);
    expect(controller.statusFor(100), MessageSendStatus.sent);
    expect(cache.deleted, contains(tempMid),
        reason:
            'cache writes upsert rows, so a sent placeholder needs deletion');
    expect(cache.rows.any((m) => m.mid == tempMid), isFalse);
  });

  for (final source in ['history', 'SSE']) {
    test('$source confirmation removes a restored failed row from cache',
        () async {
      final api = _Api();
      final cache = _Cache([
        _message(-44,
            content: 'delivered before disconnect',
            fromUid: 7,
            localId: 44,
            localOrderAnchor: 20),
        _message(20),
      ]);
      final container = await setup(cache, api, finishHistory: false);
      await container.read(_provider.future);
      final controller = container.read(_provider.notifier);
      expect(controller.statusFor(-44), MessageSendStatus.failed);
      final echo = _message(100,
          content: 'delivered before disconnect', fromUid: 7, localId: 44);
      if (source == 'history') {
        api.requests.single.result.complete([echo]);
      } else {
        api.requests.single.result.complete([]);
        controller.applyIncomingMessage(echo);
      }
      await _flush();
      expect(
          container.read(_provider).requireValue.map((m) => m.mid), [100, 20]);
      expect(controller.statusFor(-44), isNull);
      expect(controller.statusFor(100), MessageSendStatus.sent);
      expect(cache.deleted, contains(-44));

      container.invalidate(_provider);
      await container.read(_provider.future);
      await _flush();
      api.requests.last.result.complete([]);
      await _flush();
      expect(
          container.read(_provider).requireValue.map((m) => m.mid), [100, 20]);
    });
  }

  test('cache restore removes an already confirmed temporary row', () async {
    final cache = _Cache([
      _message(100, content: 'delivered', fromUid: 7, localId: 44),
      _message(20),
      _message(-44,
          content: 'delivered', fromUid: 7, localId: 44, localOrderAnchor: 20),
    ]);
    final container = await setup(cache, _Api());
    expect(container.read(_provider).requireValue.map((m) => m.mid), [100, 20]);
    expect(container.read(_provider.notifier).statusFor(-44), isNull);
    expect(cache.deleted, contains(-44));
    expect(cache.rows.any((m) => m.mid == -44), isFalse);
  });

  test('cache restore retains live sends while removing a confirmed old row',
      () async {
    final cachedRows = [
      _message(-44,
          content: 'delivered before disconnect',
          fromUid: 7,
          localId: 44,
          localOrderAnchor: 20),
      _message(20),
    ];
    final readGate = Completer<List<ChatMessage>>();
    final cache = _Cache(List.of(cachedRows), readGate: readGate);
    final api = _Api()..holdEachSend = true;
    final container = await setup(cache, api, finishHistory: false);
    final controller = container.read(_provider.notifier);
    final sending = controller.sendText('new send while restoring');
    final newTempMid = container.read(_provider).requireValue.first.mid;
    controller.applyIncomingMessage(_message(100,
        content: 'delivered before disconnect', fromUid: 7, localId: 44));
    await _flush();

    readGate.complete(cachedRows);
    await _flush();
    await container.read(_provider.future);
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [newTempMid, 100, 20]);
    expect(controller.statusFor(newTempMid), MessageSendStatus.sending);
    expect(controller.statusFor(-44), isNull);
    expect(cache.deleted, contains(-44));

    api.sends.single.result.complete(101);
    await sending;
    api.requests.single.result.complete([]);
    await _flush();
    expect(container.read(_provider).requireValue.map((m) => m.mid),
        [101, 100, 20]);
    expect(cache.rows.any((m) => m.mid < 0), isFalse);
  });
}
