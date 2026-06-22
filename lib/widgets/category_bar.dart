// lib/widgets/category_bar.dart
// Flutter equivalent of CategoryBar in widgets.py.
// Reads categories from assets/data/categories.json and builds
// a row of popup-menu buttons, one per top-level category.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/library_service.dart';
import '../themes/app_palette.dart';

typedef _BookOpenCb = void Function(
    int? bookId, String path, String title, int page, {bool isOtzaria});

// ── Public widget ─────────────────────────────────────────────────────────────

class CategoryBar extends StatefulWidget {
  final _BookOpenCb onBookOpened;
  const CategoryBar({super.key, required this.onBookOpened});

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/categories.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _categories =
              (data['categories'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  // ── parse path#page= ────────────────────────────────────────────────────────
  static (String, int) _parsePath(String raw) {
    if (raw.contains('#page=')) {
      final parts = raw.split('#page=');
      return (parts[0], int.tryParse(parts[1]) ?? 1);
    }
    return (raw, 1);
  }

  // ── Build a recursive PopupMenuButton tree ──────────────────────────────────

  List<PopupMenuEntry<_BookEntry>> _buildEntries(
      List<dynamic> items, int depth) {
    final entries = <PopupMenuEntry<_BookEntry>>[];
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      final name = m['name'] as String? ?? '';
      final children = m['children'] as List?;
      final path = m['path'] as String? ?? '';

      if (children != null && children.isNotEmpty) {
        // Submenu header (non-clickable divider + nested handled via _NestedMenu)
        entries.add(_NestedMenuEntry(name: name, children: children,
            depth: depth, parsePath: _parsePath, onOpen: widget.onBookOpened));
      } else if (path.isNotEmpty) {
        final (purePath, page) = _parsePath(path);
        entries.add(PopupMenuItem<_BookEntry>(
          value: _BookEntry(path: purePath, name: name, page: page),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(name, style: const TextStyle(fontSize: 13)),
          ),
        ));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeProvider>().palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        for (final cat in _categories)
          _CatButton(
            title: cat['title'] as String? ?? '',
            books: (cat['books'] as List?)?.cast<Map<String, dynamic>>() ?? [],
            palette: palette,
            buildEntries: _buildEntries,
            onBookOpened: widget.onBookOpened,
          ),
      ],
    );
  }
}

// ── Internal data / helper types ──────────────────────────────────────────────

class _BookEntry {
  final String path;
  final String name;
  final int page;
  const _BookEntry({required this.path, required this.name, required this.page});
}

// ── Single category button ────────────────────────────────────────────────────

class _CatButton extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> books;
  final AppPalette palette;
  final List<PopupMenuEntry<_BookEntry>> Function(List<dynamic>, int) buildEntries;
  final _BookOpenCb onBookOpened;

  const _CatButton({
    required this.title,
    required this.books,
    required this.palette,
    required this.buildEntries,
    required this.onBookOpened,
  });

  @override
  State<_CatButton> createState() => _CatButtonState();
}

class _CatButtonState extends State<_CatButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showMenu(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          constraints: const BoxConstraints(minHeight: 24),
          decoration: BoxDecoration(
            gradient: _hovered
                ? null
                : LinearGradient(
                    colors: [p.accent, p.accentLight, p.panelLight],
                  ),
            color: _hovered ? p.itemHover : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext ctx) async {
    final box = ctx.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(ctx).overlay!.context.findRenderObject()! as RenderBox;
    final off = box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay);

    final result = await showMenu<_BookEntry>(
      context: ctx,
      position: RelativeRect.fromLTRB(off.dx, off.dy, off.dx + 200, off.dy + 400),
      items: widget.buildEntries(widget.books, 0),
    );
    if (result != null) {
      int? bookId;
      bool isOtzaria = false;
      if (!result.path.toLowerCase().endsWith('.pdf') && !result.path.startsWith('tool://')) {
        final svc = ctx.read<LibraryService>();
        bookId = await svc.getBookIdByPath(result.path);
        if (bookId != null) isOtzaria = true;
      }
      widget.onBookOpened(bookId, result.path, result.name, result.page, isOtzaria: isOtzaria);
    }
  }
}

// ── Nested submenu entry (renders as a tappable row that opens a submenu) ────

class _NestedMenuEntry extends PopupMenuEntry<_BookEntry> {
  final String name;
  final List<dynamic> children;
  final int depth;
  final (String, int) Function(String) parsePath;
  final _BookOpenCb onOpen;

  const _NestedMenuEntry({
    required this.name,
    required this.children,
    required this.depth,
    required this.parsePath,
    required this.onOpen,
  });

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(_BookEntry? value) => false;

  @override
  State<_NestedMenuEntry> createState() => _NestedMenuEntryState();
}

class _NestedMenuEntryState extends State<_NestedMenuEntry> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      title: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(child: Text(widget.name, style: const TextStyle(fontSize: 13))),
            const Icon(Icons.chevron_left, size: 16),
          ],
        ),
      ),
      onTap: () async {
        // Build and show a child menu offset to the side
        final box = context.findRenderObject()! as RenderBox;
        final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
        final off = box.localToGlobal(const Offset(0, 0), ancestor: overlay);

        final childEntries = _buildChildren(context);
        final result = await showMenu<_BookEntry>(
          context: context,
          position: RelativeRect.fromLTRB(
            off.dx - 220, off.dy,
            off.dx, off.dy + 400,
          ),
          items: childEntries,
        );
        if (result != null && context.mounted) {
          Navigator.of(context).pop(result);
          int? bookId;
          bool isOtzaria = false;
          if (!result.path.toLowerCase().endsWith('.pdf') && !result.path.startsWith('tool://')) {
            final svc = context.read<LibraryService>();
            bookId = await svc.getBookIdByPath(result.path);
            if (bookId != null) isOtzaria = true;
          }
          widget.onOpen(bookId, result.path, result.name, result.page, isOtzaria: isOtzaria);
        }
      },
    );
  }

  List<PopupMenuEntry<_BookEntry>> _buildChildren(BuildContext ctx) {
    final entries = <PopupMenuEntry<_BookEntry>>[];
    for (final item in widget.children) {
      final m = item as Map<String, dynamic>;
      final name = m['name'] as String? ?? '';
      final subChildren = m['children'] as List?;
      final path = m['path'] as String? ?? '';

      if (subChildren != null && subChildren.isNotEmpty) {
        entries.add(_NestedMenuEntry(
          name: name,
          children: subChildren,
          depth: widget.depth + 1,
          parsePath: widget.parsePath,
          onOpen: widget.onOpen,
        ));
      } else if (path.isNotEmpty) {
        final (purePath, page) = widget.parsePath(path);
        entries.add(PopupMenuItem<_BookEntry>(
          value: _BookEntry(path: purePath, name: name, page: page),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(name, style: const TextStyle(fontSize: 13)),
          ),
        ));
      }
    }
    return entries;
  }
}
