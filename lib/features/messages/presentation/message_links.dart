import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';

const messageLinkTextStyle = TextStyle(
  color: Colors.blue,
  decoration: TextDecoration.underline,
);

const _androidMessageLinks = MethodChannel('vocechat/external_links');

/// Opens web links in the user's browser, with an in-app fallback on Android.
/// Other message-provided schemes are not dispatched to applications.
Future<void> openMessageLink(String? href, {BuildContext? context}) async {
  if (href == null) return;
  final uri = Uri.tryParse(href);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return;
  }
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (isAndroid && await _tryLaunchAndroidBrowser(uri)) return;
  if (await _tryLaunch(uri, LaunchMode.externalApplication)) return;
  if (isAndroid && await _tryLaunch(uri, LaunchMode.inAppBrowserView)) {
    return;
  }
  if (context == null || !context.mounted) return;
  final l = AppL10n.of(context);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(l.chatOpenLinkFailed),
    action: SnackBarAction(
      label: l.chatActionCopy,
      onPressed: () => Clipboard.setData(ClipboardData(text: uri.toString())),
    ),
  ));
}

Future<bool> _tryLaunchAndroidBrowser(Uri uri) async {
  try {
    // The native bridge uses the application Context and ACTION_VIEW, so it
    // remains available when a retained engine changes its Activity host.
    return await _androidMessageLinks.invokeMethod<bool>(
          'openUrl',
          {'url': uri.toString()},
        ) ??
        false;
  } on PlatformException catch (error) {
    debugPrint('Message link native launch failed: ${error.code}');
    return false;
  } on MissingPluginException {
    debugPrint('Message link native launch failed: bridge unavailable');
    return false;
  }
}

Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
  try {
    return await launchUrl(uri, mode: mode);
  } on PlatformException catch (error) {
    debugPrint('Message link launch failed (${mode.name}): ${error.code}');
    return false;
  } on MissingPluginException {
    debugPrint('Message link launch failed (${mode.name}): plugin unavailable');
    return false;
  }
}

final messageLinkPattern = RegExp(
  r'''\b(?:https?://|www\.)[^\s<>"\u3000-\u303f\uff00-\uffef]+''',
  caseSensitive: false,
);

String trimMessageLink(String text) {
  var result = text;
  while (true) {
    final previous = result;
    result = result.replaceFirst(RegExp(r'[.,;:!?]+$'), '');
    for (final pair in const [('(', ')'), ('[', ']'), ('{', '}')]) {
      while (result.endsWith(pair.$2) &&
          pair.$2.allMatches(result).length >
              pair.$1.allMatches(result).length) {
        result = result.substring(0, result.length - 1);
      }
    }
    if (result == previous) return result;
  }
}
