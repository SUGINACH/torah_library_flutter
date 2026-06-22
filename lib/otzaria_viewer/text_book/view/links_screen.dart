import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_state.dart';
import 'package:torah_library/otzaria_viewer/models/links.dart';
import 'package:torah_library/otzaria_viewer/utils/text_manipulation.dart' as utils;
// הוספנו את הייבוא הבא:
import 'package:torah_library/otzaria_viewer/text_book/view/combined_view/commentary_content.dart';

/// כרטיסיית "קישורים" בסיידבר.
class LinksViewer extends StatefulWidget {
  const LinksViewer({
    super.key,
    required this.openBookCallback,
    required this.itemPositionsListener,
    required this.closeLeftPanelCallback,
  });

  final void Function(String title, int index) openBookCallback;
  final ItemPositionsListener itemPositionsListener;
  final VoidCallback closeLeftPanelCallback;

  static List<Link> getLinks(TextBookLoaded state) {
    final links = state.links
        .where((link) =>
            link.index1 == state.visibleIndices.first &&
            link.connectionType != 'commentary')
        .toList();
    links.sort(
      (a, b) => a.path2
          .split(Platform.pathSeparator)
          .last
          .compareTo(b.path2.split(Platform.pathSeparator).last),
    );
    return links;
  }

  @override
  State<LinksViewer> createState() => _LinksViewerState();
}

class _LinksViewerState extends State<LinksViewer>
    with AutomaticKeepAliveClientMixin<LinksViewer> {
  @override
  bool get wantKeepAlive => false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<TextBookBloc, TextBookState>(
      builder: (context, state) {
        if (state is TextBookError) {
          return Center(child: Text('שגיאה: ${state.message}'));
        }
        if (state is! TextBookLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final links = LinksViewer.getLinks(state);
        if (links.isEmpty) {
          return const Center(child: Text('אין קישורים לפסקה זו'));
        }

        return ListView.builder(
          itemCount: links.length,
          itemBuilder: (context, i) {
            final link = links[i];
            return ExpansionTile(
              title: Text(
                link.heRef,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: CommentaryContent(
                    link: link,
                    fontSize: state.fontSize,
                    // קליק כפול על הטקסט יפתח את הספר ויסגור את הסיידבר
                    openBookCallback: (title, index) {
                      widget.openBookCallback(title, index);
                      widget.closeLeftPanelCallback();
                    },
                    removeNikud: state.removeNikud,
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }
}