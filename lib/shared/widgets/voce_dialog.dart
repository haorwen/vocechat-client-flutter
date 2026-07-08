import 'package:flutter/material.dart';

/// Confirm dialog matching the web reference's styled/Modal.tsx pattern:
/// rounded-8 card, 40% black barrier, and a right-aligned button row of a
/// ghost "cancel" button followed by a filled confirm button — red
/// (web `danger` variant: #EF4444, pressed #B91C1C) when [danger] is true,
/// otherwise the primary cyan.
///
/// Resolves to `true` when confirmed, `false`/`null` otherwise.
Future<bool?> showVoceConfirm({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0x66020202), // web mask: rgba(2,2,2,0.4)
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        const SizedBox(width: 8),
        danger
            ? FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return const Color(0xFFB91C1C);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xCCEF4444);
                    }
                    return const Color(0xFFEF4444);
                  }),
                ),
                child: Text(confirmLabel),
              )
            : FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(confirmLabel),
              ),
      ],
    ),
  );
}
