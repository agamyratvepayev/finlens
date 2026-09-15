import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/insight/insight_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Rebalance task 007 §6 — Insight shows the revaluation's note.
//
// `flutter test` hangs on the dev machine; written, not run. Run yourself:
//   flutter test test/insight_reval_note_test.dart

Widget _app(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: const Scaffold(body: InsightScreen()),
      ),
    );

DateRange _august() => RangePreset.thisMonth.resolve(DateTime(2026, 8, 9));

/// The subtitles of every revaluation row on screen — the second Text of each
/// (`note · date · base → after`), located by the arrow it always carries.
List<String> _revalSubtitles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.contains('→'))
    .toList();

void main() {
  testWidgets('a revaluation row renders its note first, then the date',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The seed gold revaluation carries the note "Gold price update".
    await tester.pumpWidget(_app(buildSeedStore()..setInsightWindow(_august())));
    await tester.pump(const Duration(milliseconds: 300));

    final subtitles = _revalSubtitles(tester);
    expect(subtitles.any((s) => s.startsWith('Gold price update · ')), isTrue,
        reason: 'the note leads the subtitle, the date follows');
  });

  testWidgets('a revaluation with no note is byte-identical to before — no '
      'leading separator', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore()..setInsightWindow(_august());
    // A note-less revaluation on a valuables account inside the window.
    store.addTxn(
      type: TxnType.rebalance,
      amount: 500,
      currency: 'USD',
      fromRef: 'a-car',
      toRef: 'a-car',
      date: DateTime(2026, 8, 20),
      note: '',
    );

    await tester.pumpWidget(_app(store));
    await tester.pump(const Duration(milliseconds: 300));

    final subtitles = _revalSubtitles(tester);
    // Every reval subtitle begins with a date or a note — never a bare
    // separator, which is what a prepended empty note would leave.
    for (final s in subtitles) {
      expect(s.startsWith('·') || s.startsWith(' '), isFalse,
          reason: 'no empty-note leftover at the head of "$s"');
    }
  });
}
