import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/theme/app_colors.dart';

/// Task 007 — the New-task amount is typed in place, on the docked keypad, not
/// on a bottom-sheet text prompt.

/// A reference implementation of the task 043 §4 rule, kept here so the parity
/// test proves [AmountEntry.splitPlain] reproduces it byte for byte: no decimal
/// point typed means no decimals at all; a point typed completes the field to
/// the currency's width with dim zeros.
({String typed, String rest}) legacyParts(String raw, String currency) {
  String group(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  final decimals = switch (currency) {
    'JPY' => 0,
    _ => 2,
  };
  if (raw.isEmpty) return (typed: '', rest: '0');
  final dot = raw.indexOf('.');
  final wholeSrc = dot < 0 ? raw : raw.substring(0, dot);
  final whole = group(wholeSrc.isEmpty ? '0' : wholeSrc);
  if (dot < 0) return (typed: whole, rest: '');
  final decs = raw.substring(dot + 1);
  final pad = decimals - decs.length;
  return (typed: '$whole.$decs', rest: pad > 0 ? '0' * pad : '');
}

Widget _taskApp(AppStore store, {NavigatorObserver? observer}) => StoreScope(
      store: store,
      child: MaterialApp(
        navigatorObservers: observer == null ? const [] : [observer],
        home: const QuickAddScreen(initialType: QuickAddType.newTask),
      ),
    );

Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 350));

/// The amount row's value glyph is a `Text.rich`; the label and the chip code
/// are plain `Text`. This picks the value out of the row.
TextSpan _valueSpan(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(TxnAmountFieldRow),
    matching: find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
  );
  return tester.widget<Text>(finder).textSpan! as TextSpan;
}

void main() {
  group('AmountEntry.splitPlain', () {
    test('USD groups thousands; decimals appear only after a point is typed', () {
      ({String typed, String rest}) s(String raw) =>
          AmountEntry.splitPlain(raw, 'USD');
      // No point typed → no decimals; empty field is a bare dim 0 (task 043 §4).
      expect(s(''), (typed: '', rest: '0'));
      expect(s('0'), (typed: '0', rest: ''));
      expect(s('12'), (typed: '12', rest: ''));
      expect(s('1234567'), (typed: '1,234,567', rest: ''));
      // A point typed → the field exists and is completed with dim zeros.
      expect(s('0.'), (typed: '0.', rest: '00'));
      expect(s('12.3'), (typed: '12.3', rest: '0'));
      expect(s('12.34'), (typed: '12.34', rest: ''));
    });

    test('JPY pads nothing (zero decimals)', () {
      ({String typed, String rest}) s(String raw) =>
          AmountEntry.splitPlain(raw, 'JPY');
      expect(s(''), (typed: '', rest: '0'));
      expect(s('0'), (typed: '0', rest: ''));
      expect(s('12'), (typed: '12', rest: ''));
      expect(s('1234567'), (typed: '1,234,567', rest: ''));
    });

    test('matches the task 043 §4 reference implementation', () {
      for (final currency in ['USD', 'JPY']) {
        for (final raw in ['', '0', '0.', '12', '12.3', '12.34', '1234567']) {
          expect(AmountEntry.splitPlain(raw, currency), legacyParts(raw, currency),
              reason: 'currency=$currency raw="$raw"');
        }
      }
    });
  });

  group('TxnAmountFieldRow in the task form', () {
    testWidgets('tapping the row pushes no route and shows no sheet',
        (tester) async {
      final observer = _CountingObserver();
      await tester.pumpWidget(
          _taskApp(buildSeedStore(), observer: observer));
      await _settle(tester);

      final before = observer.pushes;
      await tester.tap(find.text('Amount'));
      await _settle(tester);

      expect(observer.pushes, before,
          reason: 'focusing the amount must not push a route');
      expect(find.text('Done'), findsNothing,
          reason: 'the old amount prompt sheet must be gone');
    });

    testWidgets('the docked keypad writes to the row', (tester) async {
      await tester.pumpWidget(_taskApp(buildSeedStore()));
      await _settle(tester);

      await tester.tap(find.text('Amount'));
      await _settle(tester);
      expect(find.byType(NumericKeypad), findsOneWidget);

      for (final k in ['1', '2', '0', '0']) {
        await tester.tap(find.text(k));
        await tester.pump();
      }
      expect(find.textContaining('1,200', findRichText: true), findsOneWidget);

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(find.textContaining('120', findRichText: true), findsOneWidget);
    });

    testWidgets('the four states show 0 and the chip correctly',
        (tester) async {
      await tester.pumpWidget(_taskApp(buildSeedStore()));
      await _settle(tester);

      // empty, unfocused — a dim 0 in its currency, never a sentence
      // (task 061); the chip is always present.
      expect(find.text('Enter amount'), findsNothing);
      expect(find.byType(CurrencyChip), findsOneWidget);
      expect(_valueSpan(tester).toPlainText(), '0');

      // empty, focused — the same bare dim 0, no `.00` before a point is typed
      await tester.tap(find.text('Amount'));
      await _settle(tester);
      expect(find.text('Enter amount'), findsNothing);
      expect(find.byType(CurrencyChip), findsOneWidget);
      expect(_valueSpan(tester).toPlainText(), '0');

      // filled, focused
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(find.byType(CurrencyChip), findsOneWidget);

      // filled, unfocused
      await tester.tap(find.byType(TextField).first); // focus the title
      await _settle(tester);
      expect(find.byType(CurrencyChip), findsOneWidget);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.text('Enter amount'), findsNothing);
    });

    testWidgets('dim rule: filled+unfocused is all bright, focused keeps a pale tail',
        (tester) async {
      await tester.pumpWidget(_taskApp(buildSeedStore()));
      await _settle(tester);

      await tester.tap(find.text('Amount'));
      await _settle(tester);
      // A decimal point opens the field; the completion behind it is dim (§4) —
      // "12." typed, "00" untyped. Without the point there is no tail at all.
      for (final k in ['1', '2', '.']) {
        await tester.tap(find.text(k));
        await tester.pump();
      }

      // Focused: the untyped decimal tail is dim (textTertiary).
      var spans = _valueSpan(tester)
          .children!
          .whereType<TextSpan>()
          .toList();
      expect(spans.first.style!.color, AppColors.textPrimary); // typed "12."
      expect(spans.last.style!.color, AppColors.textTertiary); // "00" pale

      // Unfocused: the whole number is bright.
      await tester.tap(find.byType(TextField).first);
      await _settle(tester);
      spans =
          _valueSpan(tester).children!.whereType<TextSpan>().toList();
      for (final span in spans) {
        expect(span.style!.color, AppColors.textPrimary);
      }
    });

    testWidgets('mutual exclusion: title focus closes the keypad and back',
        (tester) async {
      await tester.pumpWidget(_taskApp(buildSeedStore()));
      await _settle(tester);

      // With the keypad open, focusing the title closes it.
      await tester.tap(find.text('Amount'));
      await _settle(tester);
      expect(find.byType(NumericKeypad), findsOneWidget);

      await tester.tap(find.byType(TextField).first);
      await _settle(tester);
      expect(find.byType(NumericKeypad), findsNothing);

      // With the title focused, tapping the amount raises the keypad.
      await tester.tap(find.text('Amount'));
      await _settle(tester);
      expect(find.byType(NumericKeypad), findsOneWidget);
    });

    testWidgets('chip round-trip leaves the keypad open and the amount intact',
        (tester) async {
      await tester.pumpWidget(_taskApp(buildSeedStore()));
      await _settle(tester);

      await tester.tap(find.text('Amount'));
      await _settle(tester);
      for (final k in ['1', '2', '0', '0']) {
        await tester.tap(find.text(k));
        await tester.pump();
      }
      expect(find.textContaining('1,200', findRichText: true), findsOneWidget);

      await tester.tap(find.byType(CurrencyChip));
      await _settle(tester);
      // Cancel the picker without changing the currency.
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      expect(find.byType(NumericKeypad), findsOneWidget,
          reason: 'the keypad must be back after the picker closes');
      expect(find.textContaining('1,200', findRichText: true), findsOneWidget,
          reason: 'the half-typed amount must survive the picker');
    });

    testWidgets('save records the typed amount as a negative expected amount',
        (tester) async {
      final store = buildSeedStore();
      await tester.pumpWidget(_taskApp(store));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Buy milk');
      await _settle(tester);

      await tester.tap(find.text('Amount'));
      await _settle(tester);
      for (final k in ['1', '2', '.', '5']) {
        await tester.tap(find.text(k));
        await tester.pump();
      }

      await tester.tap(find.text('Save'));
      await _settle(tester);

      final created = store.tasks.firstWhere((t) => t.title == 'Buy milk');
      expect(created.expectedAmount, -12.5);
    });
  });
}

class _CountingObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}
