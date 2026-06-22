// ============================================================
// features/changes/change_tracker.dart — מעקב שינויים
// ============================================================
import 'dart:convert';

enum ChangeType { insert, delete, format, move }

class DocChange {
  final String     changeId;
  final ChangeType type;
  final int        position;
  final int        length;
  final String     oldText;
  final String     newText;
  final String     author;
  final DateTime   timestamp;
  final String     comment;
  bool?            accepted;   // null=ממתין, true=אושר, false=נדחה

  DocChange({
    required this.changeId,
    required this.type,
    required this.position,
    this.length   = 0,
    this.oldText  = '',
    this.newText  = '',
    required this.author,
    DateTime? timestamp,
    this.comment  = '',
    this.accepted,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isPending  => accepted == null;
  bool get isAccepted => accepted == true;
  bool get isRejected => accepted == false;

  String get statusText => switch(accepted) {
    null  => 'ממתין',
    true  => 'אושר',
    false => 'נדחה',
  };

  String get description => switch (type) {
    ChangeType.insert => 'הוספה: "${newText.length > 30 ? "${newText.substring(0,30)}…" : newText}"',
    ChangeType.delete => 'מחיקה: "${oldText.length > 30 ? "${oldText.substring(0,30)}…" : oldText}"',
    ChangeType.format => 'עיצוב (מיקום $position)',
    ChangeType.move   => 'העברה (מיקום $position)',
  };

  Map<String, dynamic> toJson() => {
    'changeId': changeId, 'type': type.name,
    'position': position, 'length': length,
    'oldText': oldText, 'newText': newText,
    'author': author,
    'timestamp': timestamp.toIso8601String(),
    'comment': comment, 'accepted': accepted,
  };

  factory DocChange.fromJson(Map<String, dynamic> j) => DocChange(
    changeId:  j['changeId'],
    type:      ChangeType.values.byName(j['type']),
    position:  j['position'],
    length:    j['length'] ?? 0,
    oldText:   j['oldText'] ?? '',
    newText:   j['newText'] ?? '',
    author:    j['author'] ?? 'לא ידוע',
    timestamp: DateTime.parse(j['timestamp']),
    comment:   j['comment'] ?? '',
    accepted:  j['accepted'],
  );
}

class ChangeTracker {
  final Map<String, DocChange> _changes = {};
  int    _counter = 0;
  String author   = 'עורך';
  bool   enabled  = true;

  // ── רישום ─────────────────────────────────────────────────

  DocChange? record(ChangeType type, int position, {
    int    length   = 0,
    String oldText  = '',
    String newText  = '',
    String comment  = '',
  }) {
    if (!enabled) return null;
    final id = 'chg_${++_counter}';
    final ch = DocChange(
      changeId: id, type: type, position: position,
      length: length, oldText: oldText, newText: newText,
      author: author, comment: comment,
    );
    _changes[id] = ch;
    return ch;
  }

  DocChange? recordInsert(int pos, String text, {String comment = ''}) =>
      record(ChangeType.insert, pos, newText: text, comment: comment);

  DocChange? recordDelete(int pos, String text, {String comment = ''}) =>
      record(ChangeType.delete, pos, length: text.length,
             oldText: text, comment: comment);

  DocChange? recordFormat(int pos, int length, {String comment = ''}) =>
      record(ChangeType.format, pos, length: length, comment: comment);

  // ── אישור / דחייה ─────────────────────────────────────────

  bool accept(String id)    { final c = _changes[id]; if (c == null) return false; c.accepted = true;  return true; }
  bool reject(String id)    { final c = _changes[id]; if (c == null) return false; c.accepted = false; return true; }
  int  acceptAll()          => _pending.where((c) => accept(c.changeId)).length;
  int  rejectAll()          => _pending.where((c) => reject(c.changeId)).length;

  // ── שאילתות ───────────────────────────────────────────────

  DocChange? get_(String id) => _changes[id];
  List<DocChange> get _pending  => _changes.values.where((c) => c.isPending).toList();
  List<DocChange> getPending()  => _pending;
  List<DocChange> getAccepted() => _changes.values.where((c) => c.isAccepted).toList();
  List<DocChange> getAll()      =>
      _changes.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  int get pendingCount          => _pending.length;

  // ── יישום ─────────────────────────────────────────────────

  (String, int) applyAccepted(String text) {
    final accepted = getAccepted()
      ..sort((a, b) => b.position.compareTo(a.position)); // הפוך
    var result = text;
    var count  = 0;
    for (final ch in accepted) {
      if (ch.type == ChangeType.insert) {
        final p = ch.position.clamp(0, result.length);
        result = result.substring(0, p) + ch.newText + result.substring(p);
        count++;
      } else if (ch.type == ChangeType.delete) {
        final p = ch.position.clamp(0, result.length);
        final e = (p + ch.length).clamp(0, result.length);
        if (result.substring(p, e) == ch.oldText) {
          result = result.substring(0, p) + result.substring(e);
          count++;
        }
      }
    }
    return (result, count);
  }

  // ── ייצוא / ייבוא ─────────────────────────────────────────

  String exportDiff() => jsonEncode({
    'author': author,
    'exported': DateTime.now().toIso8601String(),
    'changes': getAll().map((c) => c.toJson()).toList(),
  });

  int importDiff(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      var count = 0;
      for (final d in (data['changes'] as List)) {
        final ch = DocChange.fromJson(d as Map<String, dynamic>);
        if (!_changes.containsKey(ch.changeId)) {
          _changes[ch.changeId] = ch;
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  void clear() { _changes.clear(); _counter = 0; }
}
