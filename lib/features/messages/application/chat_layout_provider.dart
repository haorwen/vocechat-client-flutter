import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/server_store.dart';

part 'chat_layout_provider.g.dart';

enum ChatLayoutMode { left, selfRight }

/// Server-wide message placement, shared with the web client's chat layout.
/// The dispatcher applies both the initial snapshot and live config changes.
@Riverpod(keepAlive: true)
class ChatLayout extends _$ChatLayout {
  @override
  ChatLayoutMode build() {
    // A different server must not inherit the previous server's layout while
    // waiting for its initial server_config_changed event.
    ref.watch(serverStoreProvider.select(
      (value) => value.valueOrNull?.currentServerId,
    ));
    return ChatLayoutMode.left;
  }

  void applyConfig(Map<String, dynamic> config) {
    final mode = config['chat_layout_mode'];
    // Config events are partial: omitted/null fields mean no change.
    if (mode == null) return;
    state =
        mode == 'SelfRight' ? ChatLayoutMode.selfRight : ChatLayoutMode.left;
  }
}
