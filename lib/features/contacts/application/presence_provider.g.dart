// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$presenceHash() => r'3316b956915192f5f0a5f48d02a8b0404b81b800';

/// Per-user online state.
///
/// Mirrors the web client's `users_state` / `users_state_changed` SSE handling
/// in `useStreaming`: we hold a `uid -> online` map that the avatar status dot
/// consults. Driven by `MessageDispatcher` (single SSE consumer) so we don't
/// need a second `ref.listen` competing for the same stream.
///
/// Copied from [Presence].
@ProviderFor(Presence)
final presenceProvider = NotifierProvider<Presence, Map<int, bool>>.internal(
  Presence.new,
  name: r'presenceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$presenceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Presence = Notifier<Map<int, bool>>;
String _$showOnlineStatusHash() => r'db62c94dc5274816d22c612f6bc4d37946f53060';

/// Whether the server admin has enabled per-user online dots.
///
/// Mirrors `store.server.show_user_online_status` from the web client. Updated
/// from `server_config_changed` SSE events. Defaults to `true` so first paint
/// shows the dots until the server tells us otherwise.
///
/// Copied from [ShowOnlineStatus].
@ProviderFor(ShowOnlineStatus)
final showOnlineStatusProvider =
    NotifierProvider<ShowOnlineStatus, bool>.internal(
  ShowOnlineStatus.new,
  name: r'showOnlineStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$showOnlineStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ShowOnlineStatus = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
