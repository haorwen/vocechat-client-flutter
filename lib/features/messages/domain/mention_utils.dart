// ---------------------------------------------------------------------------
// Mention tokens — ` @{uid} ` embedded in plain-text message content.
//
// Web behavior (components/Send/index.tsx `getMessageFromPlateValues` +
// components/LinkifyText.tsx): a mention renders into the raw text as a
// standalone `@{uid}` token bounded by whitespace/newline or the start/end of
// the string, and the sent message's `properties.mentions` carries the same
// uids as a plain int array (read server-side only for notification
// targeting / mute-bypass — vocechat-server/src/api/message.rs
// `MessageDetail::mentions()` — otherwise fully opaque).
//
// No lookbehind regex here (Dart's RegExp lookbehind support is unreliable
// across versions); instead find `@(\d+)` then manually check the
// surrounding characters are boundaries.
// ---------------------------------------------------------------------------

/// A single mention token found in message text.
class MentionMatch {
  const MentionMatch({required this.start, required this.end, required this.uid});

  final int start;
  final int end;
  final int uid;
}

bool _isBoundary(String ch) => ch == ' ' || ch == '\n' || ch == '\t';

/// Finds all `@{uid}` tokens in [text] bounded by whitespace/newline or the
/// start/end of the string. Duplicates are included in order of appearance
/// (matches web's un-deduplicated `mentions: number[]`).
List<MentionMatch> findMentions(String text) {
  final matches = <MentionMatch>[];
  for (final m in RegExp(r'@(\d+)').allMatches(text)) {
    final start = m.start;
    final end = m.end;
    final beforeOk = start == 0 || _isBoundary(text[start - 1]);
    final afterOk = end == text.length || _isBoundary(text[end]);
    if (beforeOk && afterOk) {
      matches.add(MentionMatch(start: start, end: end, uid: int.parse(m.group(1)!)));
    }
  }
  return matches;
}

/// Uids mentioned in [text], in order of appearance (duplicates included).
/// Used to build the outgoing `properties.mentions` array.
List<int> extractMentionUids(String text) =>
    findMentions(text).map((m) => m.uid).toList(growable: false);
