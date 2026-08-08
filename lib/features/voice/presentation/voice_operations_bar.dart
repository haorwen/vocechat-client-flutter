import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/voice_controller.dart';
import '../domain/voice_models.dart';
import 'voice_fullscreen_view.dart';

/// In-call control bar. Adapts from a single row (wide screens) to a two-row
/// Wrap layout on narrow mobile screens so the hang-up button never overflows.
/// Also shows a local camera preview when video is active.
class VoiceOperationsBar extends ConsumerWidget {
  const VoiceOperationsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(voiceControllerProvider);
    if (info == null) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    final controller = ref.read(voiceControllerProvider.notifier);
    final reconnecting =
        info.connectionState == VoiceConnectionState.reconnecting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final engine = controller.engineOrNull;
    final channelName = controller.channelNameOrNull;
    final localUid = controller.localUidOrNull;
    final showLocalPreview =
        info.video && engine != null && !kIsWeb;

    return Material(
      color: isDark ? const Color(0xFF15171C) : const Color(0xFFF1F2F4),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
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
                    color:
                        reconnecting ? Colors.red : Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Local camera preview — shown only when video is on
            if (showLocalPreview)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100,
                  height: 75,
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            if (showLocalPreview) const SizedBox(height: 4),
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
                    tooltip:
                        info.video ? l.voiceCameraOff : l.voiceCameraOn,
                    icon:
                        info.video ? Icons.videocam : Icons.videocam_off,
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
                    onTap: () => info.shareScreen
                        ? controller.stopShareScreen()
                        : controller.startShareScreen(),
                  ),
                _ToolButton(
                  tooltip: l.voiceFullscreen,
                  icon: Icons.fullscreen,
                  active: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const VoiceFullscreenView()),
                  ),
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
