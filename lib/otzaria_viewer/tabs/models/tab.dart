import 'package:torah_library/otzaria_viewer/tabs/models/text_tab.dart';

abstract class OpenedTab {
  String title;
  OpenedTab(this.title);
  
  void dispose() {}
  
  factory OpenedTab.from(OpenedTab tab) {
    if (tab is TextBookTab) {
      return TextBookTab(
        index: tab.index,
        book: tab.book,
        repository: tab.bloc.repository, // need to access repo from somewhere or assume it
        searchText: tab.searchText,
        commentators: tab.commentators,
      );
    }
    return tab;
  }
  
  Map<String, dynamic> toJson();
}
