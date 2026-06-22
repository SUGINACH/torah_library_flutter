// ============================================================
// features/search/search_engine.dart — מנוע חיפוש והחלפה
// ============================================================
import '../../utils/hebrew_utils.dart';

enum SearchMode { normal, regex, wildcard }

class SearchOptions {
  final bool caseSensitive;
  final bool wholeWords;
  final bool ignoreNikud;
  final bool ignoreTeamim;
  final bool ignoreSpaces;
  final SearchMode mode;

  const SearchOptions({
    this.caseSensitive = false,
    this.wholeWords    = false,
    this.ignoreNikud   = true,
    this.ignoreTeamim  = true,
    this.ignoreSpaces  = false,
    this.mode          = SearchMode.normal,
  });
}

class SearchResult {
  final int    position;
  final int    length;
  final String text;
  final int    lineNumber;
  final String contextBefore;
  final String contextAfter;

  const SearchResult({
    required this.position,
    required this.length,
    required this.text,
    this.lineNumber     = 0,
    this.contextBefore  = '',
    this.contextAfter   = '',
  });

  int get endPosition => position + length;

  String getContext({int ctxLen = 30}) {
    final b = contextBefore.length > ctxLen
        ? contextBefore.substring(contextBefore.length - ctxLen)
        : contextBefore;
    final a = contextAfter.length > ctxLen
        ? contextAfter.substring(0, ctxLen)
        : contextAfter;
    return '$b[$text]$a';
  }
}

class SearchEngine {
  List<SearchResult> _results = [];
  int _currentIndex = -1;
  final List<String> _searchHistory  = [];
  final List<String> _replaceHistory = [];
  static const int _maxHistory = 20;

  // ── חיפוש ─────────────────────────────────────────────────

  List<SearchResult> search(String text, String term, SearchOptions opts) {
    _addHistory(term, isReplace: false);
    _results  = [];
    _currentIndex = -1;

    final prepText = _preprocess(text, opts);
    final prepTerm = _preprocess(term, opts);

    switch (opts.mode) {
      case SearchMode.regex:
        _searchRegex(prepText, prepTerm, text, opts);
      case SearchMode.wildcard:
        _searchWildcard(prepText, prepTerm, text, opts);
      case SearchMode.normal:
        _searchNormal(prepText, prepTerm, text, opts);
    }

    if (_results.isNotEmpty) _currentIndex = 0;
    return List.unmodifiable(_results);
  }

  String _preprocess(String text, SearchOptions opts) {
    var t = text;
    if (opts.ignoreNikud)  t = HebrewUtils.removeNikud(t);
    if (opts.ignoreTeamim) t = HebrewUtils.removeTeamim(t);
    if (opts.ignoreSpaces) t = t.replaceAll(RegExp(r'\s+'), ' ');
    if (!opts.caseSensitive) t = t.toLowerCase();
    return t;
  }

  void _searchNormal(String prepText, String prepTerm,
      String origText, SearchOptions opts) {
    var start = 0;
    while (true) {
      final pos = prepText.indexOf(prepTerm, start);
      if (pos < 0) break;
      if (!opts.wholeWords || _isWholeWord(prepText, pos, prepTerm.length)) {
        _addResult(origText, pos, prepTerm.length);
      }
      start = pos + 1;
    }
  }

  void _searchRegex(String prepText, String pattern,
      String origText, SearchOptions opts) {
    try {
      final rx = RegExp(pattern,
          caseSensitive: opts.caseSensitive, unicode: true);
      for (final m in rx.allMatches(prepText)) {
        _addResult(origText, m.start, m.end - m.start);
      }
    } catch (_) {}
  }

  void _searchWildcard(String prepText, String prep,
      String origText, SearchOptions opts) {
    // * = כל תווים, ? = תו אחד
    final pattern = RegExp.escape(prep)
        .replaceAll(r'\*', '.*')
        .replaceAll(r'\?', '.');
    _searchRegex(prepText, pattern, origText, opts);
  }

  bool _isWholeWord(String text, int pos, int len) {
    final before = pos == 0 || !RegExp(r'\w').hasMatch(text[pos - 1]);
    final after  = pos + len >= text.length
        || !RegExp(r'\w').hasMatch(text[pos + len]);
    return before && after;
  }

  void _addResult(String orig, int pos, int len) {
    const ctx = 50;
    _results.add(SearchResult(
      position: pos, length: len,
      text: orig.substring(pos, (pos + len).clamp(0, orig.length)),
      lineNumber: orig.substring(0, pos).split('\n').length,
      contextBefore: orig.substring((pos - ctx).clamp(0, pos), pos),
      contextAfter:  orig.substring(
          pos + len, (pos + len + ctx).clamp(0, orig.length)),
    ));
  }

  // ── החלפה ─────────────────────────────────────────────────

  (String, int) replace(String text, String term, String replacement,
      {required bool replaceAll, SearchOptions? opts}) {
    if (_results.isEmpty && opts != null) search(text, term, opts);
    if (_results.isEmpty) return (text, 0);

    _addHistory(replacement, isReplace: true);
    var result = text;
    var count  = 0;

    if (replaceAll) {
      var offset = 0;
      for (final r in _results) {
        final p = r.position + offset;
        result = result.substring(0, p) + replacement
            + result.substring(p + r.length);
        offset += replacement.length - r.length;
        count++;
      }
    } else if (_currentIndex >= 0 && _currentIndex < _results.length) {
      final r = _results[_currentIndex];
      result = result.substring(0, r.position) + replacement
          + result.substring(r.position + r.length);
      count = 1;
    }
    return (result, count);
  }

  // ── ניווט ─────────────────────────────────────────────────

  SearchResult? next() {
    if (_results.isEmpty) return null;
    _currentIndex = (_currentIndex + 1) % _results.length;
    return _results[_currentIndex];
  }

  SearchResult? prev() {
    if (_results.isEmpty) return null;
    _currentIndex = (_currentIndex - 1 + _results.length) % _results.length;
    return _results[_currentIndex];
  }

  SearchResult? get current =>
      (_currentIndex >= 0 && _currentIndex < _results.length)
          ? _results[_currentIndex] : null;

  List<SearchResult> get allResults => List.unmodifiable(_results);
  void clearResults() { _results = []; _currentIndex = -1; }

  // ── היסטוריה ──────────────────────────────────────────────

  void _addHistory(String term, {required bool isReplace}) {
    final list = isReplace ? _replaceHistory : _searchHistory;
    list.remove(term);
    list.insert(0, term);
    if (list.length > _maxHistory) list.removeLast();
  }

  List<String> get searchHistory  => List.unmodifiable(_searchHistory);
  List<String> get replaceHistory => List.unmodifiable(_replaceHistory);
}
