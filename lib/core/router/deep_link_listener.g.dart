// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deep_link_listener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$deepLinkListenerHash() => r'd41d8cd98f00b204e9800998ecf8427e00000001';

/// Subscribes to incoming `vocechat://` deep links (Android/iOS custom URL
/// scheme — see AndroidManifest.xml / Info.plist) for the lifetime of the
/// app, and lands any valid invitation link the same way the server-picker's
/// "use invitation link" sheet does: create+select a [ServerConfig] for the
/// link's target server, clear the current account pointer, then navigate
/// to `/register` with the magic token.
///
/// Kept alive so it isn't torn down when nothing is `ref.watch`ing it —
/// mount it once via `ref.watch(deepLinkListenerProvider)` in `main.dart`.
///
/// Copied from [DeepLinkListener].
@ProviderFor(DeepLinkListener)
final deepLinkListenerProvider =
    NotifierProvider<DeepLinkListener, void>.internal(
  DeepLinkListener.new,
  name: r'deepLinkListenerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deepLinkListenerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DeepLinkListener = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
