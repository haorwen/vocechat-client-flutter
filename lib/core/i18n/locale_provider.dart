import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

/// Supported app locales. `null` means "follow system".
class AppLocale {
  const AppLocale({required this.code, this.locale});
  final String code;
  final Locale? locale;

  static const system = AppLocale(code: 'system');
  static const english = AppLocale(code: 'en', locale: Locale('en'));
  static const chinese = AppLocale(code: 'zh', locale: Locale('zh'));
  static const japanese = AppLocale(code: 'ja', locale: Locale('ja'));
  static const korean = AppLocale(code: 'ko', locale: Locale('ko'));
  static const spanish = AppLocale(code: 'es', locale: Locale('es'));
  static const french = AppLocale(code: 'fr', locale: Locale('fr'));
  static const russian = AppLocale(code: 'ru', locale: Locale('ru'));
  static const portuguese = AppLocale(code: 'pt', locale: Locale('pt'));

  static const values = [
    system,
    english,
    chinese,
    japanese,
    korean,
    spanish,
    french,
    russian,
    portuguese,
  ];

  static AppLocale fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return system;
  }
}

const _kLocaleKey = 'app.locale.code';

/// Persisted locale preference. Returns the [Locale] to feed into
/// `MaterialApp.locale` — `null` means "let the framework pick from
/// `supportedLocales` based on the device language".
@Riverpod(keepAlive: true)
class LocaleNotifier extends _$LocaleNotifier {
  AppLocale _selection = AppLocale.system;

  AppLocale get selection => _selection;

  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    _selection = AppLocale.fromCode(code);
    state = _selection.locale;
  }

  Future<void> setLocale(AppLocale value) async {
    _selection = value;
    state = value.locale;
    final prefs = await SharedPreferences.getInstance();
    if (value == AppLocale.system) {
      await prefs.remove(_kLocaleKey);
    } else {
      await prefs.setString(_kLocaleKey, value.code);
    }
  }
}
