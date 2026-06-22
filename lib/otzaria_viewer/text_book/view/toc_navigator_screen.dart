import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_state.dart';
import 'package:torah_library/otzaria_viewer/models/books.dart';
import 'package:torah_library/otzaria_viewer/utils/ref_helper.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/scheduler.dart';

class TocViewer extends StatefulWidget {
  const TocViewer({
    super.key,
    required this.scrollController,
    required this.closeLeftPaneCallback,
    required this.focusNode,
  });

  final void Function() closeLeftPaneCallback;
  final ItemScrollController scrollController;
  final FocusNode focusNode;

  @override
  State<TocViewer> createState() => _TocViewerState();
}

class _TocViewerState extends State<TocViewer>
    with AutomaticKeepAliveClientMixin<TocViewer> {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController searchController = TextEditingController();
  final ScrollController _tocScrollController = ScrollController();
  final Map<int, GlobalKey> _tocItemKeys = {};
  bool _isManuallyScrolling = false;
  int? _lastScrolledTocIndex;

  @override
  void dispose() {
    _tocScrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _scrollToActiveItem(TextBookLoaded state) {
    if (_isManuallyScrolling) return;
    final int? activeIndex = state.selectedIndex ??
        (state.visibleIndices.isNotEmpty
            ? _closestTocEntryIndex(state.tableOfContents, state.visibleIndices.first)
            : null);
    if (activeIndex == null || activeIndex == _lastScrolledTocIndex) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isManuallyScrolling) return;
      final key = _tocItemKeys[activeIndex];
      final itemContext = key?.currentContext;
      if (itemContext == null) return;
      final itemRenderObject = itemContext.findRenderObject();
      if (itemRenderObject is! RenderBox) return;
      try {
        final scrollableBox = _tocScrollController
            .position.context.storageContext
            .findRenderObject() as RenderBox;
        final itemOffset = itemRenderObject
            .localToGlobal(Offset.zero, ancestor: scrollableBox)
            .dy;
        final viewportHeight = scrollableBox.size.height;
        final itemHeight = itemRenderObject.size.height;
        final target = _tocScrollController.offset +
            itemOffset -
            (viewportHeight / 2) +
            (itemHeight / 2);
        _tocScrollController.animateTo(
          target.clamp(0.0, _tocScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } catch (_) {}
      _lastScrolledTocIndex = activeIndex;
    });
  }

  int? _closestTocEntryIndex(List<TocEntry> toc, int index) {
    TocEntry? closest;
    for (final entry in toc) {
      if (entry.index <= index) {
        closest = entry;
      } else {
        break;
      }
    }
    return closest?.index;
  }

  Widget _buildFilteredList(List<TocEntry> entries) {
    final List<TocEntry> allEntries = [];
    void collect(List<TocEntry> list) {
      for (final e in list) {
        allEntries.add(e);
        collect(e.children);
      }
    }
    collect(entries);
    final filtered = allEntries
        .where((e) => e.text.contains(searchController.text))
        .toList();

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final entry = filtered[i];
        return Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 10 * entry.level.toDouble(), 0),
          child: ListTile(
            title: Text(entry.fullText),
            dense: true,
            onTap: () {
              setState(() {
                _isManuallyScrolling = false;
                _lastScrolledTocIndex = null;
              });
              widget.scrollController.scrollTo(
                index: entry.index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.ease,
              );
              widget.closeLeftPaneCallback();
            },
          ),
        );
      },
    );
  }

  Widget _buildTocItem(TocEntry entry, {bool showFullText = false}) {
    final itemKey = _tocItemKeys.putIfAbsent(entry.index, () => GlobalKey());

    void navigateToEntry() {
      setState(() {
        _isManuallyScrolling = false;
        _lastScrolledTocIndex = null;
      });
      widget.scrollController.scrollTo(
        index: entry.index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
      );
    }

    if (entry.children.isEmpty) {
      return Padding(
        key: itemKey,
        padding: EdgeInsets.fromLTRB(0, 0, 10 * entry.level.toDouble(), 0),
        child: BlocBuilder<TextBookBloc, TextBookState>(
          builder: (context, state) {
            final int? autoIndex = state is TextBookLoaded &&
                    state.selectedIndex == null &&
                    state.visibleIndices.isNotEmpty
                ? _closestTocEntryIndex(
                    state.tableOfContents, state.visibleIndices.first)
                : null;
            final bool selected = state is TextBookLoaded &&
                ((state.selectedIndex != null &&
                        state.selectedIndex == entry.index) ||
                    autoIndex == entry.index);
            return ListTile(
              title: Text(entry.text),
              dense: true,
              selected: selected,
              onTap: navigateToEntry,
            );
          },
        ),
      );
    } else {
      return Padding(
        key: itemKey,
        padding: EdgeInsets.fromLTRB(0, 0, 10 * entry.level.toDouble(), 0),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: entry.level == 1,
            title: BlocBuilder<TextBookBloc, TextBookState>(
              builder: (context, state) {
                final int? autoIndex = state is TextBookLoaded &&
                        state.selectedIndex == null &&
                        state.visibleIndices.isNotEmpty
                    ? _closestTocEntryIndex(
                        state.tableOfContents, state.visibleIndices.first)
                    : null;
                final bool selected = state is TextBookLoaded &&
                    ((state.selectedIndex != null &&
                            state.selectedIndex == entry.index) ||
                        autoIndex == entry.index);
                return ListTile(
                  title: Text(showFullText ? entry.fullText : entry.text),
                  dense: true,
                  selected: selected,
                  onTap: navigateToEntry,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
            leading: const Icon(Icons.chevron_right_rounded, size: 18),
            trailing: const SizedBox.shrink(),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entry.children.length,
                itemBuilder: (context, i) =>
                    _buildTocItem(entry.children[i]),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocListener<TextBookBloc, TextBookState>(
      listenWhen: (previous, current) {
        if (current is! TextBookLoaded) return false;
        if (previous is! TextBookLoaded) return true;
        final prevVis = previous.visibleIndices.isNotEmpty
            ? previous.visibleIndices.first
            : -1;
        final currVis = current.visibleIndices.isNotEmpty
            ? current.visibleIndices.first
            : -1;
        return previous.selectedIndex != current.selectedIndex ||
            prevVis != currVis;
      },
      listener: (context, state) {
        if (state is TextBookLoaded) _scrollToActiveItem(state);
      },
      child: BlocBuilder<TextBookBloc, TextBookState>(
        builder: (context, state) {
          if (state is! TextBookLoaded) return const Center();
          return Column(
            children: [
              TextField(
                controller: searchController,
                focusNode: widget.focusNode,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'איתור כותרת...',
                  hintStyle: const TextStyle(fontSize: 13),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () =>
                        setState(() => searchController.clear()),
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollStartNotification &&
                        n.dragDetails != null) {
                      setState(() => _isManuallyScrolling = true);
                    } else if (n is ScrollEndNotification) {
                      setState(() => _isManuallyScrolling = false);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _tocScrollController,
                    child: searchController.text.isEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.tableOfContents.length,
                            itemBuilder: (context, i) =>
                                _buildTocItem(state.tableOfContents[i]),
                          )
                        : _buildFilteredList(state.tableOfContents),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
