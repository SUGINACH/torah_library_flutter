// lib/widgets/virtual_books_list.dart

import 'dart:async';
import 'package:flutter/material.dart';

const double _kRowHeight = 34.0; 
// צמצמנו את טווח הטעינה מראש כדי להקל על הזיכרון ומסד הנתונים
const int _kPrefetchAhead = 100;
const int _kPrefetchBehind = 50;

// ── Public widget ─────────────────────────────────────────────────────────────

class VirtualBooksList extends StatefulWidget {
  final int totalBooks;
  final Map<int, Map<String, dynamic>> cache;
  final Set<String> selectedPaths;
  final void Function(Map<String, dynamic>) onBookOpened;
  final void Function(String path, bool checked) onSelectionChanged;
  final void Function(int start, int end, String query) onRangeNeeded;

  const VirtualBooksList({
    super.key,
    required this.totalBooks,
    required this.cache,
    required this.selectedPaths,
    required this.onBookOpened,
    required this.onSelectionChanged,
    required this.onRangeNeeded,
  });

  @override
  State<VirtualBooksList> createState() => _VirtualBooksListState();
}

class _VirtualBooksListState extends State<VirtualBooksList> {
  final _scrollCtrl = ScrollController();
  Timer? _scrollDebounce;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    
    // מוודא שלא נשלח בקשות קריאה למסד הנתונים על כל פיקסל גלילה (Debounce)
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 50), () {
      if (mounted) _checkAndFetchMissing();
    });
  }

  void _checkAndFetchMissing() {
    if (!_scrollCtrl.hasClients || widget.totalBooks == 0) return;
    
    final offset   = _scrollCtrl.offset;
    final viewH    = _scrollCtrl.position.viewportDimension;
    final firstRow = (offset / _kRowHeight).floor();
    final lastRow  = ((offset + viewH) / _kRowHeight).ceil();
    
    final start = (firstRow - _kPrefetchBehind).clamp(0, widget.totalBooks - 1);
    final end   = (lastRow  + _kPrefetchAhead).clamp(0, widget.totalBooks - 1);

    // מחשב רק את הטווח ש*באמת* חסר בזיכרון המטמון
    int missingStart = -1;
    int missingEnd = -1;
    for (int i = start; i <= end; i++) {
      if (!widget.cache.containsKey(i)) {
        if (missingStart == -1) missingStart = i;
        missingEnd = i;
      }
    }

    if (missingStart != -1) {
      // מעגל קצוות כדי לבקש נתונים ב"בלוקים" אחידים (משפר ביצועי Cache)
      missingStart = (missingStart ~/ 50) * 50;
      missingEnd = ((missingEnd ~/ 50) + 1) * 50 - 1;
      missingEnd = missingEnd.clamp(0, widget.totalBooks - 1);
      
      widget.onRangeNeeded(missingStart, missingEnd, '');

      // מפעיל טיימר לניסיון חוזר למקרה שמסד הנתונים היה תפוס (MainWindow._booksLoading)
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) _checkAndFetchMissing();
      });
    } else {
      _retryTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalBooks == 0) {
      return const Center(child: Text('אין ספרים', textDirection: TextDirection.rtl));
    }

    return Scrollbar(
      controller: _scrollCtrl,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollCtrl,
        itemCount: widget.totalBooks,
        itemExtent: _kRowHeight, // משפר דרמטית את ביצועי הרשימה
        itemBuilder: (ctx, i) {
          final book = widget.cache[i];
          return _BookRow(
            book: book,
            selected: book != null && widget.selectedPaths.contains(book['path'] as String? ?? ''),
            onTap: book == null ? null : () => widget.onBookOpened(book),
            onCheckChanged: book == null
                ? null
                : (v) => widget.onSelectionChanged(
                      book['path'] as String,
                      v ?? false,
                    ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _retryTimer?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }
}

// ── Single book row ───────────────────────────────────────────────────────────

class _BookRow extends StatefulWidget {
  final Map<String, dynamic>? book;
  final bool selected;
  final VoidCallback? onTap;
  final void Function(bool?)? onCheckChanged;

  const _BookRow({
    required this.book,
    required this.selected,
    this.onTap,
    this.onCheckChanged,
  });

  @override
  State<_BookRow> createState() => _BookRowState();
}

class _BookRowState extends State<_BookRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    if (book == null || book['isLoading'] == true) {
      return Container(
        height: _kRowHeight,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          border: Border(
            bottom: BorderSide(color: Color(0xFFD9B13E)),
            right: BorderSide(color: Color(0xFFD9B13E)),
          ),
        ),
        child: const Text('טוען…',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Color(0xFF5C4A38), fontSize: 12)),
      );
    }

    final title = (book['meta_title'] ?? book['file_name'] ?? '') as String;
    final author = (book['authors'] ?? '') as String;
    final sourceFolder = (book['source_folder'] as String?) ?? 'default';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: widget.onTap,
        child: Container(
          height: _kRowHeight,
          decoration: BoxDecoration(
            color: (_hovered || widget.selected)
                ? const Color(0xFFEDDAA7) 
                : const Color(0xFFF7F7F7),
            border: const Border(
              bottom: BorderSide(color: Color(0xFFD9B13E)),
              right: BorderSide(color: Color(0xFFD9B13E)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              SizedBox(
                width: 22,
                child: Checkbox(
                  value: widget.selected,
                  onChanged: widget.onCheckChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Expanded(
                child: author.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF2C2118),
                                height: 1.1,
                              )),
                          Text(author,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF5C4A38),
                                height: 1.1,
                              )),
                        ],
                      )
                    : Text(title,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF2C2118),
                        )),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Image.asset(
                  'assets/icon/$sourceFolder.ico',
                  width: 16,
                  height: 16,
                  // התיקון הקריטי הבא מנחה את פלאטר לטעון את האייקון רק בגודל 32px לכל היותר, וחוסך עד 90% מהעומס.
                  cacheWidth: 32,
                  cacheHeight: 32,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text('📖', style: TextStyle(fontSize: 13));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}