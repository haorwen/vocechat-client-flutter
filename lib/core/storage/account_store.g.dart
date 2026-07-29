// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_store.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccountConfigImpl _$$AccountConfigImplFromJson(Map<String, dynamic> json) =>
    _$AccountConfigImpl(
      accountId: json['accountId'] as String,
      serverId: json['serverId'] as String,
      uid: (json['uid'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
      avatarUpdatedAt: (json['avatarUpdatedAt'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$AccountConfigImplToJson(
        _$AccountConfigImpl instance) =>
    <String, dynamic>{
      'accountId': instance.accountId,
      'serverId': instance.serverId,
      'uid': instance.uid,
      'name': instance.name,
      'email': instance.email,
      'isAdmin': instance.isAdmin,
      'avatarUpdatedAt': instance.avatarUpdatedAt,
    };

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$accountStoreHash() => r'a1c6d8f0e2b4a6c8d0e2b4a6c8d0e2b4a6c8d0e2';

/// See also [AccountStore].
@ProviderFor(AccountStore)
final accountStoreProvider =
    AutoDisposeAsyncNotifierProvider<AccountStore, AccountState>.internal(
  AccountStore.new,
  name: r'accountStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AccountStore = AutoDisposeAsyncNotifier<AccountState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
