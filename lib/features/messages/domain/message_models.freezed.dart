// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MessageTarget {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int uid) user,
    required TResult Function(int gid) group,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int uid)? user,
    TResult? Function(int gid)? group,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int uid)? user,
    TResult Function(int gid)? group,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageTargetUser value) user,
    required TResult Function(MessageTargetGroup value) group,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageTargetUser value)? user,
    TResult? Function(MessageTargetGroup value)? group,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageTargetUser value)? user,
    TResult Function(MessageTargetGroup value)? group,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageTargetCopyWith<$Res> {
  factory $MessageTargetCopyWith(
          MessageTarget value, $Res Function(MessageTarget) then) =
      _$MessageTargetCopyWithImpl<$Res, MessageTarget>;
}

/// @nodoc
class _$MessageTargetCopyWithImpl<$Res, $Val extends MessageTarget>
    implements $MessageTargetCopyWith<$Res> {
  _$MessageTargetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessageTarget
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$MessageTargetUserImplCopyWith<$Res> {
  factory _$$MessageTargetUserImplCopyWith(_$MessageTargetUserImpl value,
          $Res Function(_$MessageTargetUserImpl) then) =
      __$$MessageTargetUserImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int uid});
}

/// @nodoc
class __$$MessageTargetUserImplCopyWithImpl<$Res>
    extends _$MessageTargetCopyWithImpl<$Res, _$MessageTargetUserImpl>
    implements _$$MessageTargetUserImplCopyWith<$Res> {
  __$$MessageTargetUserImplCopyWithImpl(_$MessageTargetUserImpl _value,
      $Res Function(_$MessageTargetUserImpl) _then)
      : super(_value, _then);

  /// Create a copy of MessageTarget
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
  }) {
    return _then(_$MessageTargetUserImpl(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$MessageTargetUserImpl implements MessageTargetUser {
  const _$MessageTargetUserImpl({required this.uid});

  @override
  final int uid;

  @override
  String toString() {
    return 'MessageTarget.user(uid: $uid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageTargetUserImpl &&
            (identical(other.uid, uid) || other.uid == uid));
  }

  @override
  int get hashCode => Object.hash(runtimeType, uid);

  /// Create a copy of MessageTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageTargetUserImplCopyWith<_$MessageTargetUserImpl> get copyWith =>
      __$$MessageTargetUserImplCopyWithImpl<_$MessageTargetUserImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int uid) user,
    required TResult Function(int gid) group,
  }) {
    return user(uid);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int uid)? user,
    TResult? Function(int gid)? group,
  }) {
    return user?.call(uid);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int uid)? user,
    TResult Function(int gid)? group,
    required TResult orElse(),
  }) {
    if (user != null) {
      return user(uid);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageTargetUser value) user,
    required TResult Function(MessageTargetGroup value) group,
  }) {
    return user(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageTargetUser value)? user,
    TResult? Function(MessageTargetGroup value)? group,
  }) {
    return user?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageTargetUser value)? user,
    TResult Function(MessageTargetGroup value)? group,
    required TResult orElse(),
  }) {
    if (user != null) {
      return user(this);
    }
    return orElse();
  }
}

abstract class MessageTargetUser implements MessageTarget {
  const factory MessageTargetUser({required final int uid}) =
      _$MessageTargetUserImpl;

  int get uid;

  /// Create a copy of MessageTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageTargetUserImplCopyWith<_$MessageTargetUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageTargetGroupImplCopyWith<$Res> {
  factory _$$MessageTargetGroupImplCopyWith(_$MessageTargetGroupImpl value,
          $Res Function(_$MessageTargetGroupImpl) then) =
      __$$MessageTargetGroupImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int gid});
}

/// @nodoc
class __$$MessageTargetGroupImplCopyWithImpl<$Res>
    extends _$MessageTargetCopyWithImpl<$Res, _$MessageTargetGroupImpl>
    implements _$$MessageTargetGroupImplCopyWith<$Res> {
  __$$MessageTargetGroupImplCopyWithImpl(_$MessageTargetGroupImpl _value,
      $Res Function(_$MessageTargetGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of MessageTarget
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gid = null,
  }) {
    return _then(_$MessageTargetGroupImpl(
      gid: null == gid
          ? _value.gid
          : gid // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$MessageTargetGroupImpl implements MessageTargetGroup {
  const _$MessageTargetGroupImpl({required this.gid});

  @override
  final int gid;

  @override
  String toString() {
    return 'MessageTarget.group(gid: $gid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageTargetGroupImpl &&
            (identical(other.gid, gid) || other.gid == gid));
  }

  @override
  int get hashCode => Object.hash(runtimeType, gid);

  /// Create a copy of MessageTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageTargetGroupImplCopyWith<_$MessageTargetGroupImpl> get copyWith =>
      __$$MessageTargetGroupImplCopyWithImpl<_$MessageTargetGroupImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int uid) user,
    required TResult Function(int gid) group,
  }) {
    return group(gid);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int uid)? user,
    TResult? Function(int gid)? group,
  }) {
    return group?.call(gid);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int uid)? user,
    TResult Function(int gid)? group,
    required TResult orElse(),
  }) {
    if (group != null) {
      return group(gid);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageTargetUser value) user,
    required TResult Function(MessageTargetGroup value) group,
  }) {
    return group(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageTargetUser value)? user,
    TResult? Function(MessageTargetGroup value)? group,
  }) {
    return group?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageTargetUser value)? user,
    TResult Function(MessageTargetGroup value)? group,
    required TResult orElse(),
  }) {
    if (group != null) {
      return group(this);
    }
    return orElse();
  }
}

abstract class MessageTargetGroup implements MessageTarget {
  const factory MessageTargetGroup({required final int gid}) =
      _$MessageTargetGroupImpl;

  int get gid;

  /// Create a copy of MessageTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageTargetGroupImplCopyWith<_$MessageTargetGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MessageDetail {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)
        normal,
    required TResult Function(int mid, Map<String, dynamic> detail) reaction,
    required TResult Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)
        reply,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        normal,
    TResult? Function(int mid, Map<String, dynamic> detail)? reaction,
    TResult? Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        reply,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        normal,
    TResult Function(int mid, Map<String, dynamic> detail)? reaction,
    TResult Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        reply,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NormalMessageDetail value) normal,
    required TResult Function(ReactionMessageDetail value) reaction,
    required TResult Function(ReplyMessageDetail value) reply,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NormalMessageDetail value)? normal,
    TResult? Function(ReactionMessageDetail value)? reaction,
    TResult? Function(ReplyMessageDetail value)? reply,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NormalMessageDetail value)? normal,
    TResult Function(ReactionMessageDetail value)? reaction,
    TResult Function(ReplyMessageDetail value)? reply,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageDetailCopyWith<$Res> {
  factory $MessageDetailCopyWith(
          MessageDetail value, $Res Function(MessageDetail) then) =
      _$MessageDetailCopyWithImpl<$Res, MessageDetail>;
}

/// @nodoc
class _$MessageDetailCopyWithImpl<$Res, $Val extends MessageDetail>
    implements $MessageDetailCopyWith<$Res> {
  _$MessageDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$NormalMessageDetailImplCopyWith<$Res> {
  factory _$$NormalMessageDetailImplCopyWith(_$NormalMessageDetailImpl value,
          $Res Function(_$NormalMessageDetailImpl) then) =
      __$$NormalMessageDetailImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {@JsonKey(name: 'content_type') String contentType,
      String content,
      Map<String, dynamic>? properties,
      @JsonKey(name: 'expires_in') int? expiresIn});
}

/// @nodoc
class __$$NormalMessageDetailImplCopyWithImpl<$Res>
    extends _$MessageDetailCopyWithImpl<$Res, _$NormalMessageDetailImpl>
    implements _$$NormalMessageDetailImplCopyWith<$Res> {
  __$$NormalMessageDetailImplCopyWithImpl(_$NormalMessageDetailImpl _value,
      $Res Function(_$NormalMessageDetailImpl) _then)
      : super(_value, _then);

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentType = null,
    Object? content = null,
    Object? properties = freezed,
    Object? expiresIn = freezed,
  }) {
    return _then(_$NormalMessageDetailImpl(
      contentType: null == contentType
          ? _value.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      properties: freezed == properties
          ? _value._properties
          : properties // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      expiresIn: freezed == expiresIn
          ? _value.expiresIn
          : expiresIn // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$NormalMessageDetailImpl implements NormalMessageDetail {
  const _$NormalMessageDetailImpl(
      {@JsonKey(name: 'content_type') required this.contentType,
      required this.content,
      final Map<String, dynamic>? properties,
      @JsonKey(name: 'expires_in') this.expiresIn})
      : _properties = properties;

  @override
  @JsonKey(name: 'content_type')
  final String contentType;
  @override
  final String content;
  final Map<String, dynamic>? _properties;
  @override
  Map<String, dynamic>? get properties {
    final value = _properties;
    if (value == null) return null;
    if (_properties is EqualUnmodifiableMapView) return _properties;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'expires_in')
  final int? expiresIn;

  @override
  String toString() {
    return 'MessageDetail.normal(contentType: $contentType, content: $content, properties: $properties, expiresIn: $expiresIn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NormalMessageDetailImpl &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality()
                .equals(other._properties, _properties) &&
            (identical(other.expiresIn, expiresIn) ||
                other.expiresIn == expiresIn));
  }

  @override
  int get hashCode => Object.hash(runtimeType, contentType, content,
      const DeepCollectionEquality().hash(_properties), expiresIn);

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NormalMessageDetailImplCopyWith<_$NormalMessageDetailImpl> get copyWith =>
      __$$NormalMessageDetailImplCopyWithImpl<_$NormalMessageDetailImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)
        normal,
    required TResult Function(int mid, Map<String, dynamic> detail) reaction,
    required TResult Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)
        reply,
  }) {
    return normal(contentType, content, properties, expiresIn);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        normal,
    TResult? Function(int mid, Map<String, dynamic> detail)? reaction,
    TResult? Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        reply,
  }) {
    return normal?.call(contentType, content, properties, expiresIn);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        normal,
    TResult Function(int mid, Map<String, dynamic> detail)? reaction,
    TResult Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        reply,
    required TResult orElse(),
  }) {
    if (normal != null) {
      return normal(contentType, content, properties, expiresIn);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NormalMessageDetail value) normal,
    required TResult Function(ReactionMessageDetail value) reaction,
    required TResult Function(ReplyMessageDetail value) reply,
  }) {
    return normal(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NormalMessageDetail value)? normal,
    TResult? Function(ReactionMessageDetail value)? reaction,
    TResult? Function(ReplyMessageDetail value)? reply,
  }) {
    return normal?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NormalMessageDetail value)? normal,
    TResult Function(ReactionMessageDetail value)? reaction,
    TResult Function(ReplyMessageDetail value)? reply,
    required TResult orElse(),
  }) {
    if (normal != null) {
      return normal(this);
    }
    return orElse();
  }
}

abstract class NormalMessageDetail implements MessageDetail {
  const factory NormalMessageDetail(
          {@JsonKey(name: 'content_type') required final String contentType,
          required final String content,
          final Map<String, dynamic>? properties,
          @JsonKey(name: 'expires_in') final int? expiresIn}) =
      _$NormalMessageDetailImpl;

  @JsonKey(name: 'content_type')
  String get contentType;
  String get content;
  Map<String, dynamic>? get properties;
  @JsonKey(name: 'expires_in')
  int? get expiresIn;

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NormalMessageDetailImplCopyWith<_$NormalMessageDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ReactionMessageDetailImplCopyWith<$Res> {
  factory _$$ReactionMessageDetailImplCopyWith(
          _$ReactionMessageDetailImpl value,
          $Res Function(_$ReactionMessageDetailImpl) then) =
      __$$ReactionMessageDetailImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int mid, Map<String, dynamic> detail});
}

/// @nodoc
class __$$ReactionMessageDetailImplCopyWithImpl<$Res>
    extends _$MessageDetailCopyWithImpl<$Res, _$ReactionMessageDetailImpl>
    implements _$$ReactionMessageDetailImplCopyWith<$Res> {
  __$$ReactionMessageDetailImplCopyWithImpl(_$ReactionMessageDetailImpl _value,
      $Res Function(_$ReactionMessageDetailImpl) _then)
      : super(_value, _then);

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mid = null,
    Object? detail = null,
  }) {
    return _then(_$ReactionMessageDetailImpl(
      mid: null == mid
          ? _value.mid
          : mid // ignore: cast_nullable_to_non_nullable
              as int,
      detail: null == detail
          ? _value._detail
          : detail // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc

class _$ReactionMessageDetailImpl implements ReactionMessageDetail {
  const _$ReactionMessageDetailImpl(
      {required this.mid, required final Map<String, dynamic> detail})
      : _detail = detail;

  @override
  final int mid;
  final Map<String, dynamic> _detail;
  @override
  Map<String, dynamic> get detail {
    if (_detail is EqualUnmodifiableMapView) return _detail;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_detail);
  }

  @override
  String toString() {
    return 'MessageDetail.reaction(mid: $mid, detail: $detail)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReactionMessageDetailImpl &&
            (identical(other.mid, mid) || other.mid == mid) &&
            const DeepCollectionEquality().equals(other._detail, _detail));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, mid, const DeepCollectionEquality().hash(_detail));

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReactionMessageDetailImplCopyWith<_$ReactionMessageDetailImpl>
      get copyWith => __$$ReactionMessageDetailImplCopyWithImpl<
          _$ReactionMessageDetailImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)
        normal,
    required TResult Function(int mid, Map<String, dynamic> detail) reaction,
    required TResult Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)
        reply,
  }) {
    return reaction(mid, detail);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        normal,
    TResult? Function(int mid, Map<String, dynamic> detail)? reaction,
    TResult? Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        reply,
  }) {
    return reaction?.call(mid, detail);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        normal,
    TResult Function(int mid, Map<String, dynamic> detail)? reaction,
    TResult Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        reply,
    required TResult orElse(),
  }) {
    if (reaction != null) {
      return reaction(mid, detail);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NormalMessageDetail value) normal,
    required TResult Function(ReactionMessageDetail value) reaction,
    required TResult Function(ReplyMessageDetail value) reply,
  }) {
    return reaction(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NormalMessageDetail value)? normal,
    TResult? Function(ReactionMessageDetail value)? reaction,
    TResult? Function(ReplyMessageDetail value)? reply,
  }) {
    return reaction?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NormalMessageDetail value)? normal,
    TResult Function(ReactionMessageDetail value)? reaction,
    TResult Function(ReplyMessageDetail value)? reply,
    required TResult orElse(),
  }) {
    if (reaction != null) {
      return reaction(this);
    }
    return orElse();
  }
}

abstract class ReactionMessageDetail implements MessageDetail {
  const factory ReactionMessageDetail(
          {required final int mid,
          required final Map<String, dynamic> detail}) =
      _$ReactionMessageDetailImpl;

  int get mid;
  Map<String, dynamic> get detail;

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReactionMessageDetailImplCopyWith<_$ReactionMessageDetailImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ReplyMessageDetailImplCopyWith<$Res> {
  factory _$$ReplyMessageDetailImplCopyWith(_$ReplyMessageDetailImpl value,
          $Res Function(_$ReplyMessageDetailImpl) then) =
      __$$ReplyMessageDetailImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {int mid,
      @JsonKey(name: 'content_type') String contentType,
      String content,
      Map<String, dynamic>? properties,
      @JsonKey(name: 'expires_in') int? expiresIn});
}

/// @nodoc
class __$$ReplyMessageDetailImplCopyWithImpl<$Res>
    extends _$MessageDetailCopyWithImpl<$Res, _$ReplyMessageDetailImpl>
    implements _$$ReplyMessageDetailImplCopyWith<$Res> {
  __$$ReplyMessageDetailImplCopyWithImpl(_$ReplyMessageDetailImpl _value,
      $Res Function(_$ReplyMessageDetailImpl) _then)
      : super(_value, _then);

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mid = null,
    Object? contentType = null,
    Object? content = null,
    Object? properties = freezed,
    Object? expiresIn = freezed,
  }) {
    return _then(_$ReplyMessageDetailImpl(
      mid: null == mid
          ? _value.mid
          : mid // ignore: cast_nullable_to_non_nullable
              as int,
      contentType: null == contentType
          ? _value.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      properties: freezed == properties
          ? _value._properties
          : properties // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      expiresIn: freezed == expiresIn
          ? _value.expiresIn
          : expiresIn // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$ReplyMessageDetailImpl implements ReplyMessageDetail {
  const _$ReplyMessageDetailImpl(
      {required this.mid,
      @JsonKey(name: 'content_type') required this.contentType,
      required this.content,
      final Map<String, dynamic>? properties,
      @JsonKey(name: 'expires_in') this.expiresIn})
      : _properties = properties;

  @override
  final int mid;
  @override
  @JsonKey(name: 'content_type')
  final String contentType;
  @override
  final String content;
  final Map<String, dynamic>? _properties;
  @override
  Map<String, dynamic>? get properties {
    final value = _properties;
    if (value == null) return null;
    if (_properties is EqualUnmodifiableMapView) return _properties;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'expires_in')
  final int? expiresIn;

  @override
  String toString() {
    return 'MessageDetail.reply(mid: $mid, contentType: $contentType, content: $content, properties: $properties, expiresIn: $expiresIn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReplyMessageDetailImpl &&
            (identical(other.mid, mid) || other.mid == mid) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality()
                .equals(other._properties, _properties) &&
            (identical(other.expiresIn, expiresIn) ||
                other.expiresIn == expiresIn));
  }

  @override
  int get hashCode => Object.hash(runtimeType, mid, contentType, content,
      const DeepCollectionEquality().hash(_properties), expiresIn);

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReplyMessageDetailImplCopyWith<_$ReplyMessageDetailImpl> get copyWith =>
      __$$ReplyMessageDetailImplCopyWithImpl<_$ReplyMessageDetailImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)
        normal,
    required TResult Function(int mid, Map<String, dynamic> detail) reaction,
    required TResult Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)
        reply,
  }) {
    return reply(mid, contentType, content, properties, expiresIn);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        normal,
    TResult? Function(int mid, Map<String, dynamic> detail)? reaction,
    TResult? Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        reply,
  }) {
    return reply?.call(mid, contentType, content, properties, expiresIn);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        normal,
    TResult Function(int mid, Map<String, dynamic> detail)? reaction,
    TResult Function(
            int mid,
            @JsonKey(name: 'content_type') String contentType,
            String content,
            Map<String, dynamic>? properties,
            @JsonKey(name: 'expires_in') int? expiresIn)?
        reply,
    required TResult orElse(),
  }) {
    if (reply != null) {
      return reply(mid, contentType, content, properties, expiresIn);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NormalMessageDetail value) normal,
    required TResult Function(ReactionMessageDetail value) reaction,
    required TResult Function(ReplyMessageDetail value) reply,
  }) {
    return reply(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NormalMessageDetail value)? normal,
    TResult? Function(ReactionMessageDetail value)? reaction,
    TResult? Function(ReplyMessageDetail value)? reply,
  }) {
    return reply?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NormalMessageDetail value)? normal,
    TResult Function(ReactionMessageDetail value)? reaction,
    TResult Function(ReplyMessageDetail value)? reply,
    required TResult orElse(),
  }) {
    if (reply != null) {
      return reply(this);
    }
    return orElse();
  }
}

abstract class ReplyMessageDetail implements MessageDetail {
  const factory ReplyMessageDetail(
          {required final int mid,
          @JsonKey(name: 'content_type') required final String contentType,
          required final String content,
          final Map<String, dynamic>? properties,
          @JsonKey(name: 'expires_in') final int? expiresIn}) =
      _$ReplyMessageDetailImpl;

  int get mid;
  @JsonKey(name: 'content_type')
  String get contentType;
  String get content;
  Map<String, dynamic>? get properties;
  @JsonKey(name: 'expires_in')
  int? get expiresIn;

  /// Create a copy of MessageDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReplyMessageDetailImplCopyWith<_$ReplyMessageDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) {
  return _ChatMessage.fromJson(json);
}

/// @nodoc
mixin _$ChatMessage {
  int get mid => throw _privateConstructorUsedError;
  @JsonKey(name: 'from_uid')
  int get fromUid =>
      throw _privateConstructorUsedError; // Server serializes DateTime as i64 unix milliseconds, not ISO string.
  @JsonKey(name: 'created_at')
  int get createdAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _messageTargetFromJson, toJson: _messageTargetToJson)
  MessageTarget get target => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _messageDetailFromJson, toJson: _messageDetailToJson)
  MessageDetail get detail => throw _privateConstructorUsedError;

  /// Serializes this ChatMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
          ChatMessage value, $Res Function(ChatMessage) then) =
      _$ChatMessageCopyWithImpl<$Res, ChatMessage>;
  @useResult
  $Res call(
      {int mid,
      @JsonKey(name: 'from_uid') int fromUid,
      @JsonKey(name: 'created_at') int createdAt,
      @JsonKey(fromJson: _messageTargetFromJson, toJson: _messageTargetToJson)
      MessageTarget target,
      @JsonKey(fromJson: _messageDetailFromJson, toJson: _messageDetailToJson)
      MessageDetail detail});

  $MessageTargetCopyWith<$Res> get target;
  $MessageDetailCopyWith<$Res> get detail;
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res, $Val extends ChatMessage>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mid = null,
    Object? fromUid = null,
    Object? createdAt = null,
    Object? target = null,
    Object? detail = null,
  }) {
    return _then(_value.copyWith(
      mid: null == mid
          ? _value.mid
          : mid // ignore: cast_nullable_to_non_nullable
              as int,
      fromUid: null == fromUid
          ? _value.fromUid
          : fromUid // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
      target: null == target
          ? _value.target
          : target // ignore: cast_nullable_to_non_nullable
              as MessageTarget,
      detail: null == detail
          ? _value.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as MessageDetail,
    ) as $Val);
  }

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageTargetCopyWith<$Res> get target {
    return $MessageTargetCopyWith<$Res>(_value.target, (value) {
      return _then(_value.copyWith(target: value) as $Val);
    });
  }

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageDetailCopyWith<$Res> get detail {
    return $MessageDetailCopyWith<$Res>(_value.detail, (value) {
      return _then(_value.copyWith(detail: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChatMessageImplCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$$ChatMessageImplCopyWith(
          _$ChatMessageImpl value, $Res Function(_$ChatMessageImpl) then) =
      __$$ChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int mid,
      @JsonKey(name: 'from_uid') int fromUid,
      @JsonKey(name: 'created_at') int createdAt,
      @JsonKey(fromJson: _messageTargetFromJson, toJson: _messageTargetToJson)
      MessageTarget target,
      @JsonKey(fromJson: _messageDetailFromJson, toJson: _messageDetailToJson)
      MessageDetail detail});

  @override
  $MessageTargetCopyWith<$Res> get target;
  @override
  $MessageDetailCopyWith<$Res> get detail;
}

/// @nodoc
class __$$ChatMessageImplCopyWithImpl<$Res>
    extends _$ChatMessageCopyWithImpl<$Res, _$ChatMessageImpl>
    implements _$$ChatMessageImplCopyWith<$Res> {
  __$$ChatMessageImplCopyWithImpl(
      _$ChatMessageImpl _value, $Res Function(_$ChatMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mid = null,
    Object? fromUid = null,
    Object? createdAt = null,
    Object? target = null,
    Object? detail = null,
  }) {
    return _then(_$ChatMessageImpl(
      mid: null == mid
          ? _value.mid
          : mid // ignore: cast_nullable_to_non_nullable
              as int,
      fromUid: null == fromUid
          ? _value.fromUid
          : fromUid // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
      target: null == target
          ? _value.target
          : target // ignore: cast_nullable_to_non_nullable
              as MessageTarget,
      detail: null == detail
          ? _value.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as MessageDetail,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMessageImpl implements _ChatMessage {
  const _$ChatMessageImpl(
      {required this.mid,
      @JsonKey(name: 'from_uid') required this.fromUid,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(fromJson: _messageTargetFromJson, toJson: _messageTargetToJson)
      required this.target,
      @JsonKey(fromJson: _messageDetailFromJson, toJson: _messageDetailToJson)
      required this.detail});

  factory _$ChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMessageImplFromJson(json);

  @override
  final int mid;
  @override
  @JsonKey(name: 'from_uid')
  final int fromUid;
// Server serializes DateTime as i64 unix milliseconds, not ISO string.
  @override
  @JsonKey(name: 'created_at')
  final int createdAt;
  @override
  @JsonKey(fromJson: _messageTargetFromJson, toJson: _messageTargetToJson)
  final MessageTarget target;
  @override
  @JsonKey(fromJson: _messageDetailFromJson, toJson: _messageDetailToJson)
  final MessageDetail detail;

  @override
  String toString() {
    return 'ChatMessage(mid: $mid, fromUid: $fromUid, createdAt: $createdAt, target: $target, detail: $detail)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageImpl &&
            (identical(other.mid, mid) || other.mid == mid) &&
            (identical(other.fromUid, fromUid) || other.fromUid == fromUid) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.target, target) || other.target == target) &&
            (identical(other.detail, detail) || other.detail == detail));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, mid, fromUid, createdAt, target, detail);

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      __$$ChatMessageImplCopyWithImpl<_$ChatMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMessageImplToJson(
      this,
    );
  }
}

abstract class _ChatMessage implements ChatMessage {
  const factory _ChatMessage(
      {required final int mid,
      @JsonKey(name: 'from_uid') required final int fromUid,
      @JsonKey(name: 'created_at') required final int createdAt,
      @JsonKey(fromJson: _messageTargetFromJson, toJson: _messageTargetToJson)
      required final MessageTarget target,
      @JsonKey(fromJson: _messageDetailFromJson, toJson: _messageDetailToJson)
      required final MessageDetail detail}) = _$ChatMessageImpl;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) =
      _$ChatMessageImpl.fromJson;

  @override
  int get mid;
  @override
  @JsonKey(name: 'from_uid')
  int get fromUid; // Server serializes DateTime as i64 unix milliseconds, not ISO string.
  @override
  @JsonKey(name: 'created_at')
  int get createdAt;
  @override
  @JsonKey(fromJson: _messageTargetFromJson, toJson: _messageTargetToJson)
  MessageTarget get target;
  @override
  @JsonKey(fromJson: _messageDetailFromJson, toJson: _messageDetailToJson)
  MessageDetail get detail;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ChatEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatEventCopyWith<$Res> {
  factory $ChatEventCopyWith(ChatEvent value, $Res Function(ChatEvent) then) =
      _$ChatEventCopyWithImpl<$Res, ChatEvent>;
}

/// @nodoc
class _$ChatEventCopyWithImpl<$Res, $Val extends ChatEvent>
    implements $ChatEventCopyWith<$Res> {
  _$ChatEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$ChatEventReadyImplCopyWith<$Res> {
  factory _$$ChatEventReadyImplCopyWith(_$ChatEventReadyImpl value,
          $Res Function(_$ChatEventReadyImpl) then) =
      __$$ChatEventReadyImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ChatEventReadyImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventReadyImpl>
    implements _$$ChatEventReadyImplCopyWith<$Res> {
  __$$ChatEventReadyImplCopyWithImpl(
      _$ChatEventReadyImpl _value, $Res Function(_$ChatEventReadyImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ChatEventReadyImpl implements ChatEventReady {
  const _$ChatEventReadyImpl();

  @override
  String toString() {
    return 'ChatEvent.ready()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ChatEventReadyImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return ready();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return ready?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (ready != null) {
      return ready();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return ready(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return ready?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (ready != null) {
      return ready(this);
    }
    return orElse();
  }
}

abstract class ChatEventReady implements ChatEvent {
  const factory ChatEventReady() = _$ChatEventReadyImpl;
}

/// @nodoc
abstract class _$$ChatEventHeartbeatImplCopyWith<$Res> {
  factory _$$ChatEventHeartbeatImplCopyWith(_$ChatEventHeartbeatImpl value,
          $Res Function(_$ChatEventHeartbeatImpl) then) =
      __$$ChatEventHeartbeatImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? time});
}

/// @nodoc
class __$$ChatEventHeartbeatImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventHeartbeatImpl>
    implements _$$ChatEventHeartbeatImplCopyWith<$Res> {
  __$$ChatEventHeartbeatImplCopyWithImpl(_$ChatEventHeartbeatImpl _value,
      $Res Function(_$ChatEventHeartbeatImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? time = freezed,
  }) {
    return _then(_$ChatEventHeartbeatImpl(
      time: freezed == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ChatEventHeartbeatImpl implements ChatEventHeartbeat {
  const _$ChatEventHeartbeatImpl({this.time});

  @override
  final String? time;

  @override
  String toString() {
    return 'ChatEvent.heartbeat(time: $time)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventHeartbeatImpl &&
            (identical(other.time, time) || other.time == time));
  }

  @override
  int get hashCode => Object.hash(runtimeType, time);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventHeartbeatImplCopyWith<_$ChatEventHeartbeatImpl> get copyWith =>
      __$$ChatEventHeartbeatImplCopyWithImpl<_$ChatEventHeartbeatImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return heartbeat(time);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return heartbeat?.call(time);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (heartbeat != null) {
      return heartbeat(time);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return heartbeat(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return heartbeat?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (heartbeat != null) {
      return heartbeat(this);
    }
    return orElse();
  }
}

abstract class ChatEventHeartbeat implements ChatEvent {
  const factory ChatEventHeartbeat({final String? time}) =
      _$ChatEventHeartbeatImpl;

  String? get time;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventHeartbeatImplCopyWith<_$ChatEventHeartbeatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChatEventChatImplCopyWith<$Res> {
  factory _$$ChatEventChatImplCopyWith(
          _$ChatEventChatImpl value, $Res Function(_$ChatEventChatImpl) then) =
      __$$ChatEventChatImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ChatMessage message});

  $ChatMessageCopyWith<$Res> get message;
}

/// @nodoc
class __$$ChatEventChatImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventChatImpl>
    implements _$$ChatEventChatImplCopyWith<$Res> {
  __$$ChatEventChatImplCopyWithImpl(
      _$ChatEventChatImpl _value, $Res Function(_$ChatEventChatImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$ChatEventChatImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as ChatMessage,
    ));
  }

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ChatMessageCopyWith<$Res> get message {
    return $ChatMessageCopyWith<$Res>(_value.message, (value) {
      return _then(_value.copyWith(message: value));
    });
  }
}

/// @nodoc

class _$ChatEventChatImpl implements ChatEventChat {
  const _$ChatEventChatImpl({required this.message});

  @override
  final ChatMessage message;

  @override
  String toString() {
    return 'ChatEvent.chat(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventChatImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventChatImplCopyWith<_$ChatEventChatImpl> get copyWith =>
      __$$ChatEventChatImplCopyWithImpl<_$ChatEventChatImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return chat(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return chat?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (chat != null) {
      return chat(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return chat(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return chat?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (chat != null) {
      return chat(this);
    }
    return orElse();
  }
}

abstract class ChatEventChat implements ChatEvent {
  const factory ChatEventChat({required final ChatMessage message}) =
      _$ChatEventChatImpl;

  ChatMessage get message;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventChatImplCopyWith<_$ChatEventChatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChatEventKickImplCopyWith<$Res> {
  factory _$$ChatEventKickImplCopyWith(
          _$ChatEventKickImpl value, $Res Function(_$ChatEventKickImpl) then) =
      __$$ChatEventKickImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? reason});
}

/// @nodoc
class __$$ChatEventKickImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventKickImpl>
    implements _$$ChatEventKickImplCopyWith<$Res> {
  __$$ChatEventKickImplCopyWithImpl(
      _$ChatEventKickImpl _value, $Res Function(_$ChatEventKickImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? reason = freezed,
  }) {
    return _then(_$ChatEventKickImpl(
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ChatEventKickImpl implements ChatEventKick {
  const _$ChatEventKickImpl({this.reason});

  @override
  final String? reason;

  @override
  String toString() {
    return 'ChatEvent.kick(reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventKickImpl &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reason);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventKickImplCopyWith<_$ChatEventKickImpl> get copyWith =>
      __$$ChatEventKickImplCopyWithImpl<_$ChatEventKickImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return kick(reason);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return kick?.call(reason);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (kick != null) {
      return kick(reason);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return kick(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return kick?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (kick != null) {
      return kick(this);
    }
    return orElse();
  }
}

abstract class ChatEventKick implements ChatEvent {
  const factory ChatEventKick({final String? reason}) = _$ChatEventKickImpl;

  String? get reason;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventKickImplCopyWith<_$ChatEventKickImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChatEventUsersSnapshotImplCopyWith<$Res> {
  factory _$$ChatEventUsersSnapshotImplCopyWith(
          _$ChatEventUsersSnapshotImpl value,
          $Res Function(_$ChatEventUsersSnapshotImpl) then) =
      __$$ChatEventUsersSnapshotImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<Map<String, dynamic>> users, int version});
}

/// @nodoc
class __$$ChatEventUsersSnapshotImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventUsersSnapshotImpl>
    implements _$$ChatEventUsersSnapshotImplCopyWith<$Res> {
  __$$ChatEventUsersSnapshotImplCopyWithImpl(
      _$ChatEventUsersSnapshotImpl _value,
      $Res Function(_$ChatEventUsersSnapshotImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? users = null,
    Object? version = null,
  }) {
    return _then(_$ChatEventUsersSnapshotImpl(
      users: null == users
          ? _value._users
          : users // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$ChatEventUsersSnapshotImpl implements ChatEventUsersSnapshot {
  const _$ChatEventUsersSnapshotImpl(
      {required final List<Map<String, dynamic>> users, required this.version})
      : _users = users;

  final List<Map<String, dynamic>> _users;
  @override
  List<Map<String, dynamic>> get users {
    if (_users is EqualUnmodifiableListView) return _users;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_users);
  }

  @override
  final int version;

  @override
  String toString() {
    return 'ChatEvent.usersSnapshot(users: $users, version: $version)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventUsersSnapshotImpl &&
            const DeepCollectionEquality().equals(other._users, _users) &&
            (identical(other.version, version) || other.version == version));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_users), version);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventUsersSnapshotImplCopyWith<_$ChatEventUsersSnapshotImpl>
      get copyWith => __$$ChatEventUsersSnapshotImplCopyWithImpl<
          _$ChatEventUsersSnapshotImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return usersSnapshot(users, version);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return usersSnapshot?.call(users, version);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (usersSnapshot != null) {
      return usersSnapshot(users, version);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return usersSnapshot(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return usersSnapshot?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (usersSnapshot != null) {
      return usersSnapshot(this);
    }
    return orElse();
  }
}

abstract class ChatEventUsersSnapshot implements ChatEvent {
  const factory ChatEventUsersSnapshot(
      {required final List<Map<String, dynamic>> users,
      required final int version}) = _$ChatEventUsersSnapshotImpl;

  List<Map<String, dynamic>> get users;
  int get version;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventUsersSnapshotImplCopyWith<_$ChatEventUsersSnapshotImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChatEventGroupChangedImplCopyWith<$Res> {
  factory _$$ChatEventGroupChangedImplCopyWith(
          _$ChatEventGroupChangedImpl value,
          $Res Function(_$ChatEventGroupChangedImpl) then) =
      __$$ChatEventGroupChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Map<String, dynamic> data});
}

/// @nodoc
class __$$ChatEventGroupChangedImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventGroupChangedImpl>
    implements _$$ChatEventGroupChangedImplCopyWith<$Res> {
  __$$ChatEventGroupChangedImplCopyWithImpl(_$ChatEventGroupChangedImpl _value,
      $Res Function(_$ChatEventGroupChangedImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
  }) {
    return _then(_$ChatEventGroupChangedImpl(
      data: null == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc

class _$ChatEventGroupChangedImpl implements ChatEventGroupChanged {
  const _$ChatEventGroupChangedImpl({required final Map<String, dynamic> data})
      : _data = data;

  final Map<String, dynamic> _data;
  @override
  Map<String, dynamic> get data {
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_data);
  }

  @override
  String toString() {
    return 'ChatEvent.groupChanged(data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventGroupChangedImpl &&
            const DeepCollectionEquality().equals(other._data, _data));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_data));

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventGroupChangedImplCopyWith<_$ChatEventGroupChangedImpl>
      get copyWith => __$$ChatEventGroupChangedImplCopyWithImpl<
          _$ChatEventGroupChangedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return groupChanged(data);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return groupChanged?.call(data);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (groupChanged != null) {
      return groupChanged(data);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return groupChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return groupChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (groupChanged != null) {
      return groupChanged(this);
    }
    return orElse();
  }
}

abstract class ChatEventGroupChanged implements ChatEvent {
  const factory ChatEventGroupChanged(
      {required final Map<String, dynamic> data}) = _$ChatEventGroupChangedImpl;

  Map<String, dynamic> get data;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventGroupChangedImplCopyWith<_$ChatEventGroupChangedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChatEventUserJoinedGroupImplCopyWith<$Res> {
  factory _$$ChatEventUserJoinedGroupImplCopyWith(
          _$ChatEventUserJoinedGroupImpl value,
          $Res Function(_$ChatEventUserJoinedGroupImpl) then) =
      __$$ChatEventUserJoinedGroupImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int gid, List<int> uid});
}

/// @nodoc
class __$$ChatEventUserJoinedGroupImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventUserJoinedGroupImpl>
    implements _$$ChatEventUserJoinedGroupImplCopyWith<$Res> {
  __$$ChatEventUserJoinedGroupImplCopyWithImpl(
      _$ChatEventUserJoinedGroupImpl _value,
      $Res Function(_$ChatEventUserJoinedGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gid = null,
    Object? uid = null,
  }) {
    return _then(_$ChatEventUserJoinedGroupImpl(
      gid: null == gid
          ? _value.gid
          : gid // ignore: cast_nullable_to_non_nullable
              as int,
      uid: null == uid
          ? _value._uid
          : uid // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ));
  }
}

/// @nodoc

class _$ChatEventUserJoinedGroupImpl implements ChatEventUserJoinedGroup {
  const _$ChatEventUserJoinedGroupImpl(
      {required this.gid, required final List<int> uid})
      : _uid = uid;

  @override
  final int gid;
  final List<int> _uid;
  @override
  List<int> get uid {
    if (_uid is EqualUnmodifiableListView) return _uid;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_uid);
  }

  @override
  String toString() {
    return 'ChatEvent.userJoinedGroup(gid: $gid, uid: $uid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventUserJoinedGroupImpl &&
            (identical(other.gid, gid) || other.gid == gid) &&
            const DeepCollectionEquality().equals(other._uid, _uid));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, gid, const DeepCollectionEquality().hash(_uid));

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventUserJoinedGroupImplCopyWith<_$ChatEventUserJoinedGroupImpl>
      get copyWith => __$$ChatEventUserJoinedGroupImplCopyWithImpl<
          _$ChatEventUserJoinedGroupImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return userJoinedGroup(gid, uid);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return userJoinedGroup?.call(gid, uid);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (userJoinedGroup != null) {
      return userJoinedGroup(gid, uid);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return userJoinedGroup(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return userJoinedGroup?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (userJoinedGroup != null) {
      return userJoinedGroup(this);
    }
    return orElse();
  }
}

abstract class ChatEventUserJoinedGroup implements ChatEvent {
  const factory ChatEventUserJoinedGroup(
      {required final int gid,
      required final List<int> uid}) = _$ChatEventUserJoinedGroupImpl;

  int get gid;
  List<int> get uid;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventUserJoinedGroupImplCopyWith<_$ChatEventUserJoinedGroupImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChatEventUserLeavedGroupImplCopyWith<$Res> {
  factory _$$ChatEventUserLeavedGroupImplCopyWith(
          _$ChatEventUserLeavedGroupImpl value,
          $Res Function(_$ChatEventUserLeavedGroupImpl) then) =
      __$$ChatEventUserLeavedGroupImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int gid, List<int> uid});
}

/// @nodoc
class __$$ChatEventUserLeavedGroupImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventUserLeavedGroupImpl>
    implements _$$ChatEventUserLeavedGroupImplCopyWith<$Res> {
  __$$ChatEventUserLeavedGroupImplCopyWithImpl(
      _$ChatEventUserLeavedGroupImpl _value,
      $Res Function(_$ChatEventUserLeavedGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gid = null,
    Object? uid = null,
  }) {
    return _then(_$ChatEventUserLeavedGroupImpl(
      gid: null == gid
          ? _value.gid
          : gid // ignore: cast_nullable_to_non_nullable
              as int,
      uid: null == uid
          ? _value._uid
          : uid // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ));
  }
}

/// @nodoc

class _$ChatEventUserLeavedGroupImpl implements ChatEventUserLeavedGroup {
  const _$ChatEventUserLeavedGroupImpl(
      {required this.gid, required final List<int> uid})
      : _uid = uid;

  @override
  final int gid;
  final List<int> _uid;
  @override
  List<int> get uid {
    if (_uid is EqualUnmodifiableListView) return _uid;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_uid);
  }

  @override
  String toString() {
    return 'ChatEvent.userLeavedGroup(gid: $gid, uid: $uid)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventUserLeavedGroupImpl &&
            (identical(other.gid, gid) || other.gid == gid) &&
            const DeepCollectionEquality().equals(other._uid, _uid));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, gid, const DeepCollectionEquality().hash(_uid));

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventUserLeavedGroupImplCopyWith<_$ChatEventUserLeavedGroupImpl>
      get copyWith => __$$ChatEventUserLeavedGroupImplCopyWithImpl<
          _$ChatEventUserLeavedGroupImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return userLeavedGroup(gid, uid);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return userLeavedGroup?.call(gid, uid);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (userLeavedGroup != null) {
      return userLeavedGroup(gid, uid);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return userLeavedGroup(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return userLeavedGroup?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (userLeavedGroup != null) {
      return userLeavedGroup(this);
    }
    return orElse();
  }
}

abstract class ChatEventUserLeavedGroup implements ChatEvent {
  const factory ChatEventUserLeavedGroup(
      {required final int gid,
      required final List<int> uid}) = _$ChatEventUserLeavedGroupImpl;

  int get gid;
  List<int> get uid;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventUserLeavedGroupImplCopyWith<_$ChatEventUserLeavedGroupImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChatEventServerConfigChangedImplCopyWith<$Res> {
  factory _$$ChatEventServerConfigChangedImplCopyWith(
          _$ChatEventServerConfigChangedImpl value,
          $Res Function(_$ChatEventServerConfigChangedImpl) then) =
      __$$ChatEventServerConfigChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Map<String, dynamic> data});
}

/// @nodoc
class __$$ChatEventServerConfigChangedImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventServerConfigChangedImpl>
    implements _$$ChatEventServerConfigChangedImplCopyWith<$Res> {
  __$$ChatEventServerConfigChangedImplCopyWithImpl(
      _$ChatEventServerConfigChangedImpl _value,
      $Res Function(_$ChatEventServerConfigChangedImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
  }) {
    return _then(_$ChatEventServerConfigChangedImpl(
      data: null == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc

class _$ChatEventServerConfigChangedImpl
    implements ChatEventServerConfigChanged {
  const _$ChatEventServerConfigChangedImpl(
      {required final Map<String, dynamic> data})
      : _data = data;

  final Map<String, dynamic> _data;
  @override
  Map<String, dynamic> get data {
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_data);
  }

  @override
  String toString() {
    return 'ChatEvent.serverConfigChanged(data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventServerConfigChangedImpl &&
            const DeepCollectionEquality().equals(other._data, _data));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_data));

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventServerConfigChangedImplCopyWith<
          _$ChatEventServerConfigChangedImpl>
      get copyWith => __$$ChatEventServerConfigChangedImplCopyWithImpl<
          _$ChatEventServerConfigChangedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return serverConfigChanged(data);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return serverConfigChanged?.call(data);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (serverConfigChanged != null) {
      return serverConfigChanged(data);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return serverConfigChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return serverConfigChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (serverConfigChanged != null) {
      return serverConfigChanged(this);
    }
    return orElse();
  }
}

abstract class ChatEventServerConfigChanged implements ChatEvent {
  const factory ChatEventServerConfigChanged(
          {required final Map<String, dynamic> data}) =
      _$ChatEventServerConfigChangedImpl;

  Map<String, dynamic> get data;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventServerConfigChangedImplCopyWith<
          _$ChatEventServerConfigChangedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ChatEventUnknownImplCopyWith<$Res> {
  factory _$$ChatEventUnknownImplCopyWith(_$ChatEventUnknownImpl value,
          $Res Function(_$ChatEventUnknownImpl) then) =
      __$$ChatEventUnknownImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String type, String raw});
}

/// @nodoc
class __$$ChatEventUnknownImplCopyWithImpl<$Res>
    extends _$ChatEventCopyWithImpl<$Res, _$ChatEventUnknownImpl>
    implements _$$ChatEventUnknownImplCopyWith<$Res> {
  __$$ChatEventUnknownImplCopyWithImpl(_$ChatEventUnknownImpl _value,
      $Res Function(_$ChatEventUnknownImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? raw = null,
  }) {
    return _then(_$ChatEventUnknownImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      raw: null == raw
          ? _value.raw
          : raw // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ChatEventUnknownImpl implements ChatEventUnknown {
  const _$ChatEventUnknownImpl({required this.type, required this.raw});

  @override
  final String type;
  @override
  final String raw;

  @override
  String toString() {
    return 'ChatEvent.unknown(type: $type, raw: $raw)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatEventUnknownImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.raw, raw) || other.raw == raw));
  }

  @override
  int get hashCode => Object.hash(runtimeType, type, raw);

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatEventUnknownImplCopyWith<_$ChatEventUnknownImpl> get copyWith =>
      __$$ChatEventUnknownImplCopyWithImpl<_$ChatEventUnknownImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ready,
    required TResult Function(String? time) heartbeat,
    required TResult Function(ChatMessage message) chat,
    required TResult Function(String? reason) kick,
    required TResult Function(List<Map<String, dynamic>> users, int version)
        usersSnapshot,
    required TResult Function(Map<String, dynamic> data) groupChanged,
    required TResult Function(int gid, List<int> uid) userJoinedGroup,
    required TResult Function(int gid, List<int> uid) userLeavedGroup,
    required TResult Function(Map<String, dynamic> data) serverConfigChanged,
    required TResult Function(String type, String raw) unknown,
  }) {
    return unknown(type, raw);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ready,
    TResult? Function(String? time)? heartbeat,
    TResult? Function(ChatMessage message)? chat,
    TResult? Function(String? reason)? kick,
    TResult? Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult? Function(Map<String, dynamic> data)? groupChanged,
    TResult? Function(int gid, List<int> uid)? userJoinedGroup,
    TResult? Function(int gid, List<int> uid)? userLeavedGroup,
    TResult? Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult? Function(String type, String raw)? unknown,
  }) {
    return unknown?.call(type, raw);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ready,
    TResult Function(String? time)? heartbeat,
    TResult Function(ChatMessage message)? chat,
    TResult Function(String? reason)? kick,
    TResult Function(List<Map<String, dynamic>> users, int version)?
        usersSnapshot,
    TResult Function(Map<String, dynamic> data)? groupChanged,
    TResult Function(int gid, List<int> uid)? userJoinedGroup,
    TResult Function(int gid, List<int> uid)? userLeavedGroup,
    TResult Function(Map<String, dynamic> data)? serverConfigChanged,
    TResult Function(String type, String raw)? unknown,
    required TResult orElse(),
  }) {
    if (unknown != null) {
      return unknown(type, raw);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ChatEventReady value) ready,
    required TResult Function(ChatEventHeartbeat value) heartbeat,
    required TResult Function(ChatEventChat value) chat,
    required TResult Function(ChatEventKick value) kick,
    required TResult Function(ChatEventUsersSnapshot value) usersSnapshot,
    required TResult Function(ChatEventGroupChanged value) groupChanged,
    required TResult Function(ChatEventUserJoinedGroup value) userJoinedGroup,
    required TResult Function(ChatEventUserLeavedGroup value) userLeavedGroup,
    required TResult Function(ChatEventServerConfigChanged value)
        serverConfigChanged,
    required TResult Function(ChatEventUnknown value) unknown,
  }) {
    return unknown(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ChatEventReady value)? ready,
    TResult? Function(ChatEventHeartbeat value)? heartbeat,
    TResult? Function(ChatEventChat value)? chat,
    TResult? Function(ChatEventKick value)? kick,
    TResult? Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult? Function(ChatEventGroupChanged value)? groupChanged,
    TResult? Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult? Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult? Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult? Function(ChatEventUnknown value)? unknown,
  }) {
    return unknown?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ChatEventReady value)? ready,
    TResult Function(ChatEventHeartbeat value)? heartbeat,
    TResult Function(ChatEventChat value)? chat,
    TResult Function(ChatEventKick value)? kick,
    TResult Function(ChatEventUsersSnapshot value)? usersSnapshot,
    TResult Function(ChatEventGroupChanged value)? groupChanged,
    TResult Function(ChatEventUserJoinedGroup value)? userJoinedGroup,
    TResult Function(ChatEventUserLeavedGroup value)? userLeavedGroup,
    TResult Function(ChatEventServerConfigChanged value)? serverConfigChanged,
    TResult Function(ChatEventUnknown value)? unknown,
    required TResult orElse(),
  }) {
    if (unknown != null) {
      return unknown(this);
    }
    return orElse();
  }
}

abstract class ChatEventUnknown implements ChatEvent {
  const factory ChatEventUnknown(
      {required final String type,
      required final String raw}) = _$ChatEventUnknownImpl;

  String get type;
  String get raw;

  /// Create a copy of ChatEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatEventUnknownImplCopyWith<_$ChatEventUnknownImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
