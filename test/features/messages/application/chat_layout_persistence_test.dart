import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/messages/application/chat_layout_provider.dart';

class _Servers extends ServerStore {
  @override
  Future<ServerState> build() async =>
      const ServerState(currentServerId: 'first');

  void select(String id) => state = AsyncData(ServerState(currentServerId: id));
}

Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> setup() async {
    final container = ProviderContainer(overrides: [
      serverStoreProvider.overrideWith(_Servers.new),
    ]);
    addTearDown(container.dispose);
    await container.read(serverStoreProvider.future);
    return container;
  }

  test('saved server layout is restored before live configuration arrives',
      () async {
    SharedPreferences.setMockInitialValues({});
    final first = await setup();
    first.read(chatLayoutProvider.notifier).applyConfig({
      'chat_layout_mode': 'SelfRight',
    });
    await _flush();
    final restarted = await setup();
    restarted.read(chatLayoutProvider);
    await _flush();
    expect(restarted.read(chatLayoutProvider), ChatLayoutMode.selfRight);
  });

  test('live config wins over an unfinished cache restore', () async {
    SharedPreferences.setMockInitialValues({
      'voce_chat_layout_first': 'SelfRight',
    });
    final container = await setup();
    container.read(chatLayoutProvider.notifier).applyConfig({
      'chat_layout_mode': 'Left',
    });
    await _flush();
    expect(container.read(chatLayoutProvider), ChatLayoutMode.left);
    expect(
        (await SharedPreferences.getInstance())
            .getString('voce_chat_layout_first'),
        'Left');
  });

  test('switching servers restores only that server layout', () async {
    SharedPreferences.setMockInitialValues({
      'voce_chat_layout_first': 'SelfRight',
      'voce_chat_layout_second': 'Left',
    });
    final container = await setup();
    container.read(chatLayoutProvider);
    await _flush();
    expect(container.read(chatLayoutProvider), ChatLayoutMode.selfRight);
    (container.read(serverStoreProvider.notifier) as _Servers).select('second');
    container.read(chatLayoutProvider);
    await _flush();
    expect(container.read(chatLayoutProvider), ChatLayoutMode.left);
  });
}
