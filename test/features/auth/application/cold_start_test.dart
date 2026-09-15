import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const commitChannel = MethodChannel('vocechat/secure_storage_commit');

  for (final rememberMe in [false, true]) {
    test(
        'Android cold start preserves session (remember password: $rememberMe)',
        () async {
      final previousHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousHttpOverrides);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var storage = <String, String>{};
      var disk = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(commitChannel, (call) async {
        disk = Map.of(storage);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(commitChannel, null));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        final key = args['key'] as String;
        switch (call.method) {
          case 'read':
            return storage[key];
          case 'write':
            storage[key] = args['value'] as String;
            return null;
          case 'delete':
            storage.remove(key);
            return null;
          default:
            throw StateError(call.method);
        }
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <String>[];
      var rejectSession = false;
      server.listen((request) async {
        requests.add(request.uri.path);
        if (rejectSession &&
            (request.uri.path == '/api/user/me' ||
                request.uri.path == '/api/token/renew')) {
          request.response.statusCode = 401;
          await request.response.close();
          return;
        }
        final Object body;
        switch (request.uri.path) {
          case '/api/admin/system/organization':
            // The real server has a separate UUID in organization config.
            body = {'server_id': 'org-instance-uuid'};
          case '/api/token/login':
            body = {
              'server_id': 'server',
              'token': 'access',
              'refresh_token': 'refresh',
              'expired_in': 3600,
              'user': {'uid': 7, 'name': 'Test', 'email': 'test@example.com'},
            };
          case '/api/user/me':
            expect(request.headers.value('X-API-Key'), 'access');
            body = {'uid': 7, 'name': 'Test', 'email': 'test@example.com'};
          default:
            body = {};
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
        await request.response.close();
      });
      SharedPreferences.setMockInitialValues({
        'voce_servers': [
          jsonEncode(ServerConfig(
                  id: 'local-server',
                  baseUrl: 'http://127.0.0.1:${server.port}',
                  name: 'Test')
              .toJson())
        ],
        'voce_current_server': 'local-server',
      });
      final first = ProviderContainer();
      final subscription = first.listen(authControllerProvider, (_, __) {});
      await first.read(authControllerProvider.future);
      await first
          .read(authControllerProvider.notifier)
          .login('test@example.com', 'test-password', rememberMe: rememberMe);
      expect(first.read(authControllerProvider).requireValue,
          isA<AuthStateAuthenticated>());
      expect(first.read(accountStoreProvider).requireValue.currentAccountId,
          'server::7');
      subscription.close();
      first.dispose();
      storage = Map.of(disk);
      final prefs = await SharedPreferences.getInstance();
      final savedPreferences = {
        for (final key in prefs.getKeys()) key: prefs.get(key)!
      };
      SharedPreferences.setMockInitialValues(savedPreferences);

      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      restarted.listen(authControllerProvider, (_, __) {});
      // Deliberately do not preload server/account providers: this is startup.
      expect(await restarted.read(authControllerProvider.future),
          isA<AuthStateAuthenticated>());
      final remembered = await restarted
          .read(secureTokenStoreProvider('server'))
          .readRememberedCredential();
      expect(remembered?.email, rememberMe ? 'test@example.com' : null);
      expect(remembered?.password, rememberMe ? 'test-password' : null);
      expect(
          requests.where((path) => path == '/api/token/login'), hasLength(1));
      expect(requests, contains('/api/user/me'));
      expect(restarted.read(authRestoreFailureProvider), isNull);

      // A revoked session should lead to login with an explicit reason, but
      // must not erase the separately remembered password.
      rejectSession = true;
      await restarted.read(authControllerProvider.notifier).bootstrap();
      expect(restarted.read(authControllerProvider).requireValue,
          isA<AuthStateUnauthenticated>());
      expect(restarted.read(authRestoreFailureProvider),
          AuthRestoreFailure.rejected);
      storage = Map.of(disk);
      expect(
          (await SecureTokenStore(id: 'server').readRememberedCredential())
              ?.password,
          rememberMe ? 'test-password' : null);
    });
  }
}
