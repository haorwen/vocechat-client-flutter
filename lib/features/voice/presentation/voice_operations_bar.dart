import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/voice_controller.dart';
import '../domain/voice_models.dart';
import 'voice_fullscreen_view.dart';
import 'voice_participant_video_tile.dart';

/// In-call control bar. Adapts from a single row (wide screens) to a two-row
/// Wrap layout on narrow mobile screens so the hang-up button never overflows.
/// The compact mode shows every participant in a horizontally scrollable strip.
class VoiceOperationsBar extends ConsumerStatefulWidget {
  const VoiceOperationsBar({super.key, this.fullscreen = false});

  final bool fullscreen;

  @override
  ConsumerState<VoiceOperationsBar> createState() => _VoiceOperationsBarState();
}

class _VoiceOperationsBarState extends ConsumerState<VoiceOperationsBar> {
  bool _openingFullscreen = false;
  bool _screenShareBusy = false;

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(voiceControllerProvider);
    if (info == null) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    final controller = ref.read(voiceControllerProvider.notifier);
    final reconnecting =
        info.connectionState == VoiceConnectionState.reconnecting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final showParticipants = !widget.fullscreen && !_openingFullscreen;

    return Material(
      color: isDark ? const Color(0xFF15171C) : const Color(0xFFF1F2F4),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.fullscreen)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NetworkDot(quality: info.downlinkNetworkQuality),
                  const SizedBox(width: 6),
                  Text(
                    reconnecting ? l.voiceReconnecting : l.voiceConnected,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: reconnecting ? Colors.red : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            if (showParticipants) ...[
              const SizedBox(height: 8),
              ValueListenableBuilder<VoicingMembers>(
                valueListenable: controller.members,
                builder: (context, members, _) {
                  if (members.ids.isEmpty) return const SizedBox.shrink();
                  return SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: members.ids.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final uid = members.ids[index];
                        return SizedBox(
                          width: 120,
                          child: VoiceParticipantVideoTile(
                            key: ValueKey('compact-participant-$uid'),
                            uid: uid,
                            memberInfo: members.byId[uid],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
            if (!widget.fullscreen) const SizedBox(height: 4),
            // Controls — Wrap so buttons reflow on narrow screens
            Wrap(
              spacing: 0,
              runSpacing: 0,
              children: [
                _ToolButton(
                  tooltip: info.muted ? l.voiceUnmute : l.voiceMute,
                  icon: info.muted ? Icons.mic_off : Icons.mic,
                  active: !info.muted,
                  onTap: () => controller.setMuted(!info.muted),
                ),
                _ToolButton(
                  tooltip: info.deafen ? l.voiceUndeafen : l.voiceDeafen,
                  icon: info.deafen ? Icons.volume_off : Icons.volume_up,
                  active: !info.deafen,
                  onTap: () => controller.setDeafen(!info.deafen),
                ),
                if (isVoiceCallingSupported)
                  _ToolButton(
                    tooltip: info.video ? l.voiceCameraOff : l.voiceCameraOn,
                    icon: info.video ? Icons.videocam : Icons.videocam_off,
                    active: info.video,
                    onTap: () => info.video
                        ? controller.closeCamera()
                        : controller.openCamera(),
                  ),
                if (!kIsWeb &&
                    (defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.macOS ||
                        defaultTargetPlatform == TargetPlatform.android))
                  _ToolButton(
                    tooltip: l.voiceShareScreen,
                    icon: Icons.screen_share,
                    active: info.shareScreen,
                    onTap: _screenShareBusy ? () {} : _toggleScreenShare,
                  ),
                _ToolButton(
                  tooltip: widget.fullscreen
                      ? l.tooltipExitFullscreen
                      : l.voiceFullscreen,
                  icon: widget.fullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  active: false,
                  onTap: _toggleFullscreen,
                ),
                _ToolButton(
                  tooltip: l.voiceLeave,
                  icon: Icons.call_end,
                  active: false,
                  danger: true,
                  onTap: controller.leave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleScreenShare() async {
    if (_screenShareBusy) return;
    setState(() => _screenShareBusy = true);
    try {
      final controller = ref.read(voiceControllerProvider.notifier);
      final info = ref.read(voiceControllerProvider);
      if (info?.shareScreen ?? false) {
        await controller.stopShareScreen();
      } else {
        await controller.startShareScreen();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).errorPrefix('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _screenShareBusy = false);
    }
  }

  Future<void> _toggleFullscreen() async {
    if (widget.fullscreen) {
      Navigator.of(context).pop();
      return;
    }
    if (_openingFullscreen) return;

    setState(() => _openingFullscreen = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const VoiceFullscreenView(),
        ),
      );
    } finally {
      if (mounted) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) setState(() => _openingFullscreen = false);
      }
    }
  }
}

class _NetworkDot extends StatelessWidget {
  const _NetworkDot({required this.quality});
  final int? quality;

  @override
  Widget build(BuildContext context) {
    final q = quality ?? 0;
    final color = switch (q) {
      1 || 2 => Colors.green,
      3 || 4 => Colors.orange,
      5 || 6 => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Colors.red
        : active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).iconTheme.color;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
    );
  }
}
