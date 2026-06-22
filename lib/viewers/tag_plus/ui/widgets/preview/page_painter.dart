// ============================================================
// ui/widgets/preview/page_painter.dart — ציור עמוד מותאם
// ============================================================
import 'package:flutter/material.dart';
import '../../../core/models/paragraph.dart';
import '../../../core/models/document.dart';
import '../../../config/theme_config.dart';
import '../../../config/text_config.dart';

class PagePainter extends CustomPainter {
  final List<Paragraph> paragraphs;
  final PageSettings    settings;
  final double          zoom;
  final bool            showMargins;
  final bool            showGrid;
  final int             pageNumber;

  const PagePainter({
    required this.paragraphs,
    required this.settings,
    this.zoom        = 1.0,
    this.showMargins = true,
    this.showGrid    = false,
    this.pageNumber  = 1,
  });

  double get mm => 3.7795 * zoom;  // 96 DPI

  @override
  void paint(Canvas canvas, Size size) {
    final pw = settings.width  * mm;
    final ph = settings.height * mm;

    // רקע
    canvas.drawRect(Rect.fromLTWH(0,0,pw,ph),
        Paint()..color = Colors.white);
    // מסגרת
    canvas.drawRect(Rect.fromLTWH(0,0,pw,ph),
        Paint()..color = TagPlusColors.pageBorder
               ..style = PaintingStyle.stroke
               ..strokeWidth = 0.5);

    if (showGrid)    _drawGrid(canvas, pw, ph);
    if (showMargins) _drawMargins(canvas, pw, ph);
    _drawText(canvas, pw, ph);
    _drawPageNumber(canvas, pw, ph);
  }

  void _drawGrid(Canvas canvas, double pw, double ph) {
    final p = Paint()..color = Colors.grey.withValues(alpha: 0.25)..strokeWidth = 0.3;
    final step = 10 * mm;
    for (double y = 0; y < ph; y += step) {
      canvas.drawLine(Offset(0,y), Offset(pw,y), p);
    }
    for (double x = 0; x < pw; x += step) {
      canvas.drawLine(Offset(x,0), Offset(x,ph), p);
    }
  }

  void _drawMargins(Canvas canvas, double pw, double ph) {
    final r = Rect.fromLTRB(
      settings.marginInner  * mm,
      settings.marginTop    * mm,
      pw - settings.marginOuter  * mm,
      ph - settings.marginBottom * mm,
    );
    canvas.drawRect(r,
        Paint()..color = TagPlusColors.pageMarginBg..style = PaintingStyle.fill);
    canvas.drawRect(r,
        Paint()..color = TagPlusColors.marginLine
               ..style = PaintingStyle.stroke..strokeWidth = 0.5);
  }

  void _drawText(Canvas canvas, double pw, double ph) {
    if (paragraphs.isEmpty) return;
    final lx = settings.marginInner  * mm;
    final ty = settings.marginTop    * mm;
    final tw = settings.textWidth    * mm;
    final by = ph - settings.marginBottom * mm;
    var y = ty;

    for (final p in paragraphs) {
      if (y >= by) break;
      final fs = (p.style.fontSize * zoom).clamp(4.0, 72.0);
      final sp = p.style.paragraphSpacing * mm * 0.35;
      final snippet = p.text.length > 180
          ? '${p.text.substring(0,180)}…' : p.text;
      final tp = TextPainter(
        text: TextSpan(text: snippet, style: TextStyle(
          fontFamily: p.style.fontFamily,
          fontSize:   fs,
          fontWeight: p.style.bold   ? FontWeight.bold   : FontWeight.normal,
          fontStyle:  p.style.italic ? FontStyle.italic  : FontStyle.normal,
          decoration: p.style.underline
              ? TextDecoration.underline : TextDecoration.none,
          color:  _hex(p.style.color),
          height: p.style.lineSpacing,
        )),
        textDirection: TextDirection.rtl,
        textAlign:     _align(p.style.alignment),
        maxLines: 8, ellipsis: '…',
      )..layout(maxWidth: tw);
      tp.paint(canvas, Offset(lx, y.clamp(ty, by - tp.height)));
      y += tp.height + sp;
    }
  }

  void _drawPageNumber(Canvas canvas, double pw, double ph) {
    final tp = TextPainter(
      text: TextSpan(text: '— $pageNumber —', style: TextStyle(
          fontSize: (8 * zoom).clamp(4.0,14.0),
          color: Colors.grey.shade500, fontFamily: 'David')),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: pw);
    tp.paint(canvas, Offset((pw - tp.width) / 2, ph - 18 * zoom));
  }

  static Color _hex(String h) {
    try { return Color(int.parse('FF${h.replaceAll("#","")}', radix: 16)); }
    catch (_) { return Colors.black; }
  }

  static TextAlign _align(TagTextAlignment a) => switch(a) {
    TagTextAlignment.right   => TextAlign.right,
    TagTextAlignment.left    => TextAlign.left,
    TagTextAlignment.center  => TextAlign.center,
    TagTextAlignment.justify => TextAlign.justify,
  };

  @override
  bool shouldRepaint(PagePainter o) =>
      o.paragraphs != paragraphs || o.zoom != zoom ||
      o.showMargins != showMargins || o.pageNumber != pageNumber;
}
