import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// A quiet clock indicator with the remaining lifetime shown on hover or tap.
/// Ticking never rebuilds the message body, media player, or chat list.
/// Deletion stays in ChatController.
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
  final _tooltipKey = GlobalKey<TooltipState>();
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
      2592000 => l.chatAutoDelete1Month,
      _ => _formatCountdown(widget.durationSeconds),
    };
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF98A2B3);
    return Tooltip(
      key: _tooltipKey,
      message: '${_formatCountdown(_remainingSeconds)}\n'
          '${l.chatExpiresTooltip(durationLabel)}',
      // Mouse hover still works in manual mode. Handle taps ourselves so
      // mouse clicks also show the tooltip immediately, before the hover wait.
      triggerMode: TooltipTriggerMode.manual,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tooltipKey.currentState?.ensureTooltipVisible(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.schedule_outlined, size: 16, color: color),
          ),
        ),
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
