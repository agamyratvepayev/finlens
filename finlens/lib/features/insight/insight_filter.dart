import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/account_filter_sheet.dart';
import '../../shared/widgets/amount_text.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

const _eps = 0.005;

/// The human label for an Insight window, shared by the header, the filter
/// preview and the see-all subtitle: month presets read `August 2026` (not
/// `1–31 Aug`), the year reads `2026`, all-time reads its own word, and
/// everything else uses the compressed day-range label.
String insightWindowLabel(DateRange w, AppLocalizations l) {
  switch (w.preset) {
    case RangePreset.thisMonth:
    case RangePreset.lastMonth:
      return monthYearLong(w.start, l);
    case RangePreset.thisYear:
      return '${w.start.year}';
    case RangePreset.allTime:
      return l.rangeAllTime;
    case RangePreset.thisWeek:
    case RangePreset.lastWeek:
    case RangePreset.last3Months:
    case null:
      return w.label(AppStore.today, l);
  }
}

/// Opens Insight's three-section filter — accounts + spending + income — with
/// the preview that mirrors what each section moves (spec §2). Shared by the
/// main screen's header and the see-all screen's header so they open the
/// identical sheet (spec §5).
Future<void> showInsightFilterSheet(BuildContext context, DateRange window) {
  final l = AppLocalizations.of(context);

  Set<String>? accVisible(AppStore s) {
    final f = s.insightAccountFilter;
    return f.isActive ? f.visibleAccountIds(s) : null;
  }

  // Categories with movement in the window (account-filtered), sorted by amount
  // descending — matching the list they filter (spec §2.3).
  List<(Category, double)> flowRows(AppStore s, {required bool income}) {
    final flow = s.categoryFlowInWindow(window, visible: accVisible(s));
    final m = income ? flow.income : flow.expense;
    final out = <(Category, double)>[];
    m.forEach((id, amount) {
      if (amount.abs() < _eps) return;
      final c = s.categoryById(id);
      if (c != null) out.add((c, amount));
    });
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  return showFilterSheet(
    context,
    sections: [
      FilterSectionSpec.accounts(
        title: l.ldgAccounts,
        note: l.insFilterAccountsNote,
        filter: (s) => s.insightAccountFilter,
        onChanged: (s, f) => s.setInsightAccountFilter(f),
        // Declaration order, matching the group grid (spec §2.3), not Balance's
        // custom order.
        groups: (s) => [
          for (final g in [...AccountGroup.assets, ...AccountGroup.liabilities])
            if (s.groupCount(g) > 0) g
        ],
      ),
      FilterSectionSpec.categories(
        title: l.insSpending,
        note: l.insFilterCategoriesNote,
        rows: (s) => flowRows(s, income: false),
        hidden: (s) => s.insightCategoryFilter,
        onChanged: (s, next) => s.setInsightCategoryFilter(next),
      ),
      FilterSectionSpec.categories(
        title: l.insIncome,
        note: l.insFilterCategoriesNote,
        rows: (s) => flowRows(s, income: true),
        hidden: (s) => s.insightCategoryFilter,
        onChanged: (s, next) => s.setInsightCategoryFilter(next),
      ),
    ],
    preview: InsightFilterPreview(window: window),
  );
}

/// The filter preview (spec §2.2). Mirrors what each section moves: row 1 (net
/// worth, always), row 2 (spending list, only while the spending section hides
/// something), row 3 (income). A toggle changes exactly one row, which is how
/// the reader learns the rule without reading it.
class InsightFilterPreview extends StatelessWidget {
  const InsightFilterPreview({super.key, required this.window});
  final DateRange window;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final accFilter = store.insightAccountFilter;
    final accVisible =
        accFilter.isActive ? accFilter.visibleAccountIds(store) : null;
    final catHidden = store.insightCategoryFilter;

    final groups = [
      for (final g in [...AccountGroup.assets, ...AccountGroup.liabilities])
        if (store.groupCount(g) > 0) g
    ];
    var totalAccts = 0, visAccts = 0;
    for (final g in groups) {
      totalAccts += store.accountsIn(g).length;
      visAccts += accFilter.visibleAccounts(store, g).length;
    }

    final netChange = store.netWorthChangeInWindow(window, visible: accVisible);
    final flow = store.categoryFlowInWindow(window, visible: accVisible);

    ({double total, double vis, int totalCats, int visCats}) block(
        Map<String, double> m) {
      var total = 0.0, vis = 0.0, tc = 0, vc = 0;
      m.forEach((id, amt) {
        if (amt.abs() < _eps) return;
        total += amt;
        tc++;
        if (!catHidden.contains(id)) {
          vis += amt;
          vc++;
        }
      });
      return (total: total, vis: vis, totalCats: tc, visCats: vc);
    }

    final exp = block(flow.expense);
    final inc = block(flow.income);

    final rows = <Widget>[
      _row(
        label: '${l.insNetWorth.toUpperCase()} · ${insightWindowLabel(window, l)}',
        value: AmountText(netChange,
            showSign: true,
            style: AppText.groupAmount
                .copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
        right: l.insAccountsShown(visAccts, totalAccts),
        topRule: false,
      ),
      if (exp.totalCats > exp.visCats)
        _row(
          label: l.insSpendingList.toUpperCase(),
          value: _ofValue(store, l, exp.vis, exp.total),
          right: l.insCategoriesShown(exp.visCats, exp.totalCats),
          topRule: true,
        ),
      if (inc.totalCats > inc.visCats)
        _row(
          label: l.insIncomeList.toUpperCase(),
          value: _ofValue(store, l, inc.vis, inc.total),
          right: l.insCategoriesShown(inc.visCats, inc.totalCats),
          topRule: true,
        ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sheetCard,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _ofValue(AppStore store, AppLocalizations l, double vis, double total) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          AmountText(vis,
              style: AppText.groupAmount
                  .copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(width: 5),
          Text(l.insOfTotal(money(total, masked: store.masked)),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        ],
      );

  Widget _row({
    required String label,
    required Widget value,
    required String right,
    required bool topRule,
  }) {
    return Container(
      decoration: topRule
          ? const BoxDecoration(
              border:
                  Border(top: BorderSide(color: AppColors.divider, width: 0.5)))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                value,
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(right,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
