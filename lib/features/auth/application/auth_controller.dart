import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_token_store.dart';
import '../../../core/storage/server_store.dart';
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
  @override
  Future<AuthState> build() async {
    return await _bootstrap();
  }

  /// Called at startup: reads stored tokens and validates them via /api/user/me.
  Future<AuthState> _bootstrap() async {
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    final serverId = serverState?.currentServerId;
    if (serverId == null) return const AuthState.unauthenticated();

    final tokenStore = ref.read(secureTokenStoreProvider(serverId));
    final tokens = await tokenStore.readTokens();
    if (tokens == null) return const AuthState.unauthenticated();

    try {
      final user = await ref.read(authApiProvider).me();
      return AuthState.authenticated(user: user);
    } catch (_) {
      return const AuthState.unauthenticated();
    }
  }

  /// Login with email + password (MD5-hashed internally).
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final request = LoginRequest(
        credential: Credential.password(
          email: email,
          password: AuthApi.hashPassword(password),
        ),
        device: 'flutter',
      );
      final response = await ref.read(authApiProvider).login(request);

      // Persist server if not already present
      final serverStore = ref.read(serverStoreProvider.notifier);
      final existing = ref.read(serverStoreProvider).valueOrNull;
      if (existing == null ||
          !existing.servers.any((s) => s.id == response.serverId)) {
        await serverStore.addServer(ServerConfig(
          id: response.serverId,
          baseUrl: existing?.servers.firstOrNull?.baseUrl ?? '',
          name: response.serverId,
        ));
      }
      await serverStore.selectServer(response.serverId);

      // Save tokens
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

  /// Re-validate tokens and refresh user state.
  Future<void> bootstrap() async {
    state = const AsyncLoading();
    state = AsyncData(await _bootstrap());
  }
}
