import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/chat_controller.dart';
import 'package:vocechat_client/features/messages/application/read_index_provider.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/messages/presentation/chat_header_details.dart';
import 'package:vocechat_client/features/messages/presentation/chat_screen.dart';
import 'package:vocechat_client/features/messages/presentation/composer_emoji_picker.dart';
import 'package:vocechat_client/features/messages/presentation/pinned_message_bar.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

const _name = 'A community with a very long group name that needs two lines';
final _description =
    List.filled(30, 'A complete community introduction.').join('\n');
const _target = MessageTarget.group(gid: 42);

PinnedMessageSummary _pin(int mid) => PinnedMessageSummary(
    mid: mid,
    content: 'Pinned message $mid',
    contentType: 'text/plain',
    createdBy: 8,
    createdAt: mid);

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 7, name: 'Me'));
}

class _Servers extends ServerStore {
  @override
  Future<ServerState> build() async => const ServerState();
}

class _Users extends UserDirectory {
  @override
  Future<Map<int, UserSummary>> build() async =>
      const {8: UserSummary(uid: 8, name: 'Peer')};
}

class _Groups extends GroupDirectory {
  @override
  Future<Map<int, GroupSummary>> build() async => {
        42: GroupSummary(
            gid: 42,
            name: _name,
            description: _description,
            pinnedMessages: [_pin(10), _pin(20)]),
      };
}

class _ReadIndex extends ReadIndex {
  @override
  Future<ReadIndexState> build() async => const ReadIndexState();
  @override
  void setGroup(int gid, int mid) {}
}

class _Chat extends ChatController {
  final located = <int>[];
  ChatMessage message(int mid) => ChatMessage(
      mid: mid,
      fromUid: 8,
      createdAt: 1000,
      target: _target,
      detail: MessageDetail.normal(
          contentType: 'text/plain', content: 'Message $mid'));
  @override
  Future<List<ChatMessage>> build(MessageTarget target) async => [message(30)];
  @override
  Future<void> loadMore() async {}
  @override
  Future<bool> ensureMessageLoaded(int mid,
      {bool Function()? shouldContinue}) async {
    located.add(mid);
    state = AsyncData([message(30), message(mid)]);
    return true;
  }
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  Future<ProviderContainer> pumpChat(WidgetTester tester,
      {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      serverStoreProvider.overrideWith(_Servers.new),
      userDirectoryProvider.overrideWith(_Users.new),
      groupDirectoryProvider.overrideWith(_Groups.new),
      readIndexProvider.overrideWith(_ReadIndex.new),
      chatControllerProvider(_target).overrideWith(_Chat.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _app(const ChatScreen(id: 'g-42')),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('composer emoji button inserts at caret and replaces selection',
      (tester) async {
    await pumpChat(tester);
    final input = find.byType(TextField);
    await tester.enterText(input, 'hello world');
    final controller = tester.widget<TextField>(input).controller!;
    controller.selection = const TextSelection.collapsed(offset: 6);
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposerEmojiPicker), findsOneWidget);
    await tester.tap(find.text('😀'));
    await tester.pumpAndSettle();
    expect(controller.text, 'hello 😀world');
    expect(controller.selection.baseOffset, 8);
    controller.selection = const TextSelection(baseOffset: 8, extentOffset: 13);
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🥰'));
    await tester.pumpAndSettle();
    expect(controller.text, 'hello 😀🥰');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('long group title and full introduction at width $width',
        (tester) async {
      await pumpChat(tester, width: width);
      final title = tester.widget<Text>(find.text(_name));
      expect(title.maxLines, 2);
      expect(tester.getTopLeft(find.byType(PinnedMessageBar)).dy,
          greaterThan(tester.getBottomLeft(find.byType(ChatHeaderDetails)).dy));
      await tester.tap(find.byType(ChatHeaderDetails));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SelectableText, _name), findsOneWidget);
      expect(find.widgetWithText(SelectableText, _description), findsOneWidget);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pin bar cycles, locates, highlights and opens the full pin list',
      (tester) async {
    final container = await pumpChat(tester);
    final chat =
        container.read(chatControllerProvider(_target).notifier) as _Chat;
    expect(find.text('Pinned message 20'), findsOneWidget);
    await tester.tap(find.text('Pinned message 20'));
    await tester.pumpAndSettle();
    expect(chat.located, [20]);
    expect(find.text('Message 20'), findsOneWidget);
    expect(
        tester
            .widgetList<MessageRow>(find.byType(MessageRow))
            .any((row) => row.message.mid == 20 && row.highlighted),
        isTrue);
    expect(find.text('Pinned message 10'), findsOneWidget);
    await tester.tap(find.text('Pinned message 10'));
    await tester.pumpAndSettle();
    expect(chat.located, [20, 10]);
    await tester.tap(find.byIcon(Icons.format_list_bulleted));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pinned message 10').last);
    await tester.pumpAndSettle();
    expect(chat.located, [20, 10, 10]);
    expect(tester.takeException(), isNull);
    // Clear the temporary highlight before the test ends.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('pin bar updates and disappears after pins are removed',
      (tester) async {
    final container = await pumpChat(tester);
    final groups = container.read(groupDirectoryProvider.notifier);
    groups.applyPinned(42, [_pin(5)]);
    await tester.pumpAndSettle();
    expect(find.text('Pinned message 5'), findsOneWidget);
    groups.applyPinned(42, []);
    await tester.pumpAndSettle();
    expect(find.byType(PinnedMessageBar), findsNothing);
  });
}
