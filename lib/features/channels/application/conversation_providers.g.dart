// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unreadInfoHash() => r'dfce3785de7d7899695193f4cc242d7582e09473';

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

/// See also [unreadInfo].
@ProviderFor(unreadInfo)
const unreadInfoProvider = UnreadInfoFamily();

/// See also [unreadInfo].
class UnreadInfoFamily extends Family<AsyncValue<UnreadInfo>> {
  /// See also [unreadInfo].
  const UnreadInfoFamily();

  /// See also [unreadInfo].
  UnreadInfoProvider call(
    ConversationKey key,
  ) {
    return UnreadInfoProvider(
      key,
    );
  }

  @override
  UnreadInfoProvider getProviderOverride(
    covariant UnreadInfoProvider provider,
  ) {
    return call(
      provider.key,
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
  String? get name => r'unreadInfoProvider';
}

/// See also [unreadInfo].
class UnreadInfoProvider extends AutoDisposeFutureProvider<UnreadInfo> {
  /// See also [unreadInfo].
  UnreadInfoProvider(
    ConversationKey key,
  ) : this._internal(
          (ref) => unreadInfo(
            ref as UnreadInfoRef,
            key,
          ),
          from: unreadInfoProvider,
          name: r'unreadInfoProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$unreadInfoHash,
          dependencies: UnreadInfoFamily._dependencies,
          allTransitiveDependencies:
              UnreadInfoFamily._allTransitiveDependencies,
          key: key,
        );

  UnreadInfoProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.key,
  }) : super.internal();

  final ConversationKey key;

  @override
  Override overrideWith(
    FutureOr<UnreadInfo> Function(UnreadInfoRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UnreadInfoProvider._internal(
        (ref) => create(ref as UnreadInfoRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        key: key,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<UnreadInfo> createElement() {
    return _UnreadInfoProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UnreadInfoProvider && other.key == key;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, key.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UnreadInfoRef on AutoDisposeFutureProviderRef<UnreadInfo> {
  /// The parameter `key` of this provider.
  ConversationKey get key;
}

class _UnreadInfoProviderElement
    extends AutoDisposeFutureProviderElement<UnreadInfo> with UnreadInfoRef {
  _UnreadInfoProviderElement(super.provider);

  @override
  ConversationKey get key => (origin as UnreadInfoProvider).key;
}

String _$conversationsRefreshingHash() =>
    r'41c2e2a564e4139b2a07b5e2c44f0637468ac9a6';

/// See also [ConversationsRefreshing].
@ProviderFor(ConversationsRefreshing)
final conversationsRefreshingProvider =
    NotifierProvider<ConversationsRefreshing, bool>.internal(
  ConversationsRefreshing.new,
  name: r'conversationsRefreshingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$conversationsRefreshingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ConversationsRefreshing = Notifier<bool>;
String _$conversationsHash() => r'e8beed9fdfd215c07fecd51faebd0bedc681573a';

/// See also [Conversations].
@ProviderFor(Conversations)
final conversationsProvider =
    AsyncNotifierProvider<Conversations, List<ConversationItem>>.internal(
  Conversations.new,
  name: r'conversationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$conversationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Conversations = AsyncNotifier<List<ConversationItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
