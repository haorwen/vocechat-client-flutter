import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../messages/domain/message_models.dart';
import '../application/voice_controller.dart';
import '../data/agora_api.dart';

/// AppBar "start a voice/video call" icon. Hidden entirely when Agora
/// calling isn't supported on this platform (Linux desktop) or isn't
/// enabled on the server (`GET /admin/agora/enabled`). Mirrors the web
/// reference's voice-entry icon in `routes/chat/VoiceChat/index.tsx`, minus
/// the VoceSpace fallback path (out of scope — see project decision to
/// port the Agora path only).
class VoiceEntryButton extends ConsumerWidget {
  const VoiceEntryButton({super.key, required this.target});

  final MessageTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVoiceCallingSupported) return const SizedBox.shrink();

    final enabledAsync = ref.watch(_agoraEnabledProvider);
    final enabled = enabledAsync.valueOrNull ?? false;
    if (!enabled) return const SizedBox.shrink();

    final voicing = ref.watch(voiceControllerProvider);
    final alreadyInThisCall = voicing?.context == target;
    final busyElsewhere = voicing != null && !alreadyInThisCall;

    final l = AppL10n.of(context);
    return IconButton(
      tooltip: l.voiceStartCall,
      icon: const Icon(Icons.call),
      onPressed: busyElsewhere || alreadyInThisCall
          ? null
          : () => ref.read(voiceControllerProvider.notifier).join(target),
    );
  }
}

final _agoraEnabledProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.read(agoraApiProvider).isEnabled();
  } catch (_) {
    return false;
  }
});
