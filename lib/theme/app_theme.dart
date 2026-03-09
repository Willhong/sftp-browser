import 'package:flutter/material.dart';

class AppTheme {
  static const seedColor = Color(0xFF2563EB);
  static const lightBackground = Color(0xFFF3F4F6);
  static const darkBackground = Color(0xFF0F172A);

  static const pageMaxWidth = 960.0;
  static const formMaxWidth = 680.0;
  static const browserMaxWidth = 1120.0;

  static const sectionRadius = 10.0;
  static const tileRadius = 6.0;
  static const chipRadius = 6.0;
  static const iconBadgeRadius = 8.0;
  static const inputRadius = 8.0;

  static const toolbarHeight = 52.0;
  static const pagePadding = EdgeInsets.fromLTRB(16, 10, 16, 0);
  static const sectionPadding = EdgeInsets.all(14);
  static const sectionGap = 10.0;
  static const tileGap = 0.0;
  static const switcherDuration = Duration(milliseconds: 180);

  static ThemeData buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: lightBackground,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sectionRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        toolbarHeight: toolbarHeight,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tileRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(inputRadius),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tileRadius),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        minLeadingWidth: 32,
        horizontalTitleGap: 10,
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.82),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  static ThemeData buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: darkBackground,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sectionRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        toolbarHeight: toolbarHeight,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tileRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(inputRadius),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tileRadius),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        minLeadingWidth: 32,
        horizontalTitleGap: 10,
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.88),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  static bool isDark(ThemeData theme) => theme.brightness == Brightness.dark;

  static Color surfaceColor(ThemeData theme) {
    return theme.colorScheme.surface;
  }

  static Color panelColor(ThemeData theme) {
    return isDark(theme) ? const Color(0xFF111827) : Colors.white;
  }

  static Color chromeColor(ThemeData theme) {
    return isDark(theme) ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
  }

  static Color mutedSurfaceColor(
    ThemeData theme, {
    double lightAlpha = 0.82,
    double darkAlpha = 0.56,
  }) {
    return theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark(theme) ? darkAlpha : lightAlpha,
    );
  }

  static BorderSide outlineSide(
    ThemeData theme, {
    double lightAlpha = 0.72,
    double darkAlpha = 0.34,
  }) {
    return BorderSide(
      color: theme.colorScheme.outlineVariant.withValues(
        alpha: isDark(theme) ? darkAlpha : lightAlpha,
      ),
    );
  }

  static Color separatorColor(ThemeData theme) {
    return theme.colorScheme.outlineVariant.withValues(
      alpha: isDark(theme) ? 0.38 : 0.68,
    );
  }

  static Color rowHoverColor(ThemeData theme) {
    return theme.colorScheme.primary.withValues(
      alpha: isDark(theme) ? 0.12 : 0.06,
    );
  }

  static List<BoxShadow> panelShadow(ThemeData theme) {
    return const [];
  }
}
