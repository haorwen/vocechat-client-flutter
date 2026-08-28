import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/voice/domain/voice_models.dart';

void main() {
  const directCall = VoicingInfo(
    context: MessageTarget.user(uid: 42),
    connectionState: VoiceConnectionState.connected,
  );
  const remoteVideo = VoicingMemberInfo(video: true);

  test('allows the only remote video in a two-person direct call', () {
    final uid = remoteVideoUidForPictureInPicture(
      call: directCall,
      localUid: 7,
      members: const VoicingMembers(
        ids: [7, 42],
        byId: {7: VoicingMemberInfo(), 42: remoteVideo},
      ),
    );

    expect(uid, 42);
  });

  test('rejects calls that are not connected', () {
    final uid = remoteVideoUidForPictureInPicture(
      call: const VoicingInfo(
        context: MessageTarget.user(uid: 42),
        connectionState: VoiceConnectionState.reconnecting,
      ),
      localUid: 7,
      members: const VoicingMembers(
        ids: [7, 42],
        byId: {7: VoicingMemberInfo(), 42: remoteVideo},
      ),
    );

    expect(uid, isNull);
  });

  test('rejects group calls even when exactly one remote video is enabled', () {
    final uid = remoteVideoUidForPictureInPicture(
      call: const VoicingInfo(context: MessageTarget.group(gid: 8)),
      localUid: 7,
      members: const VoicingMembers(
        ids: [7, 42],
        byId: {7: VoicingMemberInfo(), 42: remoteVideo},
      ),
    );

    expect(uid, isNull);
  });

  test('rejects calls whose roster does not contain exactly two people', () {
    final onePerson = remoteVideoUidForPictureInPicture(
      call: directCall,
      localUid: 7,
      members: const VoicingMembers(
        ids: [7],
        byId: {7: VoicingMemberInfo()},
      ),
    );
    final threePeople = remoteVideoUidForPictureInPicture(
      call: directCall,
      localUid: 7,
      members: const VoicingMembers(
        ids: [7, 42, 99],
        byId: {
          7: VoicingMemberInfo(),
          42: remoteVideo,
          99: VoicingMemberInfo(),
        },
      ),
    );

    expect(onePerson, isNull);
    expect(threePeople, isNull);
  });

  test('rejects screen sharing when the remote camera is disabled', () {
    final uid = remoteVideoUidForPictureInPicture(
      call: directCall,
      localUid: 7,
      members: const VoicingMembers(
        ids: [7, 42],
        byId: {
          7: VoicingMemberInfo(),
          42: VoicingMemberInfo(shareScreen: true),
        },
      ),
    );

    expect(uid, isNull);
  });

  test('rejects a roster missing the local participant', () {
    final uid = remoteVideoUidForPictureInPicture(
      call: directCall,
      localUid: 7,
      members: const VoicingMembers(
        ids: [42, 99],
        byId: {42: remoteVideo, 99: VoicingMemberInfo()},
      ),
    );

    expect(uid, isNull);
  });
}
