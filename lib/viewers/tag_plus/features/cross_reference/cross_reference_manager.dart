// ============================================================
// features/cross_reference/cross_reference_manager.dart
// הפניות פנימיות דינמיות — לעיל / לקמן / שם
// ============================================================
import '../../utils/hebrew_utils.dart';

class Anchor {
  final String anchorId;
  final String name;
  final int    position;
  int          pageNumber;
  final String context;

  Anchor({
    required this.anchorId,
    required this.name,
    required this.position,
    this.pageNumber = 0,
    this.context    = '',
  });

  Map<String, dynamic> toJson() => {
    'anchorId': anchorId, 'name': name, 'position': position,
    'pageNumber': pageNumber, 'context': context,
  };

  factory Anchor.fromJson(Map<String, dynamic> j) => Anchor(
    anchorId: j['anchorId'], name: j['name'],
    position: j['position'], pageNumber: j['pageNumber'] ?? 0,
    context: j['context'] ?? '',
  );
}

class InternalRef {
  final String refId;
  final int    sourcePosition;
  final String targetAnchorId;
  final String refType;    // 'לעיל' | 'לקמן' | 'שם' | 'הנ"ל'
  String       displayText;
  final bool   autoUpdate;

  InternalRef({
    required this.refId,
    required this.sourcePosition,
    required this.targetAnchorId,
    required this.refType,
    this.displayText = '',
    this.autoUpdate  = true,
  });
}

/// דפוסי זיהוי הפניות עבריות
final _refPatterns = <(RegExp, String)>[
  (RegExp(r'עיין\s+לעיל'),           'לעיל'),
  (RegExp(r'כמו\s+שנאמר\s+לעיל'),   'לעיל'),
  (RegExp('כנ"ל'),                   'לעיל'),
  (RegExp('כנ״ל'),                   'לעיל'),
  (RegExp(r'כמו\s+שיתבאר\s+לקמן'),  'לקמן'),
  (RegExp(r'יעויין\s+לקמן'),         'לקמן'),
  (RegExp(r'עיין\s+לקמן'),           'לקמן'),
  (RegExp(r'(?<![א-ת])שם(?![א-ת])'), 'שם'),
  (RegExp('הנ"ל'),                   'הנ"ל'),
  (RegExp('הנ״ל'),                   'הנ"ל'),
];

final _pagePattern = RegExp(
  r"(?:עמוד|עמ'|עמ׳)\s+([א-ת]{1,4}['״]?|[0-9]+)",
);

class CrossReferenceManager {
  final Map<String, Anchor>      _anchors = {};
  final Map<String, InternalRef> _refs    = {};
  int _anchorCounter = 0;
  int _refCounter    = 0;

  // ── עוגנים ────────────────────────────────────────────────

  Anchor registerAnchor({
    required String name,
    required int    position,
    String context = '',
  }) {
    final id = 'anc_${++_anchorCounter}';
    final a  = Anchor(anchorId: id, name: name,
        position: position, context: context);
    _anchors[id] = a;
    return a;
  }

  Anchor? getAnchor(String id)        => _anchors[id];
  List<Anchor> getAllAnchors()         =>
      _anchors.values.toList()..sort((a, b) => a.position.compareTo(b.position));
  Anchor? findAnchorByName(String n)  =>
      _anchors.values.cast<Anchor?>().firstWhere(
          (a) => a?.name == n, orElse: () => null);

  /// שינוי: הוספת מתודה ציבורית למחיקת עוגן כדי למנוע שגיאות קומפילציה ב-UI
  void removeAnchor(String id) {
    _anchors.remove(id);
  }

  // ── הפניות ────────────────────────────────────────────────

  InternalRef? addRef({
    required int    sourcePos,
    required String targetAnchorId,
    String refType = 'לעיל',
  }) {
    if (!_anchors.containsKey(targetAnchorId)) return null;
    final id  = 'ref_${++_refCounter}';
    final anc = _anchors[targetAnchorId]!;
    final ref = InternalRef(
      refId: id, sourcePosition: sourcePos,
      targetAnchorId: targetAnchorId, refType: refType,
      displayText: _buildDisplay(anc, refType),
    );
    _refs[id] = ref;
    return ref;
  }

  List<InternalRef> getAllRefs() => _refs.values.toList();

  // ── עדכון עמודים ──────────────────────────────────────────

  void updatePageNumbers(Map<int, int> pageMap) {
    final positions = pageMap.keys.toList()..sort();

    for (final anc in _anchors.values) {
      anc.pageNumber = _interpolatePage(anc.position, positions, pageMap);
    }
    for (final ref in _refs.values) {
      if (!ref.autoUpdate) continue;
      final anc = _anchors[ref.targetAnchorId];
      if (anc != null) {
        ref.displayText = _buildDisplay(anc, ref.refType);
      }
    }
  }

  static int _interpolatePage(int pos, List<int> sorted, Map<int, int> map) {
    if (sorted.isEmpty) return 1;
    for (final p in sorted.reversed) {
      if (pos >= p) return map[p]!;
    }
    return map[sorted.first]!;
  }

  String _buildDisplay(Anchor anc, String refType) {
    if (refType == 'שם')    return 'שם';
    if (refType == 'הנ"ל')  return 'הנ"ל';
    final pg = anc.pageNumber > 0
        ? HebrewUtils.numberToHebrew(anc.pageNumber) : '?';
    final prefix = refType == 'לעיל' ? 'לעיל' : 'לקמן';
    return anc.context.isNotEmpty
        ? "$prefix ${anc.context} (עמ' $pg)"
        : "$prefix עמ' $pg";
  }

  // ── סריקה ─────────────────────────────────────────────────

  List<(int, String, String)> findRefsInText(String text) {
    final results = <(int, String, String)>[];
    for (final (pattern, type) in _refPatterns) {
      for (final m in pattern.allMatches(text)) {
        results.add((m.start, m.group(0)!, type));
      }
    }
    results.sort((a, b) => a.$1.compareTo(b.$1));
    return results;
  }

  List<(int, String, int)> extractPageRefs(String text) {
    return _pagePattern.allMatches(text).map((m) {
      final raw  = m.group(1)!;
      final page = int.tryParse(raw) ??
          HebrewUtils.hebrewToNumber(raw.replaceAll("'", '').replaceAll('׳', ''));
      return (m.start, m.group(0)!, page);
    }).toList();
  }

  // ── ייצוא ─────────────────────────────────────────────────

  void clear() { _anchors.clear(); _refs.clear();
                 _anchorCounter = _refCounter = 0; }

  Map<String, dynamic> export() => {
    'anchors': _anchors.values.map((a) => a.toJson()).toList(),
    'refs': _refs.values.map((r) => {
      'refId': r.refId, 'sourcePosition': r.sourcePosition,
      'targetAnchorId': r.targetAnchorId,
      'refType': r.refType, 'displayText': r.displayText,
    }).toList(),
  };
}