/// Basic email syntax matching HTML email inputs used by the web client.
/// Supports subdomains and local-part characters such as `+` and apostrophes.
/// The server remains responsible for account and address verification.
bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

final _emailPattern = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
  r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
  r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
);
