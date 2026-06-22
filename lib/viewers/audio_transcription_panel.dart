/// audio_transcription_panel.dart
///
/// Flutter equivalent of audio_panel.py (PyQt6 / faster-whisper).
/// Preserves every detail: all Hebrew strings, RTL layout, model options,
/// default model (Small / index 2), colour scheme, progress behaviour,
/// editable output, clipboard, and save-to-file.
///
/// Transcription is delegated to the bundled Python worker
/// (transcription_worker.py) which is spawned as a child process —
/// exactly the same non-blocking approach as PyQt6's QThread.
///
/// ─── Embedding as a tab in a larger app ─────────────────────────────
///
///   final _panelKey = GlobalKey<AudioTranscriptionPanelState>();
///
///   // in your TabView / PageView:
///   AudioTranscriptionPanel(key: _panelKey)
///
///   // when the tab is CLOSED (not just switched):
///   _panelKey.currentState?.stopWorker();
///
///   // to query whether transcription is in progress:
///   _panelKey.currentState?.isRunning
///
/// ─── Required pubspec.yaml additions ────────────────────────────────
///
///   dependencies:
///     file_picker: ^8.1.2
///     path:        ^1.9.0
///     path_provider: ^2.1.4
///
///   flutter:
///     assets:
///       - transcription_worker.py   # fallback: extract from bundle to temp
///
/// ─── Python worker deployment ────────────────────────────────────────
///
///   Development  : place transcription_worker.py at the project root.
///   Production   : place it next to the compiled executable.
///   Fallback     : the widget extracts it from Flutter assets automatically.

library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ════════════════════════════════════════════════════════════════════
// Private data types
// ════════════════════════════════════════════════════════════════════

class _ModelOption {
  const _ModelOption(this.label, this.value);
  final String label;
  final String value;
}

enum _ProgressStatus { none, success, error }

// ════════════════════════════════════════════════════════════════════
// Public widget
// ════════════════════════════════════════════════════════════════════

class AudioTranscriptionPanel extends StatefulWidget {
  const AudioTranscriptionPanel({super.key});

  @override
  State<AudioTranscriptionPanel> createState() =>
      AudioTranscriptionPanelState();
}

// State is public so a parent widget can access [isRunning] / [stopWorker]
// via a GlobalKey<AudioTranscriptionPanelState>.
class AudioTranscriptionPanelState extends State<AudioTranscriptionPanel> {
  // ── Colour constants (mirrors original stylesheet) ────────────────
  static const Color _kGold    = Color(0xFFD9B13E);
  static const Color _kBrown   = Color(0xFF5F4030);
  static const Color _kCardBg  = Color(0xFFF7F7F7);
  static const Color _kHint    = Color(0xFF5C4A38);
  static const Color _kErrRed  = Color(0xFFc0392b);
  static const Color _kComboBorder = Color(0xFFC9B88A);

  // ── Model options (same order and labels as the original) ─────────
  static const List<_ModelOption> _kModels = [
    _ModelOption('מהיר מאוד - איכות נמוכה (Tiny)',             'tiny'),
    _ModelOption('מהיר - איכות סבירה (Base)',                  'base'),
    _ModelOption('מאוזן - איכות טובה (Small)',                 'small'),    // index 2 — default
    _ModelOption('מדויק - איכות גבוהה (Medium) [מומלץ]',      'medium'),
    _ModelOption('מקסימלי - דורש משאבים כבדים (Large-v3)',     'large-v3'),
  ];

  // ── Mutable state ─────────────────────────────────────────────────
  String          _audioPath     = '';
  String          _modelKey      = 'small'; // mirrors setCurrentIndex(2)
  String          _progressText  = '';
  bool            _running       = false;
  bool            _showBar       = false;   // indeterminate progress bar
  _ProgressStatus _progressStatus = _ProgressStatus.none;
  bool            _whisperOk     = false;
  bool            _whisperChecked = false;
  Process?        _proc;

  final TextEditingController _outputCtrl = TextEditingController();

  // ── Public API ────────────────────────────────────────────────────

  /// True while a transcription process is active.
  bool get isRunning => _running;

  /// Terminates the background process.
  /// Call this when the tab is CLOSED (not just switched).
  /// On a simple tab switch leave the worker running —
  /// results will be visible when the user returns.
  void stopWorker() {
    _proc?.kill();
    _proc = null;
    if (mounted) {
      setState(() {
        _running = false;
        _showBar  = false;
      });
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkWhisperAvailability();
  }

  @override
  void dispose() {
    stopWorker();
    _outputCtrl.dispose();
    super.dispose();
  }

  // ── Environment helpers ───────────────────────────────────────────

  /// 'python' on Windows, 'python3' elsewhere.
  String get _pythonExe => Platform.isWindows ? 'python' : 'python3';

  /// Checks whether faster-whisper is importable (mirrors WHISPER_AVAILABLE).
  Future<void> _checkWhisperAvailability() async {
    try {
      final result = await Process.run(
        _pythonExe,
        ['-c', 'import faster_whisper; print("ok")'],
      );
      if (mounted) {
        setState(() {
          _whisperOk =
              result.exitCode == 0 &&
              (result.stdout as String).trim() == 'ok';
          _whisperChecked = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _whisperOk      = false;
          _whisperChecked = true;
        });
      }
    }
  }

  /// Resolves the absolute path to transcription_worker.py.
  /// Search order:
  ///   1. Beside the compiled executable  (production)
  ///   2. Project working directory       (flutter run)
  ///   3. Flutter asset extracted to temp (bundled fallback)
  Future<String> _resolveWorkerScript() async {
    // 1. Beside the executable
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final beside = File(p.join(exeDir, 'transcription_worker.py'));
    if (beside.existsSync()) return beside.path;

    // 2. Working directory (development)
    final cwd = File(p.join(Directory.current.path, 'transcription_worker.py'));
    if (cwd.existsSync()) return cwd.path;

    // 3. Extract bundled asset
    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File(p.join(tmpDir.path, 'transcription_worker.py'));
    if (!tmpFile.existsSync()) {
      final src = await rootBundle.loadString('transcription_worker.py');
      await tmpFile.writeAsString(src, encoding: utf8);
    }
    return tmpFile.path;
  }

  // ── User actions ──────────────────────────────────────────────────

  Future<void> _pickAudio() async {
    if (_running) {
      _showDialog('פעולה רצה', 'יש להמתין לסיום התמלול הנוכחי.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'flac'],
      dialogTitle: 'בחר קובץ אודיו',
    );

    final path = result?.files.single.path;
    if (path != null) {
      setState(() {
        _audioPath      = path;
        _progressText   = '';
        _progressStatus = _ProgressStatus.none;
        _outputCtrl.clear();
      });
    }
  }

  Future<void> _startTranscription() async {
    if (_audioPath.isEmpty || !_whisperOk || _running) return;

    setState(() {
      _running        = true;
      _showBar        = true;
      _progressText   = 'מכין סביבה...';
      _progressStatus = _ProgressStatus.none;
      _outputCtrl.clear();
    });

    try {
      final scriptPath = await _resolveWorkerScript();

      _proc = await Process.start(
        _pythonExe,
        [scriptPath, _audioPath, _modelKey],
      );

      // Read JSON-line protocol from stdout (progress / result / error).
      _proc!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleOutputLine, onError: (_) {});

      // Pipe stderr to debug console only (not shown to user).
      _proc!.stderr
          .transform(utf8.decoder)
          .listen((chunk) => debugPrint('[whisper-stderr] $chunk'));

      final exitCode = await _proc!.exitCode;
      _proc = null;

      // Safety net: if the process exited non-zero but we never received
      // a 'result' or 'error' JSON line.
      if (mounted && _running && exitCode != 0) {
        _onTranscriptionError('תהליך הסתיים עם קוד שגיאה: $exitCode');
      }
    } catch (e) {
      _proc = null;
      _onTranscriptionError(e.toString());
    }
  }

  /// Parses a single JSON line emitted by transcription_worker.py.
  void _handleOutputLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      final type = (data['type'] as String?) ?? '';
      final text = (data['text'] as String?) ?? '';

      switch (type) {
        case 'progress':
          if (mounted) setState(() => _progressText = text);
        case 'result':
          _onTranscriptionSuccess(text);
        case 'error':
          _onTranscriptionError(text);
      }
    } catch (_) {
      // Unparseable line — ignore (can happen with Python warnings on stderr)
    }
  }

  void _onTranscriptionSuccess(String text) {
    if (!mounted) return;
    setState(() {
      _running        = false;
      _showBar        = false;
      _outputCtrl.text = text;
      _progressText   = 'התמלול הסתיים בהצלחה!';
      _progressStatus = _ProgressStatus.success;
    });
  }

  void _onTranscriptionError(String error) {
    if (!mounted) return;
    setState(() {
      _running        = false;
      _showBar        = false;
      _progressText   = 'התמלול נכשל.';
      _progressStatus = _ProgressStatus.error;
    });
    _showDialog('שגיאה בתמלול', 'אירעה שגיאה:\n$error', isError: true);
  }

  void _copyToClipboard() {
    final text = _outputCtrl.text;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    _showDialog('הועתק', 'הטקסט הועתק ללוח בהצלחה.');
  }

  Future<void> _saveToFile() async {
    final text = _outputCtrl.text;
    if (text.isEmpty) return;

    final defaultName = _audioPath.isNotEmpty
        ? '${p.basenameWithoutExtension(_audioPath)}_תמלול.txt'
        : 'תמלול.txt';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'שמור תמלול',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (savePath == null) return;

    try {
      await File(savePath).writeAsString(text, encoding: utf8);
      if (mounted) _showDialog('נשמר', 'הקובץ נשמר בהצלחה.');
    } catch (e) {
      if (mounted) {
        _showDialog('שגיאה', 'לא ניתן לשמור את הקובץ:\n$e', isError: true);
      }
    }
  }

  // ── Dialog helper ─────────────────────────────────────────────────

  void _showDialog(String title, String message, {bool isError = false}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('אישור'),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_whisperChecked && !_whisperOk) ...[
              const SizedBox(height: 8),
              _buildWhisperWarning(),
            ],
            const SizedBox(height: 8),
            _buildHintText(),
            const SizedBox(height: 12),
            _buildControlCard(),
            if (_progressText.isNotEmpty || _showBar) ...[
              const SizedBox(height: 8),
              _buildProgressSection(),
            ],
            const SizedBox(height: 8),
            Expanded(child: _buildOutputArea()),
            const SizedBox(height: 8),
            _buildBottomRow(),
          ],
        ),
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────

  Widget _buildHeader() {
    return const Row(
      children: [
        Text(
          'תמלול אודיו תורני בעברית (AI)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kBrown,
          ),
        ),
        Spacer(),
      ],
    );
  }

  Widget _buildWhisperWarning() {
    return const Text(
      '⚠️ הספריה faster-whisper לא מותקנת.\n'
      'נא להריץ במסוף: pip install faster-whisper',
      style: TextStyle(color: _kErrRed, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildHintText() {
    return const Text(
      'ייבא קובץ שמע של שיעור או הרצאה. התמלול מבוצע באופן מקומי על המחשב שלך '
      'לשמירה על פרטיות. שים לב: רמות דיוק גבוהות דורשות זמן עיבוד ארוך יותר.',
      style: TextStyle(color: _kHint),
    );
  }

  Widget _buildControlCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        border: Border.all(color: _kGold),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: file picker ─────────────────────────────────
          Row(
            children: [
              _styledButton('בחר קובץ שמע…', _pickAudio),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _audioPath.isEmpty ? 'לא נבחר קובץ' : p.basename(_audioPath),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  // File-system paths are always LTR regardless of UI direction
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Row 2: model selector + run ────────────────────────
          Row(
            children: [
              const Text('רמת דיוק (מודל):'),
              const SizedBox(width: 8),
              Expanded(child: _buildModelDropdown()),
              const SizedBox(width: 8),
              _styledButton(
                'התחל תמלול ▶',
                // Enabled only when a file is chosen, whisper is installed,
                // and no transcription is currently running.
                (_audioPath.isNotEmpty && _whisperOk && !_running)
                    ? _startTranscription
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kComboBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<String>(
        value: _modelKey,
        isExpanded: true,
        underline: const SizedBox(),
        items: _kModels
            .map(
              (opt) => DropdownMenuItem(
                value: opt.value,
                child: Text(opt.label, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        // Disabled while running — mirrors combo_model.setEnabled(False)
        onChanged: _running
            ? null
            : (val) {
                if (val != null) setState(() => _modelKey = val);
              },
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        Center(
          child: Text(
            _progressText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: switch (_progressStatus) {
                _ProgressStatus.success => Colors.green,
                _ProgressStatus.error   => Colors.red,
                _ProgressStatus.none    => null,
              },
              fontWeight: _progressStatus != _ProgressStatus.none
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        // Indeterminate bar — mirrors QProgressBar with range(0,0)
        if (_showBar) ...[
          const SizedBox(height: 4),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildOutputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGold),
        borderRadius: BorderRadius.circular(4),
      ),
      // TextField with expands:true fills the parent vertically
      child: TextField(
        controller: _outputCtrl,
        maxLines: null,
        expands: true,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        // readOnly: false — user can edit the transcription (mirrors setReadOnly(False))
        style: const TextStyle(fontSize: 14, height: 1.5),
        decoration: const InputDecoration(
          hintText: 'כאן יופיע התמלול... תוכל לערוך אותו ידנית בסיום.',
          hintTextDirection: TextDirection.rtl,
          contentPadding: EdgeInsets.all(8),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        _styledButton('העתק ללוח', _copyToClipboard),
        const SizedBox(width: 8),
        _styledButton('שמור כקובץ טקסט', _saveToFile),
        const Spacer(),
      ],
    );
  }

  // ── Shared button style (mirrors objectName="categoriesBtn") ──────

  Widget _styledButton(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _kGold,
        foregroundColor: _kBrown,
        disabledBackgroundColor: const Color(0xFFE8D89A),
        disabledForegroundColor: const Color(0xFF9A8060),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 0,
      ),
      child: Text(label),
    );
  }
}
