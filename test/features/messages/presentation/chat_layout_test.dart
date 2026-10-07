import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/sse_client.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/contacts/application/presence_provider.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/chat_controller.dart';
import 'package:vocechat_client/features/messages/application/chat_layout_provider.dart';
import 'package:vocechat_client/features/messages/application/message_dispatcher.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/messages/domain/message_status.dart';
import 'package:vocechat_client/features/messages/presentation/chat_screen.dart';
import 'package:vocechat_client/features/messages/presentation/mention_text.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';
import 'package:vocechat_client/shared/widgets/voce_avatar.dart';

const _users = {
  7: UserSummary(uid: 7, name: 'Me'),
  8: UserSummary(uid: 8, name: 'Peer'),
};
const _group = MessageTarget.group(gid: 42);
const _dm = MessageTarget.user(uid: 8);

ChatMessage _message(int uid, MessageTarget target,
        {int? mid, MessageDetail? detail}) =>
    ChatMessage(
      mid: mid ?? uid,
      fromUid: uid,
      createdAt: 1000,
      target: target,
      detail: detail ??
          MessageDetail.normal(
              contentType: 'text/plain', content: 'Hello $uid'),
    );

class _Servers extends ServerStore {
  @override
  Future<ServerState> build() async =>
      const ServerState(currentServerId: 'first');

  void switchServer() =>
      state = const AsyncData(ServerState(currentServerId: 'second'));

  void renameServer() => state = const AsyncData(ServerState(
        currentServerId: 'first',
        servers: [
          ServerConfig(
              id: 'first', baseUrl: 'https://chat.test', name: 'Renamed')
        ],
      ));
}

class _Chat extends ChatController {
  @override
  Future<List<ChatMessage>> build(MessageTarget target) async =>
      [_message(8, target)];
}

void main() {
  late ProviderContainer container;
  late StreamController<ChatEvent> events;

  setUp(() async {
    events = StreamController<ChatEvent>();
    container = ProviderContainer(overrides: [
      serverStoreProvider.overrideWith(_Servers.new),
      sseEventsProvider.overrideWith((ref) => events.stream),
      chatControllerProvider(_group).overrideWith(_Chat.new),
      chatControllerProvider(_dm).overrideWith(_Chat.new),
    ]);
    container.listen(serverStoreProvider, (_, __) {});
    await container.read(serverStoreProvider.future);
    container.read(messageDispatcherProvider);
  });

  tearDown(() async {
    container.dispose();
    await events.close();
  });

  Future<void> config(WidgetTester tester, Map<String, dynamic> data) async {
    events.add(ChatEvent.serverConfigChanged(data: data));
    // Deliver the stream event, then render the frame scheduled by Riverpod.
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpRows(WidgetTester tester, MessageTarget target,
      {MessageDetail? detail,
      MessageSendStatus? status,
      bool selecting = false,
      VoidCallback? onToggleSelect}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Column(children: [
            for (final uid in [7, 8])
              MessageRow(
                key: ValueKey(uid),
                message: _message(uid, target,
                    mid: status == null ? uid : -uid, detail: detail),
                currentUid: 7,
                userDir: _users,
                avatarUrlBuilder: (_, __) => null,
                target: target,
                status: status,
                selecting: selecting,
                onToggleSelect: onToggleSelect,
              ),
          ]),
        ),
      ),
    ));
    await tester.pump();
  }

  Finder within(int uid, Finder child) =>
      find.descendant(of: find.byKey(ValueKey(uid)), matching: child);

  void expectPlacement(WidgetTester tester, int uid, {required bool right}) {
    final row = tester.getRect(find.byKey(ValueKey(uid)));
    final avatar = tester.getRect(within(uid, find.byType(VoceAvatar)).first);
    final name =
        tester.getRect(within(uid, find.text(_users[uid]!.name)).first);
    if (right) {
      expect(avatar.right, closeTo(row.right - 8, 0.01));
      expect(name.right, closeTo(avatar.left - 16, 0.01));
    } else {
      expect(avatar.left, closeTo(row.left + 8, 0.01));
      expect(name.left, closeTo(avatar.right + 16, 0.01));
    }
    final content = within(uid, find.byType(MentionText)).last;
    final contentRect = tester.getRect(content);
    expect(right ? contentRect.right : contentRect.left,
        closeTo(right ? name.right : name.left, 0.01));
    // Reordering the row must not reverse the text's reading direction.
    expect(Directionality.of(tester.element(content)), TextDirection.ltr);
  }

  for (final target in [_dm, _group]) {
    testWidgets('$target follows initial and live layout updates',
        (tester) async {
      await pumpRows(tester, target);
      expectPlacement(tester, 7, right: false);
      expectPlacement(tester, 8, right: false);

      await config(tester, {'chat_layout_mode': 'SelfRight'});
      expectPlacement(tester, 7, right: true);
      expectPlacement(tester, 8, right: false);

      // Other admin settings (including serialized nulls) are partial updates.
      await config(tester, {'show_user_online_status': false});
      await config(tester, {'chat_layout_mode': null});
      expectPlacement(tester, 7, right: true);
      expect(container.read(showOnlineStatusProvider), isFalse);

      await config(tester, {'chat_layout_mode': 'Left'});
      expectPlacement(tester, 7, right: false);
      expectPlacement(tester, 8, right: false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('config received before opening a chat is retained',
      (tester) async {
    await config(tester, {'chat_layout_mode': 'SelfRight'});
    await pumpRows(tester, _group);
    expectPlacement(tester, 7, right: true);

    (container.read(serverStoreProvider.notifier) as _Servers).renameServer();
    await tester.pump();
    expectPlacement(tester, 7, right: true);

    (container.read(serverStoreProvider.notifier) as _Servers).switchServer();
    await tester.pump();
    expectPlacement(tester, 7, right: false);
    await config(tester, {'chat_layout_mode': 'SelfRight'});
    expectPlacement(tester, 7, right: true);
  });

  testWidgets('unknown layout falls back to the web default', (tester) async {
    await config(tester, {'chat_layout_mode': 'SelfRight'});
    await config(tester, {'chat_layout_mode': 'FutureLayout'});
    expect(container.read(chatLayoutProvider), ChatLayoutMode.left);
  });

  testWidgets('reply quote and body move with their sender', (tester) async {
    await container.read(chatControllerProvider(_group).future);
    await pumpRows(tester, _group,
        detail: const MessageDetail.reply(
            mid: 8, contentType: 'text/plain', content: 'A reply'));
    await config(tester, {'chat_layout_mode': 'SelfRight'});
    expectPlacement(tester, 7, right: true);
    expectPlacement(tester, 8, right: false);
    final quote = within(7, find.byType(VoceAvatar)).last;
    final originalPosition = tester.getTopLeft(quote);
    await config(tester, {'chat_layout_mode': 'Left'});
    expect(tester.getTopLeft(quote).dx, lessThan(originalPosition.dx));
    expect(tester.takeException(), isNull);
  });

  for (final status in [MessageSendStatus.sending, MessageSendStatus.failed]) {
    testWidgets('$status messages follow layout changes', (tester) async {
      await pumpRows(tester, _dm, status: status);
      await config(tester, {'chat_layout_mode': 'SelfRight'});
      expectPlacement(tester, 7, right: true);
      expectPlacement(tester, 8, right: false);
      await config(tester, {'chat_layout_mode': 'Left'});
      expectPlacement(tester, 7, right: false);
    });
  }

  testWidgets('selection still toggles after changing layout', (tester) async {
    var toggles = 0;
    await pumpRows(tester, _group,
        selecting: true, onToggleSelect: () => toggles++);
    await config(tester, {'chat_layout_mode': 'SelfRight'});
    await tester.tapAt(tester.getCenter(within(7, find.byType(MentionText))));
    expect(toggles, 1);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
