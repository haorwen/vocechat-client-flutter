// barrel
import 'package:flutter/material.dart';

/// Design tokens taken from the VoceChat Figma design system.
/// Source: ZFgSRNEP0vHPhfoIQ6BcZc — Chats / DM / Index, Contacts.
class AppTokens {
  // Primary (cyan)
  static const primary25 = Color(0xFFF5FEFF);
  static const primary50 = Color(0xFFECFDFF);
  static const primary400 = Color(0xFF22CCEE);
  static const primary500 = Color(0xFF06AED4);
  static const primary600 = Color(0xFF06B6D4);

  // Gray scale (Tailwind/Untitled UI)
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF2F4F7);
  static const gray200 = Color(0xFFEAECF0);
  static const gray300 = Color(0xFFD0D5DD);
  static const gray400 = Color(0xFF98A2B3);
  static const gray500 = Color(0xFF667085);
  static const gray600 = Color(0xFF475467);
  static const gray700 = Color(0xFF344054);
  static const gray800 = Color(0xFF1D2939);
  static const gray900 = Color(0xFF101828);

  // Neutral (zinc)
  static const zinc500 = Color(0xFF78787C);
  static const zinc600 = Color(0xFF52525B);
  static const zinc700 = Color(0xFF3F3F46);
  static const zinc800 = Color(0xFF27272A);

  // Status
  static const success = Color(0xFF12B76A);
  static const successDot = Color(0xFF22C55E);
  static const error = Color(0xFFF04438);

  // App canvas
  static const canvas = Color(0xFFF5F6F7);
  static const canvasAlt = Color(0xFFF8F9FB);
  static const surface = Color(0xFFFFFFFF);
  static const hover = Color(0xFFF5F6F7);
  static const selected = Color(0xFFEAECF0);

  // Borders / strokes (Privoce design system)
  static const borderStrong = Color(0xFFCFD4DC);
  static const borderSubtle = Color(0xFFEAECF0);

  // Privoce text shades
  static const textHeading = Color(0xFF0F1728);
  static const textBody = Color(0xFF344053);
  static const textMuted = Color(0xFF667084);

  // Privoce primary cyan accents
  static const accent500 = Color(0xFF05AED4);
  static const accent600 = Color(0xFF078AB2);
  static const accent700 = Color(0xFF0D6F90);
  static const accent900 = Color(0xFF155B75);
  static const accentSurface = Color(0xFFECFDFF);
  static const accentBorder = Color(0xFF67E3F9);

  // Browser-toolbar style decorative
  static const wolfGray = Color(0xFFC5C7D0);
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ColorScheme.fromSeed(
      seedColor: AppTokens.primary400,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppTokens.primary500,
      onPrimary: Colors.white,
      primaryContainer: AppTokens.primary50,
      onPrimaryContainer: AppTokens.primary500,
      surface: AppTokens.surface,
      onSurface: AppTokens.gray800,
      onSurfaceVariant: AppTokens.gray500,
      surfaceContainerLow: AppTokens.gray50,
      surfaceContainer: AppTokens.gray100,
      surfaceContainerHigh: AppTokens.gray100,
      surfaceContainerHighest: AppTokens.gray200,
      outline: AppTokens.gray300,
      outlineVariant: AppTokens.gray200,
      error: AppTokens.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppTokens.canvas,
      fontFamily: 'Inter',
      // Inter has no emoji glyphs — without an explicit fallback chain, emoji
      // in user-supplied text (names, messages) renders as tofu / □ on
      // platforms whose system fallback isn't picked up automatically.
      // List every common platform's color-emoji font so at least one is
      // present at runtime.
      fontFamilyFallback: const [
        'Apple Color Emoji', // macOS / iOS
        'Segoe UI Emoji', // Windows
        'Noto Color Emoji', // Linux / Android (modern)
        'Noto Sans CJK SC', // CJK fallback for Linux
        'PingFang SC', // CJK fallback for Apple
        'Microsoft YaHei', // CJK fallback for Windows
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.surface,
        foregroundColor: AppTokens.gray800,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.gray200,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppTokens.gray500,
        textColor: AppTokens.gray700,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.surface,
        indicatorColor: AppTokens.primary50,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTokens.gray600,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTokens.primary400,
          brightness: Brightness.dark,
        ),
      );
}
