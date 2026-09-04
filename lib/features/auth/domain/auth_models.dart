// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../shared/models/avo_params.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

// ---------------------------------------------------------------------------
// Credential (sealed)
// ---------------------------------------------------------------------------

@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.snake)
sealed class Credential with _$Credential {
  const factory Credential.password({
    required String email,
    required String password,
  }) = PasswordCredential;

  @FreezedUnionValue('magiclink')
  const factory Credential.magicLink({
    required String email,
  }) = MagicLinkCredential;

  factory Credential.fromJson(Map<String, dynamic> json) =>
      _$CredentialFromJson(json);
}

// Custom toJson handled by Freezed union key discriminator.
// Freezed will emit a 'runtimeType' key by default; we override with @JsonKey.

// ---------------------------------------------------------------------------
// VoceUser
// ---------------------------------------------------------------------------

@freezed
class VoceUser with _$VoceUser {
  const factory VoceUser({
    required int uid,
    required String name,
    String? email,
    @JsonKey(name: 'is_admin') @Default(false) bool isAdmin,
    @JsonKey(name: 'avatar_updated_at') int? avatarUpdatedAt,
    @JsonKey(fromJson: _avoParamsFromJson, toJson: _avoParamsToJson)
    AvoParams? avoParams,
  }) = _VoceUser;

  factory VoceUser.fromJson(Map<String, dynamic> json) =>
      _$VoceUserFromJson(json);
}

AvoParams? _avoParamsFromJson(Object? value) =>
    value is Map ? AvoParams.normalize(Map<String, dynamic>.from(value)) : null;

Map<String, dynamic>? _avoParamsToJson(AvoParams? value) => value?.toJson();

// ---------------------------------------------------------------------------
// LoginRequest
// ---------------------------------------------------------------------------

@freezed
class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required Credential credential,
    required String device,
    @JsonKey(name: 'device_token') String? deviceToken,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

// ---------------------------------------------------------------------------
// AuthResponse
// ---------------------------------------------------------------------------

@freezed
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    @JsonKey(name: 'server_id') required String serverId,
    required String token,
    @JsonKey(name: 'refresh_token') required String refreshToken,
    @JsonKey(name: 'expired_in') required int expiredIn,
    required VoceUser user,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
}

// ---------------------------------------------------------------------------
// RenewResponse (partial – only tokens returned)
// ---------------------------------------------------------------------------

@freezed
class RenewResponse with _$RenewResponse {
  const factory RenewResponse({
    required String token,
    @JsonKey(name: 'refresh_token') required String refreshToken,
    @JsonKey(name: 'expired_in') required int expiredIn,
  }) = _RenewResponse;

  factory RenewResponse.fromJson(Map<String, dynamic> json) =>
      _$RenewResponseFromJson(json);
}

// ---------------------------------------------------------------------------
// SendRegMagicTokenResponse
// ---------------------------------------------------------------------------

/// Response of `POST /api/user/send_reg_magic_link`. When the server has
/// SMTP confirmation enabled, [mailIsSent] is true and [newMagicToken] is
/// withheld (empty) — the client must wait for the user to click the
/// confirmation link emailed to them (not supported by this client yet).
/// When SMTP is disabled, [mailIsSent] is false and [newMagicToken] is a
/// fresh, already-confirmed token usable immediately with `register()`.
@freezed
class SendRegMagicTokenResponse with _$SendRegMagicTokenResponse {
  const factory SendRegMagicTokenResponse({
    @JsonKey(name: 'new_magic_token') required String newMagicToken,
    @JsonKey(name: 'mail_is_sent') required bool mailIsSent,
  }) = _SendRegMagicTokenResponse;

  factory SendRegMagicTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$SendRegMagicTokenResponseFromJson(json);
}
