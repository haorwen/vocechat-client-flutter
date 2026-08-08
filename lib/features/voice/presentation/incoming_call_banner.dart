import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../../messages/domain/message_models.dart';
import '../application/incoming_call_provider.dart';
import '../application/voice_controller.dart';

/// Draggable floating ringing card for DM calls — mirrors the web
/// reference's `components/Voice/DMCalling.tsx`. Shown app-wide (mounted in
/// `HomeShellScreen`) whenever [incomingCallProvider] reports `calling` and
/// we aren't already on the relevant chat screen.
///
/// [currentChatPeerUid] lets the caller (chat_screen) suppress the banner
/// while the matching DM is already open — the chat screen's own
/// [VoiceOperationsBar] takes over ringing/answer UI there instead of
/// stacking a duplicate floating card on top of it.
class IncomingCallBanner extends ConsumerStatefulWidget {
  const IncomingCallBanner({super.key, this.currentChatPeerUid});

  final int? currentChatPeerUid;

  @override
  ConsumerState<IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends ConsumerState<IncomingCallBanner> {
  Offset _offset = const Offset(-16, 96);

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(incomingCallProvider);
    final voicing = ref.watch(voiceControllerProvider);
    final selfUid = switch (ref.watch(authControllerProvider).valueOrNull) {
      AuthStateAuthenticated(user: final u) => u.uid,
      _ => null,
    };

    if (!call.calling || selfUid == null) return const SizedBox.shrink();
    // Already fully joined this exact call elsewhere — the chat screen's
    // operations bar owns the UI now, not this floating card.
    if (voicing != null) return const SizedBox.shrink();

    final sendByMe = call.fromUid == selfUid;
    final peerUid = sendByMe ? call.toUid : call.fromUid;
    if (peerUid == widget.currentChatPeerUid) return const SizedBox.shrink();

    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final peer = userDir[peerUid];
    final l = AppL10n.of(context);
    final name = peer?.name ?? l.chatUserFallback(peerUid);
    final avatarUrl = _avatarUrl(peerUid, peer?.avatarUpdatedAt);

    return Positioned(
      right: 16 - _offset.dx,
      top: 96 + _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _offset += d.delta),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1F2430),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoceAvatar(name: name, imageUrl: avatarUrl, size: 64),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  sendByMe ? l.voiceCallingOut : l.voiceIncomingCall,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundButton(
                      color: Colors.red,
                      icon: Icons.call_end,
                      onTap: () => _reject(sendByMe),
                    ),
                    if (!sendByMe) ...[
                      const SizedBox(width: 16),
                      _RoundButton(
                        color: Colors.green,
                        icon: Icons.call,
                        onTap: () => _answer(call.fromUid),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _answer(int fromUid) async {
    ref.read(incomingCallProvider.notifier).dismiss();
    await ref
        .read(voiceControllerProvider.notifier)
        .join(MessageTarget.user(uid: fromUid));
  }

  Future<void> _reject(bool sendByMe) async {
    ref.read(incomingCallProvider.notifier).dismiss();
    if (sendByMe) {
      // We're the caller cancelling before anyone answered — leave the
      // channel we're sitting in so the callee's poll stops seeing us.
      await ref.read(voiceControllerProvider.notifier).leave();
    }
  }

  String? _avatarUrl(int uid, int? avatarUpdatedAt) {
    if ((avatarUpdatedAt ?? 0) == 0) return null;
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    final server = serverState?.servers
        .where((s) => s.id == serverState.currentServerId)
        .firstOrNull;
    final base = server?.baseUrl ?? '';
    if (base.isEmpty) return null;
    return '$base/api/resource/avatar?uid=$uid';
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.color, required this.icon, required this.onTap});

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
