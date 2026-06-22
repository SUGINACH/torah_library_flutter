// ============================================================
// ui/widgets/preview/preview_panel.dart — פאנל תצוגה מקדימה
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/providers.dart';
import '../../../config/theme_config.dart';
import '../../../config/app_constants.dart';
import 'page_painter.dart';

class PreviewPanel extends ConsumerStatefulWidget {
  const PreviewPanel({super.key});

  @override
  ConsumerState<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends ConsumerState<PreviewPanel> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pages       = ref.watch(pagesProvider);
    final currentPage = ref.watch(currentPageProvider);
    final zoom        = ref.watch(zoomProvider);
    final showMargins = ref.watch(showMarginsProvider);
    final showGrid    = ref.watch(showGridProvider);
    final docState    = ref.watch(documentNotifierProvider);
    final settings    = docState.document.pageSettings;

    final pageW = settings.width  * 3.7795 * zoom;
    final pageH = settings.height * 3.7795 * zoom;

    final pageLayout = pages.isNotEmpty && currentPage <= pages.length
        ? pages[currentPage - 1] : null;

    return Column(children: [
      // ── סרגל כלים תצוגה ───────────────────────────────────
      _PreviewToolbar(
        currentPage: currentPage,
        totalPages:  pages.length,
        zoom:        zoom,
        onPrev:  () => _changePage(currentPage - 1, pages.length),
        onNext:  () => _changePage(currentPage + 1, pages.length),
        onZoom:  (v) => ref.read(zoomProvider.notifier).state = v,
        onMargins: () => ref.read(showMarginsProvider.notifier).state = !showMargins,
        onGrid:    () => ref.read(showGridProvider.notifier).state = !showGrid,
        showMargins: showMargins,
        showGrid:    showGrid,
      ),
      // ── אזור עמוד ─────────────────────────────────────────
      Expanded(
        child: Container(
          color: TagPlusColors.canvasGrey,
          child: Center(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // צל
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: const BoxDecoration(boxShadow: [
                    BoxShadow(color: Colors.black26,
                        blurRadius: 8, offset: Offset(3, 3)),
                  ]),
                  child: SizedBox(
                    width: pageW, height: pageH,
                    child: CustomPaint(
                      painter: PagePainter(
                        paragraphs:  pageLayout?.paragraphs ?? [],
                        settings:    settings,
                        zoom:        zoom,
                        showMargins: showMargins,
                        showGrid:    showGrid,
                        pageNumber:  currentPage,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      // ── שורת מצב ──────────────────────────────────────────
      _StatusBar(currentPage: currentPage, totalPages: pages.length, zoom: zoom),
    ]);
  }

  void _changePage(int page, int total) {
    final clamped = page.clamp(1, total.clamp(1, 9999));
    ref.read(currentPageProvider.notifier).state = clamped;
  }
}

// ── סרגל כלים פנימי ──────────────────────────────────────────

class _PreviewToolbar extends StatelessWidget {
  final int    currentPage, totalPages;
  final double zoom;
  final VoidCallback onPrev, onNext, onMargins, onGrid;
  final void Function(double) onZoom;
  final bool showMargins, showGrid;

  const _PreviewToolbar({
    required this.currentPage, required this.totalPages,
    required this.zoom, required this.onPrev, required this.onNext,
    required this.onZoom, required this.onMargins, required this.onGrid,
    required this.showMargins, required this.showGrid,
  });

  @override
  Widget build(BuildContext context) {
    final zoomPct = (zoom * 100).round();
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: TagPlusColors.toolbarBg,
        border: Border(bottom: BorderSide(color: TagPlusColors.toolbarBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        // ניווט עמודים
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: currentPage > 1 ? onPrev : null,
          tooltip: 'עמוד קודם',
        ),
        Text('$currentPage / $totalPages',
            style: const TextStyle(fontSize: 13)),
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: currentPage < totalPages ? onNext : null,
          tooltip: 'עמוד הבא',
        ),
        const VerticalDivider(),
        // זום
        IconButton(
          icon: const Icon(Icons.zoom_out, size: 18),
          onPressed: zoom > kMinZoomPct / 100
              ? () => onZoom((zoom - 0.1).clamp(
                    kMinZoomPct / 100, kMaxZoomPct / 100))
              : null,
        ),
        SizedBox(
          width: 110,
          child: Slider(
            value: zoom.clamp(kMinZoomPct / 100, kMaxZoomPct / 100),
            min:   kMinZoomPct / 100,
            max:   kMaxZoomPct / 100,
            onChanged: onZoom,
            activeColor: TagPlusColors.primary,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.zoom_in, size: 18),
          onPressed: zoom < kMaxZoomPct / 100
              ? () => onZoom((zoom + 0.1).clamp(
                    kMinZoomPct / 100, kMaxZoomPct / 100))
              : null,
        ),
        Text('$zoomPct%', style: const TextStyle(fontSize: 12)),
        const VerticalDivider(),
        // תצוגה
        _ToggleBtn(icon: Icons.margin,       label: 'שוליים', active: showMargins, onTap: onMargins),
        _ToggleBtn(icon: Icons.grid_on,      label: 'רשת',    active: showGrid,    onTap: onGrid),
      ]),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn({required this.icon, required this.label,
      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: active ? TagPlusColors.primary.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 18,
            color: active ? TagPlusColors.primary : TagPlusColors.textSecondary),
      ),
    ),
  );
}

class _StatusBar extends StatelessWidget {
  final int currentPage, totalPages;
  final double zoom;
  const _StatusBar({required this.currentPage,
      required this.totalPages, required this.zoom});

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    color: TagPlusColors.backgroundLight,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(children: [
      Text('עמוד $currentPage מתוך $totalPages',
          style: const TextStyle(fontSize: 11, color: TagPlusColors.textSecondary)),
      const Spacer(),
      Text('זום: ${(zoom * 100).round()}%',
          style: const TextStyle(fontSize: 11, color: TagPlusColors.textSecondary)),
    ]),
  );
}
