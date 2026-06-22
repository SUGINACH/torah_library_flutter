// lib/dialogs/appearance_settings_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../themes/app_palette.dart';

class AppearanceSettingsDialog extends StatefulWidget {
  const AppearanceSettingsDialog({super.key});

  @override
  State<AppearanceSettingsDialog> createState() => _AppearanceSettingsDialogState();
}

class _AppearanceSettingsDialogState extends State<AppearanceSettingsDialog> {
  // ── מצב מקומי (Local State) ──
  // נשמור כאן את הערכים, הם לא ישפיעו על האפליקציה עד ללחיצה על "שמור"
  late Color _accentColor;
  late Color _bgColor;
  late Color _textColor;
  late double _fontSize;
  late String _fontFamily;

  final List<String> _availableFonts = [
    'Segoe UI',
    'David',
    'FrankRuhlCLM',
    'Arial',
    'Tahoma',
  ];

  final List<Color> _presetColors = [
    const Color(0xFFD9B13E), const Color(0xFF1A3D6B), const Color(0xFF5F4030),
    const Color(0xFF2E7D32), const Color(0xFFc0392b), const Color(0xFF34495e),
    const Color(0xFF795548), const Color(0xFF607D8B), const Color(0xFF000000),
    const Color(0xFFFFFCF5), const Color(0xFFF0F0F0), const Color(0xFF1A1A1A),
  ];

  @override
  void initState() {
    super.initState();
    // קריאת הערכים הנוכחיים מה-Provider פעם אחת בלבד בעת פתיחת הדיאלוג
    final themeProv = context.read<ThemeProvider>();
    _accentColor = themeProv.palette.accent;
    _bgColor = themeProv.palette.background;
    _textColor = themeProv.palette.textPrimary;
    _fontSize = themeProv.globalFontSize;
    _fontFamily = themeProv.globalFontFamily;
  }

  void _saveAndClose() {
    // עדכון ה-Provider ושמירה לדיסק (מבצע Rebuild לכל האפליקציה בצורה בטוחה)
    context.read<ThemeProvider>().updateCustomAppearance(
      accent: _accentColor,
      background: _bgColor,
      textPrimary: _textColor,
      fontSize: _fontSize,
      fontFamily: _fontFamily,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('הגדרות מראה ועיצוב', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionTitle('גופן וטקסט'),
                Row(
                  children: [
                    const Text('סוג גופן:', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _availableFonts.contains(_fontFamily) ? _fontFamily : _availableFonts.first,
                      items: _availableFonts.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _fontFamily = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('גודל טקסט כללי באפליקציה:', style: TextStyle(fontSize: 14)),
                Row(
                  children: [
                    Text(_fontSize.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 10,
                        max: 24,
                        divisions: 14,
                        onChanged: (val) => setState(() => _fontSize = val),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                
                _buildSectionTitle('צבעים אישיים'),
                _buildColorRow('צבע רקע ראשי:', _bgColor, (c) => setState(() => _bgColor = c)),
                const SizedBox(height: 12),
                _buildColorRow('צבע דגש (כפתורים וכותרות):', _accentColor, (c) => setState(() => _accentColor = c)),
                const SizedBox(height: 12),
                _buildColorRow('צבע טקסט:', _textColor, (c) => setState(() => _textColor = c)),
                
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    border: Border.all(color: _accentColor, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'תצוגה מקדימה לטקסט ולצבעים שבחרת.\nהשינוי יחול על כל המסכים מיד עם הלחיצה על שמור.',
                    style: TextStyle(fontFamily: _fontFamily, fontSize: _fontSize, color: _textColor),
                  ),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // סגירה ללא שמירה
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: _saveAndClose,
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white),
            child: const Text('שמור שינויים'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
    );
  }

  Widget _buildColorRow(String label, Color currentColor, Function(Color) onSelect) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetColors.map((color) {
              final isSelected = color.value == currentColor.value;
              return GestureDetector(
                onTap: () => onSelect(color),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade400,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected ? [const BoxShadow(color: Colors.blue, blurRadius: 4)] : null,
                  ),
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }
}