import 'dart:io';

String stripHtmlIfNeeded(String text) {
  return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');
}

String removeVolwels(String text) {
  return text.replaceAll(RegExp(r'[\u0591-\u05C7]'), '');
}

String removeTeamim(String text) {
  return text.replaceAll(RegExp(r'[\u0591-\u05AF]'), '');
}

String highLight(String text, String query) {
  if (query.isEmpty) return text;
  return text.replaceAll(query, '<mark>$query</mark>');
}

String getTitleFromPath(String path) {
  return path.split(Platform.pathSeparator).last.replaceAll('.txt', '');
}

String replaceHolyNames(String text) {
  return text.replaceAll('יהוה', 'ה\'').replaceAll('יְהֹוָה', 'ה\'');
}

Future<Map<String, List<String>>> splitByEra(List<String> commentators) async {
  return {
    'ראשונים': commentators,
    'אחרונים': <String>[],
    'מחברי זמננו': <String>[],
  };
}

Future<bool> hasTopic(String title, String topic) async {
  return true;
}
