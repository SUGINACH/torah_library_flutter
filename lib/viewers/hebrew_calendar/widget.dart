/// widget.dart
/// ─────────────────────────────────────────────────────────────────────────
/// Complete Hebrew/Gregorian calendar widget with zmanim panel.
/// Ported from calendar_widget.py — UI layout and behaviour are faithful.
///
/// Public API
/// ──────────
/// HebrewCalendarWidget({onDateSelected, initialDate, palette})
///   • Use directly as a tab body, or wrap in Scaffold for standalone use.
///   • [onDateSelected] fires when the user taps a cell (≈ date_selected signal).
///   • [palette] overrides the built-in parchment colours (optional).
///
/// CalPalette — colour set accepted by the widget (matching _cal_colors output).
///
/// Static helpers (callable without an instance):
///   HebrewCalendarWidget.gregorianToHebrew(DateTime) → (year, month, day)
///   HebrewCalendarWidget.hebrewToGregorian(y, m, d)  → DateTime
library;
// ─────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PALETTE
// ═══════════════════════════════════════════════════════════════════════════

/// Colour set consumed by the calendar painter and child widgets.
/// Default values replicate the parchment theme from calendar_widget.py.
class CalPalette {
  final Color cellBg;
  final Color cellShabBg;
  final Color cellSelBg;
  final Color cellEmptyBg;
  final Color cellBorder;
  final Color todayRing;
  final Color headerBg;
  final Color headerFg;
  final Color gNumFg;
  final Color gNumShab;
  final Color gNumToday;
  final Color hDateFg;
  final Color navBg;
  final Color btnBg;
  final Color btnFg;
  final Color btnTodayBg;
  final Color stripBg;
  final Color chipLabelFg;
  final Color chipValFg;
  final Color detailBg;
  final Color detailTitle;

  const CalPalette({
    this.cellBg        = const Color(0xFFF7F7F7),
    this.cellShabBg    = const Color(0xFFEDDDA7),
    this.cellSelBg     = const Color(0xFFF0E4C8),
    this.cellEmptyBg   = const Color(0xFFFFFCF5),
    this.cellBorder    = const Color(0xFFD9B13E),
    this.todayRing     = const Color(0xFF1A3D6B),
    this.headerBg      = const Color(0xFF5F4030),
    this.headerFg      = const Color(0xFFEDDDA7),
    this.gNumFg        = const Color(0xFF2C2118),
    this.gNumShab      = const Color(0xFF4A1A6B),
    this.gNumToday     = const Color(0xFF1A3D6B),
    this.hDateFg       = const Color(0xFF5C4A38),
    this.navBg         = const Color(0xFFE7D3A4),
    this.btnBg         = const Color(0xFFD9B13E),
    this.btnFg         = const Color(0xFFFFFFFF),
    this.btnTodayBg    = const Color(0xFF1A3D6B),
    this.stripBg       = const Color(0xFFE7D3A4),
    this.chipLabelFg   = const Color(0xFF5C4A38),
    this.chipValFg     = const Color(0xFF2C2118),
    this.detailBg      = const Color(0xFFE7D3A4),
    this.detailTitle   = const Color(0xFF1A3D6B),
  });
}

// ── Event colours as Flutter Color objects ────────────────────────────────

Color _evBg(String kind) => Color(kEvColorData[kind]?.$1 ?? 0xFFEEEEEE);
Color _evFg(String kind) => Color(kEvColorData[kind]?.$2 ?? 0xFF333333);

/// Darken a color by Qt's darker(factor) logic: RGB × (100/factor).
Color _darker(Color c, int factor) {
  if (factor <= 0) return const Color(0xFF000000);
  final f = 100.0 / factor;
  return Color.fromARGB(
    c.alpha,
    (c.red * f).round().clamp(0, 255),
    (c.green * f).round().clamp(0, 255),
    (c.blue * f).round().clamp(0, 255),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOCATION MANAGER  (shared_preferences — mirrors _load_locations / _write)
// ═══════════════════════════════════════════════════════════════════════════

class _LocationData {
  final List<HalachicLocation> israel;
  final List<HalachicLocation> world;
  final List<HalachicLocation> custom;
  _LocationData(this.israel, this.world, this.custom);
}

class _LocationManager {
  static const _kKey = 'hcal_locations_v1';

  static Future<_LocationData> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        return _LocationData(
          (data['israel'] as List).map((d) => HalachicLocation.fromJson(d as Map<String, dynamic>)).toList(),
          (data['world']  as List).map((d) => HalachicLocation.fromJson(d as Map<String, dynamic>)).toList(),
          ((data['custom'] as List?) ?? []).map((d) => HalachicLocation.fromJson(d as Map<String, dynamic>)).toList(),
        );
      }
    } catch (_) {}
    // First run: persist defaults and return them
    await _save(kIsraelLocs.toList(), kWorldLocs.toList(), []);
    return _LocationData(kIsraelLocs.toList(), kWorldLocs.toList(), []);
  }

  static Future<void> _save(List<HalachicLocation> israel,
      List<HalachicLocation> world, List<HalachicLocation> custom) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kKey,
        jsonEncode({
          'version': 1,
          'israel': israel.map((l) => l.toJson()).toList(),
          'world':  world.map((l)  => l.toJson()).toList(),
          'custom': custom.map((l) => l.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  static Future<void> appendCustom(
      _LocationData existing, HalachicLocation loc) =>
      _save(existing.israel, existing.world, [...existing.custom, loc]);
}

// ═══════════════════════════════════════════════════════════════════════════
//  CALENDAR GRID  (CustomPainter — mirrors _CalGrid QPainter logic exactly)
// ═══════════════════════════════════════════════════════════════════════════

/// Column labels RTL order: col-0=שבת (physically leftmost), col-6=ראשון.
const List<String> _kDowLabels = [
  'שבת', 'שישי', 'חמישי', 'רביעי', 'שלישי', 'שני', 'ראשון',
];

/// Maps Dart weekday (1=Mon … 7=Sun) → RTL column index (0=Sat … 6=Sun).
/// Mirrors Python's {0:5,1:4,2:3,3:2,4:1,5:0,6:6}[py_wd] exactly.
const List<int> _kDartWdToRtlCol = [
  5, 4, 3, 2, 1, 0, 6, // index 0=Mon,1=Tue,…,5=Sat,6=Sun (dartWd-1)
];

class _CalendarPainter extends CustomPainter {
  final int year, month;
  final DateTime today, selected;
  final bool israel;
  final CalPalette pal;
  final void Function(DateTime) onTap;

  // Mutable hit-test map rebuilt on each paint.
  final List<(Rect, DateTime)> _cells = [];

  _CalendarPainter({
    required this.year,
    required this.month,
    required this.today,
    required this.selected,
    required this.israel,
    required this.pal,
    required this.onTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _cells.clear();

    final w = size.width, h = size.height;
    final headerH = math.max(26.0, h / 18.0);
    final rowH = math.max(1.0, (h - headerH) / 6.0);
    final colW = math.max(1.0, w / 7.0);

    // Background fill
    canvas.drawRect(Offset.zero & size, Paint()..color = pal.cellBg);

    // ── Day-name header ────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, headerH),
      Paint()..color = pal.headerBg,
    );
    final fntHSize = math.max(7.0, h / 62.0);
    for (var col = 0; col < 7; col++) {
      _drawText(
        canvas,
        _kDowLabels[col],
        TextStyle(
          color: pal.headerFg,
          fontSize: fntHSize,
          fontWeight: FontWeight.bold,
        ),
        Rect.fromLTWH(col * colW, 0, colW, headerH),
        TextAlign.center,
      );
    }

    // ── Cells ──────────────────────────────────────────────────────────
    final firstDay = DateTime(year, month, 1);
    // Days in Gregorian month
    final daysInM = DateTime(year, month + 1, 0).day;
    // RTL column for first day of month
    final rtlCol = _kDartWdToRtlCol[firstDay.weekday - 1];

    final fntGSize = math.max(8.0, h / 52.0);
    final fntDSize = math.max(6.0, h / 72.0);
    final fntESize = math.max(5.0, h / 85.0);

    for (var day = 1; day <= daysInM; day++) {
      // Position calculation — mirrors Python exactly:
      //   p  = (6 - rtl_col) + (day - 1)
      //   col = 6 - (p % 7)
      //   row = p // 7
      final p = (6 - rtlCol) + (day - 1);
      final col = 6 - (p % 7);
      final row = p ~/ 7;
      final x = col * colW;
      final yp = headerH + row * rowH;
      final rect = Rect.fromLTWH(x, yp, colW, rowH);

      final d = DateTime(year, month, day);
      _cells.add((rect, d));

      final jdn = dateToJdn(d);
      final (hy, hm, hd) = j2h(jdn);
      final dw = jdnDow(jdn);
      final isSh = (dw == 6);
      final evs = getEvents(jdn, israel);
      final isT = (d.year == today.year && d.month == today.month && d.day == today.day);
      final isS = (d.year == selected.year && d.month == selected.month && d.day == selected.day);

      // Cell background
      final bgColor = isS ? pal.cellSelBg : (isSh ? pal.cellShabBg : pal.cellBg);
      canvas.drawRect(rect, Paint()..color = bgColor);

      // Cell border
      canvas.drawRect(
        rect.deflate(0.5),
        Paint()
          ..color = pal.cellBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Today ring
      if (isT) {
        canvas.drawRect(
          rect.deflate(1.5),
          Paint()
            ..color = pal.todayRing
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // Gregorian day number (top-right)
      _drawText(
        canvas,
        '$day',
        TextStyle(
          color: isT ? pal.gNumToday : (isSh ? pal.gNumShab : pal.gNumFg),
          fontSize: fntGSize,
          fontWeight: FontWeight.bold,
        ),
        Rect.fromLTWH(x + 3, yp + 3, colW - 6, fntGSize + 6),
        TextAlign.right,
      );

      // Hebrew date (centered below day number)
      _drawText(
        canvas,
        '${hNum(hd)} ${monthName(hm, hy)}',
        TextStyle(color: pal.hDateFg, fontSize: fntDSize),
        Rect.fromLTWH(x + 2, yp + fntGSize + 8.0, colW - 4, fntDSize + 4),
        TextAlign.center,
      );

      // Event tags (up to 2)
      final evY = yp + fntGSize + fntDSize + 14.0;
      final th = fntESize + 5;
      for (var i = 0; i < evs.length && i < 2; i++) {
        final ev = evs[i];
        final tagRect = Rect.fromLTWH(x + 2, evY + i * (th + 2), colW - 4, th);
        canvas.drawRect(tagRect, Paint()..color = _evBg(ev.kind));
        canvas.drawRect(
          tagRect,
          Paint()
            ..color = _darker(_evBg(ev.kind), 120)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        _drawText(
          canvas,
          ev.name,
          TextStyle(
            color: _evFg(ev.kind),
            fontSize: fntESize,
            fontWeight: FontWeight.bold,
          ),
          tagRect.deflate(2),
          TextAlign.right,
          maxLines: 1,
        );
      }

      // "+N" overflow indicator
      if (evs.length > 2) {
        final moreY = evY + 2 * (fntESize + 7);
        _drawText(
          canvas,
          '+${evs.length - 2}',
          TextStyle(
            color: Color(kEvColorData['roshChodesh']!.$2),
            fontSize: fntESize,
          ),
          Rect.fromLTWH(x + 2, moreY, colW - 4, fntESize + 4),
          TextAlign.center,
        );
      }
    }
  }

  // ── TextPainter helper ──────────────────────────────────────────────
  void _drawText(Canvas canvas, String text, TextStyle style, Rect box,
      TextAlign align, {int maxLines = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    );
    tp.layout(minWidth: box.width, maxWidth: box.width);
    // Vertically center within the box
    final dy = (box.height - tp.height) / 2;
    tp.paint(canvas, Offset(box.left, box.top + dy.clamp(0.0, box.height)));
  }

  // ── Hit test ────────────────────────────────────────────────────────
  void handleTap(Offset pos) {
    for (final (rect, date) in _cells) {
      if (rect.contains(pos)) {
        onTap(date);
        return;
      }
    }
  }

  @override
  bool shouldRepaint(_CalendarPainter old) =>
      old.year != year ||
      old.month != month ||
      old.today != today ||
      old.selected != selected ||
      old.israel != israel ||
      old.pal != pal;
}

// ═══════════════════════════════════════════════════════════════════════════
//  YEAR STRIP  (mirrors _YearStrip)
// ═══════════════════════════════════════════════════════════════════════════

class _YearStrip extends StatelessWidget {
  final int gregYear, gregMonth;
  final CalPalette pal;

  const _YearStrip({
    required this.gregYear,
    required this.gregMonth,
    required this.pal,
  });

  @override
  Widget build(BuildContext context) {
    // ── compute the same data as Python's update_month() ────────────────
    final jdn1 = g2j(gregYear, gregMonth, 1);
    final lastDay = DateTime(gregYear, gregMonth + 1, 0).day;
    final jdnL = g2j(gregYear, gregMonth, lastDay);
    final (y1, _, __) = j2h(jdn1);
    final (y2, m2, _2) = j2h(jdnL);

    final yStr = y1 == y2
        ? hYear(y1)
        : '${hYear(y1)} – ${hYear(y2)}';
    final ytStr = y1 == y2
        ? yearType(y1)
        : '${yearType(y1)} / ${yearType(y2)}';
    final dyStr = y1 == y2
        ? '${daysInYear(y1)}'
        : '${daysInYear(y1)} / ${daysInYear(y2)}';
    final cyc = (y1 % 19 == 0) ? 19 : y1 % 19;
    final chStr =
        '${longCheshvan(y1) ? "מלא" : "חסר"} / ${shortKislev(y1) ? "חסר" : "מלא"}';

    final chips = [
      ('שנה עברית', yStr),
      ('סוג שנה', ytStr),
      ('ימי שנה', dyStr),
      ('מחזור', 'שנה $cyc/19'),
      ('חשוון/כסלו', chStr),
    ];

    return Container(
      color: pal.stripBg,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // RTL: start from right
        child: Row(
          children: chips.map((c) => _Chip(label: c.$1, val: c.$2, pal: pal)).toList(),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, val;
  final CalPalette pal;
  const _Chip({required this.label, required this.val, required this.pal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: pal.cellBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: pal.chipLabelFg)),
          Text(val,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: pal.chipValFg)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DETAIL PANEL  (mirrors _DetailPanel)
// ═══════════════════════════════════════════════════════════════════════════

class _DetailPanel extends StatelessWidget {
  final DateTime date;
  final bool israel;
  final CalPalette pal;

  const _DetailPanel({
    required this.date,
    required this.israel,
    required this.pal,
  });

  @override
  Widget build(BuildContext context) {
    final jdn = dateToJdn(date);
    final (hy, hm, hd) = j2h(jdn);
    final dw = jdnDow(jdn);
    final evs = getEvents(jdn, israel);

    final title =
        'יום ${kDowHeb[dw]},  ${date.day} ${kGregMonths[date.month]} ${date.year}'
        '    |    ${hDateStr(hy, hm, hd)}';

    return Container(
      color: pal.detailBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: pal.detailTitle),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // RTL
            child: Row(
              children: evs.isEmpty
                  ? [
                      Text('אין אירועים מיוחדים',
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: pal.hDateFg)),
                    ]
                  : evs
                      .map((ev) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _evBg(ev.kind),
                                border: Border.all(
                                    color: _darker(_evBg(ev.kind), 120)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                ev.name,
                                style: TextStyle(
                                    color: _evFg(ev.kind),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ))
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LEGEND BAR  (mirrors _build_legend)
// ═══════════════════════════════════════════════════════════════════════════

class _LegendBar extends StatelessWidget {
  final CalPalette pal;
  const _LegendBar({required this.pal});

  static const _items = [
    ('יום טוב', 'yomTov'),
    ('יום כיפור', 'yomKippur'),
    ('תענית', 'taanit'),
    ('חול המועד', 'cholHaMoed'),
    ('חנוכה', 'chanukah'),
    ('מועד מיוחד', 'special'),
    ('יום לאומי', 'memorial'),
    ('ראש חודש', 'roshChodesh'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: pal.navBg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            Text('מקרא:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: pal.gNumFg)),
            const SizedBox(width: 8),
            ..._items.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('●',
                          style: TextStyle(
                              color: _evFg(item.$2), fontSize: 10)),
                      const SizedBox(width: 2),
                      Text(item.$1,
                          style: TextStyle(
                              fontSize: 10, color: pal.gNumFg)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ZMANIM PANEL  (mirrors ZmaninPanel)
// ═══════════════════════════════════════════════════════════════════════════

/// A row entry for the zmanim table.
/// [getter] = null → section header.
typedef _ZGetter = double? Function(Zmanim z);
typedef _ZRow = (String label, _ZGetter? getter);

// ignore: prefer_const_constructors  (function tear-offs are not compile-time const)
final List<_ZRow> _kZmanimRows = [
  // ── Morning ──────────────────────────────────────────────────────────
  ("עלות השחר (90 במע')",                    _zAlot90),
  ("עלות השחר (72 במע')",                    _zAlot72),
  ("משיכיר (11.5°)",                        _zMisheyakir),
  ("עלות אזרחי (6°)",                       _zAlotCivil),
  ("הנץ החמה",                              _zSunrise),
  // ── Sof zman KS ──────────────────────────────────────────────────────
  ("__sep__:סוף זמן קריאת שמע",              null),
  ('סוף ק"ש – מג"א לחומרא (90→6.45°)',      _zSofShMaLkhumra),
  ('סוף ק"ש – מג"א (72 במע\')',              _zSofShMa),
  ('סוף ק"ש – מג"א (90 במע\')',              _zSofShMa90),
  ('סוף ק"ש – גר"א',                        _zSofShGra),
  // ── Sof zman Tefila ──────────────────────────────────────────────────
  ("__sep__:סוף זמן תפילה",                  null),
  ('סוף ת"פ – מג"א (90 במע\')',              _zSofTfMa90),
  ('סוף ת"פ – מג"א (72 במע\')',              _zSofTfMa),
  ('סוף ת"פ – גר"א',                        _zSofTfGra),
  // ── Midday / Mincha ───────────────────────────────────────────────────
  ("__sep__:צהריים / מנחה / ערב",            null),
  ("חצות היום",                              _zChatzot),
  ("מנחה גדולה",                            _zMinchaG),
  ('מנחה קטנה – גר"א',                      _zMinchaK),
  ('פלג המנחה – גר"א',                      _zPlag),
  ("פלג המנחה לחומרא (90→6.45°)",           _zPlagLkhumra),
  // ── Sunset / Nightfall ────────────────────────────────────────────────
  ("__sep__:שקיעה וצאת הכוכבים",             null),
  ("שקיעה במישור",                          _zSunsetGeo),
  ("שקיעה מהגובה",                          _zSunset),
  ("צאת – גאונים (13.5 שוות מישור)",        _zTzeit135),
  ("צאת – גאונים (18 שוות מישור)",          _zTzeit),
  ("צאת – גאונים (18 במע')",                _zTzeit18deg),
  ("צאת (8.5°)",                            _zTzeit85),
  ('צאת – חזון איש (9.28°)',               _zTzeitCi),
  ("צאת רבינו תם (72 במע')",                _zTzeitRt),
  // ── Night watches ─────────────────────────────────────────────────────
  ("__sep__:משמרות הלילה",                   null),
  ("סוף משמרה א' – גר\"א",                  _zMishmar1),
  ("חצות הלילה – גר\"א",                    _zChatzotLayla),
  ("סוף משמרה ב' – גר\"א",                  _zMishmar2),
];

// Top-level getter functions (required because const lists can't hold lambdas)
double? _zAlot90(Zmanim z)          => z.alot90;
double? _zAlot72(Zmanim z)          => z.alot72;
double? _zMisheyakir(Zmanim z)      => z.misheyakir;
double? _zAlotCivil(Zmanim z)       => z.alotCivil;
double? _zSunrise(Zmanim z)         => z.sunrise;
double? _zSofShMaLkhumra(Zmanim z)  => z.sofShMaLkhumra;
double? _zSofShMa(Zmanim z)         => z.sofShMa;
double? _zSofShMa90(Zmanim z)       => z.sofShMa90;
double? _zSofShGra(Zmanim z)        => z.sofShGra;
double? _zSofTfMa90(Zmanim z)       => z.sofTfMa90;
double? _zSofTfMa(Zmanim z)         => z.sofTfMa;
double? _zSofTfGra(Zmanim z)        => z.sofTfGra;
double? _zChatzot(Zmanim z)         => z.chatzot;
double? _zMinchaG(Zmanim z)         => z.minchaG;
double? _zMinchaK(Zmanim z)         => z.minchaK;
double? _zPlag(Zmanim z)            => z.plag;
double? _zPlagLkhumra(Zmanim z)     => z.plagLkhumra;
double? _zSunsetGeo(Zmanim z)       => z.sunsetGeo;
double? _zSunset(Zmanim z)          => z.sunset;
double? _zTzeit135(Zmanim z)        => z.tzeit135;
double? _zTzeit(Zmanim z)           => z.tzeit;
double? _zTzeit18deg(Zmanim z)      => z.tzeit18deg;
double? _zTzeit85(Zmanim z)         => z.tzeit85;
double? _zTzeitCi(Zmanim z)         => z.tzeitCi;
double? _zTzeitRt(Zmanim z)         => z.tzeitRt;
double? _zMishmar1(Zmanim z)        => z.mishmar1;
double? _zChatzotLayla(Zmanim z)    => z.chatzotLayla;
double? _zMishmar2(Zmanim z)        => z.mishmar2;

class _ZmanimPanel extends StatefulWidget {
  final DateTime? date;
  final HalachicLocation loc;
  const _ZmanimPanel({required this.date, required this.loc});

  @override
  State<_ZmanimPanel> createState() => _ZmanimPanelState();
}

class _ZmanimPanelState extends State<_ZmanimPanel> {
  bool _dst = false;

  @override
  void initState() {
    super.initState();
    _autoSetDst();
  }

  @override
  void didUpdateWidget(_ZmanimPanel old) {
    super.didUpdateWidget(old);
    if (old.loc != widget.loc || old.date != widget.date) {
      _autoSetDst();
    }
  }

  void _autoSetDst() {
    final d = widget.date;
    if (d != null && widget.loc.isIsrael) {
      setState(() => _dst = israelDst(d));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    if (d == null) {
      return const SizedBox.shrink();
    }

    final z = Zmanim(d, widget.loc, _dst ? 1.0 : 0.0);

    // Alternate row colours
    const bgA = Color(0xFFFDFAF4);
    const bgB = Color(0xFFF5EDE0);
    var rowBg = true;

    final rows = <Widget>[];
    for (final (label, getter) in _kZmanimRows) {
      if (getter == null) {
        // Section header
        final title = label.replaceFirst('__sep__:', '');
        rows.add(Container(
          width: double.infinity,
          color: const Color(0xFFE8D8B8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            '  $title',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A4A1A)),
            textDirection: TextDirection.rtl,
          ),
        ));
        rowBg = true;
      } else {
        // Time row
        final bg = rowBg ? bgA : bgB;
        rowBg = !rowBg;
        final val = getter(z);
        rows.add(Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time (left side in RTL display = right logical)
              SizedBox(
                width: 90,
                child: Text(
                  z.fmt(val),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Color(0xFF3A2A0A)),
                  textAlign: TextAlign.center,
                ),
              ),
              // Label (right side in RTL display = left logical)
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ));
      }
    }

    // SHA footer
    rows.add(const Divider(height: 1, color: Color(0xFFD0C0A0)));
    rows.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'שעה זמנית',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${z.shaGraMin} דק\'',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              const Text('גר"א:', style: TextStyle(fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${z.shaMaMin} דק\'',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              const Text('מג"א:', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    ));

    return Container(
      color: const Color(0xFFF5EDE0),
      child: Column(
        children: [
          // Header: title + DST checkbox
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24, height: 24,
                      child: Checkbox(
                        value: _dst,
                        onChanged: (v) => setState(() => _dst = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('שעון קיץ (+1)', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('⏰ זמני הלכה',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('(NOAA ±30″ | ±1′ שקיעה)',
                      style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                ]),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD0C0A0)),
          Expanded(
            child: Scrollbar(
              child: ListView(children: rows),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ADD LOCATION DIALOG  (mirrors AddLocationDialog)
// ═══════════════════════════════════════════════════════════════════════════

class _AddLocationDialog extends StatefulWidget {
  const _AddLocationDialog();

  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  final _nameCtrl = TextEditingController();
  final _latCtrl  = TextEditingController(text: '0.00000');
  final _lonCtrl  = TextEditingController(text: '0.00000');
  final _elevCtrl = TextEditingController(text: '0');
  final _tzCtrl   = TextEditingController(text: '2');
  final _offCtrl  = TextEditingController(text: '0.00');
  bool _isIsrael  = true;
  String _error   = '';

  @override
  void dispose() {
    for (final c in [_nameCtrl, _latCtrl, _lonCtrl, _elevCtrl, _tzCtrl, _offCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    setState(() => _error = '');
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = '⚠  יש להזין שם מיקום'); return; }
    final lat = double.tryParse(_latCtrl.text);
    final lon = double.tryParse(_lonCtrl.text);
    if (lat == null || lon == null) { setState(() => _error = '⚠  ערכי קואורדינטות שגויים'); return; }
    if (lat == 0.0 && lon == 0.0) {
      setState(() => _error = '⚠  קו רוחב וקו אורך הם שניהם 0 — האם הזנת קואורדינטות?');
      return;
    }
    final elev = int.tryParse(_elevCtrl.text) ?? 0;
    final tz   = int.tryParse(_tzCtrl.text) ?? 2;
    final off  = double.tryParse(_offCtrl.text) ?? 0.0;
    Navigator.pop(
      context,
      HalachicLocation(
        name: name,
        lat: double.parse(lat.toStringAsFixed(5)),
        lon: double.parse(lon.toStringAsFixed(5)),
        elev: elev,
        tz: tz,
        sunsetOffsetMin: double.parse(off.toStringAsFixed(2)),
        isIsrael: _isIsrael,
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? type, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(fontSize: 12),
                textDirection: TextDirection.rtl),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: type ?? TextInputType.text,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('הוספת מיקום חדש',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Help banner
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  border: Border.all(color: const Color(0xFFB3D4F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('📍  כיצד למצוא קואורדינטות?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A3C8C))),
                  SizedBox(height: 4),
                  Text(
                    '• Google Maps: לחץ ימני על נקודה ← שני מספרים (lat, lon)\n'
                    '• UTC±: ישראל=2 | לונדון=0 | ניו יורק=−5 | פריז=1\n'
                    '• תיקון שקיעה: 0 לרוב הערים | ירושלים=5.25 | ב"ש=3',
                    style: TextStyle(fontSize: 11, color: Color(0xFF333333)),
                  ),
                ]),
              ),
              _field('שם המיקום *', _nameCtrl, hint: 'לדוגמה: מודיעין עילית'),
              _field('קו רוחב (Lat) *\n+ צפון  − דרום', _latCtrl,
                  type: const TextInputType.numberWithOptions(signed: true, decimal: true)),
              _field('קו אורך (Lon) *\n+ מזרח  − מערב', _lonCtrl,
                  type: const TextInputType.numberWithOptions(signed: true, decimal: true)),
              _field('גובה מ"ש (אופציונלי)', _elevCtrl,
                  type: TextInputType.number),
              _field('UTC± (חורף) *', _tzCtrl,
                  type: const TextInputType.numberWithOptions(signed: true)),
              _field('תיקון שקיעה (דק\')', _offCtrl,
                  type: const TextInputType.numberWithOptions(decimal: true)),
              CheckboxListTile(
                value: _isIsrael,
                onChanged: (v) => setState(() => _isIsrael = v ?? true),
                title: const Text('ארץ ישראל  (יום טוב יום אחד)', style: TextStyle(fontSize: 12)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_error,
                      style: const TextStyle(color: Color(0xFFC62828), fontSize: 11)),
                ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
          child: const Text('✚  הוסף מיקום', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN WIDGET  (mirrors HebrewCalendarWidget)
// ═══════════════════════════════════════════════════════════════════════════

/// Hebrew/Gregorian calendar widget.
///
/// Drop-in widget usable as a standalone page or as a tab body.
/// Wrap in [Scaffold] + [AppBar] for standalone use (see main.dart).
///
/// [onDateSelected] fires when the user taps a calendar cell.
/// [palette] overrides the default parchment colour scheme.
class HebrewCalendarWidget extends StatefulWidget {
  const HebrewCalendarWidget({
    super.key,
    this.onDateSelected,
    this.initialDate,
    this.palette,
  });

  final void Function(DateTime)? onDateSelected;
  final DateTime? initialDate;
  final CalPalette? palette;

  // ── Static conversion helpers ──────────────────────────────────────────
  static (int, int, int) gregorianToHebrew(DateTime d) =>
      g2h(d.year, d.month, d.day);

  static DateTime hebrewToGregorian(int hy, int hm, int hd) {
    final (Y, M, D) = h2g(hy, hm, hd);
    return DateTime(Y, M, D);
  }

  @override
  State<HebrewCalendarWidget> createState() => _HebrewCalendarWidgetState();
}

class _HebrewCalendarWidgetState extends State<HebrewCalendarWidget> {
  late int _year, _month;
  late DateTime _selected, _today;
  bool _zmanimOpen = false;
  bool _locationsLoaded = false;

  List<HalachicLocation> _israelLocs = kIsraelLocs.toList();
  List<HalachicLocation> _worldLocs  = kWorldLocs.toList();
  List<HalachicLocation> _customLocs = [];
  late HalachicLocation _loc;
  bool _israel = true;

  // Painter reference for hit-testing
  _CalendarPainter? _painter;

  CalPalette get _pal => widget.palette ?? const CalPalette();

  @override
  void initState() {
    super.initState();
    _today    = DateTime.now();
    _selected = widget.initialDate ?? _today;
    _year     = _today.year;
    _month    = _today.month;
    _loc      = kIsraelLocs[0]; // Jerusalem default
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final data = await _LocationManager.load();
    if (!mounted) return;
    setState(() {
      _israelLocs     = data.israel;
      _worldLocs      = data.world;
      _customLocs     = data.custom;
      _loc            = data.israel.isNotEmpty ? data.israel[0] : kIsraelLocs[0];
      _israel         = _loc.isIsrael;
      _locationsLoaded = true;
    });
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _changeMonth(int delta) => setState(() {
    _month += delta;
    if (_month > 12) { _month = 1; _year++; }
    if (_month < 1)  { _month = 12; _year--; }
  });

  void _goToday() => setState(() {
    final now = DateTime.now();
    _year  = now.year;
    _month = now.month;
    _selected = now;
  });

  void _onCellTap(DateTime d) {
    setState(() => _selected = d);
    widget.onDateSelected?.call(d);
  }

  // ── Location selection ─────────────────────────────────────────────────

  void _onLocChanged(HalachicLocation loc) {
    setState(() {
      _loc    = loc;
      _israel = loc.isIsrael;
    });
  }

  Future<void> _openAddLocation() async {
    final result = await showDialog<HalachicLocation>(
      context: context,
      builder: (_) => const _AddLocationDialog(),
    );
    if (result == null || !mounted) return;
    final data = _LocationData(_israelLocs, _worldLocs, _customLocs);
    await _LocationManager.appendCustom(data, result);
    final refreshed = await _LocationManager.load();
    if (!mounted) return;
    setState(() {
      _israelLocs  = refreshed.israel;
      _worldLocs   = refreshed.world;
      _customLocs  = refreshed.custom;
      _loc         = result;
      _israel      = result.isIsrael;
    });
  }

  // ── Nav header text ───────────────────────────────────────────────────

  String _gregLabel() => '${kGregMonths[_month]} $_year';

  String _hebLabel() {
    final dim  = DateTime(_year, _month + 1, 0).day;
    final jdn1 = g2j(_year, _month, 1);
    final jdnL = g2j(_year, _month, dim);
    final (y1, m1, _)  = j2h(jdn1);
    final (y2, m2, __) = j2h(jdnL);
    if (y1 == y2 && m1 == m2) return '${monthName(m1, y1)} ${hYear(y1)}';
    if (y1 == y2) return '${monthName(m1, y1)}–${monthName(m2, y2)} ${hYear(y1)}';
    return '${monthName(m1, y1)} ${hYear(y1)} – ${monthName(m2, y2)} ${hYear(y2)}';
  }

  // ── Location dropdown items ────────────────────────────────────────────

  List<DropdownMenuItem<HalachicLocation?>> _buildLocItems() {
    DropdownMenuItem<HalachicLocation?> sep(String text) =>
        DropdownMenuItem<HalachicLocation?>(
          value: null,
          enabled: false,
          child: Text(text,
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        );

    return [
      sep('── ארץ ישראל ──'),
      ..._israelLocs.map((l) => DropdownMenuItem<HalachicLocation?>(
            value: l,
            child: Text(l.name, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13)),
          )),
      sep('── גלויות ──'),
      ..._worldLocs.map((l) => DropdownMenuItem<HalachicLocation?>(
            value: l,
            child: Text(l.name, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13)),
          )),
      if (_customLocs.isNotEmpty) ...[
        sep('── מיקומים מותאמים ──'),
        ..._customLocs.map((l) => DropdownMenuItem<HalachicLocation?>(
              value: l,
              child: Text('★ ${l.name}', textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13)),
            )),
      ],
    ];
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pal = _pal;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // ── Nav bar ────────────────────────────────────────────────────
          Container(
            color: pal.navBg,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // ← Prev
                _navBtn('← קודם', () => _changeMonth(-1), pal),
                const SizedBox(width: 6),
                // Month labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_gregLabel(),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: pal.gNumFg)),
                      Text(_hebLabel(),
                          style: TextStyle(fontSize: 11, color: pal.hDateFg)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Today
                _navBtn('היום', _goToday, pal, isTodayBtn: true),
                const SizedBox(width: 6),
                // Next →
                _navBtn('הבא →', () => _changeMonth(1), pal),
                const SizedBox(width: 10),
                // 📍 icon
                const Text('📍', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                // Location dropdown
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: DropdownButton<HalachicLocation?>(
                    value: _loc,
                    items: _locationsLoaded ? _buildLocItems() : [],
                    onChanged: (v) { if (v != null) _onLocChanged(v); },
                    underline: const SizedBox(),
                    isDense: true,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 4),
                // + Add location
                SizedBox(
                  width: 28,
                  height: 28,
                  child: OutlinedButton(
                    onPressed: _openAddLocation,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('＋',
                        style: TextStyle(fontSize: 16, color: Color(0xFF2E7D32))),
                  ),
                ),
              ],
            ),
          ),

          // ── Year strip ────────────────────────────────────────────────
          _YearStrip(gregYear: _year, gregMonth: _month, pal: pal),

          // ── Calendar grid ─────────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                _painter = _CalendarPainter(
                  year: _year,
                  month: _month,
                  today: _today,
                  selected: _selected,
                  israel: _israel,
                  pal: pal,
                  onTap: _onCellTap,
                );
                return GestureDetector(
                  onTapUp: (details) => _painter?.handleTap(details.localPosition),
                  child: CustomPaint(
                    painter: _painter,
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                );
              },
            ),
          ),

          // ── Detail panel ──────────────────────────────────────────────
          _DetailPanel(date: _selected, israel: _israel, pal: pal),

          // ── Legend ───────────────────────────────────────────────────
          _LegendBar(pal: pal),

          // ── Zmanim toggle ────────────────────────────────────────────
          Container(
            color: pal.navBg,
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() => _zmanimOpen = !_zmanimOpen),
                style: TextButton.styleFrom(
                  backgroundColor: pal.btnBg,
                  foregroundColor: pal.btnFg,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                child: Text(
                  _zmanimOpen ? '⏰ זמני הלכה ▲' : '⏰ זמני הלכה ▼',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),

          // ── Zmanim panel (collapsible) ────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _zmanimOpen ? 320 : 0,
            child: _zmanimOpen
                ? _ZmanimPanel(date: _selected, loc: _loc)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(String label, VoidCallback onPressed, CalPalette pal,
      {bool isTodayBtn = false}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isTodayBtn ? pal.btnTodayBg : pal.btnBg,
        foregroundColor: pal.btnFg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}
