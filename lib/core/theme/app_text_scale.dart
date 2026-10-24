import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'font_size_provider.dart';

/// Wrap the navigator and overlays so dialogs and text fields resize as well.
class AppTextScale extends ConsumerWidget {
  const AppTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiplier = fontSizeScales[ref.watch(fontSizeProvider)];
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: multiplier == 1
            ? media.textScaler
            : _MultipliedTextScaler(media.textScaler, multiplier),
      ),
      child: child,
    );
  }
}

/// Preserve nonlinear system scaling rather than converting it to one factor.
class _MultipliedTextScaler extends TextScaler {
  const _MultipliedTextScaler(this.systemScaler, this.multiplier);

  final TextScaler systemScaler;
  final double multiplier;

  @override
  double scale(double fontSize) => systemScaler.scale(fontSize) * multiplier;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _MultipliedTextScaler &&
      other.systemScaler == systemScaler &&
      other.multiplier == multiplier;

  @override
  int get hashCode => Object.hash(systemScaler, multiplier);
}
