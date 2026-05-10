import 'package:flutter/material.dart';

/// A translucent pill-shaped loading indicator.
///
/// Used to signal background refreshes WITHOUT covering the underlying content
/// — the cached UI stays visible and the capsule sits in a corner where it
/// can be ignored. Replaces the full-screen [CircularProgressIndicator] for
/// first-paint scenarios where we already have a cached snapshot to render.
class LoadingCapsule extends StatelessWidget {
  const LoadingCapsule({
    super.key,
    this.label = 'Updating…',
    this.compact = false,
    this.subtle = false,
  });

  final String label;
  final bool compact;

  /// When true, render with very low opacity and smaller chrome so the capsule
  /// stays out of the way during long background refreshes.
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final pad = (compact || subtle)
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    final spinnerSize = subtle ? 9.0 : (compact ? 12.0 : 14.0);
    final fontSize = subtle ? 10.0 : (compact ? 11.0 : 12.0);

    // ~25% gray-800 background + ~70% text — clearly visible if you look,
    // easy to ignore if you don't.
    final bg = subtle ? const Color(0x331F2937) : const Color(0xCC1F2937);
    final fg = subtle ? const Color(0xB3FFFFFF) : Colors.white;

    return IgnorePointer(
      ignoring: true,
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: subtle
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: spinnerSize,
              height: spinnerSize,
              child: CircularProgressIndicator(
                strokeWidth: subtle ? 1.5 : 2,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            ),
            SizedBox(width: subtle ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: fg,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience overlay positioning the capsule discreetly at the bottom-right
/// of its parent. The capsule renders in [LoadingCapsule.subtle] mode so a
/// long background refresh doesn't hijack the user's attention.
class LoadingCapsuleOverlay extends StatelessWidget {
  const LoadingCapsuleOverlay({
    super.key,
    required this.visible,
    this.label = 'Updating…',
    this.bottomPadding = 10,
    this.rightPadding = 12,
  });

  final bool visible;
  final String label;
  final double bottomPadding;
  final double rightPadding;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: rightPadding,
      bottom: bottomPadding,
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          child: LoadingCapsule(label: label, subtle: true),
        ),
      ),
    );
  }
}
