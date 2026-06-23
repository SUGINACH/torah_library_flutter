// lib/dialogs/item_display_settings_dialog.dart
// דיאלוג הגדרות תצוגה מתקדם לכל פריט בתוכנה
// מאפשר התאמה אישית של גודל, צבע, מרקם ועוד עבור כל סוגי הצגה

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../themes/app_palette.dart';
import '../otzaria_viewer/settings/settings_bloc.dart';
import '../otzaria_viewer/settings/settings_event.dart';
import '../otzaria_viewer/settings/settings_state.dart';

class ItemDisplaySettingsDialog extends StatefulWidget {
  final String itemType; // 'pdf', 'otzaria', 'docx', 'audio', 'calendar', 'general'
  
  const ItemDisplaySettingsDialog({
    super.key,
    this.itemType = 'general',
  });

  @override
  State<ItemDisplaySettingsDialog> createState() => _ItemDisplaySettingsDialogState();
}

class _ItemDisplaySettingsDialogState extends State<ItemDisplaySettingsDialog> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  late ScrollController _tabScrollController;
  
  // מצבים מקומיים להגדרות
  late double _fontSize;
  late String _fontFamily;
  late Color _backgroundColor;
  late Color _textColor;
  late Color _accentColor;
  late double _lineHeight;
  late double _marginSize;
  late double _paddingSize;
  late bool _enableAnimations;
  late String _texturePattern;
  late double _brightness;
  late double _contrast;
  late bool _rtlMode;
  late TextDirection _textDirection;
  
  // רשימת טאבים
  final List<Map<String, dynamic>> _tabs = [
    {'icon': Icons.text_fields, 'text': 'טקסט וגופן'},
    {'icon': Icons.palette, 'text': 'צבעים ומרקם'},
    {'icon': Icons.aspect_ratio, 'text': 'פריסה ומרווחים'},
    {'icon': Icons.visibility, 'text': 'נגישות ותצוגה'},
  ];
  
  // רשימת גופנים זמינים
  final List<String> _availableFonts = [
    'Segoe UI',
    'David',
    'FrankRuhlCLM',
    'Arial',
    'Tahoma',
    'Times New Roman',
    'Heebo',
    'Rubik',
  ];
  
  // רשימת מרקמים/דפוסים
  final List<Map<String, dynamic>> _texturePatterns = [
    {'name': 'חלק', 'value': 'smooth', 'icon': Icons.square},
    {'name': 'נייר', 'value': 'paper', 'icon': Icons.description},
    {'name': 'קלף', 'value': 'parchment', 'icon': Icons.article},
    {'name': 'רשת', 'value': 'grid', 'icon': Icons.grid_on},
    {'name': 'נקודות', 'value': 'dots', 'icon': Icons.blur_on},
    {'name': 'פסים', 'value': 'stripes', 'icon': Icons.view_stream},
  ];
  
  // צבעים פרסט
  final List<Color> _presetColors = [
    const Color(0xFFD9B13E), const Color(0xFF1A3D6B), const Color(0xFF5F4030),
    const Color(0xFF2E7D32), const Color(0xFFc0392b), const Color(0xFF34495e),
    const Color(0xFF795548), const Color(0xFF607D8B), const Color(0xFF000000),
    const Color(0xFFFFFCF5), const Color(0xFFF0F0F0), const Color(0xFF1A1A1A),
    const Color(0xFFE8F4F8), const Color(0xFFFDF6E3), const Color(0xFFF5F5F5),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabScrollController = ScrollController();
    _initSettingsFromCurrent();
    
    // האזנה לשינויי טאב לגלילה אוטומטית
    _tabController.addListener(_handleTabSelection);
  }
  
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    
    // גלילה אוטומטית לטאב הנבחר כדי שיהיה תמיד גלוי
    // חישוב מיקום מדויק יותר בהתבסס על מספר הטאבים
    final tabWidth = 162.0; // רוחב משוער לכל טאב (160 + margin)
    final selectedIndex = _tabController.index;
    final totalTabs = _tabs.length;
    
    if (_tabScrollController.hasClients) {
      // חישוב מיקום הגלילה כך שהטאב הנבחר יהיה במרכז
      final scrollPosition = (totalTabs - 1 - selectedIndex) * tabWidth;
      final viewportWidth = 500.0; // רוחב התצוגה המשוער
      
      double targetPosition = scrollPosition - (viewportWidth / 2) + (tabWidth / 2);
      
      // וידוא שהמיקום בתוך הטווח המותר
      final maxScroll = _tabScrollController.position.maxScrollExtent;
      targetPosition = targetPosition.clamp(0, maxScroll);
      
      _tabScrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }
  
  void _initSettingsFromCurrent() {
    final themeProv = context.read<ThemeProvider>();
    final settingsState = context.read<SettingsBloc>()?.state as SettingsState?;
    
    setState(() {
      _fontSize = settingsState?.fontSize ?? themeProv.globalFontSize ?? 16.0;
      _fontFamily = settingsState?.fontFamily ?? themeProv.globalFontFamily ?? 'FrankRuhlCLM';
      _backgroundColor = themeProv.palette.background;
      _textColor = themeProv.palette.textPrimary;
      _accentColor = themeProv.palette.accent;
      _lineHeight = settingsState?.paddingSize != null 
          ? (settingsState!.paddingSize / 10.0 * 1.5) 
          : 1.5;
      _paddingSize = settingsState?.paddingSize ?? 10.0;
      _marginSize = _paddingSize;
      _enableAnimations = true;
      _texturePattern = 'smooth';
      _brightness = 1.0;
      _contrast = 1.0;
      _rtlMode = true;
      _textDirection = TextDirection.rtl;
    });
  }

  void _saveSettings() {
    // עדכון ThemeProvider
    context.read<ThemeProvider>().updateCustomAppearance(
      accent: _accentColor,
      background: _backgroundColor,
      textPrimary: _textColor,
      fontSize: _fontSize,
      fontFamily: _fontFamily,
    );
    
    // עדכון SettingsBloc אם קיים
    final settingsBloc = context.read<SettingsBloc>();
    if (settingsBloc != null) {
      settingsBloc.add(UpdateFontSize(_fontSize));
      settingsBloc.add(UpdateFontFamily(_fontFamily));
      settingsBloc.add(UpdatePaddingSize(_paddingSize));
    }
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final palette = themeProv.palette;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.display_settings, color: palette.accent),
            const SizedBox(width: 12),
            Text('הגדרות תצוגה מתקדמות', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 550,
          child: Column(
            children: [
              // טאבים עליונים בעיצוב Chrome עם קיעורים
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: palette.borderColor,
                      width: 1,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: _tabScrollController,
                  scrollDirection: Axis.horizontal,
                  reverse: true, // גלילה מימין לשמאל (RTL)
                  child: Row(
                    children: List.generate(_tabs.length, (index) {
                      final tab = _tabs[index];
                      final isSelected = _tabController.index == index;
                      
                      return GestureDetector(
                        onTap: () => _tabController.animateTo(index),
                        child: Container(
                          width: 160,
                          height: 52,
                          margin: const EdgeInsets.only(left: 2),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      palette.background,
                                      palette.background.withValues(alpha: 0.95),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : LinearGradient(
                                    colors: [
                                      palette.background.withValues(alpha: 0.7),
                                      palette.background.withValues(alpha: 0.5),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                            border: Border(
                              left: BorderSide(
                                color: isSelected 
                                    ? palette.accent.withValues(alpha: 0.3)
                                    : palette.borderColor.withValues(alpha: 0.5),
                                width: isSelected ? 2 : 1,
                              ),
                              right: BorderSide(
                                color: isSelected 
                                    ? palette.accent.withValues(alpha: 0.3)
                                    : palette.borderColor.withValues(alpha: 0.5),
                                width: isSelected ? 2 : 1,
                              ),
                              top: BorderSide(
                                color: isSelected 
                                    ? palette.accent.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                width: isSelected ? 2 : 0,
                              ),
                            ),
                            borderRadius: isSelected
                                ? const BorderRadius.vertical(top: Radius.circular(8))
                                : const BorderRadius.vertical(top: Radius.circular(4)),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, -2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              // אפקט קיעור פנימי לטאב לא נבחר
                              if (!isSelected)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                          spreadRadius: -1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // תוכן הטאב
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      tab['icon'] as IconData,
                                      size: 18,
                                      color: isSelected 
                                          ? palette.accent 
                                          : palette.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tab['text'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected 
                                            ? FontWeight.w600 
                                            : FontWeight.normal,
                                        color: isSelected 
                                            ? palette.accent 
                                            : palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // תוכן הטאבים
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTextFontTab(palette),
                    _buildColorsTextureTab(palette),
                    _buildLayoutSpacingTab(palette),
                    _buildAccessibilityViewTab(palette),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ביטול', style: TextStyle(color: palette.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('שמור הגדרות'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFontTab(AppPalette palette) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('הגדרות גופן', palette),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.font_download, size: 20, color: palette.textSecondary),
                      const SizedBox(width: 8),
                      Text('סוג גופן:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _availableFonts.contains(_fontFamily) ? _fontFamily : _availableFonts.first,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _availableFonts.map((f) => DropdownMenuItem(
                            value: f, 
                            child: Text(f, style: TextStyle(fontFamily: f)),
                          )).toList(),
                          onChanged: (val) => setState(() => _fontFamily = val!),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Icon(Icons.format_size, size: 20, color: palette.textSecondary),
                      const SizedBox(width: 8),
                      Text('גודל גופן:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Text('${_fontSize.toInt()}', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 10,
                          max: 36,
                          divisions: 26,
                          activeColor: palette.accent,
                          onChanged: (val) => setState(() => _fontSize = val),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Icon(Icons.format_line_spacing, size: 20, color: palette.textSecondary),
                      const SizedBox(width: 8),
                      Text('גובה שורה:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Text(_lineHeight.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _lineHeight,
                          min: 1.0,
                          max: 2.5,
                          divisions: 15,
                          activeColor: palette.accent,
                          onChanged: (val) => setState(() => _lineHeight = val),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          _buildSectionTitle('תצוגה מקדימה', palette),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _backgroundColor,
              border: Border.all(color: palette.borderColor, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ:\nוְהָאָרֶץ הָיְתָה תֹהוּ וָבֹהוּ וְחֹשֶׁךְ עַל־פְּנֵי תְהוֹם וְרוּחַ אֱלֹהִים מְרַחֶפֶת עַל־פְּנֵי הַמָּיִם:',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: _fontSize,
                height: _lineHeight,
                color: _textColor,
              ),
              textDirection: _textDirection,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorsTextureTab(AppPalette palette) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('צבעי רקע וטקסט', palette),
          
          _buildColorSelector('צבע רקע:', _backgroundColor, (c) => setState(() => _backgroundColor = c), palette),
          const SizedBox(height: 12),
          _buildColorSelector('צבע טקסט:', _textColor, (c) => setState(() => _textColor = c), palette),
          const SizedBox(height: 12),
          _buildColorSelector('צבע דגש:', _accentColor, (c) => setState(() => _accentColor = c), palette),
          
          const SizedBox(height: 24),
          
          _buildSectionTitle('מרקם ודפוס רקע', palette),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _texturePatterns.map((pattern) {
              final isSelected = _texturePattern == pattern['value'];
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(pattern['icon'] as IconData, size: 16),
                    const SizedBox(width: 6),
                    Text(pattern['name'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _texturePattern = pattern['value'] as String);
                },
                selectedColor: palette.accent.withValues(alpha: 0.3),
                checkmarkColor: palette.accent,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionTitle('כוונון צבע מתקדם', palette),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.brightness_6, size: 20, color: palette.textSecondary),
                      const SizedBox(width: 8),
                      Text('בהירות:', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: 0.5,
                          max: 1.5,
                          divisions: 20,
                          activeColor: palette.accent,
                          onChanged: (val) => setState(() => _brightness = val),
                        ),
                      ),
                      Text(_brightness.toStringAsFixed(2)),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Icon(Icons.contrast, size: 20, color: palette.textSecondary),
                      const SizedBox(width: 8),
                      Text('ניגודיות:', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: _contrast,
                          min: 0.5,
                          max: 1.5,
                          divisions: 20,
                          activeColor: palette.accent,
                          onChanged: (val) => setState(() => _contrast = val),
                        ),
                      ),
                      Text(_contrast.toStringAsFixed(2)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          _buildPreviewBox(palette),
        ],
      ),
    );
  }

  Widget _buildLayoutSpacingTab(AppPalette palette) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('מרווחים וריווח', palette),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.padding, size: 20, color: palette.textSecondary),
                      const SizedBox(width: 8),
                      Text('ריווח פנימי (Padding):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Text('${_paddingSize.toInt()}', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _paddingSize,
                          min: 0,
                          max: 40,
                          divisions: 40,
                          activeColor: palette.accent,
                          onChanged: (val) => setState(() => _paddingSize = val),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Icon(Icons.margin, size: 20, color: palette.textSecondary),
                      const SizedBox(width: 8),
                      Text('שולי דף (Margin):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Text('${_marginSize.toInt()}', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _marginSize,
                          min: 0,
                          max: 60,
                          divisions: 60,
                          activeColor: palette.accent,
                          onChanged: (val) => setState(() => _marginSize = val),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionTitle('כיוון וכיווניות', palette),
          
          SwitchListTile(
            title: const Text('מצב RTL (מימין לשמאל)'),
            subtitle: const Text('התאם לכיוון קריאה בעברית'),
            value: _rtlMode,
            activeColor: palette.accent,
            onChanged: (val) => setState(() {
              _rtlMode = val;
              _textDirection = val ? TextDirection.rtl : TextDirection.ltr;
            }),
          ),
          
          const SizedBox(height: 20),
          
          _buildSectionTitle('המחשה ויזואלית', palette),
          
          Container(
            height: 200,
            margin: const EdgeInsets.all(8),
            padding: EdgeInsets.all(_paddingSize),
            decoration: BoxDecoration(
              color: _backgroundColor,
              border: Border.all(color: palette.accent, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'דוגמת תצוגה\nמרווחים: ${_paddingSize.toInt()}px',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _fontSize,
                  fontFamily: _fontFamily,
                  color: _textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityViewTab(AppPalette palette) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('נגישות ותצוגה', palette),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('הפעל אנימציות'),
                    subtitle: const Text('אנימציות מעבר וחיווי'),
                    value: _enableAnimations,
                    activeColor: palette.accent,
                    onChanged: (val) => setState(() => _enableAnimations = val),
                  ),
                  
                  const Divider(),
                  
                  ListTile(
                    leading: Icon(Icons.info_outline, color: palette.accent),
                    title: const Text('התאמות נגישות נוספות'),
                    subtitle: Text(
                      'ניתן להתאים את גודל הטקסט, הניגודיות והצבעים לשיפור הקריאות.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionTitle('פרופילים מהירים', palette),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPresetChip('קריאה רגילה', () {
                setState(() {
                  _fontSize = 16;
                  _brightness = 1.0;
                  _contrast = 1.0;
                  _backgroundColor = const Color(0xFFFFFCF5);
                  _textColor = const Color(0xFF2C2118);
                });
              }, palette),
              _buildPresetChip('קריאה בלילה', () {
                setState(() {
                  _fontSize = 18;
                  _brightness = 0.9;
                  _contrast = 1.1;
                  _backgroundColor = const Color(0xFF1A1A1A);
                  _textColor = const Color(0xFFE0E0E0);
                });
              }, palette),
              _buildPresetChip('נגישות מוגברת', () {
                setState(() {
                  _fontSize = 24;
                  _brightness = 1.0;
                  _contrast = 1.3;
                  _backgroundColor = Colors.white;
                  _textColor = Colors.black;
                });
              }, palette),
              _buildPresetChip('קלף עתיק', () {
                setState(() {
                  _fontSize = 18;
                  _brightness = 1.0;
                  _contrast = 1.0;
                  _backgroundColor = const Color(0xFFFDF6E3);
                  _textColor = const Color(0xFF3E2723);
                  _texturePattern = 'parchment';
                });
              }, palette),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionTitle('המלצות לפי סוג פריט', palette),
          
          _buildItemTypeRecommendation(
            'PDF',
            'מומלץ: גודל 14-16, ניגודיות גבוהה, רקע בהיר',
            Icons.picture_as_pdf,
            palette,
          ),
          _buildItemTypeRecommendation(
            'טקסט (Otzaria)',
            'מומלץ: גודל 16-18, גופן FrankRuhlCLM, ריווח 1.5',
            Icons.menu_book,
            palette,
          ),
          _buildItemTypeRecommendation(
            'אודיו',
            'מומלץ: גודל 14, צבעי דגש ברורים, אנימציות פעילות',
            Icons.audio_file,
            palette,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
              )),
        ],
      ),
    );
  }

  Widget _buildColorSelector(String label, Color current, Function(Color) onSelect, AppPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetColors.map((color) {
              final isSelected = color.value == current.value;
              return GestureDetector(
                onTap: () => onSelect(color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? palette.accent : palette.divider,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected 
                        ? [BoxShadow(color: palette.accent.withValues(alpha: 0.5), blurRadius: 4)] 
                        : null,
                  ),
                  child: isSelected 
                      ? Icon(Icons.check, size: 18, color: _isLightColor(color) ? Colors.black : Colors.white) 
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBox(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border.all(color: palette.accent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'תצוגה מקדימה',
            style: TextStyle(
              fontSize: _fontSize,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'השינויים יחולו מיד עם שמירת ההגדרות',
            style: TextStyle(
              fontSize: _fontSize - 2,
              fontFamily: _fontFamily,
              color: _textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, AppPalette palette) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      avatar: Icon(Icons.flash_on, size: 16, color: palette.accent),
      backgroundColor: palette.panelLight,
    );
  }

  Widget _buildItemTypeRecommendation(
    String type, 
    String recommendation, 
    IconData icon,
    AppPalette palette,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: palette.accent),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(recommendation, style: const TextStyle(fontSize: 12)),
        dense: true,
      ),
    );
  }

  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }
}
