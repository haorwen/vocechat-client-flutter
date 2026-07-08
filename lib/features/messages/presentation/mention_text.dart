import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../domain/mention_utils.dart';

// ---------------------------------------------------------------------------
// MentionText — renders plain message text with ` @{uid} ` tokens replaced by
// the resolved user's display name in the primary color (bold).
//
// Web behavior (components/LinkifyText.tsx + linkify-plugin-mention):
// tokenizes `@`+digits chunks bounded by whitespace and renders
// `@{name}` in the accent color. Unknown uids fall back to showing the raw
// `@{uid}` token (matches how the rest of this codebase falls back to a
// numeric id via `chatUserFallback` rather than hiding content).
// ---------------------------------------------------------------------------

class MentionText extends StatelessWidget {
  const MentionText({
    super.key,
    required this.text,
    required this.userDir,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final Map<int, UserSummary> userDir;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final matches = findMentions(text);
    if (matches.isEmpty) {
      return Text(
        safeText(text),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final mentionStyle = style.copyWith(
      color: AppTokens.primary500,
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: safeText(text.substring(cursor, m.start))));
      }
      final name = userDir[m.uid]?.name;
      spans.add(TextSpan(
        text: safeText('@${name ?? m.uid}'),
        style: mentionStyle,
      ));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: safeText(text.substring(cursor))));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
