import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/shared/models/avo_interaction.dart';
import 'package:vocechat_client/shared/models/avo_params.dart';
import 'package:vocechat_client/shared/widgets/avo_animation.dart';
import 'package:vocechat_client/shared/widgets/avo_noise.dart';
import 'package:vocechat_client/shared/widgets/avo_painter.dart';

// These expected values and PNGs execute the actual avo/js/avo.js in p5 1.9.4,
// not a duplicate Dart implementation. Regenerate via tool/avo_reference.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
          File('test/shared/fixtures/avo_reference.json').readAsStringSync())
      as Map<String, dynamic>;

  test('personality matches JavaScript for signed hashes, Unicode and variants',
      () {
    for (final raw in fixture['personalities'] as List) {
      final value = raw as Map<String, dynamic>;
      final personality = AvoPersonality(AvoParams.defaults.copyWith(
          name: value['name'] as String, variant: value['variant'] as int));
      expect(personality.seed, value['seed']);
      expect(personality.lobes, value['lobes']);
      expect(personality.orbiters, value['orbiters']);
      expect(personality.squish,
          closeTo((value['squish'] as num).toDouble(), 1e-12));
      expect(personality.eyeGap,
          closeTo((value['eyeGap'] as num).toDouble(), 1e-12));
      expect(personality.eyeSize,
          closeTo((value['eyeSize'] as num).toDouble(), 1e-12));
      expect(personality.noiseOffset,
          closeTo((value['noiseOff'] as num).toDouble(), 1e-12));
    }
  });

  test('continuous noise matches original p5 samples', () {
    final values = fixture['noise'] as Map<String, dynamic>;
    final noise = AvoNoise(12345);
    for (final sample in values['samples'] as List) {
      final xyz = (sample['input'] as List).cast<num>();
      expect(
          noise.sample(xyz[0].toDouble(), xyz[1].toDouble(), xyz[2].toDouble()),
          closeTo((sample['value'] as num).toDouble(), 1e-12));
    }
  });

  for (final raw in fixture['scenes'] as List) {
    final scene = raw as Map<String, dynamic>;
    test('matches original p5 ${scene['id']} rendering', () async {
      final state = _state(scene);
      final painter = AvoPainter(
          params: AvoParams.fromJson(scene['params'] as Map<String, dynamic>),
          animation: state);
      final size = Size((scene['width'] as num).toDouble(),
          (scene['height'] as num).toDouble());
      final actual = await _render(painter, size);
      final referenceBytes =
          File('test/shared/fixtures/avo_reference/${scene['id']}.png')
              .readAsBytesSync();
      final codec = await ui.instantiateImageCodec(referenceBytes);
      final reference = (await codec.getNextFrame()).image;
      final difference = await _difference(actual, reference);
      // Skia versions differ along antialiased curve edges. Average error
      // and large-error coverage constrain geometry AND color independently.
      expect(difference.mean, lessThan(.5),
          reason: '${scene['id']}: mean channel error ${difference.mean}');
      expect(difference.outliers, lessThan(.001),
          reason:
              '${scene['id']}: pixels differing >24/255: ${difference.outliers}');
      if (const bool.fromEnvironment('AVO_EXPORT')) {
        final directory = Directory('build/avo_comparison')
          ..createSync(recursive: true);
        final png = await actual.toByteData(format: ui.ImageByteFormat.png);
        File('${directory.path}/${scene['id']}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      }
      // Repainting the same instance cannot advance pop, blink or particles.
      final again = await _render(painter, size);
      expect((await _difference(actual, again)).mean, 0);
      again.dispose();
      actual.dispose();
      reference.dispose();
      codec.dispose();
      state.dispose();
    });
  }

  test('pop starts surprised, settles in .75s and leaves no permanent startle',
      () {
    final state = AvoAnimationState(randomSeed: 12345);
    expect(state.popT, 99);
    state.pop();
    expect(state.popT, 0);
    expect(state.particles.length, 6);
    for (var i = 0; i < 60; i++) {
      state.advance(1 / 60, targetLevel: 0, size: const Size(256, 256));
    }
    expect(state.popT, closeTo(1, 1e-10));
    expect(state.particles, isEmpty);
    state.pet();
    expect(state.petGlow, 1);
    expect(state.particles.length, 5);
    for (var i = 0; i < 60; i++) {
      state.advance(1 / 60, targetLevel: 0, size: const Size(256, 256));
    }
    expect(state.petGlow, closeTo(.65, 1e-10));
    state.dispose();
  });

  test('slow active frames preserve reaction time and retire old particles',
      () {
    final state = AvoAnimationState(randomSeed: 12345)..pop();
    state.advance(.5, targetLevel: 0, size: const Size(256, 256));
    expect(state.elapsed, .5);
    expect(state.popT, .5);
    state.advance(.5, targetLevel: 0, size: const Size(256, 256));
    expect(state.elapsed, 1);
    expect(state.popT, 1);
    expect(state.particles, isEmpty);
    state.dispose();
  });

  test('a 60Hz state step matches original JS reaction and particle physics',
      () {
    final transition = fixture['stateTransition'] as Map<String, dynamic>;
    final expected = transition['stateAfter'] as Map<String, dynamic>;
    final state = AvoAnimationState(randomSeed: 12345)
      ..pet()
      ..pop();
    state.level = .65;
    state.setPointer(const AvoPointer(x: 0, y: 0, speed: 0, inside: true));
    state.setPointer(
        const AvoPointer(x: 35 / 128, y: -18 / 128, speed: 1, inside: true));
    state.advance(1 / 60, targetLevel: .65, size: const Size(256, 256));
    final values = {
      'blink': state.blink,
      'nextBlink': state.nextBlink,
      'popT': state.popT,
      'hover': state.hover,
      'petGlow': state.petGlow,
      'leanX': state.leanX,
      'leanY': state.leanY
    };
    for (final entry in values.entries) {
      expect(
          entry.value, closeTo((expected[entry.key] as num).toDouble(), 1e-10),
          reason: entry.key);
    }
    final particles = expected['particles'] as List;
    expect(state.particles.length, particles.length);
    for (var i = 0; i < particles.length; i++) {
      final particle = state.particles[i];
      final actual = {
        'x': particle.x,
        'y': particle.y,
        'vx': particle.vx,
        'vy': particle.vy,
        'spin': particle.spin,
        'life': particle.life
      };
      for (final entry in actual.entries) {
        expect(entry.value,
            closeTo((particles[i][entry.key] as num).toDouble(), 1e-10),
            reason: 'particle $i ${entry.key}');
      }
    }
    state.dispose();
  });

  test('60Hz and 120Hz share breathing, smoothing and event durations', () {
    final slow = AvoAnimationState(randomSeed: 12345)
      ..pop()
      ..pet();
    final fast = AvoAnimationState(randomSeed: 12345)
      ..pop()
      ..pet();
    const pointer = AvoPointer(x: .3, y: -.2, speed: 0, inside: true);
    slow.setPointer(pointer);
    fast.setPointer(pointer);
    for (var i = 0; i < 30; i++) {
      slow.advance(1 / 60, targetLevel: .7, size: const Size(256, 256));
    }
    for (var i = 0; i < 60; i++) {
      fast.advance(1 / 120, targetLevel: .7, size: const Size(256, 256));
    }
    expect(fast.elapsed, closeTo(slow.elapsed, 1e-10));
    expect(fast.level, closeTo(slow.level, 1e-10));
    expect(fast.hover, closeTo(slow.hover, 1e-10));
    expect(fast.leanX, closeTo(slow.leanX, 1e-10));
    expect(fast.petGlow, closeTo(slow.petGlow, 1e-10));
    slow.dispose();
    fast.dispose();
  });
}

AvoAnimationState _state(Map<String, dynamic> scene) {
  final state = AvoAnimationState(
      randomSeed: scene['randomSeed'] as int,
      noiseSeed: scene['noiseSeed'] as int);
  final after = scene['stateAfter'] as Map<String, dynamic>;
  final input = scene['input'] as Map<String, dynamic>;
  state.elapsed = (input['t'] as num).toDouble();
  state.level = (input['level'] as num).toDouble();
  state.popT = (after['popT'] as num).toDouble();
  state.blink = (after['blink'] as num).toDouble();
  state.nextBlink = (after['nextBlink'] as num).toDouble();
  state.hover = (after['hover'] as num).toDouble();
  state.petGlow = (after['petGlow'] as num).toDouble();
  state.leanX = (after['leanX'] as num).toDouble();
  state.leanY = (after['leanY'] as num).toDouble();
  final pointer = input['pointer'] as Map<String, dynamic>?;
  if (pointer != null) {
    state.pointer = AvoPointer(
        x: (pointer['x'] as num) / (scene['width'] as num) * 2,
        y: (pointer['y'] as num) / (scene['height'] as num) * 2,
        speed: 0,
        inside: true);
  }
  for (final particle in after['particles'] as List) {
    state.particles.add(AvoParticle(
        heart: particle['type'] == 'heart',
        x: (particle['x'] as num).toDouble(),
        y: (particle['y'] as num).toDouble(),
        vx: (particle['vx'] as num).toDouble(),
        vy: (particle['vy'] as num).toDouble(),
        spin: (particle['spin'] as num).toDouble(),
        life: (particle['life'] as num).toDouble()));
  }
  return state;
}

Future<ui.Image> _render(AvoPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  return image;
}

Future<({double mean, double outliers})> _difference(
    ui.Image a, ui.Image b) async {
  final bytesA =
      (await a.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
          .buffer
          .asUint8List();
  final bytesB =
      (await b.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
          .buffer
          .asUint8List();
  double channel(Uint8List data, int index, int c) {
    final alpha = data[index + 3] / 255;
    const background = [16, 18, 20];
    return data[index + c] * alpha + background[c] * (1 - alpha);
  }

  var sum = 0.0;
  var outliers = 0;
  for (var i = 0; i < bytesA.length; i += 4) {
    var maximum = 0.0;
    for (var c = 0; c < 3; c++) {
      final delta = (channel(bytesA, i, c) - channel(bytesB, i, c)).abs();
      sum += delta;
      maximum = math.max(maximum, delta);
    }
    if (maximum > 24) outliers++;
  }
  return (
    mean: sum / (a.width * a.height * 3),
    outliers: outliers / (a.width * a.height)
  );
}
