import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../../messages/domain/message_models.dart';
import '../application/voice_controller.dart';
import '../domain/voice_models.dart';
import 'voice_operations_bar.dart';
import 'voice_participant_video_tile.dart';

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
          child: VoiceParticipantVideoTile(
            uid: pinnedUid,
            memberInfo: members.byId[pinnedUid],
            large: true,
            onTap: () => ref.read(voiceControllerProvider.notifier).unpin(),
          ),
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
                    child: VoiceParticipantVideoTile(
                      uid: uid,
                      memberInfo: members.byId[uid],
                      onTap: () =>
                          ref.read(voiceControllerProvider.notifier).pin(uid),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _GridLayout extends ConsumerWidget {
  const _GridLayout({required this.members});

  final VoicingMembers members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return VoiceParticipantVideoTile(
          uid: uid,
          memberInfo: members.byId[uid],
          onTap: () => ref.read(voiceControllerProvider.notifier).pin(uid),
        );
      },
    );
  }
}
