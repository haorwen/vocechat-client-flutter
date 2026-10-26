import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/preference_write.dart';

/// App-wide multipliers, applied on top of the system's accessibility scaling.
const fontSizeScales = [0.85, 0.9, 0.95, 1.0, 1.1, 1.2, 1.3, 1.4];
const defaultFontSizeStep = 3;
const _fontSizeKey = 'app.fontSize.step';

final fontSizeProvider =
    NotifierProvider<FontSizeNotifier, int>(FontSizeNotifier.new);

class FontSizeNotifier extends Notifier<int> {
  bool _changed = false;
  bool _disposed = false;
  Future<void> _write = Future.value();

  @override
  int build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return defaultFontSizeStep;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.get(_fontSizeKey);
      // A late preference read must not undo a drag that already started.
      if (!_disposed &&
          !_changed &&
          saved is int &&
          saved >= 0 &&
          saved < fontSizeScales.length) {
        state = saved;
      }
    } catch (_) {
      // Text sizing remains usable when local storage is unavailable.
    }
  }

  /// Update the UI during a drag without issuing a disk write for every frame.
  void setStep(int step) {
    _changed = true;
    state = step.clamp(0, fontSizeScales.length - 1);
  }

  /// Persist on release. Serialize writes so the last interaction wins.
  Future<void> save() {
    final step = state;
    final write = _write.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await requirePreferenceWrite(
        prefs,
        step == defaultFontSizeStep
            ? prefs.remove(_fontSizeKey)
            : prefs.setInt(_fontSizeKey, step),
      );
    });
    _write = write;
    return write;
  }
}
