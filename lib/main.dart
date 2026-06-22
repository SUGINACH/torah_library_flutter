// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'main_window.dart';
import 'services/library_service.dart';
import 'services/library_db_service.dart'; // ייבוא של קובץ השירות של מסד הנתונים
import 'themes/app_palette.dart';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_bloc.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_repository.dart';
import 'package:torah_library/otzaria_viewer/settings/settings_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.init(cacheProvider: SharePreferenceCache());

  // ── הגדרת מיקום קבצי מסד הנתונים ──
  // החלף את נתיבים אלו בנתיבים האמיתיים שבהם שמורים הקבצים במחשב שלך
  const String searchDbPath = '../backend/search.db'; 
  const String otzariaDbPath = '../backend/otzaria.db';

  // ── Frameless desktop window ──
  await windowManager.ensureInitialized();
  const opts = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1024, 768),
    title: 'הספרייה התורנית',
    titleBarStyle: TitleBarStyle.hidden,
    center: true,
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // ── Load themes.json from assets ──
  Map<String, dynamic> themesJson = {};
  try {
    final raw = await rootBundle.loadString('assets/data/themes.json');
    themesJson = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {}

  runApp(_TorahLibraryApp(
    themesJson: themesJson,
    searchDbPath: searchDbPath,
    otzariaDbPath: otzariaDbPath,
  ));
}

class _TorahLibraryApp extends StatelessWidget {
  final Map<String, dynamic> themesJson;
  final String searchDbPath;
  final String otzariaDbPath;

  const _TorahLibraryApp({
    required this.themesJson,
    required this.searchDbPath,
    required this.otzariaDbPath,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..loadThemesJson(themesJson),
        ),
        Provider<LibraryService>(
          create: (_) => LibraryDbService(
            searchDbPath: searchDbPath,
            otzariaDbPath: otzariaDbPath,
          ),
        ),
        BlocProvider<SettingsBloc>(
          create: (_) => SettingsBloc(repository: SettingsRepository())..add(LoadSettings()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, tp, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'הספרייה התורנית',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: tp.palette.accent,
              surface: tp.palette.background,
            ).copyWith(
              primary: tp.palette.accent,
              surface: tp.palette.background,
            ),
            scaffoldBackgroundColor: tp.palette.background,
            fontFamily: 'Segoe UI',
          ),
          home: const Material(
            child: MainWindow(),
          ),
        ),
      ),
    );
  }
}