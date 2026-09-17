import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/shared/models/avo_params.dart';

void main() {
  test('name generation has stable identities for Latin, Chinese and emoji',
      () {
    final fixtures = [
      ('Alice', 752715143, 343, 'wave', .65),
      ('张三', 603732418, 13, 'wave', .1),
      ('😀', -885930824, 193, 'wave', .1),
    ];
    for (final (name, variant, hue, style, energy) in fixtures) {
      final params = AvoParams.fromName(name);
      expect(params.toJson(), {
        'name': name,
        'variant': variant,
        'hue': hue,
        'style': style,
        'energy': energy,
      });
      expect(AvoParams.fromName('  $name  '), params);
      expect(AvoParams.fromJson(params.toJson()), params);
    }
    expect(AvoParams.fromName('  '), AvoParams.fromName('guest'));
  });

  test('full names seed shapes before the protocol name length limit', () {
    final prefix = List.filled(20, '😀').join();
    final first = AvoParams.fromName('${prefix}Alice');
    final second = AvoParams.fromName('${prefix}Bob');
    expect(first.name.runes, hasLength(20));
    expect(first.name, second.name);
    expect(first.stableSeed, isNot(second.stableSeed));
    expect(AvoParams.fromJson(first.toJson()).stableSeed, first.stableSeed);
  });

  test('generated identities vary appearance and remain protocol compatible',
      () {
    final params = List.generate(200, (i) => AvoParams.fromName('用户$i'));
    expect(params.map((p) => p.stableSeed).toSet(), hasLength(200));
    expect(params.map((p) => p.hue).toSet(), hasLength(8));
    expect(params.map((p) => p.style).toSet(), hasLength(3));
    expect(params.map((p) => p.energy).toSet(), hasLength(19));
    for (final value in params) {
      expect(AvoParams.fromJson(value.toJson()), value);
    }
  });

  test('normalizes malformed values to protocol-safe defaults', () {
    final params = AvoParams.normalize({
      'name': '  ',
      'variant': 'not a number',
      'hue': 999,
      'style': 'unknown',
      'energy': double.nan,
    });

    expect(params, AvoParams.defaults);
  });

  test('clamps and quantizes energy and truncates by Unicode characters', () {
    final params = AvoParams.normalize({
      'name': '😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀',
      'energy': .637,
      'hue': 343,
      'style': 'wave',
    });

    expect(params.name.runes, hasLength(20));
    expect(params.energy, .65);
    expect(params.hue, 343);
    expect(params.style, 'wave');
  });

  test('JSON round-trip preserves normalized values', () {
    const json = <String, dynamic>{
      'name': 'Han',
      'variant': 2,
      'hue': 214,
      'style': 'ring',
      'energy': .75,
    };

    expect(AvoParams.fromJson(json).toJson(), json);
  });

  test('copyWith preserves the complete serializable shape', () {
    final params = AvoParams.defaults.copyWith(
      name: 'Ada',
      variant: 2,
      hue: 13,
      style: 'ring',
      energy: 1,
    );

    expect(params.toJson(), {
      'name': 'Ada',
      'variant': 2,
      'hue': 13,
      'style': 'ring',
      'energy': 1.0,
    });
    expect(params.stableSeed, params.stableSeed);
  });
}
