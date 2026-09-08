import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens web links in the user's browser. Other message-provided schemes are
/// deliberately not dispatched to applications.
Future<void> openMessageLink(String? href) async {
  if (href == null) return;
  final uri = Uri.tryParse(href);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return;
  }
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    // Keep the message usable if no browser is available.
  }
}

final messageLinkPattern = RegExp(
  r'''\b(?:https?://|www\.)[^\s<>"\u3000-\u303f\uff00-\uffef]+''',
  caseSensitive: false,
);

String trimMessageLink(String text) {
  var result = text.replaceFirst(RegExp(r'[.,;:!?]+$'), '');
  for (final pair in const [('(', ')'), ('[', ']'), ('{', '}')]) {
    while (result.endsWith(pair.$2) &&
        pair.$2.allMatches(result).length > pair.$1.allMatches(result).length) {
      result = result.substring(0, result.length - 1);
    }
  }
  return result;
}
