// lib/viewers/word_embed/word_embed_widget.dart
//
// Overlays a stripped MS-Word window over the widget area.
// Word remains a top-level Win32 window (ribbon stays intact);
// we strip its chrome, set Flutter as owner, and reposition it every
// 50 ms to track the Flutter container.
//
// Coordinate system:
//   Flutter reports positions in *logical* pixels.
//   Win32 SetWindowPos works in *physical* (DPI-scaled) pixels.
//   Multiply by MediaQuery.devicePixelRatio before any Win32 call.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'word_win32_stub.dart'
    if (dart.library.ffi) 'word_win32.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WordPalette
// ─────────────────────────────────────────────────────────────────────────────

class WordPalette {
  final Color accent;
  final Color headerGold;
  final Color panelLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color background;
  final Color borderColor;

  const WordPalette({
    required this.accent,
    required this.headerGold,
    required this.panelLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.background,
    required this.borderColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  WordEmbedWidget
// ─────────────────────────────────────────────────────────────────────────────

class WordEmbedWidget extends StatefulWidget {
  final String? filePath;
  final WordPalette palette;

  /// MUST be updated by the parent on every build:
  ///   true  → tab is active   → Word window is visible and synced
  ///   false → tab is inactive → Word window is hidden (SW_HIDE)
  final bool isActive;

  const WordEmbedWidget({
    super.key,
    this.filePath,
    required this.palette,
    this.isActive = true,
  });

  @override
  State<WordEmbedWidget> createState() => _WordEmbedWidgetState();
}

class _WordEmbedWidgetState extends State<WordEmbedWidget>
    with WidgetsBindingObserver {

  final _launcher   = WordLauncher();
  int  _wordHwnd    = 0;
  int  _flutterHwnd = 0;

  bool _attached = false;
  bool _failed   = false;

  Timer? _pollTimer;
  Timer? _syncTimer;

  final _key = GlobalKey();
  double _dpr = 1.0;

  // Counts 50 ms ticks; every 20 ticks (= 1 s) we call findWordHwnd() to
  // detect whether Word opened a new window (e.g. user clicked a recent file
  // on Word's start screen, causing Word to spawn a new HWND in SDI mode).
  int _windowCheckTick = 0;

  // ══════════════════════════════════════════════════════════════════════════
  //  Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) return;
    WidgetsBinding.instance.addObserver(this);
    _flutterHwnd = getFlutterHwnd();
    _launch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dpr = MediaQuery.of(context).devicePixelRatio;
  }

  @override
  void didUpdateWidget(WordEmbedWidget old) {
    super.didUpdateWidget(old);
    if (!Platform.isWindows) return;

    if (old.filePath != widget.filePath) {
      _teardown(shouldQuitWord: true);
      _launch();
    } else if (old.isActive != widget.isActive) {
      _handleActiveChange();
    }
  }

  @override
  void didChangeMetrics() {
    if (!Platform.isWindows) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dpr = MediaQuery.of(context).devicePixelRatio;
      _syncNow(forceShow: false);
    });
  }

  @override
  void dispose() {
    _teardown(shouldQuitWord: true);
    if (Platform.isWindows) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Launch & attach
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _launch() async {
    final path = widget.filePath ?? '';
    final ok = path.isNotEmpty
        ? await _launcher.openFile(path)
        : await _launcher.openNew();

    if (!ok) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (!mounted) { t.cancel(); return; }
      attempts++;
      final h = findWordHwnd();
      if (h != 0) {
        t.cancel();
        _pollTimer = null;
        _attach(h);
      } else if (attempts > 37) {   // ≈ 15 seconds
        t.cancel();
        _pollTimer = null;
        if (mounted) setState(() => _failed = true);
      }
    });
  }

  void _attach(int hwnd) {
    // Wait 500 ms so Word finishes rendering before we strip its chrome.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _wordHwnd = hwnd;
      stripFrame(hwnd);
      if (_flutterHwnd != 0) setWordOwner(hwnd, _flutterHwnd);
      _attached = true;
      if (mounted) setState(() {});
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _syncNow(forceShow: true));
      _startSyncTimer();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Active / inactive switching
  // ══════════════════════════════════════════════════════════════════════════

  void _handleActiveChange() {
    if (widget.isActive) {
      _startSyncTimer();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _syncNow(forceShow: true));
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
      if (_wordHwnd != 0) hideWord(_wordHwnd);
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (widget.isActive) _syncNow(forceShow: false);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Coordinate sync
  // ══════════════════════════════════════════════════════════════════════════

  void _syncNow({required bool forceShow}) {
    if (!mounted || !_attached || _wordHwnd == 0) return;

    if (!widget.isActive) {
      hideWord(_wordHwnd);
      return;
    }

    // ── New-window detection (once per second) ────────────────────────────
    // In Word's SDI mode (Office 365 / Word 2019+) clicking a recent file on
    // the start screen opens the document in a BRAND-NEW top-level window
    // (new HWND).  Our embed is still tracking the old (now-stale) HWND, so
    // the document appears outside the app.  We poll findWordHwnd() every
    // ~1 s: if it returns a *different* OpusApp window we re-embed it.
    _windowCheckTick = (_windowCheckTick + 1) % 20; // 20 × 50 ms = 1 s
    if (_windowCheckTick == 0) {
      final topHwnd = findWordHwnd();            // foreground OpusApp window
      if (topHwnd != 0 && topHwnd != _wordHwnd) {
        // A new Word window appeared — hide the stale one and embed the new.
        hideWord(_wordHwnd);
        _wordHwnd = 0;
        _attached = false;
        if (mounted) setState(() {});
        _attach(topHwnd);
        return;
      }
    }

    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final logicalOffset = box.localToGlobal(Offset.zero);
    final logicalSize   = box.size;

    if (_flutterHwnd == 0) return;
    final (cx, cy) = clientOrigin(_flutterHwnd);

    final x = cx + (logicalOffset.dx * _dpr).round();
    final y = cy + (logicalOffset.dy * _dpr).round();
    final w = (logicalSize.width  * _dpr).round();
    final h = (logicalSize.height * _dpr).round();

    if (w <= 0 || h <= 0) return;

    if (forceShow) {
      showWordAt(_wordHwnd, x, y, w, h);
    } else {
      moveWordTo(_wordHwnd, x, y, w, h);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Cleanup
  //  NOTE: parameter renamed to `shouldQuitWord` to avoid shadowing the
  //  top-level `quitWord()` function from word_win32.dart.
  // ══════════════════════════════════════════════════════════════════════════

  void _teardown({bool shouldQuitWord = false}) {
    _pollTimer?.cancel(); _pollTimer = null;
    _syncTimer?.cancel(); _syncTimer = null;

    if (_wordHwnd != 0) {
      if (shouldQuitWord) {
        quitWord(_wordHwnd);   // ← calls the Win32 helper, no name clash
      } else {
        hideWord(_wordHwnd);
      }
      _wordHwnd = 0;
    }
    _attached = false;
    _failed   = false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Public helpers
  // ══════════════════════════════════════════════════════════════════════════

  void save() => sendSave(_wordHwnd);

  // ══════════════════════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return Center(
        child: Text(
          'הטמעת Word זמינה רק ב-Windows.',
          style: TextStyle(fontSize: 15, color: widget.palette.textPrimary),
          textDirection: TextDirection.rtl,
        ),
      );
    }

    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: widget.palette.accent),
            const SizedBox(height: 12),
            Text(
              'Microsoft Word לא נמצא.\nודא שמיקרוסופט אופיס מותקן ונסה שוב.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 15, color: widget.palette.textPrimary),
            ),
          ],
        ),
      );
    }

    return Container(
      key: _key,
      color: widget.palette.background,
      child: _attached
          ? const SizedBox.expand()
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: widget.palette.accent),
                  const SizedBox(height: 16),
                  Text(
                    'פותח את Microsoft Word…',
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.palette.textPrimary,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
    );
  }
}