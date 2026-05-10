// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Credential _$CredentialFromJson(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'password':
      return PasswordCredential.fromJson(json);
    case 'magiclink':
      return MagicLinkCredential.fromJson(json);

    default:
      throw CheckedFromJsonException(
          json, 'type', 'Credential', 'Invalid union type "${json['type']}"!');
  }
}

/// @nodoc
mixin _$Credential {
  String get email => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String email, String password) password,
    required TResult Function(String email) magicLink,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String email, String password)? password,
    TResult? Function(String email)? magicLink,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String email, String password)? password,
    TResult Function(String email)? magicLink,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PasswordCredential value) password,
    required TResult Function(MagicLinkCredential value) magicLink,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PasswordCredential value)? password,
    TResult? Function(MagicLinkCredential value)? magicLink,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PasswordCredential value)? password,
    TResult Function(MagicLinkCredential value)? magicLink,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this Credential to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Credential
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CredentialCopyWith<Credential> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CredentialCopyWith<$Res> {
  factory $CredentialCopyWith(
          Credential value, $Res Function(Credential) then) =
      _$CredentialCopyWithImpl<$Res, Credential>;
  @useResult
  $Res call({String email});
}

/// @nodoc
class _$CredentialCopyWithImpl<$Res, $Val extends Credential>
    implements $CredentialCopyWith<$Res> {
  _$CredentialCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Credential
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? email = null,
  }) {
    return _then(_value.copyWith(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PasswordCredentialImplCopyWith<$Res>
    implements $CredentialCopyWith<$Res> {
  factory _$$PasswordCredentialImplCopyWith(_$PasswordCredentialImpl value,
          $Res Function(_$PasswordCredentialImpl) then) =
      __$$PasswordCredentialImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String email, String password});
}

/// @nodoc
class __$$PasswordCredentialImplCopyWithImpl<$Res>
    extends _$CredentialCopyWithImpl<$Res, _$PasswordCredentialImpl>
    implements _$$PasswordCredentialImplCopyWith<$Res> {
  __$$PasswordCredentialImplCopyWithImpl(_$PasswordCredentialImpl _value,
      $Res Function(_$PasswordCredentialImpl) _then)
      : super(_value, _then);

  /// Create a copy of Credential
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? email = null,
    Object? password = null,
  }) {
    return _then(_$PasswordCredentialImpl(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PasswordCredentialImpl implements PasswordCredential {
  const _$PasswordCredentialImpl(
      {required this.email, required this.password, final String? $type})
      : $type = $type ?? 'password';

  factory _$PasswordCredentialImpl.fromJson(Map<String, dynamic> json) =>
      _$$PasswordCredentialImplFromJson(json);

  @override
  final String email;
  @override
  final String password;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'Credential.password(email: $email, password: $password)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PasswordCredentialImpl &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.password, password) ||
                other.password == password));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, email, password);

  /// Create a copy of Credential
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PasswordCredentialImplCopyWith<_$PasswordCredentialImpl> get copyWith =>
      __$$PasswordCredentialImplCopyWithImpl<_$PasswordCredentialImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String email, String password) password,
    required TResult Function(String email) magicLink,
  }) {
    return password(email, this.password);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String email, String password)? password,
    TResult? Function(String email)? magicLink,
  }) {
    return password?.call(email, this.password);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String email, String password)? password,
    TResult Function(String email)? magicLink,
    required TResult orElse(),
  }) {
    if (password != null) {
      return password(email, this.password);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PasswordCredential value) password,
    required TResult Function(MagicLinkCredential value) magicLink,
  }) {
    return password(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PasswordCredential value)? password,
    TResult? Function(MagicLinkCredential value)? magicLink,
  }) {
    return password?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PasswordCredential value)? password,
    TResult Function(MagicLinkCredential value)? magicLink,
    required TResult orElse(),
  }) {
    if (password != null) {
      return password(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PasswordCredentialImplToJson(
      this,
    );
  }
}

abstract class PasswordCredential implements Credential {
  const factory PasswordCredential(
      {required final String email,
      required final String password}) = _$PasswordCredentialImpl;

  factory PasswordCredential.fromJson(Map<String, dynamic> json) =
      _$PasswordCredentialImpl.fromJson;

  @override
  String get email;
  String get password;

  /// Create a copy of Credential
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PasswordCredentialImplCopyWith<_$PasswordCredentialImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MagicLinkCredentialImplCopyWith<$Res>
    implements $CredentialCopyWith<$Res> {
  factory _$$MagicLinkCredentialImplCopyWith(_$MagicLinkCredentialImpl value,
          $Res Function(_$MagicLinkCredentialImpl) then) =
      __$$MagicLinkCredentialImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String email});
}

/// @nodoc
class __$$MagicLinkCredentialImplCopyWithImpl<$Res>
    extends _$CredentialCopyWithImpl<$Res, _$MagicLinkCredentialImpl>
    implements _$$MagicLinkCredentialImplCopyWith<$Res> {
  __$$MagicLinkCredentialImplCopyWithImpl(_$MagicLinkCredentialImpl _value,
      $Res Function(_$MagicLinkCredentialImpl) _then)
      : super(_value, _then);

  /// Create a copy of Credential
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? email = null,
  }) {
    return _then(_$MagicLinkCredentialImpl(
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MagicLinkCredentialImpl implements MagicLinkCredential {
  const _$MagicLinkCredentialImpl({required this.email, final String? $type})
      : $type = $type ?? 'magiclink';

  factory _$MagicLinkCredentialImpl.fromJson(Map<String, dynamic> json) =>
      _$$MagicLinkCredentialImplFromJson(json);

  @override
  final String email;

  @JsonKey(name: 'type')
  final String $type;

  @override
  String toString() {
    return 'Credential.magicLink(email: $email)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MagicLinkCredentialImpl &&
            (identical(other.email, email) || other.email == email));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, email);

  /// Create a copy of Credential
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MagicLinkCredentialImplCopyWith<_$MagicLinkCredentialImpl> get copyWith =>
      __$$MagicLinkCredentialImplCopyWithImpl<_$MagicLinkCredentialImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String email, String password) password,
    required TResult Function(String email) magicLink,
  }) {
    return magicLink(email);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String email, String password)? password,
    TResult? Function(String email)? magicLink,
  }) {
    return magicLink?.call(email);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String email, String password)? password,
    TResult Function(String email)? magicLink,
    required TResult orElse(),
  }) {
    if (magicLink != null) {
      return magicLink(email);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PasswordCredential value) password,
    required TResult Function(MagicLinkCredential value) magicLink,
  }) {
    return magicLink(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PasswordCredential value)? password,
    TResult? Function(MagicLinkCredential value)? magicLink,
  }) {
    return magicLink?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PasswordCredential value)? password,
    TResult Function(MagicLinkCredential value)? magicLink,
    required TResult orElse(),
  }) {
    if (magicLink != null) {
      return magicLink(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MagicLinkCredentialImplToJson(
      this,
    );
  }
}

abstract class MagicLinkCredential implements Credential {
  const factory MagicLinkCredential({required final String email}) =
      _$MagicLinkCredentialImpl;

  factory MagicLinkCredential.fromJson(Map<String, dynamic> json) =
      _$MagicLinkCredentialImpl.fromJson;

  @override
  String get email;

  /// Create a copy of Credential
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MagicLinkCredentialImplCopyWith<_$MagicLinkCredentialImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VoceUser _$VoceUserFromJson(Map<String, dynamic> json) {
  return _VoceUser.fromJson(json);
}

/// @nodoc
mixin _$VoceUser {
  int get uid => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_admin')
  bool get isAdmin => throw _privateConstructorUsedError;
  @JsonKey(name: 'avatar_updated_at')
  int? get avatarUpdatedAt => throw _privateConstructorUsedError;

  /// Serializes this VoceUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VoceUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoceUserCopyWith<VoceUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoceUserCopyWith<$Res> {
  factory $VoceUserCopyWith(VoceUser value, $Res Function(VoceUser) then) =
      _$VoceUserCopyWithImpl<$Res, VoceUser>;
  @useResult
  $Res call(
      {int uid,
      String name,
      String? email,
      @JsonKey(name: 'is_admin') bool isAdmin,
      @JsonKey(name: 'avatar_updated_at') int? avatarUpdatedAt});
}

/// @nodoc
class _$VoceUserCopyWithImpl<$Res, $Val extends VoceUser>
    implements $VoceUserCopyWith<$Res> {
  _$VoceUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoceUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? name = null,
    Object? email = freezed,
    Object? isAdmin = null,
    Object? avatarUpdatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      isAdmin: null == isAdmin
          ? _value.isAdmin
          : isAdmin // ignore: cast_nullable_to_non_nullable
              as bool,
      avatarUpdatedAt: freezed == avatarUpdatedAt
          ? _value.avatarUpdatedAt
          : avatarUpdatedAt // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VoceUserImplCopyWith<$Res>
    implements $VoceUserCopyWith<$Res> {
  factory _$$VoceUserImplCopyWith(
          _$VoceUserImpl value, $Res Function(_$VoceUserImpl) then) =
      __$$VoceUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int uid,
      String name,
      String? email,
      @JsonKey(name: 'is_admin') bool isAdmin,
      @JsonKey(name: 'avatar_updated_at') int? avatarUpdatedAt});
}

/// @nodoc
class __$$VoceUserImplCopyWithImpl<$Res>
    extends _$VoceUserCopyWithImpl<$Res, _$VoceUserImpl>
    implements _$$VoceUserImplCopyWith<$Res> {
  __$$VoceUserImplCopyWithImpl(
      _$VoceUserImpl _value, $Res Function(_$VoceUserImpl) _then)
      : super(_value, _then);

  /// Create a copy of VoceUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? name = null,
    Object? email = freezed,
    Object? isAdmin = null,
    Object? avatarUpdatedAt = freezed,
  }) {
    return _then(_$VoceUserImpl(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      isAdmin: null == isAdmin
          ? _value.isAdmin
          : isAdmin // ignore: cast_nullable_to_non_nullable
              as bool,
      avatarUpdatedAt: freezed == avatarUpdatedAt
          ? _value.avatarUpdatedAt
          : avatarUpdatedAt // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VoceUserImpl implements _VoceUser {
  const _$VoceUserImpl(
      {required this.uid,
      required this.name,
      this.email,
      @JsonKey(name: 'is_admin') this.isAdmin = false,
      @JsonKey(name: 'avatar_updated_at') this.avatarUpdatedAt});

  factory _$VoceUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$VoceUserImplFromJson(json);

  @override
  final int uid;
  @override
  final String name;
  @override
  final String? email;
  @override
  @JsonKey(name: 'is_admin')
  final bool isAdmin;
  @override
  @JsonKey(name: 'avatar_updated_at')
  final int? avatarUpdatedAt;

  @override
  String toString() {
    return 'VoceUser(uid: $uid, name: $name, email: $email, isAdmin: $isAdmin, avatarUpdatedAt: $avatarUpdatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoceUserImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin) &&
            (identical(other.avatarUpdatedAt, avatarUpdatedAt) ||
                other.avatarUpdatedAt == avatarUpdatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, uid, name, email, isAdmin, avatarUpdatedAt);

  /// Create a copy of VoceUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoceUserImplCopyWith<_$VoceUserImpl> get copyWith =>
      __$$VoceUserImplCopyWithImpl<_$VoceUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VoceUserImplToJson(
      this,
    );
  }
}

abstract class _VoceUser implements VoceUser {
  const factory _VoceUser(
          {required final int uid,
          required final String name,
          final String? email,
          @JsonKey(name: 'is_admin') final bool isAdmin,
          @JsonKey(name: 'avatar_updated_at') final int? avatarUpdatedAt}) =
      _$VoceUserImpl;

  factory _VoceUser.fromJson(Map<String, dynamic> json) =
      _$VoceUserImpl.fromJson;

  @override
  int get uid;
  @override
  String get name;
  @override
  String? get email;
  @override
  @JsonKey(name: 'is_admin')
  bool get isAdmin;
  @override
  @JsonKey(name: 'avatar_updated_at')
  int? get avatarUpdatedAt;

  /// Create a copy of VoceUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoceUserImplCopyWith<_$VoceUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) {
  return _LoginRequest.fromJson(json);
}

/// @nodoc
mixin _$LoginRequest {
  Credential get credential => throw _privateConstructorUsedError;
  String get device => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_token')
  String? get deviceToken => throw _privateConstructorUsedError;

  /// Serializes this LoginRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LoginRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LoginRequestCopyWith<LoginRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LoginRequestCopyWith<$Res> {
  factory $LoginRequestCopyWith(
          LoginRequest value, $Res Function(LoginRequest) then) =
      _$LoginRequestCopyWithImpl<$Res, LoginRequest>;
  @useResult
  $Res call(
      {Credential credential,
      String device,
      @JsonKey(name: 'device_token') String? deviceToken});

  $CredentialCopyWith<$Res> get credential;
}

/// @nodoc
class _$LoginRequestCopyWithImpl<$Res, $Val extends LoginRequest>
    implements $LoginRequestCopyWith<$Res> {
  _$LoginRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LoginRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? credential = null,
    Object? device = null,
    Object? deviceToken = freezed,
  }) {
    return _then(_value.copyWith(
      credential: null == credential
          ? _value.credential
          : credential // ignore: cast_nullable_to_non_nullable
              as Credential,
      device: null == device
          ? _value.device
          : device // ignore: cast_nullable_to_non_nullable
              as String,
      deviceToken: freezed == deviceToken
          ? _value.deviceToken
          : deviceToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of LoginRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CredentialCopyWith<$Res> get credential {
    return $CredentialCopyWith<$Res>(_value.credential, (value) {
      return _then(_value.copyWith(credential: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$LoginRequestImplCopyWith<$Res>
    implements $LoginRequestCopyWith<$Res> {
  factory _$$LoginRequestImplCopyWith(
          _$LoginRequestImpl value, $Res Function(_$LoginRequestImpl) then) =
      __$$LoginRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Credential credential,
      String device,
      @JsonKey(name: 'device_token') String? deviceToken});

  @override
  $CredentialCopyWith<$Res> get credential;
}

/// @nodoc
class __$$LoginRequestImplCopyWithImpl<$Res>
    extends _$LoginRequestCopyWithImpl<$Res, _$LoginRequestImpl>
    implements _$$LoginRequestImplCopyWith<$Res> {
  __$$LoginRequestImplCopyWithImpl(
      _$LoginRequestImpl _value, $Res Function(_$LoginRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of LoginRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? credential = null,
    Object? device = null,
    Object? deviceToken = freezed,
  }) {
    return _then(_$LoginRequestImpl(
      credential: null == credential
          ? _value.credential
          : credential // ignore: cast_nullable_to_non_nullable
              as Credential,
      device: null == device
          ? _value.device
          : device // ignore: cast_nullable_to_non_nullable
              as String,
      deviceToken: freezed == deviceToken
          ? _value.deviceToken
          : deviceToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LoginRequestImpl implements _LoginRequest {
  const _$LoginRequestImpl(
      {required this.credential,
      required this.device,
      @JsonKey(name: 'device_token') this.deviceToken});

  factory _$LoginRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$LoginRequestImplFromJson(json);

  @override
  final Credential credential;
  @override
  final String device;
  @override
  @JsonKey(name: 'device_token')
  final String? deviceToken;

  @override
  String toString() {
    return 'LoginRequest(credential: $credential, device: $device, deviceToken: $deviceToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LoginRequestImpl &&
            (identical(other.credential, credential) ||
                other.credential == credential) &&
            (identical(other.device, device) || other.device == device) &&
            (identical(other.deviceToken, deviceToken) ||
                other.deviceToken == deviceToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, credential, device, deviceToken);

  /// Create a copy of LoginRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LoginRequestImplCopyWith<_$LoginRequestImpl> get copyWith =>
      __$$LoginRequestImplCopyWithImpl<_$LoginRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LoginRequestImplToJson(
      this,
    );
  }
}

abstract class _LoginRequest implements LoginRequest {
  const factory _LoginRequest(
          {required final Credential credential,
          required final String device,
          @JsonKey(name: 'device_token') final String? deviceToken}) =
      _$LoginRequestImpl;

  factory _LoginRequest.fromJson(Map<String, dynamic> json) =
      _$LoginRequestImpl.fromJson;

  @override
  Credential get credential;
  @override
  String get device;
  @override
  @JsonKey(name: 'device_token')
  String? get deviceToken;

  /// Create a copy of LoginRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LoginRequestImplCopyWith<_$LoginRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) {
  return _AuthResponse.fromJson(json);
}

/// @nodoc
mixin _$AuthResponse {
  @JsonKey(name: 'server_id')
  String get serverId => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;
  @JsonKey(name: 'refresh_token')
  String get refreshToken => throw _privateConstructorUsedError;
  @JsonKey(name: 'expired_in')
  int get expiredIn => throw _privateConstructorUsedError;
  VoceUser get user => throw _privateConstructorUsedError;

  /// Serializes this AuthResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthResponseCopyWith<AuthResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthResponseCopyWith<$Res> {
  factory $AuthResponseCopyWith(
          AuthResponse value, $Res Function(AuthResponse) then) =
      _$AuthResponseCopyWithImpl<$Res, AuthResponse>;
  @useResult
  $Res call(
      {@JsonKey(name: 'server_id') String serverId,
      String token,
      @JsonKey(name: 'refresh_token') String refreshToken,
      @JsonKey(name: 'expired_in') int expiredIn,
      VoceUser user});

  $VoceUserCopyWith<$Res> get user;
}

/// @nodoc
class _$AuthResponseCopyWithImpl<$Res, $Val extends AuthResponse>
    implements $AuthResponseCopyWith<$Res> {
  _$AuthResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serverId = null,
    Object? token = null,
    Object? refreshToken = null,
    Object? expiredIn = null,
    Object? user = null,
  }) {
    return _then(_value.copyWith(
      serverId: null == serverId
          ? _value.serverId
          : serverId // ignore: cast_nullable_to_non_nullable
              as String,
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      refreshToken: null == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiredIn: null == expiredIn
          ? _value.expiredIn
          : expiredIn // ignore: cast_nullable_to_non_nullable
              as int,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as VoceUser,
    ) as $Val);
  }

  /// Create a copy of AuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VoceUserCopyWith<$Res> get user {
    return $VoceUserCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AuthResponseImplCopyWith<$Res>
    implements $AuthResponseCopyWith<$Res> {
  factory _$$AuthResponseImplCopyWith(
          _$AuthResponseImpl value, $Res Function(_$AuthResponseImpl) then) =
      __$$AuthResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'server_id') String serverId,
      String token,
      @JsonKey(name: 'refresh_token') String refreshToken,
      @JsonKey(name: 'expired_in') int expiredIn,
      VoceUser user});

  @override
  $VoceUserCopyWith<$Res> get user;
}

/// @nodoc
class __$$AuthResponseImplCopyWithImpl<$Res>
    extends _$AuthResponseCopyWithImpl<$Res, _$AuthResponseImpl>
    implements _$$AuthResponseImplCopyWith<$Res> {
  __$$AuthResponseImplCopyWithImpl(
      _$AuthResponseImpl _value, $Res Function(_$AuthResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of AuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serverId = null,
    Object? token = null,
    Object? refreshToken = null,
    Object? expiredIn = null,
    Object? user = null,
  }) {
    return _then(_$AuthResponseImpl(
      serverId: null == serverId
          ? _value.serverId
          : serverId // ignore: cast_nullable_to_non_nullable
              as String,
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      refreshToken: null == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiredIn: null == expiredIn
          ? _value.expiredIn
          : expiredIn // ignore: cast_nullable_to_non_nullable
              as int,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as VoceUser,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AuthResponseImpl implements _AuthResponse {
  const _$AuthResponseImpl(
      {@JsonKey(name: 'server_id') required this.serverId,
      required this.token,
      @JsonKey(name: 'refresh_token') required this.refreshToken,
      @JsonKey(name: 'expired_in') required this.expiredIn,
      required this.user});

  factory _$AuthResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$AuthResponseImplFromJson(json);

  @override
  @JsonKey(name: 'server_id')
  final String serverId;
  @override
  final String token;
  @override
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @override
  @JsonKey(name: 'expired_in')
  final int expiredIn;
  @override
  final VoceUser user;

  @override
  String toString() {
    return 'AuthResponse(serverId: $serverId, token: $token, refreshToken: $refreshToken, expiredIn: $expiredIn, user: $user)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthResponseImpl &&
            (identical(other.serverId, serverId) ||
                other.serverId == serverId) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken) &&
            (identical(other.expiredIn, expiredIn) ||
                other.expiredIn == expiredIn) &&
            (identical(other.user, user) || other.user == user));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, serverId, token, refreshToken, expiredIn, user);

  /// Create a copy of AuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthResponseImplCopyWith<_$AuthResponseImpl> get copyWith =>
      __$$AuthResponseImplCopyWithImpl<_$AuthResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AuthResponseImplToJson(
      this,
    );
  }
}

abstract class _AuthResponse implements AuthResponse {
  const factory _AuthResponse(
      {@JsonKey(name: 'server_id') required final String serverId,
      required final String token,
      @JsonKey(name: 'refresh_token') required final String refreshToken,
      @JsonKey(name: 'expired_in') required final int expiredIn,
      required final VoceUser user}) = _$AuthResponseImpl;

  factory _AuthResponse.fromJson(Map<String, dynamic> json) =
      _$AuthResponseImpl.fromJson;

  @override
  @JsonKey(name: 'server_id')
  String get serverId;
  @override
  String get token;
  @override
  @JsonKey(name: 'refresh_token')
  String get refreshToken;
  @override
  @JsonKey(name: 'expired_in')
  int get expiredIn;
  @override
  VoceUser get user;

  /// Create a copy of AuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthResponseImplCopyWith<_$AuthResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RenewResponse _$RenewResponseFromJson(Map<String, dynamic> json) {
  return _RenewResponse.fromJson(json);
}

/// @nodoc
mixin _$RenewResponse {
  String get token => throw _privateConstructorUsedError;
  @JsonKey(name: 'refresh_token')
  String get refreshToken => throw _privateConstructorUsedError;
  @JsonKey(name: 'expired_in')
  int get expiredIn => throw _privateConstructorUsedError;

  /// Serializes this RenewResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RenewResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RenewResponseCopyWith<RenewResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RenewResponseCopyWith<$Res> {
  factory $RenewResponseCopyWith(
          RenewResponse value, $Res Function(RenewResponse) then) =
      _$RenewResponseCopyWithImpl<$Res, RenewResponse>;
  @useResult
  $Res call(
      {String token,
      @JsonKey(name: 'refresh_token') String refreshToken,
      @JsonKey(name: 'expired_in') int expiredIn});
}

/// @nodoc
class _$RenewResponseCopyWithImpl<$Res, $Val extends RenewResponse>
    implements $RenewResponseCopyWith<$Res> {
  _$RenewResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RenewResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? token = null,
    Object? refreshToken = null,
    Object? expiredIn = null,
  }) {
    return _then(_value.copyWith(
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      refreshToken: null == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiredIn: null == expiredIn
          ? _value.expiredIn
          : expiredIn // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RenewResponseImplCopyWith<$Res>
    implements $RenewResponseCopyWith<$Res> {
  factory _$$RenewResponseImplCopyWith(
          _$RenewResponseImpl value, $Res Function(_$RenewResponseImpl) then) =
      __$$RenewResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String token,
      @JsonKey(name: 'refresh_token') String refreshToken,
      @JsonKey(name: 'expired_in') int expiredIn});
}

/// @nodoc
class __$$RenewResponseImplCopyWithImpl<$Res>
    extends _$RenewResponseCopyWithImpl<$Res, _$RenewResponseImpl>
    implements _$$RenewResponseImplCopyWith<$Res> {
  __$$RenewResponseImplCopyWithImpl(
      _$RenewResponseImpl _value, $Res Function(_$RenewResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of RenewResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? token = null,
    Object? refreshToken = null,
    Object? expiredIn = null,
  }) {
    return _then(_$RenewResponseImpl(
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      refreshToken: null == refreshToken
          ? _value.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiredIn: null == expiredIn
          ? _value.expiredIn
          : expiredIn // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RenewResponseImpl implements _RenewResponse {
  const _$RenewResponseImpl(
      {required this.token,
      @JsonKey(name: 'refresh_token') required this.refreshToken,
      @JsonKey(name: 'expired_in') required this.expiredIn});

  factory _$RenewResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$RenewResponseImplFromJson(json);

  @override
  final String token;
  @override
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @override
  @JsonKey(name: 'expired_in')
  final int expiredIn;

  @override
  String toString() {
    return 'RenewResponse(token: $token, refreshToken: $refreshToken, expiredIn: $expiredIn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RenewResponseImpl &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken) &&
            (identical(other.expiredIn, expiredIn) ||
                other.expiredIn == expiredIn));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, token, refreshToken, expiredIn);

  /// Create a copy of RenewResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RenewResponseImplCopyWith<_$RenewResponseImpl> get copyWith =>
      __$$RenewResponseImplCopyWithImpl<_$RenewResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RenewResponseImplToJson(
      this,
    );
  }
}

abstract class _RenewResponse implements RenewResponse {
  const factory _RenewResponse(
          {required final String token,
          @JsonKey(name: 'refresh_token') required final String refreshToken,
          @JsonKey(name: 'expired_in') required final int expiredIn}) =
      _$RenewResponseImpl;

  factory _RenewResponse.fromJson(Map<String, dynamic> json) =
      _$RenewResponseImpl.fromJson;

  @override
  String get token;
  @override
  @JsonKey(name: 'refresh_token')
  String get refreshToken;
  @override
  @JsonKey(name: 'expired_in')
  int get expiredIn;

  /// Create a copy of RenewResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RenewResponseImplCopyWith<_$RenewResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
