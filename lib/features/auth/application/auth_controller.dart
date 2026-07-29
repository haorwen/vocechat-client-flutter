import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/account_store.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/utils/app_log.dart';
import '../data/auth_api.dart';
import '../domain/auth_models.dart';

part 'auth_controller.freezed.dart';
part 'auth_controller.g.dart';

// ---------------------------------------------------------------------------
// AuthState (sealed)
// ---------------------------------------------------------------------------

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = AuthStateUnauthenticated;
  const factory AuthState.loading() = AuthStateLoading;
  const factory AuthState.authenticated({required VoceUser user}) =
      AuthStateAuthenticated;
}

// ---------------------------------------------------------------------------
// AuthController
// ---------------------------------------------------------------------------

@riverpod
class AuthController extends _$AuthController {
  /// Suppresses the store listeners' invalidateSelf while we are driving
  /// server/account-id changes from inside login()/logout()/switchAccount()
  /// ourselves. Without this, mutating the stores mid-operation invalidates
  /// this very provider before the async flow finishes — triggering the
  /// "Cannot use ref functions after the dependency of a provider changed"
  /// assertion.
  bool _suppressStoreReact = false;

  @override
  Future<AuthState> build() async {
    bootLog('5 AuthController.build: enter');
    // Listen — instead of watch — so updates to accountStore (e.g. login
    // creating/selecting a new account, or the user switching accounts)
    // trigger an explicit re-bootstrap rather than invalidating this
    // provider mid-async-operation.
    ref.listen<AsyncValue<AccountState>>(
      accountStoreProvider,
      (prev, next) {
        if (_suppressStoreReact) return;
        final prevId = prev?.valueOrNull?.currentAccountId;
        final nextId = next.valueOrNull?.currentAccountId;
        if (prevId != nextId) {
          ref.invalidateSelf();
        }
      },
    );
    // Wait for both stores to finish loading before bootstrapping.
    bootLog('6 AuthController.build: await stores.future');
    await ref.read(serverStoreProvider.notifier).future;
    await ref.read(accountStoreProvider.notifier).future;
    bootLog('7 AuthController.build: stores ready, calling _bootstrap');
    final result = await _bootstrap();
    bootLog('8 AuthController.build: _bootstrap returned ${result.runtimeType}');
    return result;
  }

  AccountConfig? _currentAccount() {
    final accountState = ref.read(accountStoreProvider).valueOrNull;
    final accountId = accountState?.currentAccountId;
    if (accountId == null) return null;
    return accountState?.accounts.where((a) => a.accountId == accountId).firstOrNull;
  }

  /// Called at startup: reads stored tokens for the current account, refreshes
  /// if expired, then validates via /api/user/me. Falls back to refresh on
  /// 401.
  Future<AuthState> _bootstrap() async {
    final account = _currentAccount();
    AppLog.d(
      LogTag.auth,
      () => '🟦 bootstrap: accountId=${account?.accountId}',
    );
    if (account == null) return const AuthState.unauthenticated();

    // Keep the server store's currentServerId in sync with the account we're
    // bootstrapping against — both stores are always written together by
    // login()/switchAccount(), but this guards against them drifting apart
    // (e.g. a persisted-state edge case) since dio's baseUrl is resolved
    // from serverStore, not accountStore.
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    if (serverState?.currentServerId != account.serverId) {
      await ref.read(serverStoreProvider.notifier).selectServer(account.serverId);
    }

    final tokenStore = ref.read(secureTokenStoreProvider(account.accountId));
    final tokens = await tokenStore.readTokens();
    AppLog.d(
      LogTag.auth,
      () =>
          '🟦 bootstrap: tokens=${tokens == null ? "null" : "ok expires=${tokens.expiresAt}"}',
    );
    if (tokens == null) return const AuthState.unauthenticated();

    final api = ref.read(authApiProvider);

    // Proactively refresh if access token is expired or about to expire (<60s).
    final now = DateTime.now();
    final almostExpired = tokens.expiresAt.isBefore(
      now.add(const Duration(seconds: 60)),
    );
    if (almostExpired) {
      AppLog.d(LogTag.auth, () => '🟦 bootstrap: token expired/near, refreshing');
      final refreshed = await _tryRefresh(api, tokenStore, tokens.refreshToken);
      AppLog.d(LogTag.auth, () => '🟦 bootstrap: refresh result=$refreshed');
      if (!refreshed) return const AuthState.unauthenticated();
    }

    // Try fetching the current user; on 401 fall back to refresh once more.
    try {
      final user = await api.me();
      AppLog.d(LogTag.auth, () => '🟦 bootstrap: me() ok uid=${user.uid}');
      await _syncAccountProfile(account, user);
      return AuthState.authenticated(user: user);
    } catch (e) {
      AppLog.d(LogTag.auth, () => '🟦 bootstrap: me() failed: $e — trying refresh');
      final refreshed = await _tryRefresh(api, tokenStore, tokens.refreshToken);
      if (!refreshed) return const AuthState.unauthenticated();
      try {
        final user = await api.me();
        AppLog.d(
          LogTag.auth,
          () => '🟦 bootstrap: me() ok after refresh uid=${user.uid}',
        );
        await _syncAccountProfile(account, user);
        return AuthState.authenticated(user: user);
      } catch (e2) {
        AppLog.w(
          LogTag.auth,
          () => '🟦 bootstrap: me() still failed after refresh: $e2',
        );
        return const AuthState.unauthenticated();
      }
    }
  }

  /// Keep the saved [AccountConfig]'s display fields (name/email/avatar) in
  /// sync with the latest `/api/user/me`, so the account-switcher list
  /// doesn't show stale info after a profile edit.
  Future<void> _syncAccountProfile(AccountConfig account, VoceUser user) async {
    if (account.name == user.name &&
        account.email == user.email &&
        account.isAdmin == user.isAdmin &&
        account.avatarUpdatedAt == user.avatarUpdatedAt) {
      return;
    }
    await ref.read(accountStoreProvider.notifier).upsertAccount(
          account.copyWith(
            name: user.name,
            email: user.email,
            isAdmin: user.isAdmin,
            avatarUpdatedAt: user.avatarUpdatedAt,
          ),
        );
  }

  /// Exchange refresh token for a new access token; persist on success.
  Future<bool> _tryRefresh(
    AuthApi api,
    SecureTokenStore tokenStore,
    String refreshToken,
  ) async {
    try {
      final renew = await api.renew(refreshToken);
      await tokenStore.saveTokens(
        access: renew.token,
        refresh: renew.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: renew.expiredIn)),
      );
      AppLog.d(
        LogTag.auth,
        () =>
            '🟦 _tryRefresh: success, new expires=${DateTime.now().add(Duration(seconds: renew.expiredIn))}',
      );
      return true;
    } catch (e) {
      AppLog.w(LogTag.auth, () => '🟦 _tryRefresh: failed: $e');
      return false;
    }
  }

  /// Public wrapper around [_tryRefresh] for callers (e.g. the SSE provider)
  /// that need to proactively renew the access token before opening a new
  /// long-lived connection. Returns `true` if the token store now holds a
  /// fresh token, `false` if renewal failed (network error, refresh token
  /// rejected, etc.). Idempotent: returns `false` quietly when there is no
  /// current account or no stored refresh token.
  Future<bool> renewIfPossible() async {
    final account = _currentAccount();
    if (account == null) return false;
    final tokenStore = ref.read(secureTokenStoreProvider(account.accountId));
    final tokens = await tokenStore.readTokens();
    if (tokens == null) return false;
    return _tryRefresh(
        ref.read(authApiProvider), tokenStore, tokens.refreshToken);
  }

  /// Align the local server entry with the server-issued id, so token
  /// namespace and currentServerId stay in sync — and we never grow the
  /// servers list with a duplicate on every login.
  ///
  /// [targetBaseUrl] is the base URL the login/register call actually hit —
  /// normally the currently-configured server, but may point at a different
  /// server entirely when logging into a second account elsewhere (see
  /// [login]'s `serverUrl` override). Matching by id first (same server as
  /// before) then by normalized baseUrl (a server already saved under a
  /// different local id) avoids creating duplicate [ServerConfig] entries.
  Future<void> _reconcileServerEntry(
    String responseServerId,
    String targetBaseUrl,
  ) async {
    final serverStore = ref.read(serverStoreProvider.notifier);
    final existing = ref.read(serverStoreProvider).valueOrNull;
    final normalized = targetBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

    if (existing?.servers.any((s) => s.id == responseServerId) ?? false) {
      if (existing?.currentServerId != responseServerId) {
        await serverStore.selectServer(responseServerId);
      }
      return;
    }

    final matchByUrl = existing?.servers
        .where((s) =>
            s.baseUrl.trim().replaceAll(RegExp(r'/+$'), '') == normalized)
        .firstOrNull;
    if (matchByUrl != null) {
      await serverStore.replaceServerId(
        oldId: matchByUrl.id,
        newId: responseServerId,
      );
    } else {
      await serverStore.addServer(ServerConfig(
        id: responseServerId,
        baseUrl: normalized,
        name: Uri.tryParse(normalized)?.host ?? normalized,
      ));
    }
    await serverStore.selectServer(responseServerId);
  }

  /// Login with email + password (MD5-hashed internally).
  ///
  /// [serverUrl], when provided, targets that server instead of the
  /// currently-configured one — used by the account-switcher's "Add
  /// account" screen to sign into a second identity on a different
  /// VoceChat server. The request is issued through a scoped, disposable
  /// [VoceDioClient] (same interceptor stack: Referer injection, UTF-16
  /// sanitization, error mapping) rather than the shared [dioClientProvider],
  /// so the currently-active session's Dio instance — and any in-flight
  /// requests relying on it — are left untouched until this login succeeds.
  Future<void> login(
    String email,
    String password, {
    bool rememberMe = false,
    String? serverUrl,
  }) async {
    // Preserve the previous value (hasValue stays true) instead of a bare
    // AsyncLoading(). The router's redirect uses `authAsync.hasValue` to
    // distinguish this in-flight login from the app's initial auth
    // bootstrap — a bare loading state would be indistinguishable from
    // startup and force a /splash redirect mid-login, tearing down
    // LoginScreen before the error/success ever reaches it.
    // isRefresh: false is required — with the default `true`, copying over
    // a previous AsyncError produces another AsyncError (just isLoading:
    // true), not a real AsyncLoading. `ref.listen`'s `whenOrNull` would then
    // treat that as `isRefreshing` and re-fire the *stale* error callback
    // (e.g. re-showing "wrong password" from a prior attempt) a split
    // second before the new, successful result lands.
    state = AsyncLoading<AuthState>().copyWithPrevious(state, isRefresh: false);

    state = await AsyncValue.guard(() async {
      _suppressStoreReact = true;
      try {
        final currentServer = ref.read(serverStoreProvider).valueOrNull;
        final currentBaseUrl = currentServer?.servers
                .where((s) => s.id == currentServer.currentServerId)
                .firstOrNull
                ?.baseUrl ??
            '';
        final targetBaseUrl =
            (serverUrl != null && serverUrl.trim().isNotEmpty)
                ? serverUrl.trim().replaceAll(RegExp(r'/+$'), '')
                : currentBaseUrl;
        final api = targetBaseUrl == currentBaseUrl
            ? ref.read(authApiProvider)
            : AuthApi(VoceDioClient(baseUrl: targetBaseUrl, ref: ref).dio);

        final request = LoginRequest(
          credential: Credential.password(
            email: email,
            password: AuthApi.hashPassword(password),
          ),
          device: 'flutter',
        );
        final response = await api.login(request);

        await _reconcileServerEntry(response.serverId, targetBaseUrl);

        // Save tokens under an account-scoped key so the same server can
        // hold multiple logged-in accounts side by side.
        final accountId =
            AccountStore.makeId(response.serverId, response.user.uid);
        final tokenStore = ref.read(secureTokenStoreProvider(accountId));
        await tokenStore.saveTokens(
          access: response.token,
          refresh: response.refreshToken,
          expiresAt:
              DateTime.now().add(Duration(seconds: response.expiredIn)),
        );
        AppLog.d(
          LogTag.auth,
          () =>
              '🟢 login: tokens saved for accountId=$accountId expires=${DateTime.now().add(Duration(seconds: response.expiredIn))}',
        );

        await ref.read(accountStoreProvider.notifier).upsertAccount(
              AccountConfig(
                accountId: accountId,
                serverId: response.serverId,
                uid: response.user.uid,
                name: response.user.name,
                email: response.user.email,
                isAdmin: response.user.isAdmin,
                avatarUpdatedAt: response.user.avatarUpdatedAt,
              ),
            );
        await ref.read(accountStoreProvider.notifier).selectAccount(accountId);

        // Remembered credentials are pre-login convenience — keyed by
        // serverId (not accountId) since we don't know the uid until after
        // login succeeds.
        final rememberStore =
            ref.read(secureTokenStoreProvider(response.serverId));
        if (rememberMe) {
          await rememberStore.saveRememberedCredential(
            email: email,
            password: password,
          );
        } else {
          await rememberStore.clearRememberedCredential();
        }

        return AuthState.authenticated(user: response.user);
      } catch (e, st) {
        AppLog.e(LogTag.auth, () => '🔴 login() failed: $e',
            error: e, stackTrace: st);
        rethrow;
      } finally {
        _suppressStoreReact = false;
      }
    });
  }

  /// Logout the current account: clears its tokens and resets auth state.
  /// The [AccountConfig] entry itself is kept (not removed) so it still
  /// appears in the account switcher for a quick re-login — mirroring how a
  /// signed-out browser tab still remembers "who" was signed in.
  Future<void> logout() async {
    try {
      await ref.read(authApiProvider).logout();
    } catch (_) {
      // Best-effort — always clear locally
    }

    final account = _currentAccount();
    if (account != null) {
      await ref.read(secureTokenStoreProvider(account.accountId)).clear();
    }

    _suppressStoreReact = true;
    try {
      await ref.read(accountStoreProvider.notifier).clearCurrentAccount();
    } finally {
      _suppressStoreReact = false;
    }

    state = const AsyncData(AuthState.unauthenticated());
  }

  /// Remove a saved account entirely (clears its tokens and drops it from
  /// the switcher list). If it was the current account, resulting state is
  /// `unauthenticated`.
  Future<void> removeAccount(String accountId) async {
    await ref.read(secureTokenStoreProvider(accountId)).clear();
    final wasCurrent =
        ref.read(accountStoreProvider).valueOrNull?.currentAccountId ==
            accountId;

    _suppressStoreReact = true;
    try {
      await ref.read(accountStoreProvider.notifier).removeAccount(accountId);
    } finally {
      _suppressStoreReact = false;
    }

    if (wasCurrent) {
      state = const AsyncData(AuthState.unauthenticated());
    }
  }

  /// Switch to a different saved account (same or different server) without
  /// requiring the user to log out first. Attempts a silent token
  /// revalidation/refresh against the target account; if that fails (expired
  /// refresh token, revoked session, etc.) the resulting state is
  /// `unauthenticated` and the caller is expected to route to `/login`.
  Future<void> switchAccount(String accountId) async {
    final accountState = ref.read(accountStoreProvider).valueOrNull;
    final target =
        accountState?.accounts.where((a) => a.accountId == accountId).firstOrNull;
    if (target == null) return;
    if (accountState?.currentAccountId == accountId) return;

    state = AsyncLoading<AuthState>().copyWithPrevious(state, isRefresh: false);

    _suppressStoreReact = true;
    try {
      await ref.read(serverStoreProvider.notifier).selectServer(target.serverId);
      await ref.read(accountStoreProvider.notifier).selectAccount(accountId);
    } finally {
      _suppressStoreReact = false;
    }

    state = AsyncData(await _bootstrap());
  }

  /// Register a new account and auto-login on success.
  Future<void> register(String name, String email, String password) async {
    // See login() — preserve hasValue so the router's redirect doesn't
    // mistake this in-flight registration for the initial auth bootstrap.
    // isRefresh: false — see login() for why the default true is wrong here.
    state = AsyncLoading<AuthState>().copyWithPrevious(state, isRefresh: false);

    state = await AsyncValue.guard(() async {
      _suppressStoreReact = true;
      try {
        final response = await ref
            .read(authApiProvider)
            .register(email: email, password: password, name: name);

        final currentServer = ref.read(serverStoreProvider).valueOrNull;
        final currentBaseUrl = currentServer?.servers
                .where((s) => s.id == currentServer.currentServerId)
                .firstOrNull
                ?.baseUrl ??
            '';
        await _reconcileServerEntry(response.serverId, currentBaseUrl);

        final accountId =
            AccountStore.makeId(response.serverId, response.user.uid);
        final tokenStore = ref.read(secureTokenStoreProvider(accountId));
        await tokenStore.saveTokens(
          access: response.token,
          refresh: response.refreshToken,
          expiresAt:
              DateTime.now().add(Duration(seconds: response.expiredIn)),
        );

        await ref.read(accountStoreProvider.notifier).upsertAccount(
              AccountConfig(
                accountId: accountId,
                serverId: response.serverId,
                uid: response.user.uid,
                name: response.user.name,
                email: response.user.email,
                isAdmin: response.user.isAdmin,
                avatarUpdatedAt: response.user.avatarUpdatedAt,
              ),
            );
        await ref.read(accountStoreProvider.notifier).selectAccount(accountId);

        return AuthState.authenticated(user: response.user);
      } finally {
        _suppressStoreReact = false;
      }
    });
  }

  /// Re-validate tokens and refresh user state.
  Future<void> bootstrap() async {
    // See login() — preserve hasValue so a re-validation triggered while
    // already authenticated/unauthenticated doesn't look like the app's
    // initial auth bootstrap to the router's redirect logic.
    // isRefresh: false — see login() for why the default true is wrong here.
    state = AsyncLoading<AuthState>().copyWithPrevious(state, isRefresh: false);
    state = AsyncData(await _bootstrap());
  }

  /// Re-fetch `/api/user/me` and update [state] in place, without the token
  /// re-validation `_bootstrap()` does. Used after a profile edit (name,
  /// avatar) so the rest of the app picks up the fresh `VoceUser` (e.g. the
  /// updated `avatarUpdatedAt` for cache-busting) without a jarring loading
  /// flash or redundant refresh-token exchange. No-op if not authenticated.
  Future<void> refreshUser() async {
    final current = state.valueOrNull;
    if (current is! AuthStateAuthenticated) return;
    try {
      final user = await ref.read(authApiProvider).me();
      final account = _currentAccount();
      if (account != null) {
        await _syncAccountProfile(account, user);
      }
      state = AsyncData(AuthState.authenticated(user: user));
    } catch (e) {
      AppLog.w(LogTag.auth, () => '🟦 refreshUser: me() failed: $e');
      // Best-effort — keep the previous state on failure.
    }
  }
}
