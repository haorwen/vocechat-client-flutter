import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocechat_client/core/background/background_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android background policy excludes transient inactive state', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final container = ProviderContainer();
    final state = container.read(androidBackgroundedProvider.notifier);
    try {
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(container.read(androidBackgroundedProvider), isFalse);
      state.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(container.read(androidBackgroundedProvider), isFalse);
      state.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(container.read(androidBackgroundedProvider), isTrue);
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(container.read(androidBackgroundedProvider), isTrue);
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(container.read(androidBackgroundedProvider), isFalse);
      state.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(container.read(androidBackgroundedProvider), isTrue);
    } finally {
      container.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });
  test('iOS lifecycle does not enable Android resource policy', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final container = ProviderContainer();
    final state = container.read(androidBackgroundedProvider.notifier);
    try {
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(container.read(androidBackgroundedProvider), isFalse);
    } finally {
      container.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
