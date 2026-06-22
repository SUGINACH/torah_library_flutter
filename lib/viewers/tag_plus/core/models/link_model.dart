// ============================================================
// core/models/link_model.dart — מודל קישור
// ============================================================

enum LinkType {
  footnote, endnote, crossReference, commentary,
  source, internal, external, custom;

  String get hebrewName => const {
    'footnote': 'הערת שוליים',
    'endnote': 'הערת סיום',
    'crossReference': 'הפניה צולבת',
    'commentary': 'פירוש',
    'source': 'מקור',
    'internal': 'פנימי',
    'external': 'חיצוני',
    'custom': 'מותאם',
  }[name]!;
}

enum MarkerStyle { numbers, hebrewLetters, symbols, custom }

class LinkModel {
  final String   linkId;
  final LinkType linkType;
  final int      sourcePosition;
  final int      targetPosition;
  final String   marker;
  final String   sourceText;
  final String   targetText;
  final Map<String, dynamic> metadata;

  const LinkModel({
    required this.linkId,
    required this.linkType,
    required this.sourcePosition,
    required this.targetPosition,
    required this.marker,
    this.sourceText = '',
    this.targetText = '',
    this.metadata   = const {},
  });

  LinkModel copyWith({String? marker, String? targetText}) => LinkModel(
    linkId: linkId, linkType: linkType,
    sourcePosition: sourcePosition, targetPosition: targetPosition,
    marker: marker ?? this.marker,
    sourceText: sourceText,
    targetText: targetText ?? this.targetText,
    metadata: metadata,
  );

  Map<String, dynamic> toJson() => {
    'linkId': linkId, 'linkType': linkType.name,
    'sourcePosition': sourcePosition, 'targetPosition': targetPosition,
    'marker': marker, 'sourceText': sourceText, 'targetText': targetText,
  };

  factory LinkModel.fromJson(Map<String, dynamic> j) => LinkModel(
    linkId: j['linkId'],
    linkType: LinkType.values.byName(j['linkType']),
    sourcePosition: j['sourcePosition'],
    targetPosition: j['targetPosition'],
    marker: j['marker'],
    sourceText: j['sourceText'] ?? '',
    targetText: j['targetText'] ?? '',
  );
}
