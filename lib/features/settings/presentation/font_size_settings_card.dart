import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/font_size_provider.dart';
import '../../../l10n/generated/app_localizations.dart';

class FontSizeSettingsCard extends ConsumerWidget {
  const FontSizeSettingsCard({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(fontSizeProvider.notifier).save();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppL10n.of(context).appearanceFontSizeSaveFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final colors = Theme.of(context).colorScheme;
    final step = ref.watch(fontSizeProvider);
    final percent = (fontSizeScales[step] * 100).round();
    final value = step == defaultFontSizeStep
        ? l.appearanceFontSizeDefault(percent)
        : l.appearanceFontSizeValue(percent);

    return Container(
      constraints: const BoxConstraints(maxWidth: 512),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(l.appearanceFontSize,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface)),
              Text(value,
                  style:
                      TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.appearanceFontSizeDescription,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: colors.onSurfaceVariant)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l.appearanceFontSizePreview,
              key: const Key('font-size-preview'),
              style:
                  TextStyle(fontSize: 16, height: 1.5, color: colors.onSurface),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ExcludeSemantics(
                  child: Text('A',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                          fontSize: 16, color: colors.onSurfaceVariant))),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    trackShape: const RoundedRectSliderTrackShape(),
                    activeTrackColor: colors.outline,
                    inactiveTrackColor: colors.outline,
                    activeTickMarkColor: colors.outline,
                    inactiveTickMarkColor: colors.outline,
                    tickMarkShape: const _FontSizeTickMarkShape(),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 14,
                        elevation: 3,
                        pressedElevation: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 22),
                    overlayColor: colors.onSurface.withValues(alpha: 0.08),
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: Semantics(
                    label: l.appearanceFontSize,
                    child: Slider(
                      key: const Key('font-size-slider'),
                      min: 0,
                      max: (fontSizeScales.length - 1).toDouble(),
                      divisions: fontSizeScales.length - 1,
                      value: step.toDouble(),
                      semanticFormatterCallback: (v) {
                        final p = (fontSizeScales[v.round()] * 100).round();
                        return v.round() == defaultFontSizeStep
                            ? l.appearanceFontSizeDefault(p)
                            : l.appearanceFontSizeValue(p);
                      },
                      onChanged: (v) => ref
                          .read(fontSizeProvider.notifier)
                          .setStep(v.round()),
                      onChangeEnd: (_) => _save(context, ref),
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                  child: Text('A',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                          fontSize: 26, color: colors.onSurfaceVariant))),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const Key('font-size-reset'),
              onPressed: step == defaultFontSizeStep
                  ? null
                  : () {
                      ref
                          .read(fontSizeProvider.notifier)
                          .setStep(defaultFontSizeStep);
                      _save(context, ref);
                    },
              child: Text(l.appearanceFontSizeReset),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short vertical ticks match the iOS text-size control.
class _FontSizeTickMarkShape extends SliderTickMarkShape {
  const _FontSizeTickMarkShape();

  @override
  Size getPreferredSize(
          {required SliderThemeData sliderTheme, bool? isEnabled}) =>
      const Size(2, 7);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) {
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 2, height: 7),
          const Radius.circular(1)),
      Paint()..color = sliderTheme.inactiveTickMarkColor!,
    );
  }
}
