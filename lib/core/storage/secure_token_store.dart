import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_token_store.g.dart';

class TokenData {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const TokenData({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });
}

class SecureTokenStore {
  SecureTokenStore({required this.serverId})
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final String serverId;
  final FlutterSecureStorage _storage;

  String _key(String suffix) => 'voce_${serverId}_$suffix';

  Future<void> saveTokens({
    required String access,
    required String refresh,
    required DateTime expiresAt,
  }) async {
    await Future.wait([
      _storage.write(key: _key('access'), value: access),
      _storage.write(key: _key('refresh'), value: refresh),
      _storage.write(
          key: _key('expires_at'), value: expiresAt.toIso8601String()),
    ]);
  }

  Future<TokenData?> readTokens() async {
    final results = await Future.wait([
      _storage.read(key: _key('access')),
      _storage.read(key: _key('refresh')),
      _storage.read(key: _key('expires_at')),
    ]);
    final access = results[0];
    final refresh = results[1];
    final expiresAtStr = results[2];
    if (access == null || refresh == null || expiresAtStr == null) return null;
    return TokenData(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.parse(expiresAtStr),
    );
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _key('access')),
      _storage.delete(key: _key('refresh')),
      _storage.delete(key: _key('expires_at')),
    ]);
  }
}

@riverpod
SecureTokenStore secureTokenStore(Ref ref, String serverId) {
  return SecureTokenStore(serverId: serverId);
}
