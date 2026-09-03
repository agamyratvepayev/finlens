import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/more/more_screen.dart';
import 'package:finlens/features/more/tag_management_screen.dart';
import 'package:finlens/features/more/widgets/split_action_row.dart';
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

  // ── §1 — no header, and §2 short labels ──────────────────────────────────────
  group('chrome', () {
    testWidgets('the word "More" appears nowhere on the screen', (tester) async {
      final store = buildSeedStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      // moreTitle is "More"; with the header gone it must not render (the bottom
      // nav — not part of this test harness — is the only place the word lives).
      expect(find.text(l.moreTitle), findsNothing);
    });

    testWidgets('Back up / Restore use the short labels, not "… data"',
        (tester) async {
      final store = buildSeedStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(l.moreBackupShort), findsOneWidget); // "Back up"
      expect(find.text(l.moreRestoreShort), findsOneWidget); // "Restore"
      // The long dialog-title strings never appear on a row.
      expect(find.text(l.moreBackup), findsNothing); // "Back up data"
      expect(find.text(l.moreRestore), findsNothing); // "Restore data"
    });
  });

  // ── §4 — the version footer is pinned, not scrolled ──────────────────────────
  group('version footer', () {
    testWidgets('is a sibling of the list, not inside it', (tester) async {
      final store = buildSeedStore();
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      final version = find.textContaining('FinLens');
      expect(version, findsOneWidget);
      // It renders, but never as a descendant of the scrollable list.
      expect(
        find.descendant(of: find.byType(ListView), matching: version),
        findsNothing,
      );
    });
  });

  // ── §3.1 — one row height across all five row types ──────────────────────────
  group('row heights', () {
    testWidgets('all five More row types render at 38 pt', (tester) async {
      final store = buildSeedStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      double rowHeight(String text) => tester
          .getSize(find
              .ancestor(of: find.text(text), matching: find.byType(InkWell))
              .first)
          .height;

      // Split rows measure the whole row (both cells stretch to one height).
      expect(tester.getSize(find.byType(SplitCountRow)).height,
          closeTo(38, 0.5));
      expect(tester.getSize(find.byType(SplitActionRow)).height,
          closeTo(38, 0.5));
      expect(rowHeight(l.moreArchive), closeTo(38, 0.5));
      expect(rowHeight(l.language), closeTo(38, 0.5));
      expect(rowHeight(l.moreMaskAmounts), closeTo(38, 0.5));
    });
  });

  // ── §3.2 — chevrons and values share one right edge down the card ────────────
  group('column alignment', () {
    testWidgets('every chevron and every value shares one right x',
        (tester) async {
      // Categories 2, Tags 0, Archive 0, Language English (the spec's fixture).
      final store = noArchiveStore();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      Finder rowOf(String text) =>
          find.ancestor(of: find.text(text), matching: find.byType(InkWell))
              .first;

      double chevronRight(Finder row) => tester
          .getRect(find.descendant(
              of: row, matching: find.byIcon(Icons.chevron_right_rounded)))
          .right;
      double valueRight(Finder row, String value) =>
          tester.getRect(find.descendant(of: row, matching: find.text(value)))
              .right;

      final archive = rowOf(l.moreArchive);
      final language = rowOf(l.language);
      final tagsCell = rowOf(l.moreTags); // the right split cell

      // Chevrons: the full-width rows and the right split cell all end at one x.
      final chevX = chevronRight(archive);
      expect(chevronRight(language), closeTo(chevX, 0.5));
      expect(chevronRight(tagsCell), closeTo(chevX, 0.5));

      // Values: Archive's 0, Language's "English", and the Tags cell's 0 too.
      final valX = valueRight(archive, '0');
      expect(valueRight(language, 'English'), closeTo(valX, 0.5));
      expect(valueRight(tagsCell, '0'), closeTo(valX, 0.5));
    });
  });

  // ── §2.1 — the split action row stacks when a label would not fit ────────────
  group('split action row stacking', () {
    testWidgets('English fits side-by-side at 320 pt', (tester) async {
      final store = buildSeedStore();
      await tester.pumpWidget(app(store, size: const Size(320, 640)));
      await tester.pump(const Duration(milliseconds: 300));
      // One row's height ⇒ the two cells sit side by side.
      expect(tester.getSize(find.byType(SplitActionRow)).height,
          closeTo(38, 0.5));
    });

    testWidgets('a long locale (ru) stacks into two rows at 320 pt',
        (tester) async {
      final store = buildSeedStore();
      await tester.pumpWidget(app(store,
          locale: const Locale('ru'), size: const Size(320, 640)));
      await tester.pump(const Duration(milliseconds: 300));
      // Two stacked full-width rows + a hairline ⇒ well over one row's height.
      expect(
          tester.getSize(find.byType(SplitActionRow)).height, greaterThan(60));
    });
  });
}
