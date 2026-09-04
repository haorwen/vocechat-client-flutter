// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$VoicingInfo {
  MessageTarget get context => throw _privateConstructorUsedError;
  bool get joining => throw _privateConstructorUsedError;
  VoiceConnectionState? get connectionState =>
      throw _privateConstructorUsedError;
  int? get downlinkNetworkQuality => throw _privateConstructorUsedError;
  bool get muted => throw _privateConstructorUsedError;
  bool get deafen => throw _privateConstructorUsedError;
  bool get video => throw _privateConstructorUsedError;
  bool get shareScreen => throw _privateConstructorUsedError;
  int get speakingVolume => throw _privateConstructorUsedError;

  /// Create a copy of VoicingInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoicingInfoCopyWith<VoicingInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoicingInfoCopyWith<$Res> {
  factory $VoicingInfoCopyWith(
          VoicingInfo value, $Res Function(VoicingInfo) then) =
      _$VoicingInfoCopyWithImpl<$Res, VoicingInfo>;
  @useResult
  $Res call(
      {MessageTarget context,
      bool joining,
      VoiceConnectionState? connectionState,
      int? downlinkNetworkQuality,
      bool muted,
      bool deafen,
      bool video,
      bool shareScreen,
      int speakingVolume});

  $MessageTargetCopyWith<$Res> get context;
}

/// @nodoc
class _$VoicingInfoCopyWithImpl<$Res, $Val extends VoicingInfo>
    implements $VoicingInfoCopyWith<$Res> {
  _$VoicingInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoicingInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? context = null,
    Object? joining = null,
    Object? connectionState = freezed,
    Object? downlinkNetworkQuality = freezed,
    Object? muted = null,
    Object? deafen = null,
    Object? video = null,
    Object? shareScreen = null,
    Object? speakingVolume = null,
  }) {
    return _then(_value.copyWith(
      context: null == context
          ? _value.context
          : context // ignore: cast_nullable_to_non_nullable
              as MessageTarget,
      joining: null == joining
          ? _value.joining
          : joining // ignore: cast_nullable_to_non_nullable
              as bool,
      connectionState: freezed == connectionState
          ? _value.connectionState
          : connectionState // ignore: cast_nullable_to_non_nullable
              as VoiceConnectionState?,
      downlinkNetworkQuality: freezed == downlinkNetworkQuality
          ? _value.downlinkNetworkQuality
          : downlinkNetworkQuality // ignore: cast_nullable_to_non_nullable
              as int?,
      muted: null == muted
          ? _value.muted
          : muted // ignore: cast_nullable_to_non_nullable
              as bool,
      deafen: null == deafen
          ? _value.deafen
          : deafen // ignore: cast_nullable_to_non_nullable
              as bool,
      video: null == video
          ? _value.video
          : video // ignore: cast_nullable_to_non_nullable
              as bool,
      shareScreen: null == shareScreen
          ? _value.shareScreen
          : shareScreen // ignore: cast_nullable_to_non_nullable
              as bool,
      speakingVolume: null == speakingVolume
          ? _value.speakingVolume
          : speakingVolume // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of VoicingInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageTargetCopyWith<$Res> get context {
    return $MessageTargetCopyWith<$Res>(_value.context, (value) {
      return _then(_value.copyWith(context: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$VoicingInfoImplCopyWith<$Res>
    implements $VoicingInfoCopyWith<$Res> {
  factory _$$VoicingInfoImplCopyWith(
          _$VoicingInfoImpl value, $Res Function(_$VoicingInfoImpl) then) =
      __$$VoicingInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {MessageTarget context,
      bool joining,
      VoiceConnectionState? connectionState,
      int? downlinkNetworkQuality,
      bool muted,
      bool deafen,
      bool video,
      bool shareScreen,
      int speakingVolume});

  @override
  $MessageTargetCopyWith<$Res> get context;
}

/// @nodoc
class __$$VoicingInfoImplCopyWithImpl<$Res>
    extends _$VoicingInfoCopyWithImpl<$Res, _$VoicingInfoImpl>
    implements _$$VoicingInfoImplCopyWith<$Res> {
  __$$VoicingInfoImplCopyWithImpl(
      _$VoicingInfoImpl _value, $Res Function(_$VoicingInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of VoicingInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? context = null,
    Object? joining = null,
    Object? connectionState = freezed,
    Object? downlinkNetworkQuality = freezed,
    Object? muted = null,
    Object? deafen = null,
    Object? video = null,
    Object? shareScreen = null,
    Object? speakingVolume = null,
  }) {
    return _then(_$VoicingInfoImpl(
      context: null == context
          ? _value.context
          : context // ignore: cast_nullable_to_non_nullable
              as MessageTarget,
      joining: null == joining
          ? _value.joining
          : joining // ignore: cast_nullable_to_non_nullable
              as bool,
      connectionState: freezed == connectionState
          ? _value.connectionState
          : connectionState // ignore: cast_nullable_to_non_nullable
              as VoiceConnectionState?,
      downlinkNetworkQuality: freezed == downlinkNetworkQuality
          ? _value.downlinkNetworkQuality
          : downlinkNetworkQuality // ignore: cast_nullable_to_non_nullable
              as int?,
      muted: null == muted
          ? _value.muted
          : muted // ignore: cast_nullable_to_non_nullable
              as bool,
      deafen: null == deafen
          ? _value.deafen
          : deafen // ignore: cast_nullable_to_non_nullable
              as bool,
      video: null == video
          ? _value.video
          : video // ignore: cast_nullable_to_non_nullable
              as bool,
      shareScreen: null == shareScreen
          ? _value.shareScreen
          : shareScreen // ignore: cast_nullable_to_non_nullable
              as bool,
      speakingVolume: null == speakingVolume
          ? _value.speakingVolume
          : speakingVolume // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$VoicingInfoImpl implements _VoicingInfo {
  const _$VoicingInfoImpl(
      {required this.context,
      this.joining = false,
      this.connectionState,
      this.downlinkNetworkQuality,
      this.muted = false,
      this.deafen = false,
      this.video = false,
      this.shareScreen = false,
      this.speakingVolume = 0});

  @override
  final MessageTarget context;
  @override
  @JsonKey()
  final bool joining;
  @override
  final VoiceConnectionState? connectionState;
  @override
  final int? downlinkNetworkQuality;
  @override
  @JsonKey()
  final bool muted;
  @override
  @JsonKey()
  final bool deafen;
  @override
  @JsonKey()
  final bool video;
  @override
  @JsonKey()
  final bool shareScreen;
  @override
  @JsonKey()
  final int speakingVolume;

  @override
  String toString() {
    return 'VoicingInfo(context: $context, joining: $joining, connectionState: $connectionState, downlinkNetworkQuality: $downlinkNetworkQuality, muted: $muted, deafen: $deafen, video: $video, shareScreen: $shareScreen, speakingVolume: $speakingVolume)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoicingInfoImpl &&
            (identical(other.context, context) || other.context == context) &&
            (identical(other.joining, joining) || other.joining == joining) &&
            (identical(other.connectionState, connectionState) ||
                other.connectionState == connectionState) &&
            (identical(other.downlinkNetworkQuality, downlinkNetworkQuality) ||
                other.downlinkNetworkQuality == downlinkNetworkQuality) &&
            (identical(other.muted, muted) || other.muted == muted) &&
            (identical(other.deafen, deafen) || other.deafen == deafen) &&
            (identical(other.video, video) || other.video == video) &&
            (identical(other.shareScreen, shareScreen) ||
                other.shareScreen == shareScreen) &&
            (identical(other.speakingVolume, speakingVolume) ||
                other.speakingVolume == speakingVolume));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      context,
      joining,
      connectionState,
      downlinkNetworkQuality,
      muted,
      deafen,
      video,
      shareScreen,
      speakingVolume);

  /// Create a copy of VoicingInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoicingInfoImplCopyWith<_$VoicingInfoImpl> get copyWith =>
      __$$VoicingInfoImplCopyWithImpl<_$VoicingInfoImpl>(this, _$identity);
}

abstract class _VoicingInfo implements VoicingInfo {
  const factory _VoicingInfo(
      {required final MessageTarget context,
      final bool joining,
      final VoiceConnectionState? connectionState,
      final int? downlinkNetworkQuality,
      final bool muted,
      final bool deafen,
      final bool video,
      final bool shareScreen,
      final int speakingVolume}) = _$VoicingInfoImpl;

  @override
  MessageTarget get context;
  @override
  bool get joining;
  @override
  VoiceConnectionState? get connectionState;
  @override
  int? get downlinkNetworkQuality;
  @override
  bool get muted;
  @override
  bool get deafen;
  @override
  bool get video;
  @override
  bool get shareScreen;
  @override
  int get speakingVolume;

  /// Create a copy of VoicingInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoicingInfoImplCopyWith<_$VoicingInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$VoicingMemberInfo {
  int get speakingVolume => throw _privateConstructorUsedError;
  bool get muted => throw _privateConstructorUsedError;
  bool get video => throw _privateConstructorUsedError;
  bool get shareScreen => throw _privateConstructorUsedError;

  /// Create a copy of VoicingMemberInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoicingMemberInfoCopyWith<VoicingMemberInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoicingMemberInfoCopyWith<$Res> {
  factory $VoicingMemberInfoCopyWith(
          VoicingMemberInfo value, $Res Function(VoicingMemberInfo) then) =
      _$VoicingMemberInfoCopyWithImpl<$Res, VoicingMemberInfo>;
  @useResult
  $Res call({int speakingVolume, bool muted, bool video, bool shareScreen});
}

/// @nodoc
class _$VoicingMemberInfoCopyWithImpl<$Res, $Val extends VoicingMemberInfo>
    implements $VoicingMemberInfoCopyWith<$Res> {
  _$VoicingMemberInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoicingMemberInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? speakingVolume = null,
    Object? muted = null,
    Object? video = null,
    Object? shareScreen = null,
  }) {
    return _then(_value.copyWith(
      speakingVolume: null == speakingVolume
          ? _value.speakingVolume
          : speakingVolume // ignore: cast_nullable_to_non_nullable
              as int,
      muted: null == muted
          ? _value.muted
          : muted // ignore: cast_nullable_to_non_nullable
              as bool,
      video: null == video
          ? _value.video
          : video // ignore: cast_nullable_to_non_nullable
              as bool,
      shareScreen: null == shareScreen
          ? _value.shareScreen
          : shareScreen // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VoicingMemberInfoImplCopyWith<$Res>
    implements $VoicingMemberInfoCopyWith<$Res> {
  factory _$$VoicingMemberInfoImplCopyWith(_$VoicingMemberInfoImpl value,
          $Res Function(_$VoicingMemberInfoImpl) then) =
      __$$VoicingMemberInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int speakingVolume, bool muted, bool video, bool shareScreen});
}

/// @nodoc
class __$$VoicingMemberInfoImplCopyWithImpl<$Res>
    extends _$VoicingMemberInfoCopyWithImpl<$Res, _$VoicingMemberInfoImpl>
    implements _$$VoicingMemberInfoImplCopyWith<$Res> {
  __$$VoicingMemberInfoImplCopyWithImpl(_$VoicingMemberInfoImpl _value,
      $Res Function(_$VoicingMemberInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of VoicingMemberInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? speakingVolume = null,
    Object? muted = null,
    Object? video = null,
    Object? shareScreen = null,
  }) {
    return _then(_$VoicingMemberInfoImpl(
      speakingVolume: null == speakingVolume
          ? _value.speakingVolume
          : speakingVolume // ignore: cast_nullable_to_non_nullable
              as int,
      muted: null == muted
          ? _value.muted
          : muted // ignore: cast_nullable_to_non_nullable
              as bool,
      video: null == video
          ? _value.video
          : video // ignore: cast_nullable_to_non_nullable
              as bool,
      shareScreen: null == shareScreen
          ? _value.shareScreen
          : shareScreen // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$VoicingMemberInfoImpl implements _VoicingMemberInfo {
  const _$VoicingMemberInfoImpl(
      {this.speakingVolume = 0,
      this.muted = false,
      this.video = false,
      this.shareScreen = false});

  @override
  @JsonKey()
  final int speakingVolume;
  @override
  @JsonKey()
  final bool muted;
  @override
  @JsonKey()
  final bool video;
  @override
  @JsonKey()
  final bool shareScreen;

  @override
  String toString() {
    return 'VoicingMemberInfo(speakingVolume: $speakingVolume, muted: $muted, video: $video, shareScreen: $shareScreen)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoicingMemberInfoImpl &&
            (identical(other.speakingVolume, speakingVolume) ||
                other.speakingVolume == speakingVolume) &&
            (identical(other.muted, muted) || other.muted == muted) &&
            (identical(other.video, video) || other.video == video) &&
            (identical(other.shareScreen, shareScreen) ||
                other.shareScreen == shareScreen));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, speakingVolume, muted, video, shareScreen);

  /// Create a copy of VoicingMemberInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoicingMemberInfoImplCopyWith<_$VoicingMemberInfoImpl> get copyWith =>
      __$$VoicingMemberInfoImplCopyWithImpl<_$VoicingMemberInfoImpl>(
          this, _$identity);
}

abstract class _VoicingMemberInfo implements VoicingMemberInfo {
  const factory _VoicingMemberInfo(
      {final int speakingVolume,
      final bool muted,
      final bool video,
      final bool shareScreen}) = _$VoicingMemberInfoImpl;

  @override
  int get speakingVolume;
  @override
  bool get muted;
  @override
  bool get video;
  @override
  bool get shareScreen;

  /// Create a copy of VoicingMemberInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoicingMemberInfoImplCopyWith<_$VoicingMemberInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$VoicingMembers {
  List<int> get ids => throw _privateConstructorUsedError;
  Map<int, VoicingMemberInfo> get byId => throw _privateConstructorUsedError;
  int? get pin => throw _privateConstructorUsedError;

  /// Create a copy of VoicingMembers
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoicingMembersCopyWith<VoicingMembers> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoicingMembersCopyWith<$Res> {
  factory $VoicingMembersCopyWith(
          VoicingMembers value, $Res Function(VoicingMembers) then) =
      _$VoicingMembersCopyWithImpl<$Res, VoicingMembers>;
  @useResult
  $Res call({List<int> ids, Map<int, VoicingMemberInfo> byId, int? pin});
}

/// @nodoc
class _$VoicingMembersCopyWithImpl<$Res, $Val extends VoicingMembers>
    implements $VoicingMembersCopyWith<$Res> {
  _$VoicingMembersCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoicingMembers
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ids = null,
    Object? byId = null,
    Object? pin = freezed,
  }) {
    return _then(_value.copyWith(
      ids: null == ids
          ? _value.ids
          : ids // ignore: cast_nullable_to_non_nullable
              as List<int>,
      byId: null == byId
          ? _value.byId
          : byId // ignore: cast_nullable_to_non_nullable
              as Map<int, VoicingMemberInfo>,
      pin: freezed == pin
          ? _value.pin
          : pin // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VoicingMembersImplCopyWith<$Res>
    implements $VoicingMembersCopyWith<$Res> {
  factory _$$VoicingMembersImplCopyWith(_$VoicingMembersImpl value,
          $Res Function(_$VoicingMembersImpl) then) =
      __$$VoicingMembersImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<int> ids, Map<int, VoicingMemberInfo> byId, int? pin});
}

/// @nodoc
class __$$VoicingMembersImplCopyWithImpl<$Res>
    extends _$VoicingMembersCopyWithImpl<$Res, _$VoicingMembersImpl>
    implements _$$VoicingMembersImplCopyWith<$Res> {
  __$$VoicingMembersImplCopyWithImpl(
      _$VoicingMembersImpl _value, $Res Function(_$VoicingMembersImpl) _then)
      : super(_value, _then);

  /// Create a copy of VoicingMembers
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ids = null,
    Object? byId = null,
    Object? pin = freezed,
  }) {
    return _then(_$VoicingMembersImpl(
      ids: null == ids
          ? _value._ids
          : ids // ignore: cast_nullable_to_non_nullable
              as List<int>,
      byId: null == byId
          ? _value._byId
          : byId // ignore: cast_nullable_to_non_nullable
              as Map<int, VoicingMemberInfo>,
      pin: freezed == pin
          ? _value.pin
          : pin // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$VoicingMembersImpl implements _VoicingMembers {
  const _$VoicingMembersImpl(
      {final List<int> ids = const <int>[],
      final Map<int, VoicingMemberInfo> byId = const <int, VoicingMemberInfo>{},
      this.pin})
      : _ids = ids,
        _byId = byId;

  final List<int> _ids;
  @override
  @JsonKey()
  List<int> get ids {
    if (_ids is EqualUnmodifiableListView) return _ids;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ids);
  }

  final Map<int, VoicingMemberInfo> _byId;
  @override
  @JsonKey()
  Map<int, VoicingMemberInfo> get byId {
    if (_byId is EqualUnmodifiableMapView) return _byId;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_byId);
  }

  @override
  final int? pin;

  @override
  String toString() {
    return 'VoicingMembers(ids: $ids, byId: $byId, pin: $pin)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoicingMembersImpl &&
            const DeepCollectionEquality().equals(other._ids, _ids) &&
            const DeepCollectionEquality().equals(other._byId, _byId) &&
            (identical(other.pin, pin) || other.pin == pin));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_ids),
      const DeepCollectionEquality().hash(_byId),
      pin);

  /// Create a copy of VoicingMembers
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoicingMembersImplCopyWith<_$VoicingMembersImpl> get copyWith =>
      __$$VoicingMembersImplCopyWithImpl<_$VoicingMembersImpl>(
          this, _$identity);
}

abstract class _VoicingMembers implements VoicingMembers {
  const factory _VoicingMembers(
      {final List<int> ids,
      final Map<int, VoicingMemberInfo> byId,
      final int? pin}) = _$VoicingMembersImpl;

  @override
  List<int> get ids;
  @override
  Map<int, VoicingMemberInfo> get byId;
  @override
  int? get pin;

  /// Create a copy of VoicingMembers
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoicingMembersImplCopyWith<_$VoicingMembersImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$IncomingCallState {
  int get fromUid => throw _privateConstructorUsedError;
  int get toUid => throw _privateConstructorUsedError;
  bool get calling => throw _privateConstructorUsedError;

  /// Create a copy of IncomingCallState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IncomingCallStateCopyWith<IncomingCallState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IncomingCallStateCopyWith<$Res> {
  factory $IncomingCallStateCopyWith(
          IncomingCallState value, $Res Function(IncomingCallState) then) =
      _$IncomingCallStateCopyWithImpl<$Res, IncomingCallState>;
  @useResult
  $Res call({int fromUid, int toUid, bool calling});
}

/// @nodoc
class _$IncomingCallStateCopyWithImpl<$Res, $Val extends IncomingCallState>
    implements $IncomingCallStateCopyWith<$Res> {
  _$IncomingCallStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of IncomingCallState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fromUid = null,
    Object? toUid = null,
    Object? calling = null,
  }) {
    return _then(_value.copyWith(
      fromUid: null == fromUid
          ? _value.fromUid
          : fromUid // ignore: cast_nullable_to_non_nullable
              as int,
      toUid: null == toUid
          ? _value.toUid
          : toUid // ignore: cast_nullable_to_non_nullable
              as int,
      calling: null == calling
          ? _value.calling
          : calling // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$IncomingCallStateImplCopyWith<$Res>
    implements $IncomingCallStateCopyWith<$Res> {
  factory _$$IncomingCallStateImplCopyWith(_$IncomingCallStateImpl value,
          $Res Function(_$IncomingCallStateImpl) then) =
      __$$IncomingCallStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int fromUid, int toUid, bool calling});
}

/// @nodoc
class __$$IncomingCallStateImplCopyWithImpl<$Res>
    extends _$IncomingCallStateCopyWithImpl<$Res, _$IncomingCallStateImpl>
    implements _$$IncomingCallStateImplCopyWith<$Res> {
  __$$IncomingCallStateImplCopyWithImpl(_$IncomingCallStateImpl _value,
      $Res Function(_$IncomingCallStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of IncomingCallState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fromUid = null,
    Object? toUid = null,
    Object? calling = null,
  }) {
    return _then(_$IncomingCallStateImpl(
      fromUid: null == fromUid
          ? _value.fromUid
          : fromUid // ignore: cast_nullable_to_non_nullable
              as int,
      toUid: null == toUid
          ? _value.toUid
          : toUid // ignore: cast_nullable_to_non_nullable
              as int,
      calling: null == calling
          ? _value.calling
          : calling // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$IncomingCallStateImpl implements _IncomingCallState {
  const _$IncomingCallStateImpl(
      {this.fromUid = 0, this.toUid = 0, this.calling = false});

  @override
  @JsonKey()
  final int fromUid;
  @override
  @JsonKey()
  final int toUid;
  @override
  @JsonKey()
  final bool calling;

  @override
  String toString() {
    return 'IncomingCallState(fromUid: $fromUid, toUid: $toUid, calling: $calling)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IncomingCallStateImpl &&
            (identical(other.fromUid, fromUid) || other.fromUid == fromUid) &&
            (identical(other.toUid, toUid) || other.toUid == toUid) &&
            (identical(other.calling, calling) || other.calling == calling));
  }

  @override
  int get hashCode => Object.hash(runtimeType, fromUid, toUid, calling);

  /// Create a copy of IncomingCallState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IncomingCallStateImplCopyWith<_$IncomingCallStateImpl> get copyWith =>
      __$$IncomingCallStateImplCopyWithImpl<_$IncomingCallStateImpl>(
          this, _$identity);
}

abstract class _IncomingCallState implements IncomingCallState {
  const factory _IncomingCallState(
      {final int fromUid,
      final int toUid,
      final bool calling}) = _$IncomingCallStateImpl;

  @override
  int get fromUid;
  @override
  int get toUid;
  @override
  bool get calling;

  /// Create a copy of IncomingCallState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IncomingCallStateImplCopyWith<_$IncomingCallStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
