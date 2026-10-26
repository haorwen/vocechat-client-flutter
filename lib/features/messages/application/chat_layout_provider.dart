import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/utils/app_log.dart';

part 'chat_layout_provider.g.dart';

enum ChatLayoutMode { left, selfRight }

/// Server-wide message placement, shared with the web client's chat layout.
/// The dispatcher applies both the initial snapshot and live config changes.
@Riverpod(keepAlive: true)
class ChatLayout extends _$ChatLayout {
  Object _scope = Object();
  int _revision = 0;
  Future<void> _writes = Future.value();

  String _key(String serverId) => 'voce_chat_layout_$serverId';

  @override
  ChatLayoutMode build() {
    final serverId = ref.watch(serverStoreProvider.select(
      (value) => value.valueOrNull?.currentServerId,
    ));
    final scope = _scope = Object();
    final revision = _revision;
    ref.onDispose(() {
      if (_scope == scope) _scope = Object();
    });
    if (serverId != null) {
      unawaited(_restore(serverId, scope, revision));
    }
    return ChatLayoutMode.left;
  }

  Future<void> _restore(String serverId, Object scope, int revision) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_scope != scope || _revision != revision) return;
      final saved = prefs.getString(_key(serverId));
      if (saved != null) {
        state = saved == 'SelfRight'
            ? ChatLayoutMode.selfRight
            : ChatLayoutMode.left;
      }
    } catch (error) {
      AppLog.w(LogTag.chat, () => 'Chat layout cache unavailable: $error');
    }
  }

  void applyConfig(Map<String, dynamic> config) {
    final mode = config['chat_layout_mode'];
    // Config events are partial: omitted/null fields mean no change.
    if (mode == null) return;
    _revision++;
    state =
        mode == 'SelfRight' ? ChatLayoutMode.selfRight : ChatLayoutMode.left;
    final serverId = ref.read(serverStoreProvider).valueOrNull?.currentServerId;
    if (serverId == null) return;
    final saved = state == ChatLayoutMode.selfRight ? 'SelfRight' : 'Left';
    // Serialize writes so rapid live changes cannot persist in reverse order.
    _writes = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(serverId), saved);
    }).catchError((Object error) {
      AppLog.w(LogTag.chat, () => 'Chat layout save deferred: $error');
    });
  }
}
