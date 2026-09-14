import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/features/app_update/application/app_update_controller.dart';
import 'package:vocechat_client/features/app_update/application/app_update_provider.dart';
import 'package:vocechat_client/features/app_update/data/update_preferences_store.dart';
import 'package:vocechat_client/features/app_update/domain/android_release.dart';

AndroidRelease release({int code = 23, bool force = true, int floor = 0}) =>
    AndroidRelease(
      version: '0.3.$code',
      versionCode: code,
      timestamp: 1789056000000,
      forceUpdate: force,
      lastForceVersionCode: floor,
      updateUrl: Uri.parse('https://update.voce.chat/app.apk'),
    );

void main() {
  var now = DateTime.utc(2026, 9, 10);
  setUp(() {
    now = DateTime.utc(2026, 9, 10);
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer start(
      {AndroidRelease? metadata,
      int installed = 22,
      UpdatePreferencesStore? store}) {
    final container = ProviderContainer(overrides: [
      androidUpdateSupportedProvider.overrideWithValue(true),
      installedAndroidVersionCodeProvider
          .overrideWith((ref) async => installed),
      startupAndroidUpdateProvider.overrideWith((ref) async => metadata),
      updateClockProvider.overrideWithValue(() => now),
      if (store != null)
        updatePreferencesStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test(
      'three persistent emergency skips each grant exactly 24 hours across restarts',
      () async {
    for (var used = 0; used < 3; used++) {
      final app = start(metadata: release());
      final prompt = await app.read(appUpdateControllerProvider.future);
      expect(prompt!.emergencySkipsRemaining, 3 - used);
      await app.read(appUpdateControllerProvider.notifier).emergencySkip();
      expect(app.read(appUpdateControllerProvider).valueOrNull, isNull);
      final saved = await UpdatePreferencesStore().read();
      expect(saved.emergencySkipsUsed, used + 1);
      expect(saved.emergencySkipUntilMs,
          now.add(const Duration(hours: 24)).millisecondsSinceEpoch);

      // Reload native persisted JSON into a fresh preferences cache to simulate
      // restarting the process, not merely reusing the controller's memory.
      SharedPreferences.setMockInitialValues(
          {UpdatePreferencesStore.storageKey: jsonEncode(saved.toJson())});
      now = now
          .add(const Duration(hours: 24))
          .subtract(const Duration(milliseconds: 1));
      final beforeExpiry = start(metadata: release());
      expect(
          await beforeExpiry.read(appUpdateControllerProvider.future), isNull);
      expect(
          (await UpdatePreferencesStore().read()).emergencySkipsUsed, used + 1);
      now = now.add(const Duration(milliseconds: 1));
      // An already-running session is not interrupted on expiration.
      expect(
          await beforeExpiry.read(appUpdateControllerProvider.future), isNull);
    }
    final exhausted = start(metadata: release());
    expect(
        (await exhausted.read(appUpdateControllerProvider.future))!
            .emergencySkipsRemaining,
        0);
    await expectLater(
        exhausted.read(appUpdateControllerProvider.notifier).emergencySkip(),
        throwsStateError);
    expect(exhausted.read(appUpdateControllerProvider).valueOrNull, isNotNull);
    expect((await UpdatePreferencesStore().read()).emergencySkipsUsed, 3);
  });

  test(
      'new optional and forced releases preserve active exemption and used skips',
      () async {
    final first = start(metadata: release());
    await first.read(appUpdateControllerProvider.future);
    await first.read(appUpdateControllerProvider.notifier).emergencySkip();
    now = now.add(const Duration(hours: 12));
    final optional =
        start(metadata: release(code: 24, force: false, floor: 23));
    expect(await optional.read(appUpdateControllerProvider.future), isNull);
    final forced = start(metadata: release(code: 25));
    expect(await forced.read(appUpdateControllerProvider.future), isNull);
    now = now.add(const Duration(hours: 12));
    final next = start(metadata: release(code: 26, force: false, floor: 25));
    final prompt = await next.read(appUpdateControllerProvider.future);
    expect(prompt!.isRequired, isTrue);
    expect(prompt.emergencySkipsRemaining, 2);
    expect((await UpdatePreferencesStore().read()).requiredVersionCode, 25);
  });

  test(
      'optional skip hides exactly that build and never overrides a forced requirement',
      () async {
    final optional = start(metadata: release(force: false));
    await optional.read(appUpdateControllerProvider.future);
    await optional.read(appUpdateControllerProvider.notifier).skipVersion();
    expect(
        await start(metadata: release(force: false))
            .read(appUpdateControllerProvider.future),
        isNull);
    final newer = await start(metadata: release(code: 24, force: false))
        .read(appUpdateControllerProvider.future);
    expect(newer!.release.versionCode, 24);
    final required = start(metadata: release(force: false, floor: 23));
    expect(
        (await required.read(appUpdateControllerProvider.future))!.isRequired,
        isTrue);
    await expectLater(
        required.read(appUpdateControllerProvider.notifier).skipVersion(),
        throwsStateError);
    required.read(appUpdateControllerProvider.notifier).postpone();
    expect(required.read(appUpdateControllerProvider).valueOrNull, isNotNull);
  });

  test(
      'installing the required build resets emergency usage for a future requirement',
      () async {
    await UpdatePreferencesStore().write(const UpdatePreferences(
        requiredVersionCode: 23, emergencySkipsUsed: 3));
    final upgraded = start(
        metadata: release(code: 24, force: false, floor: 23), installed: 23);
    expect(
        (await upgraded.read(appUpdateControllerProvider.future))!.isRequired,
        isFalse);
    expect((await UpdatePreferencesStore().read()).emergencySkipsUsed, 0);
    final future = start(metadata: release(code: 25), installed: 23);
    expect(
        (await future.read(appUpdateControllerProvider.future))!
            .emergencySkipsRemaining,
        3);
  });

  test(
      'partial upgrade below the observed requirement does not replenish skips',
      () async {
    await UpdatePreferencesStore().write(const UpdatePreferences(
        requiredVersionCode: 25, emergencySkipsUsed: 3));
    final partial = start(
        metadata: release(code: 26, force: false, floor: 25), installed: 23);
    expect(
        (await partial.read(appUpdateControllerProvider.future))!
            .emergencySkipsRemaining,
        0);
  });

  test(
      'up-to-date install clears fulfilled emergency period even without a prompt',
      () async {
    await UpdatePreferencesStore().write(const UpdatePreferences(
        requiredVersionCode: 23, emergencySkipsUsed: 3));
    expect(await start(installed: 23).read(appUpdateControllerProvider.future),
        isNull);
    expect((await UpdatePreferencesStore().read()).requiredVersionCode, 0);
    expect((await UpdatePreferencesStore().read()).emergencySkipsUsed, 0);
  });

  test('concurrent skip requests consume only one opportunity', () async {
    final app = start(metadata: release());
    await app.read(appUpdateControllerProvider.future);
    final controller = app.read(appUpdateControllerProvider.notifier);
    await Future.wait([controller.emergencySkip(), controller.emergencySkip()]);
    expect((await UpdatePreferencesStore().read()).emergencySkipsUsed, 1);
  });

  test('corrupt preferences do not turn a forced update into a bypass',
      () async {
    SharedPreferences.setMockInitialValues(
        {UpdatePreferencesStore.storageKey: 'broken JSON'});
    final app = start(metadata: release());
    final prompt = await app.read(appUpdateControllerProvider.future);
    expect(prompt!.isRequired, isTrue);
    expect(prompt.preferencesAvailable, isFalse);
    expect(prompt.emergencySkipsRemaining, 0);
    await expectLater(
        app.read(appUpdateControllerProvider.notifier).emergencySkip(),
        throwsStateError);
  });

  test(
      'write failure leaves the required update visible without consuming a skip',
      () async {
    final store = _FailingStore();
    final app = start(metadata: release(), store: store);
    await app.read(appUpdateControllerProvider.future);
    store.fail = true;
    await expectLater(
        app.read(appUpdateControllerProvider.notifier).emergencySkip(),
        throwsStateError);
    expect(app.read(appUpdateControllerProvider).valueOrNull, isNotNull);
    expect((await store.read()).emergencySkipsUsed, 0);
  });
}

class _FailingStore extends UpdatePreferencesStore {
  bool fail = false;
  @override
  Future<void> write(UpdatePreferences value) {
    if (fail) throw StateError('write failed');
    return super.write(value);
  }
}
