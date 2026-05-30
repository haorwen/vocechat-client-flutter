// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appPackageInfoHash() => r'e52c11784c0afff54df46f0a6f46e99781e324f1';

/// App package metadata (version + build number) read once from the platform.
///
/// Used by the About pane so the displayed version tracks `pubspec.yaml`
/// instead of a hardcoded string. Kept alive: the values never change for the
/// lifetime of the process.
///
/// Copied from [appPackageInfo].
@ProviderFor(appPackageInfo)
final appPackageInfoProvider = FutureProvider<PackageInfo>.internal(
  appPackageInfo,
  name: r'appPackageInfoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appPackageInfoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppPackageInfoRef = FutureProviderRef<PackageInfo>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
