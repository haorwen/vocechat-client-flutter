import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:vocechat_client/core/storage/preference_write.dart';
import 'package:vocechat_client/core/theme/font_size_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> load() async {
    await SharedPreferences.getInstance();
    await Future<void>.delayed(Duration.zero);
  }

  for (final step in [6, 7]) {
    test('restores saved font size step $step in a fresh provider container',
        () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      expect(first.read(fontSizeProvider), defaultFontSizeStep);
      first.read(fontSizeProvider.notifier).setStep(step);
      await first.read(fontSizeProvider.notifier).save();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(fontSizeProvider);
      await load();
      expect(second.read(fontSizeProvider), step);
      expect(
          fontSizeScales[second.read(fontSizeProvider)], step == 6 ? 1.3 : 1.4);

      second.read(fontSizeProvider.notifier).setStep(defaultFontSizeStep);
      await second.read(fontSizeProvider.notifier).save();
      expect(
          (await SharedPreferences.getInstance())
              .containsKey('app.fontSize.step'),
          isFalse);
      final third = ProviderContainer();
      addTearDown(third.dispose);
      third.read(fontSizeProvider);
      await load();
      expect(third.read(fontSizeProvider), defaultFontSizeStep);
    });
  }

  for (final saved in [-1, 99, 'large']) {
    test('invalid preference $saved uses the default', () async {
      SharedPreferences.setMockInitialValues({'app.fontSize.step': saved});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(fontSizeProvider);
      await load();
      expect(container.read(fontSizeProvider), defaultFontSizeStep);
    });
  }

  test('a late startup read cannot undo a new selection', () async {
    SharedPreferences.setMockInitialValues({'app.fontSize.step': 0});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(fontSizeProvider.notifier).setStep(6);
    await load();
    expect(container.read(fontSizeProvider), 6);
  });

  test('rapid saves keep the last selection on disk', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(fontSizeProvider.notifier);
    notifier.setStep(0);
    final first = notifier.save();
    notifier.setStep(6);
    final second = notifier.save();
    await Future.wait([first, second]);
    expect(
        (await SharedPreferences.getInstance()).getInt('app.fontSize.step'), 6);
  });

  test('a failed save can be retried without breaking later writes', () async {
    final disk = _FailingPreferences();
    SharedPreferencesStorePlatform.instance = disk;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final notifier = container.read(fontSizeProvider.notifier);
    notifier.setStep(6);
    await expectLater(
        notifier.save(), throwsA(isA<PreferenceWriteException>()));
    expect(container.read(fontSizeProvider), 6);
    disk.fail = false;
    await notifier.save();
    expect(disk.values['flutter.app.fontSize.step'], 6);
  });
}

class _FailingPreferences extends SharedPreferencesStorePlatform {
  final values = <String, Object>{};
  bool fail = true;

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (fail) return false;
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}
