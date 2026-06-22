// ============================================================
// state/providers.dart — ספקי Riverpod מרכזיים
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/engines/text_engine.dart';
import '../core/engines/page_calculator.dart';
import '../core/engines/link_manager.dart';
import '../features/search/search_engine.dart';
import '../features/cross_reference/cross_reference_manager.dart';
import '../features/bibliography/bibliography_engine.dart';
import '../features/layout/layout_balancer.dart';
import '../features/changes/change_tracker.dart';
import 'document_notifier.dart';
import 'editor_notifier.dart';

// ── מנועי ליבה (singleton per scope) ─────────────────────────

final textEngineProvider = Provider<TextEngine>((ref) => TextEngine());

final pageCalculatorProvider = Provider<PageCalculator>((ref) {
  final docState = ref.watch(documentNotifierProvider);
  return PageCalculator(settings: docState.document.pageSettings);
});

final linkManagerProvider = Provider<LinkManager>((ref) => LinkManager());

final searchEngineProvider = Provider<SearchEngine>((ref) => SearchEngine());

// ── תכונות ────────────────────────────────────────────────────

final crossRefProvider =
    Provider<CrossReferenceManager>((ref) => CrossReferenceManager());

final bibliographyProvider =
    Provider<BibliographyEngine>((ref) => BibliographyEngine());

final layoutBalancerProvider =
    Provider<LayoutBalancer>((ref) => LayoutBalancer());

final changeTrackerProvider =
    Provider<ChangeTracker>((ref) => ChangeTracker());

// ── State Notifiers ───────────────────────────────────────────

final documentNotifierProvider =
    NotifierProvider<DocumentNotifier, DocumentState>(DocumentNotifier.new);

final editorNotifierProvider =
    NotifierProvider<EditorNotifier, EditorState>(EditorNotifier.new);

// ── תצוגה ─────────────────────────────────────────────────────

final currentPageProvider = StateProvider<int>((ref) => 1);

final zoomProvider = StateProvider<double>((ref) => 1.0);

final showMarginsProvider = StateProvider<bool>((ref) => true);

final showGridProvider = StateProvider<bool>((ref) => false);

/// ספקי חישוב עמודים (מחושב מחדש לפי תוכן)
final pagesProvider = Provider<List<PageLayout>>((ref) {
  final engine     = ref.watch(textEngineProvider);
  final calculator = ref.watch(pageCalculatorProvider);
  return calculator.distributeToPages(engine.getAll());
});

final totalPagesProvider = Provider<int>((ref) {
  return ref.watch(pagesProvider).length;
});
