// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_dispatcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$messageDispatcherHash() => r'4e00ce7d4cc20e72f5823d5f9ed304927f41f06d';

/// Long-lived listener that routes every incoming SSE chat event to:
///   1. the conversations list (so previews update on the left), and
///   2. the per-target ChatController (so the chat screen has the message
///      ready the moment it's opened, even if it had never been opened
///      before — and stays in sync while it's in the background).
///
/// Kept alive for the entire app lifetime so it does NOT depend on any
/// screen being mounted.
///
/// Copied from [MessageDispatcher].
@ProviderFor(MessageDispatcher)
final messageDispatcherProvider =
    NotifierProvider<MessageDispatcher, void>.internal(
  MessageDispatcher.new,
  name: r'messageDispatcherProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$messageDispatcherHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MessageDispatcher = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
