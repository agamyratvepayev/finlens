import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 11 — the New account sheet's `Starting balance` row.
//
// `flutter test` hangs on the dev machine, so this file is written, not run
// here. Run it yourself:
//   flutter test test/task11_starting_balance_row_colors_test.dart
//
// The row used to dim its decimals *because they were decimals* (a dedicated
// `textTertiary` style). It now follows the one rule (spec §0): pale means "not
// typed yet". Empty → the placeholder is dim; filled and unfocused → the whole
// number is bright (`textPrimary`), with no tertiary anywhere in the figure.

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
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store) => StoreScope(
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
                onPressed: () => showNewAccountSheet(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

/// The caret blinks forever while a row is focused, so pumpAndSettle never
/// returns once focus lands — fixed frames instead.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Colours of the amount paragraph's child TextSpans (caret WidgetSpan skipped).
List<Color?> _amountColours(WidgetTester tester, String needle) {
  final rp = tester.renderObject<RenderParagraph>(
      find.textContaining(needle, findRichText: true));
  final root = rp.text as TextSpan;
  return [
    for (final c in root.children ?? const <InlineSpan>[])
      if (c is TextSpan) c.style?.color,
  ];
}

void main() {
  testWidgets('empty renders the placeholder dim', (tester) async {
    await tester.pumpWidget(_host(_store()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // USD base currency → the empty amount reads "0.00", the currency code is a
    // separate widget, not part of the number.
    final colours = _amountColours(tester, '0.00');
    expect(colours, isNotEmpty);
    expect(colours.every((c) => c == AppColors.textTertiary), isTrue,
        reason: 'nothing typed yet, so the whole placeholder is pale');
    expect(colours, isNot(contains(AppColors.textPrimary)));
  });

  testWidgets('a typed value, unfocused, renders no tertiary in the number',
      (tester) async {
    await tester.pumpWidget(_host(_store()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Focus the balance row and type 1000 on the docked keypad.
    await tester.tap(find.text('Starting balance'));
    await _frames(tester);
    for (final k in ['1', '0', '0', '0']) {
      await tester.tap(find.descendant(
        of: find.byType(NumericKeypad),
        matching: find.text(k),
      ));
      await _frames(tester);
    }

    // While focused the ".00" padding is still pale (typing state).
    final typing = _amountColours(tester, '1,000');
    expect(typing, contains(AppColors.textTertiary));
    expect(typing, contains(AppColors.textPrimary));

    // Blur the row: focusing the name field closes the keypad, so the row is
    // now filled + unfocused — the done state.
    await tester.tap(find.byType(EditableText).first);
    await tester.pumpAndSettle();

    final done = _amountColours(tester, '1,000');
    expect(done, isNot(contains(AppColors.textTertiary)),
        reason: 'a finished amount has no pale, not-yet-typed part');
    expect(done, contains(AppColors.textPrimary));
  });
}
