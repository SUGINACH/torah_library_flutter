// lib/services/library_service.dart
// Abstract interface mirroring every function imported from library_service.py
// across all widgets: main_window, pdf_viewer, otzaria_viewer.

abstract class LibraryService {
  // ── main_window / books panel ──────────────────────────────────────────────

  Future<int> booksCount();

  /// Returns {'total': int, 'items': List<Map<String, dynamic>>}
  /// Each item: path, bookId, meta_title, file_name, authors, is_otzaria,
  ///            source_folder, page_count
  Future<Map<String, dynamic>> listBooks({
    String? q,
    int limit = 70,
    int offset = 0,
  });

  /// logic: 'and' | 'or' | 'phrase'
  Future<List<Map<String, dynamic>>> fulltextSearch(
    String query,
    String logic, {
    int limit = 100,
    int offset = 0,
    List<String>? bookPaths,
  });

  Future<List<Map<String, dynamic>>> semanticSearch(
    String query, {
    int limit = 100,
    int offset = 0,
    List<String>? bookPaths,
  });

  /// Returns [{path, bookPath, bookId, lineIndex}, ...]
  Future<List<Map<String, dynamic>>> quickNav(String query);

  Future<bool> semanticIndexAvailable();

  // ── pdf_viewer ─────────────────────────────────────────────────────────────

  /// True if the file at [path] exists and is readable.
  Future<bool> pdfExists(String path);

  /// Returns [{title, page, level}, ...] for the PDF outline/TOC.
  Future<List<Map<String, dynamic>>> pdfOutline(String path);

  // ── otzaria_viewer ─────────────────────────────────────────────────────────

  /// Returns full segment list for a book.
  /// Each segment: {line_index, content, heading_level?, ...}
  Future<List<Map<String, dynamic>>> getOtzariaBook(int bookId);

  /// Returns {links_map: {lineAdj: [link,...]}, available_commentaries: [...]}
  Future<Map<String, dynamic>> getBookMetadata(int bookId);

  /// Returns {cid: {lineAdj: [segmentId, ...]}} mapping for one commentary.
  Future<Map<String, dynamic>> getCommentaryMapping(int bookId, int commentaryId);

  /// Links attached to a given 1-based line index.
  Future<List<Map<String, dynamic>>> getLinksForLine(int bookId, int lineIndex);

  /// Returns {content: String} for one segment by ID.
  Future<Map<String, dynamic>> getSegment(int segmentId);

  // ── update_dialog ──────────────────────────────────────────────────────────

  /// Invalidate the sorted-books cache (called after indexing).
  Future<void> invalidateBooksCache();

  Future<int?> getBookIdByPath(String path);
}
