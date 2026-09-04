// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avo_interaction_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$avoInteractionForUidHash() =>
    r'cae1f97fbc28ba9c2de6f7ba03e67a87ef0044b0';

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

/// See also [avoInteractionForUid].
@ProviderFor(avoInteractionForUid)
const avoInteractionForUidProvider = AvoInteractionForUidFamily();

/// See also [avoInteractionForUid].
class AvoInteractionForUidFamily extends Family<RemoteAvoInteraction?> {
  /// See also [avoInteractionForUid].
  const AvoInteractionForUidFamily();

  /// See also [avoInteractionForUid].
  AvoInteractionForUidProvider call(
    int uid,
  ) {
    return AvoInteractionForUidProvider(
      uid,
    );
  }

  @override
  AvoInteractionForUidProvider getProviderOverride(
    covariant AvoInteractionForUidProvider provider,
  ) {
    return call(
      provider.uid,
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
  String? get name => r'avoInteractionForUidProvider';
}

/// See also [avoInteractionForUid].
class AvoInteractionForUidProvider
    extends AutoDisposeProvider<RemoteAvoInteraction?> {
  /// See also [avoInteractionForUid].
  AvoInteractionForUidProvider(
    int uid,
  ) : this._internal(
          (ref) => avoInteractionForUid(
            ref as AvoInteractionForUidRef,
            uid,
          ),
          from: avoInteractionForUidProvider,
          name: r'avoInteractionForUidProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$avoInteractionForUidHash,
          dependencies: AvoInteractionForUidFamily._dependencies,
          allTransitiveDependencies:
              AvoInteractionForUidFamily._allTransitiveDependencies,
          uid: uid,
        );

  AvoInteractionForUidProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.uid,
  }) : super.internal();

  final int uid;

  @override
  Override overrideWith(
    RemoteAvoInteraction? Function(AvoInteractionForUidRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AvoInteractionForUidProvider._internal(
        (ref) => create(ref as AvoInteractionForUidRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        uid: uid,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<RemoteAvoInteraction?> createElement() {
    return _AvoInteractionForUidProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AvoInteractionForUidProvider && other.uid == uid;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, uid.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AvoInteractionForUidRef on AutoDisposeProviderRef<RemoteAvoInteraction?> {
  /// The parameter `uid` of this provider.
  int get uid;
}

class _AvoInteractionForUidProviderElement
    extends AutoDisposeProviderElement<RemoteAvoInteraction?>
    with AvoInteractionForUidRef {
  _AvoInteractionForUidProviderElement(super.provider);

  @override
  int get uid => (origin as AvoInteractionForUidProvider).uid;
}

String _$avoInteractionControllerHash() =>
    r'e80fbb217195c335e0a909efadf5ce18cc678fa5';

/// See also [AvoInteractionController].
@ProviderFor(AvoInteractionController)
final avoInteractionControllerProvider = NotifierProvider<
    AvoInteractionController, Map<int, RemoteAvoInteraction>>.internal(
  AvoInteractionController.new,
  name: r'avoInteractionControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$avoInteractionControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AvoInteractionController = Notifier<Map<int, RemoteAvoInteraction>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
