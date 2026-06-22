// ============================================================
// features/bibliography/bibliography_engine.dart
// מנוע ביבליוגרפי — ר"ת + ציטוטים תורניים
// ============================================================

const Map<String, String> kAbbreviations = {
  'שו"ע': 'שולחן ערוך',      'ש"ע': 'שולחן ערוך',
  'רמב"ם': 'משנה תורה',      'ב"י': 'בית יוסף',
  'ב"ח': 'בית חדש',          'ט"ז': 'טורי זהב',
  'ש"ך': 'שפתי כהן',         'מ"ב': 'משנה ברורה',
  'מג"א': 'מגן אברהם',       'פמ"ג': 'פרי מגדים',
  'א"ר': 'אליה רבה',         'ר"ן': 'רבינו נסים',
  'ריב"ש': 'ריב"ש',          'רשב"א': 'רשב"א',
  'רשב"ם': 'רשב"ם',          'ראב"ד': 'ראב"ד',
  'רא"ש': 'רא"ש',            'סמ"ג': 'ספר מצוות גדול',
  "תוס'": 'תוספות',          'רש"י': 'רש"י',
  'ח"א': 'חיי אדם',          'ח"ח': 'חפץ חיים',
  'ב"ה': 'בית הלוי',
  // חלקי שו"ע
  'או"ח': 'אורח חיים',       'יו"ד': 'יורה דעה',
  'אה"ע': 'אבן העזר',        'חו"מ': 'חושן משפט',
  // ביטויים
  "סי'": 'סימן',             'ס"ק': 'סעיף קטן',
  "ס'": 'סעיף',              "פ'": 'פרק',
  "ה'": 'הלכה',              'ד"ה': 'דיבור המתחיל',
  "עמ'": 'עמוד',             'ע"א': 'עמוד א',
  'ע"ב': 'עמוד ב',           'ז"ל': 'זכרונו לברכה',
  'זצ"ל': 'זכר צדיק לברכה',  'נ"י': 'נרו יאיר',
};

class TorahCitation {
  final String raw;
  final String bookName;
  final String section;
  final String chapter;
  final String clause;
  final String subClause;
  final double confidence;
  final int    startPos;
  final int    endPos;

  const TorahCitation({
    required this.raw,
    required this.bookName,
    this.section   = '',
    this.chapter   = '',
    this.clause    = '',
    this.subClause = '',
    this.confidence = 0.85,
    this.startPos  = 0,
    this.endPos    = 0,
  });

  String get fullCitation {
    final parts = [kAbbreviations[bookName] ?? bookName];
    if (section.isNotEmpty)   parts.add(kAbbreviations[section]  ?? section);
    if (chapter.isNotEmpty)   parts.add("סי' $chapter");
    if (clause.isNotEmpty)    parts.add("ס' $clause");
    if (subClause.isNotEmpty) parts.add('ס"ק $subClause');
    return parts.join(' ');
  }
}

class BibliographyEngine {
  final Map<String, String> _customAbbrevs = {};
  Map<String, String> get allAbbrevs => {...kAbbreviations, ..._customAbbrevs};

  // ── ר"ת ───────────────────────────────────────────────────

  String expand(String abbrev) =>
      allAbbrevs[abbrev] ?? abbrev;

  void addCustomAbbrev(String abbrev, String full) =>
      _customAbbrevs[abbrev] = full;

  String expandAllInText(String text) {
    var result = text;
    for (final entry in (allAbbrevs.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length)))) {
      result = result.replaceAll(entry.key, '${entry.key} (${entry.value})');
    }
    return result;
  }

  // ── ניתוח ציטוטים ─────────────────────────────────────────

  static final _patterns = <RegExp>[
    // שו"ע / ב"י / ט"ז + חלק + סימן + סעיף
    RegExp(
      r'(שו"ע|ש"ע|ב"י|ב"ח|ט"ז|ש"ך|מ"ב|מג"א|פמ"ג)'
      r'(?:\s+(או"ח|יו"ד|אה"ע|חו"מ))?'
      r'''(?:\s+(?:סי'|סימן)\s*([א-ת'"״0-9]+))?'''
      r'''(?:\s+(?:ס'|סעיף)\s*([א-ת'"״0-9]+))?'''
      r'''(?:\s+(?:ס"ק)\s*([א-ת'"״0-9]+))?''',
      unicode: true,
    ),
    // רמב"ם הל' + פרק
    RegExp(
      r'''רמב"ם\s+הל'\s+([א-ת\s]+?)(?:\s+פ'\s*([א-ת'"0-9]+))?''',
      unicode: true,
    ),
    // גמרא: מסכת + דף
    RegExp(
      r'(ברכות|שבת|עירובין|פסחים|יומא|סוכה|ביצה|'
      r'בבא קמא|בבא מציעא|בבא בתרא|סנהדרין|מכות|'
      r'גיטין|קידושין|נדרים|כתובות|יבמות|נדה|'
      r'חולין|מנחות|זבחים|בכורות)'
      r'''\s+(?:דף\s+)?([א-ת'"0-9]+)''',
      unicode: true,
    ),
  ];

  List<TorahCitation> parseCitations(String text) {
    final results = <TorahCitation>[];
    for (final rx in _patterns) {
      for (final m in rx.allMatches(text)) {
        final book = (m.group(1) ?? '').trim();
        if (book.isEmpty) continue;
        results.add(TorahCitation(
          raw: m.group(0)!,
          bookName: book,
          section:   (m.groupCount >= 2 ? m.group(2) : null) ?? '',
          chapter:   (m.groupCount >= 3 ? m.group(3) : null) ?? '',
          clause:    (m.groupCount >= 4 ? m.group(4) : null) ?? '',
          subClause: (m.groupCount >= 5 ? m.group(5) : null) ?? '',
          startPos:  m.start,
          endPos:    m.end,
        ));
      }
    }
    // מיון + ביטול חפיפות
    results.sort((a, b) => a.startPos.compareTo(b.startPos));
    return _deduplicate(results);
  }

  List<TorahCitation> _deduplicate(List<TorahCitation> list) {
    final unique = <TorahCitation>[];
    for (final c in list) {
      final overlaps = unique.any(
          (u) => u.startPos <= c.startPos && c.startPos < u.endPos);
      if (!overlaps) unique.add(c);
    }
    return unique;
  }

  // ── ביבליוגרפיה ───────────────────────────────────────────

  String buildBibliography(List<TorahCitation> citations) {
    final seen = <String>{};
    final books = <String>[];
    for (final c in citations) {
      if (seen.add(c.bookName)) {
        books.add(kAbbreviations[c.bookName] ?? c.bookName);
      }
    }
    books.sort();
    return books.map((b) => '• $b').join('\n');
  }

  List<String> suggest(String partial) =>
      allAbbrevs.entries
          .where((e) => e.key.contains(partial) || e.value.contains(partial))
          .map((e) => '${e.key} — ${e.value}')
          .take(10)
          .toList();
}