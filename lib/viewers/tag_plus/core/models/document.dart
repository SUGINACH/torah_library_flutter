// ============================================================
// core/models/document.dart — מודל מסמך
// ============================================================

class TagDocument {
  final String  id;
  final String  content;
  final bool    isModified;
  final String? filePath;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DocumentMetadata metadata;
  final PageSettings pageSettings;

  const TagDocument({
    required this.id,
    this.content     = '',
    this.isModified  = false,
    this.filePath,
    required this.createdAt,
    required this.modifiedAt,
    this.metadata    = const DocumentMetadata(),
    this.pageSettings = const PageSettings(),
  });

  factory TagDocument.empty() {
    final now = DateTime.now();
    return TagDocument(
      id: 'doc_${now.millisecondsSinceEpoch}',
      createdAt: now, modifiedAt: now,
    );
  }

  String get displayName {
    if (filePath != null) {
      return filePath!.split('/').last.split('\\').last;
    }
    return metadata.title.isNotEmpty ? metadata.title : 'מסמך ללא שם';
  }

  bool get isNew => filePath == null;

  TagDocument copyWith({
    String? content, bool? isModified, String? filePath,
    DateTime? modifiedAt, DocumentMetadata? metadata,
    PageSettings? pageSettings,
  }) => TagDocument(
    id: id,
    content: content ?? this.content,
    isModified: isModified ?? this.isModified,
    filePath: filePath ?? this.filePath,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    metadata: metadata ?? this.metadata,
    pageSettings: pageSettings ?? this.pageSettings,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'content': content,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
    'metadata': metadata.toJson(),
    'pageSettings': pageSettings.toJson(),
  };

  factory TagDocument.fromJson(Map<String, dynamic> j) => TagDocument(
    id: j['id'] ?? 'doc_0',
    content: j['content'] ?? '',
    filePath: j['filePath'],
    createdAt: DateTime.parse(j['createdAt']),
    modifiedAt: DateTime.parse(j['modifiedAt']),
    metadata: j['metadata'] != null
        ? DocumentMetadata.fromJson(j['metadata']) : const DocumentMetadata(),
    pageSettings: j['pageSettings'] != null
        ? PageSettings.fromJson(j['pageSettings']) : const PageSettings(),
  );
}

/// מטא-דאטה של מסמך
class DocumentMetadata {
  final String title;
  final String author;
  final String subject;
  final List<String> keywords;
  final String language;

  const DocumentMetadata({
    this.title    = '',
    this.author   = '',
    this.subject  = '',
    this.keywords = const [],
    this.language = 'he',
  });

  DocumentMetadata copyWith({String? title, String? author, String? subject}) =>
    DocumentMetadata(
      title: title ?? this.title,
      author: author ?? this.author,
      subject: subject ?? this.subject,
      keywords: keywords,
      language: language,
    );

  Map<String, dynamic> toJson() => {
    'title': title, 'author': author,
    'subject': subject, 'keywords': keywords, 'language': language,
  };

  factory DocumentMetadata.fromJson(Map<String, dynamic> j) => DocumentMetadata(
    title: j['title'] ?? '', author: j['author'] ?? '',
    subject: j['subject'] ?? '',
    keywords: List<String>.from(j['keywords'] ?? []),
    language: j['language'] ?? 'he',
  );
}

/// הגדרות עמוד של מסמך
class PageSettings {
  final double width;
  final double height;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final double marginInner;
  final double marginOuter;
  final bool   mirrorMargins;
  final String orientation;

  const PageSettings({
    this.width        = 170,
    this.height       = 240,
    this.marginTop    = 20,
    this.marginBottom = 20,
    this.marginLeft   = 15,
    this.marginRight  = 15,
    this.marginInner  = 20,
    this.marginOuter  = 15,
    this.mirrorMargins = true,
    this.orientation  = 'portrait',
  });

  PageSettings copyWith({
    double? width, double? height,
    double? marginTop, double? marginBottom,
    double? marginLeft, double? marginRight,
  }) => PageSettings(
    width: width ?? this.width,
    height: height ?? this.height,
    marginTop: marginTop ?? this.marginTop,
    marginBottom: marginBottom ?? this.marginBottom,
    marginLeft: marginLeft ?? this.marginLeft,
    marginRight: marginRight ?? this.marginRight,
    marginInner: marginInner, marginOuter: marginOuter,
    mirrorMargins: mirrorMargins, orientation: orientation,
  );

  double get textWidth => width - marginInner - marginOuter;
  double get textHeight => height - marginTop - marginBottom;

  Map<String, dynamic> toJson() => {
    'width': width, 'height': height,
    'marginTop': marginTop, 'marginBottom': marginBottom,
    'marginLeft': marginLeft, 'marginRight': marginRight,
    'marginInner': marginInner, 'marginOuter': marginOuter,
    'mirrorMargins': mirrorMargins, 'orientation': orientation,
  };

  factory PageSettings.fromJson(Map<String, dynamic> j) => PageSettings(
    width: (j['width'] ?? 170).toDouble(),
    height: (j['height'] ?? 240).toDouble(),
    marginTop: (j['marginTop'] ?? 20).toDouble(),
    marginBottom: (j['marginBottom'] ?? 20).toDouble(),
    marginLeft: (j['marginLeft'] ?? 15).toDouble(),
    marginRight: (j['marginRight'] ?? 15).toDouble(),
    marginInner: (j['marginInner'] ?? 20).toDouble(),
    marginOuter: (j['marginOuter'] ?? 15).toDouble(),
    mirrorMargins: j['mirrorMargins'] ?? true,
    orientation: j['orientation'] ?? 'portrait',
  );
}
