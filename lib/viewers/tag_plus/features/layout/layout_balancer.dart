// ============================================================
// features/layout/layout_balancer.dart
// איזון פריסה: חלונות/יתומים + מיקרו-טיפוגרפיה
// ============================================================
import 'dart:math';
import '../../core/models/paragraph.dart';

enum IssueType { widow, orphan, looseColumn, overflow }

class LayoutIssue {
  final IssueType type;
  final int       page;
  final int       paragraphIndex;
  final int       lineCount;
  final double    severity;   // 0–1

  const LayoutIssue({
    required this.type,
    required this.page,
    required this.paragraphIndex,
    this.lineCount = 0,
    this.severity  = 0.5,
  });

  String get description => switch (type) {
    IssueType.widow       => 'חלון בעמוד $page (פסקה $paragraphIndex)',
    IssueType.orphan      => 'יתום בעמוד $page (פסקה $paragraphIndex)',
    IssueType.looseColumn => 'עמודה פתוחה בעמוד $page',
    IssueType.overflow    => 'גלישה בעמוד $page',
  };
}

class MicroAdjustment {
  final int    paragraphIndex;
  final double lineSpacingDelta;   // שינוי במרווח שורות (±)
  final double letterSpacingEm;    // שינוי במרווח אותיות (em)
  final String reason;

  const MicroAdjustment({
    required this.paragraphIndex,
    this.lineSpacingDelta  = 0,
    this.letterSpacingEm   = 0,
    required this.reason,
  });
}

class LayoutBalancer {
  static const int    minWidowLines  = 2;
  static const int    minOrphanLines = 2;
  static const double maxStretch     = 0.12;
  static const double maxShrink      = 0.08;
  static const double maxLetterAdjust= 0.03;

  // ── זיהוי בעיות ───────────────────────────────────────────

  List<LayoutIssue> detectWidowsOrphans(
    List<List<Paragraph>> pages, {
    int charsPerLine = 50,
  }) {
    final issues = <LayoutIssue>[];

    for (var i = 0; i < pages.length; i++) {
      final page    = pages[i];
      final pageNum = i + 1;
      if (page.isEmpty) continue;

      // יתום: שורות ראשונות בעמוד (שייכות לפסקה מהעמוד הקודם)
      final firstLines = _estimateLines(page.first, charsPerLine);
      if (firstLines < minOrphanLines && i > 0) {
        issues.add(LayoutIssue(
          type: IssueType.orphan, page: pageNum,
          paragraphIndex: 0, lineCount: firstLines,
          severity: 1.0 - firstLines / minOrphanLines,
        ));
      }

      // חלון: שורות אחרונות בעמוד (המשך לעמוד הבא)
      final lastLines = _estimateLines(page.last, charsPerLine);
      if (lastLines < minWidowLines && i + 1 < pages.length) {
        issues.add(LayoutIssue(
          type: IssueType.widow, page: pageNum,
          paragraphIndex: page.length - 1,
          lineCount: lastLines,
          severity: 1.0 - lastLines / minWidowLines,
        ));
      }
    }
    return issues;
  }

  // ── חישוב כוונונים ────────────────────────────────────────

  List<MicroAdjustment> calcAdjustments(
    List<LayoutIssue> issues,
    List<Paragraph>   paragraphs,
  ) {
    final adjustments = <MicroAdjustment>[];

    for (final issue in issues) {
      final idx = issue.paragraphIndex;
      if (idx < 0 || idx >= paragraphs.length) continue;

      if (issue.type == IssueType.orphan && idx > 0) {
        adjustments.add(MicroAdjustment(
          paragraphIndex:   idx - 1,
          lineSpacingDelta: -maxShrink * issue.severity,
          reason: 'תיקון יתום עמוד ${issue.page}',
        ));
      } else if (issue.type == IssueType.widow) {
        adjustments.add(MicroAdjustment(
          paragraphIndex:   idx,
          lineSpacingDelta: maxStretch * issue.severity * 0.5,
          reason: 'תיקון חלון עמוד ${issue.page}',
        ));
      }
    }
    return adjustments;
  }

  // ── יישום ─────────────────────────────────────────────────

  int applyAdjustments(
    List<Paragraph>       paragraphs,
    List<MicroAdjustment> adjustments,
  ) {
    var count = 0;
    for (final adj in adjustments) {
      final idx = adj.paragraphIndex;
      if (idx < 0 || idx >= paragraphs.length) continue;
      final old     = paragraphs[idx].style;
      final newSpacing = (old.lineSpacing + adj.lineSpacingDelta).clamp(0.9, 2.0);
      paragraphs[idx] = paragraphs[idx].copyWith(
        style: old.copyWith(lineSpacing: newSpacing),
      );
      count++;
    }
    return count;
  }

  // ── הפעלה אוטומטית ────────────────────────────────────────

  (List<LayoutIssue>, int) autoBalance(
    List<List<Paragraph>> pages, {
    int charsPerLine = 50,
  }) {
    final allParas = pages.expand((p) => p).toList();
    final issues   = detectWidowsOrphans(pages, charsPerLine: charsPerLine);
    final adjs     = calcAdjustments(issues, allParas);
    final applied  = applyAdjustments(allParas, adjs);
    return (issues, applied);
  }

  // ── עזרים ─────────────────────────────────────────────────

  static int _estimateLines(Paragraph p, int cpl) {
    var lines = 0;
    for (final line in p.text.split('\n')) {
      lines += line.isEmpty ? 1 : max(1, (line.length / cpl).ceil());
    }
    return lines;
  }
}
