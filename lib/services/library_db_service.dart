import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'library_service.dart'; // ודא שהנתיב ל-library_service.dart שלך תקין

class BookIndexEntry {
  final String sortKey;
  final String dbType;
  final dynamic id;
  BookIndexEntry(this.sortKey, this.dbType, this.id);
}

class LibraryDbService implements LibraryService {
  final String searchDbPath;
  final String otzariaDbPath;
  final Map<String, List<BookIndexEntry>> _booksIndexCache = {};

  LibraryDbService({required this.searchDbPath, required this.otzariaDbPath});

  static String normalizeHebrewSortKey(String text) {
    if (text.isEmpty) return "";
    String s = text.replaceAll(RegExp(r'[\u0591-\u05C7]'), '');
    s = s.replaceAll(RegExp(r'[\u200f\u200e\u200b"״׳”’`\-־–—\(\)\[\]\{\}]'), '');
    s = s.trim();
    s = s.replaceFirst(RegExp(r'^(ספר|פירוש|מדרש|שות|שאלות ותשובות|מסכת)\s+'), '');
    return s.toLowerCase().trim();
  }

  void invalidateCache() => _booksIndexCache.clear();

  List<BookIndexEntry> _buildSortedIndex(String? query) {
    final q = (query ?? "").trim().toLowerCase();
    if (_booksIndexCache.containsKey(q)) return _booksIndexCache[q]!;

    final List<BookIndexEntry> index = [];
    if (File(searchDbPath).existsSync()) {
      final db = sqlite3.open(searchDbPath);
      try {
        ResultSet rows = q.isNotEmpty
            ? db.prepare("SELECT path, file_name, meta_title FROM books WHERE lower(file_name) LIKE ? OR lower(meta_title) LIKE ?").select(["%$q%", "%$q%"])
            : db.select("SELECT path, file_name, meta_title FROM books");
        for (final r in rows) {
          final title = r['meta_title'] ?? r['file_name'] ?? '';
          index.add(BookIndexEntry(normalizeHebrewSortKey(title.toString()), 'pdf', r['path']));
        }
      } finally { db.dispose(); }
    }

    if (File(otzariaDbPath).existsSync()) {
      final db = sqlite3.open(otzariaDbPath);
      try {
        ResultSet rows = q.isNotEmpty
            ? db.prepare("SELECT id, title FROM books WHERE lower(title) LIKE ?").select(["%$q%"])
            : db.select("SELECT id, title FROM books");
        for (final r in rows) {
          index.add(BookIndexEntry(normalizeHebrewSortKey(r['title'].toString()), 'otzaria', r['id']));
        }
      } finally { db.dispose(); }
    }
    index.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    _booksIndexCache[q] = index;
    return index;
  }

  @override
  Future<int> booksCount() async => _buildSortedIndex("").length;

  int getBooksCount(String query) => _buildSortedIndex(query).length;

  @override
  Future<Map<String, dynamic>> listBooks({String? q, int limit = 70, int offset = 0}) async {
    return {'total': _buildSortedIndex(q).length, 'items': getBooksRange(offset, limit, q ?? "")};
  }

  List<Map<String, dynamic>> getBooksRange(int offset, int limit, String query) {
    final index = _buildSortedIndex(query);
    if (index.isEmpty || offset >= index.length) return [];
    final end = (offset + limit).clamp(0, index.length);
    final slice = index.sublist(offset, end);

    final pdfIds = slice.where((e) => entryType(e) == 'pdf').map((e) => e.id as String).toList();
    final otzIds = slice.where((e) => entryType(e) == 'otzaria').map((e) => e.id as int).toList();

    final Map<String, Map<String, dynamic>> pdfRows = {};
    final Map<int, Map<String, dynamic>> otzRows = {};

    if (pdfIds.isNotEmpty && File(searchDbPath).existsSync()) {
      final db = sqlite3.open(searchDbPath);
      try {
        final placeholders = List.filled(pdfIds.length, '?').join(',');
        final results = db.prepare("SELECT path, file_name, meta_title, authors, source_folder, page_count FROM books WHERE path IN ($placeholders)").select(pdfIds);
        for (final r in results) {
          pdfRows[r['path'] as String] = {'path': r['path'], 'file_name': r['file_name'], 'meta_title': r['meta_title'], 'authors': r['authors'], 'source_folder': r['source_folder'], 'page_count': r['page_count'], 'is_otzaria': false};
        }
      } finally { db.dispose(); }
    }

    if (otzIds.isNotEmpty && File(otzariaDbPath).existsSync()) {
      final db = sqlite3.open(otzariaDbPath);
      try {
        final placeholders = List.filled(otzIds.length, '?').join(',');
        final results = db.prepare("SELECT id, path, title, category, author FROM books WHERE id IN ($placeholders)").select(otzIds);
        for (final r in results) {
          otzRows[r['id'] as int] = {'bookId': r['id'], 'file_name': r['title'], 'meta_title': r['title'], 'authors': r['author'], 'path': r['path'], 'source_folder': 'otzaria', 'is_otzaria': true, 'page_count': 0};
        }
      } finally { db.dispose(); }
    }

    return slice.map((entry) {
      if (entryType(entry) == 'pdf') return pdfRows[entry.id as String] ?? _fallbackRow(entry.id, 'pdf');
      return otzRows[entry.id as int] ?? _fallbackRow(entry.id, 'otzaria');
    }).toList();
  }

  String entryType(BookIndexEntry e) => e.dbType;

  Map<String, dynamic> _fallbackRow(dynamic id, String dbType) => {
    'bookId': dbType == 'otzaria' ? id : null, 'file_name': 'שגיאה', 'meta_title': 'שגיאה', 'path': id.toString(), 'source_folder': 'MoreBooks', 'is_otzaria': dbType == 'otzaria', 'page_count': 0
  };

  @override
  Future<List<Map<String, dynamic>>> fulltextSearch(String query, String logic, {int limit = 100, int offset = 0, List<String>? bookPaths}) async {
    return _fulltextSearchInternalSync(query, logic, limit, offset, bookPaths);
  }

  List<Map<String, dynamic>> _fulltextSearchInternalSync(String query, String logic, int limit, int offset, List<String>? bookPaths) {
    final List<Map<String, dynamic>> results = [];
    if (File(searchDbPath).existsSync()) {
      final db = sqlite3.open(searchDbPath);
      try {
        final ftsQuery = logic == "phrase" ? '"$query"' : query.split(' ').join(' OR ');
        var sql = "SELECT fts.path, fts.page_no, snippet(fts, 0, '<mark>', '</mark>', '...', 20) as snippet, books.file_name, books.meta_title, books.authors, books.source_folder FROM fts LEFT JOIN books ON fts.path = books.path WHERE fts.content MATCH ?";
        final List<Object?> params = [ftsQuery];
        if (bookPaths != null && bookPaths.isNotEmpty) {
          sql += " AND fts.path IN (${List.filled(bookPaths.length, '?').join(',')})";
          params.addAll(bookPaths);
        }
        sql += " LIMIT ? OFFSET ?";
        params.addAll([limit, offset]);
        final rows = db.prepare(sql).select(params);
        for (final r in rows) {
          results.add({'type': 'pdf', 'file_name': r['file_name'] ?? '', 'meta_title': r['meta_title'] ?? '', 'path': r['path'] ?? '', 'page_no': r['page_no'] ?? 1, 'snippet': r['snippet'] ?? '', 'authors': r['authors'] ?? '', 'source_folder': r['source_folder'] ?? '', 'is_otzaria': false});
        }
      } finally { db.dispose(); }
    }
    return results;
  }

  @override
  Future<List<Map<String, dynamic>>> semanticSearch(String query, {int limit = 100, int offset = 0, List<String>? bookPaths}) async => [];

  @override
  Future<List<Map<String, dynamic>>> quickNav(String query) async {
    final List<Map<String, dynamic>> results = [];
    if (!File(otzariaDbPath).existsSync()) return results;
    final db = sqlite3.open(otzariaDbPath);
    try {
      final tokens = query.trim().split(RegExp(r'\s+'));
      if (tokens.isEmpty) return results;
      final term = "%${tokens[0]}%";
      final rows = db.prepare("SELECT id, path, title, category FROM books WHERE title LIKE ? LIMIT 10").select([term]);
      for (final r in rows) {
        results.add({'path': "${r['category']} > ${r['title']}", 'bookPath': r['path'], 'bookId': r['id'], 'lineIndex': 0, 'type': 'book'});
      }
    } finally { db.dispose(); }
    return results;
  }

  @override
  Future<bool> semanticIndexAvailable() async => false;

  @override
  Future<bool> pdfExists(String p) async => File(p).existsSync();

  @override
  Future<List<Map<String, dynamic>>> pdfOutline(String p) async => [];

  @override
  Future<List<Map<String, dynamic>>> getOtzariaBook(int bookId) async {
    final List<Map<String, dynamic>> segments = [];
    if (!File(otzariaDbPath).existsSync()) return segments;
    final db = sqlite3.open(otzariaDbPath);
    try {
      final rows = db.prepare('SELECT id, line_index, content, heading_level FROM segments WHERE id_book = ? ORDER BY line_index').select([bookId]);
      for (final r in rows) {
        segments.add({'id': r['id'], 'line_index': r['line_index'], 'content': r['content'] ?? '', 'heading_level': r['heading_level'] ?? 0});
      }
    } finally { db.dispose(); }
    return segments;
  }

  @override
  Future<Map<String, dynamic>> getBookMetadata(int bookId) async {
    if (!File(otzariaDbPath).existsSync()) return {'available_commentaries': [], 'links_map': <int, bool>{}};
    final db = sqlite3.open(otzariaDbPath);
    try {
      final commRows = db.prepare('SELECT commentary_book_id as id, commentary_title as title FROM book_commentaries_index WHERE source_book_id = ?').select([bookId]);
      final linksRows = db.prepare('SELECT DISTINCT line_index_1 FROM links_detailed WHERE book_id = ? AND is_commentary = 0').select([bookId]);
      final Map<int, bool> lMap = {};
      for (final r in linksRows) {
        if (r['line_index_1'] != null) lMap[r['line_index_1'] as int] = true;
      }
      return {'available_commentaries': commRows.map((r) => {'id': r['id'], 'title': r['title'] ?? ''}).toList(), 'links_map': lMap};
    } finally { db.dispose(); }
  }

  @override
  Future<List<Map<String, dynamic>>> getLinksForLine(int bookId, int lineIndex) async {
    if (!File(otzariaDbPath).existsSync()) return [];
    final db = sqlite3.open(otzariaDbPath);
    try {
      return db.prepare('SELECT l.target_segment_id, l.target_ref, b.title as target_book_title FROM links_detailed l JOIN books b ON l.target_book_id = b.id WHERE l.book_id = ? AND l.line_index_1 = ?').select([bookId, lineIndex]).map((r) => {
        'target_segment_id': r['target_segment_id'], 'target_ref': r['target_ref'] ?? '', 'target_book_title': r['target_book_title'] ?? ''
      }).toList();
    } finally { db.dispose(); }
  }

  @override
  Future<Map<String, dynamic>> getSegment(int segmentId) async {
    if (!File(otzariaDbPath).existsSync()) return {'content': ''};
    final db = sqlite3.open(otzariaDbPath);
    try {
      final rows = db.prepare('SELECT content FROM segments WHERE id = ?').select([segmentId]);
      final content = rows.isNotEmpty ? (rows.first['content'] ?? '') : "";
      return {'content': content};
    } finally { db.dispose(); }
  }

  @override
  Future<Map<String, dynamic>> getCommentaryMapping(int sourceBookId, int commentaryBookId) async {
    final Map<String, dynamic> mapping = {};
    if (!File(otzariaDbPath).existsSync()) return mapping;
    final db = sqlite3.open(otzariaDbPath);
    try {
      final rows = db.prepare('SELECT line_index_1, target_segment_id FROM links_detailed WHERE book_id = ? AND target_book_id = ?').select([sourceBookId, commentaryBookId]);
      for (final r in rows) {
        final key = r['line_index_1'].toString();
        if (!mapping.containsKey(key)) {
          mapping[key] = <int>[];
        }
        (mapping[key] as List<int>).add(r['target_segment_id'] as int);
      }
    } finally { db.dispose(); }
    return mapping;
  }

  @override
  Future<void> invalidateBooksCache() async {
    invalidateCache();
  }

  @override
  Future<int?> getBookIdByPath(String path) async {
    if (!File(otzariaDbPath).existsSync()) return null;
    final db = sqlite3.open(otzariaDbPath);
    try {
      final rows = db.prepare('SELECT id FROM books WHERE title = ?').select([path]);
      if (rows.isNotEmpty) {
        return rows.first['id'] as int;
      }
    } finally {
      db.dispose();
    }
    return null;
  }
}