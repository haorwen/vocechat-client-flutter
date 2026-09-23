import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/message_dispatcher.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

class _Cache implements MessageCache {
  List<Map<String, dynamic>>? users;
  @override
  Future<List<Map<String, dynamic>>?> readUserDirectory() async => users;
  @override
  Future<void> writeUserDirectory(List<Map<String, dynamic>> users) async {
    this.users = users;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _self = {'uid': 1, 'name': '自己'};
const _member = {'uid': 42, 'name': '群友', 'avatar_updated_at': 123};
Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
      ({
        ProviderContainer container,
        _Cache cache,
        StreamController<ChatEvent> events,
        Completer<void> requested
      })> setup({
    List<Map<String, dynamic>>? cached,
    Completer<void>? gate,
  }) async {
    final cache = _Cache()..users = cached;
    final events = StreamController<ChatEvent>();
    final requested = Completer<void>();
    final dio = Dio();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      expect(options.path, '/api/user');
      requested.complete();
      if (gate != null) await gate.future;
      handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: [_self]));
    }));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWith((ref) => dio),
      messageCacheProvider.overrideWith((ref) async => cache),
      sseEventsProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(() async {
      container.dispose();
      await events.close();
      dio.close();
    });
    container.read(messageDispatcherProvider);
    await _flush();
    return (
      container: container,
      cache: cache,
      events: events,
      requested: requested
    );
  }

  test('websocket snapshot restores non-contact names and persists them',
      () async {
    final s = await setup();
    await s.container.read(userDirectoryProvider.future);
    expect(s.container.read(userDirectoryProvider).requireValue.keys, [1]);
    s.events.add(parseSseEvent(
        'users_snapshot',
        jsonEncode({
          'version': 2,
          'users': [_self, _member],
        })));
    await _flush();
    expect(
        s.container.read(userDirectoryProvider).requireValue[42]?.name, '群友');
    expect(s.cache.users, contains(equals(_member)));
  });

  test('snapshot received during cold start survives the REST response',
      () async {
    final gate = Completer<void>();
    final s = await setup(gate: gate);
    s.events.add(
        const ChatEvent.usersSnapshot(users: [_self, _member], version: 2));
    await s.requested.future;
    gate.complete();
    await _flush();
    expect(
        s.container.read(userDirectoryProvider).requireValue[42]?.name, '群友');
  });

  test('late REST refresh cannot replace a newer snapshot', () async {
    final gate = Completer<void>();
    final s = await setup(cached: [_self], gate: gate);
    await s.container.read(userDirectoryProvider.future);
    await s.requested.future;
    s.events.add(const ChatEvent.usersSnapshot(users: [_member], version: 2));
    await _flush();
    gate.complete();
    await _flush();
    final users = s.container.read(userDirectoryProvider).requireValue;
    expect(users.keys, [42]);
    expect(s.cache.users, [_member]);
  });

  test('restricted REST refresh preserves cached non-contact members',
      () async {
    final s = await setup(cached: [_self, _member]);
    await s.container.read(userDirectoryProvider.future);
    await _flush();
    expect(
        s.container.read(userDirectoryProvider).requireValue[42]?.name, '群友');
  });

  test(
      'user logs update names, preserve partial fields and remove deleted users',
      () async {
    final s = await setup();
    await s.container.read(userDirectoryProvider.future);
    s.events.add(
        const ChatEvent.usersSnapshot(users: [_self, _member], version: 2));
    s.events.add(parseSseEvent(
        'users_log',
        jsonEncode({
          'logs': [
            {
              'uid': 42,
              'action': 'update',
              'name': '新名字',
              'avatar_updated_at': null
            },
            {'uid': 9, 'action': 'create', 'name': '新成员'},
            {'uid': 1, 'action': 'delete'},
          ]
        })));
    await _flush();
    final users = s.container.read(userDirectoryProvider).requireValue;
    expect(users[42]?.name, '新名字');
    expect(users[42]?.avatarUpdatedAt, 123);
    expect(users[9]?.name, '新成员');
    expect(users.containsKey(1), isFalse);
    expect(s.cache.users!.map((u) => u['uid']), unorderedEquals([42, 9]));
  });
}
