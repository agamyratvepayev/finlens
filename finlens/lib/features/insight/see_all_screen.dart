import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'category_detail_screen.dart';

/// The full category list, pushed from a `Tümünü gör` strip. Nav title is the
/// block name (Gider / Gelir); every category is shown, with a budget subtitle
/// where one exists. Pushed on the root navigator, so no bottom nav.
class SeeAllScreen extends StatelessWidget {
  const SeeAllScreen({super.key, required this.income, required this.window});

  final bool income;
  final DateRange window;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    final flow = store.categoryFlowInWindow(window);
    final map = income ? flow.income : flow.expense;
    final rows = <(Category?, double)>[];
    map.forEach((id, amount) {
      if (amount.abs() < 0.005) return;
      rows.add((store.categoryById(id), amount));
    });
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    final total = rows.fold(0.0, (s, r) => s + r.$2);
    final unbudgeted = income ? 0.0 : store.unbudgetedSpendWindow(window);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: income ? l.insIncome : l.insSpending,
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_periodTitle(window, l)} · ${l.insCategoriesCount(rows.length)}',
                  style: AppText.caption,
                ),
              ),
              showBack: true,
              showAdd: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, Insets.xxl),
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AmountText(total,
                        style: AppText.hero.copyWith(fontSize: 30)),
                  ),
                  const SizedBox(height: Insets.md),
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0) const RowDivider(indent: 47),
                          _Row(
                            cat: rows[i].$1,
                            amount: rows[i].$2,
                            total: total,
                            income: income,
                            window: window,
                            store: store,
                          ),
                        ],
                        if (!income && unbudgeted > 0.005)
                          // The old strip appended "· Add budget" with no
                          // onTap — a dead half-sentence (spec §10). Dropped to
                          // the honest figure alone; there is no budget-editor
                          // route from here to wire it to.
                          _Foot(
                            text: l.insUnbudgetedTotal(
                                money(unbudgeted, masked: store.masked)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodTitle(DateRange w, AppLocalizations l) {
    switch (w.preset) {
      case RangePreset.thisMonth:
      case RangePreset.lastMonth:
        return monthYearLong(w.start, l);
      case RangePreset.thisYear:
        return '${w.start.year}';
      case RangePreset.allTime:
        return l.rangeAllTime;
      default:
        return w.label(AppStore.today, l);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.cat,
    required this.amount,
    required this.total,
    required this.income,
    required this.window,
    required this.store,
  });

  final Category? cat;
  final double amount;
  final double total;
  final bool income;
  final DateRange window;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pct = total <= 0 ? 0.0 : amount / total;

    // Budget subtitle for expense categories — uses effectiveLimit (rollover
    // included) so the figure agrees with Planner.
    String? sub;
    Color subColor = AppColors.textTertiary;
    if (!income && cat != null) {
      final limit = cat!.effectiveLimit;
      if (limit == null) {
        sub = l.insNoBudget;
        subColor = AppColors.textQuaternary;
      } else {
        final ratio = limit <= 0 ? 0.0 : amount / limit;
        final over = ratio > 1;
        sub = over
            ? l.insBudgetSubOver(
                money(limit, masked: store.masked), percent(ratio, decimals: 0))
            : l.insBudgetSub(
                money(limit, masked: store.masked), percent(ratio, decimals: 0));
        if (over) subColor = AppColors.negative;
      }
    }

    return InkWell(
      onTap: cat == null
          ? null
          : () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => CategoryDetailScreen(
                      categoryId: cat!.id, window: window),
                ),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconTile(cat?.icon ?? Icons.help_outline_rounded,
                color: cat?.color ?? AppColors.textTertiary, size: 30),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontSize: 14)),
                  if (sub != null)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: subColor)),
                ],
              ),
            ),
            AmountText(amount, style: AppText.amount.copyWith(fontSize: 14)),
            const SizedBox(width: Insets.sm),
            SizedBox(
              width: 36,
              child: Text(percent(pct, decimals: 0),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, height: 1.45, color: AppColors.textSecondary)),
    );
  }
}
