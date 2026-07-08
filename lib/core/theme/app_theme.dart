// barrel
import 'package:flutter/material.dart';

/// Design tokens taken from the VoceChat Figma design system, with dark-mode
/// variants modeled on the web reference (vocechat-web-just-reference).
///
/// All getters are dynamic: they resolve against [AppTokens.brightness], which
/// `AppTheme` toggles whenever the active `ThemeData` changes. Existing
/// `AppTokens.surface`, `AppTokens.gray800`, etc. call-sites therefore become
/// theme-aware without rewriting every widget.
class AppTokens {
  AppTokens._();

  /// Active brightness. Updated by [AppTheme.applyBrightness] whenever the
  /// `ThemeData` builder runs, so all `AppTokens.*` getters resolve to the
  /// matching palette.
  static Brightness brightness = Brightness.light;

  static bool get _dark => brightness == Brightness.dark;

  // ---------- Primary (cyan) ----------
  static Color get primary25 =>
      _dark ? const Color(0xFF0B2A33) : const Color(0xFFF5FEFF);
  static Color get primary50 =>
      _dark ? const Color(0xFF103B47) : const Color(0xFFECFDFF);
  static Color get primary400 => const Color(0xFF22CCEE);
  static Color get primary500 =>
      _dark ? const Color(0xFF22CCEE) : const Color(0xFF06AED4);
  static Color get primary600 => const Color(0xFF06B6D4);

  // ---------- Gray scale ----------
  // Light: Tailwind / Untitled UI gray
  // Dark : Tailwind gray, lightened progressively so usage sites that expected
  //        "dark text on light bg" still get correct contrast on dark bg.
  static Color get gray50 =>
      _dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
  static Color get gray100 =>
      _dark ? const Color(0xFF1F2937) : const Color(0xFFF2F4F7);
  static Color get gray200 =>
      _dark ? const Color(0xFF374151) : const Color(0xFFEAECF0);
  static Color get gray300 =>
      _dark ? const Color(0xFF4B5563) : const Color(0xFFD0D5DD);
  static Color get gray400 =>
      _dark ? const Color(0xFF6B7280) : const Color(0xFF98A2B3);
  static Color get gray500 =>
      _dark ? const Color(0xFF9CA3AF) : const Color(0xFF667085);
  static Color get gray600 =>
      _dark ? const Color(0xFFD1D5DB) : const Color(0xFF475467);
  static Color get gray700 =>
      _dark ? const Color(0xFFE5E7EB) : const Color(0xFF344054);
  static Color get gray800 =>
      _dark ? const Color(0xFFF3F4F6) : const Color(0xFF1D2939);
  static Color get gray900 =>
      _dark ? const Color(0xFFF9FAFB) : const Color(0xFF101828);

  // ---------- Neutral (zinc) ----------
  static Color get zinc500 =>
      _dark ? const Color(0xFFA1A1AA) : const Color(0xFF78787C);
  static Color get zinc600 =>
      _dark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B);
  static Color get zinc700 =>
      _dark ? const Color(0xFFE4E4E7) : const Color(0xFF3F3F46);
  static Color get zinc800 =>
      _dark ? const Color(0xFFF4F4F5) : const Color(0xFF27272A);

  // ---------- Status ----------
  static Color get success =>
      _dark ? const Color(0xFF22C55E) : const Color(0xFF12B76A);
  static Color get successDot => const Color(0xFF22C55E);
  static Color get error =>
      _dark ? const Color(0xFFF87171) : const Color(0xFFF04438);

  // ---------- App canvas / surfaces ----------
  // Mirrors the web's dark scheme:
  //   page     = neutral-900   #0A0A0A
  //   card     = gray-800      #1F2937
  //   hover    = gray-700      #374151
  //   selected = gray-700      #374151
  static Color get canvas =>
      _dark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F6F7);
  static Color get canvasAlt =>
      _dark ? const Color(0xFF111827) : const Color(0xFFF8F9FB);
  static Color get surface =>
      _dark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF);
  static Color get hover =>
      _dark ? const Color(0xFF374151) : const Color(0xFFF5F6F7);
  static Color get selected =>
      _dark ? const Color(0xFF374151) : const Color(0xFFEAECF0);

  // ---------- Borders / strokes ----------
  static Color get borderStrong =>
      _dark ? const Color(0xFF4B5563) : const Color(0xFFCFD4DC);
  static Color get borderSubtle =>
      _dark ? const Color(0xFF374151) : const Color(0xFFEAECF0);

  // ---------- Text shades ----------
  static Color get textHeading =>
      _dark ? const Color(0xFFFFFFFF) : const Color(0xFF0F1728);
  static Color get textBody =>
      _dark ? const Color(0xFFE5E7EB) : const Color(0xFF344053);
  static Color get textMuted =>
      _dark ? const Color(0xFF9CA3AF) : const Color(0xFF667084);

  // ---------- Primary cyan accents ----------
  static Color get accent500 =>
      _dark ? const Color(0xFF22CCEE) : const Color(0xFF05AED4);
  static Color get accent600 =>
      _dark ? const Color(0xFF06AED4) : const Color(0xFF078AB2);
  static Color get accent700 =>
      _dark ? const Color(0xFF0E7090) : const Color(0xFF0D6F90);
  static Color get accent900 =>
      _dark ? const Color(0xFF164C63) : const Color(0xFF155B75);
  static Color get accentSurface =>
      _dark ? const Color(0xFF103B47) : const Color(0xFFECFDFF);
  static Color get accentBorder =>
      _dark ? const Color(0xFF0E7090) : const Color(0xFF67E3F9);

  // ---------- Decorative ----------
  static Color get wolfGray =>
      _dark ? const Color(0xFF4B5563) : const Color(0xFFC5C7D0);
}

class AppTheme {
  AppTheme._();

  /// Update [AppTokens.brightness] to match the actually-resolved brightness
  /// of the current frame. Call this from a widget that has access to
  /// `Theme.of(context).brightness` (e.g. `Builder` directly under
  /// `MaterialApp`). The previous design — mutating brightness inside the
  /// `lightTheme` / `darkTheme` getters — broke when MaterialApp evaluated
  /// both getters per rebuild: whichever ran last won, regardless of the
  /// active [ThemeMode].
  static void applyBrightness(Brightness b) => AppTokens.brightness = b;

  static ThemeData get lightTheme {
    // Light palette, frozen — does NOT read [AppTokens], so the global
    // brightness flag does not interfere with the ThemeData itself.
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF22CCEE),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF06AED4),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFECFDFF),
      onPrimaryContainer: const Color(0xFF06AED4),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF1D2939),
      onSurfaceVariant: const Color(0xFF667085),
      surfaceContainerLow: const Color(0xFFF9FAFB),
      surfaceContainer: const Color(0xFFF2F4F7),
      surfaceContainerHigh: const Color(0xFFF2F4F7),
      surfaceContainerHighest: const Color(0xFFEAECF0),
      outline: const Color(0xFFD0D5DD),
      outlineVariant: const Color(0xFFEAECF0),
      error: const Color(0xFFF04438),
    );

    return _buildTheme(base, Brightness.light);
  }

  static ThemeData get darkTheme {
    // Web reference dark palette
    //   bg page    neutral-900  #0A0A0A
    //   bg card    gray-800     #1F2937
    //   bg hover   gray-700     #374151
    //   text       white / gray-300
    //   border     gray-500/600
    //   brand      primary-400  #22CCEE (hover #06AED4)
    const pageBg = Color(0xFF0A0A0A);
    const cardBg = Color(0xFF1F2937);
    const hoverBg = Color(0xFF374151);
    const borderC = Color(0xFF4B5563);

    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF22CCEE),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF22CCEE),
      onPrimary: Colors.black,
      primaryContainer: const Color(0xFF164C63),
      onPrimaryContainer: const Color(0xFF67E3F9),
      surface: cardBg,
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFD1D5DB),
      surfaceContainerLow: pageBg,
      surfaceContainer: cardBg,
      surfaceContainerHigh: hoverBg,
      surfaceContainerHighest: hoverBg,
      outline: borderC,
      outlineVariant: const Color(0xFF374151),
      error: const Color(0xFFF87171),
    );

    return _buildTheme(base, Brightness.dark);
  }

  static ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F6F7);
    final appBarBg =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF);
    final dividerC =
        isDark ? const Color(0xFF374151) : const Color(0xFFEAECF0);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
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
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1D2939),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: dividerC,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark
            ? const Color(0xFF9CA3AF)
            : const Color(0xFF667085),
        textColor: isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF344054),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF),
        indicatorColor:
            isDark ? const Color(0xFF164C63) : const Color(0xFFECFDFF),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark
                ? const Color(0xFFD1D5DB)
                : const Color(0xFF475467),
          ),
        ),
      ),
      // Web styled/Input.tsx: rounded (4px), border gray-200 #E5E7EB
      // (dark gray-400), placeholder gray-400 #9CA3AF, no colored focus ring
      // — focus just keeps the border, so the focused border matches enabled.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF),
        hintStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF6B7280)
                : const Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF6B7280)
                : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF22CCEE)),
        ),
      ),
      iconTheme: IconThemeData(
        color: isDark
            ? const Color(0xFFD1D5DB)
            : const Color(0xFF475467),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF374151)
                : const Color(0xFFEAECF0),
          ),
        ),
      ),
      // Component themes below centralize shapes/sizes that screens used to
      // re-specify ad hoc, so buttons/dialogs/sheets look consistent and stay
      // dark-mode-aware without per-call-site colors.
      //
      // Button metrics mirror the web reference's styled/Button.tsx:
      // h-11 (44px), rounded-lg (8px), px-3.5 (14px), text-sm (14px) white on
      // primary-400 #22CCEE; hover/pressed primary-500 #06AED4; disabled
      // gray-300 #D1D5DB. The same bg/fg applies in dark mode (the web does
      // not swap button colors), so colors are set here rather than pulled
      // from the ColorScheme.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFD1D5DB);
            }
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return const Color(0xFF06AED4);
            }
            return const Color(0xFF22CCEE);
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      // Web "ghost" variant: transparent bg, gray-700 text, gray-300 border
      // (dark: gray-100 text, gray-500 border).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          foregroundColor:
              isDark ? const Color(0xFFF3F4F6) : const Color(0xFF374151),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF6B7280)
                : const Color(0xFFD1D5DB),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      // Web styled/Toggle.tsx: 44×24 track (radius 12), white 20px knob,
      // ON primary-400 #22CCEE / OFF gray-300 (dark gray-600), no outline.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        thumbIcon: const WidgetStatePropertyAll(null),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF22CCEE);
          }
          return isDark
              ? const Color(0xFF4B5563)
              : const Color(0xFFD1D5DB);
        }),
      ),
      // Web styled/Checkbox.tsx: 20×20, rounded-md (6px), slate-300 border,
      // cyan border + light-cyan check when selected.
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF6B7280)
              : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF22CCEE);
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF22CCEE);
          }
          return isDark
              ? const Color(0xFF6B7280)
              : const Color(0xFFCBD5E1);
        }),
      ),
      // Web styled/Modal.tsx: rounded-lg (8px) card, 20px semibold title,
      // 14px gray-400 body.
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF475467),
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: isDark
              ? const Color(0xFF9CA3AF)
              : const Color(0xFF98A2B3),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF374151) : const Color(0xFF1D2939),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isDark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor:
            isDark ? const Color(0xFF22CCEE) : const Color(0xFF06AED4),
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 2,
      ),
      // Web Tooltip.tsx: white card (dark gray-800), 12px text gray-700,
      // rounded-lg (8px), drop shadow — not the Material dark pill.
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: isDark
              ? Border.all(color: const Color(0xFF4B5563))
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white : const Color(0xFF374151),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? const Color(0xFF22CCEE) : const Color(0xFF06AED4),
      ),
    );
  }
}
