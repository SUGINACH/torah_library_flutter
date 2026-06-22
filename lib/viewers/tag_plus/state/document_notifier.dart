// ============================================================
// state/document_notifier.dart — ניהול מצב מסמך
// ============================================================
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/document.dart';
import '../utils/file_utils.dart';

class DocumentState {
  final TagDocument       document;
  final List<String>      recentFiles;
  final String?           lastError;
  final bool              isSaving;

  const DocumentState({
    required this.document,
    this.recentFiles = const [],
    this.lastError,
    this.isSaving    = false,
  });

  DocumentState copyWith({
    TagDocument? document,
    List<String>? recentFiles,
    String? lastError,
    bool? isSaving,
  }) => DocumentState(
    document:    document    ?? this.document,
    recentFiles: recentFiles ?? this.recentFiles,
    lastError:   lastError,
    isSaving:    isSaving ?? this.isSaving,
  );
}

class DocumentNotifier extends Notifier<DocumentState> {
  @override
  DocumentState build() => DocumentState(document: TagDocument.empty());

  // ── פעולות מסמך ───────────────────────────────────────────

  void newDocument() {
    state = state.copyWith(document: TagDocument.empty());
  }

  void updateContent(String content) {
    state = state.copyWith(
      document: state.document.copyWith(
        content:    content,
        isModified: true,
        modifiedAt: DateTime.now(),
      ),
    );
  }

  void updatePageSettings(PageSettings settings) {
    state = state.copyWith(
      document: state.document.copyWith(pageSettings: settings),
    );
  }

  void updateMetadata(DocumentMetadata meta) {
    state = state.copyWith(
      document: state.document.copyWith(metadata: meta),
    );
  }

  void markSaved(String? filePath) {
    state = state.copyWith(
      document: state.document.copyWith(
        filePath:   filePath ?? state.document.filePath,
        isModified: false,
        modifiedAt: DateTime.now(),
      ),
    );
    if (filePath != null) _addRecentFile(filePath);
  }

  // ── שמירה ─────────────────────────────────────────────────

  Future<bool> saveToFile(String path) async {
    state = state.copyWith(isSaving: true);
    try {
      final data = {
        'version': '2.0',
        'document': state.document.toJson(),
      };
      final ok = await FileUtils.writeText(
          path, jsonEncode(data));
      if (ok) markSaved(path);
      state = state.copyWith(isSaving: false, lastError: ok ? null : 'שגיאת שמירה');
      return ok;
    } catch (e) {
      state = state.copyWith(isSaving: false, lastError: e.toString());
      return false;
    }
  }

  Future<bool> saveAsText(String path) async {
    return FileUtils.writeText(path, state.document.content);
  }

  // ── טעינה ─────────────────────────────────────────────────

  Future<bool> loadFromFile(String path) async {
    try {
      final raw = await FileUtils.readText(path);
      if (raw == null) {
        state = state.copyWith(lastError: 'לא ניתן לקרוא קובץ');
        return false;
      }
      final ext = FileUtils.getExtension(path).toLowerCase();
      TagDocument doc;
      if (ext == '.tag' || ext == '.json') {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        doc = TagDocument.fromJson(
            data['document'] as Map<String, dynamic>? ?? data);
        doc = doc.copyWith(filePath: path);
      } else {
        // טקסט פשוט
        doc = TagDocument.empty().copyWith(content: raw, filePath: path);
      }
      state = state.copyWith(document: doc, lastError: null);
      _addRecentFile(path);
      return true;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return false;
    }
  }

  // ── קבצים אחרונים ─────────────────────────────────────────

  void _addRecentFile(String path) {
    final list = [path, ...state.recentFiles.where((f) => f != path)]
        .take(10)
        .toList();
    state = state.copyWith(recentFiles: list);
  }

  void clearError() => state = state.copyWith(lastError: null);
}
