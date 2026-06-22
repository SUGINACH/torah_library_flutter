import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/text_book_repository.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_state.dart';
import 'package:torah_library/otzaria_viewer/models/books.dart';
import 'package:torah_library/otzaria_viewer/tabs/models/tab.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
class TextBookTab extends OpenedTab {
  final TextBook book;
  int index;
  final String searchText;
  late final TextBookBloc bloc;
  List<String>? commentators;
  TextBookTab({
    required this.book,
    required this.index,
    required TextBookRepository repository,
    this.searchText = '',
    this.commentators,
    bool openLeftPane = false,
    bool splitedView = true,
  }) : super(book.title) {
    bloc = TextBookBloc(
      repository: repository,
      initialState: TextBookInitial(
        book,
        index,
        openLeftPane,
        commentators ?? [],
        searchText,
      ),
    );
  }
  factory TextBookTab.fromJson(Map<String, dynamic> json, TextBookRepository repository) {
    final bool shouldOpenLeftPane =
        (Settings.getValue<bool>('key-pin-sidebar') ?? false) ||
            (Settings.getValue<bool>('key-default-sidebar-open') ?? false);
    return TextBookTab(
      index: json['initalIndex'],
      book: TextBook(
        id: json['id'] as int,
        title: json['title'],
      ),
      repository: repository,
      commentators: List<String>.from(json['commentators']),
      splitedView: json['splitedView'],
      openLeftPane: shouldOpenLeftPane,
    );
  }
  @override
  Map<String, dynamic> toJson() {
    List<String> commentators = [];
    bool splitedView = false;
    int index = 0;
    if (bloc.state is TextBookLoaded) {
      final loadedState = bloc.state as TextBookLoaded;
      commentators = loadedState.activeCommentators;
      splitedView = loadedState.showSplitView;
      index = loadedState.visibleIndices.first;
    }
    return {
      'title': title,
      'id': book.id,
      'initalIndex': index,
      'commentators': commentators,
      'splitedView': splitedView,
      'type': 'TextBookTab'
    };
  }
}
