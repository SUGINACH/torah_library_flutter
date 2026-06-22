// lib/widgets/hits_panel.dart
// Renders search hits grouped by book. Each group is collapsible.
// Max height 220 px.

import 'dart:collection';
import 'package:flutter/material.dart';
import '../themes/app_palette.dart';

// ── group_hits() ── mirrors the standalone function in widgets.py ──────────

Map<String, Map<String, dynamic>> groupHits(List<Map<String, dynamic>> hits) {
  final m = <String, Map<String, dynamic>>{};
  for (final h in hits) {
    final path = h['path'] as String;
    m.putIfAbsent(path, () => {
      'path':        path,
      'title':       (h['meta_title'] ?? h['file_name'] ?? '') as String,
      'authors':     (h['authors'] ?? '') as String,
      'bookId':      h['bookId'],
      'is_otzaria':  h['type'] == 'otzaria',
      'source_folder': (h['source_folder'] ?? '') as String,
      'pages':       <Map<String, dynamic>>[],
    });
    final snippet = (h['snippet'] as String?) ?? '';
    (m[path]!['pages'] as List).add({
      'page_no':     h['page_no'] ?? h['lineIndex'] ?? 1,
      'snippet':     snippet,
      'is_otzaria':  h['type'] == 'otzaria',
      'path':        path,
      'bookId':      h['bookId'],
      'meta_title':  h['meta_title'] ?? h['file_name'] ?? '',
      'authors':     h['authors'] ?? '',
    });
  }

  // Sort: highest hit count first, then alphabetical
  final sortedEntries = m.entries.toList()
    ..sort((a, b) {
      final pagesA = (a.value['pages'] as List);
      final pagesB = (b.value['pages'] as List);
      final countA = pagesA.length;
      final countB = pagesB.length;
      // Higher count first, then alphabetical
      if (countA != countB) return countB.compareTo(countA);
      return ((a.value['title'] as String?) ?? '').compareTo((b.value['title'] as String?) ?? '');
    });

  final sorted = <String, Map<String, dynamic>>{};
  for (final e in sortedEntries) {
    sorted[e.key] = e.value;
  }
  return sorted;
}

/// Build a RichText with <mark> tags highlighted in yellow.
/// Also strips newlines so the snippet flows as one wrapped line.
Widget _buildHighlightedSnippet(String raw, AppPalette palette) {
  // Remove newlines / carriage returns so the snippet wraps naturally
  final cleaned = raw.replaceAll(RegExp(r'[\r\n]+'), ' ');

  final spans = <InlineSpan>[];
  final regex = RegExp(r'<mark>(.*?)</mark>');
  int lastEnd = 0;
  for (final match in regex.allMatches(cleaned)) {
    // Text before this match
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: cleaned.substring(lastEnd, match.start)));
    }
    // The highlighted match
    spans.add(TextSpan(
      text: match.group(1),
      style: const TextStyle(
        backgroundColor: Color(0xFFFFEB3B), // yellow highlight
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
    ));
    lastEnd = match.end;
  }
  // Remaining text after last match
  if (lastEnd < cleaned.length) {
    spans.add(TextSpan(text: cleaned.substring(lastEnd)));
  }

  return RichText(
    text: TextSpan(style: TextStyle(fontSize: 12, color: palette.textPrimary), children: spans),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.right,
    softWrap: true,
  );
}

// ── Public widget ─────────────────────────────────────────────────────────────

class HitsPanel extends StatefulWidget {
  final List<Map<String, dynamic>> hits;
  final bool hasMore;
  final Set<String> selectedPaths;
  final void Function(Map<String, dynamic>) onHitOpened;
  final VoidCallback onLoadMore;
  final void Function(String path, bool checked) onSelectionChanged;

  const HitsPanel({
    super.key,
    required this.hits,
    required this.hasMore,
    required this.selectedPaths,
    required this.onHitOpened,
    required this.onLoadMore,
    required this.onSelectionChanged,
  });

  @override
  State<HitsPanel> createState() => _HitsPanelState();
}

class _HitsPanelState extends State<HitsPanel> {
  final Set<String> _expanded = {};
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupHits(widget.hits);
    final palette =
        Theme.of(context).extension<AppPaletteExtension>()?.palette ??
            AppPalette.classic;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: palette.accent, width: 3),
          color: palette.panelLight,
        ),
        child: Scrollbar(
          controller: _scrollCtrl,
          thumbVisibility: true,
          child: ListView(
            controller: _scrollCtrl,
            shrinkWrap: true,
            children: [
              for (final entry in groups.entries)
                _HitGroupWidget(
                  group:      entry.value,
                  expanded:   _expanded.contains(entry.key),
                  selected:   widget.selectedPaths.contains(entry.key),
                  palette:    palette,
                  onToggle:   () => setState(() {
                    if (_expanded.contains(entry.key)) {
                      _expanded.remove(entry.key);
                    } else {
                      _expanded.add(entry.key);
                    }
                  }),
                  onPageClick: widget.onHitOpened,
                  onSelChange: (checked) =>
                      widget.onSelectionChanged(entry.key, checked),
                ),
              if (widget.hasMore)
                InkWell(
                  onTap: widget.onLoadMore,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: palette.headerGold,
                    alignment: Alignment.center,
                    child: Text('טען עוד 100 תוצאות ▼',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        )),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hit-group row (book header + expandable pages) ────────────────────────────

class _HitGroupWidget extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool expanded;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onToggle;
  final void Function(Map<String, dynamic>) onPageClick;
  final void Function(bool) onSelChange;

  const _HitGroupWidget({
    required this.group,
    required this.expanded,
    required this.selected,
    required this.palette,
    required this.onToggle,
    required this.onPageClick,
    required this.onSelChange,
  });

  @override
  Widget build(BuildContext context) {
    final p       = palette;
    final pages   = (group['pages'] as List).cast<Map<String, dynamic>>();
    final title   = group['title'] as String;
    final authors = group['authors'] as String? ?? '';
    final sourceFolder = group['source_folder'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header row (hitRow) ──────────────────────────────────────────────
        // Layout (RTL): [Checkbox] [Title + Author] [Icon] [Hit count ▼/◀]
        GestureDetector(
          onTap: onToggle,
          child: Container(
            height: 34, // matches _BookRow height
            decoration: BoxDecoration(
              color: p.accentLight,
              border: Border(
                top:   BorderSide(color: p.accent),
                right: BorderSide(color: p.accent),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Checkbox
                Checkbox(
                  value: selected,
                  onChanged: (v) => onSelChange(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                // Title + Author (2 lines)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: p.textPrimary,
                            height: 1.1,
                          )),
                      if (authors.isNotEmpty)
                        Text(authors,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 10,
                              color: p.textSecondary,
                              height: 1.1,
                            )),
                    ],
                  ),
                ),
                // אייקון דינמי (כמו ב-_BookRow)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Image.asset(
                    'assets/icon/$sourceFolder.ico',
                    width: 16,
                    height: 16,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text('📖', style: TextStyle(fontSize: 13));
                    },
                  ),
                ),
                // Hit count box with lighter background
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E4C8).withValues(alpha: 0.5), // light gold background
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${pages.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
                          )),
                      const SizedBox(width: 3),
                      Text('תוצאות',
                          style: TextStyle(
                            fontSize: 11,
                            color: p.textSecondary,
                          )),
                    ],
                  ),
                ),
                Text(expanded ? '▼' : '◀',
                    style:
                        TextStyle(color: p.textPrimary, fontSize: 12)),
              ],
            ),
          ),
        ),
        // ── Expanded pages ────────────────────────────────────────────────────
        if (expanded)
          for (final pg in pages)
            _PageRow(page: pg, palette: p, onTap: () => onPageClick(pg)),
      ],
    );
  }
}

// ── Single page/line result row ──────────────────────────────────────────────

class _PageRow extends StatefulWidget {
  final Map<String, dynamic> page;
  final AppPalette palette;
  final VoidCallback onTap;

  const _PageRow({
    required this.page,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_PageRow> createState() => _PageRowState();
}

class _PageRowState extends State<_PageRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p       = widget.palette;
    final pageNo  = widget.page['page_no'] ?? 1;
    final snippet = (widget.page['snippet'] as String?) ?? '';
    final isOtz   = widget.page['is_otzaria'] == true;
    final label   = isOtz ? 'שורה $pageNo' : 'עמוד $pageNo';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(26, 6, 8, 6),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF0F0F0) : p.panelLight,
            border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          constraints: const BoxConstraints(minHeight: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: p.textMuted,
                  )),
              const SizedBox(height: 2),
              // Snippet with lighter background, proper <mark> highlighting
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F5EB), // lighter cream than row bg
                  borderRadius: BorderRadius.circular(3),
                ),
                child: _buildHighlightedSnippet(snippet, p),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ThemeExtension so HitsPanel can read AppPalette without Provider ─────────

class AppPaletteExtension extends ThemeExtension<AppPaletteExtension> {
  final AppPalette palette;
  const AppPaletteExtension(this.palette);

  @override
  AppPaletteExtension copyWith({AppPalette? palette}) =>
      AppPaletteExtension(palette ?? this.palette);

  @override
  AppPaletteExtension lerp(AppPaletteExtension? other, double t) => this;
}