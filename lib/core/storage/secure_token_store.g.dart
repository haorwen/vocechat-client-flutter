// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secure_token_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$secureTokenStoreHash() => r'05cc1cf1948005f6ad89726ac7a3528fa55174a2';

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

/// See also [secureTokenStore].
@ProviderFor(secureTokenStore)
const secureTokenStoreProvider = SecureTokenStoreFamily();

/// See also [secureTokenStore].
class SecureTokenStoreFamily extends Family<SecureTokenStore> {
  /// See also [secureTokenStore].
  const SecureTokenStoreFamily();

  /// See also [secureTokenStore].
  SecureTokenStoreProvider call(
    String serverId,
  ) {
    return SecureTokenStoreProvider(
      serverId,
    );
  }

  @override
  SecureTokenStoreProvider getProviderOverride(
    covariant SecureTokenStoreProvider provider,
  ) {
    return call(
      provider.serverId,
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
  String? get name => r'secureTokenStoreProvider';
}

/// See also [secureTokenStore].
class SecureTokenStoreProvider extends AutoDisposeProvider<SecureTokenStore> {
  /// See also [secureTokenStore].
  SecureTokenStoreProvider(
    String serverId,
  ) : this._internal(
          (ref) => secureTokenStore(
            ref as SecureTokenStoreRef,
            serverId,
          ),
          from: secureTokenStoreProvider,
          name: r'secureTokenStoreProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$secureTokenStoreHash,
          dependencies: SecureTokenStoreFamily._dependencies,
          allTransitiveDependencies:
              SecureTokenStoreFamily._allTransitiveDependencies,
          serverId: serverId,
        );

  SecureTokenStoreProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.serverId,
  }) : super.internal();

  final String serverId;

  @override
  Override overrideWith(
    SecureTokenStore Function(SecureTokenStoreRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SecureTokenStoreProvider._internal(
        (ref) => create(ref as SecureTokenStoreRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        serverId: serverId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<SecureTokenStore> createElement() {
    return _SecureTokenStoreProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SecureTokenStoreProvider && other.serverId == serverId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, serverId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SecureTokenStoreRef on AutoDisposeProviderRef<SecureTokenStore> {
  /// The parameter `serverId` of this provider.
  String get serverId;
}

class _SecureTokenStoreProviderElement
    extends AutoDisposeProviderElement<SecureTokenStore>
    with SecureTokenStoreRef {
  _SecureTokenStoreProviderElement(super.provider);

  @override
  String get serverId => (origin as SecureTokenStoreProvider).serverId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
