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
import '../planner/edit_budget_screen.dart';
import 'category_detail_screen.dart';
import 'insight_filter.dart';

/// The full category list, pushed from a `See all` strip. Nav title is the
/// block name (Spending / Income); every category with movement is shown, with a
/// budget subtitle where one exists. A filter button on the right opens the same
/// sheet as the main screen (spec §5). Pushed on the root navigator, so no
/// bottom nav.
class SeeAllScreen extends StatelessWidget {
  const SeeAllScreen({super.key, required this.income});

  final bool income;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    // Reads Insight's window from the store (spec §6.1), not a constructor arg.
    final window = store.insightWindow;

    final accFilter = store.insightAccountFilter;
    final accVisible =
        accFilter.isActive ? accFilter.visibleAccountIds(store) : null;
    final catHidden = store.insightCategoryFilter;

    final flow = store.categoryFlowInWindow(window, visible: accVisible);
    final map = income ? flow.income : flow.expense;

    // The full list (all categories with movement) is the base for percentages
    // and the `of {total}` figure (spec §5).
    final fullRows = <(Category?, double)>[];
    map.forEach((id, amount) {
      if (amount.abs() < 0.005) return;
      fullRows.add((store.categoryById(id), amount));
    });
    fullRows.sort((a, b) => b.$2.compareTo(a.$2));
    final fullTotal = fullRows.fold(0.0, (s, r) => s + r.$2);

    // The category filter hides categories from the list; the percentages stay
    // shares of the unfiltered total, so hiding one never grows the others.
    final rows = fullRows
        .where((r) => r.$1 == null || !catHidden.contains(r.$1!.id))
        .toList();
    final visibleTotal = rows.fold(0.0, (s, r) => s + r.$2);
    final filtered = rows.length != fullRows.length;

    final unbudgeted = income ? 0.0 : store.unbudgetedSpendWindow(window);
    final filterActive = accFilter.isActive || catHidden.isNotEmpty;

    final subtitle = filtered
        ? '${insightWindowLabel(window, l)} · '
            '${l.insCategoriesShown(rows.length, fullRows.length)}'
        : '${insightWindowLabel(window, l)} · '
            '${l.insCategoriesCount(fullRows.length)}';

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
                child: Text(subtitle, style: AppText.caption),
              ),
              showBack: true,
              showAdd: false,
              trailing: _FilterButton(
                active: filterActive,
                onTap: () => showInsightFilterSheet(context, window),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, Insets.xxl),
                children: [
                  // Hero: the block total at 30pt. While the category filter
                  // hides something, `$1,182 of $2,972` (spec §5).
                  if (filtered)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AmountText(visibleTotal,
                                style: AppText.hero.copyWith(fontSize: 30)),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            l.insOfTotal(money(fullTotal, masked: store.masked)),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textTertiary),
                          ),
                        ),
                      ],
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AmountText(fullTotal,
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
                            total: fullTotal,
                            income: income,
                            store: store,
                          ),
                        ],
                        // The strip is hidden while the category filter is active
                        // — `$103 in unbudgeted categories` is unreadable next to
                        // a list showing part of the data (spec §5). When shown it
                        // is tappable (spec §4.2): the aggregate has no single
                        // target, so it opens the budget editor for the largest
                        // unbudgeted category — the biggest gap to start with.
                        if (!income &&
                            catHidden.isEmpty &&
                            unbudgeted > 0.005)
                          _Foot(
                            text: l.insUnbudgetedTotal(
                                money(unbudgeted, masked: store.masked)),
                            onTap: () =>
                                _openLargestUnbudgeted(context, store, window),
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

  void _openLargestUnbudgeted(
      BuildContext context, AppStore store, DateRange window) {
    Category? best;
    var bestAmount = 0.0;
    for (final c in store.categories.where(
        (c) => c.type == CategoryType.expense && c.monthlyBudget == null)) {
      final spent = store.spentInCategoryWindow(c.id, window);
      if (spent > bestAmount) {
        bestAmount = spent;
        best = c;
      }
    }
    if (best == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => EditBudgetScreen(categoryId: best!.id),
      ),
    );
  }
}

/// A 36pt circular filter button for the see-all header, filling accent when
/// either filter is active (spec §5, mirroring the main header's cue).
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accent : AppColors.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            active ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
            size: 19,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.cat,
    required this.amount,
    required this.total,
    required this.income,
    required this.store,
  });

  final Category? cat;
  final double amount;
  final double total;
  final bool income;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Share of the UNFILTERED block total (spec §5).
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

    // The budget subtitle is folded into one sentence, not read as a second
    // node (spec §9). Money honours the privacy eye.
    final a11y = '${cat?.name ?? '—'}, '
        '${money(amount, masked: store.masked)}, ${percent(pct, decimals: 0)}'
        '${sub != null ? ', $sub' : ''}';

    return InkWell(
      onTap: cat == null
          ? null
          : () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => CategoryDetailScreen(categoryId: cat!.id),
                ),
              ),
      child: Semantics(
        button: cat != null,
        label: a11y,
        child: ExcludeSemantics(
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
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: onTap == null
                          ? AppColors.textSecondary
                          : AppColors.accentLight)),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.accentLight),
          ],
        ),
      ),
    );
  }
}
