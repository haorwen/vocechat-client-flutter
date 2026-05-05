import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentServerKey, id);
    state = AsyncData(current.copyWith(currentServerId: id));
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
