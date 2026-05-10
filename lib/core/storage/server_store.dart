import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'server_store.freezed.dart';
part 'server_store.g.dart';

// ---------------------------------------------------------------------------
// ServerConfig (Freezed)
// ---------------------------------------------------------------------------

@freezed
class ServerConfig with _$ServerConfig {
  const factory ServerConfig({
    required String id,
    required String baseUrl,
    required String name,
    String? orgLogo,
  }) = _ServerConfig;

  factory ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$ServerConfigFromJson(json);
}

// ---------------------------------------------------------------------------
// ServerState
// ---------------------------------------------------------------------------

@freezed
class ServerState with _$ServerState {
  const factory ServerState({
    @Default([]) List<ServerConfig> servers,
    String? currentServerId,
  }) = _ServerState;
}

// ---------------------------------------------------------------------------
// ServerStoreNotifier
// ---------------------------------------------------------------------------

const _kServersKey = 'voce_servers';
const _kCurrentServerKey = 'voce_current_server';

@riverpod
class ServerStore extends _$ServerStore {
  @override
  Future<ServerState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kServersKey) ?? [];
    final servers = raw.map((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return ServerConfig.fromJson(map);
    }).toList();
    final currentId = prefs.getString(_kCurrentServerKey);
    return ServerState(servers: servers, currentServerId: currentId);
  }

  Future<void> addServer(ServerConfig server) async {
    final current = await future;
    final updated = [...current.servers, server];
    await _persist(updated, current.currentServerId);
    state = AsyncData(current.copyWith(servers: updated));
  }

  Future<void> removeServer(String id) async {
    final current = await future;
    final updated = current.servers.where((s) => s.id != id).toList();
    final newCurrentId =
        current.currentServerId == id ? null : current.currentServerId;
    await _persist(updated, newCurrentId);
    state = AsyncData(
        current.copyWith(servers: updated, currentServerId: newCurrentId));
  }

  Future<void> selectServer(String id) async {
    final current = await future;
    await _persist(current.servers, id);
    state = AsyncData(current.copyWith(currentServerId: id));
  }

  /// Replace the id of an existing server (and currentServerId if it matches),
  /// preserving baseUrl/name. Used after login/register to align the local
  /// server entry with the server-issued id without creating a duplicate.
  Future<void> replaceServerId({
    required String oldId,
    required String newId,
  }) async {
    if (oldId == newId) return;
    final current = await future;
    final updated = current.servers
        .map((s) => s.id == oldId ? s.copyWith(id: newId) : s)
        .toList();
    final newCurrent =
        current.currentServerId == oldId ? newId : current.currentServerId;
    await _persist(updated, newCurrent);
    state = AsyncData(
        current.copyWith(servers: updated, currentServerId: newCurrent));
  }

  List<ServerConfig> get list => state.valueOrNull?.servers ?? [];

  Future<void> _persist(
      List<ServerConfig> servers, String? currentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = servers.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_kServersKey, raw);
    if (currentId != null) {
      await prefs.setString(_kCurrentServerKey, currentId);
    } else {
      await prefs.remove(_kCurrentServerKey);
    }
  }
}
