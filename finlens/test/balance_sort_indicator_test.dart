import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/features/balance/balance_order.dart';
import 'package:finlens/main.dart';
import 'package:finlens/shared/widgets/section_header.dart';
import 'package:finlens/theme/app_colors.dart';

/// The sort tool announces its state through the glyph itself — a one-step
/// brightness lift, the same convention the filter tool uses — and never
/// through a floating dot.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Color sortGlyphColour(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(Icons.swap_vert_rounded)).color!;

  // The dot was an accent-filled circle floated over a tool. Scope the search
  // to the ToolCluster so unrelated circles elsewhere can't mask a regression.
  Finder dotInCluster() => find.descendant(
        of: find.byType(ToolCluster),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle &&
              (w.decoration as BoxDecoration).color == AppColors.accent,
        ),
      );

  testWidgets('default order: glyph muted, no dot', (tester) async {
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));
    await tester.pumpAndSettle();

    expect(sortGlyphColour(tester), AppColors.textSecondary);
    expect(dotInCluster(), findsNothing);
  });

  testWidgets('a non-default sort brightens the glyph, still no dot',
      (tester) async {
    final store = buildSeedStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    store.setBalanceSort(AccountSort.nameAsc);
    await tester.pumpAndSettle();

    expect(sortGlyphColour(tester), AppColors.textPrimary);
    expect(dotInCluster(), findsNothing);
  });

  testWidgets('Custom with nothing dragged keeps the glyph muted',
      (tester) async {
    final store = buildSeedStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // Selecting Custom without a drag leaves the order unconfigured — the list
    // is unchanged, so the glyph must stay muted.
    store.setBalanceOrder(const CustomOrder(), sort: AccountSort.custom);
    await tester.pumpAndSettle();

    expect(store.balanceOrder.isConfigured, isFalse);
    expect(sortGlyphColour(tester), AppColors.textSecondary);
    expect(dotInCluster(), findsNothing);
  });

  testWidgets('Custom after a real drag brightens the glyph', (tester) async {
    final store = buildSeedStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    const g = AccountGroup.valuables;
    final order = CustomOrder(
      accountOrder: {g: store.accountsIn(g).map((a) => a.id).toList()},
    );
    store.setBalanceOrder(order, sort: AccountSort.custom);
    await tester.pumpAndSettle();

    expect(sortGlyphColour(tester), AppColors.textPrimary);
    expect(dotInCluster(), findsNothing);
  });
}
