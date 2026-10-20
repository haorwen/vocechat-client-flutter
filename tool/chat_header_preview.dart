import 'package:flutter/material.dart';
import 'package:vocechat_client/features/messages/presentation/chat_header_details.dart';
import 'package:vocechat_client/features/messages/presentation/composer_emoji_picker.dart';
import 'package:vocechat_client/features/messages/presentation/pinned_message_bar.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

// Flutter 3.27 has no widget_previews API. This isolated preview works with
// the repository SDK and requires no server, sign-in or native plugins.
// flutter run -t tool/chat_header_preview.dart -d chrome
void main() => runApp(const ChatHeaderPreview());

class ChatHeaderPreview extends StatelessWidget {
  const ChatHeaderPreview({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const _PreviewScreen(),
      );
}

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen();
  static const name = 'VoceChat 开发者与用户交流群 · 一起分享有趣的项目和日常';
  static const description = '欢迎加入社区！\n在这里交流项目、提出问题，也欢迎分享你的作品。\n'
      '请尊重每一位成员，友善讨论。\n\n这是一段完整的群介绍，点击标题区域即可阅读全文。';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(children: [
                Row(children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.tag),
                  ),
                  Expanded(
                    child: ChatHeaderDetails(
                      title: name,
                      subtitle: description,
                      isChannel: true,
                      onTap: () => showGroupIntroduction(context,
                          name: name, description: description),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.more_horiz),
                  ),
                ]),
                PinnedMessageBar(
                  messages: const [
                    (mid: 20, text: '本周五 20:00 社区线上交流，欢迎参加！'),
                    (mid: 10, text: '欢迎新朋友，请先阅读群介绍。'),
                  ],
                  onLocate: (mid) => ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('定位到消息 $mid'))),
                  onShowAll: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(
                        title: Text('置顶消息'),
                        content: Text('本周五 20:00 社区线上交流，欢迎参加！\n\n'
                            '欢迎新朋友，请先阅读群介绍。')),
                  ),
                ),
                const Spacer(),
                ComposerEmojiPicker(
                  onSelected: (emoji) => ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(emoji))),
                ),
              ]),
            ),
          ),
        ),
      );
}
