import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/update_preferences_store.dart';
import '../domain/android_release.dart';
import 'app_update_provider.dart';

class AndroidUpdatePrompt {
  const AndroidUpdatePrompt({
    required this.release,
    required this.isRequired,
    required this.emergencySkipsRemaining,
    this.preferencesAvailable = true,
  });

  final AndroidRelease release;
  final bool isRequired;
  final int emergencySkipsRemaining;
  final bool preferencesAvailable;
}

final updatePreferencesStoreProvider =
    Provider((ref) => UpdatePreferencesStore());
final updateClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);
final appUpdateControllerProvider =
    AsyncNotifierProvider<AppUpdateController, AndroidUpdatePrompt?>(
        AppUpdateController.new);

class AppUpdateController extends AsyncNotifier<AndroidUpdatePrompt?> {
  static const maxEmergencySkips = 3;
  bool _saving = false;

  @override
  Future<AndroidUpdatePrompt?> build() async {
    if (!ref.read(androidUpdateSupportedProvider)) return null;
    final installed =
        await ref.read(installedAndroidVersionCodeProvider.future);
    final release = await ref.read(startupAndroidUpdateProvider.future);
    final required = release?.isRequiredFor(installed) ?? false;
    final store = ref.read(updatePreferencesStoreProvider);
    late UpdatePreferences preferences;
    try {
      final previous = await store.read();
      // Reset only after the installed APK has met the previously observed
      // requirement. Merely publishing another build cannot grant more skips.
      final fulfilled = installed >= previous.requiredVersionCode;
      final floor = required ? release!.requiredVersionCode : 0;
      final outstanding = fulfilled ? 0 : previous.requiredVersionCode;
      preferences = UpdatePreferences(
        skippedVersionCode: previous.skippedVersionCode,
        requiredVersionCode: floor > outstanding ? floor : outstanding,
        emergencySkipsUsed: fulfilled ? 0 : previous.emergencySkipsUsed,
        emergencySkipUntilMs: fulfilled ? 0 : previous.emergencySkipUntilMs,
      );
      if (preferences.requiredVersionCode != previous.requiredVersionCode ||
          preferences.emergencySkipsUsed != previous.emergencySkipsUsed ||
          preferences.emergencySkipUntilMs != previous.emergencySkipUntilMs) {
        await store.write(preferences);
      }
    } catch (_) {
      // A valid forced response must not be bypassed because preferences are
      // unavailable/corrupt. Offer download, but no unrecorded emergency skip.
      if (release == null) return null;
      return AndroidUpdatePrompt(
        release: release,
        isRequired: required,
        emergencySkipsRemaining: 0,
        preferencesAvailable: false,
      );
    }
    if (release == null ||
        (!required && preferences.skippedVersionCode == release.versionCode)) {
      return null;
    }
    // Every consumed skip grants a complete 24 hours, including the third.
    // Only startup calls build: expiration never interrupts an active session.
    if (required &&
        ref.read(updateClockProvider)().millisecondsSinceEpoch <
            preferences.emergencySkipUntilMs) {
      return null;
    }
    return AndroidUpdatePrompt(
      release: release,
      isRequired: required,
      emergencySkipsRemaining:
          maxEmergencySkips - preferences.emergencySkipsUsed,
    );
  }

  void postpone() {
    if (state.valueOrNull?.isRequired == false && !_saving) {
      state = const AsyncData(null);
    }
  }

  Future<void> skipVersion() => _dismissPersistently(emergency: false);
  Future<void> emergencySkip() => _dismissPersistently(emergency: true);

  Future<void> _dismissPersistently({required bool emergency}) async {
    if (_saving) return;
    final prompt = state.valueOrNull;
    if (prompt == null) return;
    if (emergency != prompt.isRequired || !prompt.preferencesAvailable) {
      throw StateError('This update cannot be skipped');
    }
    _saving = true;
    try {
      final store = ref.read(updatePreferencesStoreProvider);
      final previous = await store.read();
      if (emergency && previous.emergencySkipsUsed >= maxEmergencySkips) {
        throw StateError('No emergency skips remaining');
      }
      await store.write(UpdatePreferences(
        skippedVersionCode: emergency
            ? previous.skippedVersionCode
            : prompt.release.versionCode,
        requiredVersionCode: previous.requiredVersionCode,
        emergencySkipsUsed: previous.emergencySkipsUsed + (emergency ? 1 : 0),
        emergencySkipUntilMs: emergency
            ? ref
                .read(updateClockProvider)()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch
            : previous.emergencySkipUntilMs,
      ));
      state = const AsyncData(null);
    } finally {
      _saving = false;
    }
  }
}
