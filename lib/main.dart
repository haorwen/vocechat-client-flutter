import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocechat_client/core/router/app_router.dart';
import 'package:vocechat_client/core/theme/app_theme.dart';
import 'package:vocechat_client/core/theme/theme_provider.dart';

void main() {
  runApp(const ProviderScope(child: VoceChatApp()));
}

class VoceChatApp extends ConsumerWidget {
  const VoceChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeNotifierProvider);
    return MaterialApp.router(
      title: 'VoceChat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
