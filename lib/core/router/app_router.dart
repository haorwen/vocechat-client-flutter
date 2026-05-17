import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/server/presentation/server_picker_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/channels/presentation/home_shell_screen.dart';
import '../../features/channels/presentation/chat_list_screen.dart';
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

final goRouterProvider = Provider<GoRouter>((ref) {
  // Rebuild router when auth or server state changes
  final authAsync = ref.watch(authControllerProvider);
  final serverAsync = ref.watch(serverStoreProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;

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

      // Server is configured — now wait for auth bootstrap
      if (authAsync.isLoading) {
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

      // Validate nested chat route IDs — redirect invalid ones to /home.
      // Tile IDs are emitted as `u-<uid>` / `g-<gid>`, so the hyphen is part
      // of the canonical shape and the regex must include it.
      final chatMatch = RegExp(r'^/home/chat/(.+)$').firstMatch(location);
      if (chatMatch != null) {
        final id = chatMatch.group(1)!;
        if (!RegExp(r'^[ug]-\d+$').hasMatch(id)) return '/home';
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
        builder: (context, state) => const RegisterScreen(),
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
