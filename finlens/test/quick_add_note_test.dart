import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/quick_add_note_test.dart

/// Covers the inline Note row (inline-note spec §1–§7). The old modal Note
/// sheet is gone: tapping the row pushes no route — it focuses a TextField in
/// place, bound straight to the form's controller, committing as the user
/// types. The amount hero animates a cursor, so every wait uses a bounded
/// `pump` rather than `pumpAndSettle`.
Widget _app(AppStore store, {NavigatorObserver? observer, Txn? editing}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        navigatorObservers: [?observer],
        home: QuickAddScreen(
          initialType: QuickAddType.expense,
          editing: editing,
        ),
      ),
    );

/// Minimal savable fixture: one account, one expense category, fixed ids so
/// the form can be pre-filled and Save needs no pickers.
AppStore _store() => AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
      ],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

const _settle = Duration(milliseconds: 400);

/// The note row's icon is a stable handle across empty, filled and editing
/// states.
final _noteRow = find.byIcon(Icons.notes_rounded);

/// Tap the row, let the TextField enter the tree, let the deferred focus
/// request land. On short screens the row starts below the fold (the keypad
/// eats most of the height), so it is scrolled into view first.
Future<void> _focusNote(WidgetTester tester) async {
  await tester.ensureVisible(_noteRow);
  await tester.pump(_settle);
  await tester.tap(_noteRow);
  await tester.pump(); // rebuild: the TextField replaces the preview
  await tester.pump(); // post-frame focus request lands
  await tester.pump(_settle);
}

Future<void> _typeNote(WidgetTester tester, String text) async {
  await _focusNote(tester);
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _unfocusNote(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump(_settle);
}

/// Type and commit — inline there is no Done: losing focus just reveals the
/// preview; the text was already committed keystroke by keystroke.
Future<void> _setNote(WidgetTester tester, String text) async {
  await _typeNote(tester, text);
  await _unfocusNote(tester);
}

class _PushCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  Future<void> pumpForm(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pump(_settle);
  }

  // §7 — the headline regression: no route is pushed; the row itself becomes
  // the editor.
  testWidgets('tapping the note pushes no route and focuses a TextField',
      (tester) async {
    final observer = _PushCounter();
    await tester.pumpWidget(_app(buildSeedStore(), observer: observer));
    await tester.pump(_settle);
    final pushesBefore = observer.pushes; // the home route's own push

    await _focusNote(tester);

    expect(observer.pushes, pushesBefore); // navigator stack depth unchanged
    expect(find.byType(BottomSheet), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  // §1 — the row edits `_note` directly; typing needs no Done to commit.
  testWidgets('typed text is committed with no Done step', (tester) async {
    await pumpForm(tester);
    await _typeNote(tester, 'Committed as typed');
    await _unfocusNote(tester);

    expect(find.text('Committed as typed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsNothing);
  });

  testWidgets('filled row shows the note, not a "Note" label', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'Dinner with Aygul');

    expect(find.text('Note'), findsNothing);
    expect(find.text('Dinner with Aygul'), findsOneWidget);
  });

  testWidgets('empty row shows "Add a note"', (tester) async {
    await pumpForm(tester);
    expect(find.text('Add a note'), findsOneWidget);
  });

  // §6 — focusing clears the qaAddNote hint: the editor holds no hint text.
  testWidgets('focused empty field drops the "Add a note" hint',
      (tester) async {
    await pumpForm(tester);
    await _focusNote(tester);

    expect(find.text('Add a note'), findsNothing);
    expect(find.text('What was this for?'), findsNothing); // the sheet's prompt
  });

  testWidgets('an overflowing note renders on at most two lines',
      (tester) async {
    await pumpForm(tester);
    final long = List.filled(40, 'word').join(' ');
    await _setNote(tester, long);

    // The row's value carries the full string (semantics read it whole); the
    // Text caps rendering at two lines with an ellipsis.
    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  // §1 — the chevron goes: nothing opens any more.
  testWidgets('the note row has no chevron, its siblings keep theirs',
      (tester) async {
    await pumpForm(tester);
    final card = find.ancestor(
      of: _noteRow,
      matching: find.byType(Column),
    );
    // Date, Tags and Repeat still carry a chevron in the OPTIONAL card; if the
    // note row still had one there would be four.
    expect(
      find.descendant(
        of: card.first,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('clearing an existing note removes it', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'Groceries');
    await _setNote(tester, '');

    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Add a note'), findsOneWidget);
  });

  testWidgets('whitespace-only note shows as no note', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, '     ');

    expect(find.text('Add a note'), findsOneWidget);
  });

  // §1 — the threshold boundary: 280 − 229 = 51 hides it, 280 − 230 = 50
  // shows it.
  testWidgets('counter is absent at 229 chars, present at 230',
      (tester) async {
    await pumpForm(tester);
    await _focusNote(tester);

    await tester.enterText(find.byType(TextField), 'a' * 229);
    await tester.pump();
    expect(find.textContaining('/'), findsNothing);

    await tester.enterText(find.byType(TextField), 'a' * 230);
    await tester.pump();
    expect(find.text('230 / 280'), findsOneWidget);
  });

  testWidgets('input beyond the limit is rejected, existing text intact',
      (tester) async {
    await pumpForm(tester);
    await _focusNote(tester);

    await tester.enterText(find.byType(TextField), 'a' * 300);
    await tester.pump();

    // Enforced at 280: the counter proves the field capped the input.
    expect(find.text('280 / 280'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, 280);
  });

  // §1 — newlines survive in the controller; collapsing is a display rule for
  // the unfocused preview only.
  testWidgets('newlines survive editing; the row previews them as spaces',
      (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'line one\nline two');

    expect(find.text('line one line two'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Re-focusing shows the real text, breaks intact.
    await _focusNote(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'line one\nline two');
  });

  testWidgets('row semantics announce the full note', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'Split with Aygul for the shared taxi home');

    expect(
      find.bySemanticsLabel('Split with Aygul for the shared taxi home'),
      findsOneWidget,
    );
  });

  // §2 — one at a time: focusing the note closes the keypad; tapping the
  // amount hero closes the keyboard and reopens the keypad.
  testWidgets('keypad and keyboard are never open together', (tester) async {
    await pumpForm(tester);
    // A new expense opens with the keypad up.
    expect(find.byType(NumericKeypad), findsOneWidget);

    await _focusNote(tester);
    expect(find.byType(NumericKeypad), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );

    await tester.tap(find.byType(NumericHeroCard));
    await tester.pump();
    await tester.pump(_settle);
    expect(find.byType(NumericKeypad), findsOneWidget);
    // The note dropped back to its preview; no TextField remains.
    expect(find.byType(TextField), findsNothing);
  });

  // §8 — the regression that matters: same keystrokes, same saved string as
  // the modal produced. Refs pre-filled so Save needs no pickers; the keypad
  // supplies the amount; Save is tapped with the note still focused (§6).
  testWidgets('Save writes the typed note, breaks intact, while focused',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const QuickAddScreen(
          initialType: QuickAddType.expense,
          fixedFromAccountId: 'a1',
          fixedToAccountId: 'g',
        ),
      ),
    ));
    await tester.pump(_settle);
    await tester.tap(find.text('5'));
    await tester.pump();

    await _typeNote(tester, '  Dinner with Aygul\nsplit later  ');
    await tester.tap(find.text('Save'));
    await tester.pump();

    // Trimmed at the edges exactly as the modal path was; the interior line
    // break survives.
    expect(store.txns.single.note, 'Dinner with Aygul\nsplit later');
  });

  // §6 — editing an existing transaction: the seeded note shows in the row and
  // is edited in place.
  testWidgets('editing seeds the row and edits the note in place',
      (tester) async {
    final store = _store();
    final txn = store.addTxn(
      type: TxnType.expense,
      amount: 5,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'g',
      date: AppStore.today,
      note: 'seeded note',
    );
    await tester.pumpWidget(_app(store, editing: txn));
    await tester.pump(_settle);

    expect(find.text('seeded note'), findsOneWidget);

    await _typeNote(tester, 'seeded note, edited');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(txn.note, 'seeded note, edited');
  });

  // §6 — switching type while the note is focused unfocuses it cleanly.
  testWidgets('switching type while focused unfocuses without exception',
      (tester) async {
    await pumpForm(tester);
    await _focusNote(tester);

    await tester.tap(find.text('Expense')); // the type pill
    await tester.pump();
    await tester.pump(_settle);
    await tester.tap(find.text('Transfer'));
    await tester.pump();
    await tester.pump(_settle);

    expect(tester.takeException(), isNull);
    // The note dropped back to its preview: no TextField on a transfer form.
    expect(find.byType(TextField), findsNothing);
  });

  // §2 — Cancel while the note is focused: keyboard released, sheet closed,
  // nothing thrown.
  testWidgets('Cancel with the note focused pops cleanly', (tester) async {
    await tester.pumpWidget(StoreScope(
      store: buildSeedStore(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showQuickAdd(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(_settle);

    await _focusNote(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(_settle);

    expect(find.byType(QuickAddScreen), findsNothing);
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()));
    expect(tester.takeException(), isNull);
  });

  for (final entry in const <String, Size>{
    '390x844': Size(390, 844),
    '360x640': Size(360, 640),
    '320x568': Size(320, 568),
  }.entries) {
    testWidgets('row lays out with no overflow at ${entry.key}',
        (tester) async {
      await pumpForm(tester, size: entry.value);
      await _setNote(tester, 'A reasonably long note that wraps to two lines '
          'so the row must grow to hold it without overflowing.');
      // Re-open the editor: the outlined multi-line field must fit too.
      await _focusNote(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no overflow at 130% text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(buildSeedStore()),
      ),
    );
    await tester.pump(_settle);
    await _setNote(tester, 'A long enough note to force the second line.');
    expect(tester.takeException(), isNull);
  });
}
