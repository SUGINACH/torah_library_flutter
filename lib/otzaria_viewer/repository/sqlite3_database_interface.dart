import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:torah_library/otzaria_viewer/text_book/text_book_repository.dart';

class Sqlite3DatabaseInterface implements DatabaseInterface {
  final String dbPath;

  Sqlite3DatabaseInterface({required this.dbPath});

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final db = sqlite.sqlite3.open(dbPath);
    try {
      String cols = (columns != null && columns.isNotEmpty) ? columns.join(', ') : '*';
      String sql = 'SELECT $cols FROM $table';
      if (where != null && where.isNotEmpty) {
        sql += ' WHERE $where';
      }
      if (orderBy != null && orderBy.isNotEmpty) {
        sql += ' ORDER BY $orderBy';
      }
      
      final results = db.prepare(sql).select(whereArgs ?? []);
      return results.map((row) => Map<String, dynamic>.from(row)).toList();
    } finally {
      db.dispose();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = sqlite.sqlite3.open(dbPath);
    try {
      final results = db.prepare(sql).select(arguments ?? []);
      return results.map((row) => Map<String, dynamic>.from(row)).toList();
    } finally {
      db.dispose();
    }
  }
}
