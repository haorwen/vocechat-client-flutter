import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../contacts/application/presence_provider.dart';
import '../../messages/application/message_dispatcher.dart';

/// Width threshold above which the desktop left rail layout is used.
const double _kWideBreakpoint = 900;

class HomeShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate the global SSE → ChatController/Conversations dispatcher.
    ref.watch(messageDispatcherProvider);
    // Activate the presence map / online-status flag so they latch onto SSE
    // before any UI consults them.
    ref.watch(presenceProvider);
    ref.watch(showOnlineStatusProvider);

    // Match web behavior: hide the bottom nav while inside a chat
    // conversation (matches `isChattingPage && "hidden"` in MobileNavs.tsx).
    final location = GoRouterState.of(context).matchedLocation;
    final isChatting = RegExp(r'^/home/chat/').hasMatch(location);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= _kWideBreakpoint;
      if (isWide) {
        return Scaffold(
          backgroundColor: AppTokens.canvas,
          body: Row(
            children: [
              _DesktopLeftRail(
                currentIndex: navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: AppTokens.surface,
                      child: navigationShell,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        );
      }

      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: isChatting
            ? null
            : NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
                indicatorColor:
                    Theme.of(context).colorScheme.primaryContainer,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble),
                    label: 'Chats',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: 'Contacts',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// _DesktopLeftRail — vertical icon nav matching the Figma "Menu" component.
// Width 72, with a server avatar on top, primary destinations in the middle,
// and a settings affordance pinned to the bottom.
// ---------------------------------------------------------------------------

class _DesktopLeftRail extends StatelessWidget {
  const _DesktopLeftRail({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Server header avatar (matches Figma 32px circular avatar at top).
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTokens.primary50,
              shape: BoxShape.circle,
              border: Border.all(color: AppTokens.gray200),
            ),
            child: const Icon(Icons.bolt_outlined,
                size: 22, color: AppTokens.primary500),
          ),
          const SizedBox(height: 16),
          _RailItem(
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
            isSelected: currentIndex == 0,
            hasBadge: true,
            onTap: () => onDestinationSelected(0),
            tooltip: 'Chats',
          ),
          const SizedBox(height: 8),
          _RailItem(
            icon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_rounded,
            isSelected: currentIndex == 1,
            onTap: () => onDestinationSelected(1),
            tooltip: 'Contacts',
          ),
          const SizedBox(height: 8),
          _RailItem(
            icon: Icons.bookmark_outline_rounded,
            selectedIcon: Icons.bookmark_rounded,
            isSelected: false,
            onTap: () {},
            tooltip: 'Saved',
          ),
          const SizedBox(height: 8),
          _RailItem(
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder_rounded,
            isSelected: false,
            onTap: () {},
            tooltip: 'Files',
          ),
          const Spacer(),
          _RailItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            isSelected: currentIndex == 2,
            onTap: () => onDestinationSelected(2),
            tooltip: 'Settings',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
    this.hasBadge = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? AppTokens.primary400 : Colors.transparent;
    final fg = isSelected ? Colors.white : AppTokens.gray500;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(isSelected ? selectedIcon : icon, size: 24, color: fg),
              if (hasBadge && !isSelected)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTokens.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTokens.surface, width: 1.5),
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
