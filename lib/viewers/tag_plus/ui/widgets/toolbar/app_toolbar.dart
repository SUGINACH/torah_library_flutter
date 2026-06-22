// ============================================================
// ui/widgets/toolbar/app_toolbar.dart — סרגל כלים ראשי
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../state/providers.dart';

/// סרגל כלים עם TabBar — קובץ / עריכה / עימוד / תצוגה
class AppToolbar extends ConsumerWidget implements PreferredSizeWidget {
  final void Function(String action) onAction;

  const AppToolbar({super.key, required this.onAction});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docState = ref.watch(documentNotifierProvider);
    final title    = docState.document.displayName;
    final modified = docState.document.isModified;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── AppBar ────────────────────────────────────────────
      AppBar(
        centerTitle: false,
        title: Row(children: [
          const FlutterLogo(size: 20),
          const SizedBox(width: 8),
          const Text('תג פלוס',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          Text('— $title${modified ? " •" : ""}',
              style: const TextStyle(fontSize: 13,
                  color: TagPlusColors.textSecondary)),
        ]),
        actions: [
          _AppBarBtn(icon: Icons.add,           tip: 'חדש',         action: 'new',         onAction: onAction),
          _AppBarBtn(icon: Icons.folder_open,   tip: 'פתח',         action: 'open',        onAction: onAction),
          _AppBarBtn(icon: Icons.save,          tip: 'שמור (Ctrl+S)', action: 'save',      onAction: onAction),
          const VerticalDivider(indent: 10, endIndent: 10),
          _AppBarBtn(icon: Icons.picture_as_pdf,tip: 'ייצוא PDF',  action: 'export_pdf',  onAction: onAction),
          _AppBarBtn(icon: Icons.description,   tip: 'ייצוא Word', action: 'export_word', onAction: onAction),
          const VerticalDivider(indent: 10, endIndent: 10),
          _AppBarBtn(icon: Icons.search,        tip: 'חיפוש (Ctrl+F)', action: 'find',    onAction: onAction),
          _AppBarBtn(icon: Icons.settings,      tip: 'הגדרות',     action: 'settings',    onAction: onAction),
          const SizedBox(width: 8),
        ],
      ),
      // ── Ribbon-style tab row ──────────────────────────────
      _RibbonRow(onAction: onAction),
    ]);
  }
}

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final String tip, action;
  final void Function(String) onAction;
  const _AppBarBtn({required this.icon, required this.tip,
      required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 20),
    tooltip: tip,
    onPressed: () => onAction(action),
  );
}

// ── שורת Ribbon ──────────────────────────────────────────────

class _RibbonRow extends StatefulWidget {
  final void Function(String) onAction;
  const _RibbonRow({required this.onAction});
  @override
  State<_RibbonRow> createState() => _RibbonRowState();
}

class _RibbonRowState extends State<_RibbonRow>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: TagPlusColors.toolbarBg,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Divider(height: 1, thickness: 0),
        TabBar(
          controller:      _tc,
          isScrollable:    true,
          tabAlignment:    TabAlignment.start,
          labelStyle:      const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'בית'),
            Tab(text: 'הוספה'),
            Tab(text: 'עימוד'),
            Tab(text: 'תצוגה'),
          ],
        ),
      ]),
    );
  }
}

// ── מקשי קיצור ────────────────────────────────────────────────

class TagPlusKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final void Function(String) onAction;

  const TagPlusKeyboardShortcuts(
      {super.key, required this.child, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        // בסיסי — ניהול מלא יתווסף בהתאם לפלטפורמה
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
