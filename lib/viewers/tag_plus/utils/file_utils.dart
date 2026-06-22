// ============================================================
// utils/file_utils.dart — פעולות קובץ
// ============================================================
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  // ── קריאה ─────────────────────────────────────────────────

  static Future<String?> readText(String path) async {
    try {
      return await File(path).readAsString(encoding: utf8);
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> readJson(String path) async {
    final text = await readText(path);
    if (text == null) return null;
    try {
      return json.decode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── כתיבה ─────────────────────────────────────────────────

  static Future<bool> writeText(String path, String content,
      {bool backup = true}) async {
    try {
      final file = File(path);
      if (backup && await file.exists()) {
        await file.copy('$path.bak');
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(content, encoding: utf8);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> writeJson(String path, Map<String, dynamic> data,
      {bool backup = true}) async {
    return writeText(path, json.encode(data), backup: backup);
  }

  static Future<bool> writeBytes(String path, List<int> bytes) async {
    try {
      await File(path).parent.create(recursive: true);
      await File(path).writeAsBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── שאילתות ───────────────────────────────────────────────

  static Future<bool> exists(String path) => File(path).exists();

  static String getExtension(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot).toLowerCase() : '';
  }

  static String getFileName(String path) =>
      path.split('/').last.split('\\').last;

  static String getBaseName(String path) {
    final name = getFileName(path);
    final dot  = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(0, dot) : name;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024)       return '$bytes B';
    if (bytes < 1048576)    return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  // ── נתיבי מערכת ───────────────────────────────────────────

  static Future<String> getDocumentsPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (_) {
      return '.';
    }
  }

  static Future<String> getTempPath() async {
    try {
      final dir = await getTemporaryDirectory();
      return dir.path;
    } catch (_) {
      return '.';
    }
  }

  static Future<String> getSettingsPath() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/settings.json';
    } catch (_) {
      return './settings.json';
    }
  }

  // ── ניקוי ─────────────────────────────────────────────────

  static Future<int> cleanTempFiles(String tempDir,
      {int olderThanHours = 24}) async {
    int deleted = 0;
    try {
      final dir = Directory(tempDir);
      if (!await dir.exists()) return 0;
      final cutoff = DateTime.now().subtract(Duration(hours: olderThanHours));
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
            deleted++;
          }
        }
      }
    } catch (_) {}
    return deleted;
  }
}
