// ============================================================
// ui/dialogs/page_setup_dialog.dart — הגדרות עמוד
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/document.dart';
import '../../config/page_config.dart';
import '../../state/providers.dart';

Future<void> showPageSetupDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (_) => const _PageSetupDialog(),
  );
}

class _PageSetupDialog extends ConsumerStatefulWidget {
  const _PageSetupDialog();
  @override
  ConsumerState<_PageSetupDialog> createState() => _PageSetupState();
}

class _PageSetupState extends ConsumerState<_PageSetupDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late PageSettings _settings;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _settings = ref.read(documentNotifierProvider).document.pageSettings;
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('הגדרות עמוד', textDirection: TextDirection.rtl),
    content: SizedBox(
      width: 420, height: 440,
      child: Column(children: [
        TabBar(controller: _tabs, tabs: const [
          Tab(text: 'גודל עמוד'),
          Tab(text: 'שוליים'),
        ]),
        const SizedBox(height: 8),
        Expanded(child: TabBarView(controller: _tabs, children: [
          _SizeTab(settings: _settings, onChanged: (s) => setState(() => _settings = s)),
          _MarginsTab(settings: _settings, onChanged: (s) => setState(() => _settings = s)),
        ])),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
      ElevatedButton(
        onPressed: () {
          ref.read(documentNotifierProvider.notifier)
              .updatePageSettings(_settings);
          Navigator.pop(context);
        },
        child: const Text('אישור'),
      ),
    ],
  );
}

class _SizeTab extends StatefulWidget {
  final PageSettings settings;
  final void Function(PageSettings) onChanged;
  const _SizeTab({required this.settings, required this.onChanged});
  @override State<_SizeTab> createState() => _SizeTabState();
}

class _SizeTabState extends State<_SizeTab> {
  late double _w, _h;

  @override
  void initState() {
    super.initState();
    _w = widget.settings.width;
    _h = widget.settings.height;
  }

  void _applyPreset(String key) {
    final preset = PageSizes.presets[key];
    if (preset != null) {
      setState(() { _w = preset.$1; _h = preset.$2; });
      widget.onChanged(widget.settings.copyWith(width: _w, height: _h));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(padding: const EdgeInsets.all(8), children: [
      const Text('גודל מוגדר מראש:',
          style: TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: PageSizes.presets.keys.map((k) =>
        ActionChip(label: Text(k), onPressed: () => _applyPreset(k)),
      ).toList()),
      const SizedBox(height: 12),
      _NumField(label: 'רוחב (מ"מ)', value: _w, min: 50, max: 500,
          onChanged: (v) { setState(() => _w = v);
            widget.onChanged(widget.settings.copyWith(width: v)); }),
      const SizedBox(height: 8),
      _NumField(label: 'גובה (מ"מ)', value: _h, min: 50, max: 500,
          onChanged: (v) { setState(() => _h = v);
            widget.onChanged(widget.settings.copyWith(height: v)); }),
    ]),
  );
}

class _MarginsTab extends StatefulWidget {
  final PageSettings settings;
  final void Function(PageSettings) onChanged;
  const _MarginsTab({required this.settings, required this.onChanged});
  @override State<_MarginsTab> createState() => _MarginsTabState();
}

class _MarginsTabState extends State<_MarginsTab> {
  late PageSettings _s;
  @override void initState() { super.initState(); _s = widget.settings; }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(padding: const EdgeInsets.all(8), children: [
      _NumField(label: 'עליון (מ"מ)',   value: _s.marginTop,
          onChanged: (v) { setState(() => _s = _s.copyWith(marginTop: v));    widget.onChanged(_s); }),
      _NumField(label: 'תחתון (מ"מ)',  value: _s.marginBottom,
          onChanged: (v) { setState(() => _s = _s.copyWith(marginBottom: v)); widget.onChanged(_s); }),
      _NumField(label: 'ימין (מ"מ)',   value: _s.marginRight,
          onChanged: (v) { setState(() => _s = _s.copyWith(marginRight: v));  widget.onChanged(_s); }),
      _NumField(label: 'שמאל (מ"מ)',  value: _s.marginLeft,
          onChanged: (v) { setState(() => _s = _s.copyWith(marginLeft: v));   widget.onChanged(_s); }),
    ]),
  );
}

// ── שדה מספרי ────────────────────────────────────────────────

class _NumField extends StatelessWidget {
  final String label;
  final double value, min, max;
  final void Function(double) onChanged;
  const _NumField({required this.label, required this.value,
      required this.onChanged, this.min = 0, this.max = 500});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: value.toStringAsFixed(1));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(isDense: true,
              border: OutlineInputBorder()),
          onSubmitted: (v) {
            final d = double.tryParse(v);
            if (d != null) onChanged(d.clamp(min, max));
          },
        )),
      ]),
    );
  }
}
