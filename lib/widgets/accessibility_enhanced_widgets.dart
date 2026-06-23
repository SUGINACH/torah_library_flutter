// lib/widgets/accessibility_enhanced_widgets.dart
// שיפור #5: נגישות משופרת

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

// Widget טקסט עם תמיכה מלאה בנגישות
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? semanticsLabel;
  final bool? excludeSemantics;
  
  const AccessibleText({
    super.key,
    required this.text,
    this.style,
    this.textDirection,
    this.maxLines,
    this.overflow,
    this.semanticsLabel,
    this.excludeSemantics,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? text,
      excludeSemantics: excludeSemantics,
      child: Text(
        text,
        style: style,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

// כפתור עם נגישות משופרת
class AccessibleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? semanticsHint;
  final String? semanticsLabel;
  final bool? isFocused;
  
  const AccessibleButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.semanticsHint,
    this.semanticsLabel,
    this.isFocused,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel,
      hint: semanticsHint,
      focus: isFocused,
      child: ElevatedButton(
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

// Slider עם נגישות משופרת
class AccessibleSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String? semanticsLabel;
  final String? semanticsValue;
  
  const AccessibleSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.onChanged,
    this.semanticsLabel,
    this.semanticsValue,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: semanticsLabel,
      value: semanticsValue ?? value.toStringAsFixed(1),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

// Container עם נגישות והתאמות צבעים לניגודיות
class AccessibleContainer extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final String? semanticsLabel;
  final bool? isSelected;
  
  const AccessibleContainer({
    super.key,
    required this.child,
    required this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.0,
    this.borderRadius,
    this.padding,
    this.semanticsLabel,
    this.isSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    // חישוב ניגודיות אוטומטי
    final contrast = _calculateContrastRatio(backgroundColor);
    final needsBorder = contrast < 4.5 && borderColor == null;
    
    return Semantics(
      label: semanticsLabel,
      selected: isSelected,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: needsBorder || borderWidth > 0
              ? Border.all(
                  color: borderColor ?? _getAccessibleBorderColor(backgroundColor),
                  width: needsBorder ? 2.0 : borderWidth,
                )
              : null,
          borderRadius: borderRadius,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
  
  double _calculateContrastRatio(Color background) {
    // חישוב יחס ניגודיות לפי WCAG 2.0
    final luminance = background.computeLuminance();
    return (luminance + 0.05) / 0.05;
  }
  
  Color _getAccessibleBorderColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

// Card עם נגישות משופרת
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String? semanticsLabel;
  final String? semanticsHint;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  
  const AccessibleCard({
    super.key,
    required this.child,
    this.semanticsLabel,
    this.semanticsHint,
    this.color,
    this.margin,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      hint: semanticsHint,
      child: Card(
        color: color,
        margin: margin,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// Helper לחישוב ניגודיות צבעים
class AccessibilityUtils {
  static double calculateContrastRatio(Color color1, Color color2) {
    final l1 = color1.computeLuminance();
    final l2 = color2.computeLuminance();
    
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    
    return (lighter + 0.05) / (darker + 0.05);
  }
  
  static bool isAccessibleContrast(Color foreground, Color background) {
    return calculateContrastRatio(foreground, background) >= 4.5;
  }
  
  static Color getAccessibleTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
  
  static List<String> generateAccessibilityReport(Map<String, dynamic> settings) {
    final report = <String>[];
    
    // בדיקת גודל גופן
    final fontSize = settings['fontSize'] as double?;
    if (fontSize != null) {
      if (fontSize < 14) {
        report.add('⚠️ גודל הגופן קטן מ-14px - עשוי להיות קריא עבור חלק מהמשתמשים');
      } else if (fontSize >= 18) {
        report.add('✅ גודל הגופן תומך בקריאה נוחה');
      }
    }
    
    // בדיקת ניגודיות
    final bgColor = settings['backgroundColor'] as Color?;
    final textColor = settings['textColor'] as Color?;
    
    if (bgColor != null && textColor != null) {
      final contrast = calculateContrastRatio(textColor, bgColor);
      if (contrast >= 7.0) {
        report.add('✅ ניגודיות מצוינת (${contrast.toStringAsFixed(2)}:1)');
      } else if (contrast >= 4.5) {
        report.add('✅ ניגודיות טובה (${contrast.toStringAsFixed(2)}:1)');
      } else if (contrast >= 3.0) {
        report.add('⚠️ ניגודיות בינונית (${contrast.toStringAsFixed(2)}:1) - מתאים רק לטקסט גדול');
      } else {
        report.add('❌ ניגודיות נמוכה (${contrast.toStringAsFixed(2)}:1) - לא עומד בתקני נגישות');
      }
    }
    
    // בדיקת אנימציות
    final animationsEnabled = settings['enableAnimations'] as bool?;
    if (animationsEnabled == false) {
      report.add('✅ אנימציות מבוטלות - מתאים למשתמשים רגישי לתנועה');
    }
    
    return report;
  }
}

// Screen Reader Announcements
class AccessibilityAnnouncer {
  static void announce(BuildContext context, String message, {bool assertiveness = false}) {
    SemanticsService.announce(message, Directionality.of(context), 
        assertiveness: assertiveness ? Assertiveness.assertive : Assertiveness.polite);
  }
  
  static void announceFontSizeChange(double newSize) {
    // הכרזה על שינוי גודל גופן
    final message = 'גודל הגופן שונה ל-${newSize.toInt()} פיקסלים';
    // יש לקרוא לזה עם BuildContext מתאים
  }
  
  static void announceSettingsSaved() {
    final message = 'ההגדרות נשמרו בהצלחה';
  }
  
  static void announceProfileLoaded(String profileName) {
    final message = 'הפרופיל $profileName נטען';
  }
}
