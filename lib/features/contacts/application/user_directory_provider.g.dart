// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_directory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userDirectoryHash() => r'01839c105569cac13a60db82bc60bc7784b5da65';

/// See also [UserDirectory].
@ProviderFor(UserDirectory)
final userDirectoryProvider =
    AsyncNotifierProvider<UserDirectory, Map<int, UserSummary>>.internal(
  UserDirectory.new,
  name: r'userDirectoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userDirectoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserDirectory = AsyncNotifier<Map<int, UserSummary>>;
String _$groupDirectoryHash() => r'41b158280e747f1ce14b10e7c522740a00d05be2';

/// See also [GroupDirectory].
@ProviderFor(GroupDirectory)
final groupDirectoryProvider =
    AsyncNotifierProvider<GroupDirectory, Map<int, GroupSummary>>.internal(
  GroupDirectory.new,
  name: r'groupDirectoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$groupDirectoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GroupDirectory = AsyncNotifier<Map<int, GroupSummary>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
