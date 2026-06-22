// lib/services/display_settings_export_service.dart
// שיפור #4: ייצוא/ייבוא הגדרות

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/item_display_settings.dart';

class DisplaySettingsExportService {
  static const String _settingsKey = 'display_settings_export';
  
  // ייצוא הגדרות לקובץ JSON
  static Future<File> exportSettings({
    required List<ItemDisplaySettings> settings,
    String? fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/display_settings_${fileName ?? timestamp}.json';
    
    final jsonData = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.map((s) => s.toJson()).toList(),
    };
    
    final file = File(filePath);
    await file.writeAsString(jsonEncode(jsonData));
    
    return file;
  }
  
  // ייבוא הגדרות מקובץ JSON
  static Future<List<ItemDisplaySettings>> importSettings(File file) async {
    final content = await file.readAsString();
    final jsonData = jsonDecode(content) as Map<String, dynamic>;
    
    if (jsonData['version'] != '1.0') {
      throw Exception('גרסת קובץ לא נתמכת');
    }
    
    final settingsList = (jsonData['settings'] as List)
        .map((s) => ItemDisplaySettings.fromJson(s as Map<String, dynamic>))
        .toList();
    
    return settingsList;
  }
  
  // שמירת הגדרות ל-SharedPreferences
  static Future<void> saveSettingsToPrefs({
    required List<ItemDisplaySettings> settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = settings.map((s) => s.toJson()).toList();
    await prefs.setString(_settingsKey, jsonEncode(jsonData));
  }
  
  // טעינת הגדרות מ-SharedPreferences
  static Future<List<ItemDisplaySettings>> loadSettingsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    
    if (raw == null) {
      return [];
    }
    
    final jsonData = jsonDecode(raw) as List;
    return jsonData
        .map((s) => ItemDisplaySettings.fromJson(s as Map<String, dynamic>))
        .toList();
  }
  
  // יצירת גיבוי אוטומטי
  static Future<File> createBackup() async {
    final settings = await loadSettingsFromPrefs();
    if (settings.isEmpty) {
      throw Exception('אין הגדרות לגיבוי');
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return await exportSettings(
      settings: settings,
      fileName: 'backup_$timestamp',
    );
  }
  
  // שחזור מגיבוי
  static Future<void> restoreFromBackup(File backupFile) async {
    final settings = await importSettings(backupFile);
    await saveSettingsToPrefs(settings: settings);
  }
  
  // שיתוף הגדרות כמחרוזת Base64 (לשיתוף מהיר)
  static Future<String> exportToString(List<ItemDisplaySettings> settings) async {
    final jsonData = settings.map((s) => s.toJson()).toList();
    final jsonString = jsonEncode(jsonData);
    return base64Encode(utf8.encode(jsonString));
  }
  
  // ייבוא הגדרות ממחרוזת Base64
  static Future<List<ItemDisplaySettings>> importFromString(String encoded) async {
    try {
      final jsonString = utf8.decode(base64Decode(encoded));
      final jsonData = jsonDecode(jsonString) as List;
      return jsonData
          .map((s) => ItemDisplaySettings.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('מחרוזת לא חוקית');
    }
  }
}

// Dialog לייצוא/ייבוא הגדרות
class ExportImportDialog extends StatelessWidget {
  final Function(List<ItemDisplaySettings>) onImport;
  
  const ExportImportDialog({
    super.key,
    required this.onImport,
  });
  
  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context, listen: false);
    final palette = themeProv.palette;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.import_export, color: palette.accent),
          const SizedBox(width: 12),
          Text('ייצוא/ייבוא הגדרות',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ניהול הגדרות תצוגה',
                style: TextStyle(fontSize: 14, color: palette.textSecondary)),
            const SizedBox(height: 16),
            
            _buildOptionTile(
              icon: Icons.save_alt,
              title: 'ייצוא לקובץ JSON',
              subtitle: 'שמירת ההגדרות הנוכחיות לקובץ',
              onTap: () async {
                // מימוש ייצוא לקובץ
                Navigator.of(context).pop();
              },
              palette: palette,
            ),
            
            _buildOptionTile(
              icon: Icons.folder_open,
              title: 'ייבוא מקובץ JSON',
              subtitle: 'טעינת הגדרות מקובץ שמור',
              onTap: () async {
                // מימוש ייבוא מקובץ
                Navigator.of(context).pop();
              },
              palette: palette,
            ),
            
            _buildOptionTile(
              icon: Icons.backup,
              title: 'יצירת גיבוי',
              subtitle: 'שמירת גיבוי אוטומטי של ההגדרות',
              onTap: () async {
                try {
                  await DisplaySettingsExportService.createBackup();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('גיבוי נשמר בהצלחה')),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('שגיאה ביצירת גיבוי: $e')),
                    );
                  }
                }
              },
              palette: palette,
            ),
            
            _buildOptionTile(
              icon: Icons.restore,
              title: 'שחזור מגיבוי',
              subtitle: 'טעינת הגדרות מגיבוי אחרון',
              onTap: () async {
                // מימוש שחזור
                Navigator.of(context).pop();
              },
              palette: palette,
            ),
            
            _buildOptionTile(
              icon: Icons.share,
              title: 'שיתוף הגדרות',
              subtitle: 'העתקת הגדרות כלוח לשיתוף',
              onTap: () async {
                // מימוש שיתוף
                Navigator.of(context).pop();
              },
              palette: palette,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('סגור', style: TextStyle(color: palette.textSecondary)),
        ),
      ],
    );
  }
  
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppPalette palette,
  }) {
    return ListTile(
      leading: Icon(icon, color: palette.accent),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
