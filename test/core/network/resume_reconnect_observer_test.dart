import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/resume_reconnect_observer.dart';

void main() {
  late DateTime now;
  late int reconnects;
  late ResumeReconnectObserver observer;

  setUp(() {
    now = DateTime(2026, 10, 1);
    reconnects = 0;
    observer = ResumeReconnectObserver(
      now: () => now,
      onReconnect: () => reconnects++,
    );
  });

  test('Android resume through hidden reconnects after a long background', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 10));
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(reconnects, 1);

    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(reconnects, 1); // one reconnect per background interval
  });

  test('brief notification shade and permission dialogs do not reconnect', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    now = now.add(const Duration(minutes: 5));
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(reconnects, 0);

    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 5));
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(reconnects, 0);
  });

  test('reattaching an engine retained after Activity destruction reconnects',
      () {
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 3));
    observer.didChangeAppLifecycleState(AppLifecycleState.detached);
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(reconnects, 1);
  });

  test('watcher attached while already backgrounded measures until resume', () {
    observer = ResumeReconnectObserver(
      now: () => now,
      onReconnect: () => reconnects++,
      initialState: AppLifecycleState.paused,
    );
    now = now.add(const Duration(minutes: 2));
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(reconnects, 1);
  });

  test('each background interval starts fresh', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 3));
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(reconnects, 1);

    now = now.add(const Duration(hours: 1));
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 30));
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(reconnects, 1);
  });
}
