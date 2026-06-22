// ============================================================
// ui/dialogs/cross_ref_dialog.dart — ניהול הפניות פנימיות
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/cross_reference/cross_reference_manager.dart';
import '../../state/providers.dart';

Future<void> showCrossRefDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) => _CrossRefDialog(),
  );
}

class _CrossRefDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CrossRefDialog> createState() => _CrossRefState();
}

class _CrossRefState extends ConsumerState<_CrossRefDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _nameCtrl    = TextEditingController();
  final _posCtrl     = TextEditingController(text: '0');
  final _ctxCtrl     = TextEditingController();
  int    _refType    = 0; // 0=לעיל, 1=לקמן, 2=שם
  String _status     = '';

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }

  @override
  void dispose() { _tabs.dispose(); _nameCtrl.dispose(); _posCtrl.dispose(); _ctxCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mgr = ref.read(crossRefProvider);

    return AlertDialog(
      title: const Text('ניהול הפניות', textDirection: TextDirection.rtl),
      content: SizedBox(
        width: 500, height: 420,
        child: Directionality(textDirection: TextDirection.rtl,
          child: Column(children: [
            TabBar(controller: _tabs, tabs: const [
              Tab(text: 'עוגנים'),
              Tab(text: 'הפניות'),
            ]),
            Expanded(child: TabBarView(controller: _tabs, children: [
              // עוגנים
              _buildAnchors(mgr),
              // הפניות
              _buildRefs(mgr),
            ])),
            if (_status.isNotEmpty)
              Text(_status, style: const TextStyle(fontSize: 11,
                  color: Colors.green)),
          ]),
        ),
      ),
      actions: [
        ElevatedButton(onPressed: () {
          setState(() => _status = 'ההפניות עודכנו בהצלחה');
        }, child: const Text('עדכן הפניות')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('סגור')),
      ],
    );
  }

  Widget _buildAnchors(CrossReferenceManager mgr) {
    final anchors = mgr.getAllAnchors();
    return Column(children: [
      Expanded(child: anchors.isEmpty
        ? const Center(child: Text('אין עוגנים'))
        : ListView.builder(
            itemCount: anchors.length,
            itemBuilder: (_, i) {
              final a = anchors[i];
              return ListTile(dense: true,
                  title: Text(a.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('מיקום ${a.position}  |  עמ\' ${a.pageNumber}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: IconButton(icon: const Icon(Icons.delete, size: 16),
                    onPressed: () { mgr.removeAnchor(a.anchorId); setState((){}); }));
            })),
      const Divider(),
      Row(children: [
        Expanded(child: TextField(controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'שם עוגן', isDense: true, border: OutlineInputBorder()))),
        const SizedBox(width: 6),
        SizedBox(width: 80, child: TextField(controller: _posCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'מיקום', isDense: true, border: OutlineInputBorder()))),
        const SizedBox(width: 6),
        ElevatedButton(onPressed: () {
          if (_nameCtrl.text.trim().isEmpty) return;
          mgr.registerAnchor(name: _nameCtrl.text.trim(),
              position: int.tryParse(_posCtrl.text) ?? 0,
              context: _ctxCtrl.text.trim());
          _nameCtrl.clear();
          setState(() => _status = 'עוגן נוסף');
        }, child: const Text('הוסף')),
      ]),
    ]);
  }

  Widget _buildRefs(CrossReferenceManager mgr) {
    final refs = mgr.getAllRefs();
    final anchors = mgr.getAllAnchors();
    return Column(children: [
      Expanded(child: refs.isEmpty
        ? const Center(child: Text('אין הפניות'))
        : ListView.builder(itemCount: refs.length, itemBuilder: (_, i) {
            final r = refs[i];
            return ListTile(dense: true,
                title: Text('${r.refType}  →  ${r.displayText}',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text('מיקום מקור: ${r.sourcePosition}',
                    style: const TextStyle(fontSize: 11)));
          })),
      if (anchors.isNotEmpty) ...[
        const Divider(),
        Row(children: [
          const Text('סוג:', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          DropdownButton<int>(value: _refType, isDense: true,
              items: const [
                DropdownMenuItem(value: 0, child: Text('לעיל')),
                DropdownMenuItem(value: 1, child: Text('לקמן')),
                DropdownMenuItem(value: 2, child: Text('שם')),
              ],
              onChanged: (v) => setState(() => _refType = v!)),
          const Spacer(),
          ElevatedButton(onPressed: () {
            if (anchors.isEmpty) return;
            mgr.addRef(sourcePos: 0,
                targetAnchorId: anchors.first.anchorId,
                refType: ['לעיל','לקמן','שם'][_refType]);
            setState(() => _status = 'הפניה נוספה');
          }, child: const Text('הוסף הפניה')),
        ]),
      ],
    ]);
  }
}
