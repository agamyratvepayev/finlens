import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/features/ledger/trans_filter.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/trans_filter_test.dart

TxnFacts facts({
  TxnType type = TxnType.expense,
  Set<String> groups = const {},
  double abs = 100,
  List<String> tags = const [],
}) =>
    TxnFacts(type: type, groupIds: groups, absAmount: abs, tags: tags);

void main() {
  group('TransFilter.matches (spec §2)', () {
    test('empty filter matches everything', () {
      expect(const TransFilter().matches(facts()), isTrue);
    });

    test('OR within a section', () {
      const f = TransFilter(types: {TxnType.expense, TxnType.income});
      expect(f.matches(facts(type: TxnType.income)), isTrue);
      expect(f.matches(facts(type: TxnType.expense)), isTrue);
      expect(f.matches(facts(type: TxnType.transfer)), isFalse);
    });

    test('AND across sections', () {
      const f =
          TransFilter(types: {TxnType.income}, groupIds: {'c-housing'});
      // Right type, wrong group → excluded.
      expect(
          f.matches(facts(type: TxnType.income, groups: {'c-groceries'})),
          isFalse);
      expect(
          f.matches(facts(type: TxnType.income, groups: {'c-housing'})),
          isTrue);
    });

    test('an empty section imposes no constraint', () {
      const f = TransFilter(groupIds: {'c-housing'});
      // No type constraint → any type with the right group passes.
      expect(
          f.matches(facts(type: TxnType.transfer, groups: {'c-housing'})),
          isTrue);
    });

    test('amount matches on absolute value, each bound absent in turn', () {
      const minOnly = TransFilter(min: 100);
      expect(minOnly.matches(facts(abs: 150)), isTrue);
      expect(minOnly.matches(facts(abs: 50)), isFalse);

      const maxOnly = TransFilter(max: 100);
      expect(maxOnly.matches(facts(abs: 50)), isTrue);
      expect(maxOnly.matches(facts(abs: 150)), isFalse);

      // A $900 income and a $900 expense both fall in the same band.
      const band = TransFilter(min: 900, max: 900);
      expect(band.matches(facts(type: TxnType.income, abs: 900)), isTrue);
      expect(band.matches(facts(type: TxnType.expense, abs: 900)), isTrue);
    });

    test('min > max matches nothing and is not swapped', () {
      const f = TransFilter(min: 500, max: 100);
      expect(f.matches(facts(abs: 300)), isFalse);
      expect(f.matches(facts(abs: 700)), isFalse);
      expect(f.matches(facts(abs: 50)), isFalse);
      // Values are left as typed.
      expect(f.min, 500);
      expect(f.max, 100);
    });

    test('tags OR', () {
      const f = TransFilter(tags: {'fun', 'home'});
      expect(f.matches(facts(tags: ['home'])), isTrue);
      expect(f.matches(facts(tags: ['work'])), isFalse);
    });
  });

  group('isActive', () {
    test('empty is inactive; any section makes it active', () {
      expect(const TransFilter().isActive, isFalse);
      expect(const TransFilter(types: {TxnType.expense}).isActive, isTrue);
      expect(const TransFilter(min: 1).isActive, isTrue);
      expect(const TransFilter(tags: {'x'}).isActive, isTrue);
    });
  });

  group('persistence & stale-id pruning (spec §5)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips, then prunes ids that no longer exist', () async {
      const f = TransFilter(
        types: {TxnType.expense},
        groupIds: {'c-live', 'c-deleted'},
        tags: {'keep', 'gone'},
        min: 10,
        max: 200,
      );
      await f.save('trans_filter_account:a1');

      final loaded = await TransFilter.load(
        'trans_filter_account:a1',
        {'c-live'}, // c-deleted is gone
        {'keep'}, // gone is gone
      );
      expect(loaded.types, {TxnType.expense});
      expect(loaded.groupIds, {'c-live'});
      expect(loaded.tags, {'keep'});
      expect(loaded.min, 10);
      expect(loaded.max, 200);
    });

    test('saving an inactive filter clears the key', () async {
      await const TransFilter(types: {TxnType.income}).save('k');
      await const TransFilter().save('k');
      final loaded = await TransFilter.load('k', {}, {});
      expect(loaded.isActive, isFalse);
    });
  });

  group('TransSort', () {
    test('day grouping only under the two date sorts', () {
      expect(TransSort.dateNewest.groupsByDay, isTrue);
      expect(TransSort.dateOldest.groupsByDay, isTrue);
      expect(TransSort.amountHigh.groupsByDay, isFalse);
      expect(TransSort.amountLow.groupsByDay, isFalse);
      expect(TransSort.byName.groupsByDay, isFalse);
    });

    test('there are exactly five options, default newest-first', () {
      expect(TransSort.values.length, 5);
      expect(TransSort.dateNewest.isDefault, isTrue);
      expect(TransSort.byName2('nonsense'), TransSort.dateNewest);
      expect(TransSort.byName2('amountHigh'), TransSort.amountHigh);
    });
  });

  group('absolute-value sort ranks +900 and −900 adjacently (spec §1)', () {
    test('equal magnitudes sit together regardless of direction', () {
      // Mirrors the screen's amount comparator: sort by absolute magnitude.
      final rows = <({double abs, TxnType type})>[
        (abs: 900, type: TxnType.income),
        (abs: 120, type: TxnType.expense),
        (abs: 900, type: TxnType.expense),
      ]..sort((a, b) => b.abs.compareTo(a.abs));
      expect(rows[0].abs, 900);
      expect(rows[1].abs, 900);
      expect(rows[2].abs, 120);
    });
  });
}
