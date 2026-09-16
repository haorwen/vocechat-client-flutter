import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_preferences.dart';

/// Android-only; inactive (permission dialogs/PiP) is not a background pause.
final androidBackgroundedProvider =
    StateNotifierProvider<AndroidBackgrounded, bool>((ref) {
  return AndroidBackgrounded();
});

class AndroidBackgrounded extends StateNotifier<bool>
    with WidgetsBindingObserver {
  AndroidBackgrounded()
      : super(isAndroidBackgroundSupported &&
            _isBackground(WidgetsBinding.instance.lifecycleState)) {
    WidgetsBinding.instance.addObserver(this);
  }
  static bool _isBackground(AppLifecycleState? value) =>
      value == AppLifecycleState.hidden ||
      value == AppLifecycleState.paused ||
      value == AppLifecycleState.detached;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isAndroidBackgroundSupported) this.state = _isBackground(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
