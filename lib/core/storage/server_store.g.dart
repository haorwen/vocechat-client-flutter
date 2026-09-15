// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_store.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ServerConfigImpl _$$ServerConfigImplFromJson(Map<String, dynamic> json) =>
    _$ServerConfigImpl(
      id: json['id'] as String,
      baseUrl: json['baseUrl'] as String,
      name: json['name'] as String,
      orgLogo: json['orgLogo'] as String?,
      organizationServerId: json['organization_server_id'] as String?,
    );

Map<String, dynamic> _$$ServerConfigImplToJson(_$ServerConfigImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'baseUrl': instance.baseUrl,
      'name': instance.name,
      'orgLogo': instance.orgLogo,
      'organization_server_id': instance.organizationServerId,
    };

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$serverStoreHash() => r'03ccf7546e4d4ffd384a05a22342765351b20dbd';

/// See also [ServerStore].
@ProviderFor(ServerStore)
final serverStoreProvider =
    AutoDisposeAsyncNotifierProvider<ServerStore, ServerState>.internal(
  ServerStore.new,
  name: r'serverStoreProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$serverStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ServerStore = AutoDisposeAsyncNotifier<ServerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
