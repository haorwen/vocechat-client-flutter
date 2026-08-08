// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$messageCacheHash() => r'9c62f3e946e9bb6809ad81d5317b86e5b66b9d7b';

/// See also [messageCache].
@ProviderFor(messageCache)
final messageCacheProvider = FutureProvider<MessageCache>.internal(
  messageCache,
  name: r'messageCacheProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$messageCacheHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MessageCacheRef = FutureProviderRef<MessageCache>;
String _$cacheUsageBytesHash() => r'b26cccf776b09a3b6f10f5acba84f0a04f4465ea';

/// Total on-disk bytes used by the app's caches: the SQLite message/meta
/// database plus the `flutter_cache_manager` image/file store. Recomputed on
/// each watch (not kept alive) so the settings readout reflects clears and
/// growth; `ref.invalidate` after "clear cache" drops it back to ~0.
///
/// Copied from [cacheUsageBytes].
@ProviderFor(cacheUsageBytes)
final cacheUsageBytesProvider = AutoDisposeFutureProvider<int>.internal(
  cacheUsageBytes,
  name: r'cacheUsageBytesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cacheUsageBytesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CacheUsageBytesRef = AutoDisposeFutureProviderRef<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
