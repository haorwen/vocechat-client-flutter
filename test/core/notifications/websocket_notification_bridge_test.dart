import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/background/background_lifecycle.dart';
import 'package:vocechat_client/core/background/background_notifications.dart';
import 'package:vocechat_client/core/background/background_preferences.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 1, name: 'Me'));
}

class _Accounts extends AccountStore {
  @override
  Future<AccountState> build() async =>
      const AccountState(currentAccountId: 'server::1');
  void switchForTest() =>
      state = const AsyncData(AccountState(currentAccountId: 'other::1'));
}

class _Preferences extends BackgroundPreferences {
  @override
  Future<BackgroundStatus> build() async =>
      const BackgroundStatus(enabled: true, pushEnabled: true);
}

class _Users extends UserDirectory {
  @override
  Future<Map<int, UserSummary>> build() async =>
      {2: const UserSummary(uid: 2, name: 'Alice')};
}

class _Groups extends GroupDirectory {
  @override
  Future<Map<int, GroupSummary>> build() async =>
      {3: const GroupSummary(gid: 3, name: 'Project team')};
}

class _Cache implements MessageCache {
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>?> readUserDirectory() async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('unavailable');
    return [
      {'uid': 2, 'name': 'Cached Alice'}
    ];
  }

  @override
  Future<List<Map<String, dynamic>>?> readGroupDirectory() async => [
        {'gid': 3, 'name': 'Cached team'}
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _deliver = Provider<void Function(ChatMessage)>(
    (ref) => (message) => deliverBackgroundNotification(ref, message));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'foreground WS consumes stable receipt; background WS uses same key to display',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, (call) async {
      calls.add(call);
      return null;
    });
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      accountStoreProvider.overrideWith(_Accounts.new),
      backgroundPreferencesProvider.overrideWith(_Preferences.new),
      userDirectoryProvider.overrideWith(_Users.new),
      groupDirectoryProvider.overrideWith(_Groups.new),
    ]);
    // The app root keeps these auto-dispose providers subscribed in production.
    final authSub = container.listen(authControllerProvider, (_, __) {});
    final accountSub = container.listen(accountStoreProvider, (_, __) {});
    try {
      await container.read(authControllerProvider.future);
      await container.read(accountStoreProvider.future);
      await container.read(backgroundPreferencesProvider.future);
      await container.read(userDirectoryProvider.future);
      await container.read(groupDirectoryProvider.future);
      final lifecycle = container.read(androidBackgroundedProvider.notifier);
      final message = ChatMessage(
          mid: 100,
          fromUid: 2,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          target: const MessageTarget.user(uid: 1),
          detail: const MessageDetail.normal(
              contentType: 'text/plain', content: 'hello'));
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      container.read(_deliver)(message);
      await Future<void>.delayed(Duration.zero);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      container.read(_deliver)(message);
      await Future<void>.delayed(Duration.zero);
      expect(calls.length, 2);
      final foreground = calls[0].arguments as Map;
      final background = calls[1].arguments as Map;
      expect(foreground['session'], 'server::1');
      expect(foreground['mid'], 100);
      expect(foreground['target'], 'u-2');
      expect(foreground['present'], false);
      expect(background['present'], true);
      expect(background['mid'], foreground['mid']);
      expect(background['createdAt'], message.createdAt);
      expect(background['eligible'], true);
      expect(background['title'], 'Alice');
      expect(background['body'], 'hello');
      container.read(_deliver)(message.copyWith(
          mid: 101, target: const MessageTarget.group(gid: 3)));
      await Future<void>.delayed(Duration.zero);
      final group = calls.last.arguments as Map;
      expect(group['title'], 'Project team');
      expect(group['body'], 'Alice: hello');
      expect(group['target'], 'g-3');
    } finally {
      authSub.close();
      accountSub.close();
      container.dispose();
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(backgroundChannel, null);
    }
  });
  for (final scenario in ['disk', 'failure', 'account switch']) {
    test('notification names from cache: $scenario', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final cache = _Cache()..fail = scenario == 'failure';
      if (scenario == 'account switch') cache.gate = Completer<void>();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(backgroundChannel, (call) async {
        calls.add(call);
        return null;
      });
      var directoryBuilds = 0;
      final container = ProviderContainer(overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        accountStoreProvider.overrideWith(_Accounts.new),
        backgroundPreferencesProvider.overrideWith(_Preferences.new),
        messageCacheProvider.overrideWith((ref) async => cache),
        userDirectoryProvider.overrideWith(() {
          directoryBuilds++;
          return _Users();
        }),
        groupDirectoryProvider.overrideWith(() {
          directoryBuilds++;
          return _Groups();
        }),
      ]);
      final authSub = container.listen(authControllerProvider, (_, __) {});
      final accountSub = container.listen(accountStoreProvider, (_, __) {});
      try {
        await container.read(authControllerProvider.future);
        await container.read(accountStoreProvider.future);
        await container.read(backgroundPreferencesProvider.future);
        container
            .read(androidBackgroundedProvider.notifier)
            .didChangeAppLifecycleState(AppLifecycleState.paused);
        final message = ChatMessage(
            mid: 200,
            fromUid: 2,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            target: const MessageTarget.group(gid: 3),
            detail: const MessageDetail.normal(
                contentType: 'text/plain', content: 'hello'));
        container.read(_deliver)(message);
        await Future<void>.delayed(Duration.zero);
        if (scenario == 'account switch') {
          (container.read(accountStoreProvider.notifier) as _Accounts)
              .switchForTest();
          cache.gate!.complete();
          await Future<void>.delayed(Duration.zero);
          expect(calls, isEmpty);
        } else {
          final group = calls.single.arguments as Map;
          expect(group['title'], scenario == 'disk' ? 'Cached team' : '#3');
          expect(group['body'],
              scenario == 'disk' ? 'Cached Alice: hello' : '#2: hello');
          container.read(_deliver)(message.copyWith(
              mid: 201, target: const MessageTarget.user(uid: 1)));
          await Future<void>.delayed(Duration.zero);
          expect((calls.last.arguments as Map)['title'],
              scenario == 'disk' ? 'Cached Alice' : '#2');
        }
        expect(directoryBuilds, 0); // no notification-only roster fetches
      } finally {
        authSub.close();
        accountSub.close();
        container.dispose();
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(backgroundChannel, null);
      }
    });
  }
}
