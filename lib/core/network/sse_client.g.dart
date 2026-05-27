// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sse_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sseEventsHash() => r'024cc543989bd03710460e96631b7bc32becefad';

/// See also [sseEvents].
@ProviderFor(sseEvents)
final sseEventsProvider = StreamProvider<ChatEvent>.internal(
  sseEvents,
  name: r'sseEventsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sseEventsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SseEventsRef = StreamProviderRef<ChatEvent>;
String _$sseConnectionStatusHash() =>
    r'fdd05ca360d90e37c74c3007e5944681452fa0f4';

/// See also [SseConnectionStatus].
@ProviderFor(SseConnectionStatus)
final sseConnectionStatusProvider =
    NotifierProvider<SseConnectionStatus, SseStatus>.internal(
  SseConnectionStatus.new,
  name: r'sseConnectionStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sseConnectionStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SseConnectionStatus = Notifier<SseStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
