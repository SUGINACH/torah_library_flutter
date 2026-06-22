// lib/models/tab_info.dart
//
// Flutter equivalent of the TabInfo @dataclass in main_window.py.
// Serialises to/from JSON exactly as Qt's _save_tabs / _load_tabs_from_settings.

class TabInfo {
  final String tabId;
  String title;
  String path;
  int page;
  bool isOtzaria;
  int? bookId;
  String highlight;
  String authors;

  TabInfo({
    required this.tabId,
    required this.title,
    required this.path,
    this.page = 1,
    this.isOtzaria = false,
    this.bookId,
    this.highlight = '',
    this.authors = '',
  });

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Mirrors the JSON produced by _save_tabs() in main_window.py.
  factory TabInfo.fromJson(Map<String, dynamic> j) => TabInfo(
        tabId: j['id'] as String,
        title: j['title'] as String,
        path: j['path'] as String,
        page: j['page'] as int? ?? 1,
        isOtzaria: j['isOtzaria'] as bool? ?? false,
        bookId: j['bookId'] as int?,
        highlight: (j['highlightText'] as String?) ?? '',
        authors: (j['authors'] as String?) ?? '',
      );

  /// Mirrors the dict comprehension in _save_tabs().
  Map<String, dynamic> toJson() => {
        'id': tabId,
        'title': title,
        'path': path,
        'page': page,
        'isOtzaria': isOtzaria,
        'bookId': bookId,
        'highlightText': highlight,
        'authors': authors,
      };
}
