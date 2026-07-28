import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_log.dart';

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

class RememberedCredential {
  final String email;
  final String password;

  const RememberedCredential({required this.email, required this.password});
}

final _log = _TokenLogShim();
bool _webWarningLogged = false;
bool _keyringFailureLogged = false;

class _TokenLogShim {
  void w(String msg, {Object? error, StackTrace? stackTrace}) =>
      AppLog.w(LogTag.token, () => msg,
          error: error, stackTrace: stackTrace);
}

// File-based fallback when the OS keyring is unavailable
// (Linux without libsecret/seahorse, locked GNOME keyring, headless CI…).
// Stores plaintext JSON in the app's cache directory — clearly less secure
// than the OS keyring, but persists across app restarts.
bool _useFileFallback = false;
File? _fallbackFile;
Map<String, String> _fallbackCache = {};
Future<void>? _fallbackLoadFuture;

Future<File> _resolveFallbackFile() async {
  if (_fallbackFile != null) return _fallbackFile!;
  // Use HOME directly to avoid path_provider giving an app-id-dependent
  // path that changes between debug/release/dev runs.
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  final dir = Directory('$home/.vocechat-client');
  if (!await dir.exists()) await dir.create(recursive: true);
  final f = File('${dir.path}/tokens.json');
  AppLog.d(LogTag.token, () => '🔐 token fallback file: ${f.path}');
  _fallbackFile = f;
  return f;
}

Future<void> _loadFallbackCacheOnce() {
  return _fallbackLoadFuture ??= _doLoadFallbackCache();
}

Future<void> _doLoadFallbackCache() async {
  try {
    final f = await _resolveFallbackFile();
    if (await f.exists()) {
      final raw = await f.readAsString();
      if (raw.isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          _fallbackCache = parsed.map((k, v) => MapEntry(k, v.toString()));
        }
      }
    }
  } catch (e) {
    _log.w('failed to load fallback token file: $e');
  }
}

Future<void> _persistFallback() async {
  try {
    final f = await _resolveFallbackFile();
    await f.writeAsString(jsonEncode(_fallbackCache), flush: true);
    AppLog.d(
      LogTag.token,
      () => '🔐 saved tokens to ${f.path} (${_fallbackCache.length} keys)',
    );
  } catch (e) {
    _log.w('failed to persist fallback token file: $e');
  }
}

class SecureTokenStore {
  SecureTokenStore({required this.serverId})
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ) {
    if (kIsWeb && !_webWarningLogged) {
      _webWarningLogged = true;
      _log.w(
          'flutter_secure_storage falls back to localStorage on web — XSS readable');
    }
  }

  final String serverId;
  final FlutterSecureStorage _storage;

  String _key(String suffix) => 'voce_${serverId}_$suffix';

  void _onKeyringFailure(Object e) {
    _useFileFallback = true;
    if (!_keyringFailureLogged) {
      _keyringFailureLogged = true;
      _log.w(
          'OS keyring unavailable ($e); falling back to plaintext token file in app support dir.');
    }
  }

  Future<void> _writeOne(String key, String value) async {
    if (_useFileFallback) {
      await _loadFallbackCacheOnce();
      _fallbackCache[key] = value;
      await _persistFallback();
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      _onKeyringFailure(e);
      await _loadFallbackCacheOnce();
      _fallbackCache[key] = value;
      await _persistFallback();
    }
  }

  Future<String?> _readOne(String key) async {
    if (_useFileFallback) {
      await _loadFallbackCacheOnce();
      return _fallbackCache[key];
    }
    try {
      return await _storage.read(key: key);
    } catch (e) {
      _onKeyringFailure(e);
      await _loadFallbackCacheOnce();
      return _fallbackCache[key];
    }
  }

  Future<void> _deleteOne(String key) async {
    _fallbackCache.remove(key);
    if (_useFileFallback) {
      await _persistFallback();
      return;
    }
    try {
      await _storage.delete(key: key);
    } catch (e) {
      _onKeyringFailure(e);
      await _persistFallback();
    }
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
    required DateTime expiresAt,
  }) async {
    // Serial writes — flutter_secure_storage on Windows (DPAPI) and Linux
    // (libsecret) is not concurrency-safe; parallel writes can drop entries.
    await _writeOne(_key('access'), access);
    await _writeOne(_key('refresh'), refresh);
    await _writeOne(_key('expires_at'), expiresAt.toIso8601String());
    AppLog.d(
      LogTag.token,
      () =>
          '🔐 saveTokens: serverId=$serverId access.len=${access.length} refresh.len=${refresh.length} expires=$expiresAt',
    );
  }

  Future<TokenData?> readTokens() async {
    // Serial reads to avoid platform concurrency hazards.
    final access = await _readOne(_key('access'));
    final refresh = await _readOne(_key('refresh'));
    final expiresAtStr = await _readOne(_key('expires_at'));
    AppLog.d(
      LogTag.token,
      () =>
          '🔐 readTokens: serverId=$serverId access=${access != null} refresh=${refresh != null} expires=${expiresAtStr ?? "null"}',
    );
    if (access == null || refresh == null || expiresAtStr == null) return null;
    return TokenData(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.parse(expiresAtStr),
    );
  }

  Future<void> clear() async {
    await _deleteOne(_key('access'));
    await _deleteOne(_key('refresh'));
    await _deleteOne(_key('expires_at'));
  }

  Future<void> saveRememberedCredential({
    required String email,
    required String password,
  }) async {
    await _writeOne(_key('remember_email'), email);
    await _writeOne(_key('remember_password'), password);
  }

  Future<RememberedCredential?> readRememberedCredential() async {
    final email = await _readOne(_key('remember_email'));
    final password = await _readOne(_key('remember_password'));
    if (email == null || password == null) return null;
    return RememberedCredential(email: email, password: password);
  }

  Future<void> clearRememberedCredential() async {
    await _deleteOne(_key('remember_email'));
    await _deleteOne(_key('remember_password'));
  }
}

@riverpod
SecureTokenStore secureTokenStore(Ref ref, String serverId) {
  return SecureTokenStore(serverId: serverId);
}
