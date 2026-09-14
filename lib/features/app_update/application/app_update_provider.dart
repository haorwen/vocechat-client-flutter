import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/dio_client.dart';
import '../data/android_update_api.dart';
import '../domain/android_release.dart';

final androidUpdateSupportedProvider = Provider<bool>(
    (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android);

final androidUpdateApiProvider = Provider<AndroidUpdateApi>(
  (ref) => AndroidUpdateApi(ref.read(dioClientProvider).dio),
);

final installedAndroidVersionCodeProvider = FutureProvider<int>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final code = int.tryParse(info.buildNumber);
  if (code == null || code <= 0) {
    throw const FormatException('Invalid installed Android version code');
  }
  return code;
});

/// One check per ProviderScope/process lifetime, including before login.
/// Intentionally no autoDispose, timers, resume checks or server subscriptions:
/// publishing a release does not interrupt clients that are already running.
final startupAndroidUpdateProvider =
    FutureProvider<AndroidRelease?>((ref) async {
  if (!ref.read(androidUpdateSupportedProvider)) return null;
  final installed = await ref.read(installedAndroidVersionCodeProvider.future);
  final release = await ref.read(androidUpdateApiProvider).check();
  return release.isNewerThan(installed) ? release : null;
});
