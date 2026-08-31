import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/more/more_screen.dart';
import 'package:finlens/features/more/tag_management_screen.dart';
import 'package:finlens/features/more/widgets/split_count_row.dart';
import 'package:finlens/features/planner/archive_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// The More screen as a settings page (more-screen-settings spec §11):
/// the two-destination split row, Archive at zero, the removed rows, and the
/// counts-are-not-money rule.
///
/// Note: `flutter test` hangs on the dev machine, so these were written but not
/// run there; verify by running this file yourself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // The footer reads PackageInfo; without a mock the platform channel is
    // absent under the test binding.
    PackageInfo.setMockInitialValues(
      appName: 'FinLens',
      packageName: 'tech.codehammer.finlens',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Widget app(
    AppStore store, {
    Locale locale = const Locale('en'),
    double scale = 1.0,
    Size size = const Size(390, 844),
  }) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(body: MoreScreen()),
            ),
          ),
        ),
      );

  // A store with nothing archived: two accounts, two live categories, no tags.
  AppStore noArchiveStore() => AppStore(
        accounts: [
          Account(
              id: 'a1',
              name: 'Cash',
              group: AccountGroup.spendable,
              currency: 'USD',
              startingBalance: 0),
        ],
        categories: [
          Category(
              id: 'c1',
              name: 'Food',
              type: CategoryType.expense,
              icon: Icons.fastfood_rounded,
              color: Colors.red),
          Category(
              id: 'c2',
              name: 'Salary',
              type: CategoryType.income,
              icon: Icons.payments_rounded,
              color: Colors.green),
        ],
        txns: [],
        goals: [],
        tasks: [],
      );

  // ── §3 — the split row's two destinations ──────────────────────────────────
  group('split row destinations', () {
    testWidgets('Tags half opens TagManagementScreen', (tester) async {
      final store = buildSeedStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(l.moreTags));
      await tester.pumpAndSettle();

      expect(find.byType(TagManagementScreen), findsOneWidget);
    });

    testWidgets('Categories half opens the picker, not Tags', (tester) async {
      final store = buildSeedStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(l.moreCategories));
      await tester.pumpAndSettle();

      expect(find.byType(TagManagementScreen), findsNothing);
      // The category picker's search hint proves it, not Tags, opened.
      expect(find.text(l.qaSearchCategories), findsOneWidget);
    });

    testWidgets('a tap at the divider left edge opens Categories, not Tags',
        (tester) async {
      final store = buildSeedStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // 320 pt — the tightest width the app supports, and where the cells are
      // narrowest around the divider.
      await tester.pumpWidget(app(store, size: const Size(320, 640)));
      await tester.pump(const Duration(milliseconds: 300));

      final rect = tester.getRect(find.byType(SplitCountRow));
      // Just left of the centred divider → the Categories cell.
      await tester.tapAt(Offset(rect.center.dx - 2, rect.center.dy));
      await tester.pumpAndSettle();

      expect(find.byType(TagManagementScreen), findsNothing);
      expect(find.text(l.qaSearchCategories), findsOneWidget);
    });
  });

  // ── §4 — the Archive row at zero ────────────────────────────────────────────
  group('Archive row at zero', () {
    testWidgets('renders 0 and still pushes the Archive empty state',
        (tester) async {
      final store = noArchiveStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(store.archivedCount, 0);

      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      // The 0 belongs to the Archive row specifically, not the split counts.
      final archiveRow = find.ancestor(
        of: find.text(l.moreArchive),
        matching: find.byType(InkWell),
      );
      expect(archiveRow, findsOneWidget);
      expect(
        find.descendant(of: archiveRow, matching: find.text('0')),
        findsOneWidget,
      );

      await tester.tap(archiveRow);
      await tester.pumpAndSettle();

      expect(find.byType(ArchiveScreen), findsOneWidget);
      expect(find.text(l.arEmpty), findsOneWidget);
    });
  });

  // ── §11 — the removed rows are gone ─────────────────────────────────────────
  group('row set', () {
    testWidgets('no Assets / Liabilities / Add an account / Tech Spec',
        (tester) async {
      final store = buildSeedStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(l.balanceSectionAssets), findsNothing);
      expect(find.text(l.balanceSectionLiabilities), findsNothing);
      expect(find.text(l.moreAddAccount), findsNothing);
      expect(find.textContaining('Tech Spec'), findsNothing);

      // Exactly two section labels.
      expect(find.text(l.moreData.toUpperCase()), findsOneWidget);
      expect(find.text(l.morePreferences.toUpperCase()), findsOneWidget);
    });
  });

  // ── §11 — masked mode leaves the counts alone ───────────────────────────────
  group('counts are not money', () {
    testWidgets('masking does not change the Categories count', (tester) async {
      final store = buildSeedStore();
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      final count = '${store.categoryCount}';
      expect(find.text(count), findsWidgets);

      store.toggleMasked();
      await tester.pump();

      // Still the number, never masked to bullets.
      expect(find.text(count), findsWidgets);
    });
  });
}
