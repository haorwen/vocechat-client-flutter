import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/server_store.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../../messages/domain/message_models.dart';
import '../application/incoming_call_provider.dart';
import '../application/voice_controller.dart';
import '../domain/voice_models.dart';
import 'voice_operations_bar.dart';

/// App-wide draggable overlay for both ringing and active calls.
///
/// It is mounted once by `HomeShellScreen`, so call controls remain available
/// while the user moves between chats, contacts, and settings.
class IncomingCallBanner extends ConsumerStatefulWidget {
  const IncomingCallBanner({super.key});

  @override
  ConsumerState<IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends ConsumerState<IncomingCallBanner> {
  static const double _edgeMargin = 12;

  final GlobalKey _overlayKey = GlobalKey();
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final voicing = ref.watch(voiceControllerProvider);
    final call = voicing == null ? ref.watch(incomingCallProvider) : null;

    if (voicing == null && (call == null || !call.calling)) {
      return const SizedBox.shrink();
    }

    final active = voicing != null;
    final preferredWidth = active ? 320.0 : 220.0;
    final content =
        active ? const VoiceOperationsBar() : _buildRingingCard(context, call!);

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              math.max(0.0, constraints.maxWidth - _edgeMargin * 2);
          final overlayWidth = math.min(preferredWidth, availableWidth);
          final initialPosition = Offset(
            math.max(
                _edgeMargin, constraints.maxWidth - overlayWidth - _edgeMargin),
            _edgeMargin,
          );
          final position = _position ?? initialPosition;

          _schedulePositionClamp(constraints.biggest);

          return Stack(
            children: [
              Positioned(
                left: position.dx,
                top: position.dy,
                child: SizedBox(
                  key: _overlayKey,
                  width: overlayWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) => _moveOverlay(
                      details.delta,
                      constraints.biggest,
                      initialPosition,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        content,
                        Positioned(
                          right: 4,
                          top: 4,
                          child: MouseRegion(
                            key: const ValueKey('voice-call-drag-handle'),
                            cursor: SystemMouseCursors.move,
                            child: SizedBox.square(
                              dimension: 28,
                              child: Icon(
                                Icons.drag_indicator,
                                size: 18,
                                color: active
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRingingCard(BuildContext context, IncomingCallState call) {
    final selfUid = switch (ref.watch(authControllerProvider).valueOrNull) {
      AuthStateAuthenticated(user: final u) => u.uid,
      _ => null,
    };
    if (selfUid == null) return const SizedBox.shrink();

    final sendByMe = call.fromUid == selfUid;
    final peerUid = sendByMe ? call.toUid : call.fromUid;
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final peer = userDir[peerUid];
    final l = AppL10n.of(context);
    final name = peer?.name ?? l.chatUserFallback(peerUid);
    final avatarUrl = _avatarUrl(peerUid, peer?.avatarUpdatedAt);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xFF1F2430),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VoceAvatar(name: name, imageUrl: avatarUrl, size: 64),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
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
    );
  }

  void _moveOverlay(Offset delta, Size bounds, Offset initialPosition) {
    final current = _position ?? initialPosition;
    final renderBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    final contentSize = renderBox?.size ?? Size.zero;
    setState(() {
      _position = _clampPosition(current + delta, bounds, contentSize);
    });
  }

  void _schedulePositionClamp(Size bounds) {
    if (_position == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _position == null) return;
      final renderBox =
          _overlayKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      final clamped = _clampPosition(_position!, bounds, renderBox.size);
      if (clamped != _position) setState(() => _position = clamped);
    });
  }

  Offset _clampPosition(Offset value, Size bounds, Size contentSize) {
    final maxX =
        math.max(_edgeMargin, bounds.width - contentSize.width - _edgeMargin);
    final maxY =
        math.max(_edgeMargin, bounds.height - contentSize.height - _edgeMargin);
    return Offset(
      value.dx.clamp(_edgeMargin, maxX).toDouble(),
      value.dy.clamp(_edgeMargin, maxY).toDouble(),
    );
  }

  Future<void> _answer(int fromUid) async {
    context.go('/home/chat/u-$fromUid');
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
  const _RoundButton(
      {required this.color, required this.icon, required this.onTap});

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
