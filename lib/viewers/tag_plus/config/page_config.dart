// ============================================================
// config/page_config.dart — הגדרות עמוד ושוליים
// ============================================================

class PageSizes {
  static const double a4Width      = 210.0;
  static const double a4Height     = 297.0;
  static const double b5Width      = 176.0;
  static const double b5Height     = 250.0;
  static const double letterWidth  = 215.9;
  static const double letterHeight = 279.4;
  static const double seferWidth   = 170.0;  // ספר קודש
  static const double seferHeight  = 240.0;

  static const Map<String, (double, double)> presets = {
    'A4':          (a4Width,     a4Height),
    'B5':          (b5Width,     b5Height),
    'Letter':      (letterWidth, letterHeight),
    'ספר קודש':   (seferWidth,  seferHeight),
  };
}

class DefaultMargins {
  static const double top    = 20.0;
  static const double bottom = 20.0;
  static const double left   = 15.0;
  static const double right  = 15.0;
  static const double inner  = 20.0;   // פנימי (כריכה)
  static const double outer  = 15.0;   // חיצוני
  static const double header = 10.0;
  static const double footer = 10.0;
}

enum ExportFormat { pdf, docx, txt, tag, png }

enum PdfQuality {
  screen(72),
  ebook(150),
  printer(300),
  prepress(600);

  const PdfQuality(this.dpi);
  final int dpi;
}

enum PageOrientation { portrait, landscape }
