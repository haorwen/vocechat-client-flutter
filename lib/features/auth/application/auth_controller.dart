import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
  /// Suppresses the serverStore listener's invalidateSelf while we are
  /// driving server-id changes from inside login()/logout() ourselves.
  /// Without this, mutating serverStore mid-login invalidates this very
  /// provider before the async login flow finishes — triggering the
  /// "Cannot use ref functions after the dependency of a provider changed"
  /// assertion.
  bool _suppressServerStoreReact = false;

  @override
  Future<AuthState> build() async {
    bootLog('5 AuthController.build: enter');
    // Listen — instead of watch — so updates to serverStore (e.g. login
    // replacing the local id with the server-issued one, or the user
    // changing servers) trigger an explicit re-bootstrap rather than
    // invalidating this provider mid-async-operation.
    ref.listen<AsyncValue<ServerState>>(
      serverStoreProvider,
      (prev, next) {
        if (_suppressServerStoreReact) return;
        // Re-run bootstrap when the *currentServerId* changes, since that's
        // what determines whose tokens we read.
        final prevId = prev?.valueOrNull?.currentServerId;
        final nextId = next.valueOrNull?.currentServerId;
        if (prevId != nextId) {
          ref.invalidateSelf();
        }
      },
    );
    // Wait for ServerStore to finish loading before bootstrapping.
    bootLog('6 AuthController.build: await serverStoreProvider.future');
    await ref.read(serverStoreProvider.notifier).future;
    bootLog('7 AuthController.build: serverStore ready, calling _bootstrap');
    final result = await _bootstrap();
    bootLog('8 AuthController.build: _bootstrap returned ${result.runtimeType}');
    return result;
  }

  /// Called at startup: reads stored tokens, refreshes if expired,
  /// then validates via /api/user/me. Falls back to refresh on 401.
  Future<AuthState> _bootstrap() async {
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    final serverId = serverState?.currentServerId;
    AppLog.d(
      LogTag.auth,
      () =>
          '🟦 bootstrap: serverId=$serverId servers=${serverState?.servers.length ?? 0}',
    );
    if (serverId == null) return const AuthState.unauthenticated();

    final tokenStore = ref.read(secureTokenStoreProvider(serverId));
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
  /// configured server or no stored refresh token.
  Future<bool> renewIfPossible() async {
    final serverId =
        ref.read(serverStoreProvider).valueOrNull?.currentServerId;
    if (serverId == null) return false;
    final tokenStore = ref.read(secureTokenStoreProvider(serverId));
    final tokens = await tokenStore.readTokens();
    if (tokens == null) return false;
    return _tryRefresh(
        ref.read(authApiProvider), tokenStore, tokens.refreshToken);
  }

  /// Login with email + password (MD5-hashed internally).
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _suppressServerStoreReact = true;
      try {
        final request = LoginRequest(
          credential: Credential.password(
            email: email,
            password: AuthApi.hashPassword(password),
          ),
          device: 'flutter',
        );
        final response = await ref.read(authApiProvider).login(request);

        // Align the local server entry with the server-issued id, so token
        // namespace and currentServerId stay in sync — and we never grow
        // the servers list with a duplicate on every login.
        final serverStore = ref.read(serverStoreProvider.notifier);
        final existing = ref.read(serverStoreProvider).valueOrNull;
        final localCurrentId = existing?.currentServerId;
        final hasServerEntry =
            existing?.servers.any((s) => s.id == response.serverId) ?? false;

        if (!hasServerEntry) {
          if (localCurrentId != null &&
              localCurrentId != response.serverId &&
              (existing?.servers.any((s) => s.id == localCurrentId) ?? false)) {
            // Replace the placeholder local id with the canonical server id.
            await serverStore.replaceServerId(
              oldId: localCurrentId,
              newId: response.serverId,
            );
          } else {
            // Cold path: no existing entry to rename — add one keyed by
            // the server-issued id, using whatever baseUrl is configured.
            await serverStore.addServer(ServerConfig(
              id: response.serverId,
              baseUrl: existing?.servers.firstOrNull?.baseUrl ?? '',
              name: response.serverId,
            ));
            await serverStore.selectServer(response.serverId);
          }
        } else if (localCurrentId != response.serverId) {
          await serverStore.selectServer(response.serverId);
        }

        // Save tokens
        final tokenStore =
            ref.read(secureTokenStoreProvider(response.serverId));
        await tokenStore.saveTokens(
          access: response.token,
          refresh: response.refreshToken,
          expiresAt:
              DateTime.now().add(Duration(seconds: response.expiredIn)),
        );
        AppLog.d(
          LogTag.auth,
          () =>
              '🟢 login: tokens saved for serverId=${response.serverId} expires=${DateTime.now().add(Duration(seconds: response.expiredIn))}',
        );

        return AuthState.authenticated(user: response.user);
      } catch (e, st) {
        AppLog.e(LogTag.auth, () => '🔴 login() failed: $e',
            error: e, stackTrace: st);
        rethrow;
      } finally {
        _suppressServerStoreReact = false;
      }
    });
  }

  /// Logout: clear tokens and reset state.
  Future<void> logout() async {
    try {
      await ref.read(authApiProvider).logout();
    } catch (_) {
      // Best-effort — always clear locally
    }

    final serverId =
        ref.read(serverStoreProvider).valueOrNull?.currentServerId;
    if (serverId != null) {
      await ref.read(secureTokenStoreProvider(serverId)).clear();
    }

    state = const AsyncData(AuthState.unauthenticated());
  }

  /// Register a new account and auto-login on success.
  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final response = await ref
          .read(authApiProvider)
          .register(email: email, password: password, name: name);

      final serverStore = ref.read(serverStoreProvider.notifier);
      final existing = ref.read(serverStoreProvider).valueOrNull;
      final localCurrentId = existing?.currentServerId;
      final hasServerEntry =
          existing?.servers.any((s) => s.id == response.serverId) ?? false;

      if (!hasServerEntry) {
        if (localCurrentId != null &&
            localCurrentId != response.serverId &&
            (existing?.servers.any((s) => s.id == localCurrentId) ?? false)) {
          await serverStore.replaceServerId(
            oldId: localCurrentId,
            newId: response.serverId,
          );
        } else {
          await serverStore.addServer(ServerConfig(
            id: response.serverId,
            baseUrl: existing?.servers.firstOrNull?.baseUrl ?? '',
            name: response.serverId,
          ));
          await serverStore.selectServer(response.serverId);
        }
      } else if (localCurrentId != response.serverId) {
        await serverStore.selectServer(response.serverId);
      }

      final tokenStore =
          ref.read(secureTokenStoreProvider(response.serverId));
      await tokenStore.saveTokens(
        access: response.token,
        refresh: response.refreshToken,
        expiresAt:
            DateTime.now().add(Duration(seconds: response.expiredIn)),
      );

      return AuthState.authenticated(user: response.user);
    });
  }

  /// Re-validate tokens and refresh user state.
  Future<void> bootstrap() async {
    state = const AsyncLoading();
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
      state = AsyncData(AuthState.authenticated(user: user));
    } catch (e) {
      AppLog.w(LogTag.auth, () => '🟦 refreshUser: me() failed: $e');
      // Best-effort — keep the previous state on failure.
    }
  }
}
