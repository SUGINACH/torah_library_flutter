// ============================================================
// tag_plus_widget.dart — ווידג'ט ניתן להטמעה
//
// שימוש עצמאי:
//   runApp(ProviderScope(child: TagPlusApp()));
//
// הטמעה כטאב באפליקציה קיימת:
//   TabBarView(children: [
//     OtherTab(),
//     TagPlusWidget(),     // ← פשוט כאן!
//     AnotherTab(),
//   ])
//
// הטמעה עם קולבקים:
//   TagPlusWidget(
//     callbacks: TagPlusCallbacks(
//       onDocumentSaved: (path) => print('Saved: $path'),
//     ),
//     config: TagPlusConfig(defaultFontSize: 14),
//   )
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme_config.dart';
import 'ui/screens/main_screen.dart';

export 'ui/screens/main_screen.dart' show TagPlusCallbacks;

// ── הגדרות התחלתיות ──────────────────────────────────────────

class TagPlusConfig {
  final double  defaultFontSize;
  final String  defaultFontFamily;
  final double  pageWidth;
  final double  pageHeight;
  final bool    showPreviewByDefault;
  final String? initialContent;

  const TagPlusConfig({
    this.defaultFontSize       = 12,
    this.defaultFontFamily     = 'David',
    this.pageWidth             = 170,
    this.pageHeight            = 240,
    this.showPreviewByDefault  = true,
    this.initialContent,
  });

  static const TagPlusConfig defaults = TagPlusConfig();
}

// ── ווידג'ט ניתן להטמעה ──────────────────────────────────────

/// הרכיב המרכזי של תג פלוס — ניתן לשימוש:
///   • כאפליקציה עצמאית
///   • כטאב בתוך TabBarView
///   • כבן של כל Widget
class TagPlusWidget extends StatelessWidget {
  final TagPlusCallbacks? callbacks;
  final TagPlusConfig     config;

  /// האם ליצור ProviderScope חדש.
  /// - `true`  (ברירת מחדל) — כשמשובץ באפליקציה שאין לה ProviderScope
  /// - `false` — כשהאפליקציה המארחת כבר עוטפת ב-ProviderScope
  final bool createScope;

  const TagPlusWidget({
    super.key,
    this.callbacks,
    this.config       = TagPlusConfig.defaults,
    this.createScope  = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = _TagPlusRoot(
      callbacks: callbacks,
      config:    config,
    );

    if (createScope) {
      return ProviderScope(child: child);
    }
    return child;
  }
}

// ── שורש פנימי (בתוך ProviderScope) ─────────────────────────

class _TagPlusRoot extends StatelessWidget {
  final TagPlusCallbacks? callbacks;
  final TagPlusConfig     config;

  const _TagPlusRoot({required this.callbacks, required this.config});

  @override
  Widget build(BuildContext context) {
    // בדוק אם כבר בתוך MaterialApp (הטמעה כטאב)
    final hasTheme = Theme.of(context).platform != null;

    if (hasTheme) {
      // הטמעה בתוך אפליקציה קיימת — אל תיצור MaterialApp חדש
      return Theme(
        data: buildTagPlusTheme(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MainScreen(callbacks: callbacks),
        ),
      );
    }

    // עצמאי — עם MaterialApp משלנו
    return MaterialApp(
      title:        'תג פלוס',
      debugShowCheckedModeBanner: false,
      theme:        buildTagPlusTheme(),
      locale:       const Locale('he', 'IL'),
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: MainScreen(callbacks: callbacks),
    );
  }
}

// ── גרסת App עצמאית (נוחות) ──────────────────────────────────

/// גרסה נוחה להפעלה עצמאית
class TagPlusApp extends StatelessWidget {
  final TagPlusCallbacks? callbacks;
  final TagPlusConfig     config;

  const TagPlusApp({
    super.key,
    this.callbacks,
    this.config = TagPlusConfig.defaults,
  });

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: TagPlusWidget(
      callbacks:   callbacks,
      config:      config,
      createScope: false,  // ProviderScope כבר עוטף
    ),
  );
}
