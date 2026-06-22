// ============================================================
// state/editor_notifier.dart — מצב עורך הטקסט
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/hebrew_utils.dart';
import '../config/text_config.dart';

class FormatState {
  final String  fontFamily;
  final double  fontSize;
  final bool    bold;
  final bool    italic;
  final bool    underline;
  final TagTextAlignment alignment;

  const FormatState({
    this.fontFamily = 'David',
    this.fontSize   = 12,
    this.bold       = false,
    this.italic     = false,
    this.underline  = false,
    this.alignment  = TagTextAlignment.justify,
  });

  FormatState copyWith({
    String? fontFamily, double? fontSize,
    bool? bold, bool? italic, bool? underline,
    TagTextAlignment? alignment,
  }) => FormatState(
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize:   fontSize   ?? this.fontSize,
    bold:       bold       ?? this.bold,
    italic:     italic     ?? this.italic,
    underline:  underline  ?? this.underline,
    alignment:  alignment  ?? this.alignment,
  );
}

class EditorState {
  final String      text;
  final int         cursorLine;
  final int         cursorCol;
  final int         wordCount;
  final int         charCount;
  final FormatState format;
  final bool        showLineNumbers;
  final bool        isReadOnly;
  final String?     searchHighlightTerm;

  const EditorState({
    this.text                = '',
    this.cursorLine          = 1,
    this.cursorCol           = 1,
    this.wordCount           = 0,
    this.charCount           = 0,
    this.format              = const FormatState(),
    this.showLineNumbers     = false,
    this.isReadOnly          = false,
    this.searchHighlightTerm,
  });

  EditorState copyWith({
    String? text, int? cursorLine, int? cursorCol,
    int? wordCount, int? charCount, FormatState? format,
    bool? showLineNumbers, bool? isReadOnly,
    String? searchHighlightTerm,
  }) => EditorState(
    text:                text ?? this.text,
    cursorLine:          cursorLine ?? this.cursorLine,
    cursorCol:           cursorCol  ?? this.cursorCol,
    wordCount:           wordCount  ?? this.wordCount,
    charCount:           charCount  ?? this.charCount,
    format:              format     ?? this.format,
    showLineNumbers:     showLineNumbers ?? this.showLineNumbers,
    isReadOnly:          isReadOnly      ?? this.isReadOnly,
    searchHighlightTerm: searchHighlightTerm,
  );
}

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  void updateText(String text) {
    final words = HebrewUtils.countWords(text);
    state = state.copyWith(
        text: text, wordCount: words, charCount: text.length);
  }

  void updateCursor(int line, int col) =>
      state = state.copyWith(cursorLine: line, cursorCol: col);

  void updateFormat(FormatState fmt) =>
      state = state.copyWith(format: fmt);

  void setBold(bool v)         => state = state.copyWith(format: state.format.copyWith(bold: v));
  void setItalic(bool v)       => state = state.copyWith(format: state.format.copyWith(italic: v));
  void setUnderline(bool v)    => state = state.copyWith(format: state.format.copyWith(underline: v));
  void setFontFamily(String f) => state = state.copyWith(format: state.format.copyWith(fontFamily: f));
  void setFontSize(double s)   => state = state.copyWith(format: state.format.copyWith(fontSize: s));
  void toggleLineNumbers()     => state = state.copyWith(showLineNumbers: !state.showLineNumbers);
  void setReadOnly(bool v)     => state = state.copyWith(isReadOnly: v);
  void setSearchHighlight(String? term) =>
      state = state.copyWith(searchHighlightTerm: term);
}