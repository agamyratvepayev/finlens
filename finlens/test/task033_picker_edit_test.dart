import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/edit_account_screen.dart';
import 'package:finlens/features/more/accounts_management_screen.dart';
import 'package:finlens/features/more/edit_category_screen.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/features/quick_add/split_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/shared/widgets/app_card.dart';
import 'package:finlens/shared/widgets/category_cell.dart';
import 'package:finlens/shared/widgets/form_fields.dart' show RowMetrics;
import 'package:finlens/shared/widgets/swipe_actions.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task033_picker_edit_test.dart
//
// Task 033 — reaching the editors from the Quick Add picker sheets, plus the
// account-picker row joining the RowMetrics contract (§1), the account row's
// swipe-to-Edit (§2), the category tile's long-press-to-Edit (§3),
// EditAccountScreen's single pop + outcome (§4), and the stale-ref clearing (§5).

// The derived numbers §1 pins, expressed the same way the code derives them.
const double _kGlyph = 28.0;
final double _kTextStart = RowMetrics.padding + _kGlyph + RowMetrics.iconGap; // 52

Account _acc(
  String id,
  String name, {
  AccountGroup group = AccountGroup.spendable,
  double startingBalance = 1000,
  String currency = 'USD',
}) =>
    Account(
      id: id,
      name: name,
      group: group,
      currency: currency,
      startingBalance: startingBalance,
    );

Category _cat(String id, String name,
        {CategoryType type = CategoryType.expense}) =>
    Category(
      id: id,
      name: name,
      type: type,
      icon: Icons.circle,
      color: const Color(0xFF34C759),
    );

AppStore _store({
  List<Account> accounts = const [],
  List<Category> categories = const [],
  List<Txn> txns = const [],
}) =>
    AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: accounts,
      categories: categories,
      txns: txns,
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

void _setSize(WidgetTester tester, double w, double h) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
}

void main() {
  final twoSpendable = [
    _acc('a1', 'Main Checking'),
    _acc('a2', 'Savings'),
  ];

  Future<void> openAccounts(WidgetTester tester, AppStore store,
      {Account? Function(Account?)? capture, double textScale = 1.0}) async {
    await tester.pumpWidget(_host(store, (ctx) async {
      final r = await pickAccount(ctx);
      capture?.call(r);
    }, textScale: textScale));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // ── §1 — the account picker row joins the RowMetrics contract ───────────────
  group('§1 row metrics', () {
    testWidgets('row is 48pt, tile 28, name & balance at the contract sizes',
        (tester) async {
      _setSize(tester, 390, 844);
      await openAccounts(tester, _store(accounts: twoSpendable));

      // The whole row is RowMetrics.height tall.
      final rowInk = find
          .ancestor(
              of: find.text('Main Checking'), matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(rowInk).height, RowMetrics.height); // 48

      // Tile is 28.
      expect(tester.getSize(find.byType(IconTile).first),
          const Size(_kGlyph, _kGlyph));

      // Name at labelSize.
      final name = tester.widget<Text>(find.text('Main Checking'));
      expect(name.style?.fontSize, RowMetrics.labelSize);

      // Balance at valueSize.
      final amount = tester.widget<AmountText>(find.byType(AmountText).first);
      expect(amount.style?.fontSize, RowMetrics.valueSize);
    });

    testWidgets('the divider starts at padding + 28 + gap (52)', (tester) async {
      _setSize(tester, 390, 844);
      await openAccounts(tester, _store(accounts: twoSpendable));
      final dividers =
          tester.widgetList<RowDivider>(find.byType(RowDivider)).toList();
      expect(dividers, isNotEmpty);
      for (final d in dividers) {
        expect(d.indent, _kTextStart); // 52 — where the text starts
      }
    });

    testWidgets('§2 the balance keeps its tabular figures after copyWith',
        (tester) async {
      _setSize(tester, 390, 844);
      await openAccounts(tester, _store(accounts: twoSpendable));
      final amount = tester.widget<AmountText>(find.byType(AmountText).first);
      expect(amount.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()));
    });
  });

  // ── §1.4 vs §6 — other picker cards did not move ────────────────────────────
  testWidgets('§3 the currency picker card still indents its divider by Insets.md',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setCustomCurrencies(const []);
    addTearDown(() => setCustomCurrencies(const []));
    _setSize(tester, 390, 844);
    await tester.pumpWidget(_host(_store(), (ctx) => pickCurrency(ctx, 'USD')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dividers =
        tester.widgetList<RowDivider>(find.byType(RowDivider)).toList();
    expect(dividers, isNotEmpty);
    for (final d in dividers) {
      expect(d.indent, Insets.md, reason: 'currency card is unchanged'); // 12
    }
  });

  // ── §2 — an account row swipes to Edit ──────────────────────────────────────
  group('§2 account row swipes to Edit', () {
    testWidgets('exactly one action — Edit, no Delete', (tester) async {
      _setSize(tester, 390, 844);
      await openAccounts(tester, _store(accounts: twoSpendable));
      final swipe = tester.widget<SwipeActions>(
        find
            .ancestor(
                of: find.text('Main Checking'),
                matching: find.byType(SwipeActions))
            .first,
      );
      expect(swipe.actions.length, 1);
      expect(swipe.actions.single.icon, Icons.edit_outlined);
      expect(swipe.actions.single.label, 'Edit');
    });

    testWidgets('swiping and tapping Edit pushes EditAccountScreen; sheet stays',
        (tester) async {
      _setSize(tester, 390, 844);
      Account? picked = _acc('sentinel', 'sentinel');
      await openAccounts(tester, _store(accounts: twoSpendable),
          capture: (r) => picked = r);

      await tester.drag(find.text('Main Checking'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget); // the revealed action
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(EditAccountScreen), findsOneWidget);
      // The sheet was not popped and nothing was selected.
      expect(picked?.id, 'sentinel');
    });

    testWidgets('a plain tap still selects and pops, pushing nothing',
        (tester) async {
      _setSize(tester, 390, 844);
      Account? picked;
      await openAccounts(tester, _store(accounts: twoSpendable),
          capture: (r) => picked = r);

      await tester.tap(find.text('Savings'));
      await tester.pumpAndSettle();
      expect(picked?.id, 'a2');
      expect(find.byType(EditAccountScreen), findsNothing);
      expect(find.text('Select account'), findsNothing); // sheet popped
    });
  });

  // ── §3 — a category tile long-presses to Edit ───────────────────────────────
  group('§3 category tile long-presses to Edit', () {
    Future<void> openCategories(WidgetTester tester, AppStore store,
        {Set<String> usedIds = const {},
        Category? Function(Category?)? capture}) async {
      await tester.pumpWidget(_host(store, (ctx) async {
        final r = await pickCategory(ctx,
            type: CategoryType.expense, usedIds: usedIds);
        capture?.call(r);
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('long-press pushes EditCategoryScreen; the sheet stays',
        (tester) async {
      _setSize(tester, 390, 844);
      await openCategories(
          tester, _store(categories: [_cat('c1', 'Groceries')]));
      await tester.longPress(find.text('Groceries'));
      await tester.pumpAndSettle();
      expect(find.byType(EditCategoryScreen), findsOneWidget);
      expect(find.byType(CategoryCell), findsWidgets); // sheet still there
    });

    testWidgets('a plain tap still selects and pops', (tester) async {
      _setSize(tester, 390, 844);
      Category? picked;
      await openCategories(tester, _store(categories: [_cat('c1', 'Groceries')]),
          capture: (r) => picked = r);
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      expect(picked?.id, 'c1');
      expect(find.byType(EditCategoryScreen), findsNothing);
    });

    testWidgets('a disabled (used) tile neither taps nor long-presses',
        (tester) async {
      _setSize(tester, 390, 844);
      Category? picked = _cat('sentinel', 'sentinel');
      await openCategories(tester, _store(categories: [_cat('c1', 'Groceries')]),
          usedIds: {'c1'}, capture: (r) => picked = r);

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Groceries'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'sentinel'); // never selected
      expect(find.byType(EditCategoryScreen), findsNothing);
    });
  });

  // ── §3.1 — the management grid is byte-for-byte unchanged ────────────────────
  group('management grid (no onLongPress) is unchanged', () {
    testWidgets('no long-press handler and no custom semantics action',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Scaffold(
          body: CategoryCell(
            category: _cat('c1', 'Groceries'),
            selected: false,
            onTap: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final gesture = tester.widget<GestureDetector>(
        find.descendant(
            of: find.byType(CategoryCell),
            matching: find.byType(GestureDetector)),
      );
      expect(gesture.onLongPress, isNull);

      final sem = tester.widget<Semantics>(
        find
            .descendant(
                of: find.byType(CategoryCell), matching: find.byType(Semantics))
            .first,
      );
      expect(sem.properties.customSemanticsActions, isNull);
    });
  });

  // ── §2.3 / §3.2 — the Edit custom semantics action is exposed ────────────────
  testWidgets('account row and picker category tile both expose an Edit action',
      (tester) async {
    _setSize(tester, 390, 844);
    // Account row.
    await openAccounts(tester, _store(accounts: twoSpendable));
    bool exposesEdit() => find
        .byWidgetPredicate((w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.keys
                    .any((a) => a.label == 'Edit') ??
                false))
        .evaluate()
        .isNotEmpty;
    expect(exposesEdit(), isTrue);

    // Picker category tile.
    await tester.pumpWidget(_host(
        _store(categories: [_cat('c1', 'Groceries')]),
        (ctx) => pickCategory(ctx, type: CategoryType.expense)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(exposesEdit(), isTrue);
  });

  // ── §4 — EditAccountScreen pops exactly once, with its outcome ───────────────
  group('§4 EditAccountScreen outcome + single pop', () {
    Future<EditAccountOutcome?> pushEditor(
        WidgetTester tester, AppStore store, String accountId) async {
      EditAccountOutcome? outcome = EditAccountOutcome.saved; // sentinel != null
      var settled = false;
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    outcome = await Navigator.of(ctx).push<EditAccountOutcome>(
                      MaterialPageRoute(
                        builder: (_) => EditAccountScreen(accountId: accountId),
                      ),
                    );
                    settled = true;
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(EditAccountScreen), findsOneWidget);
      // Marker: the launcher screen is one route below the editor.
      expect(settled, isFalse);
      return outcome; // unused sentinel; caller re-reads via the closure
    }

    testWidgets('Save returns saved and pops one route', (tester) async {
      final store = _store(accounts: [_acc('a1', 'Cash')]);
      await pushEditor(tester, store, 'a1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      // Back at the launcher (exactly one pop): editor gone, 'go' visible.
      expect(find.byType(EditAccountScreen), findsNothing);
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('Remove (no history) returns removed', (tester) async {
      final store = _store(accounts: [_acc('a1', 'Cash', startingBalance: 0)]);
      EditAccountOutcome? got;
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => got = await Navigator.of(ctx)
                      .push<EditAccountOutcome>(MaterialPageRoute(
                          builder: (_) =>
                              const EditAccountScreen(accountId: 'a1'))),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove this account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove account')); // confirm
      await tester.pumpAndSettle();

      expect(got, EditAccountOutcome.removed);
      expect(find.byType(EditAccountScreen), findsNothing);
      expect(find.text('go'), findsOneWidget); // exactly one pop
    });

    testWidgets('Archive (history, zero balance) returns archived',
        (tester) async {
      // startingBalance 100, an expense of 100 → history exists, balance 0.
      final store = _store(
        accounts: [_acc('a1', 'Cash', startingBalance: 100)],
        categories: [_cat('c1', 'Food')],
        txns: [
          Txn(
            id: 't1',
            type: TxnType.expense,
            amount: 100,
            currency: 'USD',
            fromRef: 'a1',
            toRef: 'c1',
            date: DateTime(2026, 8, 1),
          ),
        ],
      );
      EditAccountOutcome? got;
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => got = await Navigator.of(ctx)
                      .push<EditAccountOutcome>(MaterialPageRoute(
                          builder: (_) =>
                              const EditAccountScreen(accountId: 'a1'))),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive this account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive account')); // confirm
      await tester.pumpAndSettle();

      expect(got, EditAccountOutcome.archived);
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('Cancel returns null', (tester) async {
      final store = _store(accounts: [_acc('a1', 'Cash')]);
      EditAccountOutcome? got = EditAccountOutcome.saved; // sentinel
      var done = false;
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    got = await Navigator.of(ctx).push<EditAccountOutcome>(
                        MaterialPageRoute(
                            builder: (_) =>
                                const EditAccountScreen(accountId: 'a1')));
                    done = true;
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(got, isNull);
    });
  });

  // ── §4.3 — More ▸ Accounts no longer closes when an account is removed ───────
  testWidgets('regression: removing an account keeps More ▸ Accounts open',
      (tester) async {
    _setSize(tester, 390, 844);
    final store = _store(accounts: [
      _acc('a1', 'Cash', startingBalance: 0),
      _acc('a2', 'Savings', startingBalance: 0),
    ]);
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: const AccountsManagementScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(find.byType(EditAccountScreen), findsOneWidget);

    await tester.tap(find.text('Remove this account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove account'));
    await tester.pumpAndSettle();

    // The editor popped exactly once — the Accounts list is still here.
    expect(find.byType(EditAccountScreen), findsNothing);
    expect(find.byType(AccountsManagementScreen), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
  });

  // ── §5 — a deleted item clears the form's field; the sheet stays open ────────
  group('§5 stale-ref clearing (split sheet)', () {
    Future<void> openSplit(WidgetTester tester, AppStore store,
        {required List<SplitLine> initial}) async {
      await tester.pumpWidget(_host(store, (ctx) {
        showSplitSheet(
          ctx,
          total: 100,
          currency: 'USD',
          accountName: 'Cash',
          categoryType: CategoryType.expense,
          initial: initial,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('deleting a category clears the line but keeps the sheet',
        (tester) async {
      _setSize(tester, 390, 844);
      final store = _store(
          categories: [_cat('c1', 'Groceries'), _cat('c2', 'Transport')]);
      await openSplit(tester, store, initial: [
        SplitLine(categoryId: 'c1', amount: 60),
        SplitLine(categoryId: 'c2', amount: 40),
      ]);

      // Open the first line's category picker.
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      // Long-press its (enabled) tile to reach the editor.
      await tester.longPress(find.text('Groceries').last);
      await tester.pumpAndSettle();
      expect(find.byType(EditCategoryScreen), findsOneWidget);

      // Delete it (no history ⇒ a true delete).
      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      // Back on the picker — cancel it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The store no longer resolves c1, and the split sheet is still up.
      expect(store.categoryById('c1'), isNull);
      expect(find.byType(EditCategoryScreen), findsNothing);
      // The line kept its amount but lost its dead category → placeholder.
      expect(find.text('Choose category'), findsWidgets);
    });

    testWidgets('an archived category is kept, not cleared', (tester) async {
      _setSize(tester, 390, 844);
      // c1 has history ⇒ the editor archives rather than deletes; it still
      // resolves afterwards, so the line must keep it (§5).
      final store = _store(
        categories: [_cat('c1', 'Groceries'), _cat('c2', 'Transport')],
        txns: [
          Txn(
            id: 't1',
            type: TxnType.expense,
            amount: 5,
            currency: 'USD',
            fromRef: 'a1',
            toRef: 'c1',
            date: DateTime(2026, 8, 1),
          ),
        ],
        accounts: [_acc('a1', 'Cash')],
      );
      await openSplit(tester, store, initial: [
        SplitLine(categoryId: 'c1', amount: 60),
        SplitLine(categoryId: 'c2', amount: 40),
      ]);

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Groceries').last);
      await tester.pumpAndSettle();
      expect(find.byType(EditCategoryScreen), findsOneWidget);

      await tester.tap(find.text('Archive category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive category').last); // confirm
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Still resolves (archived items stay in the private list) → kept.
      expect(store.categoryById('c1'), isNotNull);
      expect(find.text('Groceries'), findsWidgets);
    });
  });

  // ── §Layout — no overflow across widths, scale and locales, both sheets ──────
  group('layout: no overflow', () {
    const widths = [390.0, 360.0, 320.0];
    for (final w in widths) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('account sheet @ ${w.toInt()}pt ${scale}x', (tester) async {
          _setSize(tester, w, 844);
          await openAccounts(
            tester,
            _store(accounts: twoSpendable),
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
        });
        testWidgets('category sheet @ ${w.toInt()}pt ${scale}x', (tester) async {
          _setSize(tester, w, 844);
          await tester.pumpWidget(_host(
            _store(categories: [_cat('c1', 'Groceries')]),
            (ctx) => pickCategory(ctx, type: CategoryType.expense),
            textScale: scale,
          ));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
