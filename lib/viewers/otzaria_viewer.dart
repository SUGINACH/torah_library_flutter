import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/library_db_service.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/combined_view/combined_book_screen.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_bloc.dart';
import 'package:torah_library/otzaria_viewer/text_book/bloc/text_book_state.dart';
import 'package:torah_library/otzaria_viewer/text_book/view/text_book_screen.dart';
import 'package:torah_library/otzaria_viewer/text_book/text_book_repository.dart';
import 'package:torah_library/otzaria_viewer/repository/sqlite3_database_interface.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_bloc.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_repository.dart';
import 'package:torah_library/otzaria_viewer/tabs/models/text_tab.dart';
import 'package:torah_library/otzaria_viewer/models/books.dart';
import 'package:torah_library/otzaria_viewer/models/links.dart';

class OtzariaViewer extends StatefulWidget {
  final int bookId;
  final String path;
  final int initialLine;
  final String highlight;
  final void Function(void Function(int line, String snippet))? onJumpReady;
  final void Function(int bookId, String path, String title, int line)? onOpenBook;

  const OtzariaViewer({
    super.key,
    required this.bookId,
    required this.path,
    this.initialLine = 0,
    this.highlight = '',
    this.onJumpReady,
    this.onOpenBook,
  });

  @override
  State<OtzariaViewer> createState() => _OtzariaViewerState();
}

class _OtzariaViewerState extends State<OtzariaViewer> {
  bool _loading = true;
  String? _loadError;
  List<String> _data = [];
  late TextBookRepository _repository;
  late TextBookBloc _textBookBloc;
  late SettingsBloc _settingsBloc;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final svc = context.read<LibraryService>();
      final dbService = svc as LibraryDbService;
      final sqlitePath = dbService.otzariaDbPath;
      
      OtzariaDatabaseConnector.getSegmentContentCallback = (int segmentId) async {
        final seg = await dbService.getSegment(segmentId);
        return seg['content'] as String;
      };
      
      final segs = await svc.getOtzariaBook(widget.bookId);
      final strings = segs.map((e) => (e['content'] as String?) ?? '').toList();

      if (!mounted) return;

      _repository = TextBookRepository(
        db: Sqlite3DatabaseInterface(dbPath: sqlitePath),
      );
      
      _textBookBloc = TextBookBloc(
        repository: _repository,
        initialState: TextBookInitial(
          TextBook(id: widget.bookId, title: widget.path),
          widget.initialLine,
          false,
          const [],
        ),
      );
      
      _settingsBloc = SettingsBloc(repository: SettingsRepository());

      setState(() {
        _data = strings;
        _loading = false;
      });
      
      // Tell main window how to jump
      widget.onJumpReady?.call((line, snippet) {
        final state = _textBookBloc.state;
        if (state is TextBookLoaded) {
          state.scrollController.scrollTo(
            index: line,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textBookBloc.close();
    _settingsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) return Center(child: Text('Error: $_loadError'));

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _textBookBloc),
        BlocProvider.value(value: _settingsBloc),
      ],
      child: TextBookScreen(
        tab: TextBookTab(
          book: TextBook(id: widget.bookId, title: widget.path),
          index: widget.initialLine,
          repository: _repository,
        ),
        openBookCallback: (title, index) async {
          if (widget.onOpenBook != null) {
            final svc = context.read<LibraryService>();
            final bookId = await svc.getBookIdByPath(title);
            if (bookId != null) {
              widget.onOpenBook!(bookId, title, title, index);
            }
          }
        },
      ),
    );
  }
}
