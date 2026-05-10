// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PasswordCredentialImpl _$$PasswordCredentialImplFromJson(
        Map<String, dynamic> json) =>
    _$PasswordCredentialImpl(
      email: json['email'] as String,
      password: json['password'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$PasswordCredentialImplToJson(
        _$PasswordCredentialImpl instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
      'type': instance.$type,
    };

_$MagicLinkCredentialImpl _$$MagicLinkCredentialImplFromJson(
        Map<String, dynamic> json) =>
    _$MagicLinkCredentialImpl(
      email: json['email'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$$MagicLinkCredentialImplToJson(
        _$MagicLinkCredentialImpl instance) =>
    <String, dynamic>{
      'email': instance.email,
      'type': instance.$type,
    };

_$VoceUserImpl _$$VoceUserImplFromJson(Map<String, dynamic> json) =>
    _$VoceUserImpl(
      uid: (json['uid'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      avatarUpdatedAt: (json['avatar_updated_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$VoceUserImplToJson(_$VoceUserImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'name': instance.name,
      'email': instance.email,
      'is_admin': instance.isAdmin,
      'avatar_updated_at': instance.avatarUpdatedAt,
    };

_$LoginRequestImpl _$$LoginRequestImplFromJson(Map<String, dynamic> json) =>
    _$LoginRequestImpl(
      credential:
          Credential.fromJson(json['credential'] as Map<String, dynamic>),
      device: json['device'] as String,
      deviceToken: json['device_token'] as String?,
    );

Map<String, dynamic> _$$LoginRequestImplToJson(_$LoginRequestImpl instance) =>
    <String, dynamic>{
      'credential': instance.credential,
      'device': instance.device,
      'device_token': instance.deviceToken,
    };

_$AuthResponseImpl _$$AuthResponseImplFromJson(Map<String, dynamic> json) =>
    _$AuthResponseImpl(
      serverId: json['server_id'] as String,
      token: json['token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiredIn: (json['expired_in'] as num).toInt(),
      user: VoceUser.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$AuthResponseImplToJson(_$AuthResponseImpl instance) =>
    <String, dynamic>{
      'server_id': instance.serverId,
      'token': instance.token,
      'refresh_token': instance.refreshToken,
      'expired_in': instance.expiredIn,
      'user': instance.user,
    };

_$RenewResponseImpl _$$RenewResponseImplFromJson(Map<String, dynamic> json) =>
    _$RenewResponseImpl(
      token: json['token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiredIn: (json['expired_in'] as num).toInt(),
    );

Map<String, dynamic> _$$RenewResponseImplToJson(_$RenewResponseImpl instance) =>
    <String, dynamic>{
      'token': instance.token,
      'refresh_token': instance.refreshToken,
      'expired_in': instance.expiredIn,
    };
