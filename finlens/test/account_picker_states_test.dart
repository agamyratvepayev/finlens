import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/account_picker_states_test.dart
//
// Covers the account picker's four states (account-picker-sheet spec §8):
//   1 · no accounts        2 · accounts, no query
//   3 · accounts, matches  4 · accounts, query with no match
//
// The header create action is discriminated by its leading '+' glyph, which the
// empty-state (state 1) filled button does not render.

Account _acc(String id, String name, AccountGroup group) => Account(
      id: id,
      name: name,
      group: group,
      currency: 'USD',
      startingBalance: 1000,
    );

AppStore _emptyStore() => AppStore(
      accounts: const <Account>[],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

AppStore _populatedStore() => AppStore(
      accounts: [
        _acc('a1', 'Main Checking', AccountGroup.spendable),
        _acc('a2', 'Savings', AccountGroup.spendable),
        _acc('a3', 'Amex', AccountGroup.creditCards),
      ],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(
  AppStore store,
  void Function(BuildContext) onTap, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        // A `builder` override reaches modal routes (the sheet), which a
        // MediaQuery below the Navigator would not.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onTap(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester, AppStore store,
    {Locale locale = const Locale('en'), double textScale = 1.0}) async {
  await tester.pumpWidget(
      _host(store, (ctx) => pickAccount(ctx), locale: locale, textScale: textScale));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void _setSize(WidgetTester tester, double w, double h) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
}

Iterable<String> _allText(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map(
          (t) => t.data ?? t.textSpan?.toPlainText() ?? '',
        );

void main() {
  // ── State 1 · no accounts ────────────────────────────────────────────────
  group('state 1 · no accounts', () {
    testWidgets('regression: empty state, not the no-match message',
        (tester) async {
      await _open(tester, _emptyStore());

      // The whole point of the spec: the "No account matches …" line and the
      // search field must be gone, replaced by the empty state.
      expect(find.textContaining('No account matches'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      // Header create action (its '+') is absent; the empty-state button is the
      // sole create affordance.
      expect(find.text('+'), findsNothing);
      expect(find.text('No accounts yet'), findsOneWidget);
      expect(find.text('New account'), findsOneWidget);
    });

    testWidgets('renders no empty pair of quotation marks anywhere',
        (tester) async {
      await _open(tester, _emptyStore());
      for (final s in _allText(tester)) {
        expect(s.contains('""'), isFalse, reason: 'stray quotes in: "$s"');
      }
    });

    testWidgets('the search field is not focused (no keyboard)', (tester) async {
      await _open(tester, _emptyStore());
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });
  });

  // ── State 2 · accounts, no query ─────────────────────────────────────────
  group('state 2 · accounts, no query', () {
    testWidgets('full list, search field and single header action',
        (tester) async {
      await _open(tester, _populatedStore());
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Amex'), findsOneWidget);
      expect(find.textContaining('No account matches'), findsNothing);
      // Create action present exactly once, in the header.
      expect(find.text('+'), findsOneWidget);
      expect(find.text('New account'), findsOneWidget);
    });

    testWidgets('the search field is not autofocused', (tester) async {
      await _open(tester, _populatedStore());
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    testWidgets('a whitespace-only query is treated as no query',
        (tester) async {
      await _open(tester, _populatedStore());
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      // State 2, not state 4: the full list stays and the message never shows.
      expect(find.textContaining('No account matches'), findsNothing);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
    });
  });

  // ── State 3 · accounts, query with matches ───────────────────────────────
  group('state 3 · accounts, matches', () {
    testWidgets('only matching rows; header action still present',
        (tester) async {
      await _open(tester, _populatedStore());
      await tester.enterText(find.byType(TextField), 'Savings');
      await tester.pumpAndSettle();
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Main Checking'), findsNothing);
      expect(find.text('Amex'), findsNothing);
      expect(find.textContaining('No account matches'), findsNothing);
      expect(find.text('+'), findsOneWidget);
    });
  });

  // ── State 4 · accounts, query with no match ──────────────────────────────
  group('state 4 · accounts, no match', () {
    testWidgets('one message, trimmed query, no quotation marks',
        (tester) async {
      await _open(tester, _populatedStore());
      await tester.enterText(find.byType(TextField), '  Revolut  ');
      await tester.pumpAndSettle();
      expect(find.textContaining('No account matches'), findsOneWidget);
      // Query is trimmed and shown; the message carries no quotation marks.
      expect(find.textContaining('Revolut'), findsOneWidget);
      for (final s in _allText(tester)) {
        expect(s.contains('""'), isFalse);
      }
      // No account rows.
      expect(find.text('Main Checking'), findsNothing);
      // Create action still exactly once, in the header.
      expect(find.text('+'), findsOneWidget);
    });

    testWidgets('a 200-character query stays on one line without exception',
        (tester) async {
      _setSize(tester, 390, 844);
      await _open(tester, _populatedStore());
      await tester.enterText(find.byType(TextField), 'z' * 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The message is a single RichText line.
      final richFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('No account matches'),
      );
      expect(richFinder, findsOneWidget);
      expect(tester.widget<RichText>(richFinder).maxLines, 1);
    });
  });

  // ── Header stability across states 2–4 ───────────────────────────────────
  testWidgets('header create action does not move as the query changes',
      (tester) async {
    _setSize(tester, 390, 844);
    await _open(tester, _populatedStore());
    final emptyQueryPos = tester.getTopLeft(find.text('New account'));
    await tester.enterText(find.byType(TextField), 'Revolut'); // no match → state 4
    await tester.pumpAndSettle();
    final noMatchPos = tester.getTopLeft(find.text('New account'));
    expect(noMatchPos, emptyQueryPos);
  });

  testWidgets('the create action appears exactly once in every state',
      (tester) async {
    // State 1
    await _open(tester, _emptyStore());
    expect(find.text('New account'), findsOneWidget);

    // States 2 → 3 → 4 on a populated store.
    await _open(tester, _populatedStore());
    expect(find.text('New account'), findsOneWidget); // 2
    await tester.enterText(find.byType(TextField), 'Savings');
    await tester.pumpAndSettle();
    expect(find.text('New account'), findsOneWidget); // 3
    await tester.enterText(find.byType(TextField), 'Revolut');
    await tester.pumpAndSettle();
    expect(find.text('New account'), findsOneWidget); // 4
  });

  // ── No overflow across widths, scale and locales ─────────────────────────
  group('layout: no overflow', () {
    const widths = [390.0, 360.0, 320.0];

    Future<void> exercise(WidgetTester tester,
        {required Locale locale, required double textScale}) async {
      // State 1
      await _open(tester, _emptyStore(), locale: locale, textScale: textScale);
      expect(tester.takeException(), isNull);
      // States 2 → 3 → 4
      await _open(tester, _populatedStore(),
          locale: locale, textScale: textScale);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'Sav');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'Revolut');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    for (final w in widths) {
      testWidgets('en @ ${w.toInt()}pt, 1.0x', (tester) async {
        _setSize(tester, w, 844);
        await exercise(tester, locale: const Locale('en'), textScale: 1.0);
      });
      testWidgets('en @ ${w.toInt()}pt, 1.3x', (tester) async {
        _setSize(tester, w, 844);
        await exercise(tester, locale: const Locale('en'), textScale: 1.3);
      });
    }

    for (final loc in const [Locale('tr'), Locale('ru')]) {
      testWidgets('${loc.languageCode} @ 320pt, 1.0x', (tester) async {
        _setSize(tester, 320, 568);
        await exercise(tester, locale: loc, textScale: 1.0);
      });
    }
  });
}
