import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

const _emojis = [
  '😀',
  '😃',
  '😄',
  '😁',
  '😆',
  '😅',
  '😂',
  '🤣',
  '😊',
  '🥰',
  '😍',
  '😘',
  '😎',
  '🤩',
  '🥳',
  '🙂',
  '😉',
  '🙃',
  '😋',
  '😛',
  '🤪',
  '🤗',
  '🤭',
  '🫣',
  '🤔',
  '🫡',
  '🤫',
  '😐',
  '🙄',
  '😏',
  '😴',
  '🤤',
  '😢',
  '😭',
  '🥹',
  '🥺',
  '😤',
  '😡',
  '🤯',
  '😱',
  '😨',
  '😳',
  '🫠',
  '🤒',
  '🤕',
  '🤢',
  '🤮',
  '😷',
  '👍',
  '👎',
  '👏',
  '🙌',
  '🤝',
  '🙏',
  '💪',
  '✌️',
  '👌',
  '🤞',
  '👋',
  '🫶',
  '❤️',
  '🧡',
  '💛',
  '💚',
  '💙',
  '💜',
  '🖤',
  '🤍',
  '💔',
  '💕',
  '💯',
  '🔥',
  '✨',
  '⭐',
  '🌟',
  '🎉',
  '🎊',
  '🎁',
  '🏆',
  '🥇',
  '🎂',
  '🍰',
  '☕',
  '🍵',
  '🍻',
  '🥂',
  '🍕',
  '🍔',
  '🐶',
  '🐱',
  '🐼',
  '🐻',
  '🐰',
  '🦊',
  '🌹',
  '🌻',
  '🌈',
  '☀️',
  '🌙',
  '⚡',
  '🚀',
  '🎯',
  '✅',
  '❌',
];

Future<String?> showComposerEmojiPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 440),
    builder: (_) => ComposerEmojiPicker(
      onSelected: (emoji) => Navigator.of(context).pop(emoji),
    ),
  );
}

class ComposerEmojiPicker extends StatelessWidget {
  const ComposerEmojiPicker({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 320,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(children: [
              Expanded(
                child: Text(l.chatEmoji,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: l.actionClose,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 48),
              itemCount: _emojis.length,
              itemBuilder: (context, index) {
                final emoji = _emojis[index];
                return Semantics(
                  button: true,
                  label: emoji,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelected(emoji),
                    child: Center(
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 26))),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
