// lib/themes/app_palette.dart
//
// Flutter equivalent of the colour system in themes.py.
//
// Python side:
//   theme_palette(key)        → dict[css_var → qt_key]
//   build_stylesheet(palette) → Qt stylesheet string
//
// Flutter side:
//   AppPalette                → typed colour record (one per theme)
//   ThemeProvider             → ChangeNotifier; call applyTheme(key) to switch
//
// Usage — inject once at the root of your app:
//
//   ChangeNotifierProvider(
//     create: (_) => ThemeProvider()
//       ..loadThemesJson(jsonDecode(themesJsonString)),
//     child: ...,
//   )
//
// Then anywhere:
//   final palette = context.watch<ThemeProvider>().palette;

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


// ═══════════════════════════════════════════════════════════════════════════════
// AppPalette — all colour tokens, mirroring _CSS_MAP in themes.py
// ═══════════════════════════════════════════════════════════════════════════════

class AppPalette {
  // Direct equivalents of the CSS variables mapped in themes.py _CSS_MAP
  final Color background;    // --bg-app-main
  final Color borderColor;   // --border-frame-main
  final Color accent;        // --accent-gold-main
  final Color accentLight;   // --accent-gold-light
  final Color textPrimary;   // --text-primary
  final Color textSecondary; // --text-secondary
  final Color textMuted;     // --text-muted
  final Color panelLight;    // --bg-panel-light
  final Color panelTan;      // --bg-panel-tan
  final Color itemHover;     // --bg-item-hover
  final Color inputBorder;   // --border-input-light
  final Color tabActive;     // --bg-tab-active
  final Color headerGold;    // --bg-header-gold
  final Color hitSnippet;    // --bg-hit-snippet
  final Color highlight;     // --highlight-gold
  final Color divider;       // --border-divider-light
  final Color sidebarActive; // --bg-sidebar-active

  const AppPalette({
    required this.background,
    required this.borderColor,
    required this.accent,
    required this.accentLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.panelLight,
    required this.panelTan,
    required this.itemHover,
    required this.inputBorder,
    required this.tabActive,
    required this.headerGold,
    required this.hitSnippet,
    required this.highlight,
    required this.divider,
    required this.sidebarActive,
  });

  // ── Default "classic" values ───────────────────────────────────────────────
  // These match the fallback literals in build_stylesheet() in themes.py.

  static const AppPalette classic = AppPalette(
    background:    Color(0xFFFFFCF5),
    borderColor:   Color(0xFF5F4030),
    accent:        Color(0xFFD9B13E),
    accentLight:   Color(0xFFEDDAA7),
    textPrimary:   Color(0xFF2C2118),
    textSecondary: Color(0xFF5C4A38),
    textMuted:     Color(0xFF777777),
    panelLight:    Color(0xFFF7F7F7),
    panelTan:      Color(0xFFE7D3A4),
    itemHover:     Color(0xFFEFD8A8),
    inputBorder:   Color(0xFFC9B88A),
    tabActive:     Color(0xBFD9B13E),
    headerGold:    Color(0xFFF0E4C8),
    hitSnippet:    Color(0xFFFAFAFA),
    highlight:     Color(0xFFD9B13E),
    divider:       Color(0xFFF0E0B0),
    sidebarActive: Color(0xFFEFD8A8),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ThemeProvider — mirrors _select_theme / _apply_theme in main_window.py
// ═══════════════════════════════════════════════════════════════════════════════

class ThemeProvider extends ChangeNotifier {
  AppPalette _palette = AppPalette.classic;
  String _themeKey = 'classic';
  Map<String, dynamic> _availableThemes = {};

  AppPalette get palette => _palette;
  String get themeKey => _themeKey;

  /// All theme keys → display names (for building the theme menu).
  Map<String, String> get themeNames => {
        for (final e in _availableThemes.entries)
          e.key: (e.value['name'] as String?) ?? e.key,
      };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once at startup with the decoded contents of themes.json.
  /// Mirrors load_themes() in themes.py.
  void loadThemesJson(Map<String, dynamic> themes) {
    _availableThemes = themes;
    applyTheme(_themeKey);
  }

  /// Switch to [key].  Mirrors _select_theme() + _apply_theme() + theme_palette().
  void applyTheme(String key) {
    final entry = _availableThemes[key] ?? _availableThemes['classic'];
    if (entry == null) {
      _themeKey = 'classic';
      _palette = AppPalette.classic;
      notifyListeners();
      return;
    }
    final colors = entry['colors'] as Map<String, dynamic>? ?? {};
    _themeKey = key;
    _palette = AppPalette(
      background:    _hex(colors['--bg-app-main'],          AppPalette.classic.background),
      borderColor:   _hex(colors['--border-frame-main'],    AppPalette.classic.borderColor),
      accent:        _hex(colors['--accent-gold-main'],     AppPalette.classic.accent),
      accentLight:   _hex(colors['--accent-gold-light'],    AppPalette.classic.accentLight),
      textPrimary:   _hex(colors['--text-primary'],         AppPalette.classic.textPrimary),
      textSecondary: _hex(colors['--text-secondary'],       AppPalette.classic.textSecondary),
      textMuted:     _hex(colors['--text-muted'],           AppPalette.classic.textMuted),
      panelLight:    _hex(colors['--bg-panel-light'],       AppPalette.classic.panelLight),
      panelTan:      _hex(colors['--bg-panel-tan'],         AppPalette.classic.panelTan),
      itemHover:     _hex(colors['--bg-item-hover'],        AppPalette.classic.itemHover),
      inputBorder:   _hex(colors['--border-input-light'],   AppPalette.classic.inputBorder),
      tabActive:     _hex(colors['--bg-tab-active'],        AppPalette.classic.tabActive),
      headerGold:    _hex(colors['--bg-header-gold'],       AppPalette.classic.headerGold),
      hitSnippet:    _hex(colors['--bg-hit-snippet'],       AppPalette.classic.hitSnippet),
      highlight:     _hex(colors['--highlight-gold'],       AppPalette.classic.highlight),
      divider:       _hex(colors['--border-divider-light'], AppPalette.classic.divider),
      sidebarActive: _hex(colors['--bg-sidebar-active'],    AppPalette.classic.sidebarActive),
    );
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Parse a CSS hex color string (#RGB / #RRGGBB / #RRGGBBAA).
  static Color _hex(dynamic cssVal, Color fallback) {
    if (cssVal is! String) return fallback;
    final s = cssVal.trim();
    if (!s.startsWith('#')) return fallback;
    final h = s.substring(1);
    try {
      if (h.length == 3) {
        final r = h[0];
        final g = h[1];
        final b = h[2];
        return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
      }
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      if (h.length == 8) return Color(int.parse(h, radix: 16));
    } catch (_) {}
    return fallback;
  }
  double _globalFontSize = 14.0;
  String _globalFontFamily = 'Segoe UI';

  double get globalFontSize => _globalFontSize;
  String get globalFontFamily => _globalFontFamily;

  // פונקציה לשמירה ועדכון עיצוב מותאם אישית
  Future<void> updateCustomAppearance({
    Color? accent,
    Color? background,
    Color? textPrimary,
    double? fontSize,
    String? fontFamily,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // עדכון הפלטה הנוכחית עם הערכים החדשים (אפשר להרחיב לעוד צבעים)
    _palette = AppPalette(
      background: background ?? _palette.background,
      borderColor: _palette.borderColor,
      accent: accent ?? _palette.accent,
      accentLight: _palette.accentLight,
      textPrimary: textPrimary ?? _palette.textPrimary,
      textSecondary: _palette.textSecondary,
      textMuted: _palette.textMuted,
      panelLight: background != null ? background.withValues(alpha: 0.95) : _palette.panelLight,
      panelTan: _palette.panelTan,
      itemHover: accent != null ? accent.withValues(alpha: 0.2) : _palette.itemHover,
      inputBorder: _palette.inputBorder,
      tabActive: accent != null ? accent.withValues(alpha: 0.8) : _palette.tabActive,
      headerGold: _palette.headerGold,
      hitSnippet: _palette.hitSnippet,
      highlight: accent ?? _palette.highlight,
      divider: _palette.divider,
      sidebarActive: _palette.sidebarActive,
    );

    if (fontSize != null) _globalFontSize = fontSize;
    if (fontFamily != null) _globalFontFamily = fontFamily;

    // שמירה בזיכרון המכשיר כדי שיטען בהפעלה הבאה
    await prefs.setString('custom_appearance', jsonEncode({
      'accent': accent?.value,
      'background': background?.value,
      'textPrimary': textPrimary?.value,
      'fontSize': _globalFontSize,
      'fontFamily': _globalFontFamily,
    }));

    // מודיע לכל האפליקציה להתרענן - פעם אחת בלבד!
    notifyListeners();
  }

  // כדי לטעון את זה בתחילת האפליקציה (ניתן לקרוא לזה מ-main.dart)
  Future<void> loadCustomAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('custom_appearance');
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      updateCustomAppearance(
        accent: data['accent'] != null ? Color(data['accent']) : null,
        background: data['background'] != null ? Color(data['background']) : null,
        textPrimary: data['textPrimary'] != null ? Color(data['textPrimary']) : null,
        fontSize: data['fontSize'],
        fontFamily: data['fontFamily'],
      );
    }
  }
}
