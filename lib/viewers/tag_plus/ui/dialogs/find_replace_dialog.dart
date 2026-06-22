// ============================================================
// ui/dialogs/find_replace_dialog.dart — חיפוש והחלפה
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/search/search_engine.dart';
import '../../state/providers.dart';
import '../../config/theme_config.dart';

Future<void> showFindReplaceDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _FindReplaceDialog(),
  );
}

class _FindReplaceDialog extends ConsumerStatefulWidget {
  const _FindReplaceDialog();
  @override
  ConsumerState<_FindReplaceDialog> createState() => _FindReplaceState();
}

class _FindReplaceState extends ConsumerState<_FindReplaceDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _findCtrl    = TextEditingController();
  final _replaceCtrl = TextEditingController();
  bool _caseSensitive= false;
  bool _wholeWords   = false;
  bool _ignoreNikud  = true;
  bool _ignoreTeamim = true;
  SearchMode _mode   = SearchMode.normal;
  int  _resultCount  = 0;
  String _status     = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    super.dispose();
  }

  SearchOptions get _opts => SearchOptions(
    caseSensitive: _caseSensitive, wholeWords: _wholeWords,
    ignoreNikud:  _ignoreNikud,  ignoreTeamim: _ignoreTeamim, mode: _mode,
  );

  void _doSearch() {
    final engine  = ref.read(searchEngineProvider);
    final docState= ref.read(documentNotifierProvider);
    final results = engine.search(docState.document.content,
        _findCtrl.text, _opts);
    setState(() {
      _resultCount = results.length;
      _status = results.isEmpty ? 'לא נמצאו תוצאות'
          : 'נמצאו $results.length תוצאות';
    });
  }

  void _doReplaceAll() {
    if (_findCtrl.text.isEmpty) return;
    final engine = ref.read(searchEngineProvider);
    final doc    = ref.read(documentNotifierProvider).document;
    final (newText, count) = engine.replace(
        doc.content, _findCtrl.text, _replaceCtrl.text,
        replaceAll: true, opts: _opts);
    ref.read(documentNotifierProvider.notifier).updateContent(newText);
    setState(() => _status = 'הוחלפו $count מופעים');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('חיפוש והחלפה', textDirection: TextDirection.rtl),
    content: SizedBox(
      width: 480, height: 380,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(children: [
          TabBar(controller: _tabs,
              tabs: const [Tab(text: 'חיפוש'), Tab(text: 'מתקדם')]),
          const SizedBox(height: 8),
          Expanded(child: TabBarView(controller: _tabs, children: [
            // טאב בסיסי
            _BasicTab(
              findCtrl: _findCtrl, replaceCtrl: _replaceCtrl,
              caseSensitive: _caseSensitive, wholeWords: _wholeWords,
              ignoreNikud: _ignoreNikud, ignoreTeamim: _ignoreTeamim,
              onCaseChanged:   (v) => setState(() => _caseSensitive = v),
              onWordsChanged:  (v) => setState(() => _wholeWords    = v),
              onNikudChanged:  (v) => setState(() => _ignoreNikud   = v),
              onTeamimChanged: (v) => setState(() => _ignoreTeamim  = v),
            ),
            // טאב מתקדם
            _AdvancedTab(
              mode: _mode,
              onModeChanged: (m) => setState(() => _mode = m),
            ),
          ])),
          // תוצאות
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(_status,
                  style: TextStyle(
                    color: _resultCount > 0
                        ? TagPlusColors.success : TagPlusColors.textSecondary,
                    fontSize: 12)),
            ),
        ]),
      ),
    ),
    actions: [
      TextButton(onPressed: _doSearch,      child: const Text('מצא הבא')),
      TextButton(onPressed: _doReplaceAll,  child: const Text('החלף הכל')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('סגור')),
    ],
  );
}

class _BasicTab extends StatelessWidget {
  final TextEditingController findCtrl, replaceCtrl;
  final bool caseSensitive, wholeWords, ignoreNikud, ignoreTeamim;
  final ValueChanged<bool> onCaseChanged, onWordsChanged,
      onNikudChanged, onTeamimChanged;

  const _BasicTab({
    required this.findCtrl, required this.replaceCtrl,
    required this.caseSensitive, required this.wholeWords,
    required this.ignoreNikud, required this.ignoreTeamim,
    required this.onCaseChanged, required this.onWordsChanged,
    required this.onNikudChanged, required this.onTeamimChanged,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(4),
    children: [
      TextField(controller: findCtrl,
          decoration: const InputDecoration(labelText: 'חפש',
              isDense: true, border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: replaceCtrl,
          decoration: const InputDecoration(labelText: 'החלף ב',
              isDense: true, border: OutlineInputBorder())),
      const SizedBox(height: 10),
      CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('התאמת רישיות', style: TextStyle(fontSize: 13)),
          value: caseSensitive, onChanged: (v) => onCaseChanged(v!)),
      CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('מילים שלמות',  style: TextStyle(fontSize: 13)),
          value: wholeWords,    onChanged: (v) => onWordsChanged(v!)),
      CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('התעלם מניקוד', style: TextStyle(fontSize: 13)),
          value: ignoreNikud,   onChanged: (v) => onNikudChanged(v!)),
      CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('התעלם מטעמים',style: TextStyle(fontSize: 13)),
          value: ignoreTeamim,  onChanged: (v) => onTeamimChanged(v!)),
    ],
  );
}

class _AdvancedTab extends StatelessWidget {
  final SearchMode mode;
  final ValueChanged<SearchMode> onModeChanged;
  const _AdvancedTab({required this.mode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(4),
    children: [
      const Text('מצב חיפוש:', style: TextStyle(fontWeight: FontWeight.w500)),
      RadioListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('רגיל',    style: TextStyle(fontSize: 13)),
          value: SearchMode.normal,   groupValue: mode, onChanged: (v) => onModeChanged(v!)),
      RadioListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('Regex',   style: TextStyle(fontSize: 13)),
          value: SearchMode.regex,    groupValue: mode, onChanged: (v) => onModeChanged(v!)),
      RadioListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('Wildcard (* ?)', style: TextStyle(fontSize: 13)),
          value: SearchMode.wildcard, groupValue: mode, onChanged: (v) => onModeChanged(v!)),
      const Divider(),
      const Text('תווים מיוחדים בWildcard:\n  *  = כל תווים\n  ?  = תו אחד',
          style: TextStyle(fontSize: 11, color: TagPlusColors.textSecondary)),
    ],
  );
}
