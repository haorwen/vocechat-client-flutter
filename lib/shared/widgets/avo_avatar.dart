import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/avo_interaction.dart';
import '../models/avo_params.dart';
import 'avo_animation.dart';
import 'avo_painter.dart';

/// Native, platform-independent Avo avatar. Animation frames repaint the
/// canvas through a ticker and never rebuild the surrounding widget tree.
class AvoAvatar extends StatefulWidget {
  const AvoAvatar({
    super.key,
    required this.params,
    this.level = 0,
    this.scale = .62,
    this.interactive = false,
    this.onInteraction,
    this.remoteInteraction,
  });

  final AvoParams params;
  final double level;
  final double scale;
  final bool interactive;
  final ValueChanged<AvoLocalInteraction>? onInteraction;
  final RemoteAvoInteraction? remoteInteraction;

  @override
  State<AvoAvatar> createState() => _AvoAvatarState();
}

class _AvoAvatarState extends State<AvoAvatar>
    with SingleTickerProviderStateMixin {
  static const _pointerInterval = Duration(milliseconds: 50);
  static const _pointerHeartbeat = Duration(milliseconds: 250);
  static const _pointerTtl = Duration(milliseconds: 800);
  static const _petInterval = Duration(milliseconds: 250);

  final _animation = AvoAnimationState();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Size _size = Size.zero;
  AvoPointer? _localPointer;
  AvoPointer? _pendingPointer;
  AvoPointer? _remotePointer;
  Duration? _remotePointerUpdatedAt;
  Duration? _lastPointerSentAt;
  Duration? _lastPointerEventAt;
  Duration? _lastPointerEventTimestamp;
  Offset? _lastPosition;
  Duration? _lastPetSentAt;
  String? _lastRemotePopId;
  String? _lastRemotePetId;

  // Frame timestamps are monotonic and also follow WidgetTester's fake clock.
  Duration get _now => SchedulerBinding.instance.currentSystemFrameTimeStamp;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _applyRemote();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.of(context)) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else {
      _ticker.stop();
      _lastTick = Duration.zero;
    }
  }

  void _tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    final dt =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    final now = _now;
    final remoteUpdatedAt = _remotePointerUpdatedAt;
    if (remoteUpdatedAt != null && now - remoteUpdatedAt >= _pointerTtl) {
      _remotePointer = null;
      _remotePointerUpdatedAt = null;
      if (!widget.interactive) _animation.setPointer(null, remote: true);
    }
    _animation.advance(
      dt,
      targetLevel: widget.level,
      size: _size,
      scale: widget.scale,
    );
    _flushPointer(now);
    if (widget.interactive &&
        _localPointer != null &&
        _animation.isRubbing &&
        _animation.petGlow > .3 &&
        widget.onInteraction != null &&
        (_lastPetSentAt == null || now - _lastPetSentAt! >= _petInterval)) {
      _lastPetSentAt = now;
      widget.onInteraction!(AvoLocalInteraction.pet(AvoPet(
        intensity: _animation.petGlow.clamp(0.0, 1.0).toDouble(),
        x: _localPointer!.x,
        y: _localPointer!.y,
      )));
    }
  }

  @override
  void didUpdateWidget(covariant AvoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final interactivityChanged = oldWidget.interactive != widget.interactive;
    if (interactivityChanged) {
      _clearLocalPointer(notify: false);
      _lastPointerSentAt = null;
      _lastPetSentAt = null;
    }
    _applyRemote(
      previous: oldWidget.remoteInteraction,
      forcePointer: interactivityChanged,
    );
  }

  void _applyRemote({
    RemoteAvoInteraction? previous,
    bool forcePointer = false,
  }) {
    final remote = widget.remoteInteraction;
    final pop = remote?.pop;
    final pet = remote?.pet;
    if (pop != null && pop.eventId != _lastRemotePopId) {
      _lastRemotePopId = pop.eventId;
      _animation.pop();
    }
    if (pet != null && pet.eventId != _lastRemotePetId) {
      _lastRemotePetId = pet.eventId;
      _animation.pet();
    }
    final pointerChanged = !identical(remote?.pointer, previous?.pointer);
    if (pointerChanged) {
      _remotePointer = remote?.pointer;
      _remotePointerUpdatedAt = _remotePointer == null ? null : _now;
    }
    if (!widget.interactive && (pointerChanged || forcePointer)) {
      final updatedAt = _remotePointerUpdatedAt;
      _animation.setPointer(
        updatedAt != null && _now - updatedAt < _pointerTtl
            ? _remotePointer
            : null,
        remote: true,
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _triggerPop() {
    _animation.pop();
    widget.onInteraction?.call(const AvoLocalInteraction.pop());
  }

  void _updatePointer(PointerEvent event) {
    if (!widget.interactive) return;
    final position = event.localPosition;
    if (!(Offset.zero & _size).contains(position)) {
      _clearLocalPointer();
      return;
    }
    final now = _now;
    final previousPosition = _lastPosition;
    final previousTimestamp = _lastPointerEventTimestamp;
    final eventDelta = previousTimestamp == null
        ? Duration.zero
        : event.timeStamp - previousTimestamp;
    final delta = eventDelta > Duration.zero
        ? eventDelta
        : now - (_lastPointerEventAt ?? now);
    final dt = math.max(
      .001,
      delta.inMicroseconds / Duration.microsecondsPerSecond,
    );
    final distance =
        previousPosition == null ? 0.0 : (position - previousPosition).distance;
    final pointer = AvoPointer(
      x: ((position.dx - _size.width / 2) / math.max(1, _size.width / 2))
          .clamp(-1.0, 1.0)
          .toDouble(),
      y: ((position.dy - _size.height / 2) / math.max(1, _size.height / 2))
          .clamp(-1.0, 1.0)
          .toDouble(),
      speed: (distance / math.max(1, _size.shortestSide) / dt / 4)
          .clamp(0.0, 1.0)
          .toDouble(),
      inside: true,
    );
    // Input sampling is independent of outbound throttling: every move reaches
    // the local animation, including previews that have no transport callback.
    _lastPosition = position;
    _lastPointerEventTimestamp = event.timeStamp;
    _lastPointerEventAt = now;
    _localPointer = pointer;
    _pendingPointer = pointer;
    _animation.setPointer(pointer);
    _flushPointer(now);
  }

  void _flushPointer(Duration now) {
    final callback = widget.onInteraction;
    final localPointer = _localPointer;
    if (!widget.interactive || callback == null || localPointer == null) return;
    final lastSentAt = _lastPointerSentAt;
    if (lastSentAt != null && now - lastSentAt < _pointerInterval) return;
    var pointer = _pendingPointer;
    if (pointer == null) {
      if (lastSentAt != null && now - lastSentAt < _pointerHeartbeat) return;
      // A heartbeat keeps a remote pointer alive without replaying old motion.
      pointer = AvoPointer(
        x: localPointer.x,
        y: localPointer.y,
        speed: 0,
        inside: true,
      );
    }
    _pendingPointer = null;
    _lastPointerSentAt = now;
    callback(AvoLocalInteraction.pointer(pointer));
  }

  void _clearLocalPointer({bool notify = true}) {
    final hadPointer = _localPointer != null;
    _localPointer = null;
    _pendingPointer = null;
    _lastPosition = null;
    _lastPointerEventAt = null;
    _lastPointerEventTimestamp = null;
    _animation.setPointer(null);
    if (notify && hadPointer) {
      widget.onInteraction?.call(const AvoLocalInteraction.pointerLeave());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = constraints.constrain(Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 180,
        constraints.hasBoundedHeight ? constraints.maxHeight : 180,
      ));
      Widget child = ClipRect(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: AvoPainter(
              params: widget.params,
              animation: _animation,
              scale: widget.scale,
              repaint: _animation,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      if (widget.interactive) {
        child = MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: _updatePointer,
          onHover: _updatePointer,
          onExit: (_) => _clearLocalPointer(),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _updatePointer(event);
              _triggerPop();
            },
            onPointerMove: _updatePointer,
            onPointerUp: (event) {
              if (event.kind != PointerDeviceKind.mouse) _clearLocalPointer();
            },
            onPointerCancel: (_) => _clearLocalPointer(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Consume the tap so pressing Avo does not also pin its card.
              // The reaction already starts at pointer-down, as on the canvas.
              onTap: () {},
              child: child,
            ),
          ),
        );
      } else {
        child = IgnorePointer(child: child);
      }
      return SizedBox.fromSize(size: _size, child: child);
    });
  }
}
