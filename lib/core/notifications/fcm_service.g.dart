// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fcm_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fcmServiceHash() => r'bc2383f6aa9c8790e3ab0ba6cee477c7689366a5';

/// Initialises Firebase Messaging on Android/iOS and wires up notification
/// tap handlers. keepAlive ensures listeners are never torn down for the app's
/// lifetime. No-op on all other platforms.
///
/// Copied from [fcmService].
@ProviderFor(fcmService)
final fcmServiceProvider = FutureProvider<void>.internal(
  fcmService,
  name: r'fcmServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$fcmServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FcmServiceRef = FutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
