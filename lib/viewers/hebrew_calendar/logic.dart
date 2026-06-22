/// logic.dart
/// ─────────────────────────────────────────────────────────────────────────
/// Hebrew calendar algorithm + astronomical zmanim engine + location model.
/// Ported 1-to-1 from calendar_widget.py — all calculations are IDENTICAL.
/// Pure Dart: no Flutter dependency. Safe to import in non-Flutter projects.
///
/// Public surface:
///   g2j / j2g / j2h / h2j / g2h / h2g — Gregorian ↔ Julian Day ↔ Hebrew
///   getEvents(jdn, israel)             — list of HebrewEvent for a JDN
///   Zmanim(date, location, [dstExtra]) — all halachic times for a day
///   HalachicLocation                  — location data class
///   kIsraelLocs / kWorldLocs           — built-in location lists
///   israelDst(date)                    — Israeli DST auto-detection
///   hNum / hYear / hDateStr            — Hebrew numeral formatting
///   yearType / daysInYear / ...        — year info helpers
library;
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 1 — HEBREW CALENDAR ALGORITHM
//  Pure Dart, no external dependencies.
//  Verified accurate for Hebrew years 5700–5900 AM (1940–2140 CE).
// ═══════════════════════════════════════════════════════════════════════════

const int _kEpoch = 347998; // JDN of 1 Tishri, year 1 AM

const List<String> kMnReg = [
  '', 'תשרי', 'חשוון', 'כסלו', 'טבת', 'שבט',
  'אדר', 'ניסן', 'אייר', 'סיוון', 'תמוז', 'אב', 'אלול',
];
const List<String> kMnLeap = [
  '', 'תשרי', 'חשוון', 'כסלו', 'טבת', 'שבט',
  'אדר א׳', 'אדר ב׳', 'ניסן', 'אייר', 'סיוון', 'תמוז', 'אב', 'אלול',
];
const List<String> kGregMonths = [
  '', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
  'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
];
const List<String> kDowHeb = [
  'ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת',
]; // index 0 = Sunday

const List<String> _kOnes = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
const List<String> _kTens = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];

// ── Hebrew numerals ───────────────────────────────────────────────────────

String _hLetters(int n) {
  if (n == 15) return 'טו';
  if (n == 16) return 'טז';
  var s = '';
  var r = n;
  for (final pair in [
    (400, 'ת'),
    (300, 'ש'),
    (200, 'ר'),
    (100, 'ק'),
  ]) {
    while (r >= pair.$1) {
      s += pair.$2;
      r -= pair.$1;
    }
  }
  if (r >= 10) {
    s += _kTens[r ~/ 10];
    r %= 10;
  }
  if (r > 0) s += _kOnes[r];
  return s;
}

String hNum(int n) {
  final s = _hLetters(n);
  if (s.isEmpty) return '';
  return s.length == 1
      ? '$s׳'
      : '${s.substring(0, s.length - 1)}״${s[s.length - 1]}';
}

String hYear(int y) {
  final k = y ~/ 1000;
  final r = y % 1000;
  return (k > 0 ? '${_kOnes[k]}׳' : '') + hNum(r);
}

String hDateStr(int y, int m, int d) => '${hNum(d)} ${monthName(m, y)} ${hYear(y)}';

// ── Year arithmetic ───────────────────────────────────────────────────────

bool isLeap(int y) => (7 * y + 1) % 19 < 7;
int numMonths(int y) => isLeap(y) ? 13 : 12;

int _elapsed(int y) {
  final m = (235 * y - 234) ~/ 19;
  final p = 12084 + 13753 * m;
  var d = 29 * m + p ~/ 25920;
  if ((3 * (d + 1)) % 7 < 3) d++;
  return d;
}

int _delay(int y) {
  final n0 = _elapsed(y - 1), n1 = _elapsed(y), n2 = _elapsed(y + 1);
  if (n2 - n1 == 356) return 2;
  if (n1 - n0 == 382) return 1;
  return 0;
}

int newYear(int y) => _kEpoch + _elapsed(y) + _delay(y);
int daysInYear(int y) => newYear(y + 1) - newYear(y);
bool longCheshvan(int y) => daysInYear(y) % 10 == 5;
bool shortKislev(int y) => daysInYear(y) % 10 == 3;

String yearType(int y) {
  final d = daysInYear(y);
  return const {
        353: 'חסרה',
        354: 'כסדרה',
        355: 'שלמה',
        383: 'מעוברת חסרה',
        384: 'מעוברת כסדרה',
        385: 'מעוברת שלמה',
      }[d] ??
      '$d ימים';
}

// ── Month arithmetic ──────────────────────────────────────────────────────

/// Days in Hebrew month m of year y.
/// Month numbering: 1=Tishri, 2=Cheshvan, 3=Kislev, 4=Tevet, 5=Shevat,
///   6=Adar/AdarI, [7=AdarII in leap], 7/8=Nisan, …, 12/13=Elul.
int daysInMonth(int m, int y) {
  final lp = isLeap(y);
  switch (m) {
    case 1:  return 30;
    case 2:  return longCheshvan(y) ? 30 : 29;
    case 3:  return shortKislev(y) ? 29 : 30;
    case 4:  return 29;
    case 5:  return 30;
    case 6:  return lp ? 30 : 29;
    case 7:  return lp ? 29 : 30;
    case 8:  return lp ? 30 : 29;
    case 9:  return lp ? 29 : 30;
    case 10: return lp ? 30 : 29;
    case 11: return lp ? 29 : 30;
    case 12: return lp ? 30 : 29;
    case 13: return 29;
    default: return 29;
  }
}

String monthName(int m, int y) => (isLeap(y) ? kMnLeap : kMnReg)[m];

// Month number helpers (same as Python m_nisan, m_iyar, …)
int mNisan(int y) => isLeap(y) ? 8 : 7;
int mIyar(int y) => isLeap(y) ? 9 : 8;
int mSivan(int y) => isLeap(y) ? 10 : 9;
int mTamuz(int y) => isLeap(y) ? 11 : 10;
int mAv(int y) => isLeap(y) ? 12 : 11;
int mAdar(int y) => isLeap(y) ? 7 : 6; // "real" Adar (AdarII in leap)

// ── JDN ↔ Gregorian ──────────────────────────────────────────────────────

int g2j(int Y, int M, int D) {
  final a = (14 - M) ~/ 12;
  final y = Y + 4800 - a;
  final m = M + 12 * a - 3;
  return D + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
}

(int, int, int) j2g(int j) {
  final a = j + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - 146097 * b ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - 1461 * d ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  return (
    100 * b + d - 4800 + m ~/ 10,
    m + 3 - 12 * (m ~/ 10),
    e - (153 * m + 2) ~/ 5 + 1,
  );
}

// ── JDN ↔ Hebrew ─────────────────────────────────────────────────────────

(int, int, int) j2h(int j) {
  var y = ((j - _kEpoch) * 98496.0 / 35975351.0).toInt() + 1;
  while (newYear(y + 1) <= j) {
    y++;
  }
  while (newYear(y) > j) {
    y--;
  }
  final doy = j - newYear(y) + 1;
  var m = 1, acc = 0;
  while (m <= numMonths(y)) {
    final dim = daysInMonth(m, y);
    if (acc + dim >= doy) break;
    acc += dim;
    m++;
  }
  return (y, m, doy - acc);
}

int h2j(int y, int m, int d) {
  var j = newYear(y) + d - 1;
  for (var i = 1; i < m; i++) {
    j += daysInMonth(i, y);
  }
  return j;
}

// ── Combined conversions ──────────────────────────────────────────────────

(int, int, int) g2h(int Y, int M, int D) => j2h(g2j(Y, M, D));
(int, int, int) h2g(int y, int m, int d) => j2g(h2j(y, m, d));

/// Day-of-week: 0 = Sunday, 1 = Monday, …, 6 = Saturday.
int jdnDow(int j) => (j + 1) % 7;

int dateToJdn(DateTime d) => g2j(d.year, d.month, d.day);

// ── Fast-day / holiday JDN helpers ───────────────────────────────────────

int _jTzomGedaliah(int y) {
  final j = h2j(y, 1, 3);
  return jdnDow(j) == 6 ? j + 1 : j; // postpone from Shabbat to Sunday
}

int _jTanitEsther(int y) {
  final j = h2j(y, mAdar(y), 13);
  return jdnDow(j) == 6 ? j - 2 : j; // Shabbat → Thursday
}

int _j17Tamuz(int y) {
  final j = h2j(y, mTamuz(y), 17);
  return jdnDow(j) == 6 ? j + 1 : j;
}

int _j9Av(int y) {
  final j = h2j(y, mAv(y), 9);
  return jdnDow(j) == 6 ? j + 1 : j;
}

int _jYomHashoah(int y) {
  final j0 = h2j(y, mNisan(y), 27);
  final dw = jdnDow(j0);
  if (dw == 5) return j0 - 1; // Friday → Thursday
  if (dw == 0) return j0 + 1; // Sunday → Monday
  return j0;
}

int _jYomHaatzmaut(int y) {
  final j0 = h2j(y, mIyar(y), 5);
  final dw = jdnDow(j0);
  if (dw == 5) return j0 - 1; // Friday → Thursday
  if (dw == 6) return j0 - 2; // Saturday → Thursday
  if (dw == 0) return j0 + 2; // Sunday → Tuesday
  // This branch is mathematically unreachable (dw==4 → j0-1 has dw==3, never in {4,5})
  // Kept verbatim from Python for faithfulness:
  if (dw == 4 && {4, 5}.contains(jdnDow(j0 - 1))) return j0 - 1;
  return j0;
}

int _jYomHazikaron(int y) => _jYomHaatzmaut(y) - 1;

// ── Omer ─────────────────────────────────────────────────────────────────

int _omerDay(int j, int y) => j - h2j(y, mNisan(y), 16) + 1;

String? omerStr(int day) {
  if (day < 1 || day > 49) return null;
  final w = day ~/ 7, d = day % 7;
  var s = 'יום ${hNum(day)} לעומר';
  if (w > 0 && d > 0) {
    s += ' (${hNum(w)} שבועות ו${hNum(d)} ימים)';
  } else if (w > 0) {
    s += ' (${hNum(w)} שבועות שלמים)';
  }
  return s;
}

// ── Event types ───────────────────────────────────────────────────────────

class HebrewEvent {
  final String name;
  final String kind; // one of the keys used in kEvColorData
  const HebrewEvent(this.name, this.kind);
}

/// (bg ARGB int, fg ARGB int) for each event kind.
/// Import as Color(kEvColorData['yomTov']!.$1) in Flutter.
const Map<String, (int, int)> kEvColorData = {
  'yomTov':         (0xFFFDF3D0, 0xFF7A5200),
  'yomKippur':      (0xFFF8D8D8, 0xFF6B0000),
  'taanit':         (0xFFEEDEDE, 0xFF8B1A1A),
  'cholHaMoed':     (0xFFFEF7E0, 0xFF7A5200),
  'chanukah':       (0xFFDCE8F8, 0xFF1A3D6B),
  'special':        (0xFFDFF0E0, 0xFF2D5A27),
  'memorial':       (0xFFE8E8E8, 0xFF3A3A3A),
  'roshChodesh':    (0xFFE0EAFF, 0xFF1A3D6B),
  'yomTovDiaspora': (0xFFFFF8D0, 0xFF7A5200),
  'omer':           (0xFFEFFFEC, 0xFF2D5A27),
  'shabbat':        (0xFFEDE8F8, 0xFF4A1A6B),
};

/// Returns all Hebrew events for a given Julian Day Number.
/// Pass [israel]=true for Israeli 1-day yom tov, false for Diaspora 2-day.
List<HebrewEvent> getEvents(int jdn, bool israel) {
  final (y, m, d) = j2h(jdn);
  final lp = isLeap(y);
  final nisn = mNisan(y), iyar = mIyar(y), sivan = mSivan(y);
  final tamuz = mTamuz(y), av = mAv(y), adar = mAdar(y);
  final ev = <HebrewEvent>[];

  // ── Rosh Chodesh ──────────────────────────────────────────────────────
  if (d == 1 && m != 1) {
    ev.add(HebrewEvent('ראש חודש ${monthName(m, y)}', 'roshChodesh'));
  }
  if (d == 30) {
    final nm2 = m < numMonths(y) ? m + 1 : 1;
    final ny2 = m < numMonths(y) ? y : y + 1;
    ev.add(HebrewEvent('ראש חודש ${monthName(nm2, ny2)}', 'roshChodesh'));
  }

  // ── Tishri ────────────────────────────────────────────────────────────
  if (m == 1) {
    if (d == 1) ev.add(const HebrewEvent('ראש השנה א׳', 'yomTov'));
    if (d == 2) ev.add(const HebrewEvent('ראש השנה ב׳', 'yomTov'));
    if (jdn == _jTzomGedaliah(y)) ev.add(const HebrewEvent('צום גדליה', 'taanit'));
    if (d == 10) ev.add(const HebrewEvent('יום כיפור', 'yomKippur'));
    if (d == 15) ev.add(const HebrewEvent('סוכות א׳', 'yomTov'));
    if (d == 16) {
      ev.add(HebrewEvent(
        israel ? 'חול המועד סוכות' : 'סוכות ב׳',
        israel ? 'cholHaMoed' : 'yomTovDiaspora',
      ));
    }
    if (d >= 17 && d <= 20) ev.add(const HebrewEvent('חול המועד סוכות', 'cholHaMoed'));
    if (d == 21) ev.add(const HebrewEvent('הושענא רבה', 'special'));
    if (d == 22) {
      ev.add(const HebrewEvent('שמיני עצרת', 'yomTov'));
      if (israel) ev.add(const HebrewEvent('שמחת תורה', 'yomTov'));
    }
    if (d == 23 && !israel) ev.add(const HebrewEvent('שמחת תורה', 'yomTovDiaspora'));
  }

  // ── Chanukah ──────────────────────────────────────────────────────────
  final chanDay = jdn - h2j(y, 3, 25) + 1;
  if (chanDay >= 1 && chanDay <= 8) {
    ev.add(HebrewEvent('חנוכה – נר ${hNum(chanDay)}', 'chanukah'));
  }

  // ── Tevet ─────────────────────────────────────────────────────────────
  if (m == 4 && d == 10) ev.add(const HebrewEvent('עשרה בטבת', 'taanit'));

  // ── Shevat ────────────────────────────────────────────────────────────
  if (m == 5 && d == 15) ev.add(const HebrewEvent('ט״ו בשבט', 'special'));

  // ── Adar ──────────────────────────────────────────────────────────────
  if (lp && m == 6 && d == 14) ev.add(const HebrewEvent('פורים קטן', 'special'));
  if (lp && m == 6 && d == 15) ev.add(const HebrewEvent('שושן פורים קטן', 'special'));
  if (jdn == _jTanitEsther(y)) ev.add(const HebrewEvent('תענית אסתר', 'taanit'));
  if (m == adar && d == 14) ev.add(const HebrewEvent('פורים', 'yomTov'));
  if (m == adar && d == 15) ev.add(const HebrewEvent('שושן פורים', 'special'));

  // ── Nisan ─────────────────────────────────────────────────────────────
  if (m == nisn) {
    if (d == 14) ev.add(const HebrewEvent('ערב פסח / תענית בכורות', 'taanit'));
    if (d == 15) ev.add(const HebrewEvent('פסח א׳', 'yomTov'));
    if (d == 16) {
      ev.add(HebrewEvent(
        israel ? 'חול המועד פסח' : 'פסח ב׳',
        israel ? 'cholHaMoed' : 'yomTovDiaspora',
      ));
    }
    if (d >= 17 && d <= 20) ev.add(const HebrewEvent('חול המועד פסח', 'cholHaMoed'));
    if (d == 21) ev.add(const HebrewEvent('שביעי של פסח', 'yomTov'));
    if (d == 22 && !israel) ev.add(const HebrewEvent('אחרון של פסח', 'yomTovDiaspora'));
  }

  // ── National days ─────────────────────────────────────────────────────
  if (jdn == _jYomHashoah(y)) ev.add(const HebrewEvent('יום השואה והגבורה', 'memorial'));
  if (m == iyar) {
    if (jdn == _jYomHazikaron(y)) ev.add(const HebrewEvent('יום הזיכרון', 'memorial'));
    if (jdn == _jYomHaatzmaut(y)) ev.add(const HebrewEvent('יום העצמאות', 'memorial'));
    if (d == 14) ev.add(const HebrewEvent('פסח שני', 'special'));
    if (d == 18) ev.add(const HebrewEvent('ל״ג בעומר', 'special'));
    if (d == 28) ev.add(const HebrewEvent('יום ירושלים', 'memorial'));
  }

  // ── Sivan ─────────────────────────────────────────────────────────────
  if (m == sivan) {
    if (d == 6) ev.add(const HebrewEvent('שבועות', 'yomTov'));
    if (d == 7 && !israel) ev.add(const HebrewEvent('שבועות ב׳', 'yomTovDiaspora'));
  }

  // ── Tammuz / Av ───────────────────────────────────────────────────────
  if (jdn == _j17Tamuz(y)) ev.add(const HebrewEvent('י״ז בתמוז', 'taanit'));
  if (m == av) {
    if (jdn == _j9Av(y)) ev.add(const HebrewEvent('תשעה באב', 'taanit'));
    if (d == 15) ev.add(const HebrewEvent('ט״ו באב', 'special'));
  }

  // ── Omer ──────────────────────────────────────────────────────────────
  final od = _omerDay(jdn, y);
  if (od >= 1 && od <= 49) {
    final os = omerStr(od);
    if (os != null) ev.add(HebrewEvent(os, 'omer'));
  }

  return ev;
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 2 — LOCATION MODEL
// ═══════════════════════════════════════════════════════════════════════════

/// Geographic location with halachic parameters.
///
/// [sunsetOffsetMin]: practical topographic horizon correction (minutes).
///   0  = flat/sea-level (most cities).
///   >0 = sunset appears later due to western mountains (Jerusalem +5.25 min).
/// [isIsrael]: true = Israel (1-day yom tov); false = Diaspora (2-day).
class HalachicLocation {
  final String name;
  final double lat;
  final double lon;
  final int elev; // metres above sea level
  final int tz; // UTC offset, winter (no DST)
  final double sunsetOffsetMin; // topographic sunset correction
  final bool isIsrael;

  const HalachicLocation({
    required this.name,
    required this.lat,
    required this.lon,
    this.elev = 0,
    required this.tz,
    this.sunsetOffsetMin = 0,
    required this.isIsrael,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lon': lon,
        'elev': elev,
        'tz': tz,
        'offset': sunsetOffsetMin,
        'is_israel': isIsrael,
      };

  @override
  bool operator ==(Object other) =>
      other is HalachicLocation &&
      other.name == name &&
      other.lat == lat &&
      other.lon == lon;

  @override
  int get hashCode => Object.hash(name, lat, lon);

  factory HalachicLocation.fromJson(Map<String, dynamic> d) => HalachicLocation(
        name: d['name'] as String,
        lat: (d['lat'] as num).toDouble(),
        lon: (d['lon'] as num).toDouble(),
        elev: ((d['elev'] as num?) ?? 0).toInt(),
        tz: ((d['tz'] as num?) ?? 2).toInt(),
        sunsetOffsetMin: ((d['offset'] as num?) ?? 0).toDouble(),
        isIsrael: (d['is_israel'] as bool?) ?? true,
      );
}

// ── Built-in location lists ────────────────────────────────────────────────

const List<HalachicLocation> kIsraelLocs = [
  HalachicLocation(name: 'ירושלים',      lat: 31.7683, lon: 35.2137, elev: 800,  tz: 2, sunsetOffsetMin: 5.25, isIsrael: true),
  HalachicLocation(name: 'תל אביב',      lat: 32.0853, lon: 34.7818, elev: 5,    tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'חיפה',         lat: 32.7940, lon: 34.9896, elev: 5,    tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'באר שבע',      lat: 31.2530, lon: 34.7915, elev: 285,  tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'אשדוד',        lat: 31.8040, lon: 34.6550, elev: 30,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'נתניה',        lat: 32.3215, lon: 34.8532, elev: 20,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'פתח תקווה',   lat: 32.0840, lon: 34.8870, elev: 50,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'ראשון לציון', lat: 31.9730, lon: 34.8010, elev: 35,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'רחובות',       lat: 31.8960, lon: 34.8110, elev: 55,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'הרצליה',       lat: 32.1660, lon: 34.8440, elev: 20,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'כפר סבא',     lat: 32.1750, lon: 34.9070, elev: 65,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'מודיעין',      lat: 31.8980, lon: 35.0120, elev: 360,  tz: 2, sunsetOffsetMin: 3,    isIsrael: true),
  HalachicLocation(name: 'אילת',         lat: 29.5581, lon: 34.9482, elev: 3,    tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'טבריה',        lat: 32.7960, lon: 35.5310, elev: -210, tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'נצרת',         lat: 32.6996, lon: 35.3035, elev: 350,  tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'אשקלון',       lat: 31.6688, lon: 34.5742, elev: 50,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'רמת גן',      lat: 32.0684, lon: 34.8248, elev: 45,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
  HalachicLocation(name: 'ביתר עילית',  lat: 31.6980, lon: 35.1170, elev: 800,  tz: 2, sunsetOffsetMin: 5,    isIsrael: true),
  HalachicLocation(name: 'בית שמש',     lat: 31.7450, lon: 34.9870, elev: 360,  tz: 2, sunsetOffsetMin: 3,    isIsrael: true),
  HalachicLocation(name: 'עפולה',        lat: 32.6070, lon: 35.2900, elev: 60,   tz: 2, sunsetOffsetMin: 0,    isIsrael: true),
];

const List<HalachicLocation> kWorldLocs = [
  HalachicLocation(name: 'ניו יורק',       lat: 40.7128,  lon: -74.0060,  elev: 10,  tz: -5, isIsrael: false),
  HalachicLocation(name: "לוס אנג'לס",    lat: 34.0522,  lon: -118.2437, elev: 71,  tz: -8, isIsrael: false),
  HalachicLocation(name: 'לונדון',         lat: 51.5074,  lon: -0.1278,   elev: 11,  tz: 0,  isIsrael: false),
  HalachicLocation(name: 'פריז',           lat: 48.8566,  lon: 2.3522,    elev: 35,  tz: 1,  isIsrael: false),
  HalachicLocation(name: 'אמסטרדם',        lat: 52.3676,  lon: 4.9041,    elev: 2,   tz: 1,  isIsrael: false),
  HalachicLocation(name: 'אנטוורפן',       lat: 51.2194,  lon: 4.4025,    elev: 10,  tz: 1,  isIsrael: false),
  HalachicLocation(name: 'בואנוס איירס',  lat: -34.6037, lon: -58.3816,  elev: 25,  tz: -3, isIsrael: false),
  HalachicLocation(name: 'מלבורן',         lat: -37.8136, lon: 144.9631,  elev: 31,  tz: 10, isIsrael: false),
  HalachicLocation(name: 'מוסקבה',         lat: 55.7558,  lon: 37.6173,   elev: 156, tz: 3,  isIsrael: false),
  HalachicLocation(name: 'טורונטו',        lat: 43.6532,  lon: -79.3832,  elev: 76,  tz: -5, isIsrael: false),
  HalachicLocation(name: 'שיקגו',          lat: 41.8781,  lon: -87.6298,  elev: 179, tz: -6, isIsrael: false),
  HalachicLocation(name: 'מיאמי',          lat: 25.7617,  lon: -80.1918,  elev: 2,   tz: -5, isIsrael: false),
];

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION 3 — ASTRONOMICAL ZMANIM ENGINE
//  Algorithm: Jean Meeus "Astronomical Algorithms" (2nd ed.)
//  Accuracy:  ±30 seconds for years 1900–2100
// ═══════════════════════════════════════════════════════════════════════════

// Zenith constants  (= 90 + degrees below geometric horizon)
const double _kZsr        = 90.833;  // geometric SR/SS (refraction + radius)
const double _kZAlot16    = 106.1;   // 16.1° = alot/tzeit-RT 72-min angular
const double _kZAlot20    = 109.75;  // 19.75° = alot 90-min angular
const double _kZGeonim18  = 94.75;   // 4.75° ≈ 18-min angular (גאונים 18 במע')
const double _kZTzeit645  = 96.45;   // 6.45° = tzeit for מג"א לחומרא
const double _kZTzeit85   = 98.5;    // 8.5°
const double _kZTzeit928  = 99.28;   // 9.28° = Chazon Ish
const double _kZMisheyakir = 101.5;  // 11.5° = misheyakir

/// Julian Day Number (fractional) for midnight UTC of Gregorian date.
/// Mirrors Python's _jdn() exactly.
double _jdnFloat(int y, int m, int d) {
  var yr = y, mo = m;
  if (mo <= 2) {
    yr--;
    mo += 12;
  }
  final a = (yr / 100).toInt(); // Python: int(y/100) = truncation toward zero
  final b = 2 - a + (a / 4).toInt();
  return (365.25 * (yr + 4716)).toInt() +
      (30.6001 * (mo + 1)).toInt() +
      d +
      b -
      1524.5;
}

/// NOAA solar position: (declination°, equation-of-time minutes).
/// Mirrors Python's _noaa_decl_eot() exactly.
(double, double) _noaaDecl(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final l0 =
      (280.46646 + 36000.76983 * t + 0.0003032 * t * t) % 360.0;
  final mAnom =
      (357.52911 + 35999.05029 * t - 0.0001537 * t * t) % 360.0;
  final mAnomR = mAnom * math.pi / 180.0;
  final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(mAnomR) +
      (0.019993 - 0.000101 * t) * math.sin(2 * mAnomR) +
      0.000289 * math.sin(3 * mAnomR);
  final omega = 125.04 - 1934.136 * t;
  final omegaR = omega * math.pi / 180.0;
  final appLon = l0 + c - 0.00569 - 0.00478 * math.sin(omegaR);
  final meanOb = 23.0 +
      (26.0 +
              (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) /
                  60.0) /
          60.0;
  final obCorr = meanOb + 0.00256 * math.cos(omegaR);
  final decl = math.asin(math.sin(obCorr * math.pi / 180.0) *
          math.sin(appLon * math.pi / 180.0)) *
      180.0 /
      math.pi;
  final tanH = math.tan(obCorr / 2.0 * math.pi / 180.0);
  final tanSq = tanH * tanH; // Python's y2
  final e = 0.016708634 - 0.000042037 * t;
  final l0r = l0 * math.pi / 180.0;
  final eot = 4.0 *
      (180.0 / math.pi) *
      (tanSq * math.sin(2 * l0r) -
          2 * e * math.sin(mAnomR) +
          4 * e * tanSq * math.sin(mAnomR) * math.cos(2 * l0r) -
          0.5 * tanSq * tanSq * math.sin(4 * l0r) -
          1.25 * e * e * math.sin(2 * mAnomR));
  return (decl, eot);
}

/// UTC decimal-hours of a solar event, or null (circumpolar).
/// Mirrors Python's _sun_event_utc() with 5-iteration refinement.
double? _sunEventUtc(
    double jdMidnight, double lat, double lon, double zenithDeg, bool rising) {
  var utcMin = 720.0;
  for (var i = 0; i < 5; i++) {
    final (decl, eot) = _noaaDecl(jdMidnight + utcMin / 1440.0);
    final cosH = (math.cos(zenithDeg * math.pi / 180.0) -
            math.sin(lat * math.pi / 180.0) * math.sin(decl * math.pi / 180.0)) /
        (math.cos(lat * math.pi / 180.0) * math.cos(decl * math.pi / 180.0));
    if (cosH < -1 || cosH > 1) return null;
    final h =
        math.acos(cosH.clamp(-1.0, 1.0)) * 180.0 / math.pi;
    final noonMin = 720.0 - 4.0 * lon - eot;
    utcMin = noonMin + (rising ? -4.0 * h : 4.0 * h);
  }
  return utcMin / 60.0 % 24.0;
}

/// Format UTC decimal-hours as local "HH:MM:SS".
/// Mirrors Python's _fmt() exactly.
String fmtUtcTime(double? utcHours, double tz) {
  if (utcHours == null) return '—';
  final local = (utcHours + tz) % 24.0;
  final totalS = (local * 3600).round();
  final h = (totalS ~/ 3600) % 24;
  final rem = totalS % 3600;
  final min = rem ~/ 60;
  final sec = rem % 60;
  return '${h.toString().padLeft(2, '0')}'
      ':${min.toString().padLeft(2, '0')}'
      ':${sec.toString().padLeft(2, '0')}';
}

/// Returns true if [d] falls within Israeli DST (since the 2013 law).
/// DST start: last Friday on or before 1 April.
/// DST end  : last Sunday strictly before 1 October.
/// Mirrors Python's _israel_dst() exactly.
bool israelDst(DateTime d) {
  final y = d.year;
  // DST start: last Friday ≤ April 1
  final apr1 = DateTime(y, 4, 1);
  // Dart weekday: Mon=1,...,Fri=5,...,Sun=7
  final daysToFriday = (apr1.weekday - 5) % 7; // 0 if Fri, 1 if Sat, …
  final dstStart = apr1.subtract(Duration(days: daysToFriday));
  // DST end: last Sunday ≤ Sep 30  (= last Sunday strictly < Oct 1)
  final sep30 = DateTime(y, 9, 30);
  final daysToSunday = (sep30.weekday - 7) % 7; // 0 if Sun, 1 if Mon, …
  final dstEnd = sep30.subtract(Duration(days: daysToSunday));
  final dd = DateTime(d.year, d.month, d.day);
  // Python: dst_start <= d < dst_end
  return !dd.isBefore(dstStart) && dd.isBefore(dstEnd);
}

// ── Zmanim class ──────────────────────────────────────────────────────────

/// All halachic times for a single date + location.
///
/// Methodology (per 'עתים לבינה' / KosherJava):
/// * SR/SS zenith = 90.833 (flat/sea-level — standard halachic base).
/// * "שקיעה במישור" = geometric/flat-horizon sunset (sunsetGeo).
/// * "שקיעה מהגובה" = sunsetGeo + topographic offset (e.g. 5.25 min Jerusalem).
/// * SHA zmanit GRA: (sunsetGeo − sunriseGeo) / 12  — uses GEOMETRIC sunset.
///   Using the practical sunset would shift chatzot by half the offset.
/// * Alot / tzeit RT: computed ANGULARLY (16.1° = 72 min at equinox).
/// * SHA zmanit MGA: (tzeitRt_angular − alot72_angular) / 12.
/// * Fixed-minute tzeit rows (13.5 שוות, 18 שוות) use sunsetGeo as base.
///
/// All time fields are UTC decimal-hours (double?); null = not computable.
/// Convert to local time with [fmt()] or [fmtUtcTime(value, tz)].
class Zmanim {
  final DateTime date;
  final HalachicLocation loc;
  final double tz; // = loc.tz + dstExtra

  // ── Morning ─────────────────────────────────────────────────────────────
  late final double? alot90;    // עלות השחר 90 במע'
  late final double? alot72;    // עלות השחר 72 במע'
  late final double? misheyakir; // משיכיר 11.5°
  late final double? alotCivil; // עלות אזרחי 6°
  late final double? sunrise;   // הנץ החמה

  // ── Sof zman ────────────────────────────────────────────────────────────
  late final double? sofShMaLkhumra; // סוף ק"ש מג"א לחומרא (90→6.45°)
  late final double? sofShMa;        // סוף ק"ש מג"א (72 במע')
  late final double? sofShMa90;      // סוף ק"ש מג"א (90 במע')
  late final double? sofShGra;       // סוף ק"ש גר"א
  late final double? sofTfMa90;      // סוף ת"פ מג"א (90 במע')
  late final double? sofTfMa;        // סוף ת"פ מג"א (72 במע')
  late final double? sofTfGra;       // סוף ת"פ גר"א

  // ── Midday / Mincha ──────────────────────────────────────────────────────
  late final double? chatzot;   // חצות היום
  late final double? minchaG;   // מנחה גדולה
  late final double? minchaK;   // מנחה קטנה גר"א
  late final double? plag;      // פלג המנחה גר"א
  late final double? plagLkhumra; // פלג לחומרא (90→6.45°)

  // ── Sunset / Nightfall ───────────────────────────────────────────────────
  late final double? sunsetGeo; // שקיעה במישור
  late final double? sunset;    // שקיעה מהגובה
  late final double? tzeit135;  // צאת גאונים 13.5 שוות מישור
  late final double? tzeit;     // צאת גאונים 18 שוות מישור
  late final double? tzeit18deg; // צאת גאונים 18 במע'
  late final double? tzeit85;   // צאת 8.5°
  late final double? tzeitCi;   // צאת חזון איש 9.28°
  late final double? tzeitRt;   // צאת ר"ת 72 במע'

  // ── Night watches ───────────────────────────────────────────────────────
  late final double? mishmar1;     // סוף משמרה א' גר"א
  late final double? chatzotLayla; // חצות הלילה גר"א
  late final double? mishmar2;     // סוף משמרה ב' גר"א

  late final double _shaGra; // sha'ah zmanit GRA (hours)
  late final double _shaMa;  // sha'ah zmanit MGA (hours)

  Zmanim(this.date, this.loc, [double dstExtra = 0])
      : tz = loc.tz + dstExtra {
    _compute();
  }

  void _compute() {
    final jd0 = _jdnFloat(date.year, date.month, date.day);
    final lat = loc.lat, lon = loc.lon;
    final off = loc.sunsetOffsetMin / 60.0; // topographic offset in hours

    // Geometric (flat-horizon) SR/SS
    final srGeo = _sunEventUtc(jd0, lat, lon, _kZsr, true);
    final ssGeo = _sunEventUtc(jd0, lat, lon, _kZsr, false);

    // Practical sunset = geometric + topographic offset
    final ssPrac = ssGeo != null ? ssGeo + off : null;

    // Angular twilights (degree-based)
    alot72     = _sunEventUtc(jd0, lat, lon, _kZAlot16,     true);   // 16.1°
    alot90     = _sunEventUtc(jd0, lat, lon, _kZAlot20,     true);   // 19.75°
    final tzRt = _sunEventUtc(jd0, lat, lon, _kZAlot16,     false);  // ר"ת symmetric
    alotCivil  = _sunEventUtc(jd0, lat, lon, 96.0,          true);   // 6°
    misheyakir = _sunEventUtc(jd0, lat, lon, _kZMisheyakir, true);   // 11.5°
    tzeitRt    = tzRt;

    // Fixed-minute tzeit (from GEOMETRIC sunset — "שוות מישור")
    tzeit135 = ssGeo != null ? ssGeo + 13.5 / 60.0 : null;
    tzeit    = ssGeo != null ? ssGeo + 18.0 / 60.0 : null;

    // Angular tzeit
    tzeit18deg = _sunEventUtc(jd0, lat, lon, _kZGeonim18, false);
    tzeit85    = _sunEventUtc(jd0, lat, lon, _kZTzeit85,  false);
    tzeitCi    = _sunEventUtc(jd0, lat, lon, _kZTzeit928, false);

    // Displayed SR/SS
    sunrise    = srGeo;
    sunsetGeo  = ssGeo;
    sunset     = ssPrac;

    // SHA zmanit GRA — uses GEOMETRIC sunset (critical!)
    if (srGeo != null && ssGeo != null) {
      _shaGra = (ssGeo - srGeo) / 12.0;
    } else {
      _shaGra = 1.0;
    }

    // SHA zmanit MGA (alot72 angular ↔ tzeitRt angular)
    if (alot72 != null && tzRt != null) {
      _shaMa = (tzRt - alot72!) / 12.0;
    } else {
      _shaMa = _shaGra;
    }

    // SHA-90 for symmetric מג"א 90°
    final tzRt90 = _sunEventUtc(jd0, lat, lon, _kZAlot20, false);
    final shaM90 = (alot90 != null && tzRt90 != null)
        ? (tzRt90 - alot90!) / 12.0
        : _shaGra;

    // SHA-90 לחומרא: alot90 → tzeit at 6.45°
    final tz645 = _sunEventUtc(jd0, lat, lon, _kZTzeit645, false);
    final shaM90Lk = (alot90 != null && tz645 != null)
        ? (tz645 - alot90!) / 12.0
        : _shaGra;

    // ── Local aliases for closure lambdas ──────────────────────────────
    final srL   = srGeo;
    final alL   = alot72;
    final a90L  = alot90;
    final g     = _shaGra;
    final shaMa = _shaMa;

    double? srN(double n)    => srL  != null ? srL  + n * g       : null;
    double? alN(double n)    => alL  != null ? alL + n * shaMa   : null;
    double? a90N(double n)   => a90L != null ? a90L + n * shaM90  : null;
    double? a90LkN(double n) => a90L != null ? a90L + n * shaM90Lk : null;

    // ── Derived times ──────────────────────────────────────────────────
    chatzot         = srN(6);
    sofShGra        = srN(3);
    sofShMa         = alN(3);
    sofShMa90       = a90N(3);
    sofShMaLkhumra  = a90LkN(3);
    sofTfGra        = srN(4);
    sofTfMa         = alN(4);
    sofTfMa90       = a90N(4);

    // Mincha Gedola: max(chatzot+30min, chatzot+0.5*sha_gra) per Mishna Berura
    final ch = chatzot;
    if (ch != null) {
      final opt1 = ch + 30.0 / 60.0;
      final opt2 = ch + 0.5 * g;
      minchaG = opt1 > opt2 ? opt1 : opt2;
    } else {
      minchaG = null;
    }
    minchaK      = srN(9.5);
    plag         = srN(10.75);
    plagLkhumra  = a90LkN(10.75);

    // ── Night watches (משמרות) — night = sunsetGeo → next-day sunriseGeo ──
    if (srGeo != null && ssGeo != null) {
      // Night length in hours (straddles midnight):
      final night = srGeo < ssGeo
          ? srGeo + 24.0 - ssGeo  // normal case (SR next day is before SS today)
          : srGeo - ssGeo;        // polar edge case
      mishmar1      = (ssGeo + night / 3.0) % 24.0;
      chatzotLayla  = (ssGeo + night / 2.0) % 24.0;
      mishmar2      = (ssGeo + 2.0 * night / 3.0) % 24.0;
    } else {
      mishmar1 = chatzotLayla = mishmar2 = null;
    }
  }

  /// Convert a UTC-hours value to local time string "HH:MM:SS".
  String fmt(double? utcH) => fmtUtcTime(utcH, tz);

  /// SHA zmanit GRA as "MM:SS" string (minutes may exceed 60).
  String get shaGraMin {
    final totalS = (_shaGra * 3600).round();
    return '${totalS ~/ 60}:${(totalS % 60).toString().padLeft(2, '0')}';
  }

  /// SHA zmanit MGA as "MM:SS" string.
  String get shaMaMin {
    final totalS = (_shaMa * 3600).round();
    return '${totalS ~/ 60}:${(totalS % 60).toString().padLeft(2, '0')}';
  }
}
