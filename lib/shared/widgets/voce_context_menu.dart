import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A single entry in a [showVoceContextMenu] popover.
///
/// [icon] is optional: message context menus show an icon per row, while the
/// chat-list context menu (matching the web reference) is icon-free.
class VoceContextMenuItem {
  const VoceContextMenuItem(
    this.value,
    this.label, {
    this.icon,
    this.danger = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final bool danger;
}

/// Shows the VoceChat-styled context menu anchored at [globalPos] and resolves
/// to the chosen item's value (or null if dismissed).
///
/// Restyled to match the web reference's `.context-menu` (src/index.css): a
/// rounded-12 white/black popover with a soft shadow, items that turn
/// primary-400 (cyan) with white text/icon on hover, and a deep-red "danger"
/// variant for destructive actions. Built as a transparent overlay route so we
/// control the popover chrome instead of Material's default `showMenu`
/// /`PopupMenuItem` look.
Future<String?> showVoceContextMenu({
  required BuildContext context,
  required Offset globalPos,
  required List<VoceContextMenuItem> items,
  double menuWidth = 180.0,
}) {
  // Item height (≈32) + 2px gap, plus 4px vertical padding top & bottom.
  final menuHeight = items.length * 34.0 + 8;

  return Navigator.of(context, rootNavigator: true).push<String>(
    PageRouteBuilder<String>(
      opaque: false,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (ctx, anim, _) {
        // `globalPos` is in window (global) coordinates. The Positioned below
        // is laid out relative to this route's own box, so convert the global
        // point into the route's local space — otherwise any offset between
        // the window origin and this Navigator (desktop title bar, nested
        // navigator, etc.) shifts the menu far from the cursor.
        final routeBox = ctx.findRenderObject() as RenderBox?;
        final local = routeBox?.globalToLocal(globalPos) ?? globalPos;
        final size = routeBox?.size ?? MediaQuery.of(ctx).size;

        // Flip to the left / above if there isn't room to the right / below.
        double left = local.dx;
        if (left + menuWidth + 8 > size.width) {
          left = local.dx - menuWidth;
        }
        double top = local.dy;
        if (top + menuHeight + 8 > size.height) {
          top = local.dy - menuHeight;
        }
        left = left.clamp(8.0, (size.width - menuWidth - 8).clamp(8.0, size.width));
        top = top.clamp(8.0, (size.height - menuHeight - 8).clamp(8.0, size.height));

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                onSecondaryTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: FadeTransition(
                opacity: anim,
                child: _VoceContextMenu(items: items),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _VoceContextMenu extends StatelessWidget {
  const _VoceContextMenu({required this.items});
  final List<VoceContextMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          // web: bg #fff / dark bg black
          color: dark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            // web: 0 20px 25px 20px rgba(31,41,55,.1), 0 10px 10px rgba(31,41,55,.04)
            BoxShadow(
              color: Color(0x1A1F2937),
              blurRadius: 25,
              spreadRadius: 6,
              offset: Offset(0, 16),
            ),
            BoxShadow(
              color: Color(0x0A1F2937),
              blurRadius: 10,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              _VoceContextMenuItemTile(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoceContextMenuItemTile extends StatefulWidget {
  const _VoceContextMenuItemTile({required this.item});
  final VoceContextMenuItem item;

  @override
  State<_VoceContextMenuItemTile> createState() =>
      _VoceContextMenuItemTileState();
}

class _VoceContextMenuItemTileState extends State<_VoceContextMenuItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.brightness == Brightness.dark;
    final danger = widget.item.danger;
    // web idle color: #616161 (light) / white (dark); danger: #a11043
    final Color idleColor = danger
        ? const Color(0xFFA11043)
        : (dark ? Colors.white : const Color(0xFF616161));
    // web hover bg: #22ccee (primary-400) normal, #b42318 danger → white text
    final Color hoverBg =
        danger ? const Color(0xFFB42318) : AppTokens.primary400;
    final Color fg = _hovered ? Colors.white : idleColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(widget.item.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(widget.item.icon, size: 20, color: fg),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
