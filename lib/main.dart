import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:vocechat_client/core/i18n/locale_provider.dart';
import 'package:vocechat_client/core/router/app_router.dart';
import 'package:vocechat_client/core/router/deep_link_listener.dart';
import 'package:vocechat_client/core/theme/app_theme.dart';
import 'package:vocechat_client/core/theme/theme_provider.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

void main() {
  // video_player has no official Windows/Linux backend; fvp fills that gap
  // and defers to the official implementation on platforms that have one.
  // Android is also opted in (even though video_player_android exists)
  // because it falls back to an FFmpeg software decoder when the device's
  // hardware MediaCodec doesn't recognize a stream's codec/profile — the
  // stock plugin has no such fallback and its channel just dies, so some
  // servers' HEVC uploads simply won't play at all on affected devices.
  fvp.registerWith(options: {'platforms': ['windows', 'linux', 'android']});
  runApp(const ProviderScope(child: VoceChatApp()));
}

class VoceChatApp extends ConsumerWidget {
  const VoceChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeNotifierProvider);
    final locale = ref.watch(localeNotifierProvider);
    // Mounts the app_links subscription for the app's lifetime (Android/iOS
    // vocechat:// custom scheme). keepAlive on the provider means this watch
    // just needs to fire once to start it — see deep_link_listener.dart.
    ref.watch(deepLinkListenerProvider);

    // AppTokens.* getters resolve through a global brightness flag. Sync it
    // from the brightness MaterialApp actually picked (which depends on
    // `themeMode` plus, when system, the platform brightness). We must do
    // this inside a Builder under MaterialApp so Theme.of(context) reflects
    // the just-applied ThemeData — applying it in the parent build runs
    // *before* MaterialApp reconciles the new theme, so colors captured by
    // widgets on the current frame would still come from the stale flag and
    // only refresh on the next navigation/rebuild.
    return MaterialApp.router(
      title: 'VoceChat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        AppTheme.applyBrightness(brightness);
        // Key the subtree by brightness so every descendant rebuilds (and
        // re-reads AppTokens.*) the instant the resolved theme flips —
        // otherwise widgets that don't watch themeMode keep cached colors.
        return GestureDetector(
          // Tapping blank space anywhere dismisses the keyboard — mirrors
          // native mobile behavior. deferToChild would only fire when a
          // descendant already claims the hit, so opaque is required to
          // catch taps on plain, non-interactive areas.
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: KeyedSubtree(
            key: ValueKey(brightness),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
