
abstract class Book {
  final int id; // מזהה ייחודי של הספר במסד הנתונים
  final String title;
  final List<String>? extraTitles;
  String? author;
  String? heShortDesc;
  String? pubDate;
  String? pubPlace;
  int order;
  String topics;
  Book({
    required this.id,
    required this.title,
    this.author,
    this.heShortDesc,
    this.pubDate,
    this.pubPlace,
    this.order = 999,
    this.topics = '',
    this.extraTitles,
  });
}
class TextBook extends Book {
  TextBook({
    required super.id,
    required super.title,
    super.author,
    super.heShortDesc,
    super.pubDate,
    super.pubPlace,
    super.order = 999,
    super.topics,
    super.extraTitles,
  });
  factory TextBook.fromJson(Map<String, dynamic> json) {
    return TextBook(
      id: json['id'] as int,
      title: json['title'] as String,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': 'TextBook',
    };
  }
}
class TocEntry {
  String text;
  final int index;
  final int level;
  final TocEntry? parent;
  List<TocEntry> children = [];
  String get fullText {
    TocEntry? p = parent;
    String t = text;
    while (p != null && p.level > 1) {
      if (p.text != '') {
        t = '${p.text}, $t';
      }
      p = p.parent;
    }
    return t;
  }
  TocEntry({
    required this.text,
    required this.index,
    this.level = 1,
    this.parent,
  });
}
