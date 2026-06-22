import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:torah_library/otzaria_viewer/models/books.dart';
import 'package:torah_library/otzaria_viewer/models/links.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_bloc.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_state.dart';
import 'package:torah_library/otzaria_viewer/tabs/models/text_tab.dart';
import 'package:torah_library/otzaria_viewer/utils/text_manipulation.dart' as utils;
class CommentaryContent extends StatefulWidget {
  const CommentaryContent({
    super.key,
    required this.link,
    required this.fontSize,
    required this.openBookCallback,
    required this.removeNikud,
    this.searchQuery = '',
  });
  final bool removeNikud;
  final Link link;
  final double fontSize;
  final Function(String title, int index) openBookCallback;
  final String searchQuery;
  @override
  State<CommentaryContent> createState() => _CommentaryContentState();
}
class _CommentaryContentState extends State<CommentaryContent> {
  late Future<String> content;
  @override
  void initState() {
    super.initState();
    content = widget.link.content;
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () {
        widget.openBookCallback(
          utils.getTitleFromPath(widget.link.path2),
          widget.link.index2 - 1,
        );
      },
      child: FutureBuilder(
          future: content,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              String text = snapshot.data!;
              if (widget.removeNikud) {
                text = utils.removeVolwels(text);
              }
              text = utils.highLight(text, widget.searchQuery);              
              return BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, settingsState) {
                  return Html(data: text, style: {
                    'body': Style(
                        fontSize: FontSize(widget.fontSize / 1.2),
                        fontFamily: settingsState.fontFamily,
                        textAlign: TextAlign.justify),
                  });
                },
              );
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          }),
    );
  }
}
