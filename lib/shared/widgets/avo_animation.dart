import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/avo_interaction.dart';
import '../models/avo_params.dart';
import 'avo_noise.dart';

/// JavaScript's signed shifts and signed remainder are intentional here.
/// For example guest#0 has only two orbiters in the original implementation.
class AvoPersonality {
  AvoPersonality(AvoParams params) : seed = params.stableSeed;
  final int seed;
  int get _signed => seed.toSigned(32);
  int get lobes => 5 + seed % 4;
  int get orbiters => 6 + (_signed >> 3).remainder(7);
  double get squish => .85 + (_signed >> 6).remainder(30) / 100;
  double get eyeGap => .30 + (_signed >> 9).remainder(14) / 100;
  double get eyeSize => .10 + (_signed >> 12).remainder(8) / 100;
  double get noiseOffset => (seed % 1000) / 10;
}

class AvoParticle {
  AvoParticle({
    required this.heart,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.spin,
    this.life = 1,
  });
  final bool heart;
  double x, y, vx, vy, spin, life;
}

/// All temporal state lives with the widget, never in a disposable painter.
/// Painting is read-only: extra repaints cannot advance time or spawn particles.
class AvoAnimationState extends ChangeNotifier {
  AvoAnimationState({int? randomSeed, int noiseSeed = 12345})
      : _random = AvoRandom(randomSeed ?? math.Random().nextInt(0x7fffffff)),
        noise = AvoNoise(noiseSeed) {
    nextBlink = 1 + _random.nextDouble() * 3;
  }

  final AvoRandom _random;
  final AvoNoise noise;
  final List<AvoParticle> particles = [];
  double elapsed = 0;
  double level = 0;
  double popT = 99;
  double petGlow = 0;
  double hover = 0;
  double blink = 0;
  late double nextBlink;
  double leanX = 0;
  double leanY = 0;
  AvoPointer? pointer;
  bool isRubbing = false;
  AvoPointer? _targetPointer;
  bool _remotePointer = false;
  double _pendingSpeed = 0;

  void setPointer(AvoPointer? value, {bool remote = false}) {
    final next = value?.inside == true ? value!.normalized() : null;
    if (next != null &&
        _targetPointer != null &&
        (next.x != _targetPointer!.x || next.y != _targetPointer!.y)) {
      _pendingSpeed = next.speed;
    }
    _remotePointer = remote;
    _targetPointer = next;
    if (!remote || pointer == null || next == null) pointer = next;
    if (next == null) {
      _pendingSpeed = 0;
      isRubbing = false;
    }
    notifyListeners();
  }

  void pop() {
    popT = 0;
    blink = 0;
    for (var i = 0; i < 6; i++) {
      final angle = i / 6 * math.pi * 2 + _random.nextDouble() * .4;
      final velocity = 1 + _random.nextDouble() * 1.6;
      _spawn(false, math.cos(angle) * 8, math.sin(angle) * 8,
          math.cos(angle) * velocity, math.sin(angle) * velocity);
    }
    notifyListeners();
  }

  void pet() {
    petGlow = 1;
    for (var i = 0; i < 5; i++) {
      _spawn(
          true,
          (_random.nextDouble() - .5) * 40,
          (_random.nextDouble() - .5) * 25,
          (_random.nextDouble() - .5) * 1.2,
          -1.5 - _random.nextDouble());
    }
    notifyListeners();
  }

  void _spawn(bool heart, double x, double y, double vx, double vy) {
    if (particles.length > 40) particles.removeAt(0);
    particles.add(AvoParticle(
        heart: heart,
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        spin: _random.nextDouble() * 6));
  }

  static double _ease(double perFrame, double dt) =>
      1 - math.pow(1 - perFrame, dt * 60).toDouble();

  void advance(
    double dt, {
    required double targetLevel,
    required Size size,
    double scale = .62,
  }) {
    if (!dt.isFinite || dt <= 0) return;
    // Keep the reference's elapsed time after a slow active frame. Exponential
    // easing remains bounded even then; TickerMode pauses reset the ticker.
    elapsed += dt;
    popT += dt;
    final target = targetLevel.isFinite ? targetLevel.clamp(0.0, 1.0) : 0.0;
    // avo/js/audio.js attack/release rates, interpolated between Agora samples.
    level += (target - level) * _ease(target > level ? .35 : .12, dt);
    nextBlink -= dt;
    if (nextBlink <= 0) {
      blink = 1;
      nextBlink = 1.5 + _random.nextDouble() * 3.5;
    }
    blink = math.max(0.0, blink - dt / .11);

    final next = _targetPointer;
    final previous = pointer;
    if (_remotePointer && previous != null && next != null) {
      final ease = _ease(.35, dt);
      pointer = AvoPointer(
          x: previous.x + (next.x - previous.x) * ease,
          y: previous.y + (next.y - previous.y) * ease,
          speed: next.speed,
          inside: next.inside,
          seq: next.seq);
    }
    final bodySize = size.shortestSide * scale;
    final radius = bodySize * .5;
    final point = pointer;
    final position = Offset(
        (point?.x ?? 0) * size.width * .5, (point?.y ?? 0) * size.height * .5);
    final overBody = point != null && position.distance < radius * .95;
    hover += ((overBody ? 1 : 0) - hover) * _ease(8 / 60, dt);
    // Wire speed is fractions of four viewport widths/second; p5 uses pixels
    // per frame. Consume a move once, so stationary hovering never keeps petting.
    final speed = _pendingSpeed * size.shortestSide * 4 / 60;
    _pendingSpeed = 0;
    isRubbing = overBody && speed > 3;
    if (isRubbing) {
      petGlow = math.min(1.0, petGlow + speed * .0035 * dt * 60);
      if (petGlow > .3 && _random.nextDouble() < _ease(.12, dt)) {
        _spawn(true, position.dx * .8, position.dy * .8,
            (_random.nextDouble() - .5) * 1.2, -1.5 - _random.nextDouble());
      }
    }
    petGlow = math.max(0.0, petGlow - dt * .35);
    var targetLean = Offset.zero;
    if (point != null && radius > 0) {
      final distance = position.distance == 0 ? 1.0 : position.distance;
      final pull = math.max(0.0, 1 - distance / (radius * 3.5));
      targetLean = Offset(position.dx / distance * pull * radius * .16,
          position.dy / distance * pull * radius * .12);
    }
    leanX += (targetLean.dx - leanX) * _ease(6 / 60, dt);
    leanY += (targetLean.dy - leanY) * _ease(6 / 60, dt);

    final frameCount = dt * 60;
    final k = bodySize / 100;
    for (var i = particles.length - 1; i >= 0; i--) {
      final particle = particles[i];
      particle.life -= dt * (particle.heart ? .7 : 1.4);
      if (particle.life <= 0) {
        particles.removeAt(i);
        continue;
      }
      // At 60Hz these are the original p5 steps. Fractional steps retain the
      // same speed on high refresh rate displays.
      particle.x += particle.vx * k * frameCount;
      particle.y += particle.vy * k * frameCount;
      particle.vx *= math.pow(.97, frameCount).toDouble();
      if (particle.heart) particle.vy -= dt * 1.2;
      particle.spin += dt * 3;
    }
    notifyListeners();
  }
}
