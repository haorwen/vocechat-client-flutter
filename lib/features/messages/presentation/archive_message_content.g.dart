// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_message_content.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$archiveContentHash() => r'e2d9b22684cd4f4ed474582b310a34a3c845d7a3';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [archiveContent].
@ProviderFor(archiveContent)
const archiveContentProvider = ArchiveContentFamily();

/// See also [archiveContent].
class ArchiveContentFamily extends Family<AsyncValue<Archive>> {
  /// See also [archiveContent].
  const ArchiveContentFamily();

  /// See also [archiveContent].
  ArchiveContentProvider call(
    String filePath,
  ) {
    return ArchiveContentProvider(
      filePath,
    );
  }

  @override
  ArchiveContentProvider getProviderOverride(
    covariant ArchiveContentProvider provider,
  ) {
    return call(
      provider.filePath,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'archiveContentProvider';
}

/// See also [archiveContent].
class ArchiveContentProvider extends AutoDisposeFutureProvider<Archive> {
  /// See also [archiveContent].
  ArchiveContentProvider(
    String filePath,
  ) : this._internal(
          (ref) => archiveContent(
            ref as ArchiveContentRef,
            filePath,
          ),
          from: archiveContentProvider,
          name: r'archiveContentProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$archiveContentHash,
          dependencies: ArchiveContentFamily._dependencies,
          allTransitiveDependencies:
              ArchiveContentFamily._allTransitiveDependencies,
          filePath: filePath,
        );

  ArchiveContentProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.filePath,
  }) : super.internal();

  final String filePath;

  @override
  Override overrideWith(
    FutureOr<Archive> Function(ArchiveContentRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ArchiveContentProvider._internal(
        (ref) => create(ref as ArchiveContentRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        filePath: filePath,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Archive> createElement() {
    return _ArchiveContentProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ArchiveContentProvider && other.filePath == filePath;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, filePath.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ArchiveContentRef on AutoDisposeFutureProviderRef<Archive> {
  /// The parameter `filePath` of this provider.
  String get filePath;
}

class _ArchiveContentProviderElement
    extends AutoDisposeFutureProviderElement<Archive> with ArchiveContentRef {
  _ArchiveContentProviderElement(super.provider);

  @override
  String get filePath => (origin as ArchiveContentProvider).filePath;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
