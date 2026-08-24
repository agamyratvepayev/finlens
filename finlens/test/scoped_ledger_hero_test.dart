import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/l10n/enum_labels.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/theme/app_theme.dart';

/// Mounts a fresh screen per scope — [initialScope] is read once into State, so
/// keying by scope forces a new State rather than silently reusing the old one.
Widget _app(AppStore store, LedgerScope scope) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ScopedLedgerScreen(
          key: ValueKey('${scope.runtimeType}${scope.hashCode}'),
          initialScope: scope,
        ),
      ),
    );

/// The hero's balance is the only 22pt/w700 Text on the screen.
Text _heroBalance(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).firstWhere(
          (t) => t.style?.fontSize == 22 && t.style?.fontWeight == FontWeight.w700,
        );

void main() {
  final l = AppLocalizationsEn();

  Future<void> mount(WidgetTester tester, AppStore store, LedgerScope s) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(store, s));
    // Match the layout test: a fixed 300ms pump, not pumpAndSettle — a 600ms
    // one-shot hint timer keeps the tree from ever fully settling. The timer is
    // cancelled in dispose() when the widget tears down, so it never dangles.
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('account-scope hero prints the account\'s own currency symbol',
      (tester) async {
    final store = buildSeedStore();
    final eur = store.accounts.firstWhere((a) => a.currency == 'EUR');
    final usd = store.accounts.firstWhere((a) => a.currency == 'USD');

    // EUR account: its native balance, so a € symbol — and it is the only €
    // on the screen, because every ledger row is a base-currency ($) figure.
    await mount(tester, store, AccountScope(eur.id));
    expect(_heroBalance(tester).data, startsWith('€'));
    expect(find.textContaining('€'), findsOneWidget);

    // USD account: base symbol, unchanged behaviour.
    await mount(tester, store, AccountScope(usd.id));
    expect(_heroBalance(tester).data, startsWith(r'$'));
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('group-scope hero prints the base currency symbol',
      (tester) async {
    final store = buildSeedStore();
    // Spendable holds the EUR wallet, but the group total sums across
    // currencies, so it is a base-currency ($) figure — never €.
    await mount(tester, store, const GroupScope(AccountGroup.spendable));

    expect(_heroBalance(tester).data, startsWith(r'$'));
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('the identity block is >= 44pt and the subtitle sits under the name',
      (tester) async {
    final store = buildSeedStore();
    final account = store.accountsIn(AccountGroup.spendable).first;
    await mount(tester, store, AccountScope(account.id));

    // The 44pt tap target now lives on the whole block: the ConstrainedBox
    // that wraps the name+subtitle column.
    final block = find.ancestor(
      of: find.text(account.name),
      matching: find.byWidgetPredicate(
        (w) =>
            w is ConstrainedBox &&
            w.constraints == const BoxConstraints(minHeight: 44),
      ),
    );
    expect(block, findsOneWidget);
    expect(tester.getSize(block).height, greaterThanOrEqualTo(44));

    // Title and subtitle are stacked with no spacer, so the subtitle's top
    // sits flush under the name's box — a 1–3px ink gap, not the old ~18px.
    final title = tester.getRect(find.text(account.name));
    final subtitle = tester.getRect(find.text('${account.group.label(l)}  ·  ${account.currency}'));
    expect(subtitle.top - title.bottom, lessThan(4));
    expect(subtitle.top - title.bottom, greaterThan(-2));
  });

  testWidgets('tapping the subtitle opens the scope picker', (tester) async {
    final store = buildSeedStore();
    final account = store.accountsIn(AccountGroup.spendable).first;
    await mount(tester, store, AccountScope(account.id));

    final subtitle =
        find.text('${account.group.label(l)}  ·  ${account.currency}');
    expect(subtitle, findsOneWidget);

    await tester.tap(subtitle);
    await tester.pump(); // start the modal route
    await tester.pump(const Duration(milliseconds: 400)); // let it animate in

    // The picker sheet is titled with l.ldgShow — it exists only in the sheet.
    expect(find.text(l.ldgShow), findsOneWidget);
  });
}
