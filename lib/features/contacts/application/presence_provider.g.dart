// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$presenceHash() => r'2d250e9a14fa322a71deeb72c4f765265c96a5dd';

/// Per-user online state.
///
/// Mirrors the web client's `users_state` / `users_state_changed` SSE handling
/// in `useStreaming`: we hold a `uid -> online` map that the avatar status dot
/// consults. The server only mentions a uid in `users_state` when it has a
/// non-default state — anyone absent is treated as offline (matches the web
/// behavior in `slices/users.ts: updateUsersStatus` where missing uids retain
/// their last value, which defaults to undefined/false).
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
String _$showOnlineStatusHash() => r'a98a0d8b24375d1f560474a8f4d93873a6220853';

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
