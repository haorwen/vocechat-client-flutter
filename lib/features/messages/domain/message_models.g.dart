// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageImpl _$$ChatMessageImplFromJson(Map<String, dynamic> json) =>
    _$ChatMessageImpl(
      mid: (json['mid'] as num).toInt(),
      fromUid: (json['from_uid'] as num).toInt(),
      createdAt: (json['created_at'] as num).toInt(),
      target: _messageTargetFromJson(json['target'] as Map<String, dynamic>),
      detail: _messageDetailFromJson(json['detail'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ChatMessageImplToJson(_$ChatMessageImpl instance) =>
    <String, dynamic>{
      'mid': instance.mid,
      'from_uid': instance.fromUid,
      'created_at': instance.createdAt,
      'target': _messageTargetToJson(instance.target),
      'detail': _messageDetailToJson(instance.detail),
    };
