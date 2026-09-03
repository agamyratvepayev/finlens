import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/more/tag_management_screen.dart';
import 'package:finlens/features/quick_add/tag_picker_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/theme/app_theme.dart';

// The "fill gaps only" additions to the tag feature:
//   • §7 five-tag cap in the picker
//   • §9 UNUSED group on the management screen
//   • §8 plural "Tags" form-row label
// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/tag_gaps_test.dart

Account _acc(String id) => Account(
      id: id,
      name: id,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

Category _cat(String id) => Category(
      id: id,
      name: id,
      type: CategoryType.expense,
      icon: Icons.circle,
      color: const Color(0xFF30D158),
    );

Txn _exp(String id, DateTime date, List<String> tagIds) => Txn(
      id: id,
      type: TxnType.expense,
      amount: 10,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'c1',
      date: date,
      tagIds: tagIds,
    );

DateTime _d(int day) => DateTime(2026, 8, day, 12);

Tag _tag(String id, {String? name, bool archived = false, required int used}) =>
    Tag(
      id: id,
      name: name ?? id,
      archived: archived,
      createdAt: _d(1),
      lastUsedAt: _d(used),
    );

AppStore _store({List<Txn> txns = const [], List<Tag> tags = const []}) =>
    AppStore(
      accounts: [_acc('a1')],
      categories: [_cat('c1')],
      txns: txns,
      goals: const [],
      tasks: const [],
      tags: tags,
    );

Widget _host(AppStore store, Widget child) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  group('five-tag cap (§7)', () {
    // Six existing tags, five of them already selected — at the cap.
    Future<Set<String>> openAtCap(WidgetTester tester, AppStore store) async {
      Set<String> last = {};
      await tester.pumpWidget(_host(
        store,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showTagPicker(
                  ctx,
                  selected: const {'t1', 't2', 't3', 't4', 't5'},
                  onChanged: (ids) => last = ids,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return last;
    }

    AppStore sixTags() => _store(
          tags: [for (var i = 1; i <= 6; i++) _tag('t$i', name: 't$i', used: i)],
          txns: [for (var i = 1; i <= 6; i++) _exp('x$i', _d(i), ['t$i'])],
        );

    testWidgets('at five selected the cap line shows and create is disabled',
        (tester) async {
      final store = sixTags();
      await openAtCap(tester, store);

      // The explanation line is visible (silent ignoring is forbidden).
      expect(find.text('Up to 5 tags. Deselect one to add another.'),
          findsOneWidget);

      // A new name still surfaces a create row — but it is disabled: tapping it
      // creates nothing.
      await tester.enterText(find.byType(TextField), 'brandnew');
      await tester.pumpAndSettle();
      expect(find.text('Create #brandnew'), findsOneWidget);
      await tester.tap(find.text('Create #brandnew'));
      await tester.pumpAndSettle();
      expect(store.allTags.length, 6); // nothing created
    });

    testWidgets('a sixth selection attempt changes nothing', (tester) async {
      final store = sixTags();
      final last = await openAtCap(tester, store);

      // Five selected → five check marks in the list.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));

      // #t6 is the one unselected row; tapping it is a no-op at the cap.
      await tester.tap(find.text('#t6'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));
      expect(last, isEmpty); // onChanged never fired
    });
  });

  group('management UNUSED group (§9)', () {
    testWidgets('a count-0 tag lands under UNUSED, a used one under IN USE',
        (tester) async {
      final store = _store(txns: [_exp('t1', _d(1), const ['used'])]);
      store.createTag('spare'); // never applied → count 0
      await tester.pumpWidget(_host(store, const TagManagementScreen()));
      await tester.pumpAndSettle();

      expect(find.text('IN USE'), findsOneWidget);
      expect(find.text('UNUSED'), findsOneWidget);
      expect(find.text('#used'), findsOneWidget);
      expect(find.text('#spare'), findsOneWidget);
    });

    testWidgets('no UNUSED section when every tag is in use', (tester) async {
      final store = _store(txns: [_exp('t1', _d(1), const ['used'])]);
      await tester.pumpWidget(_host(store, const TagManagementScreen()));
      await tester.pumpAndSettle();

      expect(find.text('IN USE'), findsOneWidget);
      expect(find.text('UNUSED'), findsNothing);
    });
  });

  group('plural row label (§8)', () {
    test('the form-row label is plural', () {
      expect(AppLocalizationsEn().qaTag, 'Tags');
    });
  });
}
