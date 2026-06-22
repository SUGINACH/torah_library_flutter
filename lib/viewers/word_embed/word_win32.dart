/// word_win32.dart — REVISED
/// ─────────────────────────────────────────────────────────────────────────
/// Windows-only HWND helpers for Word embedding.
/// NO COM / NO IDispatch / NO NativeCallable — those all caused crashes.
/// Word is launched via Process.start (simple, reliable).
/// All Win32 function calls are wrapped here and exported explicitly
/// so word_embed_widget.dart never calls package:win32 directly.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  CONSTANTS — same values as before, kept for easy diffing
// ═══════════════════════════════════════════════════════════════════════════

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
// Keyboard constants for Ctrl+S save
const int kVkControl      = 0x11;
const int kVkS            = 0x53;
const int kKeyeventfKeyup = 0x0002;

// ── keybd_event via direct FFI ──────────────────────────────────────────────
// The win32 Dart package does NOT export keybd_event (deprecated Win32 API,
// skipped by the package code-generator). Load it straight from user32.dll.
typedef _KbdFn = Void Function(Uint8, Uint8, Uint32, IntPtr);
final _keybdEvent = DynamicLibrary.open('user32.dll')
    .lookupFunction<_KbdFn, void Function(int, int, int, int)>('keybd_event');

// ═══════════════════════════════════════════════════════════════════════════
//  WordLauncher — replaces the old WordCom class
//  Launches WINWORD.EXE via Process.start.  No COM at all.
// ═══════════════════════════════════════════════════════════════════════════

class WordLauncher {
  String _currentPath = '';

  /// Path of the file currently open in Word (empty = new document).
  String get currentPath => _currentPath;

  /// Launch Word with an existing file. Returns false if Word is not found.
  Future<bool> openFile(String path) async {
    _currentPath = path;
    return _launch(path);
  }

  /// Launch Word with a blank new document.
  Future<bool> openNew() async {
    _currentPath = '';
    return _launch('');
  }

  Future<bool> _launch(String filePath) async {
    final exe = await _findWordExe();
    if (exe == null) return false;

    try {
      final args = filePath.isNotEmpty ? [filePath] : <String>[];
      // detached = Word keeps running if the Flutter app is closed
      await Process.start(exe, args, mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      // Shell fallback via cmd /c start
      try {
        final shellArgs = filePath.isNotEmpty
            ? ['/c', 'start', '', filePath]
            : ['/c', 'start', '', 'WINWORD.EXE'];
        await Process.start('cmd', shellArgs,
            mode: ProcessStartMode.detached, runInShell: true);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Locate WINWORD.EXE — tries 'where' first, then common paths.
  static Future<String?> _findWordExe() async {
    // 1. Ask Windows where the executable is
    try {
      final r =
          await Process.run('where', ['WINWORD.EXE'], runInShell: true);
      if (r.exitCode == 0) {
        final first =
            r.stdout.toString().trim().split('\n').first.trim();
        if (first.isNotEmpty && File(first).existsSync()) return first;
      }
    } catch (_) {}

    // 2. Check common Office installation folders
    final pfDirs = {
      Platform.environment['ProgramFiles'],
      Platform.environment['ProgramFiles(x86)'],
      r'C:\Program Files',
      r'C:\Program Files (x86)',
    }.whereType<String>();

    const officeRels = [
      r'Microsoft Office\root\Office16\WINWORD.EXE',
      r'Microsoft Office\Office16\WINWORD.EXE',
      r'Microsoft Office\root\Office15\WINWORD.EXE',
      r'Microsoft Office\Office15\WINWORD.EXE',
      r'Microsoft Office\root\Office14\WINWORD.EXE',
      r'Microsoft Office\Office14\WINWORD.EXE',
    ];

    for (final pf in pfDirs) {
      for (final rel in officeRels) {
        final p = '$pf\\$rel';
        if (File(p).existsSync()) return p;
      }
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HWND HELPERS
//  All exported explicitly — word_embed_widget.dart calls ONLY these.
//  Nothing from package:win32 is called directly from the widget.
// ═══════════════════════════════════════════════════════════════════════════

/// Remove title bar + resize border. Keeps Word as a top-level owned window
/// so its full ribbon is preserved — same as Python _strip_frame_only().
void stripFrame(int hwnd) {
  int style = GetWindowLongPtr(hwnd, kGwlStyle);
  style &= ~(kWsCaption | kWsThickframe);
  style |= kWsVisible;
  SetWindowLongPtr(hwnd, kGwlStyle, style);

  final exs = GetWindowLongPtr(hwnd, kGwlExstyle);
  SetWindowLongPtr(hwnd, kGwlExstyle, exs | kWsExToolwnd);

  SetWindowPos(hwnd, 0, 0, 0, 0, 0,
      kSwpFrame | kSwpNosize | kSwpNomove | kSwpNozorder | kSwpNoact);
}

/// Find Word's HWND by its window class 'OpusApp'.
/// Simple FindWindow — no EnumWindows/NativeCallable needed.
/// Returns 0 if Word is not running yet.
int findWordHwnd() {
  final cls = 'OpusApp'.toNativeUtf16();
  final h   = FindWindow(cls, nullptr);
  calloc.free(cls);
  return h;
}

/// Get the Flutter app's HWND.
int getFlutterHwnd() {
  final cls = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
  final h   = FindWindow(cls, nullptr);
  calloc.free(cls);
  return h != 0 ? h : GetActiveWindow();
}

/// Make wordHwnd owned by ownerHwnd (keeps Word on top, ribbon intact).
void setWordOwner(int wordHwnd, int ownerHwnd) =>
    SetWindowLongPtr(wordHwnd, kGwlpHwndParent, ownerHwnd);

/// Physical screen (x, y, w, h) of a window via GetWindowRect.
(int, int, int, int) hwndRect(int hwnd) {
  final r   = calloc<RECT>();
  GetWindowRect(hwnd, r);
  final res = (r.ref.left, r.ref.top,
      r.ref.right - r.ref.left, r.ref.bottom - r.ref.top);
  calloc.free(r);
  return res;
}

/// Physical screen coordinates of a window's client-area top-left.
(int, int) clientOrigin(int hwnd) {
  final pt = calloc<POINT>()
    ..ref.x = 0
    ..ref.y = 0;
  ClientToScreen(hwnd, pt);
  final res = (pt.ref.x, pt.ref.y);
  calloc.free(pt);
  return res;
}

/// Position Word at (x, y, w, h) and make it visible.
void showWordAt(int hwnd, int x, int y, int w, int h) {
  SetWindowPos(hwnd, 0, x, y, w, h, kSwpNoact | kSwpNozorder);
  ShowWindow(hwnd, kSwShow);
}

/// Reposition Word without changing z-order (called by the 50ms sync timer).
void moveWordTo(int hwnd, int x, int y, int w, int h) =>
    SetWindowPos(hwnd, 0, x, y, w, h, kSwpNoact | kSwpNozorder);

/// Hide Word's window (when the tab is not active).
void hideWord(int hwnd) => ShowWindow(hwnd, kSwHide);

/// Send Ctrl+S to the Word window (triggers Word's own save dialog if unsaved).
void sendSave(int hwnd) {
  if (hwnd == 0) return;
  SetForegroundWindow(hwnd);
  _keybdEvent(kVkControl, 0, 0, 0);
  _keybdEvent(kVkS, 0, 0, 0);
  _keybdEvent(kVkS, 0, kKeyeventfKeyup, 0);
  _keybdEvent(kVkControl, 0, kKeyeventfKeyup, 0);
}

/// Gracefully close Word (it will prompt to save unsaved changes).
void quitWord(int hwnd) {
  if (hwnd != 0) PostMessage(hwnd, WM_CLOSE, 0, 0);
}