// ============================================================
// core/engines/link_manager.dart — מנהל קישורים
// ============================================================
import '../models/link_model.dart';
import '../../utils/hebrew_utils.dart';

class LinkManager {
  final Map<String, LinkModel> _links = {};
  int _counter = 0;
  MarkerStyle markerStyle = MarkerStyle.numbers;
  bool autoNumbering = true;
  List<String> customMarkers = [];

  // ── הוספה ─────────────────────────────────────────────────

  LinkModel addLink({
    required LinkType linkType,
    required int      sourcePos,
    required int      targetPos,
    String sourceText = '',
    String targetText = '',
    String? marker,
  }) {
    final id  = 'link_${++_counter}';
    final mrk = marker ?? (autoNumbering ? _genMarker(linkType) : '');
    final link = LinkModel(
      linkId: id, linkType: linkType,
      sourcePosition: sourcePos, targetPosition: targetPos,
      marker: mrk,
      sourceText: sourceText, targetText: targetText,
    );
    _links[id] = link;
    return link;
  }

  // ── שאילתות ───────────────────────────────────────────────

  bool remove(String linkId) => _links.remove(linkId) != null;

  LinkModel? get(String linkId) => _links[linkId];

  List<LinkModel> getByType(LinkType type) =>
      _links.values.where((l) => l.linkType == type).toList();

  List<LinkModel> getAtPosition(int pos) =>
      _links.values.where((l) => l.sourcePosition == pos).toList();

  List<LinkModel> getAll() => List.unmodifiable(_links.values);

  bool update(String linkId, {String? marker, String? targetText}) {
    final link = _links[linkId];
    if (link == null) return false;
    _links[linkId] = link.copyWith(marker: marker, targetText: targetText);
    return true;
  }

  // ── ולידציה ───────────────────────────────────────────────

  (bool, List<String>) validate() {
    final errors = <String>[];
    for (final link in _links.values) {
      if (link.sourcePosition < 0) {
        errors.add('${link.linkId}: מיקום מקור שלילי');
      }
      if (link.targetPosition < 0) {
        errors.add('${link.linkId}: מיקום יעד שלילי');
      }
      if (link.marker.isEmpty) {
        errors.add('${link.linkId}: חסר סימן');
      }
    }
    return (errors.isEmpty, errors);
  }

  void renumber({LinkType? type}) {
    final links = (type != null ? getByType(type) : getAll())
      ..sort((a, b) => a.sourcePosition.compareTo(b.sourcePosition));
    for (var i = 0; i < links.length; i++) {
      _links[links[i].linkId] =
          links[i].copyWith(marker: _markerByNumber(i + 1, links[i].linkType));
    }
  }

  // ── ייצוא / ייבוא ─────────────────────────────────────────

  List<Map<String, dynamic>> export() =>
      _links.values.map((l) => l.toJson()).toList();

  void importLinks(List<Map<String, dynamic>> data) {
    clear();
    for (final d in data) {
      final link = LinkModel.fromJson(d);
      _links[link.linkId] = link;
    }
  }

  void clear() { _links.clear(); _counter = 0; }

  // ── פנימי ─────────────────────────────────────────────────

  String _genMarker(LinkType type) {
    final count = getByType(type).length + 1;
    return _markerByNumber(count, type);
  }

  String _markerByNumber(int n, LinkType type) {
    return switch (markerStyle) {
      MarkerStyle.numbers =>
          n.toString(),
      MarkerStyle.hebrewLetters =>
          HebrewUtils.numberToHebrew(n, useGeresh: false),
      MarkerStyle.symbols => () {
          const syms = ['*', '**', '***', '†', '‡', '§', '¶'];
          return n <= syms.length ? syms[n - 1] : '*$n';
        }(),
      MarkerStyle.custom => () {
          if (customMarkers.isNotEmpty) {
            return customMarkers[(n - 1) % customMarkers.length];
          }
          return n.toString();
        }(),
    };
  }
}
