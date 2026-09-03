import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/theme/app_theme.dart';

/// Covers the Note row and Note sheet (spec §3–§8). These drive the real UI:
/// tap the note row, type in the sheet, commit or discard, and assert what the
/// row and sheet show. The amount hero animates a cursor, so every wait uses a
/// bounded `pump` rather than `pumpAndSettle`.
Widget _app(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const QuickAddScreen(initialType: QuickAddType.expense),
      ),
    );

const _settle = Duration(milliseconds: 400);

/// The note row's icon is a stable handle across empty and filled states.
final _noteRow = find.byIcon(Icons.notes_rounded);

Future<void> _openNote(WidgetTester tester) async {
  await tester.tap(_noteRow);
  await tester.pump();
  await tester.pump(_settle);
}

Future<void> _setNote(WidgetTester tester, String text) async {
  await _openNote(tester);
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.text('Done'));
  await tester.pump();
  await tester.pump(_settle);
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

  // §8 regression test. On the pre-change row this fails: the row rendered a
  // literal 'Note' label. After the change the label is gone and only the note
  // text is present.
  testWidgets('filled row shows the note, not a "Note" label', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'Dinner with Aygul');

    expect(find.text('Note'), findsNothing); // sheet closed → no title, no label
    expect(find.text('Dinner with Aygul'), findsOneWidget);
  });

  testWidgets('empty row shows "Add a note"', (tester) async {
    await pumpForm(tester);
    expect(find.text('Add a note'), findsOneWidget);
  });

  testWidgets('an overflowing note renders on at most two lines', (tester) async {
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

  testWidgets('sheet shows the prompt, never "Optional"', (tester) async {
    await pumpForm(tester);
    await _openNote(tester);

    expect(find.text('What was this for?'), findsOneWidget);
    expect(find.text('Optional'), findsNothing);
  });

  testWidgets('typing then Cancel leaves the note unchanged', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'Groceries');

    await _openNote(tester);
    await tester.enterText(find.byType(TextField), 'Something else');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(_settle);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Something else'), findsNothing);
  });

  testWidgets('clearing an existing note then Done removes it', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'Groceries');
    await _setNote(tester, '');

    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Add a note'), findsOneWidget);
  });

  testWidgets('whitespace-only note saves as no note', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, '     ');

    expect(find.text('Add a note'), findsOneWidget);
  });

  testWidgets('counter is absent at 100 chars, present at 240', (tester) async {
    await pumpForm(tester);

    await _openNote(tester);
    await tester.enterText(find.byType(TextField), 'a' * 100);
    await tester.pump();
    expect(find.textContaining('/'), findsNothing);

    await tester.enterText(find.byType(TextField), 'a' * 240);
    await tester.pump();
    expect(find.text('240 / 280'), findsOneWidget);
  });

  testWidgets('input beyond the limit is rejected, existing text intact',
      (tester) async {
    await pumpForm(tester);

    await _openNote(tester);
    await tester.enterText(find.byType(TextField), 'a' * 300);
    await tester.pump();

    // Enforced at 280: the counter proves the field capped the input.
    expect(find.text('280 / 280'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, 280);
  });

  testWidgets('newlines in the note render as spaces on the row', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'line one\nline two');

    expect(find.text('line one line two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('row semantics announce the full note', (tester) async {
    await pumpForm(tester);
    await _setNote(tester, 'Split with Aygul for the shared taxi home');

    expect(
      find.bySemanticsLabel('Split with Aygul for the shared taxi home'),
      findsOneWidget,
    );
  });

  for (final entry in const <String, Size>{
    '390x844': Size(390, 844),
    '360x640': Size(360, 640),
    '320x568': Size(320, 568),
  }.entries) {
    testWidgets('row and sheet lay out with no overflow at ${entry.key}',
        (tester) async {
      await pumpForm(tester, size: entry.value);
      await _setNote(tester, 'A reasonably long note that wraps to two lines '
          'so the row must grow to hold it without overflowing.');
      await _openNote(tester);
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
