import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../../messages/domain/message_models.dart';
import '../application/voice_controller.dart';
import '../domain/voice_models.dart';
import 'voice_operations_bar.dart';

/// Multi-user video grid, mirrors the web reference's
/// `routes/chat/VoiceFullscreen.tsx`: a pinned/spotlighted tile up top (if
/// any member is pinned) with the rest as a scrollable strip, or an even
/// grid when nobody is pinned.
class VoiceFullscreenView extends ConsumerStatefulWidget {
  const VoiceFullscreenView({super.key});

  @override
  ConsumerState<VoiceFullscreenView> createState() =>
      _VoiceFullscreenViewState();
}

class _VoiceFullscreenViewState extends ConsumerState<VoiceFullscreenView> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.read(voiceControllerProvider.notifier);
    final info = ref.watch(voiceControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_titleFor(info?.context)),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<VoicingMembers>(
          valueListenable: controller.members,
          builder: (context, members, _) {
            if (info == null) {
              return const SizedBox.shrink();
            }
            final pinned = members.pin;
            return Column(
              children: [
                Expanded(
                  child: pinned != null
                      ? _SpotlightLayout(pinnedUid: pinned, members: members)
                      : _GridLayout(members: members),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: VoiceOperationsBar(fullscreen: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _titleFor(MessageTarget? context) {
    final l = AppL10n.of(this.context);
    if (context == null) return l.voiceFullscreen;
    final userDir = ref.read(userDirectoryProvider).valueOrNull ?? const {};
    return context.map(
      user: (t) => userDir[t.uid]?.name ?? l.chatUserFallback(t.uid),
      group: (t) => l.chatGroupFallback(t.gid),
    );
  }
}

class _SpotlightLayout extends ConsumerWidget {
  const _SpotlightLayout({required this.pinnedUid, required this.members});

  final int pinnedUid;
  final VoicingMembers members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = members.ids.where((id) => id != pinnedUid).toList();
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _VideoTile(
              uid: pinnedUid, info: members.byId[pinnedUid], large: true),
        ),
        if (others.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: others.length,
              itemBuilder: (context, i) {
                final uid = others[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 100,
                    child: _VideoTile(uid: uid, info: members.byId[uid]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _GridLayout extends StatelessWidget {
  const _GridLayout({required this.members});

  final VoicingMembers members;

  @override
  Widget build(BuildContext context) {
    if (members.ids.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: members.ids.length <= 2 ? 1 : 2,
        childAspectRatio: 16 / 10,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: members.ids.length,
      itemBuilder: (context, i) {
        final uid = members.ids[i];
        return _VideoTile(uid: uid, info: members.byId[uid]);
      },
    );
  }
}

class _VideoTile extends ConsumerWidget {
  const _VideoTile({required this.uid, this.info, this.large = false});

  final int uid;
  final VoicingMemberInfo? info;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final name = userDir[uid]?.name ?? '#$uid';
    final controller = ref.read(voiceControllerProvider.notifier);
    final engine = controller.engineOrNull;
    final channelName = controller.channelNameOrNull;
    final localUid = controller.localUidOrNull;
    final showVideo = (info?.video ?? false) || (info?.shareScreen ?? false);
    final speaking = (info?.speakingVolume ?? 0) > 50;

    return GestureDetector(
      onTap: () => controller.pin(uid),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF23262E),
          borderRadius: BorderRadius.circular(12),
          border:
              speaking ? Border.all(color: Colors.greenAccent, width: 2) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo && engine != null && channelName != null)
              AgoraVideoView(
                controller: uid == localUid
                    ? VideoViewController(
                        rtcEngine: engine,
                        canvas: VideoCanvas(uid: 0),
                      )
                    : VideoViewController.remote(
                        rtcEngine: engine,
                        canvas: VideoCanvas(uid: uid),
                        connection: RtcConnection(channelId: channelName),
                      ),
              )
            else
              Center(child: VoceAvatar(name: name, size: large ? 96 : 48)),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (info?.muted ?? false)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child:
                            Icon(Icons.mic_off, color: Colors.white, size: 12),
                      ),
                    Text(name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
