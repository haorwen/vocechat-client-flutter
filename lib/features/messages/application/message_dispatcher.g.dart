// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_dispatcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$messageDispatcherHash() => r'bb1ff2511c348e85d0af33c41bcd30cadc5b4e89';

/// Long-lived listener that routes every incoming SSE chat event to:
///   1. the conversations list (so previews update on the left),
///   2. the per-target ChatController (so the chat screen has the message
///      ready the moment it's opened, even if it had never been opened
///      before — and stays in sync while it's in the background), and
///   3. the presence / show-online-status providers (so DM avatars reflect
///      the actual online state, mirroring the web client's `useStreaming`
///      handler for `users_state` / `users_state_changed` /
///      `server_config_changed`).
///
/// Kept alive for the entire app lifetime so it does NOT depend on any
/// screen being mounted.
///
/// Copied from [MessageDispatcher].
@ProviderFor(MessageDispatcher)
final messageDispatcherProvider =
    NotifierProvider<MessageDispatcher, void>.internal(
  MessageDispatcher.new,
  name: r'messageDispatcherProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$messageDispatcherHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MessageDispatcher = Notifier<void>;
String _$kickReasonHash() => r'e19bc8f6b88c22e75c1a10fe097e2c601352ab02';

/// Last-seen kick reason from a server `kick` event. Login screen / banner
/// reads this to surface a toast ("kicked from another device" / "your
/// account has been deleted"). `null` when there is no pending reason.
/// Set back to `null` by the consumer after displaying.
///
/// Copied from [KickReason].
@ProviderFor(KickReason)
final kickReasonProvider = NotifierProvider<KickReason, String?>.internal(
  KickReason.new,
  name: r'kickReasonProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$kickReasonHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$KickReason = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
