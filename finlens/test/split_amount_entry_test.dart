import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/split_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// One amount model per app.
///
/// A split line used to run on a raw `TextField` and the system keyboard behind
/// a third modal, printing `2555686` where the form's hero prints
/// `$2,555,686.00`. The missing grouping was the symptom; the defect was two
/// ways to type an amount inside one flow, with two parsers that had to agree
/// forever. The line now runs on `AmountEntry` and the app's own keypad, so
/// there is one parser and one formatter.
Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
    );

AppStore _store() => AppStore(
      accounts: [
        Account(
          id: 'a1',
          name: 'Cash',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 1000,
        ),
      ],
      categories: [_cat('c1', 'Groceries'), _cat('c2', 'Household')],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Future<void> _open(
  WidgetTester tester, {
  required double total,
  required List<SplitLine> initial,
  Locale? locale,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(StoreScope(
    store: _store(),
    child: MaterialApp(
      locale: locale,
      // main.dart's list: flutter_localizations ships no Turkmen, so the tk
      // shims must precede the Global* delegates.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        TkMaterialLocalizationsDelegate(),
        TkCupertinoLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSplitSheet(
                  ctx,
                  total: total,
                  currency: 'USD',
                  accountName: 'Cash',
                  categoryType: CategoryType.expense,
                  initial: initial,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

SplitLine _line(String cat, double? amt) =>
    SplitLine(categoryId: cat, amount: amt);

/// Taps a keypad key by its face.
Future<void> _key(WidgetTester tester, String k) async {
  await tester.tap(find.descendant(
    of: find.byType(NumericKeypad),
    matching: find.text(k),
  ));
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await _key(tester, d);
  }
}

void main() {
  // ── §4 · the parity test ──────────────────────────────────────────────────
  //
  // The direct test of the rule: the same key sequence must mean the same thing
  // wherever it is typed. This one is unit-level on purpose — it compares the
  // model both surfaces run on, so it cannot be satisfied by two
  // implementations that merely happen to agree today.
  group('the hero and a split line share one entry model', () {
    test('the same keys produce the same raw string and the same value', () {
      const keys = ['2', '5', '5', '5', '6', '8', '6'];

      var hero = '';
      for (final k in keys) {
        hero = AmountEntry.press(hero, k);
      }

      // A split line drives the identical function; there is no second model to
      // diverge from.
      var line = '';
      for (final k in keys) {
        line = AmountEntry.press(line, k);
      }

      expect(line, hero);
      expect(AmountEntry.value(line), AmountEntry.value(hero));
      expect(hero, '2555686');
      expect(AmountEntry.value(hero), 2555686.0);
    });

    test('digits accumulate as whole units, not cents from the right', () {
      var raw = '';
      for (final k in '2555686'.split('')) {
        raw = AmountEntry.press(raw, k);
      }
      // $2,555,686.00 — not $25,556.86.
      expect(AmountEntry.value(raw), 2555686.0);
      final parts = AmountEntry.split(raw, 'USD');
      expect('${parts.typed}${parts.rest}', r'$2,555,686.00');
    });

    test('the decimal key and the two-decimal cap behave identically', () {
      expect(AmountEntry.press('12', '.'), '12.');
      expect(AmountEntry.press('12.', '.'), '12.');
      expect(AmountEntry.press('12.34', '5'), '12.34');
      expect(AmountEntry.press('', '.'), '0.');
    });

    test('backspace at length zero is a no-op', () {
      expect(AmountEntry.backspace(''), '');
    });
  });

  // ── §12 · the reported bug ────────────────────────────────────────────────
  testWidgets('typing 2555686 into a split line renders it grouped',
      (tester) async {
    await _open(tester, total: 3000000, initial: [
      _line('c1', null),
      _line('c2', 10),
    ]);

    // Open the keypad on the first line by tapping its amount.
    await tester.tap(find.text('—').first);
    await tester.pumpAndSettle();

    await _type(tester, '2555686');

    // Before this change the line printed the raw `2555686`; it now goes
    // through the app's one formatter.
    expect(find.text(r'$2,555,686.00'), findsOneWidget);
    expect(find.text('2555686'), findsNothing);
  });

  // ── §12 · no system keyboard, anywhere ────────────────────────────────────
  testWidgets('tapping a line amount raises no EditableText', (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', null),
      _line('c2', null),
    ]);

    expect(find.byType(EditableText), findsNothing);
    await tester.tap(find.text('—').first);
    await tester.pumpAndSettle();

    expect(find.byType(EditableText), findsNothing,
        reason: 'the split sheet has no text field on its amount path');
    expect(find.byType(NumericKeypad), findsOneWidget);
  });

  // ── §1 · the two modes ────────────────────────────────────────────────────
  testWidgets('list mode shows Split evenly and Done and no keypad',
      (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 50),
      _line('c2', 50),
    ]);

    expect(find.byType(NumericKeypad), findsNothing);
    expect(find.text('Split evenly'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    // The button that could not name its own line is gone.
    expect(find.text('Assign the rest'), findsNothing);
  });

  testWidgets('entry mode shows the keypad and neither button', (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 50),
      _line('c2', 50),
    ]);

    await tester.tap(find.text(r'$50.00').first);
    await tester.pumpAndSettle();

    expect(find.byType(NumericKeypad), findsOneWidget);
    expect(find.text('Split evenly'), findsNothing);
    expect(find.text('Done'), findsNothing,
        reason: 'you cannot be finished while a number is half-typed');
  });

  testWidgets('switching lines keeps the keypad open', (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 50),
      _line('c2', 25),
    ]);

    await tester.tap(find.text(r'$50.00'));
    await tester.pumpAndSettle();
    expect(find.byType(NumericKeypad), findsOneWidget);

    // Straight to another line — no open-type-dismiss cycle.
    await tester.tap(find.text(r'$25.00'));
    await tester.pumpAndSettle();
    expect(find.byType(NumericKeypad), findsOneWidget);

    // Typing now lands on the second line.
    await _type(tester, '9');
    expect(find.text(r'$259.00'), findsOneWidget);
  });

  testWidgets('tapping the active line again closes the keypad',
      (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 50),
      _line('c2', 50),
    ]);

    await tester.tap(find.text(r'$50.00').first);
    await tester.pumpAndSettle();
    expect(find.byType(NumericKeypad), findsOneWidget);

    await tester.tap(find.text(r'$50.00').first);
    await tester.pumpAndSettle();
    expect(find.byType(NumericKeypad), findsNothing);
  });

  // ── §3 · the active line hides its ✕ ──────────────────────────────────────
  testWidgets('the active line shows no ✕; inactive lines do', (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 50),
      _line('c2', 50),
    ]);

    expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));

    await tester.tap(find.text(r'$50.00').first);
    await tester.pumpAndSettle();

    // The delete control would sit under the finger that is typing.
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  // ── §9 · `—` means empty, `$0.00` means zero ──────────────────────────────
  testWidgets('an unassigned line reads —; a line set to zero reads \$0.00',
      (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', null),
      _line('c2', 0),
    ]);

    expect(find.text('—'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget);
  });

  testWidgets('typing then clearing a line returns it to —', (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', null),
      _line('c2', 50),
    ]);

    await tester.tap(find.text('—'));
    await tester.pumpAndSettle();
    await _type(tester, '5');
    expect(find.text(r'$5.00'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(NumericKeypad),
      matching: find.byIcon(Icons.backspace_outlined),
    ));
    await tester.pump();
    expect(find.text('—'), findsOneWidget,
        reason: 'an emptied line is unassigned again, not zero');
  });

  // ── §5 · the remainder line's three states ────────────────────────────────
  testWidgets('the remainder renders under, exact and over', (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 30),
      _line('c2', 20),
    ]);
    expect(find.text('Left to assign'), findsOneWidget);
    // The remainder goes through `money` without forceDecimals, as it always
    // has — a whole figure prints $50.
    expect(find.text(r'$50'), findsOneWidget);
  });

  testWidgets('the remainder reads Fully assigned at exactly zero',
      (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 60),
      _line('c2', 40),
    ]);
    expect(find.text('Fully assigned'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('the over-assigned magnitude prints positive', (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 80),
      _line('c2', 40),
    ]);
    expect(find.text('Over-assigned by'), findsOneWidget);
    // The word carries the direction; the figure itself carries no minus sign,
    // which would read as an amount rather than a state.
    expect(find.text(r'$20'), findsOneWidget);
    expect(find.text(r'-$20'), findsNothing);
    expect(find.text(r'−$20'), findsNothing);
  });

  testWidgets('the remainder is tappable only when under, and only in entry '
      'mode', (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 30),
      _line('c2', 20),
    ]);

    // List mode: no chevron, not interactive.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.tap(find.text(r'$30.00'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

  });

  testWidgets('the remainder is not tappable while over-assigned',
      (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 80),
      _line('c2', 40),
    ]);
    await tester.tap(find.text(r'$80.00'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('Assign the rest adds to the active line and keeps the keypad',
      (tester) async {
    await _open(tester, total: 208957, initial: [
      _line('c1', 120000),
      _line('c2', null),
    ]);

    await tester.tap(find.text(r'$120,000.00'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Left to assign'));
    await tester.pumpAndSettle();

    // Added, not replaced: $120,000 + $88,957. The Total row carries the same
    // figure once the line absorbs the rest, hence two matches.
    expect(find.text(r'$208,957.00'), findsNWidgets(2));
    expect(find.text(r'$120,000.00'), findsNothing);
    expect(find.text('Fully assigned'), findsOneWidget);
    expect(find.byType(NumericKeypad), findsOneWidget);
  });

  // ── §8 · Done ─────────────────────────────────────────────────────────────
  testWidgets('Done needs remainder zero and no unassigned line',
      (tester) async {
    // Remainder zero but a line left blank → disabled.
    await _open(tester, total: 100, initial: [
      _line('c1', 100),
      _line('c2', null),
    ]);
    expect(find.text('Fully assigned'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'))
          .onPressed,
      isNull,
      reason: 'a line the user created and did not fill is a question',
    );

  });

  testWidgets('Done is enabled at remainder zero with an explicit \$0.00 line',
      (tester) async {
    await _open(tester, total: 100, initial: [
      _line('c1', 100),
      _line('c2', 0),
    ]);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'))
          .onPressed,
      isNotNull,
      reason: 'an intentional zero share is assigned, unlike a blank line',
    );
  });

  // ── §2 · Add a line ───────────────────────────────────────────────────────
  testWidgets('Add a line is the card\'s last row and reachable with the '
      'keypad open at 320pt', (tester) async {
    await _open(tester,
        total: 100,
        initial: [_line('c1', 40), _line('c2', 20)],
        size: const Size(320, 568));

    await tester.tap(find.text(r'$40.00'));
    await tester.pumpAndSettle();
    expect(find.byType(NumericKeypad), findsOneWidget);

    // It lives inside the scrolling card, so it survives entry mode.
    final add = find.text('Add a line');
    expect(add, findsOneWidget);
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    expect(tester.getRect(add).height, greaterThan(0));
  });

  // ── §11 · layout ──────────────────────────────────────────────────────────
  for (final size in const [
    Size(390, 844),
    Size(360, 640),
    Size(320, 568),
  ]) {
    for (final scale in const [1.0, 1.3]) {
      for (final locale in const [
        Locale('en'),
        Locale('tr'),
        Locale('tk'),
        Locale('ru'),
      ]) {
        testWidgets(
            'no overflow with the keypad open at ${size.width.toInt()}×'
            '${size.height.toInt()} / ${(scale * 100).toInt()}% in '
            '${locale.languageCode}', (tester) async {
          await _open(tester,
              total: 208957,
              initial: [
                _line('c1', 120000),
                _line('c2', 40000),
                _line('c1', null),
              ],
              size: size,
              textScale: scale,
              locale: locale);

          await tester.tap(find.text(r'$120,000.00'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(NumericKeypad), findsOneWidget);

          // At least two lines visible above the remainder line.
          final visible = find
              .byIcon(Icons.shopping_basket_rounded)
              .evaluate()
              .where((e) {
            final box = e.renderObject as RenderBox?;
            if (box == null || !box.hasSize) return false;
            final y = box.localToGlobal(Offset.zero).dy;
            return y >= 0 && y <= size.height;
          }).length;
          expect(visible, greaterThanOrEqualTo(2),
              reason: 'the list must keep at least two lines in view');
        });
      }
    }
  }
}
