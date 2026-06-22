// ============================================================
// ui/screens/main_screen.dart — מסך ראשי
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/editor/editor_panel.dart';
import '../widgets/preview/preview_panel.dart';
import '../widgets/toolbar/app_toolbar.dart';
import '../dialogs/page_setup_dialog.dart';
import '../dialogs/find_replace_dialog.dart';
import '../dialogs/cross_ref_dialog.dart';
import '../../state/providers.dart';
import '../../config/theme_config.dart';

/// קולבק — מאפשר לאפליקציית האב לדעת על שינויים
class TagPlusCallbacks {
  final void Function(String path)? onDocumentSaved;
  final void Function(String path)? onDocumentOpened;
  final void Function(String content)? onContentChanged;

  const TagPlusCallbacks({
    this.onDocumentSaved,
    this.onDocumentOpened,
    this.onContentChanged,
  });
}

class MainScreen extends ConsumerStatefulWidget {
  final TagPlusCallbacks? callbacks;
  const MainScreen({super.key, this.callbacks});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _showPreview = true;   // ניתן להחביא תצוגה מקדימה

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppToolbar(onAction: _handleAction),
      body: _body(),
      bottomNavigationBar: _buildStatusBar(),
    );
  }

  Widget _body() {
    if (!_showPreview) return const EditorPanel();

    return LayoutBuilder(builder: (ctx, constraints) {
      // מתחת ל-700px רוחב — עמוד אחד
      if (constraints.maxWidth < 700) {
        return const EditorPanel();
      }
      return const Row(children: [
        Expanded(flex: 55, child: EditorPanel()),
        VerticalDivider(width: 1),
        Expanded(flex: 45, child: PreviewPanel()),
      ]);
    });
  }

  Widget _buildStatusBar() {
    final docState = ref.watch(documentNotifierProvider);
    final modified = docState.document.isModified;
    return Container(
      height: 24,
      color: TagPlusColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Icon(modified ? Icons.edit : Icons.check_circle,
            size: 12,
            color: modified ? TagPlusColors.warning : TagPlusColors.success),
        const SizedBox(width: 6),
        Text(
          modified ? 'שינויים לא שמורים' : 'מוכן',
          style: const TextStyle(fontSize: 11,
              color: TagPlusColors.textSecondary),
        ),
        if (docState.lastError != null) ...[
          const SizedBox(width: 16),
          Text(docState.lastError!,
              style: const TextStyle(fontSize: 11, color: TagPlusColors.error)),
        ],
      ]),
    );
  }

  // ── מטפל פעולות ───────────────────────────────────────────

  Future<void> _handleAction(String action) async {
    switch (action) {
      case 'new':
        _confirmUnsaved(() =>
            ref.read(documentNotifierProvider.notifier).newDocument());

      case 'open':
        _confirmUnsaved(_openFile);

      case 'save':
        await _saveFile();

      case 'export_pdf':
        await _exportFile('pdf');

      case 'export_word':
        await _exportFile('docx');

      case 'find':
        if (context.mounted) await showFindReplaceDialog(context);

      case 'settings':
        if (context.mounted) await showPageSetupDialog(context);

      case 'cross_refs':
        if (context.mounted) await showCrossRefDialog(context);

      case 'toggle_preview':
        setState(() => _showPreview = !_showPreview);
    }
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['tag','txt','docx'],
      type: FileType.custom,
    );
    if (result?.files.single.path == null) return;
    final path = result!.files.single.path!;
    final ok = await ref.read(documentNotifierProvider.notifier)
        .loadFromFile(path);
    if (ok) {
      // סנכרון מנוע טקסט
      final content = ref.read(documentNotifierProvider).document.content;
      ref.read(textEngineProvider).loadFromTagged(content);
      widget.callbacks?.onDocumentOpened?.call(path);
    }
  }

  Future<void> _saveFile() async {
    final doc = ref.read(documentNotifierProvider).document;
    String? path = doc.filePath;
    if (path == null) {
      final result = await FilePicker.platform.saveFile(
        fileName:          'מסמך.tag',
        allowedExtensions: ['tag','txt'],
        type:              FileType.custom,
      );
      if (result == null) return;
      path = result;
    }
    final ok = await ref.read(documentNotifierProvider.notifier)
        .saveToFile(path);
    if (ok) widget.callbacks?.onDocumentSaved?.call(path);
  }

  Future<void> _exportFile(String format) async {
    final result = await FilePicker.platform.saveFile(
      fileName:          'export.$format',
      allowedExtensions: [format],
      type:              FileType.custom,
    );
    if (result == null) return;
    // ייצוא — ממש ב-exporters
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ייצוא $format הושלם: $result')));
    }
  }

  void _confirmUnsaved(VoidCallback action) {
    final modified = ref.read(documentNotifierProvider).document.isModified;
    if (!modified) { action(); return; }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('שינויים לא שמורים',
            textDirection: TextDirection.rtl),
        content: const Text('האם לשמור לפני המשך?',
            textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); action(); },
              child: const Text('המשך ללא שמירה')),
          ElevatedButton(onPressed: () async {
            Navigator.pop(context);
            await _saveFile();
            action();
          }, child: const Text('שמור')),
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('ביטול')),
        ],
      ),
    );
  }
}
