import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/shared/models/avo_params.dart';

void main() {
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
