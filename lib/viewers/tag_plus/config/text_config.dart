// ============================================================
// config/text_config.dart — תגיות טקסט, סוגי עימוד
// ============================================================

/// תגיות סימון
class TextTags {
  static const String title      = '@כותרת';
  static const String subtitle   = '@תת-כותרת';
  static const String chapter    = '@פרק';
  static const String section    = '@סימן';
  static const String subsection = '@סעיף';
  static const String mainText   = '@טקסט-ראשי';
  static const String commentary = '@פירוש';
  static const String footnote   = '@הערה';
  static const String quote      = '@ציטוט';
  static const String rashi      = '@רשי';
  static const String tosafot    = '@תוספות';
  static const String bold       = '@מודגש';
  static const String italic     = '@נטוי';
  static const String pageBreak  = '@מעבר-עמוד';
  static const String anchor     = '@עוגן';
  static const String indexMark  = '@מפתח';
  static const String crossRef   = '@הפניה';
}

/// טווחי Unicode לניקוד וטעמים
class HebrewRanges {
  static const int hebrewLetterStart = 0x05D0;  // א
  static const int hebrewLetterEnd   = 0x05EA;  // ת
  static const int nikudStart        = 0x05B0;  // שווא
  static const int nikudEnd          = 0x05BD;  // מתג
  static const int teamimStart       = 0x0591;  // אתנחתא
  static const int teamimEnd         = 0x05AF;
  static const int sofPasuq          = 0x05C3;
}

/// מצבי פריסת רב-טקסט
enum MultiTextMode {
  single,
  twoColumn,
  threeColumn,
  gemara,
  mikraot,
  custom,
}

/// סוגי תיבות טקסט בפריסה
enum TextBoxType {
  main,
  rashi,
  tosafot,
  commentary,
  footnote,
  header,
  footer,
  custom,
}

/// סוג יישור טקסט
enum TagTextAlignment { right, left, center, justify }
