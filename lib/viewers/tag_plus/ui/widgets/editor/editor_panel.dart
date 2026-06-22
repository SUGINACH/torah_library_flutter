// ============================================================
// ui/widgets/editor/editor_panel.dart — פאנל עורך מלא
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/providers.dart';
import '../../../state/editor_notifier.dart';
import '../../../config/theme_config.dart';
import '../../../config/app_constants.dart';

class EditorPanel extends ConsumerStatefulWidget {
  const EditorPanel({super.key});
  @override
  ConsumerState<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends ConsumerState<EditorPanel> {
  final _ctrl       = TextEditingController();
  final _focusNode  = FocusNode();
  bool  _syncing    = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    // טעינת תוכן ראשוני
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final docText = ref.read(documentNotifierProvider).document.content;
      if (_ctrl.text != docText) {
        _syncing = true;
        _ctrl.text = docText;
        _syncing = false;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_syncing) return;
    final text = _ctrl.text;
    ref.read(editorNotifierProvider.notifier).updateText(text);
    ref.read(documentNotifierProvider.notifier).updateContent(text);
    // סנכרון מנוע טקסט
    final engine = ref.read(textEngineProvider);
    engine.loadFromTagged(text);
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorNotifierProvider);

    // סנכרון מבחוץ (למשל אחרי פתיחת קובץ)
    final docText = ref.watch(
        documentNotifierProvider.select((s) => s.document.content));
    if (_ctrl.text != docText && !_focusNode.hasFocus) {
      _syncing = true;
      _ctrl.value = _ctrl.value.copyWith(
        text: docText,
        selection: TextSelection.collapsed(offset: docText.length),
      );
      _syncing = false;
    }

    return Column(children: [
      // ── סרגל כלים ─────────────────────────────────────────
      _FormatToolbar(editorState: editorState),

      // ── עורך ──────────────────────────────────────────────
      Expanded(
        child: Container(
          color: TagPlusColors.background,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: _ctrl,
                focusNode:  _focusNode,
                maxLines:   null,
                expands:    true,
                readOnly:   editorState.isReadOnly,
                textDirection: TextDirection.rtl,
                textAlign:  TextAlign.right,
                style: TextStyle(
                  fontFamily: editorState.format.fontFamily,
                  fontSize:   editorState.format.fontSize,
                  fontWeight: editorState.format.bold
                      ? FontWeight.bold : FontWeight.normal,
                  fontStyle: editorState.format.italic
                      ? FontStyle.italic : FontStyle.normal,
                  decoration: editorState.format.underline
                      ? TextDecoration.underline : TextDecoration.none,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'הקלד כאן את הטקסט…',
                  hintTextDirection: TextDirection.rtl,
                  hintStyle: TextStyle(color: TagPlusColors.textHint),
                ),
                onChanged: (_) {},
                onTap: () {
                  final pos  = _ctrl.selection.baseOffset;
                  final before = pos > 0 ? _ctrl.text.substring(0, pos) : '';
                  final line   = before.split('\n').length;
                  final col    = before.split('\n').last.length + 1;
                  ref.read(editorNotifierProvider.notifier)
                      .updateCursor(line, col);
                },
              ),
            ),
          ),
        ),
      ),

      // ── שורת מצב ──────────────────────────────────────────
      _EditorStatusBar(state: editorState),
    ]);
  }
}

// ── סרגל עיצוב ───────────────────────────────────────────────

class _FormatToolbar extends ConsumerWidget {
  final EditorState editorState;
  const _FormatToolbar({required this.editorState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(editorNotifierProvider.notifier);
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: TagPlusColors.toolbarBg,
        border: Border(bottom: BorderSide(color: TagPlusColors.toolbarBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        // גופן
        SizedBox(
          width: 130,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: editorState.format.fontFamily,
              isDense: true,
              items: const ['David','FrankRuehl','Noto Sans Hebrew','Arial']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (f) => notifier.setFontFamily(f!),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 64,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: editorState.format.fontSize,
              isDense: true,
              items: [8,9,10,11,12,14,16,18,20,24,28,32,36,48,72]
                  .map((s) => DropdownMenuItem(
                        value: s.toDouble(),
                        child: Text('$s', style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (s) => notifier.setFontSize(s!),
            ),
          ),
        ),
        const VerticalDivider(indent: 6, endIndent: 6),
        // B / I / U
        _FmtBtn(label: 'B', tooltip: 'מודגש (Ctrl+B)',
            active: editorState.format.bold,
            bold: true,
            onTap: () => notifier.setBold(!editorState.format.bold)),
        _FmtBtn(label: 'I', tooltip: 'נטוי (Ctrl+I)',
            active: editorState.format.italic,
            italic: true,
            onTap: () => notifier.setItalic(!editorState.format.italic)),
        _FmtBtn(label: 'U', tooltip: 'קו תחתון (Ctrl+U)',
            active: editorState.format.underline,
            underline: true,
            onTap: () => notifier.setUnderline(!editorState.format.underline)),
        const VerticalDivider(indent: 6, endIndent: 6),
        // ניקוד/טעמים
        _ActionBtn(label: 'הסר ניקוד',  onTap: () => _removeNikud(ref)),
        const SizedBox(width: 4),
        _ActionBtn(label: 'הסר טעמים', onTap: () => _removeTeamim(ref)),
      ]),
    );
  }

  void _removeNikud(WidgetRef ref) {
    final doc = ref.read(documentNotifierProvider);
    final clean = doc.document.content
        .split('')
        .where((ch) {
          final c = ch.codeUnitAt(0);
          return !(c >= 0x05B0 && c <= 0x05BD);
        })
        .join();
    ref.read(documentNotifierProvider.notifier).updateContent(clean);
  }

  void _removeTeamim(WidgetRef ref) {
    final doc = ref.read(documentNotifierProvider);
    final clean = doc.document.content
        .split('')
        .where((ch) {
          final c = ch.codeUnitAt(0);
          return !(c >= 0x0591 && c <= 0x05AF);
        })
        .join();
    ref.read(documentNotifierProvider.notifier).updateContent(clean);
  }
}

class _FmtBtn extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool active, bold, italic, underline;
  final VoidCallback onTap;
  const _FmtBtn({required this.label, required this.tooltip,
      required this.active, required this.onTap,
      this.bold=false, this.italic=false, this.underline=false});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 30, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? TagPlusColors.primary.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? TagPlusColors.primary : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle:  italic ? FontStyle.italic : FontStyle.normal,
          decoration: underline ? TextDecoration.underline : null,
          color: active ? TagPlusColors.primary : TagPlusColors.textPrimary,
        )),
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12),
    ),
    child: Text(label),
  );
}

// ── שורת מצב עורך ─────────────────────────────────────────────

class _EditorStatusBar extends StatelessWidget {
  final EditorState state;
  const _EditorStatusBar({required this.state});

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    color: TagPlusColors.backgroundLight,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(children: [
      Text('שורה: ${state.cursorLine}, עמודה: ${state.cursorCol}',
          style: const TextStyle(fontSize: 11,
              color: TagPlusColors.textSecondary)),
      const Spacer(),
      Text('מילים: ${state.wordCount}',
          style: const TextStyle(fontSize: 11,
              color: TagPlusColors.textSecondary)),
      const SizedBox(width: 16),
      Text('תווים: ${state.charCount}',
          style: const TextStyle(fontSize: 11,
              color: TagPlusColors.textSecondary)),
    ]),
  );
}
