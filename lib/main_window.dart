// lib/main_window.dart
//
// Flutter equivalent of qt_app/main_window.py
//
// Required pubspec.yaml dependencies:
//   provider: ^6.1.2
//   shared_preferences: ^2.3.2
//   window_manager: ^0.3.9        (desktop only)
//
// Inject at your app root before calling MainWindow():
//
//   MultiProvider(
//     providers: [
//       ChangeNotifierProvider(create: (_) => ThemeProvider()
//           ..loadThemesJson(jsonDecode(themesJsonString))),
//       Provider<LibraryService>(create: (_) => MyLibraryServiceImpl()),
//     ],
//     child: MaterialApp(home: MainWindow()),
//   )
//
// Window initialisation (in main.dart, before runApp):
//   await windowManager.ensureInitialized();
//   windowManager.waitUntilReadyToShow(
//     WindowOptions(
//       size: Size(1280, 800),
//       minimumSize: Size(1024, 768),
//       title: 'הספרייה התורנית',
//       titleBarStyle: TitleBarStyle.hidden,   // frameless
//     ),
//     () async => await windowManager.show(),
//   );
//
// Layout (RTL):
//
//  ┌───────────────────────────────────────────────────────────────────────┐
//  │  categoriesBar  [CategoryBar] ···[quickNav][Tools][Theme][Win ctrls]  │
//  ├──────────────────────────┬────────────────────────────────────────────┤
//  │   rightPanel (360 px)    │              centerPanel (flex)            │
//  │ ┌──────────────────────┐ │  ┌────────────────────────────────────┐   │
//  │ │    search section    │ │  │        DocumentTabsBar             │   │
//  │ │  [fullSearch input ] │ │  ├────────────────────────────────────┤   │
//  │ │  [AND|OR|phr|sem   ] │ │  │                                    │   │
//  │ │  [HitsPanel        ] │ │  │         viewer host                │   │
//  │ │  [statusLine       ] │ │  │  (PDF / Otzaria / tool tabs)       │   │
//  │ ├──────────────────────┤ │  │  All viewers stay in the tree      │   │
//  │ │    books section     │ │  │  via Offstage — mirrors Qt's       │   │
//  │ │  [booksSearch input] │ │  │  tab.widget instance caching.      │   │
//  │ │  [VirtualBooksList ] │ │  │                                    │   │
//  │ │  [statusLine       ] │ │  └────────────────────────────────────┘   │
//  │ └──────────────────────┘ │                                            │
//  └──────────────────────────┴────────────────────────────────────────────┘

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'models/tab_info.dart';
import 'services/library_service.dart';
import 'themes/app_palette.dart';
// בתחילת קובץ main_window.dart הוסף את הייבוא:
import 'dialogs/appearance_settings_dialog.dart';

// בתוך הפונקציה _buildLeftGroup

// Sub-widgets — each lives in its own file (converted separately).
// Imports are listed here to make the dependency graph explicit.
import 'widgets/category_bar.dart';
import 'widgets/document_tabs_bar.dart';
import 'widgets/hits_panel.dart';
import 'widgets/virtual_books_list.dart';
import 'viewers/pdf_viewer.dart';
import 'viewers/otzaria_viewer.dart';
import 'viewers/docx_viewer.dart';
import 'viewers/word_embed/word_embed_widget.dart';
import 'viewers/audio_transcription_panel.dart';
import 'viewers/hebrew_calendar_widget.dart';
import 'viewers/tag_plus/tag_plus_widget.dart';
import 'dialogs/update_progress_dialog.dart';
import 'dialogs/item_display_settings_dialog.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MainWindow
// ═══════════════════════════════════════════════════════════════════════════════

class MainWindow extends StatefulWidget {
  final bool guestMode;
  const MainWindow({super.key, this.guestMode = false});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> with WindowListener {
  // ── Core state (mirrors __init__ instance variables) ──────────────────────

  List<TabInfo> _tabs = [];
  String? _activeTabId;
  String _tabMode = 'multiple'; // 'multiple' | 'single'

  final Map<int, Map<String, dynamic>> _booksCache = {};
  int _booksTotal = 0;

  List<Map<String, dynamic>> _searchHits = [];
  int _searchOffset = 0;
  bool _hasMoreHits = false;

  final Set<String> _selectedPaths = {};

  bool _rightPanelVisible = true;

  // Mirrors QSplitter initial sizes [360, 900]
  double _rightPanelWidth = 360.0;
  double _splitterDragStartX = 0;
  double _splitterDragStartWidth = 360.0;

  // Tracks which search field has focus (eventFilter equivalent).
  // true = fullSearch has focus (show hits), false = booksSearch has focus
  bool _sidebarHitsFocus = true;

  // Current logic-toggle selection ('and' | 'or' | 'phrase' | 'semantic')
  String _searchLogic = 'and';

  // ── Settings (mirrors QSettings("TorahLibrary", "PyQt6")) ─────────────────
  SharedPreferences? _prefs;
  bool _settingsLoaded = false;
  bool _suppressSave = false; // mirrors self._suppress_save in showEvent

  // ── Text controllers ──────────────────────────────────────────────────────
  late final TextEditingController _fullSearchCtrl;
  late final TextEditingController _booksSearchCtrl;
  late final TextEditingController _quickNavCtrl;

  // Focus nodes — for eventFilter equivalent
  final FocusNode _fullSearchFocus = FocusNode();
  final FocusNode _booksSearchFocus = FocusNode();

  // ── Debounce timers ───────────────────────────────────────────────────────
  Timer? _quickNavTimer;   // 300 ms, mirrors self._quick_nav_timer
  Timer? _booksTimer;      // 300 ms, mirrors QTimer.singleShot(300, ...)

  // ── Viewer cache ──────────────────────────────────────────────────────────
  // Mirrors tab.widget in Qt: keeps viewer instances alive so state is
  // preserved when switching tabs (Offstage keeps them in the widget tree).
  // Key: tabId  →  Value: the viewer Widget
  final Map<String, Widget> _viewerCache = {};

  // GlobalKeys for AudioTranscriptionPanel — required to call stopWorker()
  // when a tab is closed (mirrors stop_worker for audio tabs in main_window.py).
  final Map<String, GlobalKey<AudioTranscriptionPanelState>> _audioKeys = {};

  // Per-tab jump callbacks registered by the viewer after it is built.
  // Mirrors _jump_to_search_result → hasattr(w, 'jump_to_page_and_highlight')
  final Map<String, void Function(int page, String snippet)> _jumpCallbacks = {};

  // ── Quick-nav overlay ─────────────────────────────────────────────────────
  OverlayEntry? _quickNavOverlay;
  final LayerLink _quickNavLayerLink = LayerLink();
  List<Map<String, dynamic>> _quickNavResults = [];

  // ── Loading guard (mirrors _BooksLoader list) ─────────────────────────────
  bool _booksLoading = false;

  // Path to the instructions PDF (mirrors INSTRUCTIONS_PDF constant)
  static const String _instructionsPdfAsset = 'assets/instructions.pdf';

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _fullSearchCtrl = TextEditingController();
    _booksSearchCtrl = TextEditingController();
    _quickNavCtrl    = TextEditingController();

    _fullSearchFocus.addListener(_onFocusChange);
    _booksSearchFocus.addListener(_onFocusChange);

    windowManager.addListener(this);

    // Load QSettings equivalent then run deferred startup
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      _prefs = prefs;
      _loadTabsFromSettings();
      final savedTheme = prefs.getString('theme') ?? 'classic';
      context.read<ThemeProvider>().applyTheme(savedTheme);
      setState(() => _settingsLoaded = true);
      // Mirrors QTimer.singleShot(0, self._deferred_startup)
      WidgetsBinding.instance.addPostFrameCallback((_) => _deferredStartup());
    });

    if (widget.guestMode) {
      // Mirrors showEvent setting _suppress_save
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _suppressSave = true);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _quickNavTimer?.cancel();
    _booksTimer?.cancel();
    _fullSearchFocus.removeListener(_onFocusChange);
    _booksSearchFocus.removeListener(_onFocusChange);
    _fullSearchFocus.dispose();
    _booksSearchFocus.dispose();
    _fullSearchCtrl.dispose();
    _booksSearchCtrl.dispose();
    _quickNavCtrl.dispose();
    _hideQuickNavPopup();
    super.dispose();
  }

  // ── Focus-change handler (mirrors eventFilter in main_window.py) ──────────

  void _onFocusChange() {
    if (_fullSearchFocus.hasFocus) {
      setState(() => _sidebarHitsFocus = true);
    } else if (_booksSearchFocus.hasFocus) {
      setState(() => _sidebarHitsFocus = false);
    }
  }

  bool get _showHitsPanel => _sidebarHitsFocus && _searchHits.isNotEmpty;

  // ═══════════════════════════════════════════════════════════════════════════
  // Deferred startup  (mirrors _deferred_startup)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _deferredStartup() async {
    await _refreshBooksCount();
    await _loadBooksRange(0, 70, _booksSearchCtrl.text);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Settings persistence  (mirrors QSettings / _load_tabs_from_settings /
  //                                              _save_tabs)
  // ═══════════════════════════════════════════════════════════════════════════

  void _loadTabsFromSettings() {
    if (widget.guestMode) {
      _tabs = [
        TabInfo(
          tabId: 'instructions',
          title: 'הוראות שימוש',
          path: _instructionsPdfAsset,
          page: 1,
        ),
      ];
      _activeTabId = 'instructions';
      return;
    }

    final raw = _prefs?.getString('tabs');
    if (raw != null) {
      try {
        final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _tabs = items.map(TabInfo.fromJson).toList();
        // Word tabs cannot be auto-restored (COM/Win32 launch must be user-
        // initiated). Restoring them on startup causes an immediate crash.
        _tabs.removeWhere((t) => t.path == 'tool://word');
      } catch (_) {
        _tabs = [];
      }
    }

    if (_tabs.isEmpty) {
      _tabs = [
        TabInfo(
          tabId: 'instructions',
          title: 'הוראות שימוש',
          path: _instructionsPdfAsset,
          page: 1,
        ),
      ];
    }

    final saved = _prefs?.getString('active_tab') ?? '';
    _activeTabId = _tabs.any((t) => t.tabId == saved)
        ? saved
        : _tabs.first.tabId;
  }

  void _saveTabs() {
    if (widget.guestMode) return;
    if (_suppressSave) return;
    if (_prefs == null) return;
    // Exclude Word tabs from persistence — they cannot be safely auto-restored.
    final saveable = _tabs.where((t) => t.path != 'tool://word').toList();
    _prefs!.setString('tabs', jsonEncode(saveable.map((t) => t.toJson()).toList()));
    if (_activeTabId != null) {
      // If the active tab was a Word tab, don't persist it as active.
      final activeIsWord = _tabs
          .any((t) => t.tabId == _activeTabId && t.path == 'tool://word');
      if (!activeIsWord) {
        _prefs!.setString('active_tab', _activeTabId!);
      } else if (saveable.isNotEmpty) {
        _prefs!.setString('active_tab', saveable.last.tabId);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Window chrome  (frameless window — mirrors setWindowFlags FramelessWindowHint)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors _toggle_fullscreen
  Future<void> _toggleFullscreen() async {
    final isFull = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFull);
  }

  /// Mirrors _toggle_panel
  void _togglePanel() {
    setState(() => _rightPanelVisible = !_rightPanelVisible);
    // Mirrors QTimer.singleShot(150, self._refit_viewer) —
    // Flutter layout engine handles refit automatically on next frame.
  }

  /// Mirrors _toggle_tab_mode
  void _toggleTabMode() {
    setState(() {
      _tabMode = _tabMode == 'multiple' ? 'single' : 'multiple';
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Theme  (mirrors _apply_theme / _select_theme)
  // ═══════════════════════════════════════════════════════════════════════════

  void _selectTheme(String key) {
    context.read<ThemeProvider>().applyTheme(key);
    if (!widget.guestMode) {
      _prefs?.setString('theme', key);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Books loading  (mirrors _BooksLoader QThread + _on_books_loaded)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors _refresh_books_count
  Future<void> _refreshBooksCount() async {
    try {
      final count = await context.read<LibraryService>().booksCount();
      if (mounted) setState(() => _booksTotal = count);
    } catch (_) {
      if (mounted) setState(() => _booksTotal = 0);
    }
  }

  /// Mirrors _on_books_query_changed (debounce 300 ms)
  void _onBooksQueryChanged() {
    _booksCache.clear();
    setState(() {});
    _booksTimer?.cancel();
    final q = _booksSearchCtrl.text;
    _booksTimer = Timer(
      const Duration(milliseconds: 300),
      () => _loadBooksRange(0, 70, q),
    );
  }

  /// Mirrors _load_books_range + _on_books_loaded combined.
  Future<void> _loadBooksRange(int start, int end, String query) async {
    if (_booksLoading) return;
    _booksLoading = true;
    final limit = (end - start + 1).clamp(1, 300);
    try {
      final svc = context.read<LibraryService>();
      final result = await svc.listBooks(
        q: query.trim().isEmpty ? null : query,
        limit: limit,
        offset: start,
      );
      if (!mounted) return;
      // Mirrors: if query != self.books_search.text(): return
      if (query != _booksSearchCtrl.text) return;

      final total = result['total'] as int;
      final items = (result['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _booksTotal = total;
        for (var i = 0; i < items.length; i++) {
          _booksCache[start + i] = items[i];
        }
      });
    } catch (_) {
      // silently swallow — mirrors Qt behaviour
    } finally {
      _booksLoading = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Search  (mirrors _current_logic / _run_search / _load_more_hits)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mirrors _current_logic — returns null if user cancelled the semantic dialog.
  Future<String?> _currentLogic() async {
    if (_searchLogic == 'semantic') {
      final available =
          await context.read<LibraryService>().semanticIndexAvailable();
      if (!available) {
        if (!mounted) return null;
        await showDialog(
          context: context,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('חיפוש סמנטי'),
              content: const Text(
                'אינדקס סמנטי עדיין לא נבנה.\nהרץ: backend/build_semantic_index.py',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('אישור'),
                ),
              ],
            ),
          ),
        );
        return 'and';
      }
    }
    return _searchLogic;
  }

  /// Mirrors _run_search(offset, append)
  Future<void> _runSearch(int offset, bool append) async {
    final q = _fullSearchCtrl.text.trim();
    if (q.isEmpty) return;
    final logic = await _currentLogic();
    if (logic == null) return;

    try {
      final svc = context.read<LibraryService>();
      final paths = _selectedPaths.isNotEmpty ? _selectedPaths.toList() : null;
      List<Map<String, dynamic>> hits;

      if (logic == 'semantic') {
        hits = await svc.semanticSearch(q,
            limit: 100, offset: offset, bookPaths: paths);
      } else {
        hits = await svc.fulltextSearch(q, logic,
            limit: 100, offset: offset, bookPaths: paths);
      }

      if (!mounted) return;
      setState(() {
        if (append) {
          _searchHits.addAll(hits);
        } else {
          _searchHits = hits;
        }
        _searchOffset = offset;
        _hasMoreHits = hits.length == 100;
      });
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('חיפוש'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('אישור'),
            ),
          ],
        ),
      );
    }
  }

  /// Mirrors _load_more_hits
  void _loadMoreHits() => _runSearch(_searchOffset + 100, true);

  // ═══════════════════════════════════════════════════════════════════════════
  // Quick-nav popup  (mirrors QListWidget popup + _fetch_quick_nav)
  // ═══════════════════════════════════════════════════════════════════════════

  void _onQuickNavChanged() {
    _quickNavTimer?.cancel();
    _quickNavTimer = Timer(
      const Duration(milliseconds: 300),
      _fetchQuickNav,
    );
  }

  /// Mirrors _fetch_quick_nav
  Future<void> _fetchQuickNav() async {
    final q = _quickNavCtrl.text.trim();
    if (q.length < 2) {
      _hideQuickNavPopup();
      return;
    }
    try {
      final results = await context.read<LibraryService>().quickNav(q);
      if (!mounted) return;
      _quickNavResults = results;
      _showQuickNavPopup();
    } catch (_) {}
  }

  void _showQuickNavPopup() {
    _hideQuickNavPopup();
    if (_quickNavResults.isEmpty) return;

    _quickNavOverlay = OverlayEntry(
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: CompositedTransformFollower(
          link: _quickNavLayerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          child: Material(
            elevation: 4,
            color: context.read<ThemeProvider>().palette.background,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240, maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _quickNavResults.length,
                itemBuilder: (_, i) {
                  final r = _quickNavResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      (r['path'] as String?) ?? '',
                      textDirection: TextDirection.rtl,
                    ),
                    onTap: () => _onQuickNavPick(r),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_quickNavOverlay!);
  }

  void _hideQuickNavPopup() {
    _quickNavOverlay?.remove();
    _quickNavOverlay = null;
  }

  /// Mirrors _on_quick_nav_pick
  void _onQuickNavPick(Map<String, dynamic> r) {
    final path = (r['path'] as String?) ?? '';
    openBookTab(
      r['bookId'] as int?,
      (r['bookPath'] as String?) ?? '',
      path.contains('>') ? path.split('>').last.trim() : path,
      r['lineIndex'] as int? ?? 0,
      isOtzaria: true,
    );
    _quickNavCtrl.clear();
    _hideQuickNavPopup();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tab management  (mirrors _select_tab / _close_tab / _add_blank_tab / open_book_tab)
  // ═══════════════════════════════════════════════════════════════════════════

  TabInfo? _activeTab() {
    for (final t in _tabs) {
      if (t.tabId == _activeTabId) return t;
    }
    return null;
  }

  /// Mirrors _select_tab
  void _selectTab(String tabId) {
    setState(() => _activeTabId = tabId);
    _saveTabs();
  }

  /// Mirrors _close_tab (including stop_worker for audio tabs)
  void _closeTab(String tabId) {
    // Stop audio worker before closing (mirrors stop_worker for audio tabs)
    _audioKeys[tabId]?.currentState?.stopWorker();
    _audioKeys.remove(tabId);
    setState(() {
      _viewerCache.remove(tabId);
      _jumpCallbacks.remove(tabId);
      _tabs.removeWhere((t) => t.tabId == tabId);
      if (_tabs.isEmpty) {
        _addBlankTab();
        return;
      }
      if (_activeTabId == tabId) {
        _activeTabId = _tabs.last.tabId;
      }
    });
    _saveTabs();
  }

  /// Mirrors _add_blank_tab
  void _addBlankTab() {
    final tid = 'blank-${_tabs.length}';
    _tabs.add(TabInfo(tabId: tid, title: 'דף חדש', path: ''));
    _activeTabId = tid;
    // No viewer cached for blank tabs (mirrors Qt: no tab.widget set)
    setState(() {});
  }

  /// Mirrors _next_tab / _prev_tab  (bound to Ctrl+PageDown / Ctrl+PageUp)
  void _nextTab() {
    if (_tabs.length < 2) return;
    final ids = _tabs.map((t) => t.tabId).toList();
    final i = ids.indexOf(_activeTabId ?? '');
    _selectTab(ids[(i + 1) % ids.length]);
  }

  void _prevTab() {
    if (_tabs.length < 2) return;
    final ids = _tabs.map((t) => t.tabId).toList();
    final i = ids.indexOf(_activeTabId ?? '');
    _selectTab(ids[(i - 1 + ids.length) % ids.length]);
  }

  // ── open_tool_tab ──────────────────────────────────────────────────────────

  /// Mirrors open_tool_tab
  void openToolTab(String kind, String title) {
    openBookTab(null, 'tool://$kind', title, 1, isOtzaria: false);
  }

  // ── open_book_tab (the main entry point) ───────────────────────────────────

  /// Mirrors open_book_tab — the central method for opening any content.
  void openBookTab(
    int? bookId,
    String path,
    String title,
    int page, {
    String highlight = '',
    String authors = '',
    bool isOtzaria = false,
  }) {
    final isOtz = isOtzaria || path.toLowerCase().endsWith('.txt');

    // ── 1. Already open? Navigate to it. ────────────────────────────────────
    for (final t in _tabs) {
      if (t.path.isNotEmpty && t.path == path) {
        t.page      = page > 0 ? page : t.page;
        t.highlight = highlight.isNotEmpty ? highlight : t.highlight;
        t.bookId    = bookId ?? t.bookId;
        t.isOtzaria = isOtz;
        setState(() => _activeTabId = t.tabId);
        _saveTabs();
        return;
      }
    }

    // ── 2. Single-tab mode ──────────────────────────────────────────────────
    if (_tabMode == 'single') {
      if (_tabs.length == 1 && _tabs.first.path.isNotEmpty) {
        // Replace in-place (mirrors the early-return branch)
        final t = _tabs.first;
        // Evict old viewer so the new path gets a fresh widget
        _viewerCache.remove(t.tabId);
        _jumpCallbacks.remove(t.tabId);
        t.path      = path;
        t.title     = title;
        t.page      = page > 0 ? page : (isOtz ? 0 : 1);
        t.highlight = highlight;
        t.bookId    = bookId;
        t.isOtzaria = isOtz;
        t.authors   = authors;
        setState(() => _activeTabId = t.tabId);
        _saveTabs();
        return;
      }
      // Keep only the instructions tab, close everything else
      final keep = _tabs.where((t) => t.tabId == 'instructions').toList();
      for (final t in _tabs) {
        _viewerCache.remove(t.tabId);
        _jumpCallbacks.remove(t.tabId);
      }
      _tabs
        ..clear()
        ..addAll(keep);
    }

    // ── 3. Create new tab ───────────────────────────────────────────────────
    final tab = TabInfo(
      tabId:      '$path-${_tabs.length}',
      title:      title,
      path:       path,
      page:       page > 0 ? page : (isOtz ? 0 : 1),
      isOtzaria:  isOtz,
      bookId:     bookId,
      highlight:  highlight,
      authors:    authors,
    );
    _tabs.add(tab);
    setState(() => _activeTabId = tab.tabId);
    _saveTabs();
  }

  /// Mirrors _open_book_dict
  void _openBookDict(Map<String, dynamic> book) {
    openBookTab(
      book['bookId'] as int?,
      book['path'] as String,
      ((book['meta_title'] ?? book['file_name']) as String?) ?? '',
      (book['is_otzaria'] == true) ? 0 : 1,
      authors:   (book['authors'] as String?) ?? '',
      isOtzaria: book['is_otzaria'] == true,
    );
  }

  /// Mirrors _open_hit_dict
  void _openHitDict(Map<String, dynamic> h) {
    final isOtz = h['is_otzaria'] == true || h['type'] == 'otzaria';
    final page  = isOtz
        ? (h['lineIndex'] as int? ?? 0)
        : (h['page_no']   as int? ?? 1);

    openBookTab(
      h['bookId'] as int?,
      h['path'] as String,
      ((h['title'] ?? h['meta_title']) as String?) ?? '',
      page,
      highlight: _fullSearchCtrl.text,
      authors:   (h['authors'] as String?) ?? '',
      isOtzaria: isOtz,
    );
    // Mirrors QTimer.singleShot(100, lambda: _jump_to_search_result(...))
    final snippet = (h['snippet'] as String?) ?? '';
    Future.delayed(
      const Duration(milliseconds: 100),
      () => _jumpToSearchResult(page, snippet),
    );
  }

  /// Mirrors _jump_to_search_result.
  ///
  /// The highlight words are the authoritative highlight source and must NOT
  /// be overwritten; snippet is a positional hint only.
  void _jumpToSearchResult(int page, String snippet) {
    final cb = _jumpCallbacks[_activeTabId];
    if (cb != null) cb(page, snippet);
    // If no callback is registered yet the viewer will use its initial page.
  }

  /// Mirrors _on_path_selected
  void _onPathSelected(String path, bool checked) {
    setState(() {
      if (checked) {
        _selectedPaths.add(path);
      } else {
        _selectedPaths.remove(path);
      }
    });
  }

  /// Called by viewer widgets when the user turns a page.
  /// Mirrors _update_tab_page.
  void _updateTabPage(String tabId, int page) {
    for (final t in _tabs) {
      if (t.tabId == tabId) {
        t.page = page;
        break;
      }
    }
    _saveTabs();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Viewer construction  (mirrors _show_active_viewer + tab.widget caching)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns the viewer for [tab], creating and caching it on first access.
  ///
  /// Flutter equivalent of Qt's pattern:
  ///   if tab.widget:
  ///       w = tab.widget
  ///   else:
  ///       w = <new widget>
  ///       tab.widget = w
  Widget _getOrCreateViewer(TabInfo tab) {
    if (_viewerCache.containsKey(tab.tabId)) {
      return _viewerCache[tab.tabId]!;
    }

    final Widget w;
    if (tab.path.isEmpty) {
      w = _staticLabel('בחר ספר מהרשימה');
    } else if (tab.path.startsWith('tool://')) {
      w = _buildToolViewer(tab.path.replaceFirst('tool://', ''));
    } 
    // --- הוסף את הבלוק הזה כאן כדי לטפל בקבצי וורד שנפתחים מהרשימה ---
    else if (tab.path.toLowerCase().endsWith('.docx')) {
      w = DocxViewer(filePath: tab.path);
    }
    // -------------------------------------------------------------
    else if (tab.isOtzaria && tab.bookId != null) {
      w = OtzariaViewer(
        bookId:      tab.bookId!,
        path:        tab.path,
        initialLine: tab.page,
        highlight:   tab.highlight,
        onJumpReady: (cb) => _jumpCallbacks[tab.tabId] = cb,
        onOpenBook: (bookId, path, title, line) {
          openBookTab(bookId, path, title, line, isOtzaria: true);
        },
      );
    } else if (tab.path.toLowerCase().endsWith('.pdf')) {
      w = PdfViewer(
        path:        tab.path,
        initialPage: tab.page > 0 ? tab.page : 1,
        highlight:   tab.highlight,
        onPageChange: (p) => _updateTabPage(tab.tabId, p),
        onJumpReady:  (cb) => _jumpCallbacks[tab.tabId] = cb,
      );
    } else {
      return _staticLabel('סוג קובץ לא נתמך:\n${tab.path}');
    }

    _viewerCache[tab.tabId] = w;
    return w;
  }

  /// Mirrors the tool:// branch of _show_active_viewer
  Widget _buildToolViewer(String kind) {
    switch (kind) {
      case 'audio':
        final key = GlobalKey<AudioTranscriptionPanelState>();
        return Builder(builder: (ctx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final tabId = _activeTabId;
            if (tabId != null) _audioKeys[tabId] = key;
          });
          return AudioTranscriptionPanel(key: key);
        });

      case 'calendar':
        return const HebrewCalendarWidget();

      case 'tag_plus':
        return const TagPlusWidget(createScope: true);

      // --- תיקון: הוספת 'word' וגם 'docx' והעברת filePath ריק למסמך חדש ---
      case 'word':
      case 'docx':
        return const DocxViewer(filePath: ''); 
      // ---------------------------------------------------------------

      default:
        return _staticLabel('כלי לא מוכר: $kind');
    }
  }

  static Widget _staticLabel(String msg) => Center(
        child: Text(msg, textAlign: TextAlign.center),
      );

  // ── Update dialog ──────────────────────────────────────────────────────────

  /// Mirrors _on_update_all
  Future<void> _onUpdateAll() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => const UpdateProgressDialog(),
    );
    if (accepted == true && mounted) {
      await _refreshBooksCount();
      _booksCache.clear();
      await _loadBooksRange(0, 70, _booksSearchCtrl.text);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Show a minimal loading screen while SharedPreferences is initialising.
    // Mirrors the brief gap before _deferred_startup fires in Qt.
    if (!_settingsLoaded) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: Text('טוען…')),
        ),
      );
    }

    final palette = context.watch<ThemeProvider>().palette;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.pageDown):
              const _NextTabIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.pageUp):
              const _PrevTabIntent(),
        },
        child: Actions(
          actions: {
            _NextTabIntent: CallbackAction<_NextTabIntent>(
              onInvoke: (_) => _nextTab(),
            ),
            _PrevTabIntent: CallbackAction<_PrevTabIntent>(
              onInvoke: (_) => _prevTab(),
            ),
          },
          child: Focus(
            autofocus: true,
            child: Container(
              color: palette.background,
              child: Column(
                children: [
                  // ── Top bar (categories bar) ─────────────────────────────
                  _buildCategoriesBar(palette),
                  // ── Main area ────────────────────────────────────────────
                  Expanded(
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        // Right panel (search + books list) — collapsible
                        if (_rightPanelVisible)
                          SizedBox(
                            width: _rightPanelWidth,
                            child: _buildRightPanel(palette),
                          ),
                        // Resizable splitter handle
                        if (_rightPanelVisible)
                          _buildSplitterHandle(palette),
                        // Center panel (tabs + viewer)
                        Expanded(child: _buildCenterPanel(palette)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Categories bar ─────────────────────────────────────────────────────────
  //
  // Mirrors _build_ui's cat_row:
  //   cat_row.addWidget(self.category_bar)   ← right side in RTL
  //   cat_row.addStretch(1)
  //   cat_row.addLayout(left_group)          ← left side in RTL

  Widget _buildCategoriesBar(AppPalette palette) {
    return DragToMoveArea(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: palette.panelLight.withOpacity(0.85),
          border: Border(bottom: BorderSide(color: palette.divider)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // Right side: category dropdown menus
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: CategoryBar(
                onBookOpened: (bookId, path, title, page, {isOtzaria = false}) =>
                    openBookTab(bookId, path, title, page, isOtzaria: isOtzaria),
              ),
            ),
            const Spacer(),
            // Left side: quickNav + tools + theme + window controls
            _buildLeftGroup(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftGroup(AppPalette palette) {
    final themeNames = context.read<ThemeProvider>().themeNames;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Quick-nav input (QLineEdit#quickNav, min-width: 240) ──────────
          SizedBox(
            width: 240,
            child: CompositedTransformTarget(
              link: _quickNavLayerLink,
              child: TextField(
                controller: _quickNavCtrl,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: palette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'ניווט מהיר (לדוגמה: ברכות א ב)',
                  hintStyle: TextStyle(color: palette.textMuted),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  isDense: true,
                ),
                onChanged: (_) => _onQuickNavChanged(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // ── Tools menu (QPushButton#toolsBtn) ────────────────────────────
          _IconMenuBtn(
            tooltip: 'כלים נוספים',
            icon: Icons.build_outlined,
            palette: palette,
            items: [
              ('עורך DOCX',     () => openToolTab('docx',     'עורך DOCX')),
              ('Microsoft Word', () => openToolTab('word',     'Microsoft Word')),
              ('תמלול אודיו',   () => openToolTab('audio',    'תמלול אודיו')),
              ('לוח שנה עברי',  () => openToolTab('calendar', 'לוח שנה')),
              ('תג פלוס',       () => openToolTab('tag_plus', 'תג פלוס')),
            ],
          ),
          // ── Theme dialog ─────────────────────────────
          _IconBtn(
            tooltip: 'הגדרות תצוגה מתקדמות',
            icon: Icons.display_settings, // אייקון הגדרות תצוגה
            palette: palette,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const ItemDisplaySettingsDialog(),
              );
            },
          ),
          _IconBtn(
            tooltip: 'הגדרות מראה',
            icon: Icons.settings, // אייקון גלגל שיניים
            palette: palette,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const AppearanceSettingsDialog(),
              );
            },
          ),
          // ── Theme menu (QPushButton#themeBtn) ─────────────────────────────
          _IconMenuBtn(
            tooltip: 'ערכת נושא',
            icon: Icons.palette_outlined,
            palette: palette,
            items: [
              for (final e in themeNames.entries) (e.value, () => _selectTheme(e.key)),
            ],
          ),
          // ── Update button (QPushButton#updateBtn) ─────────────────────────
          _IconBtn(
            tooltip: 'עדכון אינדקס',
            icon: Icons.system_update_alt,
            palette: palette,
            onTap: _onUpdateAll,
          ),
          // ── Window controls ───────────────────────────────────────────────
          _IconBtn(
            tooltip: 'מזעור',
            icon: Icons.remove,
            palette: palette,
            onTap: () => windowManager.minimize(),
          ),
          _IconBtn(
            tooltip: 'מסך מלא',
            icon: Icons.fullscreen,
            palette: palette,
            onTap: _toggleFullscreen,
          ),
          _IconBtn(
            tooltip: 'סגור',
            icon: Icons.close,
            palette: palette,
            onTap: () => windowManager.close(),
            overrideHoverColor: const Color(0xFFc0392b),
          ),
        ],
      ),
    );
  }

  // ── Splitter handle ────────────────────────────────────────────────────────
  //
  // Mirrors QSplitter.splitterMoved with setHandleWidth(2) and RTL direction.
  // In RTL, dragging RIGHT (positive dx) narrows the panel; dragging LEFT widens it.

  Widget _buildSplitterHandle(AppPalette palette) {
    return GestureDetector(
      onHorizontalDragStart: (d) {
        _splitterDragStartX     = d.globalPosition.dx;
        _splitterDragStartWidth = _rightPanelWidth;
      },
      onHorizontalDragUpdate: (d) {
        final delta = d.globalPosition.dx - _splitterDragStartX;
        setState(() {
          _rightPanelWidth =
              (_splitterDragStartWidth - delta).clamp(200.0, 600.0);
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(width: 2, color: palette.accent),
      ),
    );
  }

// ── Right panel ────────────────────────────────────────────────────────────
  //
  // QWidget#rightPanel: max-width / min-width 360px
  // Contains: search section (top) + books section (flex)

  Widget _buildRightPanel(AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        // העברנו את הצבע אל ה-Material למטה
        border: Border(left: BorderSide(color: palette.panelLight)),
      ),
      child: Material(
        color: palette.panelLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchSection(palette),
            Expanded(child: _buildBooksSection(palette)),
          ],
        ),
      ),
    );
  }

  // ── Search section ─────────────────────────────────────────────────────────

  Widget _buildSearchSection(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // QWidget#fullSearchBox — gradient header
        _buildGradientBox(
          palette,
          child: Focus(
            focusNode: _fullSearchFocus,
            child: TextField(
              controller: _fullSearchCtrl,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: palette.textPrimary),
              decoration: _panelInputDecoration(
                  'חפש בתוכן הספרים...', palette),
              onSubmitted: (_) => _runSearch(0, false),
            ),
          ),
        ),
        // Logic toggle row
        _buildLogicRow(palette),
        // HitsPanel — visible only when fullSearch has focus and hits exist
        if (_showHitsPanel)
          HitsPanel(
            hits:             _searchHits,
            hasMore:          _hasMoreHits,
            selectedPaths:    _selectedPaths,
            onHitOpened:      _openHitDict,
            onLoadMore:       _loadMoreHits,
            onSelectionChanged: _onPathSelected,
          ),
        if (_showHitsPanel) _buildStatusLine('תוצאות: ${_searchHits.length}', palette),
      ],
    );
  }

  Widget _buildLogicRow(AppPalette palette) {
    const options = [
      ('and',      'כל המילים'),
      ('or',       'אחת מהמילים'),
      ('phrase',   'ביטוי מדויק'),
      ('semantic', 'חיפוש סמנטי'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (val, label) in options)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Tooltip(
                message: val == 'semantic'
                    ? 'לאחר בניית אינדקס AI — build_semantic_index.py'
                    : '',
                child: _LogicToggleBtn(
                  label:      label,
                  isSelected: _searchLogic == val,
                  isEnabled:  val != 'semantic',
                  palette:    palette,
                  onTap: val == 'semantic'
                      ? null
                      : () => setState(() => _searchLogic = val),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Books section ──────────────────────────────────────────────────────────

  Widget _buildBooksSection(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // QWidget#booksSearchBox — gradient header
        _buildGradientBox(
          palette,
          child: Focus(
            focusNode: _booksSearchFocus,
            child: TextField(
              controller: _booksSearchCtrl,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: palette.textPrimary),
              decoration:
                  _panelInputDecoration('חפש שם ספר/מחבר...', palette),
              onChanged: (_) => _onBooksQueryChanged(),
            ),
          ),
        ),
        Expanded(
          child: VirtualBooksList(
            totalBooks:        _booksTotal,
            cache:             _booksCache,
            selectedPaths:     _selectedPaths,
            onBookOpened:      _openBookDict,
            onSelectionChanged: _onPathSelected,
            onRangeNeeded:     _loadBooksRange,
          ),
        ),
        _buildStatusLine(
          _booksSearchCtrl.text.trim().isNotEmpty
              ? 'נמצאו: $_booksTotal'
              : 'במאגר: $_booksTotal',
          palette,
        ),
      ],
    );
  }

  // ── Center panel ───────────────────────────────────────────────────────────

  Widget _buildCenterPanel(AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        // העברנו את הצבע אל ה-Material למטה
        border: Border(
          // Matches QWidget#centerPanel { border-right: 1px solid accent }
          // In RTL the "right" side is the left edge physically.
          right: BorderSide(color: palette.accent),
        ),
      ),
      child: Material(
        color: palette.panelLight,
        child: Column(
          children: [
            // DocumentTabsBar — mirrors self.tabs_bar
            DocumentTabsBar(
              tabs: _tabs
                  .map((t) => {
                        'id':      t.tabId,
                        'title':   t.title,
                        'authors': t.authors,
                        'path':    t.path,
                      })
                  .toList(),
              activeTabId:  _activeTabId ?? '',
              tabMode:      _tabMode,
              palette:      palette,
              onTabSelected:     _selectTab,
              onTabClosed:       _closeTab,
              onNewTabRequested: _addBlankTab,
              onTogglePanel:     _togglePanel,
              onToggleTabMode:   _toggleTabMode,
            ),
            // Viewer host — mirrors self.viewer_host / viewer_layout
            Expanded(child: _buildViewerHost()),
          ],
        ),
      ),
    );
  }

  // ── Viewer host ────────────────────────────────────────────────────────────
  //
  // Uses Offstage to keep every viewer in the widget tree at all times,
  // preserving state exactly as Qt does with tab.widget.
  // Each entry is wrapped in a KeyedSubtree so Flutter tracks viewers by
  // tabId regardless of list-position changes (close/reorder).

  Widget _buildViewerHost() {
    if (_tabs.isEmpty) return _staticLabel('בחר ספר מהרשימה');

    final palette = context.read<ThemeProvider>().palette;

    return Stack(
      children: _tabs.map((tab) {
        final isActive = tab.tabId == _activeTabId;

        // ── Word tabs: never cache, always pass isActive ───────────────────
        // WordEmbedWidget manages a Win32 window that floats *above* the app.
        // Offstage only hides our Flutter placeholder — NOT the Win32 window.
        // The widget must receive an up-to-date `isActive` every build so
        // didUpdateWidget fires and it can show/hide the Word window itself.
        // Using a stable ValueKey ensures Flutter reuses the same State object
        // (so Word stays open) while still calling didUpdateWidget on changes.
        if (tab.path == 'tool://word') {
          return KeyedSubtree(
            key: ValueKey(tab.tabId),
            child: Offstage(
              offstage: !isActive,   // hides Flutter placeholder only
              child: WordEmbedWidget(
                key: ValueKey('word-embed-${tab.tabId}'),
                isActive: isActive,
                palette: WordPalette(
                  accent:        palette.accent,
                  headerGold:    palette.headerGold,
                  panelLight:    palette.panelLight,
                  textPrimary:   palette.textPrimary,
                  textSecondary: palette.textSecondary,
                  background:    palette.background,
                  borderColor:   palette.borderColor,
                ),
              ),
            ),
          );
        }

        // ── All other tabs: standard Offstage + viewer cache ───────────────
        return KeyedSubtree(
          key: ValueKey(tab.tabId),
          child: Offstage(
            offstage: !isActive,
            child: _getOrCreateViewer(tab),
          ),
        );
      }).toList(),
    );
  }

  // ── Shared panel helpers ───────────────────────────────────────────────────

  /// Gradient header container used for both fullSearchBox and booksSearchBox.
  /// Matches the stop:0 {header} stop:1 {panel} gradient in themes.py.
  Widget _buildGradientBox(AppPalette palette, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.headerGold, palette.panelLight],
        ),
      ),
      child: child,
    );
  }

  /// Mirrors QLabel#statusLine styling
  Widget _buildStatusLine(String text, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border.symmetric(
          vertical: BorderSide(color: palette.accent),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF555555),
        ),
      ),
    );
  }

  InputDecoration _panelInputDecoration(String hint, AppPalette palette) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: palette.textMuted),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: palette.inputBorder),
          borderRadius: BorderRadius.circular(2),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: palette.inputBorder),
          borderRadius: BorderRadius.circular(2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Keyboard shortcut intents  (Ctrl+PageDown / Ctrl+PageUp)
// ═══════════════════════════════════════════════════════════════════════════════

class _NextTabIntent extends Intent { const _NextTabIntent(); }
class _PrevTabIntent extends Intent { const _PrevTabIntent(); }

// ═══════════════════════════════════════════════════════════════════════════════
// _LogicToggleBtn  (mirrors QPushButton[cssClass="logic-toggle"] in themes.py)
// ═══════════════════════════════════════════════════════════════════════════════

class _LogicToggleBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final AppPalette palette;
  final VoidCallback? onTap;

  const _LogicToggleBtn({
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color:        isSelected ? palette.accent : Colors.transparent,
            border:       Border.all(color: palette.accent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize:   10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color:      isSelected ? Colors.white : palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _IconBtn  — hover-aware icon button
// Mirrors QPushButton#toolsBtn / #themeBtn / #updateBtn / #closeBtn etc.
// ═══════════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final AppPalette palette;
  final VoidCallback onTap;
  final Color? overrideHoverColor;

  const _IconBtn({
    required this.tooltip,
    required this.icon,
    required this.palette,
    required this.onTap,
    this.overrideHoverColor,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.overrideHoverColor ??
        widget.palette.accent.withOpacity(0.15);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color:        _hovered ? hoverColor : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(widget.icon, size: 18,
                color: widget.palette.textPrimary),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _IconMenuBtn  — icon button that opens a popup menu on tap
// Mirrors QPushButton.setMenu() for tools and theme buttons.
// ═══════════════════════════════════════════════════════════════════════════════

class _IconMenuBtn extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final AppPalette palette;
  final List<(String label, VoidCallback action)> items;

  const _IconMenuBtn({
    required this.tooltip,
    required this.icon,
    required this.palette,
    required this.items,
  });

  @override
  State<_IconMenuBtn> createState() => _IconMenuBtnState();
}

class _IconMenuBtnState extends State<_IconMenuBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _showMenu,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.palette.accent.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(widget.icon, size: 18,
                color: widget.palette.textPrimary),
          ),
        ),
      ),
    );
  }

  void _showMenu() {
    if (widget.items.isEmpty) return;
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final offset =
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + box.size.width,
        offset.dy + 200,
      ),
      items: widget.items
          .map(
            (item) => PopupMenuItem<String>(
              value:  item.$1,
              onTap:  item.$2,
              child:  Directionality(
                textDirection: TextDirection.rtl,
                child: Text(item.$1),
              ),
            ),
          )
          .toList(),
    );
  }
}