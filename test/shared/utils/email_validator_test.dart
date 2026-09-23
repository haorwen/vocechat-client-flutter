import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/shared/utils/email_validator.dart';

void main() {
  for (final email in [
    'xx@vip.qq.com',
    'xx@qq.com',
    'user+tag@mail.example.co.uk',
    "o'connor@example.com",
    'first.last_test@my-domain.technology',
    'USER@VIP.QQ.COM',
    '  xx@vip.qq.com  ',
  ]) {
    test('accepts $email', () => expect(isValidEmail(email), isTrue));
  }

  for (final email in [
    '',
    '   ',
    'xx',
    '@vip.qq.com',
    'xx@',
    'xx@@vip.qq.com',
    'x x@vip.qq.com',
    'xx@vip..qq.com',
    'xx@.qq.com',
    'xx@qq.com.',
    'xx@-vip.qq.com',
    'xx@vip-.qq.com',
    'xx@vip_qq.com',
  ]) {
    test('rejects "$email"', () => expect(isValidEmail(email), isFalse));
  }
}
