import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../domain/pin_chat_models.dart';

part 'pin_chat_api.g.dart';

/// Thin wrapper around the two pin endpoints. Both go through `dioProvider`
/// so auth header + retry + 401-refresh apply.
///
/// Server contract (from `vocechat-server/src/api/user.rs`):
///
///   POST /api/user/pin_chat   body: `{"target": {"uid": <int>}}` or `{"gid": ...}`
///   POST /api/user/unpin_chat body: same
///
/// 2xx means the server accepted; it then broadcasts a
/// `user_settings_changed` event with `add_pin_chats` / `remove_pin_chats`
/// that the SSE dispatcher applies to local state. We do NOT mutate the
/// `pinnedChatsProvider` from here — let the event echo do it so all
/// devices see the same sequence.
class PinChatApi {
  PinChatApi(this._dio);
  final Dio _dio;

  Future<void> pin(PinChatTarget target) async {
    await _dio.post(
      '/api/user/pin_chat',
      data: {'target': target.toJson()},
    );
  }

  Future<void> unpin(PinChatTarget target) async {
    await _dio.post(
      '/api/user/unpin_chat',
      data: {'target': target.toJson()},
    );
  }
}

@riverpod
PinChatApi pinChatApi(Ref ref) {
  final dio = ref.watch(dioProvider);
  return PinChatApi(dio);
}
