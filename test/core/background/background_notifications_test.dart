import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/background/background_notifications.dart';
import 'package:vocechat_client/features/channels/application/muted_chats_provider.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

void main() {
  const message = ChatMessage(
      mid: 12,
      fromUid: 2,
      createdAt: 1000,
      target: MessageTarget.user(uid: 1),
      detail:
          MessageDetail.normal(contentType: 'text/plain', content: 'hello'));
  bool notify(ChatMessage value,
          {bool enabled = true,
          bool backgrounded = true,
          MutedChatsState muted = const MutedChatsState()}) =>
      shouldNotifyBackgroundMessage(value,
          enabled: enabled,
          backgrounded: backgrounded,
          selfUid: 1,
          muted: muted,
          now: 5000);

  test('only opted-in background incoming messages notify', () {
    expect(notify(message), isTrue);
    expect(notify(message, enabled: false), isFalse);
    expect(notify(message, backgrounded: false), isFalse);
    expect(notify(message.copyWith(fromUid: 1)), isFalse);
    expect(notify(message.copyWith(mid: -1)), isFalse);
  });
  test('DM mute uses sender, not the recipient target', () {
    expect(notify(message, muted: const MutedChatsState(mutedUsers: {2})),
        isFalse);
    expect(
        notify(message, muted: const MutedChatsState(mutedUsers: {1})), isTrue);
  });
  test('group mute, reactions and expired messages stay silent', () {
    expect(
        notify(message.copyWith(target: const MessageTarget.group(gid: 3)),
            muted: const MutedChatsState(mutedGroups: {3})),
        isFalse);
    expect(
        notify(message.copyWith(
            detail: const MessageDetail.reaction(
                mid: 10, detail: {'type': 'like'}))),
        isFalse);
    expect(
        notify(message.copyWith(
            detail: const MessageDetail.normal(
                contentType: 'text/plain', content: 'secret', expiresIn: 1))),
        isFalse);
  });
  test(
      'mentions bypass group mute and mentions-only filters other group messages',
      () {
    final group = message.copyWith(target: const MessageTarget.group(gid: 3));
    final mention = group.copyWith(
        detail: const MessageDetail.normal(
            contentType: 'text/plain',
            content: 'hello @1',
            properties: {
          'mentions': [1]
        }));
    bool eligible(ChatMessage value) => shouldNotifyBackgroundMessage(value,
        enabled: true,
        backgrounded: true,
        selfUid: 1,
        now: 5000,
        muted: const MutedChatsState(mutedGroups: {3}),
        mentionsOnly: true);
    expect(eligible(group), isFalse);
    expect(eligible(mention), isTrue);
    expect(eligible(message), isTrue);
  });
}
