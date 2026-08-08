// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_store.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AccountConfig _$AccountConfigFromJson(Map<String, dynamic> json) {
  return _AccountConfig.fromJson(json);
}

/// @nodoc
mixin _$AccountConfig {
  String get accountId => throw _privateConstructorUsedError;
  String get serverId => throw _privateConstructorUsedError;
  int get uid => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  bool get isAdmin => throw _privateConstructorUsedError;
  int? get avatarUpdatedAt => throw _privateConstructorUsedError;

  /// Serializes this AccountConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AccountConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AccountConfigCopyWith<AccountConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccountConfigCopyWith<$Res> {
  factory $AccountConfigCopyWith(
          AccountConfig value, $Res Function(AccountConfig) then) =
      _$AccountConfigCopyWithImpl<$Res, AccountConfig>;
  @useResult
  $Res call(
      {String accountId,
      String serverId,
      int uid,
      String name,
      String? email,
      bool isAdmin,
      int? avatarUpdatedAt});
}

/// @nodoc
class _$AccountConfigCopyWithImpl<$Res, $Val extends AccountConfig>
    implements $AccountConfigCopyWith<$Res> {
  _$AccountConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AccountConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accountId = null,
    Object? serverId = null,
    Object? uid = null,
    Object? name = null,
    Object? email = freezed,
    Object? isAdmin = null,
    Object? avatarUpdatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      accountId: null == accountId
          ? _value.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      serverId: null == serverId
          ? _value.serverId
          : serverId // ignore: cast_nullable_to_non_nullable
              as String,
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
abstract class _$$AccountConfigImplCopyWith<$Res>
    implements $AccountConfigCopyWith<$Res> {
  factory _$$AccountConfigImplCopyWith(
          _$AccountConfigImpl value, $Res Function(_$AccountConfigImpl) then) =
      __$$AccountConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String accountId,
      String serverId,
      int uid,
      String name,
      String? email,
      bool isAdmin,
      int? avatarUpdatedAt});
}

/// @nodoc
class __$$AccountConfigImplCopyWithImpl<$Res>
    extends _$AccountConfigCopyWithImpl<$Res, _$AccountConfigImpl>
    implements _$$AccountConfigImplCopyWith<$Res> {
  __$$AccountConfigImplCopyWithImpl(
      _$AccountConfigImpl _value, $Res Function(_$AccountConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of AccountConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accountId = null,
    Object? serverId = null,
    Object? uid = null,
    Object? name = null,
    Object? email = freezed,
    Object? isAdmin = null,
    Object? avatarUpdatedAt = freezed,
  }) {
    return _then(_$AccountConfigImpl(
      accountId: null == accountId
          ? _value.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      serverId: null == serverId
          ? _value.serverId
          : serverId // ignore: cast_nullable_to_non_nullable
              as String,
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
class _$AccountConfigImpl implements _AccountConfig {
  const _$AccountConfigImpl(
      {required this.accountId,
      required this.serverId,
      required this.uid,
      required this.name,
      this.email,
      this.isAdmin = false,
      this.avatarUpdatedAt});

  factory _$AccountConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$AccountConfigImplFromJson(json);

  @override
  final String accountId;
  @override
  final String serverId;
  @override
  final int uid;
  @override
  final String name;
  @override
  final String? email;
  @override
  @JsonKey()
  final bool isAdmin;
  @override
  final int? avatarUpdatedAt;

  @override
  String toString() {
    return 'AccountConfig(accountId: $accountId, serverId: $serverId, uid: $uid, name: $name, email: $email, isAdmin: $isAdmin, avatarUpdatedAt: $avatarUpdatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccountConfigImpl &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.serverId, serverId) ||
                other.serverId == serverId) &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin) &&
            (identical(other.avatarUpdatedAt, avatarUpdatedAt) ||
                other.avatarUpdatedAt == avatarUpdatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, accountId, serverId, uid, name,
      email, isAdmin, avatarUpdatedAt);

  /// Create a copy of AccountConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AccountConfigImplCopyWith<_$AccountConfigImpl> get copyWith =>
      __$$AccountConfigImplCopyWithImpl<_$AccountConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AccountConfigImplToJson(
      this,
    );
  }
}

abstract class _AccountConfig implements AccountConfig {
  const factory _AccountConfig(
      {required final String accountId,
      required final String serverId,
      required final int uid,
      required final String name,
      final String? email,
      final bool isAdmin,
      final int? avatarUpdatedAt}) = _$AccountConfigImpl;

  factory _AccountConfig.fromJson(Map<String, dynamic> json) =
      _$AccountConfigImpl.fromJson;

  @override
  String get accountId;
  @override
  String get serverId;
  @override
  int get uid;
  @override
  String get name;
  @override
  String? get email;
  @override
  bool get isAdmin;
  @override
  int? get avatarUpdatedAt;

  /// Create a copy of AccountConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AccountConfigImplCopyWith<_$AccountConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AccountState {
  List<AccountConfig> get accounts => throw _privateConstructorUsedError;
  String? get currentAccountId => throw _privateConstructorUsedError;

  /// Create a copy of AccountState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AccountStateCopyWith<AccountState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccountStateCopyWith<$Res> {
  factory $AccountStateCopyWith(
          AccountState value, $Res Function(AccountState) then) =
      _$AccountStateCopyWithImpl<$Res, AccountState>;
  @useResult
  $Res call({List<AccountConfig> accounts, String? currentAccountId});
}

/// @nodoc
class _$AccountStateCopyWithImpl<$Res, $Val extends AccountState>
    implements $AccountStateCopyWith<$Res> {
  _$AccountStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AccountState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accounts = null,
    Object? currentAccountId = freezed,
  }) {
    return _then(_value.copyWith(
      accounts: null == accounts
          ? _value.accounts
          : accounts // ignore: cast_nullable_to_non_nullable
              as List<AccountConfig>,
      currentAccountId: freezed == currentAccountId
          ? _value.currentAccountId
          : currentAccountId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AccountStateImplCopyWith<$Res>
    implements $AccountStateCopyWith<$Res> {
  factory _$$AccountStateImplCopyWith(
          _$AccountStateImpl value, $Res Function(_$AccountStateImpl) then) =
      __$$AccountStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AccountConfig> accounts, String? currentAccountId});
}

/// @nodoc
class __$$AccountStateImplCopyWithImpl<$Res>
    extends _$AccountStateCopyWithImpl<$Res, _$AccountStateImpl>
    implements _$$AccountStateImplCopyWith<$Res> {
  __$$AccountStateImplCopyWithImpl(
      _$AccountStateImpl _value, $Res Function(_$AccountStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AccountState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accounts = null,
    Object? currentAccountId = freezed,
  }) {
    return _then(_$AccountStateImpl(
      accounts: null == accounts
          ? _value._accounts
          : accounts // ignore: cast_nullable_to_non_nullable
              as List<AccountConfig>,
      currentAccountId: freezed == currentAccountId
          ? _value.currentAccountId
          : currentAccountId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$AccountStateImpl implements _AccountState {
  const _$AccountStateImpl(
      {final List<AccountConfig> accounts = const [], this.currentAccountId})
      : _accounts = accounts;

  final List<AccountConfig> _accounts;
  @override
  @JsonKey()
  List<AccountConfig> get accounts {
    if (_accounts is EqualUnmodifiableListView) return _accounts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_accounts);
  }

  @override
  final String? currentAccountId;

  @override
  String toString() {
    return 'AccountState(accounts: $accounts, currentAccountId: $currentAccountId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccountStateImpl &&
            const DeepCollectionEquality().equals(other._accounts, _accounts) &&
            (identical(other.currentAccountId, currentAccountId) ||
                other.currentAccountId == currentAccountId));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_accounts), currentAccountId);

  /// Create a copy of AccountState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AccountStateImplCopyWith<_$AccountStateImpl> get copyWith =>
      __$$AccountStateImplCopyWithImpl<_$AccountStateImpl>(this, _$identity);
}

abstract class _AccountState implements AccountState {
  const factory _AccountState(
      {final List<AccountConfig> accounts,
      final String? currentAccountId}) = _$AccountStateImpl;

  @override
  List<AccountConfig> get accounts;
  @override
  String? get currentAccountId;

  /// Create a copy of AccountState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AccountStateImplCopyWith<_$AccountStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
