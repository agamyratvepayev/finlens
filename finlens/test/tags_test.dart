import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/trans_filter.dart';
import 'package:finlens/features/more/tag_management_screen.dart';
import 'package:finlens/features/quick_add/tag_picker_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Tags as a first-class entity (§1–§7). flutter test hangs on the author's
// machine — run these yourself:
//   flutter test test/tags_test.dart

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

AppStore _store({List<Txn> txns = const [], List<Tag> tags = const []}) =>
    AppStore(
      accounts: [_acc('a1')],
      categories: [_cat('c1')],
      txns: txns,
      goals: const [],
      tasks: const [],
      tags: tags,
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

void main() {
  group('migration (§1)', () {
    test('#Fun and #fun (and "fun ") collapse to one tag, all links kept', () {
      final store = _store(txns: [
        _exp('t1', _d(1), const ['Fun']),
        _exp('t2', _d(2), const ['fun']),
        _exp('t3', _d(5), const ['fun ']), // trailing space — same folded name
      ]);

      // One tag, not three.
      expect(store.allTags.length, 1);
      final tag = store.allTags.single;
      // Display keeps the FIRST occurrence's casing.
      expect(tag.name, 'Fun');
      // Every transaction is relinked to that one tag id — no raw names left.
      expect(store.txnCountForTag(tag.id), 3);
      for (final t in store.txns) {
        expect(t.tagIds, [tag.id]);
      }
      // createdAt from the oldest, lastUsedAt from the newest.
      expect(tag.createdAt, _d(1));
      expect(tag.lastUsedAt, _d(5));
      // Two folded-duplicate occurrences were collapsed.
      expect(store.tagMigrationMergedCount, 2);
    });

    test('a leading # is stripped and a duplicated id within one txn dedupes',
        () {
      final store = _store(txns: [
        _exp('t1', _d(1), const ['#fun', 'fun']), // same tag twice, one #-prefixed
      ]);
      expect(store.allTags.length, 1);
      final t = store.txns.single;
      expect(t.tagIds.length, 1); // not carried twice
      expect(store.allTags.single.name, 'fun'); // '#' stripped
    });

    test('does not run twice: a store built already-migrated is untouched', () {
      final tag = _tag('tg', name: 'keep', used: 3);
      final store = _store(
        tags: [tag],
        txns: [_exp('t1', _d(1), const ['tg'])],
      );
      // _tags was non-empty, so migration is skipped: the id-list is left as-is.
      expect(store.allTags.length, 1);
      expect(store.tagMigrationMergedCount, 0);
      expect(store.txns.single.tagIds, ['tg']);
    });
  });

  group('rename & merge (§5)', () {
    test('plain rename is one field change — no transaction rewrite', () {
      final store = _store(txns: [_exp('t1', _d(1), const ['fun'])]);
      final tag = store.allTags.single;
      final id = tag.id;
      final txnList = store.txns.single.tagIds;

      final survivor = store.renameTag(tag, 'party');
      expect(survivor.id, id); // same entity
      expect(survivor.name, 'party');
      expect(store.txns.single.tagIds, txnList); // untouched
      expect(store.txnCountForTag(id), 1);
    });

    test('rename to own name in different casing is a plain rename, not a merge',
        () {
      final store = _store(txns: [_exp('t1', _d(1), const ['fun'])]);
      final tag = store.allTags.single;
      expect(store.mergeTargetFor(tag, 'FUN'), isNull);
      store.renameTag(tag, 'FUN');
      expect(store.allTags.length, 1);
      expect(store.allTags.single.name, 'FUN');
    });

    test('rename onto an existing name merges; a txn carrying both is not '
        'doubled', () {
      final store = _store(txns: [
        _exp('t1', _d(1), const ['a']),
        _exp('t2', _d(2), const ['b']),
        _exp('t3', _d(3), const ['a', 'b']), // carries BOTH
      ]);
      final a = store.allTags.firstWhere((t) => t.name == 'a');
      final b = store.allTags.firstWhere((t) => t.name == 'b');

      expect(store.mergeTargetFor(a, 'b')?.id, b.id);
      final survivor = store.renameTag(a, 'b');

      expect(survivor.id, b.id); // merged into b
      expect(store.tagById(a.id), isNull); // source gone
      // t3 carried both — after merge it references b exactly once.
      final t3 = store.txns.firstWhere((t) => t.id == 't3');
      expect(t3.tagIds, [b.id]);
      // Every one of the three transactions now references b.
      expect(store.txnCountForTag(b.id), 3);
      // Target lastUsedAt is the later of the two.
      expect(b.lastUsedAt, _d(3));
    });
  });

  group('archive / restore / delete (§4)', () {
    test('archive removes from picker source but keeps the tag', () {
      final store = _store(txns: [_exp('t1', _d(1), const ['fun'])]);
      final tag = store.allTags.single;
      store.archiveTag(tag);
      expect(store.activeTags, isEmpty);
      expect(store.archivedTags.single.id, tag.id);
      expect(store.txnCountForTag(tag.id), 1); // transactions untouched
      store.restoreTag(tag);
      expect(store.activeTags.single.id, tag.id);
      expect(store.archivedTags, isEmpty);
    });

    test('delete is refused while in use, allowed when unused', () {
      final store = _store(txns: [_exp('t1', _d(1), const ['fun'])]);
      final tag = store.allTags.single;
      expect(store.deleteTag(tag), isFalse); // in use → refused
      expect(store.tagById(tag.id), isNotNull);

      // A tag created but never applied (or whose last txn was deleted) is
      // deletable — a typo costs nothing (§4 / §7).
      final orphan = store.createTag('typo')!;
      expect(store.txnCountForTag(orphan.id), 0);
      expect(store.deleteTag(orphan), isTrue);
      expect(store.tagById(orphan.id), isNull);
    });
  });

  group('ordering & filterability (§2 / §6)', () {
    test('active tags order by lastUsedAt, newest first — count is irrelevant',
        () {
      // "old" is used far more often but long ago; "fresh" once, yesterday.
      final store = _store(
        tags: [
          _tag('old', name: 'old', used: 1),
          _tag('fresh', name: 'fresh', used: 9),
        ],
        txns: [
          _exp('t1', _d(1), const ['old']),
          _exp('t2', _d(1), const ['old']),
          _exp('t3', _d(1), const ['old']),
          _exp('t4', _d(9), const ['fresh']),
        ],
      );
      // A low-count recent tag outranks a high-count old one.
      expect(store.activeTags.map((t) => t.id).toList(), ['fresh', 'old']);
      expect(store.txnCountForTag('old'), 3);
      expect(store.txnCountForTag('fresh'), 1);
    });

    test('an archived tag is filterable even though it left the picker', () {
      final store = _store(txns: [_exp('t1', _d(1), const ['fun'])]);
      final tag = store.allTags.single;
      store.archiveTag(tag);
      expect(store.activeTags, isEmpty); // absent from picker source

      final facts = TxnFacts(
        type: TxnType.expense,
        groupIds: const {},
        absAmount: 10,
        tagIds: [tag.id],
      );
      expect(TransFilter(tags: {tag.id}).matches(facts), isTrue);
    });
  });

  // ── Picker widget (§2) ──────────────────────────────────────────────────────
  group('tag picker', () {
    Future<void> openPicker(WidgetTester tester, AppStore store) async {
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showTagPicker(ctx, selected: const {}, onChanged: (_) {}),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('Create #… appears for a new name and not for an exact match',
        (tester) async {
      final store = _store(txns: [_exp('t1', _d(1), const ['fun'])]);
      await openPicker(tester, store);

      // A brand-new name → the create row.
      await tester.enterText(find.byType(TextField), 'brandnew');
      await tester.pumpAndSettle();
      expect(find.text('Create #brandnew'), findsOneWidget);

      // The exact existing name → no create row, and the tag itself is listed.
      await tester.enterText(find.byType(TextField), 'fun');
      await tester.pumpAndSettle();
      expect(find.text('Create #fun'), findsNothing);
      expect(find.text('#fun'), findsOneWidget);
    });

    testWidgets('an archived tag is absent from the picker', (tester) async {
      final store = _store(
        tags: [_tag('fun', name: 'fun', archived: true, used: 3)],
        txns: [_exp('t1', _d(3), const ['fun'])],
      );
      await openPicker(tester, store);
      expect(find.text('#fun'), findsNothing);
    });
  });

  // ── Management screen (§5 / §6) ───────────────────────────────────────────────
  group('management screen', () {
    Widget tagsApp(AppStore store, {Locale locale = const Locale('en')}) =>
        StoreScope(
          store: store,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.dark,
            home: const TagManagementScreen(),
          ),
        );

    testWidgets(
        'empty state uses its own strings, not tagsTitle / tagArchiveFootnote',
        (tester) async {
      final store = _store(); // no tags, no txns
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(tagsApp(store));
      await tester.pumpAndSettle();

      expect(find.text(l.tagsEmptyTitle), findsOneWidget);
      expect(find.text(l.tagsEmptyMsg), findsOneWidget);
      // The old borrowed strings are gone from the empty state: the footnote
      // isn't anywhere on the screen (the header still shows tagsTitle, so we
      // assert on the footnote, which only ever lived in the body).
      expect(find.text(l.tagArchiveFootnote), findsNothing);
    });

    testWidgets('§5 regression: a tag can be created from a zero-tag store',
        (tester) async {
      final store = _store();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(tagsApp(store));
      await tester.pumpAndSettle();

      // The create chip is present in the empty state…
      final chip = find.text('New');
      expect(chip, findsOneWidget);

      // …and tapping it opens the create sheet.
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text(l.tagNewTitle), findsWidgets); // sheet title "New tag"
      expect(find.byType(TextField), findsOneWidget); // the name field
    });

    testWidgets('archived chips are not wrapped in a 0.45 Opacity',
        (tester) async {
      final store = _store(
        tags: [_tag('fun', name: 'fun', archived: true, used: 3)],
      );
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(tagsApp(store));
      await tester.pumpAndSettle();

      expect(find.text(l.tagSectionArchived), findsOneWidget);
      // The dimmed-copy treatment is gone (§6).
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.45),
        findsNothing,
      );
    });

    testWidgets('with only archived tags, the IN USE create chip still renders',
        (tester) async {
      final store = _store(
        tags: [_tag('fun', name: 'fun', archived: true, used: 3)],
      );
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(tagsApp(store));
      await tester.pumpAndSettle();

      // Both sections render, so a first live tag can still be created.
      expect(find.text(l.tagSectionInUse), findsOneWidget);
      expect(find.text(l.tagSectionArchived), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    });
  });
}
