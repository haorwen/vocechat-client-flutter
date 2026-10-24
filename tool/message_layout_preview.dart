import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocechat_client/core/theme/app_theme.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/chat_layout_provider.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/messages/presentation/chat_screen.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

// Flutter 3.27 predates widget_previews. This preview uses the actual message
// rows with local data, without a server or sign-in:
// flutter run -t tool/message_layout_preview.dart -d linux
void main() => runApp(ProviderScope(
      overrides: [chatLayoutProvider.overrideWith(_PreviewLayout.new)],
      child: const MessageLayoutPreview(),
    ));

class _PreviewLayout extends ChatLayout {
  @override
  ChatLayoutMode build() => ChatLayoutMode.selfRight;
}

class MessageLayoutPreview extends StatelessWidget {
  const MessageLayoutPreview({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: AppTheme.lightTheme,
        home: const _PreviewScreen(),
      );
}

class _PreviewScreen extends ConsumerStatefulWidget {
  const _PreviewScreen();

  @override
  ConsumerState<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<_PreviewScreen> {
  double _textScale = 1;

  static const _users = {
    7: UserSummary(uid: 7, name: '张一诚'),
    8: UserSummary(uid: 8, name: 'admin'),
  };
  static const _target = MessageTarget.group(gid: 42);
  static const _samples = [
    (uid: 7, text: '只要大退了点进来就要转圈', type: 'text/plain'),
    (uid: 8, text: '这个要做大群吗，不要聊太多，后面进来的都可以看到历史记录😀', type: 'text/plain'),
    (uid: 7, text: '没事，明天主管理号再建个新的', type: 'text/plain'),
    (
      uid: 8,
      text: '**Markdown** 长消息也应该在对面头像前换行，给左右两侧留出一致的阅读空间。',
      type: 'text/markdown'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final split = ref.watch(chatLayoutProvider) == ChatLayoutMode.selfRight;
    return Scaffold(
      appBar: AppBar(title: const Text('消息换行预览')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('左右布局'),
                value: split,
                onChanged: (value) =>
                    ref.read(chatLayoutProvider.notifier).applyConfig({
                  'chat_layout_mode': value ? 'SelfRight' : 'Left',
                }),
              ),
              Slider(
                value: _textScale,
                min: 0.85,
                max: 1.3,
                divisions: 9,
                label: '${(_textScale * 100).round()}%',
                onChanged: (value) => setState(() => _textScale = value),
              ),
              Expanded(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(_textScale),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final (index, sample) in _samples.indexed)
                        MessageRow(
                          message: ChatMessage(
                            mid: -index - 1,
                            fromUid: sample.uid,
                            createdAt:
                                DateTime(2026, 10, 23).millisecondsSinceEpoch,
                            target: _target,
                            detail: MessageDetail.normal(
                              contentType: sample.type,
                              content: sample.text,
                            ),
                          ),
                          currentUid: 7,
                          userDir: _users,
                          avatarUrlBuilder: (_, __) => null,
                          target: _target,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
