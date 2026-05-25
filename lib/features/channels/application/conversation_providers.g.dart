// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unreadCountHash() => r'79f92c6f54c9684a9127d1d502ed77eff00eb622';

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

/// See also [unreadCount].
@ProviderFor(unreadCount)
const unreadCountProvider = UnreadCountFamily();

/// See also [unreadCount].
class UnreadCountFamily extends Family<int> {
  /// See also [unreadCount].
  const UnreadCountFamily();

  /// See also [unreadCount].
  UnreadCountProvider call(
    ConversationKey key,
  ) {
    return UnreadCountProvider(
      key,
    );
  }

  @override
  UnreadCountProvider getProviderOverride(
    covariant UnreadCountProvider provider,
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
  String? get name => r'unreadCountProvider';
}

/// See also [unreadCount].
class UnreadCountProvider extends AutoDisposeProvider<int> {
  /// See also [unreadCount].
  UnreadCountProvider(
    ConversationKey key,
  ) : this._internal(
          (ref) => unreadCount(
            ref as UnreadCountRef,
            key,
          ),
          from: unreadCountProvider,
          name: r'unreadCountProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$unreadCountHash,
          dependencies: UnreadCountFamily._dependencies,
          allTransitiveDependencies:
              UnreadCountFamily._allTransitiveDependencies,
          key: key,
        );

  UnreadCountProvider._internal(
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
    int Function(UnreadCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UnreadCountProvider._internal(
        (ref) => create(ref as UnreadCountRef),
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
  AutoDisposeProviderElement<int> createElement() {
    return _UnreadCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UnreadCountProvider && other.key == key;
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
mixin UnreadCountRef on AutoDisposeProviderRef<int> {
  /// The parameter `key` of this provider.
  ConversationKey get key;
}

class _UnreadCountProviderElement extends AutoDisposeProviderElement<int>
    with UnreadCountRef {
  _UnreadCountProviderElement(super.provider);

  @override
  ConversationKey get key => (origin as UnreadCountProvider).key;
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
String _$conversationsHash() => r'f4e6f68760816066188f75e07039aba3c369bda2';

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
