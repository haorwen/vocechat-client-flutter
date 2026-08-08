import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_controller.dart';
import '../data/agora_api.dart';
import '../domain/voice_models.dart';
import 'voice_controller.dart';

part 'incoming_call_provider.g.dart';

/// Discovers incoming/outgoing DM call invites by polling the server's
/// active-channel list, mirroring the web reference's `useGetAgoraChannelsQuery`
/// (10s interval) in `components/Voice/index.tsx`. The server's `UserCalling`
/// push event exists but is not currently wired up server-side
/// (`admin_agora.rs` has the notify call commented out), so polling is the
/// only reliable signal; [MessageDispatcher] feeds `ChatEvent.userCalling`
/// into [set] too, so a future server fix needs no client change.
///
/// A DM call is "ringing" when exactly one participant (the caller) is in
/// the `vocechat:dm:{selfUid}` channel and it isn't us.
@Riverpod(keepAlive: true)
class IncomingCall extends _$IncomingCall {
  Timer? _timer;

  @override
  IncomingCallState build() {
    ref.onDispose(() => _timer?.cancel());
    _start();
    return const IncomingCallState();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
    // Fire once immediately rather than waiting a full interval.
    Future.microtask(_poll);
  }

  Future<void> _poll() async {
    final authState = ref.read(authControllerProvider).valueOrNull;
    if (authState is! AuthStateAuthenticated) return;
    final selfUid = authState.user.uid;

    // Already in a call (either side) — the active-channel list would just
    // re-confirm what we already know, and re-triggering `set()` mid-call
    // risks clobbering the connected state with a stale "ringing" snapshot.
    if (ref.read(voiceControllerProvider) != null) return;

    try {
      final channels = await ref.read(agoraApiProvider).getActiveChannels();
      final myChannel = channels.where((c) {
        return c.context?.map(
              user: (t) => t.uid == selfUid,
              group: (_) => false,
            ) ==
            true;
      }).firstOrNull;

      if (myChannel == null || myChannel.userCount != 1) {
        // No one is waiting in our DM channel — clear a stale ring, but only
        // one we're not actively answering (calling==true is the ringing
        // state; leave it for the user to explicitly reject/answer).
        return;
      }

      final usersInChannel =
          await ref.read(agoraApiProvider).getChannelUsers(myChannel.channelName);
      final caller = usersInChannel.where((uid) => uid != selfUid).firstOrNull;
      if (caller == null) return;

      set(fromUid: caller, toUid: selfUid, calling: true);
    } catch (_) {
      // Transient network error — next tick retries.
    }
  }

  /// Update the ringing state. [calling] toggles visibility of the ringing
  /// banner; the caller/callee uids persist across mid-call widget rebuilds
  /// even after [calling] is cleared (mirrors the web slice's
  /// `updateCallInfo`, which keeps `from`/`to` when only muting `calling`).
  void set({int? fromUid, int? toUid, bool? calling}) {
    state = state.copyWith(
      fromUid: fromUid ?? state.fromUid,
      toUid: toUid ?? state.toUid,
      calling: calling ?? state.calling,
    );
  }

  void dismiss() {
    state = state.copyWith(calling: false);
  }

  void clear() {
    state = const IncomingCallState();
  }
}
