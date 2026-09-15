import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const commitChannel = MethodChannel('vocechat/secure_storage_commit');
  const id = 'server::7';
  const prefix = 'voce_${id}_';
  final expires = DateTime.utc(2030);
  late Directory directory;
  late File legacyFile;
  late Map<String, String> keychain;
  late Map<String, String> disk;
  late List<MethodCall> calls;
  String? failMethod;

  SecureTokenStore openStore() =>
      SecureTokenStore(id: id, legacyFallbackFile: legacyFile);

  Future<void> save(SecureTokenStore store, {String access = 'access'}) =>
      store.saveTokens(access: access, refresh: 'refresh', expiresAt: expires);

  Map<String, String> legacyTokens() => {
        '${prefix}access': 'old-access',
        '${prefix}refresh': 'old-refresh',
        '${prefix}expires_at': expires.toIso8601String(),
      };

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group(platform.name, () {
      setUp(() async {
        debugDefaultTargetPlatformOverride = platform;
        directory = await Directory.systemTemp.createTemp('ios-session-test');
        legacyFile = File('${directory.path}/tokens.json');
        keychain = {};
        disk = {};
        calls = [];
        failMethod = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(commitChannel, (call) async {
          expect(call.method, 'commit');
          if (failMethod == 'commit') {
            throw PlatformException(code: 'secure_storage_commit_failed');
          }
          disk = Map.of(keychain);
          return null;
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == failMethod) {
            throw PlatformException(code: '-25308', message: 'Keychain locked');
          }
          final args = call.arguments as Map;
          final key = args['key'] as String;
          switch (call.method) {
            case 'read':
              return keychain[key];
            case 'write':
              keychain[key] = args['value'] as String;
              if (platform == TargetPlatform.iOS) disk = Map.of(keychain);
              return null;
            case 'delete':
              keychain.remove(key);
              if (platform == TargetPlatform.iOS) disk = Map.of(keychain);
              return null;
            default:
              throw StateError('Unexpected storage method: ${call.method}');
          }
        });
      });

      tearDown(() async {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(commitChannel, null);
        await directory.delete(recursive: true);
      });

      test('session survives a new store with one atomic secure-storage write',
          () async {
        await save(openStore());
        final writes = calls.where((call) => call.method == 'write').toList();
        expect(writes, hasLength(1));
        expect(writes.single.arguments['key'], '${prefix}session');

        // Kill the in-memory plugin cache. Only committed disk data survives.
        keychain = Map.of(disk);
        final restored = await openStore().readTokens();
        expect(restored?.accessToken, 'access');
        expect(restored?.refreshToken, 'refresh');
        expect(restored?.expiresAt, expires);
        expect(await legacyFile.exists(), isFalse);
      });

      test('old three-key Keychain session migrates without a new login',
          () async {
        keychain.addAll(legacyTokens());
        expect((await openStore().readTokens())?.accessToken, 'old-access');
        expect(keychain.keys, ['${prefix}session']);
        expect((await openStore().readTokens())?.refreshToken, 'old-refresh');
      });

      test('restart recovers old fallback file even when Keychain is healthy',
          () async {
        await legacyFile.writeAsString(jsonEncode({
          ...legacyTokens(),
          'voce_other::8_access': 'other-account',
        }));

        expect((await openStore().readTokens())?.refreshToken, 'old-refresh');
        expect(jsonDecode(await legacyFile.readAsString()), {
          'voce_other::8_access': 'other-account',
        });
        expect((await openStore().readTokens())?.accessToken, 'old-access');
      });

      test('remembered password survives process memory being discarded',
          () async {
        await openStore().saveRememberedCredential(
            email: 'test@example.com', password: 'password');
        keychain = Map.of(disk);
        final remembered = await openStore().readRememberedCredential();
        expect(remembered?.email, 'test@example.com');
        expect(remembered?.password, 'password');
        expect(calls.where((call) => call.method == 'write'), hasLength(1));
      });

      test('legacy password split between secure storage and file migrates',
          () async {
        keychain['${prefix}remember_email'] = 'test@example.com';
        await legacyFile.writeAsString(
            jsonEncode({'${prefix}remember_password': 'password'}));
        expect((await openStore().readRememberedCredential())?.password,
            'password');
        keychain = Map.of(disk);
        expect((await openStore().readRememberedCredential())?.email,
            'test@example.com');
        expect(jsonDecode(await legacyFile.readAsString()), isEmpty);
      });

      test('opting out of remembered password survives interrupted cleanup',
          () async {
        keychain.addAll({
          '${prefix}remember_email': 'test@example.com',
          '${prefix}remember_password': 'password'
        });
        failMethod = 'delete';
        await openStore().clearRememberedCredential();
        keychain = Map.of(disk);
        failMethod = null;
        expect(await openStore().readRememberedCredential(), isNull);
      });

      if (platform == TargetPlatform.android) {
        test('disk commit failure is not reported as successful login',
            () async {
          await save(openStore());
          failMethod = 'commit';
          await expectLater(save(openStore(), access: 'new-access'),
              throwsA(isA<PlatformException>()));
          keychain = Map.of(disk);
          failMethod = null;
          expect((await openStore().readTokens())?.accessToken, 'access');
        });

        test('disk commit failure is not reported as remembered password saved',
            () async {
          failMethod = 'commit';
          await expectLater(
              openStore().saveRememberedCredential(
                  email: 'test@example.com', password: 'password'),
              throwsA(isA<PlatformException>()));
          keychain = Map.of(disk);
          failMethod = null;
          expect(await openStore().readRememberedCredential(), isNull);
        });
      }

      test('recovers a legacy save split across Keychain and fallback file',
          () async {
        keychain['${prefix}access'] = 'old-access';
        final fileTokens = legacyTokens()..remove('${prefix}access');
        await legacyFile.writeAsString(jsonEncode(fileTokens));
        final restored = await openStore().readTokens();
        expect(restored?.accessToken, 'old-access');
        expect(restored?.refreshToken, 'old-refresh');
      });

      test(
          'failed Keychain write surfaces failure and preserves previous session',
          () async {
        await save(openStore());
        failMethod = 'write';
        await expectLater(save(openStore(), access: 'replacement'),
            throwsA(isA<PlatformException>()));
        expect(await legacyFile.exists(), isFalse);
        failMethod = null;
        expect((await openStore().readTokens())?.accessToken, 'access');
      });

      test(
          'locked Keychain read is distinct from absent credentials and recovers',
          () async {
        await save(openStore());
        failMethod = 'read';
        await expectLater(
            openStore().readTokens(), throwsA(isA<PlatformException>()));
        failMethod = null;
        expect((await openStore().readTokens())?.accessToken, 'access');
        expect(await legacyFile.exists(), isFalse);
      });

      test(
          'logout marker prevents recovery of legacy tokens after cleanup failure',
          () async {
        keychain.addAll(legacyTokens());
        await legacyFile.writeAsString(jsonEncode(legacyTokens()));
        failMethod = 'delete';
        await openStore().clear();
        failMethod = null;
        expect(await openStore().readTokens(), isNull);

        await save(openStore(), access: 'new-login');
        expect((await openStore().readTokens())?.accessToken, 'new-login');
      });

      test('failed migration keeps legacy credentials for the next start',
          () async {
        await legacyFile.writeAsString(jsonEncode(legacyTokens()));
        failMethod = 'write';
        await expectLater(
            openStore().readTokens(), throwsA(isA<PlatformException>()));
        expect(jsonDecode(await legacyFile.readAsString()), legacyTokens());
        failMethod = null;
        expect((await openStore().readTokens())?.accessToken, 'old-access');
      });
    });
  }
}
