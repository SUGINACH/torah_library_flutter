import 'package:torah_library/otzaria_viewer/models/books.dart';

Future<String> refFromIndex(int index, Future<List<TocEntry>> tocFuture) async {
  final toc = await tocFuture;
  if (toc.isEmpty) return '';
  TocEntry? closest;
  for (var entry in toc) {
    if (entry.index <= index) {
      closest = entry;
    } else {
      break;
    }
  }
  return closest?.text ?? '';
}
