import 'dart:async';

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
import '../storage/account_store.dart';
import '../recovery/app_recovery.dart';
import '../../l10n/generated/app_localizations.dart';

// ---------------------------------------------------------------------------
// Splash (thin placeholder until auth guard is wired)
// ---------------------------------------------------------------------------

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeout;
  bool _waitingTooLong = false;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _waitingTooLong = true);
    });
  }

  void _retry() {
    final recovery = AppRecoveryHost.maybeOf(context);
    if (recovery != null) {
      recovery.retry();
      return;
    }
    ref.invalidate(serverStoreProvider);
    ref.invalidate(accountStoreProvider);
    ref.invalidate(authControllerProvider);
    setState(() => _waitingTooLong = false);
    _startTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_waitingTooLong) {
      final l = AppL10n.of(context);
      return AppRecoveryPage(
          onRetry: _retry,
          title: l.appLoadingSlowTitle,
          body: l.appLoadingSlowBody);
    }
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
              child:
                  Icon(Icons.chat_bubble_rounded, size: 42, color: cs.primary),
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
  var disposed = false;
  final consuming = <String>{};
  // A redirect can run while Router is mounting. Acknowledging the tap on
  // next frame avoids mutating Riverpod during that build, and the
  // equality check preserves a newer tap delivered before this one settles.
  void consumeLater(String target) {
    if (!consuming.add(target)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      consuming.remove(target);
      if (!disposed && ref.read(fcmPendingChatTargetProvider) == target) {
        ref.read(fcmPendingChatTargetProvider.notifier).state = null;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  ref.listen(authControllerProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(serverStoreProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(fcmPendingChatTargetProvider, (_, next) {
    // Clearing an acknowledged tap must not re-parse the old route before
    // Router has published the newly matched location back to its provider.
    if (next != null) refreshNotifier.refresh();
  });
  late final GoRouter router;
  ref.onDispose(() {
    disposed = true;
    router.dispose();
    refreshNotifier.dispose();
  });

  router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    errorBuilder: (context, state) =>
        AppRecoveryPage(onRetry: () => router.go('/home')),
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
          (serverState?.servers
                  .any((s) => s.id == serverState.currentServerId) ??
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

      // Keep redirect free of synchronous provider writes. Consume only once
      // the target is matched, so a second evaluation cannot undo the tap.
      final pendingFcm = ref.read(fcmPendingChatTargetProvider);
      if (pendingFcm != null) {
        if (!RegExp(r'^[ug]-\d+$').hasMatch(pendingFcm)) {
          consumeLater(pendingFcm);
        } else {
          final target = '/home/chat/$pendingFcm';
          if (location != target) return target;
          consumeLater(pendingFcm);
        }
      }

      // Native notifications and app_links own these external intents. If
      // Flutter also forwards the URI, retain the current app page instead
      // of replacing the chat with an unmatched route.
      if (state.uri.scheme == 'vocechat-notification' ||
          state.uri.scheme == 'vocechat') {
        final current = router.routerDelegate.currentConfiguration;
        return !current.isError &&
                current.uri.scheme.isEmpty &&
                current.uri.path.isNotEmpty
            ? current.uri.toString()
            : '/home';
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
    routes: ref.read(appRoutesProvider),
  );
  return router;
});

// Route builders are injectable so navigation can be checked independently
// from network/platform-heavy screens.
final appRoutesProvider = Provider<List<RouteBase>>((ref) => [
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
        builder: (context, state) => RegisterScreen(
            magicToken: state.extra is String ? state.extra as String : null),
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
                builder: (context, state) => const ContactsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ]);
