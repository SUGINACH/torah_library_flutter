// ============================================================
// config/app_constants.dart — קבועי אפליקציה
// ============================================================

const String kAppName        = 'תג פלוס';
const String kAppVersion     = '2.0.0';
const String kAppAuthor      = 'מוטי הורביץ';
const String kAppDescription = 'מערכת עימוד מתקדמת לספרי קודש';
const String kAppCopyright   = '© 2026 $kAppAuthor';

// קבצים
const String kSettingsKey      = 'tag_plus_settings';
const String kRecentFilesKey   = 'tag_plus_recent_files';
const int    kMaxRecentFiles   = 10;
const int    kAutoSaveSeconds  = 300;
const int    kMaxUndoLevels    = 100;

// גבולות
const double kMinFontSize   = 6;
const double kMaxFontSize   = 72;
const double kMinPageWidth  = 50;
const double kMaxPageWidth  = 500;
const double kMinPageHeight = 50;
const double kMaxPageHeight = 500;
const int    kMinZoomPct    = 25;
const int    kMaxZoomPct    = 400;

// המרות
const double kMmToPt   = 2.83465;   // מ"מ → נקודות טיפוגרפיות
const double kPtToMm   = 0.352778;
const double kMmToPx96 = 3.77953;   // מ"מ → פיקסלים ב-96 DPI
const double kInchToMm = 25.4;
const int    kDefaultDpi = 96;

// extensions קבצים נתמכים
const List<String> kSupportedImportExtensions = ['.tag', '.txt', '.docx'];
const List<String> kSupportedExportExtensions = ['.pdf', '.docx', '.txt', '.tag', '.png'];
