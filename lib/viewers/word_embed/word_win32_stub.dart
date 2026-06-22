/// word_win32_stub.dart — non-Windows stub
/// All symbols mirror word_win32.dart exactly.
// ─────────────────────────────────────────────────────────────────────────

const int kGwlStyle       = -16;
const int kGwlExstyle     = -20;
const int kGwlpHwndParent = -8;
const int kWsCaption      = 0x00C00000;
const int kWsThickframe   = 0x00040000;
const int kWsVisible      = 0x10000000;
const int kWsExToolwnd    = 0x00000080;
const int kSwpNosize      = 0x0001;
const int kSwpNomove      = 0x0002;
const int kSwpNozorder    = 0x0004;
const int kSwpNoact       = 0x0010;
const int kSwpFrame       = 0x0020;
const int kSwHide         = 0;
const int kSwShow         = 5;
const int kVkControl      = 0x11;
const int kVkS            = 0x53;
const int kKeyeventfKeyup = 0x0002;

class WordLauncher {
  String get currentPath => '';
  Future<bool> openFile(String path)  async => false;
  Future<bool> openNew()              async => false;
}

void                  stripFrame(int hwnd)                          {}
int                   findWordHwnd()                                => 0;
int                   getFlutterHwnd()                             => 0;
void                  setWordOwner(int wh, int oh)                  {}
(int, int, int, int)  hwndRect(int hwnd)                           => (0, 0, 0, 0);
(int, int)            clientOrigin(int hwnd)                       => (0, 0);
void                  showWordAt(int h, int x, int y, int w, int ht) {}
void                  moveWordTo(int h, int x, int y, int w, int ht) {}
void                  hideWord(int hwnd)                            {}
void                  sendSave(int hwnd)                            {}
void                  quitWord(int hwnd)                            {}