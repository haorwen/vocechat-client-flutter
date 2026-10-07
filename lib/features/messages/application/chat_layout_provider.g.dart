// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_layout_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatLayoutHash() => r'21cf3b7ae112af408735aa265da2aef203bb2db2';

/// Server-wide message placement, shared with the web client's chat layout.
/// The dispatcher applies both the initial snapshot and live config changes.
///
/// Copied from [ChatLayout].
@ProviderFor(ChatLayout)
final chatLayoutProvider =
    NotifierProvider<ChatLayout, ChatLayoutMode>.internal(
  ChatLayout.new,
  name: r'chatLayoutProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chatLayoutHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatLayout = Notifier<ChatLayoutMode>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
