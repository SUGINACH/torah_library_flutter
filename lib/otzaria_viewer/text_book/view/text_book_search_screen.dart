import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_event.dart';
import 'package:torah_library/otzaria_viewer/text_book/models/text_book_searcher.dart';
import 'package:torah_library/otzaria_viewer/text_book/models/search_results.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_state.dart';

class TextBookSearchView extends StatefulWidget {
  const TextBookSearchView({
    super.key,
    required this.data,
    required this.scrollController,
    required this.focusNode,
    required this.closeLeftPaneCallback,
    this.initialQuery = '',
  });

  final String data;
  final ItemScrollController scrollController;
  final FocusNode focusNode;
  final VoidCallback closeLeftPaneCallback;
  final String initialQuery;

  @override
  State<TextBookSearchView> createState() => _TextBookSearchViewState();
}

class _TextBookSearchViewState extends State<TextBookSearchView>
    with AutomaticKeepAliveClientMixin<TextBookSearchView> {
  @override
  bool get wantKeepAlive => true;

  late final TextEditingController _ctrl;
  late final TextBookSearcher _searcher;
  List<TextSearchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _searcher = TextBookSearcher(widget.data)
      ..addListener(_onResults);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.focusNode.requestFocus();
      if (_ctrl.text.isNotEmpty) _searcher.startTextSearch(_ctrl.text);
    });
  }

  @override
  void dispose() {
    _searcher
      ..removeListener(_onResults)
      ..dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onResults() {
    if (mounted) setState(() => _results = _searcher.searchResults);
  }

  void _onChanged(String q) {
    context.read<TextBookBloc>().add(UpdateSearchText(q));
    _searcher.startTextSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        TextField(
          controller: _ctrl,
          focusNode: widget.focusNode,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          onChanged: _onChanged,
          onSubmitted: (_) => widget.focusNode.requestFocus(),
          decoration: InputDecoration(
            hintText: 'חפש כאן...',
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                _ctrl.clear();
                _onChanged('');
                widget.focusNode.requestFocus();
              },
            ),
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
        if (_results.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'נמצאו ${_results.length} תוצאות',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          ),
        Expanded(
          child: _results.isEmpty && _ctrl.text.isNotEmpty
              ? const Center(child: Text('אין תוצאות'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        r.address,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        r.snippet,
                        textDirection: TextDirection.rtl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        widget.scrollController.scrollTo(
                          index: r.index,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.ease,
                        );
                        widget.closeLeftPaneCallback();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
