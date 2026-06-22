import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_event.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_state.dart';

/// כרטיסיית "פרשנות" בסיידבר — רשימת מפרשים עם צ'קבוקס לכל אחד.
class CommentatorsListView extends StatefulWidget {
  const CommentatorsListView({super.key});

  @override
  State<CommentatorsListView> createState() => _CommentatorsListViewState();
}

class _CommentatorsListViewState extends State<CommentatorsListView> {
  final TextEditingController _searchController = TextEditingController();

  static const String _kRishonim = '__TITLE_RISHONIM__';
  static const String _kAcharonim = '__TITLE_ACHARONIM__';
  static const String _kModern = '__TITLE_MODERN__';
  static const String _kUngrouped = '__TITLE_UNGROUPED__';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _headerLabel(String key) {
    switch (key) {
      case _kRishonim:
        return 'ראשונים';
      case _kAcharonim:
        return 'אחרונים';
      case _kModern:
        return 'מחברי זמננו';
      default:
        return 'שאר מפרשים';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TextBookBloc, TextBookState>(
      builder: (context, state) {
        if (state is! TextBookLoaded) return const Center();
        if (state.availableCommentators.isEmpty) {
          return const Center(child: Text('אין פרשנים'));
        }

        // חישוב הרשימה באופן דינמי לפי החיפוש (ללא setState בתוך הבנייה)
        final q = _searchController.text;
        List<String> filter(List<String> list) =>
            list.where((t) => t.contains(q)).toList();

        final rishonim = filter(state.rishonim);
        final acharonim = filter(state.acharonim);
        final modern = filter(state.modernCommentators);
        final Set<String> listed = {...rishonim, ...acharonim, ...modern};
        final ungrouped = filter(
          state.availableCommentators.where((c) => !listed.contains(c)).toList(),
        );

        final List<String> items = [];
        if (rishonim.isNotEmpty) { items.add(_kRishonim); items.addAll(rishonim); }
        if (acharonim.isNotEmpty) { items.add(_kAcharonim); items.addAll(acharonim); }
        if (modern.isNotEmpty) { items.add(_kModern); items.addAll(modern); }
        if (ungrouped.isNotEmpty) { items.add(_kUngrouped); items.addAll(ungrouped); }

        final allVisible = items.where((e) => !e.startsWith('__TITLE_')).toList();
        final allSelected = allVisible.isNotEmpty && allVisible.every(state.activeCommentators.contains);

        return Column(
          children: [
            // ── שורת חיפוש ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(6),
              child: TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'סינון פרשן...',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (_) => setState(() {}), // מעדכן את המסך בהתאם להקלדה
              ),
            ),
            // ── כפתור בחירת הכל ──────────────────────────────────────────
            if (items.isNotEmpty)
              CheckboxListTile(
                dense: true,
                title: const Text('הצג את כל הפרשנים (המוצגים)',
                    textDirection: TextDirection.rtl),
                value: allSelected,
                onChanged: (checked) {
                  final newActive = List<String>.from(state.activeCommentators);
                  if (checked ?? false) {
                    newActive.addAll(allVisible.where((e) => !newActive.contains(e)));
                  } else {
                    newActive.removeWhere((e) => allVisible.contains(e));
                  }
                  context.read<TextBookBloc>().add(UpdateCommentators(newActive));
                },
              ),
            // ── רשימה ─────────────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  if (item.startsWith('__TITLE_')) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              _headerLabel(item),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.8),
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    );
                  }
                  return CheckboxListTile(
                    dense: true,
                    title: Text(item, textDirection: TextDirection.rtl),
                    value: state.activeCommentators.contains(item),
                    onChanged: (checked) {
                      final current =
                          List<String>.from(state.activeCommentators);
                      if (checked ?? false) {
                        current.add(item);
                      } else {
                        current.remove(item);
                      }
                      context
                          .read<TextBookBloc>()
                          .add(UpdateCommentators(current));
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}