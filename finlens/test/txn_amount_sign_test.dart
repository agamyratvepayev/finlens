import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

Widget _host(AppStore store, Widget child) => StoreScope(
      store: store,
      child: MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child)),
    );

TxnRow _row(Txn txn, String perspective, {double? balance}) => TxnRow(
      txn: txn,
      perspectiveAccountId: perspective,
      runningBalance: balance,
      onTap: () {},
      onEdit: () {},
      onCopy: () {},
      onDelete: () {},
    );

void main() {
  group('formatter — one place, explicit parameter', () {
    test('signed:false (signless) drops the sign for +, − and 0', () {
      expect(money(120, signless: true), r'$120');
      expect(money(-120, signless: true), r'$120');
      expect(money(0, signless: true), r'$0');
    });

    test('signed keeps the minus on negatives, adds no plus on positives', () {
      expect(money(-120), '−\$120');
      expect(money(120), r'$120');
      expect(money(0), r'$0');
    });

    test('a negative balance keeps its minus while a negative amount does not',
        () {
      // Same value, different intent: the balance is signed, the amount is not.
      expect(money(-300), '−\$300');
      expect(money(-300, signless: true), r'$300');
    });

    test('foreign-currency negative: sign handling identical, symbol unchanged',
        () {
      expect(money(-500, currency: 'EUR', signless: true), '€500');
      expect(money(-500, currency: 'EUR'), '−€500');
    });

    test('the minus is the true U+2212, produced only by the formatter', () {
      expect(money(-1).contains('−'), isTrue);
      expect(money(-1).contains('-'), isFalse); // not a hyphen
    });
  });

  group('rendered rows', () {
    late AppStore store;
    late Account account;
    late Category expenseCat;

    setUp(() {
      store = buildSeedStore();
      account = store.accounts.firstWhere((a) => a.name == 'Main Checking');
      expenseCat =
          store.categories.firstWhere((c) => c.type == CategoryType.expense);
    });

    testWidgets('an expense row is unsigned while its negative balance is not',
        (tester) async {
      final txn = Txn(
        id: 'e1',
        type: TxnType.expense,
        amount: 120,
        currency: 'USD',
        fromRef: account.id,
        toRef: expenseCat.id,
        date: DateTime(2026, 8, 9),
      );

      await tester
          .pumpWidget(_host(store, _row(txn, account.id, balance: -300)));
      await tester.pumpAndSettle();

      // Amount: unsigned, no + or − anywhere on it.
      expect(find.text(r'$120'), findsOneWidget);
      expect(find.text('−\$120'), findsNothing);
      expect(find.text('+\$120'), findsNothing);

      // Colour still carries direction: the amount is red.
      expect(tester.widget<Text>(find.text(r'$120')).style?.color,
          AppColors.negative);

      // The running balance below keeps its minus — it is a balance, not a
      // direction of travel.
      expect(find.text('−\$300'), findsOneWidget);
    });

    testWidgets('a transfer row renders unsigned and neutral — never red/green',
        (tester) async {
      // Spec §2/§3: a transfer moves the user's own money; it is neither a gain
      // nor a loss, so its amount is the neutral transfer colour on every side —
      // not the red an outflow would otherwise wear.
      final other = store.accounts.firstWhere((a) => a.id != account.id);
      final txn = Txn(
        id: 't1',
        type: TxnType.transfer,
        amount: 500,
        currency: 'EUR',
        fromRef: account.id, // source perspective
        toRef: other.id,
        date: DateTime(2026, 8, 4),
      );

      await tester.pumpWidget(_host(store, _row(txn, account.id)));
      await tester.pumpAndSettle();

      expect(find.text('€500'), findsOneWidget);
      expect(find.text('−€500'), findsNothing);
      expect(tester.widget<Text>(find.text('€500')).style?.color,
          AppColors.transferAmount);
    });

    testWidgets('each amount carries a direction semantics label',
        (tester) async {
      final handle = tester.ensureSemantics();
      final txn = Txn(
        id: 'e2',
        type: TxnType.expense,
        amount: 120,
        currency: 'USD',
        fromRef: account.id,
        toRef: expenseCat.id,
        date: DateTime(2026, 8, 9),
      );

      await tester.pumpWidget(_host(store, _row(txn, account.id)));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'^Expense, ')), findsOneWidget);
      handle.dispose();
    });
  });

  group('contrast — direction colours are the sole visual cue', () {
    double channel(int c) {
      final s = c / 255.0;
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    double lum(int r, int g, int b) =>
        0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);

    double ratio(double a, double b) =>
        a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);

    test('#FF453A and #30D158 clear 4.5:1 on both #1C1C1E and #000000', () {
      final red = lum(0xFF, 0x45, 0x3A);
      final green = lum(0x30, 0xD1, 0x58);
      final card = lum(0x1C, 0x1C, 0x1E);
      final page = lum(0x00, 0x00, 0x00);

      expect(ratio(red, card), greaterThan(4.5));
      expect(ratio(green, card), greaterThan(4.5));
      expect(ratio(red, page), greaterThan(4.5));
      expect(ratio(green, page), greaterThan(4.5));
    });
  });
}
