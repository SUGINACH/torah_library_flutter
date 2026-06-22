// ============================================================
// core/engines/page_calculator.dart — חישוב עמודים ושורות
// ============================================================
import 'dart:math';
import '../models/paragraph.dart';
import '../models/document.dart';
import '../../config/app_constants.dart';

class LineMetrics {
  final double heightPx;
  final double spacing;
  final int    charsPerLine;

  const LineMetrics({
    required this.heightPx,
    required this.spacing,
    required this.charsPerLine,
  });

  double get totalHeight => heightPx * spacing;
}

class PageLayout {
  final int              pageNumber;
  final List<Paragraph>  paragraphs;
  final bool             isRightPage;
  const PageLayout({
    required this.pageNumber,
    required this.paragraphs,
    this.isRightPage = true,
  });
}

class PageCalculator {
  PageSettings _settings;

  PageCalculator({PageSettings? settings})
      : _settings = settings ?? const PageSettings();

  void updateSettings(PageSettings s) => _settings = s;

  double get _mmToPx => kDefaultDpi / 25.4;

  // ── מדדי שורה ─────────────────────────────────────────────

  LineMetrics calcLineMetrics({
    required double fontSize,
    double spacing = 1.15,
    double charsPerMm = 1.8,  // ממוצע לגופן עברי 12pt
  }) {
    final heightPx   = fontSize * 1.333;          // pt → px (96dpi)
    final textWidthPx = _settings.textWidth * _mmToPx;
    final avgCharW   = fontSize * 0.6;            // ממוצע תו בפיקסלים
    final cpl        = max(1, (textWidthPx / avgCharW).floor());
    return LineMetrics(heightPx: heightPx, spacing: spacing, charsPerLine: cpl);
  }

  int calcLinesPerPage({double fontSize = 12, double spacing = 1.15}) {
    final metrics   = calcLineMetrics(fontSize: fontSize, spacing: spacing);
    final heightPx  = _settings.textHeight * _mmToPx;
    return max(1, (heightPx / metrics.totalHeight).floor());
  }

  // ── חלוקה לעמודים ─────────────────────────────────────────

  List<PageLayout> distributeToPages(
    List<Paragraph> paragraphs, {
    double fontSize  = 12,
    double spacing   = 1.15,
  }) {
    final lpp     = calcLinesPerPage(fontSize: fontSize, spacing: spacing);
    final metrics = calcLineMetrics(fontSize: fontSize, spacing: spacing);

    final pages       = <PageLayout>[];
    var   currentPage = <Paragraph>[];
    var   usedLines   = 0;

    int paraLines(Paragraph p) {
      var lines = 0;
      for (final line in p.text.split('\n')) {
        lines += line.isEmpty
            ? 1
            : max(1, (line.length / metrics.charsPerLine).ceil());
      }
      return lines;
    }

    for (final para in paragraphs) {
      final paraH = paraLines(para);
      if (currentPage.isNotEmpty && usedLines + paraH > lpp) {
        pages.add(PageLayout(
          pageNumber: pages.length + 1,
          paragraphs: List.from(currentPage),
          isRightPage: (pages.length + 1) % 2 == 1,
        ));
        currentPage = [];
        usedLines   = 0;
      }
      currentPage.add(para);
      usedLines += paraH;
    }
    if (currentPage.isNotEmpty) {
      pages.add(PageLayout(
        pageNumber: pages.length + 1,
        paragraphs: currentPage,
        isRightPage: (pages.length + 1) % 2 == 1,
      ));
    }
    return pages.isEmpty
        ? [const PageLayout(pageNumber: 1, paragraphs: [])]
        : pages;
  }

  // ── רוחב טורים ────────────────────────────────────────────

  List<double> calcColumnWidths(int numCols, {double gap = 10}) {
    final w = (_settings.textWidth - gap * (numCols - 1)) / numCols;
    return List.generate(numCols, (_) => max(10, w));
  }

  int estimatePages(String text, {double fontSize = 12}) {
    final chars = text.length;
    final lpp   = calcLinesPerPage(fontSize: fontSize);
    final cpl   = calcLineMetrics(fontSize: fontSize).charsPerLine;
    return max(1, (chars / (lpp * cpl)).ceil());
  }

  PageSettings get settings => _settings;
}
