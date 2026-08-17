import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../shared/widgets/swipe_back_route.dart';
import '../ledger/ledger_scope.dart';
import '../ledger/scoped_ledger_screen.dart';
import '../quick_add/quick_add_sheet.dart';
import 'widgets/account_rows.dart';

/// Spec 1.2 — Assets detail. Unlike Balance, every group starts expanded
/// because this page is already the detail view.
class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GroupDetailScreen(
      title: 'Assets',
      groups: null,
      isAssets: true,
    );
  }
}

/// Shared body for Assets (1.2) and Liabilities (1.3) — symmetric by design.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({
    super.key,
    required this.title,
    required this.isAssets,
    this.groups,
  });

  final String title;
  final bool isAssets;
  final List<AccountGroup>? groups;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = groups ??
        (isAssets ? AccountGroup.assets : AccountGroup.liabilities);
    // Sum the groups actually being shown, not the whole side. Opening this
    // scoped to one group (from Balance) otherwise printed the full asset
    // total under that group's name.
    final total = list.fold<double>(0, (sum, g) => sum + store.groupTotal(g));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: title,
              showBack: true,
              onAdd: () => showQuickAdd(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Insets.gutter),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title.toUpperCase(), style: AppText.label),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: AmountText(
                                  total,
                                  style: AppText.hero.copyWith(fontSize: 30),
                                  color:
                                      isAssets ? null : AppColors.negative,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text('Total $title', style: AppText.caption),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: Insets.lg),
                          child: DeltaChip(
                            fraction: store.netWorthDeltaFraction,
                            caption: store.comparePeriod.caption,
                            isLiability: !isAssets,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  for (final group in list) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.gutter,
                        0,
                        Insets.gutter,
                        Insets.md,
                      ),
                      child: AppCard(
                        child: Column(
                          children: [
                            GroupRow(
                              group: group,
                              total: store.groupTotal(group),
                              count: store.groupCount(group),
                              share: store.groupShare(group),
                              // Account creation is contextual, never a
                              // permanent row in the list.
                              onLongPress: () =>
                                  showNewAccountSheet(context, group: group),
                            ),
                            const RowDivider(indent: Insets.md),
                            for (final a in store.accountsIn(group))
                              _row(context, store, a),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppStore store, Account a) {
    final sub = isAssets
        ? (text: null, color: null)
        : liabilitySubtitle(store, a);
    return AccountRow(
      account: a,
      balance: store.balanceOf(a.id),
      subtitle: sub.text,
      subtitleColor: sub.color,
      onTap: () => Navigator.of(context).push(
        SwipeBackPageRoute(
          builder: (_) => ScopedLedgerScreen(initialScope: AccountScope(a.id)),
        ),
      ),
    );
  }
}
