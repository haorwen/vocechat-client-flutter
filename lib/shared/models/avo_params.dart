import 'dart:math' as math;

/// Stable, server-compatible configuration for an Avo avatar.
class AvoParams {
  const AvoParams({
    required this.name,
    required this.variant,
    required this.hue,
    required this.style,
    required this.energy,
  });

  static const defaultHue = 193;
  static const defaultStyle = 'blob';
  static const allowedHues = <int>[193, 214, 235, 172, 151, 43, 13, 343];
  static const allowedStyles = <String>{'blob', 'ring', 'wave'};

  final String name;
  final int variant;
  final int hue;
  final String style;
  final double energy;

  static const defaults = AvoParams(
    name: 'guest',
    variant: 0,
    hue: defaultHue,
    style: defaultStyle,
    energy: 0.6,
  );

  /// Sanitizes both API and imported JSON. Malformed values never prevent a
  /// user directory or login from loading.
  factory AvoParams.normalize(Map<String, dynamic>? json,
      {String? fallbackName}) {
    final rawName = json?['name']?.toString().trim();
    final name = _runes(
        rawName?.isNotEmpty == true ? rawName! : (fallbackName ?? 'guest'));
    final hueValue = _number(json?['hue'])?.toInt();
    final styleValue = json?['style']?.toString();
    final rawEnergy = _number(json?['energy'])?.toDouble();
    final energyValue =
        rawEnergy != null && rawEnergy.isFinite ? rawEnergy : null;
    final variantValue = _number(json?['variant'])?.toInt() ?? 0;
    return AvoParams(
      name: name.isEmpty ? 'guest' : name,
      variant: variantValue,
      hue: allowedHues.contains(hueValue) ? hueValue! : defaultHue,
      style: allowedStyles.contains(styleValue) ? styleValue! : defaultStyle,
      energy: _stepEnergy(energyValue ?? defaults.energy),
    );
  }

  factory AvoParams.fromJson(Map<String, dynamic> json) =>
      AvoParams.normalize(json);

  Map<String, dynamic> toJson() => {
        'name': name,
        'variant': variant,
        'hue': hue,
        'style': style,
        'energy': energy,
      };

  AvoParams copyWith(
          {String? name,
          int? variant,
          int? hue,
          String? style,
          double? energy}) =>
      AvoParams.normalize({
        ...toJson(),
        if (name != null) 'name': name,
        if (variant != null) 'variant': variant,
        if (hue != null) 'hue': hue,
        if (style != null) 'style': style,
        if (energy != null) 'energy': energy,
      });

  /// Deterministic seed used by the painter; never use dart:math Random()
  /// without a seed for avatar appearance.
  int get stableSeed {
    var hash = 0x811c9dc5;
    for (final codeUnit in '$name#$variant'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static num? _number(Object? value) => value is num ? value : null;

  static String _runes(String value) =>
      String.fromCharCodes(value.runes.take(20));

  static double _stepEnergy(double value) {
    final clamped = value.clamp(0.1, 1.0).toDouble();
    final step = math.max(2, (clamped / 0.05).round());
    return (step / 20.0).clamp(0.1, 1.0).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is AvoParams &&
      other.name == name &&
      other.variant == variant &&
      other.hue == hue &&
      other.style == style &&
      other.energy == energy;

  @override
  int get hashCode => Object.hash(name, variant, hue, style, energy);
}
