import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/channels/application/conversation_providers.dart';
import 'package:vocechat_client/features/messages/application/read_index_provider.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

typedef _ReadBatch = ({Map<int, int> users, Map<int, int> groups});

class _MemoryCache implements MessageCache {
  Map<int, int> users = {};
  Map<int, int> groups = {};
  Map<int, int> pendingUsers = {};
  Map<int, int> pendingGroups = {};
  Completer<void>? readGate;

  Future<Map<int, int>> _load(Map<int, int> values) async {
    final snapshot = Map<int, int>.of(values);
    if (readGate case final gate?) await gate.future;
    return snapshot;
  }

  @override
  Future<Map<int, int>> readReadIndexUsers() => _load(users);
  @override
  Future<Map<int, int>> readReadIndexGroups() => _load(groups);
  @override
  Future<Map<int, int>> readPendingReadIndexUsers() => _load(pendingUsers);
  @override
  Future<Map<int, int>> readPendingReadIndexGroups() => _load(pendingGroups);
  @override
  Future<void> writeReadIndexUsers(Map<int, int> values) async {
    users = Map.of(values);
  }

  @override
  Future<void> writeReadIndexGroups(Map<int, int> values) async {
    groups = Map.of(values);
  }

  @override
  Future<void> writePendingReadIndexUsers(Map<int, int> values) async {
    pendingUsers = Map.of(values);
  }

  @override
  Future<void> writePendingReadIndexGroups(Map<int, int> values) async {
    pendingGroups = Map.of(values);
  }

  @override
  Future<UnreadInfo> unreadSince(MessageTarget target,
          {required int sinceMid,
          required int excludeFromUid,
          required int mentionUid}) async =>
      (count: sinceMid < 20 ? 3 : 0, mention: sinceMid < 20);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadApi implements MessageApi {
  final calls = <_ReadBatch>[];
  Future<void> Function()? onRead;

  @override
  Future<void> readMessage({
    List<({int uid, int mid})>? users,
    List<({int gid, int mid})>? groups,
  }) async {
    calls.add((
      users: {for (final u in users ?? <({int uid, int mid})>[]) u.uid: u.mid},
      groups: {
        for (final g in groups ?? <({int gid, int mid})>[]) g.gid: g.mid
      },
    ));
    await onRead?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Conversations extends Conversations {
  @override
  Future<List<ConversationItem>> build() async => const [
        ConversationItem(
          key: GroupConversationKey(42),
          name: 'group',
          isChannel: true,
          lastMid: 20,
        ),
      ];
}

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}

void main() {
  ProviderContainer create(_MemoryCache cache, _ReadApi api) {
    final container = ProviderContainer(overrides: [
      messageCacheProvider.overrideWith((ref) async => cache),
      messageApiProvider.overrideWith((ref) => api),
      authControllerProvider.overrideWith(_Auth.new),
      conversationsProvider.overrideWith(_Conversations.new),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('local reads are immediate while server writes are coalesced',
      (tester) async {
    final cache = _MemoryCache();
    final api = _ReadApi();
    final container = create(cache, api);
    await container.read(readIndexProvider.future);
    final reads = container.read(readIndexProvider.notifier);

    reads.setUser(7, 20);
    reads.setUser(7, 30);
    reads.setGroup(42, 40);
    expect(container.read(readIndexProvider).requireValue.readUser(7), 30);
    expect(container.read(readIndexProvider).requireValue.readGroup(42), 40);
    expect(api.calls, isEmpty);
    await tester.pump();
    expect(cache.pendingUsers, {7: 30});
    expect(cache.pendingGroups, {42: 40});

    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls.length, 1);
    expect(api.calls.single.users, {7: 30});
    expect(api.calls.single.groups, {42: 40});
    expect(cache.pendingUsers, isEmpty);
    expect(cache.pendingGroups, isEmpty);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('failed sync keeps badges read and retries the newest marker',
      (tester) async {
    final cache = _MemoryCache();
    final api = _ReadApi()..onRead = () async => throw StateError('offline');
    final container = create(cache, api);
    await container.read(readIndexProvider.future);
    final reads = container.read(readIndexProvider.notifier);
    reads.setGroup(42, 20);
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls.length, 1);
    expect(container.read(readIndexProvider).requireValue.readGroup(42), 20);
    expect(cache.pendingGroups, {42: 20});

    reads.setGroup(42, 30);
    api.onRead = null;
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls.last.groups, {42: 30});
    expect(cache.pendingGroups, isEmpty);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('in-flight acknowledgement does not drop a newer queued read',
      (tester) async {
    final cache = _MemoryCache();
    final firstResponse = Completer<void>();
    final api = _ReadApi()..onRead = () => firstResponse.future;
    final container = create(cache, api);
    await container.read(readIndexProvider.future);
    final reads = container.read(readIndexProvider.notifier);
    reads.setUser(7, 20);
    await tester.pump(const Duration(milliseconds: 500));
    reads.setUser(7, 30);
    firstResponse.complete();
    await tester.pump();
    expect(cache.pendingUsers, {7: 30});

    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls.map((c) => c.users), [
      {7: 20},
      {7: 30}
    ]);
    expect(cache.pendingUsers, isEmpty);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('stale snapshots and deltas never roll back local reads',
      (tester) async {
    final cache = _MemoryCache();
    final api = _ReadApi();
    final container = create(cache, api);
    await container.read(readIndexProvider.future);
    final reads = container.read(readIndexProvider.notifier);
    reads.setUser(7, 30);
    reads.setGroup(42, 40);
    reads.applySnapshot({7: 10}, {});
    reads.applyDelta({7: 20}, {42: 30});
    expect(container.read(readIndexProvider).requireValue.readUser(7), 30);
    expect(container.read(readIndexProvider).requireValue.readGroup(42), 40);

    reads.applyDelta({7: 30}, {42: 50});
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls, isEmpty);
    expect(cache.pendingUsers, isEmpty);
    expect(cache.pendingGroups, isEmpty);
    expect(cache.groups, {42: 50});
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'reads and server settings arriving during disk load are retained',
      (tester) async {
    final gate = Completer<void>();
    final cache = _MemoryCache()
      ..users = {7: 10}
      ..groups = {42: 5}
      ..readGate = gate;
    final api = _ReadApi();
    final container = create(cache, api);
    final loaded = container.read(readIndexProvider.future);
    await tester.pump();
    final reads = container.read(readIndexProvider.notifier);
    reads.setUser(7, 30);
    reads.applySnapshot({8: 40}, {42: 20});
    gate.complete();
    await loaded;
    await tester.pump();
    expect(
        container.read(readIndexProvider).requireValue.users, {7: 30, 8: 40});
    expect(container.read(readIndexProvider).requireValue.groups, {42: 20});
    expect(cache.pendingUsers, {7: 30});
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'a restarted provider resumes persisted reads without resending baselines',
      (tester) async {
    final cache = _MemoryCache()
      ..users = {7: 30, 8: 40}
      ..pendingUsers = {7: 30};
    final api = _ReadApi();
    final container = create(cache, api);
    await container.read(readIndexProvider.future);
    expect(container.read(readIndexProvider).requireValue.readUser(7), 30);
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls.single.users, {7: 30});
    expect(cache.pendingUsers, isEmpty);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('viewing a baseline marker still reports an explicit read',
      (tester) async {
    final cache = _MemoryCache();
    final api = _ReadApi();
    final container = create(cache, api);
    await container.read(readIndexProvider.future);
    final reads = container.read(readIndexProvider.notifier);
    reads.baselineUser(7, 30);
    reads.baselineGroup(42, 40);
    reads.setUser(7, -1);
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls, isEmpty);
    reads.setUser(7, 30);
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls.single.users, {7: 30});
    expect(api.calls.single.groups, isEmpty);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('account cache rebuild drops old state and queued requests',
      (tester) async {
    final oldCache = _MemoryCache();
    final api = _ReadApi();
    final container = create(oldCache, api);
    await container.read(readIndexProvider.future);
    container.read(readIndexProvider.notifier).setUser(7, 30);
    await tester.pump();
    final newCache = _MemoryCache()..users = {7: 5};
    container.updateOverrides([
      messageCacheProvider.overrideWith((ref) async => newCache),
      messageApiProvider.overrideWith((ref) => api),
      authControllerProvider.overrideWith(_Auth.new),
      conversationsProvider.overrideWith(_Conversations.new),
    ]);
    container.invalidate(messageCacheProvider);
    await tester.pump();
    await container.read(readIndexProvider.future);
    expect(container.read(readIndexProvider).requireValue.readUser(7), 5);
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls, isEmpty);
    expect(oldCache.pendingUsers, {7: 30});
    expect(newCache.pendingUsers, isEmpty);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('conversation unread count and mentions follow the local marker',
      (tester) async {
    final cache = _MemoryCache()..groups = {42: 10};
    final api = _ReadApi()..onRead = () async => throw StateError('offline');
    final container = create(cache, api);
    await container.read(authControllerProvider.future);
    await container.read(conversationsProvider.future);
    const key = GroupConversationKey(42);
    final subscription = container.listen(unreadInfoProvider(key), (_, __) {});
    addTearDown(subscription.close);
    expect(await container.read(unreadInfoProvider(key).future),
        (count: 3, mention: true));

    container.read(readIndexProvider.notifier).setGroup(42, 20);
    await tester.pump();
    expect(await container.read(unreadInfoProvider(key).future),
        (count: 0, mention: false));
    expect(api.calls, isEmpty);
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
