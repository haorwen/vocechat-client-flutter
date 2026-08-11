import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/fcm_service.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/server/presentation/server_picker_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/channels/presentation/home_shell_screen.dart';
import '../../features/channels/presentation/chat_list_screen.dart';
import '../../features/channels/presentation/channel_settings_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/messages/presentation/chat_screen.dart';
import '../storage/server_store.dart';

// ---------------------------------------------------------------------------
// Splash (thin placeholder until auth guard is wired)
// ---------------------------------------------------------------------------

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.chat_bubble_rounded,
                  size: 42, color: cs.primary),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: cs.primary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Router provider with auth redirect
// ---------------------------------------------------------------------------

/// Notifies GoRouter's `redirect` to re-evaluate without recreating the
/// `GoRouter` instance itself. Recreating the router (the old behavior of
/// `ref.watch`ing auth/server state directly in the provider body) tears
/// down and rebuilds the entire routed widget tree on every auth state
/// transition — including the transient `loading` state a login attempt
/// passes through. That destroyed `LoginScreen` (and its `ref.listen` that
/// surfaces the login error SnackBar) before the login response ever
/// arrived, so failures appeared to do nothing.
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(serverStoreProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(fcmPendingChatTargetProvider, (_, __) => refreshNotifier.refresh());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authAsync = ref.read(authControllerProvider);
      final serverAsync = ref.read(serverStoreProvider);

      // Server store must finish loading before any routing decision
      if (serverAsync.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final serverState = serverAsync.valueOrNull;
      final hasServer = serverState?.currentServerId != null &&
          (serverState?.servers.any(
                  (s) => s.id == serverState.currentServerId) ??
              false);

      // No server configured → straight to picker (auth is irrelevant here)
      if (!hasServer) {
        if (location == '/server-picker') return null;
        return '/server-picker';
      }

      // Server is configured — now wait for auth bootstrap. Only route to
      // /splash for the *initial* bootstrap (no previous auth value yet).
      // A login()/register() attempt from the login screen also sets a bare
      // `AsyncLoading()` — that must NOT force a redirect away from /login,
      // or the screen (and the `ref.listen` that shows the error SnackBar)
      // gets torn down and rebuilt before the failure ever reaches it.
      if (authAsync.isLoading && !authAsync.hasValue) {
        return location == '/splash' ? null : '/splash';
      }

      final authState = authAsync.valueOrNull;
      final isAuthenticated = authState is AuthStateAuthenticated;

      // Server set but not authenticated → login (allow register/picker too)
      if (!isAuthenticated) {
        const allowed = ['/login', '/register', '/server-picker'];
        if (allowed.contains(location)) return null;
        return '/login';
      }

      // Authenticated → block auth screens, send splash to home
      const authScreens = ['/login', '/register', '/splash'];
      if (authScreens.contains(location)) return '/home';

      // FCM notification tap: navigate to the target chat and clear the
      // pending state so the redirect only fires once.
      final pendingFcm = ref.read(fcmPendingChatTargetProvider);
      if (pendingFcm != null) {
        ref.read(fcmPendingChatTargetProvider.notifier).state = null;
        return '/home/chat/$pendingFcm';
      }

      // Validate nested chat route IDs — redirect invalid ones to /home.
      // Tile IDs are emitted as `u-<uid>` / `g-<gid>`, so the hyphen is part
      // of the canonical shape and the regex must include it. The id segment
      // may be followed by an optional `/settings` suffix (channel settings
      // subroute), which must not be swallowed into the id capture group.
      final chatMatch =
          RegExp(r'^/home/chat/([^/]+)(?:/settings)?$').firstMatch(location);
      if (chatMatch != null) {
        final id = chatMatch.group(1)!;
        if (!RegExp(r'^[ug]-\d+$').hasMatch(id)) return '/home';
        // Channel settings is only valid for channels, not DMs.
        if (location.endsWith('/settings') && !id.startsWith('g-')) {
          return '/home/chat/$id';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/server-picker',
        builder: (context, state) => const ServerPickerScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterScreen(magicToken: state.extra as String?),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: 'chat/:id',
                    builder: (context, state) =>
                        ChatScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'settings',
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final gid = int.tryParse(id.substring(2)) ?? 0;
                          return ChannelSettingsScreen(gid: gid);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (context, state) =>
                    const ContactsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
