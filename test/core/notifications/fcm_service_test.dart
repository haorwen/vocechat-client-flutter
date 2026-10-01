import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/notifications/fcm_service.dart';

void main() {
  test('FCM handles numeric and string chat IDs', () {
    expect(parseFcmChatTarget({'vocechat_to_gid': '12'}), 'g-12');
    expect(parseFcmChatTarget({'vocechat_from_uid': 3}), 'u-3');
  });
  test('malformed notification data is ignored without throwing', () {
    for (final value in [null, '', 'bad', '-1', -1, 1.5, true, [], {}]) {
      expect(parseFcmChatTarget({'vocechat_to_gid': value}), isNull);
      expect(parseFcmChatTarget({'vocechat_from_uid': value}), isNull);
    }
    expect(parseFcmChatTarget({}), isNull);
    // An invalid group must not accidentally navigate to its sender's DM.
    expect(
        parseFcmChatTarget({'vocechat_to_gid': null, 'vocechat_from_uid': '3'}),
        isNull);
  });
}
