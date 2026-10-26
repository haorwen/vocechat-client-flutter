import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/message_dispatcher.dart';
import 'package:vocechat_client/features/messages/application/burn_after_read_provider.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

const _group = {
  'gid': 42,
  'name': 'Community',
  'description': 'A complete introduction',
  'pinned_messages': <Map<String, dynamic>>[],
};

Map<String, dynamic> _pin(int mid, String content) => {
      'mid': mid,
      'content': content,
      'content_type': 'text/plain',
      'created_by': 8,
      'created_at': mid,
    };

class _Cache implements MessageCache {
  List<Map<String, dynamic>> groups = [_group];
  @override
  Future<List<Map<String, dynamic>>?> readGroupDirectory() async => groups;
  @override
  Future<void> writeGroupDirectory(List<Map<String, dynamic>> groups) async {
    this.groups = groups;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
        StreamController<ChatEvent> events
      })> setup({Completer<void>? refreshGate}) async {
    final cache = _Cache();
    final events = StreamController<ChatEvent>();
    final dio = Dio();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      expect(options.path, '/api/group');
      if (refreshGate != null) await refreshGate.future;
      handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: [_group]));
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
    await container.read(groupDirectoryProvider.future);
    await _flush();
    return (container: container, cache: cache, events: events);
  }

  test('description survives caching and copying a group for pin changes', () {
    final group = GroupSummary.fromJson(_group).copyWith(pinnedMessages: []);
    expect(GroupSummary.fromJson(group.toJson()).description,
        'A complete introduction');
  });

  test('remote pin, edit and unpin events update the directory and cache',
      () async {
    final s = await setup();
    void emit(int mid, Map<String, dynamic>? message) =>
        s.events.add(parseSseEvent('pinned_message_updated',
            jsonEncode({'gid': 42, 'mid': mid, 'msg': message})));
    emit(10, _pin(10, 'First pin'));
    emit(20, _pin(20, 'Second pin'));
    await _flush();
    var group = s.container.read(groupDirectoryProvider).requireValue[42]!;
    expect(group.pinnedMessages.map((p) => p.mid), [10, 20]);
    emit(10, _pin(10, 'Edited pin'));
    await _flush();
    group = s.container.read(groupDirectoryProvider).requireValue[42]!;
    expect(group.pinnedMessages.where((p) => p.mid == 10).single.content,
        'Edited pin');
    emit(10, null);
    emit(20, null);
    await _flush();
    group = s.container.read(groupDirectoryProvider).requireValue[42]!;
    expect(group.pinnedMessages, isEmpty);
    expect(s.cache.groups.single['pinned_messages'], isEmpty);
    expect(s.cache.groups.single['description'], 'A complete introduction');
  });

  test('remote introduction and pins survive a late REST response', () async {
    final gate = Completer<void>();
    final s = await setup(refreshGate: gate);
    s.events.add(const ChatEvent.groupChanged(data: {
      'gid': 42,
      'name': 'Renamed community',
      'description': 'Updated introduction',
      'owner': null,
    }));
    s.events.add(parseSseEvent(
        'pinned_message_updated',
        jsonEncode({
          'gid': 42,
          'mid': 10,
          'msg': _pin(10, 'New pin'),
        })));
    await _flush();
    gate.complete();
    await _flush();
    final group = s.container.read(groupDirectoryProvider).requireValue[42]!;
    expect(group.name, 'Renamed community');
    expect(group.description, 'Updated introduction');
    expect(group.pinnedMessages.single.mid, 10);
    expect(s.cache.groups.single['description'], 'Updated introduction');
  });
  test('channel auto-delete changes sync through SSE and survive pin updates',
      () async {
    final s = await setup();
    await s.container.read(groupDirectoryProvider.future);
    s.events.add(parseSseEvent(
        'group_changed',
        jsonEncode({
          'gid': 42,
          'auto_delete_after': 2592000,
        })));
    await _flush();
    expect(
        s.container
            .read(groupDirectoryProvider)
            .requireValue[42]
            ?.autoDeleteAfter,
        2592000);
    s.container.read(groupDirectoryProvider.notifier).applyPinned(42, []);
    expect(
        s.container
            .read(groupDirectoryProvider)
            .requireValue[42]
            ?.autoDeleteAfter,
        2592000);
    expect(s.cache.groups.single['auto_delete_after'], 2592000);
    await s.container
        .read(groupDirectoryProvider.notifier)
        .applyGroupUpdate(_group, replace: true);
    expect(
        s.container
            .read(groupDirectoryProvider)
            .requireValue[42]
            ?.autoDeleteAfter,
        isNull);
  });

  test('empty supported settings differ from unsupported server snapshots',
      () async {
    final s = await setup();
    s.events.add(parseSseEvent('user_settings', jsonEncode({})));
    await _flush();
    expect(s.container.read(burnAfterReadProvider).supportsGroups, isFalse);
    expect(s.container.read(burnAfterReadProvider).supportsUsers, isFalse);
    s.events.add(parseSseEvent(
        'user_settings',
        jsonEncode({
          'burn_after_reading_groups': [],
          'burn_after_reading_users': [],
        })));
    await _flush();
    expect(s.container.read(burnAfterReadProvider).supportsGroups, isTrue);
    expect(s.container.read(burnAfterReadProvider).supportsUsers, isTrue);
  });
}
