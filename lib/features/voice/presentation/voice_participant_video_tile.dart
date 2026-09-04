import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/avo_params.dart';
import '../../../shared/widgets/avo_avatar.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../application/avo_interaction_controller.dart';
import '../application/voice_controller.dart';
import '../domain/voice_models.dart';

/// A single local or remote participant video surface.
///
/// Local video visibility comes from [VoicingInfo], while remote visibility
/// comes from the member roster populated by Agora callbacks.
class VoiceParticipantVideoTile extends ConsumerWidget {
  const VoiceParticipantVideoTile({
    required this.uid,
    this.memberInfo,
    this.large = false,
    this.onTap,
    super.key,
  });

  final int uid;
  final VoicingMemberInfo? memberInfo;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callInfo = ref.watch(voiceControllerProvider);
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final summary = userDir[uid];
    final name = summary?.name ?? '#$uid';
    final avoParams = summary?.avoParams ?? AvoParams.defaults;
    final controller = ref.read(voiceControllerProvider.notifier);
    final engine = controller.engineOrNull;
    final channelName = controller.channelNameOrNull;
    final isLocal = uid == controller.localUidOrNull;
    final isLocalScreenShare = isLocal && (callInfo?.shareScreen ?? false);
    final showVideo = isLocal
        ? (callInfo?.video ?? false) || isLocalScreenShare
        : (memberInfo?.video ?? false) || (memberInfo?.shareScreen ?? false);
    final level = (isLocal
                ? (callInfo?.speakingVolume ?? 0)
                : (memberInfo?.speakingVolume ?? 0))
            .clamp(0, 255) /
        255.0;
    final speaking = level > .2;
    final remoteInteraction = ref.watch(avoInteractionForUidProvider(uid));

    final tile = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF23262E),
        borderRadius: BorderRadius.circular(8),
        border:
            speaking ? Border.all(color: Colors.greenAccent, width: 2) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showVideo && engine != null && channelName != null)
            AgoraVideoView(
              key: ValueKey(isLocal ? 'local-video-$uid' : 'remote-video-$uid'),
              controller: isLocal
                  ? VideoViewController(
                      rtcEngine: engine,
                      canvas: VideoCanvas(
                        uid: 0,
                        sourceType: isLocalScreenShare
                            ? VideoSourceType.videoSourceScreen
                            : VideoSourceType.videoSourceCamera,
                      ),
                    )
                  : VideoViewController.remote(
                      rtcEngine: engine,
                      canvas: VideoCanvas(uid: uid),
                      connection: RtcConnection(channelId: channelName),
                    ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AvoAvatar(
                  params: avoParams,
                  level: level,
                  interactive: isLocal,
                  remoteInteraction: isLocal ? null : remoteInteraction,
                  onInteraction: isLocal
                      ? (event) => ref
                          .read(avoInteractionControllerProvider.notifier)
                          .sendLocal(event)
                      : null,
                ),
              ),
            ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (memberInfo?.muted ?? false)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child:
                            Icon(Icons.mic_off, color: Colors.white, size: 12),
                      ),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return GestureDetector(onTap: onTap, child: tile);
  }
}
