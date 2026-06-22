// lib/widgets/document_tabs_bar.dart
// Flutter equivalent of DocumentTabsBar in widgets.py.
//
// Layout (RTL):
//   [🗐 ↔]  [‹]  [scrollable tab strip …]  [+]  [›]
//
// Tabs are right-aligned; the first tab in the list appears on the far right.
// Active tab has a gradient header. Tab type sets the top-border colour.

import 'package:flutter/material.dart';
import '../themes/app_palette.dart';

// ── Colour per tab type (mirrors tabType CSS in themes.py) ──────────────────
const _tabTypeColors = {
  'docx':     Color(0xFF3498db),
  'audio':    Color(0xFF2ecc71),
  'calendar': Color(0xFF9b59b6),
  'otzaria':  Color(0xFFd35400),
  'pdf':      Color(0xFFD9B13E), // accent
};

// ── Public widget ─────────────────────────────────────────────────────────────

class DocumentTabsBar extends StatefulWidget {
  final List<Map<String, dynamic>> tabs;  // [{id, title, authors, path}, ...]
  final String activeTabId;
  final String tabMode;            // 'multiple' | 'single'
  final AppPalette palette;
  final void Function(String) onTabSelected;
  final void Function(String) onTabClosed;
  final VoidCallback onNewTabRequested;
  final VoidCallback onTogglePanel;
  final VoidCallback onToggleTabMode;

  const DocumentTabsBar({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.tabMode,
    required this.palette,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onNewTabRequested,
    required this.onTogglePanel,
    required this.onToggleTabMode,
  });

  @override
  State<DocumentTabsBar> createState() => _DocumentTabsBarState();
}

class _DocumentTabsBarState extends State<DocumentTabsBar> {
  final _scrollCtrl = ScrollController();

  // Scroll to the active tab after a build
  @override
  void didUpdateWidget(DocumentTabsBar old) {
    super.didUpdateWidget(old);
    if (old.activeTabId != widget.activeTabId ||
        old.tabs.length != widget.tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    final idx = widget.tabs.indexWhere((t) => t['id'] == widget.activeTabId);
    if (idx < 0) return;
    final target = idx * 260.0;
    _scrollCtrl.animateTo(
      target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;

    return Container(
      height: 28,
      color: p.panelLight,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _CtrlBtn(
            icon: '🗐',
            tooltip: 'מצב טאב יחיד / מרובה',
            palette: p,
            onTap: widget.onToggleTabMode,
          ),
          _CtrlBtn(
            icon: '↔',
            tooltip: 'הסתר/הצג פאנל',
            palette: p,
            onTap: widget.onTogglePanel,
          ),
          _CtrlBtn(icon: '‹', tooltip: '', palette: p,
            onTap: () => _scrollCtrl.animateTo(
              (_scrollCtrl.offset - 220).clamp(0, double.infinity),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final tab in widget.tabs)
                    _TabItem(
                      tab: tab,
                      isActive: tab['id'] == widget.activeTabId,
                      palette: p,
                      onSelect: () => widget.onTabSelected(tab['id'] as String),
                      onClose:  () => widget.onTabClosed(tab['id'] as String),
                    ),
                ],
              ),
            ),
          ),
          _CtrlBtn(icon: '+', tooltip: 'טאב חדש', palette: p,
              onTap: widget.onNewTabRequested),
          _CtrlBtn(icon: '›', tooltip: '', palette: p,
            onTap: () => _scrollCtrl.animateTo(
              _scrollCtrl.offset + 220,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }
}

// ── Single tab item ────────────────────────────────────────────────────────────

class _TabItem extends StatefulWidget {
  final Map<String, dynamic> tab;
  final bool isActive;
  final AppPalette palette;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.palette,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hovered = false;

  String _tabType() {
    final path = (widget.tab['path'] as String?) ?? '';
    if (path.startsWith('tool://')) return path.replaceFirst('tool://', '');
    if (path.toLowerCase().endsWith('.pdf')) return 'pdf';
    if (path.toLowerCase().endsWith('.txt') ||
        (widget.tab['isOtzaria'] == true)) return 'otzaria';
    return 'default';
  }

  Color _typeColor() =>
      _tabTypeColors[_tabType()] ?? widget.palette.accent;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final active = widget.isActive;

    final title   = (widget.tab['title'] as String?)?.isNotEmpty == true
        ? widget.tab['title'] as String
        : '(ריק)';
    final authors = (widget.tab['authors'] as String?) ?? '';
    final full    = authors.isNotEmpty ? '$title • $authors' : title;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft:  Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 278),
            height: active ? 25 : 22,
            margin: const EdgeInsets.only(left: 2),
            padding: const EdgeInsets.only(right: 10, left: 8),
            decoration: BoxDecoration(
              gradient: active
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [p.headerGold, p.accentLight],
                    )
                  : (_hovered ? LinearGradient(colors: [p.itemHover, p.itemHover]) : null),
              color: active || _hovered ? null : p.panelLight,
              border: Border(
                top:   BorderSide(color: _typeColor(), width: active ? 1 : 1),
                left:  BorderSide(color: p.accent),
                right: BorderSide(color: p.accent),
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Text(
                    full,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onClose,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.transparent),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('×',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
                          )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small control / scroll button ────────────────────────────────────────────

class _CtrlBtn extends StatefulWidget {
  final String icon;
  final String tooltip;
  final AppPalette palette;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_CtrlBtn> createState() => _CtrlBtnState();
}

class _CtrlBtnState extends State<_CtrlBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            color: _hovered ? widget.palette.itemHover : Colors.transparent,
            child: Text(
              widget.icon,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _hovered
                    ? widget.palette.borderColor
                    : widget.palette.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}