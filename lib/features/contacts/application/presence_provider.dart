import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/sse_client.dart';
import '../../messages/domain/message_models.dart';

part 'presence_provider.g.dart';

/// Per-user online state.
///
/// Mirrors the web client's `users_state` / `users_state_changed` SSE handling
/// in `useStreaming`: we hold a `uid -> online` map that the avatar status dot
/// consults. The server only mentions a uid in `users_state` when it has a
/// non-default state — anyone absent is treated as offline (matches the web
/// behavior in `slices/users.ts: updateUsersStatus` where missing uids retain
/// their last value, which defaults to undefined/false).
@Riverpod(keepAlive: true)
class Presence extends _$Presence {
  @override
  Map<int, bool> build() {
    // Subscribe once; the map mutates as `users_state` / `users_state_changed`
    // events arrive over SSE.
    ref.listen(sseEventsProvider, (_, next) {
      next.whenData(_handle);
    });
    return const {};
  }

  void _handle(ChatEvent event) {
    if (event is! ChatEventUnknown) return;
    switch (event.type) {
      case 'users_state':
        _applySnapshot(event.raw);
        break;
      case 'users_state_changed':
        _applyChange(event.raw);
        break;
    }
  }

  void _applySnapshot(String raw) {
    final decoded = _decode(raw);
    if (decoded == null) return;
    final users = decoded['users'];
    if (users is! List) return;
    final next = <int, bool>{};
    for (final u in users) {
      if (u is! Map) continue;
      final uid = (u['uid'] as num?)?.toInt();
      if (uid == null) continue;
      next[uid] = u['online'] == true;
    }
    state = next;
  }

  void _applyChange(String raw) {
    final decoded = _decode(raw);
    if (decoded == null) return;
    final uid = (decoded['uid'] as num?)?.toInt();
    if (uid == null) return;
    final online = decoded['online'] == true;
    state = {...state, uid: online};
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return null;
  }
}

/// Whether the server admin has enabled per-user online dots.
///
/// Mirrors `store.server.show_user_online_status` from the web client. Updated
/// from `server_config_changed` SSE events. Defaults to `true` so first paint
/// shows the dots until the server tells us otherwise.
@Riverpod(keepAlive: true)
class ShowOnlineStatus extends _$ShowOnlineStatus {
  @override
  bool build() {
    ref.listen(sseEventsProvider, (_, next) {
      next.whenData((event) {
        if (event is ChatEventServerConfigChanged) {
          final flag = event.data['show_user_online_status'];
          if (flag is bool) state = flag;
        }
      });
    });
    return true;
  }
}
