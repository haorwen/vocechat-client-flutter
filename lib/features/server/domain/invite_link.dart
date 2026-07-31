// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_link.freezed.dart';

// ---------------------------------------------------------------------------
// InviteLinkParseResult (sealed)
// ---------------------------------------------------------------------------

@freezed
sealed class InviteLinkParseResult with _$InviteLinkParseResult {
  const factory InviteLinkParseResult.valid({
    required String serverBaseUrl,
    required String magicToken,
  }) = InviteLinkParseValid;

  const factory InviteLinkParseResult.invalid() = InviteLinkParseInvalid;
}

// ---------------------------------------------------------------------------
// parseInviteLink
// ---------------------------------------------------------------------------

/// Parses a pasted VoceChat invitation link into a target server base URL
/// and magic token.
///
/// Server-generated links (`vocechat-server/src/api/group.rs`,
/// `create_reg_magic_link`) look like:
///   `https://<host>[:port]/?magic_token=<hex>#/register`
/// with `magic_token` living in the query string *before* the `#` hash-route
/// fragment.
///
/// Some sources instead produce hash-route-style links where the token is
/// *inside* the fragment's own query string, e.g.
///   `https://<host>[:port]/#/register?magic_token=<hex>`
/// (the shape a `HashRouter`-based web app naturally emits from
/// `location.href`). Both shapes are accepted: `magic_token` is looked up in
/// the query string before `#` first, then in the query string inside the
/// fragment.
///
/// Only http/https links carry a resolvable server address on their own —
/// a bare custom-scheme link (`vocechat://...`) has no host that maps to a
/// real server, so it is rejected here; deep_link_listener.dart is expected
/// to unwrap such links to an inner http(s) URL before calling this.
InviteLinkParseResult parseInviteLink(String rawLink) {
  final trimmed = rawLink.trim();
  if (trimmed.isEmpty) return const InviteLinkParseResult.invalid();

  final hashIndex = trimmed.indexOf('#');
  final beforeHash =
      hashIndex == -1 ? trimmed : trimmed.substring(0, hashIndex);
  final afterHash = hashIndex == -1 ? '' : trimmed.substring(hashIndex + 1);

  final uri = Uri.tryParse(beforeHash);
  if (uri == null || uri.host.isEmpty) {
    return const InviteLinkParseResult.invalid();
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return const InviteLinkParseResult.invalid();
  }

  var magicToken = uri.queryParameters['magic_token'];

  if (magicToken == null || magicToken.isEmpty) {
    final fragmentQueryIndex = afterHash.indexOf('?');
    if (fragmentQueryIndex != -1) {
      final fragmentQuery = afterHash.substring(fragmentQueryIndex + 1);
      magicToken = Uri.splitQueryString(fragmentQuery)['magic_token'];
    }
  }

  if (magicToken == null || magicToken.isEmpty) {
    return const InviteLinkParseResult.invalid();
  }

  final serverBaseUrl = uri.hasPort
      ? '${uri.scheme}://${uri.host}:${uri.port}'
      : '${uri.scheme}://${uri.host}';

  return InviteLinkParseResult.valid(
    serverBaseUrl: serverBaseUrl,
    magicToken: magicToken,
  );
}
