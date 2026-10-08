import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:vocechat_client/features/messages/presentation/mention_text.dart';
import 'package:vocechat_client/features/messages/presentation/message_links.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';

class _Launcher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;

  final opened = <String>[];
  final modes = <PreferredLaunchMode>[];
  final outcomes = <Object>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    modes.add(options.mode);
    if (outcomes.isNotEmpty) {
      final outcome = outcomes.removeAt(0);
      if (outcome is bool) return outcome;
      throw outcome;
    }
    return true;
  }
}

void main() {
  const nativeLinks = MethodChannel('vocechat/external_links');
  late _Launcher launcher;
  late UrlLauncherPlatform original;
  setUp(() {
    original = UrlLauncherPlatform.instance;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeLinks, (call) async => false);
  });
  tearDown(() {
    UrlLauncherPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeLinks, null);
  });

  testWidgets('Android link taps use the native browser bridge',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      nativeLinks,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MentionText(
          text: 'https://doc.voce.chat/bot/bot-and-webhook',
          userDir: {},
          style: TextStyle(fontSize: 14),
        ),
      ),
    ));
    await tester.tap(find.byType(MentionText));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'openUrl');
    expect(calls.single.arguments,
        {'url': 'https://doc.voce.chat/bot/bot-and-webhook'});
    expect(launcher.opened, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final nativeFailure in [
    false,
    PlatformException(code: 'ACTIVITY_NOT_FOUND'),
    PlatformException(code: 'channel-error'),
    MissingPluginException('Bridge unavailable'),
  ]) {
    test('Android falls back to url_launcher after native $nativeFailure',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeLinks, (call) async {
        if (nativeFailure is bool) return nativeFailure;
        throw nativeFailure;
      });
      await openMessageLink('https://example.com');
      expect(launcher.opened, ['https://example.com']);
      expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
    });
  }

  test('invalid schemes never reach the Android native bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeLinks, (call) async {
      calls.add(call);
      return true;
    });
    for (final href in [
      null,
      'javascript:alert(1)',
      'file:///tmp/test',
      'https:'
    ]) {
      await openMessageLink(href);
    }
    expect(calls, isEmpty);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('plain text URL opens browser and releases gesture handlers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MentionText(
          text: 'https://example.com/path?q=1',
          userDir: {},
          style: TextStyle(fontSize: 14),
        ),
      ),
    ));
    await tester.tap(find.byType(MentionText));
    await tester.pump();
    expect(launcher.opened, ['https://example.com/path?q=1']);
    expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('www links open with https', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MentionText(
          text: 'www.example.com',
          userDir: {},
          style: TextStyle(fontSize: 14),
        ),
      ),
    ));
    await tester.tap(find.byType(MentionText));
    await tester.pump();
    expect(launcher.opened, ['https://www.example.com']);
  });

  testWidgets('selectable text links open the browser', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MentionText(
          text: 'https://example.com',
          userDir: {},
          selectable: true,
          style: TextStyle(fontSize: 14),
        ),
      ),
    ));
    await tester.tap(find.byType(MentionText));
    await tester.pump();
    expect(launcher.opened, ['https://example.com']);
  });

  testWidgets('a rebuild during a touch does not cancel the link tap',
      (tester) async {
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return MentionText(
            text: 'https://example.com',
            userDir: const {},
            style: const TextStyle(fontSize: 14),
          );
        }),
      ),
    ));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(MentionText)));
    rebuild(() {});
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(launcher.opened, ['https://example.com']);
  });

  testWidgets('updated message text opens the current link', (tester) async {
    for (final url in [
      'https://example.com/first',
      'https://example.com/next'
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MentionText(
            text: url,
            userDir: const {},
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ));
      await tester.tap(find.byType(MentionText));
      await tester.pump();
    }
    expect(launcher.opened,
        ['https://example.com/first', 'https://example.com/next']);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain text stays literal while its URL is blue and clickable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MentionText(
          text:
              '*literal* @8 [Document](https://example.com/Test_(one) "Docs")!',
          userDir: {8: UserSummary(uid: 8, name: 'Peer')},
          style: TextStyle(fontSize: 14),
        ),
      ),
    ));
    final paragraph = tester.widget<RichText>(find.byType(RichText).first);
    const url = 'https://example.com/Test_(one)';
    final text = paragraph.text.toPlainText();
    expect(text, '*literal* @Peer [Document]($url "Docs")!');
    final start = text.indexOf(url);
    final link = paragraph.text.getSpanForPosition(TextPosition(offset: start))
        as TextSpan;
    expect(link.recognizer, isNotNull);
    expect(link.style?.color, Colors.blue);
    expect(link.style?.decoration, TextDecoration.underline);
    final box =
        tester.renderObject<RenderParagraph>(find.byType(RichText).first);
    final rect = box.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + url.length));
    await tester.tapAt(box.localToGlobal(rect.first.toRect().center));
    await tester.pump();
    expect(launcher.opened, [url]);
  });

  test('URL boundaries preserve balanced parentheses and exclude punctuation',
      () {
    expect(trimMessageLink('https://example.com/wiki/Test_(one).'),
        'https://example.com/wiki/Test_(one)');
    expect(trimMessageLink('https://example.com).'), 'https://example.com');
    expect(trimMessageLink('https://example.com)]'), 'https://example.com');
    expect(trimMessageLink('https://example.com.)'), 'https://example.com');
    expect(trimMessageLink('https://example.com/Test_(one).)]'),
        'https://example.com/Test_(one)');
    expect(messageLinkPattern.firstMatch('链接 https://example.com，看看')?.group(0),
        'https://example.com');
  });

  test('markdown callback opens web URLs and ignores invalid schemes',
      () async {
    await openMessageLink('https://example.com');
    await openMessageLink(null);
    await openMessageLink('javascript:alert(1)');
    await openMessageLink('file:///tmp/test');
    await openMessageLink('https:');
    expect(launcher.opened, ['https://example.com']);
  });

  for (final failure in [
    false,
    PlatformException(code: 'ACTIVITY_NOT_FOUND'),
    PlatformException(code: 'NO_ACTIVITY'),
    MissingPluginException('Plugin unavailable'),
  ]) {
    test('Android retries $failure with an in-app browser', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      launcher.outcomes.addAll([failure, true]);
      await openMessageLink('https://doc.voce.chat/bot/bot-and-webhook');
      expect(launcher.modes, [
        PreferredLaunchMode.externalApplication,
        PreferredLaunchMode.inAppBrowserView,
      ]);
      expect(launcher.opened, [
        'https://doc.voce.chat/bot/bot-and-webhook',
        'https://doc.voce.chat/bot/bot-and-webhook',
      ]);
    });
  }
}
