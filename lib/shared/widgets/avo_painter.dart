import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/avo_interaction.dart';
import '../models/avo_params.dart';

/// Mutable values owned by [AvoAvatar]. The ticker repaints the painter
/// directly, so animation frames do not rebuild the surrounding widget tree.
class AvoAnimationState {
  double elapsed = 0;
  double petGlow = 0;
  double popT = 0;
  AvoPointer? pointer;
  bool hover = false;
}

class AvoPainter extends CustomPainter {
  AvoPainter({
    required this.params,
    required this.level,
    required this.animation,
    super.repaint,
  });
  final AvoParams params;
  final double level;
  final AvoAnimationState animation;

  AvoPointer? get pointer => animation.pointer;
  double get pointerSpeed => animation.pointer?.speed ?? 0;
  bool get hover => animation.hover;
  double get petGlow => animation.petGlow;
  double get popT => animation.popT;
  double get elapsed => animation.elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .34;
    final seed = math.Random(params.stableSeed);
    final pulse =
        1 + (math.sin(elapsed * 3.2) * .035 + level * .10) * params.energy;
    final hue = params.hue.toDouble();
    final color = HSVColor.fromAHSV(1, hue, .62, .98).toColor();
    final shadow = Paint()..color = Colors.black.withValues(alpha: .12);
    canvas.drawCircle(
        center.translate(0, radius * .12), radius * pulse * 1.04, shadow);

    switch (params.style) {
      case 'ring':
        _drawRing(canvas, center, radius, color, seed);
      case 'wave':
        _drawWave(canvas, center, radius, color);
      default:
        _drawBlob(canvas, center, radius, color, seed);
    }
    _drawFace(canvas, center, radius, color);
    _drawParticles(canvas, center, radius, color, seed);
  }

  void _drawBlob(
      Canvas canvas, Offset c, double r, Color color, math.Random random) {
    final path = Path();
    final points = 12;
    for (var i = 0; i <= points; i++) {
      final angle = i / points * math.pi * 2;
      final wobble = 1 +
          (random.nextDouble() - .5) * .14 +
          math.sin(elapsed * 2 + angle * 3) * .025;
      final p = c + Offset(math.cos(angle), math.sin(angle)) * r * wobble;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawRing(
      Canvas canvas, Offset c, double r, Color color, math.Random random) {
    canvas.drawCircle(c, r * .77, Paint()..color = color);
    final orbitPaint = Paint()..color = color.withValues(alpha: .72);
    for (var i = 0; i < 8; i++) {
      final angle = elapsed * (.65 + i * .025) + i * math.pi / 4;
      final orbit = r * (.91 + random.nextDouble() * .12);
      canvas.drawCircle(c + Offset(math.cos(angle), math.sin(angle)) * orbit,
          r * (.07 + level * .025), orbitPaint);
    }
  }

  void _drawWave(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(c, r * .72, Paint()..color = color);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .055
      ..color = color.withValues(alpha: .6);
    for (var i = 1; i <= 3; i++) {
      final wave = (elapsed * .18 + i * .25) % 1;
      canvas.drawCircle(c, r * (.78 + wave * .55),
          paint..color = color.withValues(alpha: .5 * (1 - wave)));
    }
  }

  void _drawFace(Canvas canvas, Offset c, double r, Color color) {
    final look = pointer?.normalized() ??
        const AvoPointer(x: 0, y: 0, speed: 0, inside: false);
    final eyeGap = r * (.30 + (params.stableSeed % 5) * .018);
    final eyeY = c.dy - r * .12;
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()
      ..color = HSVColor.fromAHSV(1, params.hue.toDouble(), .55, .35).toColor();
    for (final x in [c.dx - eyeGap, c.dx + eyeGap]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, eyeY), width: r * .30, height: r * .38),
          eyePaint);
      final pupil = Offset(x + look.x * r * .09, eyeY + look.y * r * .09);
      canvas.drawCircle(pupil, r * .095, pupilPaint);
    }
    final mouth = Paint()
      ..color = pupilPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .045
      ..strokeCap = StrokeCap.round;
    final smile = (popT > 0 ? .18 : 0) + petGlow * .05;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(c.dx, c.dy + r * .18),
            width: r * .55,
            height: r * (.26 + smile)),
        0,
        math.pi,
        false,
        mouth);
    if (petGlow > 0) {
      canvas.drawCircle(
          c,
          r * 1.06,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * .06
            ..color = Colors.white.withValues(alpha: petGlow * .55));
    }
  }

  void _drawParticles(
      Canvas canvas, Offset c, double r, Color color, math.Random random) {
    final intensity = math.max(petGlow, popT);
    if (intensity <= 0) {
      return;
    }
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: intensity.clamp(0, 1));
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 + params.stableSeed % 10;
      final distance = r * (1.15 + (1 - intensity) * .3);
      final p = c + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawRect(
          Rect.fromCenter(center: p, width: r * .06, height: r * .16), paint);
    }
  }

  @override
  bool shouldRepaint(covariant AvoPainter oldDelegate) =>
      oldDelegate.params != params ||
      oldDelegate.level != level ||
      oldDelegate.pointer != pointer ||
      oldDelegate.pointerSpeed != pointerSpeed ||
      oldDelegate.hover != hover ||
      oldDelegate.petGlow != petGlow ||
      oldDelegate.popT != popT ||
      oldDelegate.elapsed != elapsed;
}
