import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'message_links.dart';

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

class MentionText extends StatefulWidget {
  const MentionText({
    super.key,
    required this.text,
    required this.userDir,
    required this.style,
    this.selectable = false,
    this.maxLines,
    this.overflow,
  });

  final bool selectable;
  final String text;
  final Map<int, UserSummary> userDir;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  final _recognizers = <String, TapGestureRecognizer>{};

  void _disposeRecognizers() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  TextSpan _linkSpan(String label, String href, Set<String> activeLinks) {
    activeLinks.add(href);
    final recognizer = _recognizers.putIfAbsent(
      href,
      () => TapGestureRecognizer()
        ..onTap = () => openMessageLink(href, context: context),
    );
    return TextSpan(
      text: safeText(label),
      style: messageLinkTextStyle,
      mouseCursor: SystemMouseCursors.click,
      recognizer: recognizer,
    );
  }

  List<InlineSpan> _plainSpans(String text, Set<String> activeLinks) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in messageLinkPattern.allMatches(text)) {
      final label = trimMessageLink(match.group(0)!);
      final href =
          label.toLowerCase().startsWith('www.') ? 'https://$label' : label;
      if (match.start > cursor) {
        spans
            .add(TextSpan(text: safeText(text.substring(cursor, match.start))));
      }
      spans.add(_linkSpan(label, href, activeLinks));
      cursor = match.start + label.length;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: safeText(text.substring(cursor))));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final activeLinks = <String>{};
    final text = widget.text;
    final style = widget.style;
    final userDir = widget.userDir;
    final matches = findMentions(text);
    final mentionStyle = style.copyWith(
      color: AppTokens.primary500,
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.addAll(_plainSpans(text.substring(cursor, m.start), activeLinks));
      }
      final name = userDir[m.uid]?.name;
      spans.add(TextSpan(
        text: safeText('@${name ?? m.uid}'),
        style: mentionStyle,
      ));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.addAll(_plainSpans(text.substring(cursor), activeLinks));
    }

    // Reuse handlers for links that are still present: rebuilding between
    // pointer down and up must not cancel an in-progress tap.
    _recognizers.removeWhere((href, recognizer) {
      if (activeLinks.contains(href)) return false;
      recognizer.dispose();
      return true;
    });

    if (widget.selectable) {
      return SelectableText.rich(TextSpan(style: style, children: spans));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
