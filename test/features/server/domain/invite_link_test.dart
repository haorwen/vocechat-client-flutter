import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/server/domain/invite_link.dart';

void main() {
  group('parseInviteLink', () {
    test('parses token-before-hash links (server-generated shape)', () {
      final result = parseInviteLink(
        'https://dev.voce.chat/?magic_token=abc123#/register',
      );
      expect(
        result,
        const InviteLinkParseResult.valid(
          serverBaseUrl: 'https://dev.voce.chat',
          magicToken: 'abc123',
        ),
      );
    });

    test('parses token-after-hash links (hash-router shape)', () {
      final result = parseInviteLink(
        'https://dev.voce.chat/#/register?magic_token=abc123',
      );
      expect(
        result,
        const InviteLinkParseResult.valid(
          serverBaseUrl: 'https://dev.voce.chat',
          magicToken: 'abc123',
        ),
      );
    });

    test('parses token-after-hash links with a port', () {
      final result = parseInviteLink(
        'https://dev.voce.chat:3000/#/register?magic_token=abc123',
      );
      expect(
        result,
        const InviteLinkParseResult.valid(
          serverBaseUrl: 'https://dev.voce.chat:3000',
          magicToken: 'abc123',
        ),
      );
    });

    test('returns invalid for empty input', () {
      expect(parseInviteLink(''), const InviteLinkParseResult.invalid());
    });

    test('returns invalid for non-http(s) scheme', () {
      expect(
        parseInviteLink('vocechat://dev.voce.chat/?magic_token=abc123'),
        const InviteLinkParseResult.invalid(),
      );
    });

    test('returns invalid when magic_token is missing entirely', () {
      expect(
        parseInviteLink('https://dev.voce.chat/#/register'),
        const InviteLinkParseResult.invalid(),
      );
    });
  });
}
