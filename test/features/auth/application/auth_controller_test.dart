import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';

const _old =
    AccountConfig(accountId: 'old::1', serverId: 'old', uid: 1, name: 'Old');
const _next =
    AccountConfig(accountId: 'next::2', serverId: 'next', uid: 2, name: 'Next');

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 1, name: 'Old'));
  @override
  Future<bool> checkServerIdentity([String? requestedBaseUrl]) async => false;
}

class _Servers extends ServerStore {
  _Servers({this.failSelect = false, this.initial = 'old'});
  final bool failSelect;
  final String initial;
  @override
  Future<ServerState> build() async =>
      ServerState(currentServerId: initial, servers: const [
        ServerConfig(id: 'old', baseUrl: 'https://old.test', name: 'Old'),
        ServerConfig(id: 'next', baseUrl: 'https://next.test', name: 'Next'),
      ]);
  @override
  Future<void> selectServer(String id) async {
    if (failSelect) throw StateError('disk write failed');
    state = AsyncData((await future).copyWith(currentServerId: id));
  }
}

class _Accounts extends AccountStore {
  @override
  Future<AccountState> build() async =>
      const AccountState(accounts: [_old, _next], currentAccountId: 'old::1');
  @override
  Future<void> selectAccount(String accountId) async =>
      throw StateError('account write failed');
}

void main() {
  Future<ProviderContainer> setup(_Servers servers) async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      serverStoreProvider.overrideWith(() => servers),
      accountStoreProvider.overrideWith(_Accounts.new),
    ]);
    addTearDown(container.dispose);
    // AuthController is autoDispose; retain it while its operation is tested.
    container.listen(authControllerProvider, (_, __) {});
    container.listen(accountStoreProvider, (_, __) {});
    container.listen(serverStoreProvider, (_, __) {});
    await container.read(serverStoreProvider.future);
    await container.read(accountStoreProvider.future);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('switch failure before pointers move restores the previous session',
      () async {
    final container = await setup(_Servers(failSelect: true));
    await expectLater(
        container
            .read(authControllerProvider.notifier)
            .switchAccount('next::2'),
        throwsStateError);
    final auth = container.read(authControllerProvider);
    expect(auth.isLoading, isFalse);
    expect(auth.valueOrNull, isA<AuthStateAuthenticated>());
  });

  test(
      'switch failure after server moves exits loading with a recoverable error',
      () async {
    final container = await setup(_Servers());
    await expectLater(
        container
            .read(authControllerProvider.notifier)
            .switchAccount('next::2'),
        throwsStateError);
    final auth = container.read(authControllerProvider);
    expect(auth.isLoading, isFalse);
    expect(auth.hasError, isTrue);
  });

  test('revalidation store failure also exits loading', () async {
    final container = await setup(_Servers(failSelect: true, initial: 'next'));
    await container.read(authControllerProvider.notifier).bootstrap();
    final auth = container.read(authControllerProvider);
    expect(auth.isLoading, isFalse);
    expect(auth.hasError, isTrue);
  });
}
