import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/notifications/fcm_service.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/data/auth_api.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';

class Messaging extends Fake implements FirebaseMessaging {
  String? apns = 'apns';
  String? token = 'cached-token';
  int tokenReads = 0;
  Future<String?>? tokenResult;
  final refreshes = StreamController<String>.broadcast();
  final permission = Completer<NotificationSettings>();
  (bool, bool, bool)? presentation;

  @override
  Future<String?> getAPNSToken() async => apns;
  @override
  Future<String?> getToken({String? vapidKey}) {
    tokenReads++;
    return tokenResult ?? Future.value(token);
  }

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {
    presentation = (alert, badge, sound);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #requestPermission) return permission.future;
    return super.noSuchMethod(invocation);
  }
}

class Settings extends Fake implements NotificationSettings {}

class Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 1, name: 'Self'));
  void logoutLocally() => state = const AsyncData(AuthState.unauthenticated());
}

class Accounts extends AccountStore {
  @override
  Future<AccountState> build() async =>
      const AccountState(currentAccountId: 'server::1');
  void switchLocally() =>
      state = const AsyncData(AccountState(currentAccountId: 'other::1'));
}

class Api extends AuthApi {
  Api() : super(Dio());
  final uploads = <String>[];
  bool fail = false;
  Future<void>? uploadResult;
  @override
  Future<void> updateDeviceToken(String deviceToken) async {
    uploads.add(deviceToken);
    if (fail) throw StateError('temporary network failure');
    await uploadResult;
  }
}

final containers = <ProviderContainer>[];

Future<ProviderContainer> start(
    WidgetTester tester, Messaging messaging, Api api,
    {Api? otherApi}) async {
  final container = ProviderContainer(overrides: [
    fcmMessagingProvider.overrideWithValue(messaging),
    authControllerProvider.overrideWith(Auth.new),
    accountStoreProvider.overrideWith(Accounts.new),
    authApiProvider.overrideWith((ref) {
      final account =
          ref.watch(accountStoreProvider).valueOrNull?.currentAccountId;
      return account == 'other::1' ? otherApi ?? api : api;
    }),
  ]);
  containers.add(container);
  addTearDown(() async {
    container.dispose();
    await messaging.refreshes.close();
  });
  await container.read(authControllerProvider.future);
  await container.read(accountStoreProvider.future);
  container.listen(fcmServiceProvider, (_, __) {});
  await container.read(fcmServiceProvider.future);
  await tester.pump();
  return container;
}

void iosTest(String description, WidgetTesterCallback callback,
    {TargetPlatform platform = TargetPlatform.iOS}) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      for (final container in containers) {
        container.dispose();
      }
      containers.clear();
      await tester.pump(const Duration(milliseconds: 1));
    }
  }, variant: TargetPlatformVariant.only(platform));
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  tearDown(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  iosTest('late APNs registration recovers without a token refresh event',
      (tester) async {
    final messaging = Messaging()..apns = null;
    final api = Api();
    await start(tester, messaging, api);
    expect(api.uploads, isEmpty);
    expect(messaging.tokenReads, 0);
    messaging.apns = 'ready';
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(api.uploads, ['cached-token']);
    await tester.pump(const Duration(seconds: 30));
    expect(api.uploads, hasLength(1));
  });

  iosTest('failed upload retries an unchanged cached token', (tester) async {
    final messaging = Messaging();
    final api = Api()..fail = true;
    await start(tester, messaging, api);
    expect(api.uploads, ['cached-token']);
    api.fail = false;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(api.uploads, ['cached-token', 'cached-token']);
    await tester.pump(const Duration(seconds: 30));
    expect(api.uploads, hasLength(2));
  });

  iosTest('permission completion immediately retries token registration',
      (tester) async {
    final messaging = Messaging()..apns = null;
    final api = Api();
    await start(tester, messaging, api);
    messaging.apns = 'ready';
    messaging.permission.complete(Settings());
    await tester.pump();
    expect(api.uploads, ['cached-token']);
  });

  iosTest('a timed out token read recovers on a later attempt', (tester) async {
    final token = Completer<String?>();
    final messaging = Messaging()..tokenResult = token.future;
    final api = Api();
    await start(tester, messaging, api);
    await tester.pump(const Duration(seconds: 3));
    expect(api.uploads, isEmpty);
    messaging.tokenResult = null;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(api.uploads, ['cached-token']);
    token.complete('late-token');
    await tester.pump();
    expect(api.uploads, ['cached-token']);
  });

  iosTest('background suspends retries and resume repairs registration',
      (tester) async {
    final messaging = Messaging();
    final api = Api()..fail = true;
    await start(tester, messaging, api);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    api.fail = false;
    messaging.token = 'current-token';
    await tester.pump(const Duration(seconds: 30));
    expect(api.uploads, ['cached-token']);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(api.uploads, ['cached-token', 'current-token']);
  });

  iosTest('logout cancels pending registration retries', (tester) async {
    final messaging = Messaging()..apns = null;
    final api = Api();
    final container = await start(tester, messaging, api);
    (container.read(authControllerProvider.notifier) as Auth).logoutLocally();
    messaging.apns = 'ready';
    await tester.pump(const Duration(seconds: 30));
    expect(api.uploads, isEmpty);
  });

  iosTest('a pending token read cannot upload using the old account API',
      (tester) async {
    final token = Completer<String?>();
    final messaging = Messaging()..tokenResult = token.future;
    final oldApi = Api();
    final newApi = Api();
    final container = await start(tester, messaging, oldApi, otherApi: newApi);
    (container.read(accountStoreProvider.notifier) as Accounts).switchLocally();
    token.complete('current-token');
    await tester.pump();
    expect(oldApi.uploads, isEmpty);
    expect(newApi.uploads, ['current-token']);
  });

  iosTest('token rotation during an upload is serialized and not lost',
      (tester) async {
    final upload = Completer<void>();
    final messaging = Messaging();
    final api = Api()..uploadResult = upload.future;
    await start(tester, messaging, api);
    messaging.refreshes.add('rotated-token');
    await tester.pump();
    expect(api.uploads, ['cached-token']);
    upload.complete();
    await tester.pump();
    expect(api.uploads, ['cached-token', 'rotated-token']);
    messaging.refreshes.add('rotated-token');
    await tester.pump();
    expect(api.uploads, hasLength(2));
  });

  iosTest('disposal cancels retries and ignores late permission results',
      (tester) async {
    final messaging = Messaging()..apns = null;
    final api = Api();
    final container = await start(tester, messaging, api);
    container.dispose();
    messaging.apns = 'ready';
    messaging.permission.complete(Settings());
    await tester.pump(const Duration(seconds: 30));
    expect(api.uploads, isEmpty);
  });

  iosTest('iOS enables foreground banners, badges and sounds', (tester) async {
    final messaging = Messaging();
    await start(tester, messaging, Api());
    expect(messaging.presentation, (true, true, true));
  });

  iosTest('Android retains its existing foreground presentation behavior',
      (tester) async {
    final messaging = Messaging()..apns = null;
    final api = Api();
    await start(tester, messaging, api);
    expect(messaging.presentation, isNull);
    expect(api.uploads, ['cached-token']);
  }, platform: TargetPlatform.android);

  iosTest('Android still uploads token rotations received in the background',
      (tester) async {
    final messaging = Messaging();
    final api = Api();
    await start(tester, messaging, api);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    messaging.refreshes.add('background-token');
    await tester.pump();
    expect(api.uploads, ['cached-token', 'background-token']);
  }, platform: TargetPlatform.android);
}
