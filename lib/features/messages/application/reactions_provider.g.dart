// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reactions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$messageReactionsHash() => r'766a023440e013f41cc6e8481ab4f899f0a94622';

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

/// Convenience selector — reactions for a single message id (returns null if
/// none, so widgets can early-return without rebuilding on unrelated changes).
///
/// Copied from [messageReactions].
@ProviderFor(messageReactions)
const messageReactionsProvider = MessageReactionsFamily();

/// Convenience selector — reactions for a single message id (returns null if
/// none, so widgets can early-return without rebuilding on unrelated changes).
///
/// Copied from [messageReactions].
class MessageReactionsFamily extends Family<Map<String, List<int>>?> {
  /// Convenience selector — reactions for a single message id (returns null if
  /// none, so widgets can early-return without rebuilding on unrelated changes).
  ///
  /// Copied from [messageReactions].
  const MessageReactionsFamily();

  /// Convenience selector — reactions for a single message id (returns null if
  /// none, so widgets can early-return without rebuilding on unrelated changes).
  ///
  /// Copied from [messageReactions].
  MessageReactionsProvider call(
    int mid,
  ) {
    return MessageReactionsProvider(
      mid,
    );
  }

  @override
  MessageReactionsProvider getProviderOverride(
    covariant MessageReactionsProvider provider,
  ) {
    return call(
      provider.mid,
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
  String? get name => r'messageReactionsProvider';
}

/// Convenience selector — reactions for a single message id (returns null if
/// none, so widgets can early-return without rebuilding on unrelated changes).
///
/// Copied from [messageReactions].
class MessageReactionsProvider
    extends AutoDisposeProvider<Map<String, List<int>>?> {
  /// Convenience selector — reactions for a single message id (returns null if
  /// none, so widgets can early-return without rebuilding on unrelated changes).
  ///
  /// Copied from [messageReactions].
  MessageReactionsProvider(
    int mid,
  ) : this._internal(
          (ref) => messageReactions(
            ref as MessageReactionsRef,
            mid,
          ),
          from: messageReactionsProvider,
          name: r'messageReactionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$messageReactionsHash,
          dependencies: MessageReactionsFamily._dependencies,
          allTransitiveDependencies:
              MessageReactionsFamily._allTransitiveDependencies,
          mid: mid,
        );

  MessageReactionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.mid,
  }) : super.internal();

  final int mid;

  @override
  Override overrideWith(
    Map<String, List<int>>? Function(MessageReactionsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MessageReactionsProvider._internal(
        (ref) => create(ref as MessageReactionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        mid: mid,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<Map<String, List<int>>?> createElement() {
    return _MessageReactionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MessageReactionsProvider && other.mid == mid;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, mid.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MessageReactionsRef on AutoDisposeProviderRef<Map<String, List<int>>?> {
  /// The parameter `mid` of this provider.
  int get mid;
}

class _MessageReactionsProviderElement
    extends AutoDisposeProviderElement<Map<String, List<int>>?>
    with MessageReactionsRef {
  _MessageReactionsProviderElement(super.provider);

  @override
  int get mid => (origin as MessageReactionsProvider).mid;
}

String _$reactionsHash() => r'125610f7c0baf2a8a46bc4687dc2d5a13cb893f9';

/// Per-message reaction state: { mid -> { emoji -> [uid, ...] } }.
///
/// Mirrors the web client's `message.reaction.ts` slice. We keep this as a
/// dedicated provider (separate from `ChatController`) for two reasons:
///   1. Reactions are global to the workspace: a reaction on a message in
///      channel A may arrive while channel B is open. The lookup is by `mid`,
///      not by target.
///   2. `ChatController` lists are partial (we only have the recent window).
///      Reaction events for older messages still need somewhere to land so
///      they're correct if the user scrolls back.
///
/// Copied from [Reactions].
@ProviderFor(Reactions)
final reactionsProvider =
    NotifierProvider<Reactions, Map<int, Map<String, List<int>>>>.internal(
  Reactions.new,
  name: r'reactionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$reactionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Reactions = Notifier<Map<int, Map<String, List<int>>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
