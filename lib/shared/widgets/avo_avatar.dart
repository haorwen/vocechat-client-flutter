import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/avo_interaction.dart';
import '../models/avo_params.dart';
import 'avo_painter.dart';

/// Native, platform-independent Avo avatar. Animation frames repaint the
/// canvas through a ticker and never rebuild the surrounding widget tree.
class AvoAvatar extends StatefulWidget {
  const AvoAvatar(
      {super.key,
      required this.params,
      this.level = 0,
      this.interactive = false,
      this.onInteraction,
      this.remoteInteraction});
  final AvoParams params;
  final double level;
  final bool interactive;
  final ValueChanged<AvoLocalInteraction>? onInteraction;
  final RemoteAvoInteraction? remoteInteraction;

  @override
  State<AvoAvatar> createState() => _AvoAvatarState();
}

class _AvoAvatarState extends State<AvoAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 100),
  )..addListener(_tick);
  final _animation = AvoAnimationState();
  DateTime? _lastPointerSent;
  Offset? _lastPosition;
  DateTime? _lastPet;
  String? _lastRemotePopId;
  String? _lastRemotePetId;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _applyRemote(widget.remoteInteraction);
  }

  void _ensureAnimating() {
    if (_ticker.isAnimating) return;
    _lastTick = Duration.zero;
    _ticker.forward(from: 0);
  }

  void _tick() {
    final elapsed = _ticker.lastElapsedDuration ?? Duration.zero;
    final dt = math.min(
      .1,
      math.max(
          .0,
          (elapsed - _lastTick).inMicroseconds /
              Duration.microsecondsPerSecond),
    );
    _lastTick = elapsed;
    _animation.elapsed =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    _animation.petGlow = math.max(0, _animation.petGlow - dt / .7);
    _animation.popT = math.max(0, _animation.popT - dt / .5);
    final sent = _lastPointerSent;
    if (_animation.pointer != null &&
        !_animation.hover &&
        sent != null &&
        DateTime.now().difference(sent) > const Duration(milliseconds: 800)) {
      _animation.pointer = null;
    }
    if (!_animation.hover &&
        _animation.pointer == null &&
        _animation.petGlow <= 0 &&
        _animation.popT <= 0) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AvoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyRemote(widget.remoteInteraction);
  }

  void _applyRemote(RemoteAvoInteraction? remote) {
    if (remote == null) {
      return;
    }
    _ensureAnimating();
    final pop = remote.pop;
    final pet = remote.pet;
    if (pop != null && pop.eventId != _lastRemotePopId) {
      _lastRemotePopId = pop.eventId;
      _triggerPop(notify: false);
    }
    if (pet != null && pet.eventId != _lastRemotePetId) {
      _lastRemotePetId = pet.eventId;
      _triggerPet(notify: false);
    }
    _animation.pointer = remote.pointer;
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    super.dispose();
  }

  void _triggerPop({required bool notify}) {
    _animation.popT = 1;
    _ensureAnimating();
    if (notify) widget.onInteraction?.call(const AvoLocalInteraction.pop());
  }

  void _triggerPet({required bool notify}) {
    _animation.petGlow = 1;
    _ensureAnimating();
    if (notify) {
      widget.onInteraction?.call(
        const AvoLocalInteraction.pet(AvoPet(intensity: 1, x: 0, y: 0)),
      );
    }
  }

  void _sendPointer(PointerEvent event, Size size, {required bool inside}) {
    if (!widget.interactive || widget.onInteraction == null) return;
    final now = DateTime.now();
    final position = event.localPosition;
    final center = Offset(size.width / 2, size.height / 2);
    final x = ((position.dx - center.dx) / math.max(1, size.width / 2))
        .clamp(-1.0, 1.0)
        .toDouble();
    final y = ((position.dy - center.dy) / math.max(1, size.height / 2))
        .clamp(-1.0, 1.0)
        .toDouble();
    final previous = _lastPosition;
    final elapsed = _lastPointerSent == null
        ? .05
        : math.max(
            .001, now.difference(_lastPointerSent!).inMicroseconds / 1000000);
    final distance = previous == null ? 0 : (position - previous).distance;
    final speed = (distance /
            math.max(1, math.min(size.width, size.height)) /
            elapsed /
            4)
        .clamp(0.0, 1.0)
        .toDouble();
    if (_lastPointerSent != null &&
        now.difference(_lastPointerSent!) < const Duration(milliseconds: 50) &&
        (position - (_lastPosition ?? position)).distance < 2) {
      return;
    }
    final pointer = AvoPointer(x: x, y: y, speed: speed, inside: inside);
    _lastPointerSent = now;
    _lastPosition = position;
    _animation.pointer = pointer;
    _ensureAnimating();
    widget.onInteraction!(AvoLocalInteraction.pointer(pointer));
    if (speed > .55 &&
        (_lastPet == null ||
            now.difference(_lastPet!) >= const Duration(milliseconds: 250))) {
      _lastPet = now;
      _triggerPet(notify: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      Widget child = CustomPaint(
        painter: AvoPainter(
          params: widget.params,
          level: widget.level.clamp(0, 1).toDouble(),
          animation: _animation,
          repaint: _ticker,
        ),
        child: const SizedBox.expand(),
      );
      if (widget.interactive) {
        child = MouseRegion(
          onEnter: (e) {
            _animation.hover = true;
            _sendPointer(e, size, inside: true);
          },
          onHover: (e) => _sendPointer(e, size, inside: true),
          onExit: (e) {
            _animation.hover = false;
            _animation.pointer = null;
            _ensureAnimating();
            widget.onInteraction
                ?.call(const AvoLocalInteraction.pointerLeave());
          },
          child: GestureDetector(
              onTap: () => _triggerPop(notify: true), child: child),
        );
      }
      return child;
    });
  }
}
