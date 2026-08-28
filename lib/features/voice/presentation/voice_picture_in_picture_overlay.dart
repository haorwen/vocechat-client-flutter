import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/voice_controller.dart';
import '../domain/voice_models.dart';
import 'voice_participant_video_tile.dart';

/// Replaces the Android activity content with the eligible remote video while
/// Android shrinks that activity into its system picture-in-picture window.
/// iOS uses Agora's native PiP content view and does not need this layer.
class VoicePictureInPictureOverlay extends ConsumerWidget {
  const VoicePictureInPictureOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return child;
    }

    final controller = ref.read(voiceControllerProvider.notifier);
    return ValueListenableBuilder<int?>(
      valueListenable: controller.pictureInPictureRemoteUid,
      builder: (context, remoteUid, _) {
        if (remoteUid == null) return child;

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            ColoredBox(
              key: const ValueKey('voice-picture-in-picture-video'),
              color: Colors.black,
              child: ValueListenableBuilder<VoicingMembers>(
                valueListenable: controller.members,
                builder: (context, members, _) => VoiceParticipantVideoTile(
                  uid: remoteUid,
                  memberInfo: members.byId[remoteUid],
                  large: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
