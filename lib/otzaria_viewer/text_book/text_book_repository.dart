import 'package:torah_library/otzaria_viewer/models/books.dart';
import 'package:torah_library/otzaria_viewer/models/links.dart';
import 'package:torah_library/otzaria_viewer/utils/text_manipulation.dart';
/// ממשק מופשט לביצוע שאילתות מול מנהל ה-SQLite באפליקציה שלך
abstract class DatabaseInterface {
  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  });
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]);
}
class TextBookRepository {
  final DatabaseInterface db;
  TextBookRepository({required this.db});
  /// שליפת שורות הספר מתוך טבלת segments
  Future<List<String>> getBookContentList(int bookId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'segments',
      columns: ['content'],
      where: 'id_book = ?',
      whereArgs: [bookId],
      orderBy: 'line_index ASC',
    );
    return maps.map((row) => row['content'] as String).toList();
  }
  /// בניית עץ תוכן העניינים הדו-כיווני
  Future<List<TocEntry>> getTableOfContents(int bookId) async {
    final List<Map<String, dynamic>> rows = await db.query(
      'segments',
      columns: ['line_index', 'content', 'heading_level'],
      where: 'id_book = ? AND heading_level > 0',
      whereArgs: [bookId],
      orderBy: 'line_index ASC',
    );
    List<TocEntry> toc = [];
    Map<int, TocEntry> parents = {};
    for (var row in rows) {
      final int level = row['heading_level'] as int;
      final int index = row['line_index'] as int;
      final String text = stripHtmlIfNeeded(row['content'] as String);
      TocEntry entry = TocEntry(text: text, index: index, level: level);
      if (level == 1) {
        toc.add(entry);
        parents[level] = entry;
      } else {
        TocEntry? parent = parents[level - 1];
        if (parent != null) {
          TocEntry childEntry = TocEntry(
            text: text,
            index: index,
            level: level,
            parent: parent,
          );
          parent.children.add(childEntry);
          parents[level] = childEntry;
        } else {
          toc.add(entry);
          parents[level] = entry;
        }
      }
    }
    return toc;
  }
  /// שליפת קישורים מתוך טבלת detailed_links
  Future<List<Link>> getBookLinks(int bookId) async {
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT l.line_index_1, l.line_index_2, l.connection_type, l.target_ref, l.target_segment_id, b.title as target_title
      FROM links_detailed l
      JOIN books b ON l.target_book_id = b.id
      WHERE l.book_id = ?
    ''', [bookId]); // הוסר התנאי החוסם
    
    return rows.map((row) {
      return Link(
        heRef: row['target_ref'] ?? '',
        index1: (row['line_index_1'] as int) - 1, 
        path2: row['target_title'] ?? '',
        index2: (row['line_index_2'] as int) - 1,
        connectionType: row['connection_type'] ?? 'commentary',
        targetSegmentId: row['target_segment_id'] as int?,
      );
    }).toList();
  }
  /// שליפת רשימת המפרשים הזמינים לספר
  Future<List<String>> getAvailableCommentators(int bookId) async {
    final List<Map<String, dynamic>> rows = await db.query(
      'book_commentaries_index',
      columns: ['commentary_title'],
      where: 'source_book_id = ?',
      whereArgs: [bookId],
    );
    return rows.map((row) => row['commentary_title'] as String).toList();
  }
}
