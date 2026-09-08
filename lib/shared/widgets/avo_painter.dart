import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/avo_params.dart';
import 'avo_animation.dart';

/// Native Canvas port of avo/js/avo.js Creature drawing, in the same units.
/// No state is advanced here: rebuilding or painting twice is harmless.
class AvoPainter extends CustomPainter {
  AvoPainter(
      {required this.params,
      required this.animation,
      this.scale = .62,
      super.repaint})
      : personality = AvoPersonality(params);

  final AvoParams params;
  final AvoAnimationState animation;
  final double scale;
  final AvoPersonality personality;
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  double get _t => animation.elapsed;
  double get _level => animation.level;
  double get _pop => math.max(0.0, 1 - animation.popT * 1.35);
  Color _hsb(double hue, double saturation, double brightness,
          [double alpha = 1]) =>
      HSVColor.fromAHSV(alpha.clamp(0.0, 1.0), hue % 360, saturation / 100,
              brightness / 100)
          .toColor();

  void _circle(
      Canvas canvas, double x, double y, double diameter, Color color) {
    canvas.drawCircle(Offset(x, y), diameter / 2, _fill..color = color);
  }

  void _ellipse(
      Canvas canvas, double x, double y, double w, double h, Color color) {
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        _fill..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    final bodySize = size.shortestSide * scale;
    final r0 = bodySize * .5;
    if (r0 <= 0) return;
    final breathe = math.sin(_t * 1.4 + personality.noiseOffset) * .02;
    final excite = animation.hover * .02 + animation.petGlow * .07;
    final bodyScale = 1 + breathe + _level * .16 * params.energy + excite;
    final jelly = _pop * math.sin(animation.popT * 24) * .055;
    canvas.save();
    canvas.translate(size.width / 2 + animation.leanX,
        size.height / 2 + animation.leanY - _pop * r0 * .07);
    canvas.rotate(animation.leanX / r0 * .14 +
        _pop * math.sin(animation.popT * 28) * .025);
    canvas.scale(1 + jelly, 1 - jelly * .85);
    final lively =
        math.min(1.0, _level + animation.hover * .12 + animation.petGlow * .5);
    final diameter = bodySize * bodyScale;
    switch (params.style) {
      case 'ring':
        _drawRing(canvas, diameter, lively);
      case 'wave':
        _drawWave(canvas, diameter, lively);
      default:
        _drawBlob(canvas, diameter, lively);
    }
    _drawFace(canvas, diameter, size);
    _drawParticles(canvas, bodySize);
    canvas.restore();
  }

  /// p5 curveVertex uses Catmull-Rom control points (tightness=0). The first
  /// and last vertices are controls; endShape(CLOSE) closes the remaining gap.
  static Path curvePath(List<Offset> points) {
    final path = Path();
    if (points.length < 4) return path;
    path.moveTo(points[1].dx, points[1].dy);
    // Both public endShape and Renderer2D append the first vertex in p5 1.9.4.
    final closed = [...points, points.first, points.first];
    for (var i = 1; i + 2 < closed.length; i++) {
      final a = closed[i - 1];
      final b = closed[i];
      final c = closed[i + 1];
      final d = closed[i + 2];
      final control1 = b + (c - a) / 6;
      final control2 = c - (d - b) / 6;
      path.cubicTo(
          control1.dx, control1.dy, control2.dx, control2.dy, c.dx, c.dy);
    }
    return path
      ..lineTo(points.first.dx, points.first.dy)
      ..close();
  }

  void _drawBlob(Canvas canvas, double size, double level) {
    final r = size * .5;
    final wobble = (.06 + level * .22 * params.energy + _pop * .1) * r;
    final hue = params.hue.toDouble();
    if (level > .04) {
      _circle(canvas, 0, 0, size * (1.25 + level * .35),
          _hsb(hue, 70, 90, .06 + level * .12));
    }
    for (var layer = 2; layer >= 0; layer--) {
      final lr = r * (1 + layer * .10);
      final vertices = <Offset>[];
      for (var a = 0.0; a < math.pi * 2; a += .22) {
        final n = animation.noise.sample(
            math.cos(a) * .8 + personality.noiseOffset,
            math.sin(a) * .8 + personality.noiseOffset,
            _t * (.35 + level * 1.2) + layer * 3);
        final rr = lr + (n - .5) * 2 * wobble;
        vertices.add(
            Offset(math.cos(a) * rr * personality.squish, math.sin(a) * rr));
      }
      canvas.drawPath(
          curvePath(vertices),
          _fill
            ..color = _hsb(hue, 62 - layer * 8.0, layer == 0 ? 78 : 90,
                layer == 0 ? 1 : .16 - layer * .04));
    }
  }

  void _drawRing(Canvas canvas, double size, double level) {
    final r = size * .5;
    final hue = params.hue.toDouble();
    _circle(canvas, 0, 0, r * 1.1, _hsb(hue, 55, 75));
    _circle(canvas, 0, 0, r * 1.28, _hsb(hue, 40, 92, .35));
    final speed = .5 + level * 2.4 * params.energy + _pop * 1.5;
    for (var i = 0; i < personality.orbiters; i++) {
      final fraction = i / personality.orbiters;
      final angle = _t * speed * (.6 + fraction * .7) +
          fraction * math.pi * 2 +
          personality.noiseOffset;
      final orbitR = r * (.75 + fraction * .45) + level * r * .3;
      final d = r * (.10 + fraction * .10) * (1 + level * .8);
      final satelliteHue = (hue + (fraction - .5) * 24 + 360) % 360;
      _circle(canvas, math.cos(angle) * orbitR, math.sin(angle) * orbitR * .92,
          d, _hsb(satelliteHue, 70, 95, .85));
      _circle(
          canvas,
          math.cos(angle - .25) * orbitR,
          math.sin(angle - .25) * orbitR * .92,
          d * .6,
          _hsb(satelliteHue, 70, 95, .25));
    }
  }

  void _drawWave(Canvas canvas, double size, double level) {
    final r = size * .5;
    final hue = params.hue.toDouble();
    _circle(canvas, 0, 0, r * 1.15, _hsb(hue, 55, 75));
    for (var i = 0; i < 4; i++) {
      final phase = (_t * (.5 + level * 1.6) + i / 4) % 1;
      final rr = r * (.6 + phase * (.9 + level * .9 + _pop * .4));
      canvas.drawCircle(
          Offset.zero,
          rr,
          _stroke
            ..color = _hsb(hue, 65, 95, (1 - phase) * (.16 + level * .55))
            ..strokeWidth = 2 + (1 - phase) * 3 + level * 2);
    }
  }

  void _arc(Canvas canvas, double x, double y, double w, double h, double start,
      double end, Color color, double strokeWidth) {
    canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        start,
        end - start,
        false,
        _stroke
          ..color = color
          ..strokeWidth = strokeWidth);
  }

  void _drawFace(Canvas canvas, double size, Size viewport) {
    final r = size * .5;
    final startle = math.max(0.0, 1 - animation.popT / .55);
    final happy = startle > .25 ? 0.0 : animation.petGlow;
    final curious = startle > .25
        ? 0.0
        : math.max(0.0, animation.hover * (1 - happy * 1.4));
    var lookX = 0.0;
    var lookY = 0.0;
    final pointer = animation.pointer;
    if (pointer != null) {
      final dx = pointer.x * viewport.width / 2;
      final dy = pointer.y * viewport.height / 2;
      final distance = math.sqrt(dx * dx + dy * dy);
      final m = distance == 0 ? 1.0 : distance;
      final k = math.min(1.0, m / (r * 2));
      lookX = dx / m * k * r * .09;
      lookY = dy / m * k * r * .09;
    } else {
      lookX = math.cos(_t * .6 + personality.noiseOffset) * r * .04;
      lookY = math.sin(_t * .45 + personality.noiseOffset) * r * .03;
    }
    lookX *= 1 + curious * .4;
    lookY *= 1 + curious * .4;
    lookX *= 1 - startle * .75;
    lookY =
        lookY * (1 - startle * .75) - startle * r * .03 - curious * r * .018;
    final eyeY = -r * .08 + lookY;
    final gap = r * personality.eyeGap;
    final eyeR =
        r * personality.eyeSize * 2 * (1 + startle * .16 + curious * .08);
    final openness =
        math.max(1 - animation.blink, .85 + startle * .15 + curious * .06);
    final pupilK = .45 * (1 - startle * .28 + curious * .14);
    if (happy > .35) {
      final hEye = eyeR * .8;
      for (final side in [-1, 1]) {
        _arc(canvas, side * gap + lookX, eyeY + hEye * .15, hEye, hEye * .9,
            math.pi, math.pi * 2, _hsb(0, 0, 100, .95), hEye * .22);
      }
    } else {
      for (final side in [-1, 1]) {
        final ex = side * gap + lookX;
        _ellipse(canvas, ex, eyeY, eyeR, eyeR * math.max(.08, openness),
            _hsb(0, 0, 100, .95));
        if (openness > .35) {
          _ellipse(canvas, ex + lookX * .6, eyeY + lookY * .4, eyeR * pupilK,
              eyeR * pupilK * openness, _hsb(0, 0, 12));
        }
      }
    }
    if (happy > .2) {
      for (final side in [-1, 1]) {
        _ellipse(canvas, side * gap * 1.5 + lookX, eyeY + eyeR * .9, eyeR * .9,
            eyeR * .5, _hsb(13, 55, 100, (happy - .2) * .5));
      }
    }
    final mouthY = r * .22;
    if (startle > .35) {
      final ow = r * (.07 + startle * .05);
      _ellipse(canvas, lookX * .5, mouthY + lookY * .3 + r * .01, ow, ow * 1.1,
          _hsb(0, 0, 10, .85));
    } else if (startle > .08) {
      _ellipse(canvas, lookX * .5, mouthY + lookY * .3, r * .22 * (1 - startle),
          r * .025, _hsb(0, 0, 10, .75));
    } else if (happy > .35 && _level < .12) {
      final mw = r * (.24 + happy * .14);
      _arc(canvas, lookX * .5, mouthY + lookY * .3 - mw * .15, mw, mw * .8, .25,
          math.pi - .25, _hsb(0, 0, 10, .85), r * .045);
    } else if (curious > .2 && _level < .1) {
      _ellipse(
          canvas,
          lookX * .5,
          mouthY + lookY * .3,
          r * (.14 + curious * .04),
          r * (.022 + curious * .014),
          _hsb(0, 0, 10, .8));
    } else {
      final mw = r * .30 * (1 + _level * .25);
      final mh = r * (.035 + _level * .30 * params.energy);
      _ellipse(
          canvas, lookX * .5, mouthY + lookY * .3, mw, mh, _hsb(0, 0, 10, .85));
      if (mh > r * .09) {
        _ellipse(canvas, lookX * .5, mouthY + mh * .22, mw * .5, mh * .4,
            _hsb(0, 70, 90, .9));
      }
    }
  }

  void _drawParticles(Canvas canvas, double size) {
    final k = size / 100;
    for (final particle in animation.particles.reversed) {
      final x = particle.x;
      final y = particle.y;
      if (particle.heart) {
        final s = (5 + (1 - particle.life) * 4) * k;
        final heartY = y + math.sin(particle.spin) * 1.5;
        final heart = Path()
          ..moveTo(x, heartY + s * .35)
          ..cubicTo(x - s, heartY - s * .35, x - s * .45, heartY - s, x,
              heartY - s * .3)
          ..cubicTo(x + s * .45, heartY - s, x + s, heartY - s * .35, x,
              heartY + s * .35)
          ..close();
        canvas.drawPath(
            heart, _fill..color = _hsb(343, 65, 100, particle.life * .9));
      } else {
        final s = (2 + particle.life * 3) * k;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(particle.spin);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: s, height: s),
                Radius.circular(s * .3)),
            _fill..color = _hsb(params.hue.toDouble(), 45, 100, particle.life));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant AvoPainter oldDelegate) =>
      oldDelegate.params != params ||
      oldDelegate.animation != animation ||
      oldDelegate.scale != scale;
}
