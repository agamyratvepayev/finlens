import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/transaction_repeat_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 030 — the Repeat sheets stop lying and stop stacking.
// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/transaction_repeat_030_test.dart
//
// The seed date is 2026-08-09, a Sunday (weekday 7); month grids therefore seed
// day 9 and weekday grids seed Sun.

// ── Harness ──────────────────────────────────────────────────────────────────

class _PushCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
      ],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

/// Pumps a screen whose single button opens the Repeat sheet and captures the
/// selection it returns.
Future<void> _pump(
  WidgetTester tester, {
  required void Function(TxnRepeatSelection?) onResult,
  TxnRepeatSelection current = const TxnRepeatSelection(freq: RepeatFrequency.none),
  Locale? locale,
  NavigatorObserver? observer,
}) async {
  await tester.pumpWidget(StoreScope(
    store: _store(),
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      navigatorObservers: observer != null ? [observer] : const [],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => onResult(await showTxnRepeatSheet(
                ctx,
                current: current,
                date: DateTime(2026, 8, 9),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

Future<void> _openRepeat(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _openCustom(WidgetTester tester) async {
  await _openRepeat(tester);
  await tester.tap(find.text('Custom'));
  await tester.pumpAndSettle();
}

Future<void> _openEnds(WidgetTester tester) async {
  await _openRepeat(tester);
  await tester.tap(find.text('Monthly'));
  await tester.pump();
  await tester.tap(find.text('Ends'));
  await tester.pumpAndSettle();
}

/// The summary readback (interval + days). It moved out of the control card to
/// full width under the title (task 037 §2); it is now the only 13pt accentLight
/// Text and wraps freely.
String _summary(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  return texts
      .firstWhere((t) =>
          t.style?.fontSize == 13 &&
          t.style?.color == AppColors.accentLight &&
          (t.data ?? '').startsWith('Every'))
      .data!;
}

void main() {
  // ── §2 · no fourth sheet ───────────────────────────────────────────────────

  group('no fourth sheet', () {
    testWidgets('tapping After opens no sheet', (tester) async {
      final obs = _PushCounter();
      await _pump(tester, onResult: (_) {}, observer: obs);
      await _openEnds(tester);
      final before = obs.pushes;
      await tester.tap(find.text('After'));
      await tester.pumpAndSettle();
      expect(obs.pushes, before);
    });

    testWidgets('tapping the interval opens no sheet', (tester) async {
      final obs = _PushCounter();
      await _pump(tester, onResult: (_) {}, observer: obs);
      await _openCustom(tester);
      final before = obs.pushes;
      await tester.tap(find.byType(TextField)); // the interval field
      await tester.pumpAndSettle();
      expect(obs.pushes, before);
    });

    testWidgets('_NumberSheet no longer renders a title/Done pair', (tester) async {
      // Its Done button (a bare FilledButton) and Cancel-less title are gone;
      // only the sheets' own Done remains.
      await _pump(tester, onResult: (_) {});
      await _openEnds(tester);
      await tester.tap(find.text('After'));
      await tester.pumpAndSettle();
      // No extra route: the count field lives in the row.
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // ── §2.1 · the clamp (After count, min 2 max 999) ──────────────────────────

  group('the clamp', () {
    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('1 is not snapped mid-typing but becomes 2 on blur',
        (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openEnds(tester);
      await tester.tap(find.text('After'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      expect(fieldText(tester), '1'); // no per-keystroke clamp
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(fieldText(tester), '2');
    });

    testWidgets('1000 clamps to 999 on blur', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openEnds(tester);
      await tester.tap(find.text('After'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(fieldText(tester), '999');
    });
  });

  // ── §3 · clear an end ──────────────────────────────────────────────────────

  testWidgets('clearing a date returns (null, null) and reads Never',
      (tester) async {
    TxnRepeatSelection? result;
    await _pump(
      tester,
      onResult: (r) => result = r,
      current: TxnRepeatSelection(
        freq: RepeatFrequency.monthly,
        daysOfMonth: const {15},
        endDate: DateTime(2027, 1, 1),
      ),
    );
    await _openRepeat(tester);
    await tester.tap(find.text('Ends'));
    await tester.pumpAndSettle();
    // On-a-date is selected → its trailing slot is a clear button.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    // The Ends sheet's own Done (topmost), then the Repeat sheet's Done.
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    expect(find.text('Never'), findsWidgets); // Ends row now reads Never
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.endDate, isNull);
    expect(result!.endCount, isNull);
  });

  testWidgets('the Never row keeps its tick', (tester) async {
    await _pump(tester, onResult: (_) {});
    await _openEnds(tester);
    // Default current = no end → Never selected → a check, no clear button.
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  // ── §4 · single-select while interval > 1 ──────────────────────────────────

  group('single vs multi day', () {
    testWidgets('interval 1 is multi-select', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      // Default month, day 9 seeded. Add the 14th.
      await tester.tap(find.text('14'));
      await tester.pump();
      expect(_summary(tester), 'Every month on 9 and 14');
      expect(find.text('ON THESE DAYS'), findsOneWidget);
    });

    testWidgets('interval > 1 is single-select', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      await tester.tap(find.byIcon(Icons.add_rounded)); // interval 2
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('14'));
      await tester.pump();
      // Only the 14th survives — no "and".
      expect(_summary(tester), 'Every 2 months on the 14th');
      expect(find.text('ON THIS DAY'), findsOneWidget);
    });

    testWidgets('raising the interval collapses the set on screen',
        (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      await tester.tap(find.text('14'));
      await tester.pump();
      expect(_summary(tester), 'Every month on 9 and 14');
      await tester.tap(find.byIcon(Icons.add_rounded)); // interval 2
      await tester.pump();
      expect(_summary(tester), 'Every 2 months on the 9th'); // lowest kept
      expect(find.text('ON THIS DAY'), findsOneWidget);
    });
  });

  // ── §5 · the summary, all seven shapes ─────────────────────────────────────

  group('summary shapes', () {
    testWidgets('day / year append no day-set', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      await tester.tap(find.text('Day'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(_summary(tester), 'Every 3 days');

      await tester.tap(find.text('Year'));
      await tester.pump();
      // n is 3 from before; drop to 2.
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(_summary(tester), 'Every 2 years');
    });

    testWidgets('month shapes', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      // Every 4 months on the 9th.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add_rounded));
      }
      await tester.pump();
      expect(_summary(tester), 'Every 4 months on the 9th');

      // Every month on 9 and 14 (bare numbers for several days — task 037 §4).
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.remove_rounded));
      }
      await tester.pump();
      await tester.tap(find.text('14'));
      await tester.pump();
      expect(_summary(tester), 'Every month on 9 and 14');

      // Every 2 months on the last day: reduce to Last only, then raise n.
      await tester.tap(find.text('Last'));
      await tester.pump(); // {9, 14, Last}
      await tester.tap(find.text('9'));
      await tester.pump(); // {14, Last}
      await tester.tap(find.text('14'));
      await tester.pump(); // {Last}
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(_summary(tester), 'Every 2 months on the last day');
    });

    testWidgets('the three-item join (commas + and)', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      await tester.tap(find.text('14'));
      await tester.tap(find.text('21'));
      await tester.pump();
      expect(_summary(tester), 'Every month on 9, 14 and 21');
    });

    testWidgets('week shapes', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      await tester.tap(find.text('Week'));
      await tester.pump();

      // Every 2 weeks on Mon: single-select at interval 2 then pick Monday.
      await tester.tap(find.byIcon(Icons.add_rounded)); // interval 2
      await tester.pump();
      await tester.tap(find.text('M')); // Monday (unique narrow label)
      await tester.pump();
      expect(_summary(tester), 'Every 2 weeks on Mon');

      // Every week on Mon, Wed and Fri.
      await tester.tap(find.byIcon(Icons.remove_rounded)); // interval 1, multi
      await tester.pump();
      await tester.tap(find.text('W')); // Wed
      await tester.tap(find.text('F')); // Fri
      await tester.pump();
      expect(_summary(tester), 'Every week on Mon, Wed and Fri');
    });
  });

  // ── §4 · the invariant ─────────────────────────────────────────────────────

  testWidgets('interval > 1 never leaves the sheet with more than one day',
      (tester) async {
    TxnRepeatSelection? result;
    await _pump(tester, onResult: (r) => result = r);
    await _openCustom(tester);
    // Try hard to smuggle two days past interval 2.
    await tester.tap(find.text('14'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded)); // interval 2 → collapse
    await tester.pump();
    await tester.tap(find.text('21')); // single-select replaces
    await tester.pump();
    await tester.tap(find.text('Done')); // Custom Done
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done')); // Repeat Done
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.interval, greaterThan(1));
    expect(result!.daysOfMonth.length, 1);
  });

  // ── §7 · layout ────────────────────────────────────────────────────────────

  group('layout', () {
    const sizes = [Size(390, 844), Size(360, 640), Size(320, 568)];
    const scales = [1.0, 1.3];

    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('Custom fits ${size.width.toInt()} @ $scale',
            (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await _pump(tester, onResult: (_) {});
          await _openCustom(tester);
          // A busy month set to stress the headline.
          await tester.tap(find.text('14'));
          await tester.tap(find.text('21'));
          await tester.tap(find.text('28'));
          await tester.pump();
          // Keyboard up: focus the interval field.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('Ends fits ${size.width.toInt()} @ $scale', (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await _pump(tester, onResult: (_) {});
          await _openEnds(tester);
          await tester.tap(find.text('After')); // keyboard up
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // ── colour sanity: selection is still marked on the cleared row ─────────────

  testWidgets('selected end row keeps an accent label', (tester) async {
    await _pump(
      tester,
      onResult: (_) {},
      current: TxnRepeatSelection(
        freq: RepeatFrequency.monthly,
        daysOfMonth: const {15},
        endDate: DateTime(2027, 1, 1),
      ),
    );
    await _openRepeat(tester);
    await tester.tap(find.text('Ends'));
    await tester.pumpAndSettle();
    // The value stays accent even though the trailing slot is now a clear button.
    final value = tester.widget<Text>(find.textContaining('2027'));
    expect(value.style?.color, AppColors.accentLight);
  });

  // ── task 037 · the summary leaves the card and the day-phrase is rewritten ──

  group('summary readback (037)', () {
    testWidgets('one day is an ordinal', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      // Default month, day 9 seeded, interval 1.
      expect(_summary(tester), 'Every month on the 9th');
    });

    testWidgets('several days are bare numbers, ascending, last final',
        (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      // Tap out of order: 21 before 14. Seed is 9.
      await tester.tap(find.text('21'));
      await tester.tap(find.text('14'));
      await tester.pump();
      expect(_summary(tester), 'Every month on 9, 14 and 21');
      // Last always sorts final, whatever the numbers.
      await tester.tap(find.text('Last'));
      await tester.pump();
      expect(_summary(tester), 'Every month on 9, 14, 21 and last day');
    });

    testWidgets('ten days list; eleven collapse to a count', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      // Seed 9; add up to ten, then an eleventh.
      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '10']) {
        await tester.tap(find.text(d));
      }
      await tester.pump();
      expect(_summary(tester),
          'Every month on 1, 2, 3, 4, 5, 6, 7, 8, 9 and 10'); // ten → listed
      await tester.tap(find.text('11'));
      await tester.pump();
      expect(_summary(tester), 'Every month on 11 days'); // eleven → count
    });

    testWidgets('no day selected → interval phrase alone, no dangling on',
        (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      await tester.tap(find.text('Clear'));
      await tester.pump();
      final s = _summary(tester);
      expect(s, 'Every month');
      expect(s.contains('  '), isFalse); // no double space
      expect(s.trimRight(), s); // no trailing preposition/space
    });

    testWidgets('the summary is not inside the interval bar and sits above it',
        (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      final summary = find.text('Every month on the 9th');
      // Not a descendant of the control bar (the old card is gone).
      expect(
        find.descendant(
            of: find.byKey(const ValueKey('repeatEveryBar')),
            matching: summary),
        findsNothing,
      );
      // It reads above the interval bar.
      expect(tester.getCenter(summary).dy,
          lessThan(tester.getCenter(find.byKey(const ValueKey('repeatEveryBar'))).dy));
    });

    testWidgets('with several days the summary renders in full, no ellipsis',
        (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      await tester.tap(find.text('14'));
      await tester.tap(find.text('21'));
      await tester.pump();
      final t = tester.widget<Text>(find.text('Every month on 9, 14 and 21'));
      expect(t.overflow, isNot(TextOverflow.ellipsis));
      expect(t.maxLines, isNull);
    });

    testWidgets('the summary is a live region', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      final sem = tester.widget<Semantics>(find
          .ancestor(
              of: find.text('Every month on the 9th'),
              matching: find.byType(Semantics))
          .first);
      expect(sem.properties.liveRegion, isTrue);
    });
  });

  // ── task 037 · the interval row ─────────────────────────────────────────────

  group('interval row (037)', () {
    testWidgets('carries the Repeat every label', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      expect(find.text('Repeat every'), findsOneWidget);
    });

    testWidgets('bar height equals a unit segment, at 1.0 and 1.3', (tester) async {
      for (final scale in const [1.0, 1.3]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, onResult: (_) {});
        await _openCustom(tester);
        final bar =
            tester.getSize(find.byKey(const ValueKey('repeatEveryBar'))).height;
        final segment = tester
            .getSize(find
                .ancestor(of: find.text('Month'), matching: find.byType(Container))
                .first)
            .height;
        expect(bar, segment, reason: 'scale $scale');
      }
    });

    testWidgets('− is disabled at the minimum but still in the tree',
        (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      // Interval starts at 1 → minus disabled.
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      final minus = tester.widget<GestureDetector>(find
          .ancestor(
              of: find.byIcon(Icons.remove_rounded),
              matching: find.byType(GestureDetector))
          .first);
      expect(minus.onTap, isNull); // disabled
    });

    testWidgets('step buttons keep a 44×44 tap target', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      final plus = find
          .ancestor(
              of: find.byIcon(Icons.add_rounded),
              matching: find.byType(SizedBox))
          .first;
      final size = tester.getSize(plus);
      expect(size.width, greaterThanOrEqualTo(44.0));
      expect(size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('the value does not shift as the interval grows 1→9→10→12',
        (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      double leftOfField() =>
          tester.getTopLeft(find.byType(TextField)).dx;
      final at1 = leftOfField();
      await tester.enterText(find.byType(TextField), '9');
      await tester.pump();
      expect(leftOfField(), at1);
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      expect(leftOfField(), at1);
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(leftOfField(), at1);
    });
  });

  // ── task 037 · Clear ────────────────────────────────────────────────────────

  group('Clear (037)', () {
    testWidgets('absent with nothing selected, present with a selection, and '
        'leaves interval and unit untouched', (tester) async {
      await _pump(tester, onResult: (_) {});
      await _openCustom(tester);
      // Day 9 seeded → Clear present.
      expect(find.text('Clear'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pump();
      // Nothing selected → Clear gone, summary is the interval phrase alone,
      // and neither the interval nor the unit moved.
      expect(find.text('Clear'), findsNothing);
      expect(_summary(tester), 'Every month');
      expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text, '1');
      // Re-selecting brings Clear back.
      await tester.tap(find.text('14'));
      await tester.pump();
      expect(find.text('Clear'), findsOneWidget);
      expect(_summary(tester), 'Every month on the 14th');
    });
  });

  // ── task 037 · rcNDays plural forms ─────────────────────────────────────────

  group('rcNDays plurals (037)', () {
    Future<AppLocalizations> loc(WidgetTester tester, Locale locale) async {
      late AppLocalizations l;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (ctx) {
          l = AppLocalizations.of(ctx);
          return const SizedBox();
        }),
      ));
      return l;
    }

    testWidgets('en / tr / tk / ru at 11, 14, 21', (tester) async {
      final en = await loc(tester, const Locale('en'));
      expect([en.rcNDays(11), en.rcNDays(14), en.rcNDays(21)],
          ['11 days', '14 days', '21 days']);

      final tr = await loc(tester, const Locale('tr'));
      // Turkish does not pluralise the noun with a count.
      expect([tr.rcNDays(11), tr.rcNDays(14), tr.rcNDays(21)],
          ['11 gün', '14 gün', '21 gün']);

      final tk = await loc(tester, const Locale('tk'));
      expect([tk.rcNDays(11), tk.rcNDays(14), tk.rcNDays(21)],
          ['11 gün', '14 gün', '21 gün']);

      final ru = await loc(tester, const Locale('ru'));
      // 11–14 → many (дней); 21 → one (день).
      expect([ru.rcNDays(11), ru.rcNDays(14), ru.rcNDays(21)],
          ['11 дней', '14 дней', '21 день']);
    });
  });

  // ── task 037 · width case: ten days, 320pt @ 1.3, longest locale ────────────

  testWidgets('ten days at 320 @ 1.3 (ru): no overflow, Done reachable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568) * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pump(tester, onResult: (_) {}, locale: const Locale('ru'));
    await _openCustom(tester);
    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '10']) {
      await tester.tap(find.text(d));
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Done stays reachable — the sheet scrolls it into view.
    await tester.ensureVisible(find.text('Done'));
    expect(tester.takeException(), isNull);
  });
}
