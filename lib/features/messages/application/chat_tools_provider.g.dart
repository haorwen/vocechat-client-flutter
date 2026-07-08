// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_tools_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatToolsHash() => r'096d2340a08dcb8c628685cb8621aaa577bf055c';

/// See also [chatTools].
@ProviderFor(chatTools)
final chatToolsProvider = Provider<ChatTools>.internal(
  chatTools,
  name: r'chatToolsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chatToolsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChatToolsRef = ProviderRef<ChatTools>;
String _$favoritesHash() => r'54f5bca7bf39414b1ccd4ffa822837b462695b94';

/// See also [Favorites].
@ProviderFor(Favorites)
final favoritesProvider =
    AsyncNotifierProvider<Favorites, List<FavoriteArchive>>.internal(
  Favorites.new,
  name: r'favoritesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$favoritesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Favorites = AsyncNotifier<List<FavoriteArchive>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
