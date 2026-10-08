import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/chat_controller.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/messages/presentation/chat_screen.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

const _target = MessageTarget.group(gid: 42);
const _url = 'https://example.com/docs';
const _users = {
  7: UserSummary(uid: 7, name: 'Me'),
  8: UserSummary(uid: 8, name: 'Peer'),
};

ChatMessage _message(MessageDetail detail) => ChatMessage(
      mid: 10,
      fromUid: 8,
      createdAt: 1000,
      target: _target,
      detail: detail,
    );

class _Servers extends ServerStore {
  @override
  Future<ServerState> build() async =>
      const ServerState(currentServerId: 'first');
}

class _Chat extends ChatController {
  @override
  Future<List<ChatMessage>> build(MessageTarget target) async => [
        _message(const MessageDetail.normal(
                contentType: 'text/plain', content: 'Original message'))
            .copyWith(mid: 8),
      ];
}

class _Launcher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;

  final opened = <String>[];
  final outcomes = <bool>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return outcomes.isEmpty ? true : outcomes.removeAt(0);
  }
}

void main() {
  const nativeLinks = MethodChannel('vocechat/external_links');
  late ProviderContainer container;
  late _Launcher launcher;
  late UrlLauncherPlatform original;

  setUp(() async {
    original = UrlLauncherPlatform.instance;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeLinks, (call) async => false);
    container = ProviderContainer(overrides: [
      serverStoreProvider.overrideWith(_Servers.new),
      chatControllerProvider(_target).overrideWith(_Chat.new),
    ]);
    await container.read(serverStoreProvider.future);
    await container.read(chatControllerProvider(_target).future);
  });

  tearDown(() {
    container.dispose();
    UrlLauncherPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeLinks, null);
  });

  Future<void> pumpRow(WidgetTester tester, ChatMessage message,
      {bool selecting = false, VoidCallback? onToggleSelect}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: MessageRow(
            message: message,
            currentUid: 7,
            userDir: _users,
            avatarUrlBuilder: (_, __) => null,
            target: _target,
            selecting: selecting,
            onToggleSelect: onToggleSelect,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Finder label(String text) => find.text(text, findRichText: true);

  for (final contentType in [
    'text/markdown',
    'text/plain',
    'Text/Markdown; charset=utf-8',
  ]) {
    testWidgets(
        'demo bot $contentType preserves its format and opens a blue link',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const url = 'https://doc.voce.chat/bot/bot-and-webhook';
      await pumpRow(
          tester,
          _message(MessageDetail.normal(
            contentType: contentType,
            content: 'I am ChatGPT 6.0.\n\n'
                'This is a demo bot, you can easily host a bot at your own '
                'VoceChat. Check [Document]($url).',
          )));
      final plain = contentType == 'text/plain';
      final expected = plain ? 'Check [Document]($url).' : 'Check Document.';
      final paragraphFinder = find.byWidgetPredicate((widget) =>
          widget is RichText && widget.text.toPlainText().contains(expected));
      expect(paragraphFinder, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
      final linkText = plain ? url : 'Document';
      final start = paragraph.text.toPlainText().indexOf(linkText);
      if (plain) {
        final title = paragraph.text.getSpanForPosition(TextPosition(
                offset: paragraph.text.toPlainText().indexOf('Document')))
            as TextSpan;
        expect(title.recognizer, isNull);
      }
      final link = paragraph.text
          .getSpanForPosition(TextPosition(offset: start)) as TextSpan;
      expect(link.recognizer, isNotNull);
      expect(link.style?.color, Colors.blue);
      expect(link.style?.decoration, TextDecoration.underline);
      final box = paragraph.getBoxesForSelection(TextSelection(
          baseOffset: start, extentOffset: start + linkText.length));
      await tester.tapAt(paragraph.localToGlobal(box.first.toRect().center));
      await tester.pump();
      expect(launcher.opened, [url]);
    });
  }

  for (final kind in ['normal', 'reply', 'edited']) {
    for (final syntax in ['title', 'autolink']) {
      testWidgets('$kind Markdown $syntax link opens its destination',
          (tester) async {
        final markdown =
            syntax == 'title' ? '[Documentation]($_url)' : '<$_url>';
        final detail = kind == 'reply'
            ? MessageDetail.reply(
                mid: 8, contentType: 'text/markdown', content: markdown)
            : MessageDetail.normal(
                contentType: 'text/markdown', content: markdown);
        var message = _message(detail);
        if (kind == 'edited') {
          message = _message(const MessageDetail.reply(
                  mid: 8, contentType: 'text/plain', content: 'Before edit'))
              .copyWith(
                  editedContent: markdown, editedContentType: 'text/markdown');
        }
        await pumpRow(tester, message);
        final link = label(syntax == 'title' ? 'Documentation' : _url);
        expect(link, findsOneWidget);
        await tester.tap(link);
        await tester.pump();
        expect(launcher.opened, [_url]);
      });
    }
  }

  testWidgets('plain text link opens from a message row', (tester) async {
    await pumpRow(
        tester,
        _message(const MessageDetail.normal(
            contentType: 'text/plain', content: _url)));
    await tester.tap(label(_url));
    await tester.pump();
    expect(launcher.opened, [_url]);
  });

  testWidgets('Markdown browser failure offers to copy the link',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    launcher.outcomes.addAll([false, false]);
    await pumpRow(
        tester,
        _message(const MessageDetail.normal(
            contentType: 'text/markdown', content: '[Documentation]($_url)')));
    await tester.tap(label('Documentation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
        find.text(
            'Could not open the link. Try again or copy it into your browser.'),
        findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, _url);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final contentType in ['text/plain', 'text/markdown']) {
    testWidgets('$contentType link tap selects the row in selection mode',
        (tester) async {
      var toggles = 0;
      final content =
          contentType == 'text/markdown' ? '[Documentation]($_url)' : _url;
      await pumpRow(
          tester,
          _message(
              MessageDetail.normal(contentType: contentType, content: content)),
          selecting: true,
          onToggleSelect: () => toggles++);
      // Selection deliberately absorbs the link's own pointer events.
      await tester.tapAt(tester.getCenter(
          label(contentType == 'text/markdown' ? 'Documentation' : _url)));
      await tester.pump();
      expect(toggles, 1);
      expect(launcher.opened, isEmpty);
    });

    testWidgets('$contentType link survives a parent rebuild during a tap',
        (tester) async {
      final content =
          contentType == 'text/markdown' ? '[Documentation]($_url)' : _url;
      final message = _message(
          MessageDetail.normal(contentType: contentType, content: content));
      await pumpRow(tester, message);
      final link =
          label(contentType == 'text/markdown' ? 'Documentation' : _url);
      final gesture = await tester.startGesture(tester.getCenter(link));
      await pumpRow(tester, message);
      await gesture.up();
      await tester.pump();
      expect(launcher.opened, [_url]);
    });
  }
}
