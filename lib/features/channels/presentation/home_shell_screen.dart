import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/sse_lifecycle.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../messages/application/message_dispatcher.dart';

/// Width threshold above which the desktop left rail layout is used.
const double _kWideBreakpoint = 900;

class HomeShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShellScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  // The GoRouter's route-information notifier. Subscribing to it is what makes
  // this shell rebuild on *intra-branch* navigation (e.g. pushing/popping
  // /home/chat/:id). StatefulNavigationShell only rebuilds on branch switches,
  // and GoRouterState.of(context) inside the shell does not re-fire when a
  // nested page is popped via Navigator.maybePop — so reading the location
  // without this listener leaves `isChatting` stale and the bottom nav
  // permanently hidden after returning from a chat. (The original bug.)
  Listenable? _routerListenable;

  void _onRouterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    final next = router.routeInformationProvider;
    if (identical(next, _routerListenable)) return;
    _routerListenable?.removeListener(_onRouterChanged);
    _routerListenable = next;
    _routerListenable?.addListener(_onRouterChanged);
  }

  @override
  void dispose() {
    _routerListenable?.removeListener(_onRouterChanged);
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;

    // Activate the global SSE → ChatController/Conversations dispatcher.
    ref.watch(messageDispatcherProvider);
    // Activate SSE lifecycle watchers: token rotation, network up/down,
    // and app foreground/background. Each is keepAlive and self-managing.
    ref.watch(sseTokenWatcherProvider);
    ref.watch(sseConnectivityWatcherProvider);
    ref.watch(sseLifecycleWatcherProvider);

    // Use MediaQuery instead of LayoutBuilder for the breakpoint: on desktop
    // (Windows/macOS/Linux) resizing the window must flip the layout reliably,
    // and a LayoutBuilder placed inside a Scaffold body can lag behind window
    // metrics during a drag. MediaQuery.sizeOf rebuilds on every metric change.
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _kWideBreakpoint;

    // Match web behavior: hide the bottom nav while inside a chat conversation
    // (matches `isChattingPage && "hidden"` in MobileNavs.tsx). Only applies
    // on narrow layouts — on wide layouts the chat list keeps URL at /home
    // and renders the conversation in a right pane via internal state, so the
    // /home/chat/* URL only appears when the user is actually on the detail
    // view (true mobile / narrow desktop).
    //
    // Read the live location from the router (kept fresh by the listener wired
    // in didChangeDependencies) rather than GoRouterState.of(context), whose
    // dependency does not re-fire on a nested Navigator pop.
    final location = GoRouterState.of(context).uri.path;
    final isChatting =
        !isWide && RegExp(r'^/home/chat/').hasMatch(location);

    if (isWide) {
      return Scaffold(
        backgroundColor: AppTokens.canvas,
        body: SafeArea(
          child: Row(
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
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: navigationShell,
      ),
      bottomNavigationBar: isChatting
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              indicatorColor:
                  Theme.of(context).colorScheme.primaryContainer,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.chat_bubble_outline),
                  selectedIcon: const Icon(Icons.chat_bubble),
                  label: AppL10n.of(context).navChats,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.people_outline),
                  selectedIcon: const Icon(Icons.people),
                  label: AppL10n.of(context).navContacts,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: AppL10n.of(context).navSettings,
                ),
              ],
            ),
    );
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
    final l = AppL10n.of(context);
    void comingSoon() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.comingSoon),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

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
            child: Icon(Icons.bolt_outlined,
                size: 22, color: AppTokens.primary500),
          ),
          const SizedBox(height: 16),
          _RailItem(
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
            isSelected: currentIndex == 0,
            hasBadge: true,
            onTap: () => onDestinationSelected(0),
            tooltip: l.navChats,
          ),
          const SizedBox(height: 8),
          _RailItem(
            icon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_rounded,
            isSelected: currentIndex == 1,
            onTap: () => onDestinationSelected(1),
            tooltip: l.navContacts,
          ),
          const SizedBox(height: 8),
          _RailItem(
            icon: Icons.bookmark_outline_rounded,
            selectedIcon: Icons.bookmark_rounded,
            isSelected: false,
            onTap: comingSoon,
            tooltip: l.navSaved,
          ),
          const SizedBox(height: 8),
          _RailItem(
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder_rounded,
            isSelected: false,
            onTap: comingSoon,
            tooltip: l.navFiles,
          ),
          const Spacer(),
          _RailItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            isSelected: currentIndex == 2,
            onTap: () => onDestinationSelected(2),
            tooltip: l.navSettings,
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
    final fg = isSelected
        ? Theme.of(context).colorScheme.onPrimary
        : AppTokens.gray500;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppTokens.hover,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
          alignment: Alignment.center,
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
