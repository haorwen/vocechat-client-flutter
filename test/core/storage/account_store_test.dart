import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/storage/account_store.dart';

void main() {
  test('removeAccountsForServer removes all accounts for a replaced server',
      () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final store = container.read(accountStoreProvider.notifier);
    await store.future;
    await store.upsertAccount(
      const AccountConfig(
        accountId: 'old-server::1',
        serverId: 'old-server',
        uid: 1,
        name: 'Alice',
      ),
    );
    await store.upsertAccount(
      const AccountConfig(
        accountId: 'old-server::2',
        serverId: 'old-server',
        uid: 2,
        name: 'Bob',
      ),
    );
    await store.upsertAccount(
      const AccountConfig(
        accountId: 'other-server::3',
        serverId: 'other-server',
        uid: 3,
        name: 'Carol',
      ),
    );
    await store.selectAccount('old-server::2');

    final removed = await store.removeAccountsForServer('old-server');

    expect(removed.map((account) => account.accountId),
        containsAll(<String>['old-server::1', 'old-server::2']));
    expect(removed, hasLength(2));
    final state = await store.future;
    expect(state.accounts.map((account) => account.accountId),
        <String>['other-server::3']);
    expect(state.currentAccountId, isNull);
  });
}
