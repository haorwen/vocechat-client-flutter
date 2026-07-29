import '../../l10n/generated/app_localizations.dart';

/// Validates a server-URL text field: requires a scheme, only allows `http`
/// for localhost/127.0.0.1 (everything else must be `https`). Shared by the
/// server-picker "Add server" sheet and the account-switcher "Add account"
/// screen, which both let the user type/edit a target server URL.
String? validateServerUrl(String? v, AppL10n l) {
  if (v == null || v.trim().isEmpty) return l.serverUrlRequired;
  final uri = Uri.tryParse(v.trim());
  if (uri == null || !uri.hasScheme) {
    return l.serverUrlMustHttps;
  }
  final host = uri.host.toLowerCase();
  final isLocalhost = host == 'localhost' || host == '127.0.0.1';
  if (uri.scheme == 'http' && !isLocalhost) {
    return l.serverUrlHttpNotAllowed;
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return l.serverUrlMustHttps;
  }
  return null;
}
