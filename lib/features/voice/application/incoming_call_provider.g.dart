// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incoming_call_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$incomingCallHash() => r'6fba6130754a6e123c45b74ce4e93125f1e6a51c';

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
///
/// Copied from [IncomingCall].
@ProviderFor(IncomingCall)
final incomingCallProvider =
    NotifierProvider<IncomingCall, IncomingCallState>.internal(
  IncomingCall.new,
  name: r'incomingCallProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$incomingCallHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$IncomingCall = Notifier<IncomingCallState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
