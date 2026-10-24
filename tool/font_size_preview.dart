import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocechat_client/core/theme/app_text_scale.dart';
import 'package:vocechat_client/core/theme/app_theme.dart';
import 'package:vocechat_client/features/settings/presentation/font_size_settings_card.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

// Flutter 3.27 predates widget_previews. Use this interactive preview instead:
// flutter run -t tool/font_size_preview.dart -d chrome
void main() => runApp(const ProviderScope(child: FontSizePreview()));

class FontSizePreview extends StatelessWidget {
  const FontSizePreview({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        builder: (context, child) => AppTextScale(child: child!),
        home: Scaffold(
          appBar: AppBar(title: const Text('字体大小')),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Center(child: FontSizeSettingsCard()),
          ),
        ),
      );
}
