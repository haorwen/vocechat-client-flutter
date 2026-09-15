import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/preference_write.dart';
import 'package:vocechat_client/core/storage/server_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const account = AccountConfig(
      accountId: 'server::7', serverId: 'server', uid: 7, name: 'Test');
  const server =
      ServerConfig(id: 'server', baseUrl: 'https://example.com', name: 'Test');

  late _FailingPreferences disk;
  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    disk = _FailingPreferences({
      'flutter.voce_accounts': [jsonEncode(account.toJson())],
      'flutter.voce_servers': [jsonEncode(server.toJson())],
    });
    SharedPreferencesStorePlatform.instance = disk;
    container = ProviderContainer();
    container.listen(accountStoreProvider, (_, __) {});
    container.listen(serverStoreProvider, (_, __) {});
  });
  tearDown(() {
    container.dispose();
    SharedPreferences.setMockInitialValues({});
  });

  test('failed current account commit is surfaced and Dart cache is reloaded',
      () async {
    await container.read(accountStoreProvider.future);
    disk.failKey = 'flutter.voce_current_account';
    await expectLater(
        container
            .read(accountStoreProvider.notifier)
            .selectAccount(account.accountId),
        throwsA(isA<PreferenceWriteException>()));
    expect(container.read(accountStoreProvider).requireValue.currentAccountId,
        isNull);
    expect(
        (await SharedPreferences.getInstance())
            .getString('voce_current_account'),
        isNull);
    disk.failKey = null;
    await container
        .read(accountStoreProvider.notifier)
        .selectAccount(account.accountId);
    expect(disk.values['flutter.voce_current_account'], account.accountId);
  });

  test('failed account list commit cannot advertise a saved profile', () async {
    await container.read(accountStoreProvider.future);
    disk.failKey = 'flutter.voce_accounts';
    await expectLater(
        container
            .read(accountStoreProvider.notifier)
            .upsertAccount(account.copyWith(name: 'Changed')),
        throwsA(isA<PreferenceWriteException>()));
    expect(
        container.read(accountStoreProvider).requireValue.accounts.single.name,
        'Test');
  });

  test('failed server selection does not remain in the preference cache',
      () async {
    await container.read(serverStoreProvider.future);
    disk.failKey = 'flutter.voce_current_server';
    await expectLater(
        container.read(serverStoreProvider.notifier).selectServer(server.id),
        throwsA(isA<PreferenceWriteException>()));
    expect(container.read(serverStoreProvider).requireValue.currentServerId,
        isNull);
    expect(
        (await SharedPreferences.getInstance())
            .getString('voce_current_server'),
        isNull);
  });
}

class _FailingPreferences extends SharedPreferencesStorePlatform {
  _FailingPreferences(this.values);
  final Map<String, Object> values;
  String? failKey;
  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == failKey) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (key == failKey) return false;
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}
