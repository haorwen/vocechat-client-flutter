import 'package:flutter/widgets.dart';

/// Measures one complete background interval, including the synthetic `hidden`
/// event Flutter emits on the way back from `paused` to `resumed`.
class ResumeReconnectObserver with WidgetsBindingObserver {
  ResumeReconnectObserver({
    required this.onReconnect,
    this.reconnectAfter = const Duration(minutes: 2),
    DateTime Function()? now,
    AppLifecycleState? initialState,
  }) : _now = now ?? DateTime.now {
    if (initialState != null) didChangeAppLifecycleState(initialState);
  }

  final VoidCallback onReconnect;
  final Duration reconnectAfter;
  final DateTime Function() _now;
  DateTime? _pausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Both pause and resume can pass through hidden. Overwriting this
        // timestamp on resume would make even hours in the background look
        // like a millisecond-long pause, leaving a dead connection in place.
        _pausedAt ??= _now();
      case AppLifecycleState.resumed:
        final pausedAt = _pausedAt;
        _pausedAt = null;
        if (pausedAt != null && _now().difference(pausedAt) >= reconnectAfter) {
          onReconnect();
        }
      case AppLifecycleState.inactive:
        // Permission dialogs, the notification shade and PiP transitions do
        // not by themselves mean the connection spent time in the background.
        break;
    }
  }
}
