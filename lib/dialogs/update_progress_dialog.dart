// lib/dialogs/update_progress_dialog.dart
// Flutter equivalent of UpdateProgressDialog + UpdateWorker in update_dialog.py.
//
// Shows a progress bar + live log while the backend runs indexing.
// Indexing is delegated to LibraryService so the dialog stays UI-only.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/library_service.dart';

// ── Stage descriptions (mirrors STAGES in update_dialog.py) ─────────────────
const _kStages = [
  (id: 'scan',  label: 'סריקת קבצים חדשים'),
  (id: 'index', label: 'אינדוקס תוכן ספרים'),
  (id: 'sort',  label: 'מיון קטלוג'),
  (id: 'fts',   label: 'בניית אינדקס חיפוש מלא'),
];

// ── Public dialog — use showDialog<bool> to get the completion flag ──────────

class UpdateProgressDialog extends StatefulWidget {
  const UpdateProgressDialog({super.key});

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  // ── State (mirrors UpdateWorker instance variables) ───────────────────────
  final List<String> _log    = [];
  double _progress           = 0.0;
  String _statusText         = 'מתחיל עדכון…';
  String _currentStage       = '';
  bool   _running            = false;
  bool   _done               = false;
  bool   _error              = false;

  // Streams from the service — cancel on dispose
  StreamSubscription<Map<String, dynamic>>? _sub;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Start immediately, mirrors UpdateWorker.start() in __init__
    WidgetsBinding.instance.addPostFrameCallback((_) => _startUpdate());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Update logic ──────────────────────────────────────────────────────────

  /// Mirrors UpdateWorker.run() + emit_progress() + emit_log()
  Future<void> _startUpdate() async {
    setState(() { _running = true; _statusText = 'מתחיל עדכון…'; });

    final svc = context.read<LibraryService>();
    // LibraryService.runUpdateIndex() returns a broadcast Stream of events:
    //   {type: 'progress', value: double}         — 0..1
    //   {type: 'stage',    id: String}
    //   {type: 'log',      msg: String}
    //   {type: 'done'}
    //   {type: 'error',    msg: String}
    //
    // If your implementation doesn't support a stream, you can fire progress
    // events as a List and play them back here.
    final stream = svc is _Streamable
        ? (svc as _Streamable).runUpdateIndex()
        : _stubStream();

    _sub = stream.listen(
      _onEvent,
      onError: (e) => _appendLog('❌ שגיאה: $e', isError: true),
      onDone:  _onStreamDone,
    );
  }

  void _onEvent(Map<String, dynamic> ev) {
    if (!mounted) return;
    final type = ev['type'] as String? ?? '';
    setState(() {
      switch (type) {
        case 'progress':
          _progress = (ev['value'] as double).clamp(0, 1);
        case 'stage':
          _currentStage = ev['id'] as String? ?? '';
          final lbl = _kStages
              .firstWhere((s) => s.id == _currentStage,
                  orElse: () => (id: '', label: _currentStage))
              .label;
          _statusText = lbl;
          _appendLog('▶ $lbl', isError: false);
        case 'log':
          _appendLog(ev['msg'] as String? ?? '', isError: false);
        case 'error':
          _appendLog('❌ ${ev['msg'] ?? 'שגיאה'}', isError: true);
          _error = true;
      }
    });
    // Auto-scroll log
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _appendLog(String msg, {required bool isError}) {
    _log.add(isError ? '⛔ $msg' : msg);
  }

  void _onStreamDone() {
    if (!mounted) return;
    setState(() {
      _done    = true;
      _running = false;
      _progress = _error ? _progress : 1.0;
      _statusText = _error ? 'הסתיים עם שגיאות' : 'עדכון הסתיים בהצלח ✓';
      _appendLog(_statusText, isError: _error);
    });
    if (!_error) {
      // Invalidate sorted-books cache (mirrors update_dialog's done signal handler)
      context.read<LibraryService>().invalidateBooksCache();
    }
  }

  // ── Stub stream (used when no real service is connected) ──────────────────
  Stream<Map<String, dynamic>> _stubStream() async* {
    for (var i = 0; i < _kStages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      yield {'type': 'stage', 'id': _kStages[i].id};
      await Future.delayed(const Duration(milliseconds: 800));
      yield {'type': 'progress', 'value': (i + 1) / _kStages.length};
    }
    await Future.delayed(const Duration(milliseconds: 200));
    yield {'type': 'done'};
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFFCF5),
        title: const Text('עדכון ואינדוקס ספרים',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2118))),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stage indicators
              _buildStageRow(),
              const SizedBox(height: 16),
              // Status text
              Text(
                _statusText,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 14,
                  color: _error
                      ? const Color(0xFFc0392b)
                      : const Color(0xFF2C2118),
                ),
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _running && !_done ? null : _progress,
                  minHeight: 18,
                  backgroundColor: const Color(0xFFE7D3A4),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _error
                        ? const Color(0xFFc0392b)
                        : const Color(0xFFD9B13E),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Log area (mirrors self.log_text QTextEdit)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Scrollbar(
                  controller: _scrollCtrl,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(8),
                    itemCount: _log.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        _log[i],
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12,
                          color: _log[i].startsWith('⛔')
                              ? const Color(0xFFFF6B6B)
                              : _log[i].startsWith('▶')
                                  ? const Color(0xFF4EC9B0)
                                  : const Color(0xFFCCCCCC),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_done)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _error
                    ? const Color(0xFFc0392b)
                    : const Color(0xFFD9B13E),
              ),
              onPressed: () => Navigator.pop(context, !_error),
              child: Text(
                _error ? 'סגור' : 'סיים',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          if (!_done)
            TextButton(
              onPressed: () {
                _sub?.cancel();
                Navigator.pop(context, false);
              },
              child: const Text('ביטול'),
            ),
        ],
      ),
    );
  }

  Widget _buildStageRow() {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _kStages.length; i++) ...[
          _StageChip(
            label:     _kStages[i].label,
            isActive:  _currentStage == _kStages[i].id,
            isDone:    _done ||
                _kStages.indexWhere((s) => s.id == _currentStage) > i,
          ),
          if (i < _kStages.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('◀', style: TextStyle(color: Color(0xFFD9B13E))),
            ),
        ],
      ],
    );
  }
}

// ── Stage indicator chip ──────────────────────────────────────────────────────

class _StageChip extends StatelessWidget {
  final String label;
  final bool   isActive;
  final bool   isDone;
  const _StageChip({
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFFD9B13E)
            : isActive
                ? const Color(0xFFEFD8A8)
                : Colors.transparent,
        border: Border.all(
          color: (isActive || isDone)
              ? const Color(0xFFD9B13E)
              : const Color(0xFFCCCCCC),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight:
              (isActive || isDone) ? FontWeight.bold : FontWeight.normal,
          color: isDone
              ? Colors.white
              : isActive
                  ? const Color(0xFF2C2118)
                  : const Color(0xFF888888),
        ),
      ),
    );
  }
}

// ── Optional interface for streaming update progress ─────────────────────────
// Implement this in your concrete LibraryService to support live progress.

abstract interface class _Streamable {
  /// Yields progress events until indexing completes.
  Stream<Map<String, dynamic>> runUpdateIndex();
}
