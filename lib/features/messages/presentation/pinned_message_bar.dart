import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';

typedef PinnedMessagePreview = ({int mid, String text});

/// Compact Telegram-style entry: tap to locate, then cycle to the next pin.
class PinnedMessageBar extends StatefulWidget {
  const PinnedMessageBar({
    super.key,
    required this.messages,
    required this.onLocate,
    required this.onShowAll,
    this.locating = false,
  });

  /// Newest pin first.
  final List<PinnedMessagePreview> messages;
  final ValueChanged<int> onLocate;
  final VoidCallback onShowAll;
  final bool locating;

  @override
  State<PinnedMessageBar> createState() => _PinnedMessageBarState();
}

class _PinnedMessageBarState extends State<PinnedMessageBar> {
  int? _selectedMid;

  @override
  void didUpdateWidget(covariant PinnedMessageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Surface newly pinned messages immediately, including remote changes.
    if (oldWidget.messages.firstOrNull?.mid !=
        widget.messages.firstOrNull?.mid) {
      _selectedMid = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pins = widget.messages;
    if (pins.isEmpty) return const SizedBox.shrink();
    final selected = pins.indexWhere((p) => p.mid == _selectedMid);
    final index = selected < 0 ? 0 : selected;
    final pin = pins[index];
    final l = AppL10n.of(context);
    return Material(
      color: AppTokens.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTokens.gray200))),
        child: Row(children: [
          Expanded(
            child: InkWell(
              onTap: widget.locating
                  ? null
                  : () {
                      widget.onLocate(pin.mid);
                      setState(() =>
                          _selectedMid = pins[(index + 1) % pins.length].mid);
                    },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(children: [
                  Icon(Icons.push_pin, size: 20, color: AppTokens.primary500),
                  Container(
                    width: 3,
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: AppTokens.primary500,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pins.length > 1
                              ? '${l.chatToolPin} · ${index + 1}/${pins.length}'
                              : l.chatToolPin,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.primary500),
                        ),
                        Text(safeText(pin.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: AppTokens.gray700)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
          if (widget.locating)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            tooltip: l.chatToolPin,
            onPressed: widget.onShowAll,
            icon: Icon(Icons.format_list_bulleted,
                size: 22, color: AppTokens.gray500),
          ),
        ]),
      ),
    );
  }
}
