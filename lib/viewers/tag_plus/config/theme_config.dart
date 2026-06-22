// ============================================================
// config/theme_config.dart — ערכת הצבעים והגופנים של תג פלוס
// ============================================================
import 'package:flutter/material.dart';

class TagPlusColors {
  // ראשיים
  static const Color primary       = Color(0xFF1565C0);
  static const Color primaryLight  = Color(0xFF2196F3);
  static const Color primaryDark   = Color(0xFF0D47A1);
  static const Color accent        = Color(0xFFFFC107);

  // מצבים
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error   = Color(0xFFF44336);
  static const Color info    = Color(0xFF00BCD4);

  // רקע
  static const Color background      = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundGrey  = Color(0xFFFAFAFA);
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color canvasGrey      = Color(0xFF888888);

  // טקסט
  static const Color textPrimary    = Color(0xFF212121);
  static const Color textSecondary  = Color(0xFF757575);
  static const Color textDisabled   = Color(0xFFBDBDBD);
  static const Color textHint       = Color(0xFF9E9E9E);
  static const Color textOnPrimary  = Color(0xFFFFFFFF);

  // עריכה
  static const Color searchHighlight = Color(0xFFFFF176);
  static const Color searchCurrent   = Color(0xFFFFD54F);
  static const Color selectionColor  = Color(0xFFB3E5FC);
  static const Color marginLine      = Color(0xFFC8C8FF);

  // שינויים
  static const Color changeInsert  = Color(0xFFC8E6C9);
  static const Color changeDelete  = Color(0xFFFFCDD2);
  static const Color changeFormat  = Color(0xFFFFF9C4);

  // עמוד
  static const Color pageShadow    = Color(0xFFB0B0B0);
  static const Color pageBorder    = Color(0xFF999999);
  static const Color pageMarginBg  = Color(0x30C8C8FF);

  // Toolbar
  static const Color toolbarBg     = Color(0xFFFFFFFF);
  static const Color toolbarBorder = Color(0xFFE0E0E0);
}

class TagPlusFonts {
  static const String hebrewPrimary   = 'David';
  static const String hebrewRashi     = 'FrankRuehl';
  static const String hebrewFallback  = 'Noto Sans Hebrew';
  static const String systemFallback  = 'sans-serif';

  static const double sizeFootnote  = 9;
  static const double sizeSmall     = 10;
  static const double sizeBody      = 12;
  static const double sizeMedium    = 14;
  static const double sizeLarge     = 16;
  static const double sizeTitle     = 18;
  static const double sizeH1        = 22;
}

/// ערכת נושא ראשית של תג פלוס
ThemeData buildTagPlusTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TagPlusColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: TagPlusColors.backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: TagPlusColors.toolbarBg,
      foregroundColor: TagPlusColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      color: TagPlusColors.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TagPlusColors.primary,
        foregroundColor: TagPlusColors.textOnPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: TagPlusColors.textDisabled),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: TagPlusColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: TagPlusColors.primary,
      unselectedLabelColor: TagPlusColors.textSecondary,
      indicatorColor: TagPlusColors.primary,
    ),
    dividerTheme: const DividerThemeData(
      color: TagPlusColors.toolbarBorder,
      thickness: 1,
      space: 1,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: TagPlusColors.textPrimary,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    fontFamily: TagPlusFonts.hebrewPrimary,
  );
}
