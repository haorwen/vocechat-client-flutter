import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/features/channels/application/conversation_providers.dart';
import 'package:vocechat_client/features/messages/application/message_dispatcher.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

class _Cache implements MessageCache {
  final firstWrite = Completer<void>();
  final writes = <({int mid, bool advance})>[];

  @override
  Future<void> appendOne(MessageTarget target, ChatMessage msg,
      {bool advanceCursor = false}) async {
    writes.add((mid: msg.mid, advance: advanceCursor));
    if (writes.length == 1) await firstWrite.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Conversations extends Conversations {
  @override
  Future<List<ConversationItem>> build() async => [];
  @override
  void applyIncomingMessage(ChatMessage msg) {}
}

ChatEvent _message(int mid) => ChatEvent.chat(
      message: ChatMessage(
        mid: mid,
        fromUid: 2,
        createdAt: 1000,
        target: const MessageTarget.group(gid: 42),
        detail: const MessageDetail.normal(
            contentType: 'text/plain', content: 'message'),
      ),
    );

Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disk failures cannot let later messages acknowledge a missing gap',
      () async {
    final events = StreamController<ChatEvent>.broadcast();
    final cache = _Cache();
    final container = ProviderContainer(overrides: [
      sseEventsProvider.overrideWith((ref) => events.stream),
      messageCacheProvider.overrideWith((ref) async => cache),
      conversationsProvider.overrideWith(_Conversations.new),
    ]);
    addTearDown(container.dispose);
    addTearDown(events.close);
    await container.read(messageCacheProvider.future);
    container.read(messageDispatcherProvider);
    events.add(const ChatEvent.connectionOpened());
    events.add(_message(101));
    events.add(_message(102));
    await _flush();
    expect(cache.writes, [(mid: 101, advance: true)]);
    cache.firstWrite.completeError(StateError('disk temporarily unavailable'));
    await _flush();
    expect(cache.writes.last, (mid: 102, advance: false));
    // A new stream replays the missing row before advancing again.
    events.add(const ChatEvent.connectionOpened());
    events.add(_message(101));
    events.add(_message(102));
    await _flush();
    expect(cache.writes.skip(2),
        [(mid: 101, advance: true), (mid: 102, advance: true)]);
  });
}
