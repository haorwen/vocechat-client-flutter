import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool get isAndroidBackgroundSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const backgroundChannel = MethodChannel('chat.voce/background');

class BackgroundStatus {
  const BackgroundStatus(
      {this.enabled = false,
      this.running = false,
      this.notifications = false,
      this.batteryExempt = false,
      this.batterySettingsVisited = false,
      this.pushEnabled = true,
      this.soundEnabled = true,
      this.mentionsOnly = false});
  final bool enabled;
  final bool running;
  final bool notifications;
  final bool batteryExempt;
  final bool batterySettingsVisited;

  bool get batterySetupComplete => batteryExempt || batterySettingsVisited;
  final bool pushEnabled;
  final bool soundEnabled;
  final bool mentionsOnly;

  factory BackgroundStatus.fromMap(Map<dynamic, dynamic> data) =>
      BackgroundStatus(
        enabled: data['enabled'] == true,
        running: data['running'] == true,
        notifications: data['notifications'] == true,
        batteryExempt: data['batteryExempt'] == true,
        batterySettingsVisited: data['batterySettingsVisited'] == true,
        pushEnabled: data['pushEnabled'] != false,
        soundEnabled: data['soundEnabled'] != false,
        mentionsOnly: data['mentionsOnly'] == true,
      );
}

class BackgroundPreferences extends AsyncNotifier<BackgroundStatus> {
  @override
  Future<BackgroundStatus> build() => _read();

  Future<BackgroundStatus> _read() async {
    if (!isAndroidBackgroundSupported) return const BackgroundStatus();
    return BackgroundStatus.fromMap(
        await backgroundChannel.invokeMapMethod('status') ?? const {});
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_read);
  }

  Future<void> openBatterySettings() async {
    if (!isAndroidBackgroundSupported) return;
    try {
      await backgroundChannel.invokeMethod('batterySettings');
    } finally {
      // Refresh even if an OEM does not provide a working settings activity.
      await refresh();
    }
  }

  Future<void> updateNotifications(
      {bool? pushEnabled, bool? soundEnabled, bool? mentionsOnly}) async {
    if (!isAndroidBackgroundSupported) return;
    await backgroundChannel.invokeMethod('notificationPreferences', {
      if (pushEnabled != null) 'pushEnabled': pushEnabled,
      if (soundEnabled != null) 'soundEnabled': soundEnabled,
      if (mentionsOnly != null) 'mentionsOnly': mentionsOnly,
    });
    await refresh();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!isAndroidBackgroundSupported) return;
    // Native preferences are authoritative, including while the UI is detached.
    await backgroundChannel.invokeMethod('setEnabled', {'enabled': enabled});
    await refresh();
  }
}

final backgroundPreferencesProvider =
    AsyncNotifierProvider<BackgroundPreferences, BackgroundStatus>(
        BackgroundPreferences.new);
