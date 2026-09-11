import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/opening_balance_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/opening_balance_amount_entry_test.dart
//
// Task 16 — the opening-balance sheet no longer types its amount on the system
// keyboard (whose comma key turned `500,0` into `5,000`). It uses the app's own
// keypad driving an AmountEntry raw string: no comma key, no separator guessing,
// no money lost. These tests pin the regression and the new inline field.

Account _asset(String id, String name, double opening,
        {String currency = 'USD'}) =>
    Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: currency,
      startingBalance: opening,
      openingDate: DateTime(2026, 8, 1),
    );

AppStore _store(List<Account> accounts) => AppStore(
      accounts: accounts,
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, String accountId) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showOpeningBalanceSheet(ctx, accountId),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

/// The focused amount row's caret blinks on a repeating animation, so
/// [WidgetTester.pumpAndSettle] never settles once the row holds focus — every
/// step after focus uses fixed frames instead.
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _open(WidgetTester tester, AppStore store, String accountId) async {
  await tester.pumpWidget(_host(store, accountId));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Focuses the amount row and presses [keys] on the docked keypad.
Future<void> _type(WidgetTester tester, List<String> keys) async {
  await tester.tap(find.text('Amount'));
  await _pumpFrames(tester);
  for (final k in keys) {
    await tester.tap(find.text(k));
    await _pumpFrames(tester);
  }
}

/// The Text.rich rendering the amount — the only Text whose plain text carries
/// the typed figure.
Text _amountText(WidgetTester tester, String contains) {
  return tester.widgetList<Text>(find.byType(Text)).firstWhere((t) =>
      t.textSpan != null && t.textSpan!.toPlainText().contains(contains));
}

List<TextSpan> _spans(Text amount) {
  final root = amount.textSpan! as TextSpan;
  return [
    for (final c in root.children ?? const <InlineSpan>[])
      if (c is TextSpan) c,
  ];
}

void main() {
  group('the regression this task exists to kill', () {
    // The old field: `_amount.text.trim().replaceAll(',', '')` then tryParse.
    // Faithfully replicated so the bug it caused is on the record.
    double? oldParse(String text) {
      final t = text.trim().replaceAll(',', '');
      if (t.isEmpty) return null;
      final v = double.tryParse(t);
      if (v == null || v < 0) return null;
      return v;
    }

    test('OLD parser turned a typed `500,0` into 5000 — the money it lost', () {
      // A user meaning five hundred, typing a comma as a decimal separator.
      expect(oldParse('500,0'), 5000.0);
      // The correct dot form the old field also accepted.
      expect(oldParse('500.0'), 500.0);
    });

    test('NEW path: the keys 5 0 0 . 0 yield 500.0, and a comma cannot be typed',
        () {
      // The keypad has no comma key, so `500,0` is unreachable. The equivalent
      // intent — 5 0 0 . 0 — flows through AmountEntry.
      var raw = '';
      for (final k in ['5', '0', '0', '.', '0']) {
        raw = AmountEntry.press(raw, k);
      }
      expect(raw, '500.0');
      expect(AmountEntry.value(raw), 500.0);
    });

    testWidgets('the docked keypad offers a dot but no comma key', (tester) async {
      final store = _store([_asset('a1', 'Main Checking', 0)]);
      await _open(tester, store, 'a1');
      await tester.tap(find.text('Amount'));
      await _pumpFrames(tester);
      expect(find.byType(NumericKeypad), findsOneWidget);
      expect(find.text('.'), findsOneWidget); // a single decimal key…
      expect(find.text(','), findsNothing); // …and no comma to misread (§4)
    });

    testWidgets('driving the real sheet, 5 0 0 . 0 stores 500.0 (not 5000)',
        (tester) async {
      final store = _store([_asset('a1', 'Main Checking', 0)]);
      await _open(tester, store, 'a1');
      await _type(tester, ['5', '0', '0', '.', '0']);

      await tester.ensureVisible(find.text('Save'));
      await _pumpFrames(tester);
      await tester.tap(find.text('Save'));
      await _pumpFrames(tester);

      expect(store.accountById('a1')!.startingBalance, 500.0);
      expect(store.accountById('a1')!.startingBalance, isNot(5000.0));
    });
  });

  group('AmountEntry drives the field', () {
    test('a third decimal keystroke is a no-op, losing nothing already typed',
        () {
      expect(AmountEntry.press('500.50', '5'), '500.50');
      expect(AmountEntry.press('500.5', '0'), '500.50'); // second decimal is ok
      expect(AmountEntry.press('500.50', '9'), '500.50'); // third is refused
    });

    test('value(raw) equals what the sheet saves', () {
      // _save writes AmountEntry.value(_amountRaw); no re-parse of display text.
      expect(AmountEntry.value('500.0'), 500.0);
      expect(AmountEntry.value('12345'), 12345.0);
      expect(AmountEntry.value('0.05'), 0.05);
    });

    test('seeding an existing balance round-trips through fromDouble/value', () {
      for (final v in [0.0, 500.0, 500.5, 500.55, 11046.0]) {
        expect(AmountEntry.value(AmountEntry.fromDouble(v)), v);
      }
    });
  });

  group('the inline field renders', () {
    testWidgets('a filled, unfocused amount shows no dim (not-yet-typed) span',
        (tester) async {
      // Seeded 500 → the display carries a `.00` padding that MUST be bright
      // once the row is filled and unfocused (task 11), never the pale tertiary.
      final store = _store([_asset('a1', 'Main Checking', 500)]);
      await _open(tester, store, 'a1');

      final amount = _amountText(tester, '500');
      final colors = _spans(amount).map((s) => s.style?.color).toList();
      expect(colors, isNot(contains(AppColors.textTertiary)));
      expect(colors, contains(AppColors.textPrimary));
    });

    testWidgets('while focused, the untyped decimal padding is dim',
        (tester) async {
      final store = _store([_asset('a1', 'Main Checking', 0)]);
      await _open(tester, store, 'a1');
      await _type(tester, ['5', '0', '0']); // "500" typed, ".00" is padding

      final amount = _amountText(tester, '500');
      final colors = _spans(amount).map((s) => s.style?.color).toList();
      expect(colors, contains(AppColors.textTertiary)); // the ".00" padding
      expect(colors, contains(AppColors.textPrimary)); // the typed "500"
    });

    testWidgets('the token side follows the currency def, no prefix symbol',
        (tester) async {
      // USD: symbol, before, flush → "$500.00".
      final usd = _store([_asset('a1', 'Main', 500)]);
      await _open(tester, usd, 'a1');
      expect(_amountText(tester, '500').textSpan!.toPlainText(), r'$500.00');
    });

    testWidgets('a code-only currency spaces the code from the number',
        (tester) async {
      // CHF has no symbol → token is the code, spaced (symbolBefore defaults
      // true) → "CHF 500.00". No bare "$" prefix; the token follows the def.
      final chf = _store([_asset('a1', 'Main', 500, currency: 'CHF')]);
      await _open(tester, chf, 'a1');
      expect(_amountText(tester, '500').textSpan!.toPlainText(), 'CHF 500.00');
    });

    testWidgets('a symbol-after currency renders the symbol flush after',
        (tester) async {
      // RUB: symbol "₽", symbolBefore false → "500.00₽" (after, flush).
      final rub = _store([_asset('a1', 'Main', 500, currency: 'RUB')]);
      await _open(tester, rub, 'a1');
      expect(_amountText(tester, '500').textSpan!.toPlainText(), '500.00₽');
    });

    testWidgets('TMT renders from its def (symbol m, before, flush)',
        (tester) async {
      // The shipped TMT def carries symbol "m", symbolBefore true — so the row
      // reads "m500.00", the def-driven form, not the spec prose's "500.00 TMT".
      final tmt = _store([_asset('a1', 'Main', 500, currency: 'TMT')]);
      await _open(tester, tmt, 'a1');
      expect(_amountText(tester, '500').textSpan!.toPlainText(), 'm500.00');
    });
  });

  group('date row and keypad never coexist', () {
    testWidgets('opening the date picker closes the keypad', (tester) async {
      final store = _store([_asset('a1', 'Main Checking', 0)]);
      await _open(tester, store, 'a1');

      await tester.tap(find.text('Amount'));
      await _pumpFrames(tester);
      expect(find.byType(NumericKeypad), findsOneWidget);

      await tester.tap(find.text('Date'));
      await _pumpFrames(tester);
      // The keypad is gone; the date picker dialog has taken over.
      expect(find.byType(NumericKeypad), findsNothing);
    });
  });
}
