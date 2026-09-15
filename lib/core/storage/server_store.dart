import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_log.dart';
import 'preference_write.dart';

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
    // OrganizationInfo.server_id comes from the server's database config.
    // LoginResponse.server_id (used by id/account/token keys) comes from
    // key.json. They are independently generated and must never be compared.
    @JsonKey(name: 'organization_server_id') String? organizationServerId,
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
    bootLog('2 ServerStore.build: SharedPreferences.getInstance');
    final prefs = await SharedPreferences.getInstance();
    bootLog('3 ServerStore.build: prefs ready');
    final raw = prefs.getStringList(_kServersKey) ?? [];
    final servers = raw.map((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return ServerConfig.fromJson(map);
    }).toList();
    final currentId = prefs.getString(_kCurrentServerKey);
    bootLog(
        '4 ServerStore.build: done servers=${servers.length} currentId=$currentId');
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

  /// Record only the identity returned by /admin/system/organization. This
  /// must not move the server/account/token namespace used by login responses.
  Future<void> setOrganizationServerId(String id, String organizationId) async {
    final current = await future;
    final updated = current.servers
        .map((server) => server.id == id
            ? server.copyWith(organizationServerId: organizationId)
            : server)
        .toList();
    await _persist(updated, current.currentServerId);
    state = AsyncData(current.copyWith(servers: updated));
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

  Future<void> _persist(List<ServerConfig> servers, String? currentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = servers.map((s) => jsonEncode(s.toJson())).toList();
    await requirePreferenceWrite(prefs, prefs.setStringList(_kServersKey, raw));
    if (currentId != null) {
      await requirePreferenceWrite(
          prefs, prefs.setString(_kCurrentServerKey, currentId));
    } else {
      await requirePreferenceWrite(prefs, prefs.remove(_kCurrentServerKey));
    }
  }
}
