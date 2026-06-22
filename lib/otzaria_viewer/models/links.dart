import 'dart:isolate';
import 'package:torah_library/otzaria_viewer/utils/text_manipulation.dart' as utils;
/// ממשק גלובלי לחיבור מסד הנתונים שלך לשאילתות טקסט של קישורים ומפרשים
abstract class OtzariaDatabaseConnector {
  static Future<String> Function(int segmentId)? getSegmentContentCallback;

  static Future<String> getSegmentContent(int segmentId) async {
    if (getSegmentContentCallback != null) {
      return await getSegmentContentCallback!(segmentId);
    }
    return "";
  }
}
class Link {
  final String heRef;
  final int index1;
  final String path2; // כותרת ספר היעד
  final int index2;
  final String connectionType;
  final int? targetSegmentId; // מקושר ל-target_segment_id מ-detailed_links
  Link({
    required this.heRef,
    required this.index1,
    required this.path2,
    required this.index2,
    required this.connectionType,
    this.targetSegmentId,
  });
  Future<String> get content async {
    if (targetSegmentId != null) {
      return await OtzariaDatabaseConnector.getSegmentContent(targetSegmentId!);
    }
    return "";
  }
}
Future<List<Link>> getLinksforIndexs({
  required List<int> indexes,
  required List<Link> links,
  required List<String> commentatorsToShow,
}) async {
  List<Link> doneLinks = links;
  List<Link> allLinks = [];
  allLinks = await Isolate.run(() {
    for (int i = 0; i < indexes.length; i++) {
      List<Link> thisLinks = doneLinks
          .where((link) =>
              link.index1 == indexes[i] &&
              (link.connectionType == "commentary" ||
                  link.connectionType == "targum") &&
              commentatorsToShow.contains(utils.getTitleFromPath(link.path2)))
          .toList();
      allLinks += thisLinks;
    }
    allLinks.sort((a, b) {
      return a.heRef
          .replaceAll(' טו,', ' ,יה')
          .replaceAll(' טז,', ' יו,')
          .compareTo(
              b.heRef.replaceAll(' טו,', ' ,יה').replaceAll(' טז,', ' יו,'));
    });
    allLinks.sort((a, b) {
      return commentatorsToShow
          .indexOf(utils.getTitleFromPath(a.path2))
          .compareTo(
              commentatorsToShow.indexOf(utils.getTitleFromPath(b.path2)));
    });
    return allLinks;
  });
  return allLinks;
}
