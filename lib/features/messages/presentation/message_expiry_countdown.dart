import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// A message's remaining lifetime, isolated so ticking never rebuilds the
/// message body, media player, or chat list. Deletion stays in ChatController.
class MessageExpiryCountdown extends StatefulWidget {
  const MessageExpiryCountdown({
    super.key,
    required this.durationSeconds,
    required this.expiresAt,
    this.currentTime,
  });

  final int durationSeconds;

  /// Unix milliseconds. Null while an optimistic message is still unsent:
  /// show its configured lifetime without starting the countdown yet.
  final int? expiresAt;

  @visibleForTesting
  final DateTime Function()? currentTime;

  @override
  State<MessageExpiryCountdown> createState() => _MessageExpiryCountdownState();
}

class _MessageExpiryCountdownState extends State<MessageExpiryCountdown>
    with WidgetsBindingObserver {
  Timer? _timer;
  late int _remainingSeconds;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _active = lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.hidden &&
        lifecycle != AppLifecycleState.detached;
    _restart();
  }

  @override
  void didUpdateWidget(covariant MessageExpiryCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt ||
        oldWidget.durationSeconds != widget.durationSeconds ||
        oldWidget.currentTime != widget.currentTime) {
      _restart();
    }
  }

  int _secondsLeft() {
    final deadline = widget.expiresAt;
    if (deadline == null) return widget.durationSeconds;
    final now = (widget.currentTime ?? DateTime.now)().millisecondsSinceEpoch;
    final remainingMs = deadline - now;
    // Keep the last second visible until the same deadline used for deletion.
    return remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
  }

  void _restart() {
    _timer?.cancel();
    _remainingSeconds = _secondsLeft();
    if (!_active || widget.expiresAt == null || _remainingSeconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Recompute from the absolute deadline, rather than decrementing a
      // counter that drifts when frames are delayed or the app is suspended.
      final next = _secondsLeft();
      if (next != _remainingSeconds) {
        setState(() => _remainingSeconds = next);
      }
      if (next <= 0) _timer?.cancel();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      setState(_restart);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _active = false;
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    final durationLabel = switch (widget.durationSeconds) {
      300 => l.chatAutoDelete5Min,
      600 => l.chatAutoDelete10Min,
      3600 => l.chatAutoDelete1Hour,
      86400 => l.chatAutoDelete1Day,
      604800 => l.chatAutoDelete1Week,
      _ => _formatCountdown(widget.durationSeconds),
    };
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF475467);
    return Tooltip(
      message: l.chatExpiresTooltip(durationLabel),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            _formatCountdown(_remainingSeconds),
            style: TextStyle(
              color: color,
              fontSize: 12,
              height: 18 / 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCountdown(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = ((seconds ~/ 60) % 60).toString().padLeft(2, '0');
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '${hours.toString().padLeft(2, '0')}:$minutes:$remainder'
      : '$minutes:$remainder';
}
