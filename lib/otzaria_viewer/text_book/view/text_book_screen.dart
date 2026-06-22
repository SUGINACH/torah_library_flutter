import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_bloc.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_state.dart';
import 'package:torah_library/otzaria_viewer/tabs/models/text_tab.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_event.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_state.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/combined_view/combined_book_screen.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/commentators_list_screen.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/links_screen.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/text_book_search_screen.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/toc_navigator_screen.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/splited_view/simple_book_view.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/splited_view/commentary_list_for_splited_view.dart';
/// המסך המלא של מציג הספר: סיידבר (ניווט / חיפוש / פרשנות / קישורים)
/// + תוכן ראשי.
///
/// [openBookCallback] — נקראת כאשר המשתמש לוחץ על קישור בכרטיסיית "קישורים"
/// או על מפרש בפרשנות. הפרמטרים: (bookTitle, lineIndex).
/// הלוגיקה של פתיחת הספר (חיפוש bookId וכדומה) מבוצעת על-ידי
/// ה-OtzariaViewer שהעביר את ה-callback.
class TextBookScreen extends StatefulWidget {
  const TextBookScreen({
    super.key,
    required this.tab,
    required this.openBookCallback,
  });

  final TextBookTab tab;

  /// (bookTitle, lineIndex) → פתיחת ספר בצופה / בסיידבר
  final void Function(String title, int index) openBookCallback;

  @override
  State<TextBookScreen> createState() => _TextBookScreenState();
}

class _TextBookScreenState extends State<TextBookScreen>
    with TickerProviderStateMixin {
  final FocusNode _searchFocus     = FocusNode();
  final FocusNode _navFocus        = FocusNode();
  late final TabController _tabs;

  static const int _kNavIdx  = 0;
  static const int _kSrchIdx = 1;
  static const int _kCommIdx = 2;
  static const int _kLinkIdx = 3;

  @override
  void initState() {
    super.initState();
    final startTab = widget.tab.searchText.isNotEmpty ? _kSrchIdx : _kNavIdx;
    _tabs = TabController(length: 4, vsync: this, initialIndex: startTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchFocus.dispose();
    _navFocus.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _openLeftPaneTab(int index) {
    context.read<TextBookBloc>().add(const ToggleLeftPane(true));
    _tabs.animateTo(index);
  }

  void _jumpToLinks() {
    _openLeftPaneTab(_kLinkIdx);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return BlocBuilder<TextBookBloc, TextBookState>(
          builder: (context, state) {
            // ── Trigger initial load ────────────────────────────────────────
            if (state is TextBookInitial) {
              context.read<TextBookBloc>().add(
                    LoadContent(
                      fontSize: settingsState.fontSize,
                      showSplitView:
                          Settings.getValue<bool>('key-splited-view') ?? false,
                      removeNikud: settingsState.defaultRemoveNikud,
                    ),
                  );
            }

            if (state is TextBookInitial || state is TextBookLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is TextBookError) {
              return Center(child: Text('שגיאה: ${state.message}'));
            }
            if (state is! TextBookLoaded) {
              return const Center(child: Text('מצב לא ידוע'));
            }

            return _buildLoaded(context, state, settingsState);
          },
        );
      },
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    TextBookLoaded state,
    SettingsState settings,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return Column(
          children: [
            _buildToolbar(context, state, isWide),
            Expanded(
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  // ── Sidebar ───────────────────────────────────────────────
                  _buildSidebar(context, state),
                  // ── Main text ─────────────────────────────────────────────
                  Expanded(
                    child: _buildTextArea(context, state, settings, isWide),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(
    BuildContext context,
    TextBookLoaded state,
    bool isWide,
  ) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Menu / sidebar toggle
          IconButton(
            icon: const Icon(Icons.menu, size: 20),
            tooltip: 'ניווט וחיפוש',
            padding: EdgeInsets.zero,
            onPressed: () => context
                .read<TextBookBloc>()
                .add(ToggleLeftPane(!state.showLeftPane)),
          ),
          // Title
          Expanded(
            child: state.currentTitle != null
                ? Text(
                    state.currentTitle!,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  )
                : const SizedBox.shrink(),
          ),
          // Nikud toggle
          IconButton(
            icon: const Icon(Icons.format_overline, size: 20),
            tooltip: 'הצג/הסתר ניקוד',
            padding: EdgeInsets.zero,
            onPressed: () => context
                .read<TextBookBloc>()
                .add(ToggleNikud(!state.removeNikud)),
          ),
          // Split-view toggle
          IconButton(
            icon: Icon(
              state.showSplitView
                  ? Icons.horizontal_split_outlined
                  : Icons.vertical_split_outlined,
              size: 20,
            ),
            tooltip: state.showSplitView
                ? 'הצגת מפרשים מתחת'
                : 'הצגת מפרשים בצד',
            padding: EdgeInsets.zero,
            onPressed: () => context
                .read<TextBookBloc>()
                .add(ToggleSplitView(!state.showSplitView)),
          ),
          if (isWide) ...[
            // Zoom out
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 20),
              tooltip: 'הקטנת טקסט',
              padding: EdgeInsets.zero,
              onPressed: () => context.read<TextBookBloc>().add(
                    UpdateFontSize(max(15.0, state.fontSize - 3)),
                  ),
            ),
            // Zoom in
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 20),
              tooltip: 'הגדלת טקסט',
              padding: EdgeInsets.zero,
              onPressed: () => context.read<TextBookBloc>().add(
                    UpdateFontSize(min(60.0, state.fontSize + 3)),
                  ),
            ),
            // First page
            IconButton(
              icon: const Icon(Icons.first_page, size: 20),
              tooltip: 'תחילת הספר',
              padding: EdgeInsets.zero,
              onPressed: () => state.scrollController.scrollTo(
                index: 0,
                duration: const Duration(milliseconds: 300),
              ),
            ),
            // Prev
            IconButton(
              icon: const Icon(Icons.navigate_before, size: 20),
              tooltip: 'קטע קודם',
              padding: EdgeInsets.zero,
              onPressed: () {
                final cur = state
                    .positionsListener.itemPositions.value.first.index;
                state.scrollController.scrollTo(
                  index: max(0, cur - 1),
                  duration: const Duration(milliseconds: 300),
                );
              },
            ),
            // Next
            IconButton(
              icon: const Icon(Icons.navigate_next, size: 20),
              tooltip: 'קטע הבא',
              padding: EdgeInsets.zero,
              onPressed: () {
                final cur = state
                    .positionsListener.itemPositions.value.first.index;
                state.scrollController.scrollTo(
                  index: cur + 1,
                  duration: const Duration(milliseconds: 300),
                );
              },
            ),
            // Last page
            IconButton(
              icon: const Icon(Icons.last_page, size: 20),
              tooltip: 'סוף הספר',
              padding: EdgeInsets.zero,
              onPressed: () => state.scrollController.scrollTo(
                index: state.content.length - 1,
                duration: const Duration(milliseconds: 300),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────

  Widget _buildSidebar(BuildContext context, TextBookLoaded state) {
    // Request focus on visible tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.showLeftPane) {
        if (_tabs.index == _kSrchIdx) _searchFocus.requestFocus();
        if (_tabs.index == _kNavIdx)  _navFocus.requestFocus();
      }
    });

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: SizedBox(
        width: state.showLeftPane ? 360 : 0,
        child: Column(
          children: [
            // Tab headers row
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabs,
                    tabs: const [
                      Tab(text: 'ניווט'),
                      Tab(text: 'חיפוש'),
                      Tab(text: 'פרשנות'),
                      Tab(text: 'קישורים'),
                    ],
                    labelStyle: const TextStyle(fontSize: 12),
                    onTap: (i) {
                      if (i == _kSrchIdx) _searchFocus.requestFocus();
                      if (i == _kNavIdx)  _navFocus.requestFocus();
                    },
                  ),
                ),
                // Pin button
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.push_pin, size: 18),
                  isSelected: state.pinLeftPane ||
                      (Settings.getValue<bool>('key-pin-sidebar') ?? false),
                  onPressed: () => context
                      .read<TextBookBloc>()
                      .add(TogglePinLeftPane(!state.pinLeftPane)),
                ),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  // 0 — ניווט (TOC)
                  TocViewer(
                    scrollController: state.scrollController,
                    focusNode: _navFocus,
                    closeLeftPaneCallback: () => context
                        .read<TextBookBloc>()
                        .add(const ToggleLeftPane(false)),
                  ),
                  // 1 — חיפוש
                  TextBookSearchView(
                    data: state.content.join('\n'),
                    scrollController: state.scrollController,
                    focusNode: _searchFocus,
                    initialQuery: state.searchText,
                    closeLeftPaneCallback: () => context
                        .read<TextBookBloc>()
                        .add(const ToggleLeftPane(false)),
                  ),
                  // 2 — פרשנות
                  const CommentatorsListView(),
                  // 3 — קישורים
                  LinksViewer(
                    openBookCallback: widget.openBookCallback,
                    itemPositionsListener: state.positionsListener,
                    closeLeftPanelCallback: () => context
                        .read<TextBookBloc>()
                        .add(const ToggleLeftPane(false)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Text area ─────────────────────────────────────────────────────────────

  Widget _buildTextArea(
    BuildContext context,
    TextBookLoaded state,
    SettingsState settings,
    bool isWide,
  ) {
    // התיקון: בחירת הווידג'ט הנכון לפי state.showSplitView
    final Widget bookContent = state.showSplitView
        ? Row(
            textDirection: TextDirection.rtl,
            children: [
              // החצי של הספר עצמו
              Expanded(
                flex: 1,
                child: SimpleBookView(
                  data: state.content,
                  textSize: state.fontSize,
                  openBookCallback: widget.openBookCallback,
                  openLeftPaneTab: _openLeftPaneTab,
                  showSplitedView: state.showSplitView,
                  tab: widget.tab,
                ),
              ),
              const VerticalDivider(width: 1, color: Colors.grey),
              // החצי של המפרשים על הפסקה המסומנת/העליונה
              Expanded(
                flex: 1,
                child: CommentaryList(
                  // מציג מפרשים על הפסקה שנבחרה, ואם לא נבחרה - על הפסקה הראשונה שמוצגת
                  index: state.selectedIndex ?? (state.visibleIndices.isNotEmpty ? state.visibleIndices.first : 0),
                  fontSize: state.fontSize,
                  openBookCallback: widget.openBookCallback,
                  showSplitView: state.showSplitView,
                ),
              ),
            ],
          )
        : CombinedView(
            data: state.content,
            textSize: state.fontSize,
            openBookCallback: widget.openBookCallback,
            openLeftPaneTab: _openLeftPaneTab,
            showSplitedView: ValueNotifier(state.showSplitView),
            tab: widget.tab,
          );

    return GestureDetector(
      onScaleUpdate: (details) {
        if (details.scale != 1.0) {
          context.read<TextBookBloc>().add(
                UpdateFontSize(
                    (state.fontSize * details.scale).clamp(15, 60)),
              );
        }
      },
      child: NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          if (!(state.pinLeftPane ||
              (Settings.getValue<bool>('key-pin-sidebar') ?? false))) {
            Future.microtask(() {
              if (mounted) {
                context
                    .read<TextBookBloc>()
                    .add(const ToggleLeftPane(false));
              }
            });
          }
          return false;
        },
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            LogicalKeySet(
              LogicalKeyboardKey.control,
              LogicalKeyboardKey.keyF,
            ): () => _openLeftPaneTab(_kSrchIdx),
          },
          child: Focus(
            autofocus: true,
            child: Padding(
              padding: state.showLeftPane
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(
                      horizontal: isWide ? settings.paddingSize : 0),
              // כאן אנחנו מציגים את התוכן הדינמי שחישבנו למעלה
              child: bookContent,
            ),
          ),
        ),
      ),
    );
  }
}
