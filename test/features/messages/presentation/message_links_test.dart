import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:vocechat_client/features/messages/presentation/mention_text.dart';
import 'package:vocechat_client/features/messages/presentation/message_links.dart';

class _Launcher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;

  final opened = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    expect(options.mode, PreferredLaunchMode.externalApplication);
    opened.add(url);
    return true;
  }
}

void main() {
  late _Launcher launcher;
  late UrlLauncherPlatform original;
  setUp(() {
    original = UrlLauncherPlatform.instance;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
  });
  tearDown(() => UrlLauncherPlatform.instance = original);

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

  test('URL boundaries preserve balanced parentheses and exclude punctuation',
      () {
    expect(trimMessageLink('https://example.com/wiki/Test_(one).'),
        'https://example.com/wiki/Test_(one)');
    expect(trimMessageLink('https://example.com).'), 'https://example.com');
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
}
