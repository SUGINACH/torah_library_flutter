// lib/viewers/pdf_viewer.dart
// Flutter equivalent of pdf_viewer.py.
//
// Architecture — mirrors the original:
//   _PdfCanvas   → InteractiveViewer + CustomPaint (virtual canvas)
//   _Toolbar     → top toolbar (page label, goto spinner, search, outline btn)
//   PdfViewer    → public StatefulWidget wrapping them
//
// Required package: pdfrx (pub.dev/packages/pdfrx)
// Add to pubspec.yaml:
//   pdfrx: ^1.0.0
//
// The pdfrx package renders PDF pages as Flutter widgets.
// We wrap PdfViewer.file() in a custom scaffold that matches the
// original toolbar layout.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
// Allow using the package name as a namespace to avoid conflicts
// ignore: library_prefixes
import 'package:pdfrx/pdfrx.dart' as pdfrx;

// ── Public widget ─────────────────────────────────────────────────────────────

class PdfViewer extends StatefulWidget {
  final String path;
  final int initialPage;
  final String highlight;
  final void Function(int page)? onPageChange;
  final void Function(void Function(int page, String snippet))? onJumpReady;

  const PdfViewer({
    super.key,
    required this.path,
    this.initialPage = 1,
    this.highlight = '',
    this.onPageChange,
    this.onJumpReady,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  late final PdfViewerController _ctrl;
  final _searchCtrl  = TextEditingController();
  final _gotoCtrl    = TextEditingController();

  bool   _outlineOpen  = false;
  int    _currentPage  = 1;
  int    _totalPages   = 0;
  List<PdfOutlineNode> _outline = [];
  String _searchTerm   = '';
  // שינוי כאן: מאפשר קבלת null כדי למנוע LateInitializationError בזמן שהספר נטען
  PdfTextSearcher? _searcher;

  // ── Keyboard shortcuts (mirrors _setup_shortcuts) ─────────────────────────
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl      = PdfViewerController();
    _focusNode = FocusNode();
    _currentPage = widget.initialPage;
    _gotoCtrl.text = widget.initialPage.toString();

    // Register jump callback for main_window._jumpToSearchResult
    widget.onJumpReady?.call(_jumpToPageAndHighlight);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _gotoCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Public API (mirrors jump_to_page_and_highlight) ────────────────────────
  void _jumpToPageAndHighlight(int page, String snippet) {
    if (_totalPages == 0 || page < 1 || page > _totalPages) return;
    _ctrl.goToPage(pageNumber: page);
    
    // Retry highlight search until searcher is ready (fixes scroll-to-highlight issue)
    _tryHighlightSearch(page);
  }

  void _tryHighlightSearch(int page, {int retry = 0}) {
    if (widget.highlight.isEmpty) return;
    if (retry > 20) return; // max 20 retries × 250ms = 5 seconds
    final searcher = _searcher;
    if (searcher != null) {
      searcher.startTextSearch(widget.highlight, goToFirstMatch: true);
    } else {
      Future.delayed(const Duration(milliseconds: 250), () {
        _tryHighlightSearch(page, retry: retry + 1);
      });
    }
  }

  // ── Toolbar handlers ───────────────────────────────────────────────────────

  void _onGotoSubmit() {
    final p = int.tryParse(_gotoCtrl.text);
    if (p != null && p >= 1 && p <= _totalPages) {
      _ctrl.goToPage(pageNumber: p);
    }
  }

  void _onSearch() {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) return;
    setState(() => _searchTerm = term);
    
    // שימוש ב-Local Capture למניעת שגיאת null-safety אסינכרונית
    final searcher = _searcher;
    if (searcher != null) {
      searcher.startTextSearch(term, goToFirstMatch: true);
    }
  }

  void _toggleOutline() => setState(() => _outlineOpen = !_outlineOpen);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
        children: [
          // ── Toolbar (mirrors _Toolbar in pdf_viewer.py) ──────────────────
          _buildToolbar(),
          // ── Body: outline + PDF canvas ───────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // Outline panel
                if (_outlineOpen)
                  SizedBox(
                    width: 250,
                    child: _buildOutlinePanel(),
                  ),
                // PDF viewer
                Expanded(child: _buildPdfCanvas()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 26,
      color: const Color(0xFFEDDAA7), // accentLight — pdfToolbar gradient start
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Page label
          Text(
            'עמוד $_currentPage / $_totalPages',
            style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
          ),
          const SizedBox(width: 16),
          // Goto input
          const Text('עבור לעמוד:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          SizedBox(
            width: 45,
            child: TextField(
              controller: _gotoCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 2),
              ),
              onSubmitted: (_) => _onGotoSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          // Search input
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
              decoration: InputDecoration(
                hintText: 'חפש בספר זה...',
                hintStyle: const TextStyle(color: Color(0xFF888888)),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
              ),
              onSubmitted: (_) => _onSearch(),
            ),
          ),
          const Spacer(),
          // Outline toggle button
          TextButton(
            onPressed: _toggleOutline,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
            ),
            child: const Text('☰',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF444444))),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfCanvas() {
    return pdfrx.PdfViewer.file(
      widget.path,
      controller: _ctrl,
      initialPageNumber: widget.initialPage,
      params: PdfViewerParams(
        onDocumentChanged: (doc) {
          if (doc == null) return;
          _totalPages = doc.pages.length;
          setState(() {});
          _loadOutline(doc);
          // Initial highlight
          if (widget.highlight.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 200), () {
              // שימוש ב-Local Capture בתוך ה-Closure של ה-Future.delayed
              final searcher = _searcher;
              if (searcher != null) {
                searcher.startTextSearch(widget.highlight,
                    goToFirstMatch: false);
              }
            });
          }
        },
        onViewerReady: (doc, ctrl) {
          _searcher = PdfTextSearcher(ctrl);
        },
        onPageChanged: (page) {
          setState(() {
            _currentPage = page ?? 1;
            _gotoCtrl.text = _currentPage.toString();
          });
          widget.onPageChange?.call(_currentPage);
        },
        // Highlight words from search
        pagePaintCallbacks: [
          if (_searchTerm.isNotEmpty || widget.highlight.isNotEmpty)
            (canvas, pageRect, page) {
              _paintHighlights(canvas, pageRect, page);
            },
        ],
      ),
    );
  }

  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final paint = Paint()
      ..color = const Color(0x70FFE000)
      ..style = PaintingStyle.fill;
    final term = _searchTerm.isNotEmpty ? _searchTerm : widget.highlight;
    
    // שימוש ב-Local Capture לצורך מעבר בטוח על תוצאות החיפוש
    final searcher = _searcher;
    if (term.isEmpty || searcher == null) return;
    
    for (final match in searcher.matches) {
      if (match.pageNumber != page.pageNumber) continue;
      final rect = match.bounds.toRect(
        page: page,
        scaledPageSize: pageRect.size,
      ).shift(pageRect.topLeft);
      canvas.drawRect(rect, paint);
    }
  }

  Future<void> _loadOutline(PdfDocument doc) async {
    final nodes = await doc.loadOutline();
    if (mounted) setState(() => _outline = nodes);
  }

  Widget _buildOutlinePanel() {
    return ListView(
      children: _buildOutlineNodes(_outline, 0),
    );
  }

  List<Widget> _buildOutlineNodes(List<PdfOutlineNode> nodes, int depth) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      widgets.add(ListTile(
        dense: true,
        contentPadding: EdgeInsets.only(right: depth * 12.0 + 8),
        title: Text(node.title ?? '',
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 12)),
        onTap: () {
          if (node.dest?.pageNumber != null) {
            _ctrl.goToPage(pageNumber: node.dest!.pageNumber!);
          }
        },
      ));
      if (node.children.isNotEmpty) {
        widgets.addAll(_buildOutlineNodes(node.children, depth + 1));
      }
    }
    return widgets;
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final sb  = _ctrl;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyJ) {
      sb.goToPage(pageNumber: (_currentPage + 1).clamp(1, _totalPages));
    } else if (key == LogicalKeyboardKey.arrowUp ||
               key == LogicalKeyboardKey.keyK) {
      sb.goToPage(pageNumber: (_currentPage - 1).clamp(1, _totalPages));
    } else if (key == LogicalKeyboardKey.pageDown) {
      sb.goToPage(pageNumber: (_currentPage + 1).clamp(1, _totalPages));
    } else if (key == LogicalKeyboardKey.pageUp) {
      sb.goToPage(pageNumber: (_currentPage - 1).clamp(1, _totalPages));
    } else if (event.logicalKey == LogicalKeyboardKey.keyB &&
               HardwareKeyboard.instance.isControlPressed) {
      _toggleOutline();
    } else if (event.logicalKey == LogicalKeyboardKey.keyF &&
               HardwareKeyboard.instance.isControlPressed) {
      // focus search
    }
  }
}