// ============================================================
// core/engines/text_engine.dart — מנוע טקסט ופסקאות
// ============================================================
import '../models/paragraph.dart';
import '../../config/text_config.dart';
import '../../utils/hebrew_utils.dart';

/// תוצאת ניתוח תגיות
class ParseResult {
  final List<Paragraph> paragraphs;
  final int taggedCount;
  const ParseResult(this.paragraphs, this.taggedCount);
}

/// מנוע טקסט — ניהול פסקאות, ניתוח תגיות, ייצוא
class TextEngine {
  final List<Paragraph> _paragraphs = [];
  int _counter = 0;

  String _newId() => 'p_${++_counter}';

  // ── ניהול פסקאות ──────────────────────────────────────────

  int addParagraph(String text, {
    ParagraphType type = ParagraphType.normal,
    TextStyleModel? style,
    int? position,
  }) {
    final para = Paragraph(
      id: _newId(), text: text, type: type,
      style: style ?? Paragraph.defaultStyleFor(type),
    );
    if (position == null) {
      _paragraphs.add(para);
      return _paragraphs.length - 1;
    } else {
      _paragraphs.insert(position, para);
      return position;
    }
  }

  bool removeParagraph(int index) {
    if (index < 0 || index >= _paragraphs.length) return false;
    _paragraphs.removeAt(index);
    return true;
  }

  Paragraph? getParagraph(int index) =>
      (index >= 0 && index < _paragraphs.length) ? _paragraphs[index] : null;

  bool updateText(int index, String text) {
    if (index < 0 || index >= _paragraphs.length) return false;
    _paragraphs[index] = _paragraphs[index].copyWith(text: text);
    return true;
  }

  bool updateStyle(int index, TextStyleModel style) {
    if (index < 0 || index >= _paragraphs.length) return false;
    _paragraphs[index] = _paragraphs[index].copyWith(style: style);
    return true;
  }

  List<Paragraph> getAll() => List.unmodifiable(_paragraphs);
  int get count => _paragraphs.length;

  void clear() => _paragraphs.clear();

  // ── טקסט מלא ──────────────────────────────────────────────

  String getFullText({bool includeNikud = true}) {
    final parts = _paragraphs.map((p) => includeNikud
        ? p.text
        : HebrewUtils.removeNikudAndTeamim(p.text));
    return parts.join('\n\n');
  }

  Map<String, int> getStatistics() {
    final full = getFullText();
    return {
      'paragraphs': _paragraphs.length,
      'words':      HebrewUtils.countWords(full),
      'chars':      full.length,
    };
  }

  // ── ניתוח תגיות ───────────────────────────────────────────

  static final Map<String, ParagraphType> _tagMap = {
    TextTags.title:      ParagraphType.title,
    TextTags.subtitle:   ParagraphType.subtitle,
    TextTags.chapter:    ParagraphType.chapter,
    TextTags.section:    ParagraphType.section,
    TextTags.subsection: ParagraphType.subsection,
    TextTags.quote:      ParagraphType.quote,
    TextTags.commentary: ParagraphType.commentary,
    TextTags.footnote:   ParagraphType.footnote,
    TextTags.rashi:      ParagraphType.rashi,
    TextTags.tosafot:    ParagraphType.tosafot,
  };

  ParseResult parseTaggedText(String text) {
    final paragraphs = <Paragraph>[];
    ParagraphType currentType = ParagraphType.normal;
    final currentLines = <String>[];
    int taggedCount = 0;

    void flush() {
      if (currentLines.isNotEmpty) {
        paragraphs.add(Paragraph(
          id: _newId(),
          text: currentLines.join('\n'),
          type: currentType,
          style: Paragraph.defaultStyleFor(currentType),
        ));
        currentLines.clear();
        currentType = ParagraphType.normal;
      }
    }

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) { flush(); continue; }

      String? matchedTag;
      ParagraphType matchedType = ParagraphType.normal;

      for (final entry in _tagMap.entries) {
        if (line.startsWith(entry.key)) {
          matchedTag  = entry.key;
          matchedType = entry.value;
          break;
        }
      }

      if (matchedTag != null) {
        flush();
        taggedCount++;
        currentType = matchedType;
        final rest = line.substring(matchedTag.length).trim();
        if (rest.isNotEmpty) {
          currentLines.add(rest);
          flush();
        }
      } else {
        currentLines.add(line);
      }
    }
    flush();
    return ParseResult(paragraphs, taggedCount);
  }

  void loadFromTagged(String text) {
    clear();
    final result = parseTaggedText(text);
    _paragraphs.addAll(result.paragraphs);
  }

  String exportToTagged() {
    final reverseMap = _tagMap.map((k, v) => MapEntry(v, k));
    return _paragraphs.map((p) {
      final tag = reverseMap[p.type];
      return tag != null ? '$tag ${p.text}' : p.text;
    }).join('\n\n');
  }

  // ── סריאליזציה ────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'paragraphs': _paragraphs.map((p) => p.toJson()).toList(),
  };

  void fromJson(Map<String, dynamic> j) {
    clear();
    for (final pd in (j['paragraphs'] as List? ?? [])) {
      _paragraphs.add(Paragraph.fromJson(pd as Map<String, dynamic>));
    }
  }
}
