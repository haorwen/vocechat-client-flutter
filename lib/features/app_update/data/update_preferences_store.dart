import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UpdatePreferences {
  const UpdatePreferences({
    this.skippedVersionCode = 0,
    this.requiredVersionCode = 0,
    this.emergencySkipsUsed = 0,
    this.emergencySkipUntilMs = 0,
  });

  final int skippedVersionCode;

  /// Highest outstanding forced build observed during this emergency period.
  final int requiredVersionCode;
  final int emergencySkipsUsed;
  final int emergencySkipUntilMs;

  factory UpdatePreferences.fromJson(Map<String, dynamic> json) {
    final skipped = json['skipped_version_code'];
    final required = json['required_version_code'];
    final used = json['emergency_skips_used'];
    final until = json['emergency_skip_until_ms'] ?? 0;
    if (skipped is! int ||
        skipped < 0 ||
        required is! int ||
        required < 0 ||
        used is! int ||
        used < 0 ||
        used > 3 ||
        until is! int ||
        until < 0 ||
        (required == 0 && used != 0) ||
        (used == 0 && until != 0)) {
      throw const FormatException('Invalid update preferences');
    }
    return UpdatePreferences(
      skippedVersionCode: skipped,
      requiredVersionCode: required,
      emergencySkipsUsed: used,
      emergencySkipUntilMs: until,
    );
  }

  Map<String, dynamic> toJson() => {
        'skipped_version_code': skippedVersionCode,
        'required_version_code': requiredVersionCode,
        'emergency_skips_used': emergencySkipsUsed,
        'emergency_skip_until_ms': emergencySkipUntilMs,
      };
}

/// App-wide preferences: switching chat servers/accounts must not replenish
/// emergency skips. All fields are written together before dismissing a prompt.
class UpdatePreferencesStore {
  static const storageKey = 'android_update_preferences_v1';

  Future<UpdatePreferences> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return const UpdatePreferences();
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid update preferences');
    }
    return UpdatePreferences.fromJson(json);
  }

  Future<void> write(UpdatePreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setString(storageKey, jsonEncode(value.toJson()))) {
        throw StateError('Unable to save update preferences');
      }
    } catch (_) {
      // SharedPreferences changes its memory cache before the native write.
      // Discard that speculative value if persistence fails.
      await prefs.reload();
      rethrow;
    }
  }
}
