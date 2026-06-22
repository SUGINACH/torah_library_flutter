// ============================================================
// core/models/paragraph.dart — מודל פסקה וסגנון טקסט
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/text_config.dart';

/// סגנון טקסט מלא
class TextStyleModel {
  final String  fontFamily;
  final double  fontSize;
  final bool    bold;
  final bool    italic;
  final bool    underline;
  final bool    strikethrough;
  final String  color;           // hex "#RRGGBB"
  final String? backgroundColor;
  final double  lineSpacing;
  final double  paragraphSpacing;
  final TagTextAlignment alignment;
  final bool    rtl;
  final double  firstLineIndent;

  const TextStyleModel({
    this.fontFamily        = 'David',
    this.fontSize          = 12,
    this.bold              = false,
    this.italic            = false,
    this.underline         = false,
    this.strikethrough     = false,
    this.color             = '#000000',
    this.backgroundColor,
    this.lineSpacing       = 1.15,
    this.paragraphSpacing  = 6,
    this.alignment         = TagTextAlignment.justify,
    this.rtl               = true,
    this.firstLineIndent   = 0,
  });

  TextStyleModel copyWith({
    String? fontFamily, double? fontSize, bool? bold, bool? italic,
    bool? underline, bool? strikethrough, String? color,
    String? backgroundColor, double? lineSpacing,
    double? paragraphSpacing, TagTextAlignment? alignment,
    bool? rtl, double? firstLineIndent,
  }) => TextStyleModel(
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    strikethrough: strikethrough ?? this.strikethrough,
    color: color ?? this.color,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    alignment: alignment ?? this.alignment,
    rtl: rtl ?? this.rtl,
    firstLineIndent: firstLineIndent ?? this.firstLineIndent,
  );

  Map<String, dynamic> toJson() => {
    'fontFamily': fontFamily, 'fontSize': fontSize,
    'bold': bold, 'italic': italic, 'underline': underline,
    'strikethrough': strikethrough, 'color': color,
    'backgroundColor': backgroundColor, 'lineSpacing': lineSpacing,
    'paragraphSpacing': paragraphSpacing, 'alignment': alignment.name,
    'rtl': rtl, 'firstLineIndent': firstLineIndent,
  };

  factory TextStyleModel.fromJson(Map<String, dynamic> j) => TextStyleModel(
    fontFamily: j['fontFamily'] ?? 'David',
    fontSize: (j['fontSize'] ?? 12).toDouble(),
    bold: j['bold'] ?? false,
    italic: j['italic'] ?? false,
    underline: j['underline'] ?? false,
    strikethrough: j['strikethrough'] ?? false,
    color: j['color'] ?? '#000000',
    backgroundColor: j['backgroundColor'],
    lineSpacing: (j['lineSpacing'] ?? 1.15).toDouble(),
    paragraphSpacing: (j['paragraphSpacing'] ?? 6).toDouble(),
    alignment: TagTextAlignment.values.byName(j['alignment'] ?? 'justify'),
    rtl: j['rtl'] ?? true,
    firstLineIndent: (j['firstLineIndent'] ?? 0).toDouble(),
  );
}

/// סוג פסקה
enum ParagraphType {
  normal, title, subtitle, chapter, section, subsection,
  quote, commentary, footnote, rashi, tosafot, header, footer;

  String get hebrewName => const {
    'normal': 'רגיל', 'title': 'כותרת', 'subtitle': 'תת-כותרת',
    'chapter': 'פרק', 'section': 'סימן', 'subsection': 'סעיף',
    'quote': 'ציטוט', 'commentary': 'פירוש', 'footnote': 'הערה',
    'rashi': 'רש"י', 'tosafot': 'תוספות',
    'header': 'כותרת עליונה', 'footer': 'כותרת תחתונה',
  }[name]!;
}

/// פסקה בודדת
class Paragraph {
  final String        id;
  final String        text;
  final ParagraphType type;
  final TextStyleModel style;
  final List<String>  tags;
  final String?       anchorId;
  final List<String>  indexMarks;
  final Map<String, dynamic> metadata;

  const Paragraph({
    required this.id,
    required this.text,
    this.type     = ParagraphType.normal,
    TextStyleModel? style,
    this.tags      = const [],
    this.anchorId,
    this.indexMarks = const [],
    this.metadata   = const {},
  }) : style = style ?? const TextStyleModel();

  Paragraph copyWith({
    String? text, ParagraphType? type, TextStyleModel? style,
    List<String>? tags, String? anchorId, List<String>? indexMarks,
  }) => Paragraph(
    id: id,
    text: text ?? this.text,
    type: type ?? this.type,
    style: style ?? this.style,
    tags: tags ?? this.tags,
    anchorId: anchorId ?? this.anchorId,
    indexMarks: indexMarks ?? this.indexMarks,
    metadata: metadata,
  );

  bool get isEmpty => text.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id, 'text': text, 'type': type.name,
    'style': style.toJson(), 'tags': tags,
    'anchorId': anchorId, 'indexMarks': indexMarks,
  };

  factory Paragraph.fromJson(Map<String, dynamic> j) => Paragraph(
    id: j['id'] ?? UniqueKey().toString(),
    text: j['text'] ?? '',
    type: ParagraphType.values.byName(j['type'] ?? 'normal'),
    style: j['style'] != null ? TextStyleModel.fromJson(j['style']) : null,
    tags: List<String>.from(j['tags'] ?? []),
    anchorId: j['anchorId'],
    indexMarks: List<String>.from(j['indexMarks'] ?? []),
  );

  /// ברירות מחדל לפי סוג
  static TextStyleModel defaultStyleFor(ParagraphType t) {
    return switch (t) {
      ParagraphType.title      => const TextStyleModel(fontSize:18, bold:true,  alignment: TagTextAlignment.center),
      ParagraphType.subtitle   => const TextStyleModel(fontSize:16, bold:true,  alignment: TagTextAlignment.center),
      ParagraphType.chapter    => const TextStyleModel(fontSize:14, bold:true,  alignment: TagTextAlignment.center),
      ParagraphType.section    => const TextStyleModel(fontSize:13, bold:true,  alignment: TagTextAlignment.right),
      ParagraphType.quote      => const TextStyleModel(fontSize:11, italic:true),
      ParagraphType.commentary => const TextStyleModel(fontSize:10, lineSpacing:1.1),
      ParagraphType.footnote   => const TextStyleModel(fontSize:9,  lineSpacing:1.1),
      ParagraphType.rashi      => const TextStyleModel(fontFamily:'FrankRuehl', fontSize:10),
      ParagraphType.tosafot    => const TextStyleModel(fontSize:10, lineSpacing:1.1),
      _                        => const TextStyleModel(),
    };
  }
}
