// ============================================================
// utils/hebrew_utils.dart — עיבוד טקסט עברי
// ============================================================

class HebrewUtils {
  // טווחי Unicode
  static const int _hebrewStart  = 0x05D0;
  static const int _hebrewEnd    = 0x05EA;
  static const int _nikudStart   = 0x05B0;
  static const int _nikudEnd     = 0x05BD;
  static const int _teamimStart  = 0x0591;
  static const int _teamimEnd    = 0x05AF;

  static const Map<String, String> _finalToRegular = {
    'ך': 'כ', 'ם': 'מ', 'ן': 'נ', 'ף': 'פ', 'ץ': 'צ',
  };
  static const Map<String, String> _regularToFinal = {
    'כ': 'ך', 'מ': 'ם', 'נ': 'ן', 'פ': 'ף', 'צ': 'ץ',
  };

  // ── בדיקות ────────────────────────────────────────────────

  static bool isHebrewChar(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return c >= _hebrewStart && c <= _hebrewEnd;
  }

  static bool isHebrew(String text) =>
      text.runes.any((c) => c >= _hebrewStart && c <= _hebrewEnd);

  static bool isNikudChar(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= _nikudStart && c <= _nikudEnd;
  }

  static bool isTaamChar(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= _teamimStart && c <= _teamimEnd;
  }

  static bool hasNikud(String text) =>
      text.runes.any((c) => c >= _nikudStart && c <= _nikudEnd);

  static bool hasTeamim(String text) =>
      text.runes.any((c) => c >= _teamimStart && c <= _teamimEnd);

  // ── הסרה ──────────────────────────────────────────────────

  static String removeNikud(String text) =>
      String.fromCharCodes(text.runes.where(
          (c) => !(c >= _nikudStart && c <= _nikudEnd)));

  static String removeTeamim(String text) =>
      String.fromCharCodes(text.runes.where(
          (c) => !(c >= _teamimStart && c <= _teamimEnd)));

  static String removeNikudAndTeamim(String text) =>
      String.fromCharCodes(text.runes.where((c) =>
          !(c >= _nikudStart && c <= _nikudEnd) &&
          !(c >= _teamimStart && c <= _teamimEnd)));

  static String cleanInvisibleChars(String text) =>
      text.replaceAll('\u200B', '').replaceAll('\u200C', '')
          .replaceAll('\u200D', '').replaceAll('\uFEFF', '');

  static String normalizeSpaces(String text) =>
      text.replaceAll(RegExp(r' {2,}'), ' ')
          .replaceAll(RegExp(r'^ +', multiLine: true), '')
          .replaceAll(RegExp(r' +$', multiLine: true), '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n');

  // ── אותיות סופיות ─────────────────────────────────────────

  static String normalizeFinalLetters(String text) {
    final words = text.split(' ');
    return words.map((word) {
      if (word.isEmpty) return word;
      final chars = word.split('');
      // אמצע מילה: סופית → רגילה
      for (var i = 0; i < chars.length - 1; i++) {
        if (_finalToRegular.containsKey(chars[i])) {
          chars[i] = _finalToRegular[chars[i]]!;
        }
      }
      // סוף מילה: רגילה → סופית
      final last = chars.last;
      if (_regularToFinal.containsKey(last)) {
        chars[chars.length - 1] = _regularToFinal[last]!;
      }
      return chars.join();
    }).join(' ');
  }

  // ── ספירה ─────────────────────────────────────────────────

  static int countWords(String text) {
    final clean = removeNikudAndTeamim(text)
        .replaceAll(RegExp(r'[^\w\s]'), ' ');
    return clean.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && isHebrew(w))
        .length;
  }

  // ── גימטריא ────────────────────────────────────────────────

  static const Map<String, int> _gematria = {
    'א':1, 'ב':2, 'ג':3, 'ד':4, 'ה':5, 'ו':6, 'ז':7, 'ח':8, 'ט':9,
    'י':10, 'כ':20, 'ך':20, 'ל':30, 'מ':40, 'ם':40,
    'נ':50, 'ן':50, 'ס':60, 'ע':70, 'פ':80, 'ף':80,
    'צ':90, 'ץ':90, 'ק':100, 'ר':200, 'ש':300, 'ת':400,
  };

  static int gematria(String text) =>
      removeNikudAndTeamim(text).split('').fold(0,
          (sum, ch) => sum + (_gematria[ch] ?? 0));

  // ── מספרים עבריים ─────────────────────────────────────────

  static String numberToHebrew(int num, {bool useGeresh = true}) {
    if (num <= 0 || num >= 10000) return num.toString();
    const ones    = ['','א','ב','ג','ד','ה','ו','ז','ח','ט'];
    const tens    = ['','י','כ','ל','מ','נ','ס','ע','פ','צ'];
    const hundreds= ['','ק','ר','ש','ת'];

    final parts = <String>[];
    var n = num;

    // מאות
    final h = n ~/ 100;
    if (h > 0) {
      if (h <= 4) { parts.add(hundreds[h]); }
      else        { parts.add(hundreds[4]); parts.add(hundreds[h - 4]); }
      n %= 100;
    }
    // עשרות + אחדות (טו/טז)
    final t = n ~/ 10, o = n % 10;
    if (t == 1 && o == 5)      { parts.add('טו'); }
    else if (t == 1 && o == 6) { parts.add('טז'); }
    else {
      if (t > 0) parts.add(tens[t]);
      if (o > 0) parts.add(ones[o]);
    }

    var result = parts.join();
    if (useGeresh && result.isNotEmpty) {
      result = result.length == 1
          ? "$result'"
          : '${result.substring(0, result.length - 1)}"${result[result.length - 1]}';
    }
    return result;
  }

  static int hebrewToNumber(String text) {
    final cleaned = text.replaceAll('"', '').replaceAll("'", '').replaceAll('׳','');
    return cleaned.split('').fold(0, (sum, ch) => sum + (_gematria[ch] ?? 0));
  }
}
