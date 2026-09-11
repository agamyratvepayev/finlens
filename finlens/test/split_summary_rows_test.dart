import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart'
    show NumericKeypad;
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// A split transaction's category row used to read `3 categories` and nothing
/// else: to see what the three were you reopened the editor. `From` names the
/// account and `Date` shows the date; `To` alone showed a number and made you
/// open a modal to learn what you had already decided.
///
/// And a split could not be undone. `splitBalanced` refuses fewer than two
/// lines, so `Done` was dim on the way down to one, the last `×` was dim too,
/// and `Cancel` restored the split the user was trying to leave — a dead end
/// with no reachable action. The form's `result.length >= 2 ? result : null`
/// already knew how to hear "no split"; nothing could say it.
Category _cat(String id, String name, Color c) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: c,
    );

AppStore _store() => AppStore(
      accounts: [
        Account(
          id: 'a1',
          name: 'My Wallet',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 500000,
        ),
      ],
      categories: [
        _cat('c1', 'Grocery', const Color(0xFF34C759)),
        _cat('c2', 'Shopping', const Color(0xFF5E5CE6)),
        _cat('c3', 'Taxi', const Color(0xFFFF9F0A)),
        _cat('c4', 'A very long category name indeed', const Color(0xFFFF375F)),
      ],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

const _delegates = <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  TkMaterialLocalizationsDelegate(),
  TkCupertinoLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

/// The Quick Add form, mounted the way `quick_add_form_test.dart` mounts it —
/// not through `showQuickAdd`, whose route never settles.
Future<AppStore> _pumpForm(
  WidgetTester tester, {
  Locale? locale,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  bool masked = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = _store();
  if (masked) store.toggleMasked();

  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: locale ?? const Locale('en'),
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (c, ch) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: ch!,
      ),
      home: const QuickAddScreen(initialType: QuickAddType.expense),
    ),
  ));
  await tester.pump();
  return store;
}

/// Drives the real form into a split: type an amount, pick a category, open the
/// editor and apply an even split across [n] lines.
Future<void> _applySplit(WidgetTester tester, int n) async {
  final l = AppLocalizations.of(tester.element(find.byType(QuickAddScreen)));
  // Amount — the app's own keypad.
  for (final d in '300'.split('')) {
    await tester.tap(find.descendant(
        of: find.byType(NumericKeypad), matching: find.text(d)));
    await tester.pump();
  }
  // A category, so the split opens with one real line.
  await tester.tap(find.text(l.qaTo));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Grocery').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.text(l.qaSplitAction));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  for (var i = 1; i < n; i++) {
    await tester.ensureVisible(find.text(l.ssAddLine));
    await tester.pump();
    await tester.tap(find.text(l.ssAddLine));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(['Grocery', 'Shopping', 'Taxi'][i % 3]).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Adding a line makes it active and opens the keypad, and entry mode hides
  // Split evenly / Done — tap the active line again to fall back to list mode.
  if (find.byType(NumericKeypad).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.text('\u2014').last);
    await tester.pump();
    await tester.tap(find.text('\u2014').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  await tester.ensureVisible(find.text(l.ssSplitEvenly));
  await tester.pump();
  await tester.tap(find.text(l.ssSplitEvenly));
  await tester.pump();
  await tester.ensureVisible(find.widgetWithText(FilledButton, l.actionDone));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, l.actionDone));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// flutter_test's default font draws every glyph as an equal-width box, which
/// makes strings far wider than the app renders them — measuring the header
/// against it would report an overflow that does not exist. Load the real
/// Roboto the SDK ships (the app declares no font family, so Material's default
/// is what it gets) before any width is measured.
Future<bool> _loadRealFont() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return false;
  final loader = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    final f = File('${dir.path}/Roboto-$w.ttf');
    if (f.existsSync()) {
      loader.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
    }
  }
  await loader.load();
  return true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // ── §1 · the row lists its split ──────────────────────────────────────────
  testWidgets('a three-line split lists three child rows, named and in order',
      (tester) async {
    await _pumpForm(tester);
    await _applySplit(tester, 3);

    // The summary still counts.
    expect(find.text('3 categories'), findsOneWidget);

    // …and the lines are named beneath it, in order.
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((t) => ['Grocery', 'Shopping', 'Taxi'].contains(t))
        .toList();
    expect(names.length, greaterThanOrEqualTo(3),
        reason: 'every line is named — no cap, no "+N more"');

    // $300 / 3 — each line's share is shown.
    expect(find.text(r'$100.00'), findsNWidgets(3));
  });

  testWidgets('no split → no child rows, and the card is unchanged',
      (tester) async {
    await _pumpForm(tester);
    final before = tester.getSize(find.byType(TxnCard).first);

    expect(find.text('2 categories'), findsNothing);
    expect(find.text('3 categories'), findsNothing);
    // The category row alone, with nothing under it.
    expect(find.text(r'$100.00'), findsNothing);
    expect(tester.getSize(find.byType(TxnCard).first), before);
  });

  testWidgets('privacy mode masks every child amount', (tester) async {
    await _pumpForm(tester, masked: true);
    await _applySplit(tester, 3);

    expect(find.text(r'$100.00'), findsNothing,
        reason: 'a masked form must not leak the figures under the row it masks');
    expect(find.textContaining('••••'), findsWidgets);
  });

  testWidgets('tapping a child row opens the split editor', (tester) async {
    await _pumpForm(tester);
    await _applySplit(tester, 3);
    expect(find.text('Split evenly'), findsNothing, reason: 'sheet is closed');

    // Tap the line, not the summary row.
    await tester.tap(find.text('Shopping').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Split evenly'), findsOneWidget,
        reason: 'one destination — the line opens the same editor');
  });

  testWidgets('the child rows carry no chevron of their own', (tester) async {
    await _pumpForm(tester);
    await _applySplit(tester, 3);
    // The From and summary (To) rows each carry a chevron; the split lines add
    // none. Task 15: those rows open bottom sheets, so their glyph is now the
    // downward chevron — the read-only lines still add nothing, so the count
    // stays at the two field rows and never reaches the split lines.
    final chevrons = find.descendant(
      of: find.byType(TxnCard).first,
      matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
    );
    expect(chevrons.evaluate().length, lessThan(4),
        reason: 'read-only lines: no chevron, no ×, no editing in place');
  });

  // ── §2 · Remove ───────────────────────────────────────────────────────────
  testWidgets('Remove is absent while a split is being created',
      (tester) async {
    await _pumpForm(tester);
    final l = AppLocalizations.of(tester.element(find.byType(QuickAddScreen)));
    for (final d in '300'.split('')) {
      await tester.tap(find.descendant(
          of: find.byType(NumericKeypad), matching: find.text(d)));
      await tester.pump();
    }
    await tester.tap(find.text(l.qaTo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Grocery').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(l.qaSplitAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Cancel'), findsWidgets);
    expect(find.text('Remove'), findsNothing,
        reason: 'Cancel already means "never mind" on a first split');
  });

  testWidgets('Remove is present when the sheet opened on an existing split',
      (tester) async {
    await _pumpForm(tester);
    await _applySplit(tester, 3);

    await tester.tap(find.text('3 categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
  });

  // The regression test for the dead branch.
  testWidgets('Remove returns the form to its pre-split category',
      (tester) async {
    await _pumpForm(tester);
    await _applySplit(tester, 3);
    expect(find.text('3 categories'), findsOneWidget);

    await tester.tap(find.text('3 categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The count is gone, the child rows with it, and the row holds the
    // category it carried before the split.
    expect(find.text('3 categories'), findsNothing);
    expect(find.text('Grocery'), findsOneWidget);
    expect(find.text(r'$100.00'), findsNothing);
    // No confirmation, no undo bar.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Remove with no pre-split category leaves Choose category',
      (tester) async {
    await _pumpForm(tester);
    final l = AppLocalizations.of(tester.element(find.byType(QuickAddScreen)));
    // Amount only — open Split before ever choosing a category.
    for (final d in '300'.split('')) {
      await tester.tap(find.descendant(
          of: find.byType(NumericKeypad), matching: find.text(d)));
      await tester.pump();
    }
    await tester.tap(find.text(l.qaSplitAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Give it two real lines so Remove appears on the second open.
    await tester.tap(find.text('Choose a category').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Grocery').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text(l.ssAddLine));
    await tester.pump();
    await tester.tap(find.text(l.ssAddLine));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Shopping').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Adding a line opens the keypad; entry mode hides Split evenly / Done.
    if (find.byType(NumericKeypad).evaluate().isNotEmpty) {
      await tester.tap(find.text('\u2014').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(find.text(l.ssSplitEvenly));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l.actionDone));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('2 categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The row falls back correctly and the Save blocker will fire.
    expect(find.text('Choose category'), findsWidgets);
  });

  // ── §5 · layout ───────────────────────────────────────────────────────────
  testWidgets('an eight-line split lays out at 320×568 with no overflow',
      (tester) async {
    await _pumpForm(tester, size: const Size(320, 568));
    await _applySplit(tester, 8);

    expect(tester.takeException(), isNull);
    expect(find.text('8 categories'), findsOneWidget);
  });

  for (final locale in const [
    Locale('en'),
    Locale('tk'),
    Locale('ru'),
    Locale('tr')
  ]) {
    for (final scale in const [1.0, 1.3]) {
    testWidgets(
        'the split header fits Split + Remove + Cancel at 320 in '
        '${locale.languageCode} @ ${(scale * 100).toInt()}%', (tester) async {
      expect(await _loadRealFont(), isTrue,
          reason: 'the SDK Roboto is needed for a representative measurement');
      await _pumpForm(tester,
          size: const Size(320, 568), locale: locale, textScale: scale);
      await _applySplit(tester, 3);

      final l = AppLocalizations.of(
          tester.element(find.byType(QuickAddScreen)));
      await tester.tap(find.text(l.qaSplitCategories(3)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l.ssRemove), findsOneWidget);
      expect(find.text(l.actionCancel), findsWidgets);

      // The title sits in an Expanded, so it yields space rather than
      // colliding; the real question is how much room it has left once the two
      // actions have taken theirs, and whether the header still fits 320.
      final title = tester.getRect(find.text(l.ssSplit));
      final remove = tester.getRect(find.text(l.ssRemove));
      final cancel = tester.getRect(find.text(l.actionCancel).last);
      final painter = TextPainter(
        text: TextSpan(
          text: l.ssSplit,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final slack = title.width - painter.width;
      debugPrint('HDR|${locale.languageCode}|${(scale * 100).toInt()}|titleBox=${title.width.toStringAsFixed(1)}'
          '|titleInk=${painter.width.toStringAsFixed(1)}'
          '|slack=${slack.toStringAsFixed(1)}'
          '|remove=[${remove.left.toStringAsFixed(1)},${remove.right.toStringAsFixed(1)}]'
          '|cancel.left=${cancel.left.toStringAsFixed(1)}'
          '|cancel.right=${cancel.right.toStringAsFixed(1)}');

      expect(cancel.left, greaterThanOrEqualTo(remove.right),
          reason: 'Remove and Cancel must not overlap');
      expect(cancel.right, lessThanOrEqualTo(320),
          reason: 'the header must stay on a 320pt screen');
      expect(slack, greaterThanOrEqualTo(0),
          reason: 'the title still has room for its own ink');
      expect(tester.takeException(), isNull);
    });
    }
  }
}
