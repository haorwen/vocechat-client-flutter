import '../../l10n/generated/app_localizations.dart';

/// Validates a server-URL text field: requires a scheme of `http` or
/// `https`. Shared by the server-picker "Add server" sheet and the
/// account-switcher "Add account" screen, which both let the user type/edit
/// a target server URL.
String? validateServerUrl(String? v, AppL10n l) {
  if (v == null || v.trim().isEmpty) return l.serverUrlRequired;
  final uri = Uri.tryParse(v.trim());
  if (uri == null || !uri.hasScheme) {
    return l.serverUrlMustHttps;
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return l.serverUrlMustHttps;
  }
  return null;
}
