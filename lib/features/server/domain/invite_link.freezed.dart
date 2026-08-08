// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$InviteLinkParseResult {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String serverBaseUrl, String magicToken) valid,
    required TResult Function() invalid,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String serverBaseUrl, String magicToken)? valid,
    TResult? Function()? invalid,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String serverBaseUrl, String magicToken)? valid,
    TResult Function()? invalid,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InviteLinkParseValid value) valid,
    required TResult Function(InviteLinkParseInvalid value) invalid,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InviteLinkParseValid value)? valid,
    TResult? Function(InviteLinkParseInvalid value)? invalid,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InviteLinkParseValid value)? valid,
    TResult Function(InviteLinkParseInvalid value)? invalid,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteLinkParseResultCopyWith<$Res> {
  factory $InviteLinkParseResultCopyWith(InviteLinkParseResult value,
          $Res Function(InviteLinkParseResult) then) =
      _$InviteLinkParseResultCopyWithImpl<$Res, InviteLinkParseResult>;
}

/// @nodoc
class _$InviteLinkParseResultCopyWithImpl<$Res,
        $Val extends InviteLinkParseResult>
    implements $InviteLinkParseResultCopyWith<$Res> {
  _$InviteLinkParseResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InviteLinkParseResult
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$InviteLinkParseValidImplCopyWith<$Res> {
  factory _$$InviteLinkParseValidImplCopyWith(_$InviteLinkParseValidImpl value,
          $Res Function(_$InviteLinkParseValidImpl) then) =
      __$$InviteLinkParseValidImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String serverBaseUrl, String magicToken});
}

/// @nodoc
class __$$InviteLinkParseValidImplCopyWithImpl<$Res>
    extends _$InviteLinkParseResultCopyWithImpl<$Res,
        _$InviteLinkParseValidImpl>
    implements _$$InviteLinkParseValidImplCopyWith<$Res> {
  __$$InviteLinkParseValidImplCopyWithImpl(_$InviteLinkParseValidImpl _value,
      $Res Function(_$InviteLinkParseValidImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteLinkParseResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serverBaseUrl = null,
    Object? magicToken = null,
  }) {
    return _then(_$InviteLinkParseValidImpl(
      serverBaseUrl: null == serverBaseUrl
          ? _value.serverBaseUrl
          : serverBaseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      magicToken: null == magicToken
          ? _value.magicToken
          : magicToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$InviteLinkParseValidImpl implements InviteLinkParseValid {
  const _$InviteLinkParseValidImpl(
      {required this.serverBaseUrl, required this.magicToken});

  @override
  final String serverBaseUrl;
  @override
  final String magicToken;

  @override
  String toString() {
    return 'InviteLinkParseResult.valid(serverBaseUrl: $serverBaseUrl, magicToken: $magicToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteLinkParseValidImpl &&
            (identical(other.serverBaseUrl, serverBaseUrl) ||
                other.serverBaseUrl == serverBaseUrl) &&
            (identical(other.magicToken, magicToken) ||
                other.magicToken == magicToken));
  }

  @override
  int get hashCode => Object.hash(runtimeType, serverBaseUrl, magicToken);

  /// Create a copy of InviteLinkParseResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteLinkParseValidImplCopyWith<_$InviteLinkParseValidImpl>
      get copyWith =>
          __$$InviteLinkParseValidImplCopyWithImpl<_$InviteLinkParseValidImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String serverBaseUrl, String magicToken) valid,
    required TResult Function() invalid,
  }) {
    return valid(serverBaseUrl, magicToken);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String serverBaseUrl, String magicToken)? valid,
    TResult? Function()? invalid,
  }) {
    return valid?.call(serverBaseUrl, magicToken);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String serverBaseUrl, String magicToken)? valid,
    TResult Function()? invalid,
    required TResult orElse(),
  }) {
    if (valid != null) {
      return valid(serverBaseUrl, magicToken);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InviteLinkParseValid value) valid,
    required TResult Function(InviteLinkParseInvalid value) invalid,
  }) {
    return valid(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InviteLinkParseValid value)? valid,
    TResult? Function(InviteLinkParseInvalid value)? invalid,
  }) {
    return valid?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InviteLinkParseValid value)? valid,
    TResult Function(InviteLinkParseInvalid value)? invalid,
    required TResult orElse(),
  }) {
    if (valid != null) {
      return valid(this);
    }
    return orElse();
  }
}

abstract class InviteLinkParseValid implements InviteLinkParseResult {
  const factory InviteLinkParseValid(
      {required final String serverBaseUrl,
      required final String magicToken}) = _$InviteLinkParseValidImpl;

  String get serverBaseUrl;
  String get magicToken;

  /// Create a copy of InviteLinkParseResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteLinkParseValidImplCopyWith<_$InviteLinkParseValidImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InviteLinkParseInvalidImplCopyWith<$Res> {
  factory _$$InviteLinkParseInvalidImplCopyWith(
          _$InviteLinkParseInvalidImpl value,
          $Res Function(_$InviteLinkParseInvalidImpl) then) =
      __$$InviteLinkParseInvalidImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$InviteLinkParseInvalidImplCopyWithImpl<$Res>
    extends _$InviteLinkParseResultCopyWithImpl<$Res,
        _$InviteLinkParseInvalidImpl>
    implements _$$InviteLinkParseInvalidImplCopyWith<$Res> {
  __$$InviteLinkParseInvalidImplCopyWithImpl(
      _$InviteLinkParseInvalidImpl _value,
      $Res Function(_$InviteLinkParseInvalidImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteLinkParseResult
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$InviteLinkParseInvalidImpl implements InviteLinkParseInvalid {
  const _$InviteLinkParseInvalidImpl();

  @override
  String toString() {
    return 'InviteLinkParseResult.invalid()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteLinkParseInvalidImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String serverBaseUrl, String magicToken) valid,
    required TResult Function() invalid,
  }) {
    return invalid();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String serverBaseUrl, String magicToken)? valid,
    TResult? Function()? invalid,
  }) {
    return invalid?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String serverBaseUrl, String magicToken)? valid,
    TResult Function()? invalid,
    required TResult orElse(),
  }) {
    if (invalid != null) {
      return invalid();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(InviteLinkParseValid value) valid,
    required TResult Function(InviteLinkParseInvalid value) invalid,
  }) {
    return invalid(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(InviteLinkParseValid value)? valid,
    TResult? Function(InviteLinkParseInvalid value)? invalid,
  }) {
    return invalid?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(InviteLinkParseValid value)? valid,
    TResult Function(InviteLinkParseInvalid value)? invalid,
    required TResult orElse(),
  }) {
    if (invalid != null) {
      return invalid(this);
    }
    return orElse();
  }
}

abstract class InviteLinkParseInvalid implements InviteLinkParseResult {
  const factory InviteLinkParseInvalid() = _$InviteLinkParseInvalidImpl;
}
