import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/same_transactions_screen.dart';
import 'edit_budget_screen.dart';

/// Spec 5.6 — the screen a budget card opens on a tap: "where did this $560
/// go?", the recurring question, not "change the limit", the rare one. Editing
/// the limit moves into the ••• menu here.
class BudgetDetailScreen extends StatelessWidget {
  const BudgetDetailScreen({
    super.key,
    required this.categoryId,
    required this.month,
  });

  final String categoryId;

  /// The month the Planner was showing when the card was tapped — every figure
  /// on this screen is scoped to it.
  final DateTime month;

  /// Past months are neutral: [Category.monthlyBudget] has no history, so
  /// colouring an earlier month against today's limit would judge a limit that
  /// never existed then (spec 5.6).
  static const _pastMonth = Color(0xFF55555A);

  /// The shared limit line across the six-month rows (spec `#EBEBF5`).
  static const _limitLine = Color(0xFFEBEBF5);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final category = store.categoryById(categoryId);
    if (category == null) {
      // Removed while open — leave rather than show an empty shell.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final monthlyBudget = category.monthlyBudget ?? 0;
    final effectiveLimit = category.effectiveLimit ?? 0;
    final spent = store.spentInCategory(category.id, month);
    final ratio = effectiveLimit <= 0 ? 0.0 : spent / effectiveLimit;
    final over = ratio > 1;
    final warn = !over && ratio >= category.warnThreshold;
    final color = over
        ? AppColors.negative
        : (warn ? AppColors.warning : AppColors.positive);
    final isCurrent = store.isCurrentMonth(month);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _navBar(context, category),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _header(context, category, monthlyBudget),
                  _thisMonth(
                    context,
                    store,
                    category,
                    spent: spent,
                    ratio: ratio,
                    over: over,
                    effectiveLimit: effectiveLimit,
                    color: color,
                    isCurrent: isCurrent,
                  ),
                  _againstTheLimit(store, category, monthlyBudget, color,
                      AppLocalizations.of(context)),
                  _transactions(context, store, category),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nav bar ────────────────────────────────────────────────────────────────

  Widget _navBar(BuildContext context, Category category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, Insets.sm, 0),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_left_rounded,
                      size: 20, color: AppColors.accentLight),
                  Text(
                    AppLocalizations.of(context).plTabBudgets,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.accentLight,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded,
                  size: 22, color: AppColors.accentLight),
              onPressed: () => _showMenu(context, category),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, Category category) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.sm),
            ListTile(
              leading: const Icon(Icons.tune_rounded,
                  color: AppColors.textPrimary),
              title: Text(AppLocalizations.of(context).ebTitle, style: AppText.body),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => EditBudgetScreen(categoryId: category.id),
                  ),
                );
              },
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _header(
      BuildContext context, Category category, double monthlyBudget) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.lg,
      ),
      child: Row(
        children: [
          IconTile(category.icon, color: category.color, size: 38),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: AppText.rowTitle.copyWith(fontSize: 19),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // The recurring limit, not the effective one (spec 5.6).
                Row(
                  children: [
                    AmountText(monthlyBudget, style: AppText.rowSubtitle),
                    Text(' ${AppLocalizations.of(context).bdAMonth}',
                        style: AppText.rowSubtitle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── This month ─────────────────────────────────────────────────────────────

  Widget _thisMonth(
    BuildContext context,
    AppStore store,
    Category category, {
    required double spent,
    required double ratio,
    required bool over,
    required double effectiveLimit,
    required Color color,
    required bool isCurrent,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).rangeThisMonth.toUpperCase(),
              style: AppText.label),
          const SizedBox(height: Insets.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AmountText(
                spent,
                style: AppText.hero.copyWith(fontSize: 27),
                color: color,
              ),
              const SizedBox(width: Insets.sm),
              Text(
                over
                    ? AppLocalizations.of(context)
                        .bdSpentOver(money(spent - effectiveLimit))
                    : AppLocalizations.of(context).bdSpent,
                style: AppText.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          ProgressBar(
            value: ratio,
            color: color,
            paceMarker: isCurrent ? store.monthProgressFor(month) : null,
            height: 8,
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Text(
                isCurrent
                    ? '${percent(ratio, decimals: 0)} · '
                        '${AppLocalizations.of(context).bdDayOfMonth(store.dayOfMonthFor(month), store.daysInMonthOf(month))}'
                    : percent(ratio, decimals: 0),
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
              if (isCurrent) ...[
                const Spacer(),
                Container(width: 2, height: 10, color: AppColors.textPrimary),
                const SizedBox(width: 5),
                Text(AppLocalizations.of(context).plPace, style: AppText.caption.copyWith(fontSize: 11.5)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Against the limit ──────────────────────────────────────────────────────

  Widget _againstTheLimit(
    AppStore store,
    Category category,
    double monthlyBudget,
    Color selectedColor,
    AppLocalizations l,
  ) {
    // Six calendar months ending with the selected one, newest first.
    final months = [
      for (var i = 0; i < 6; i++) DateTime(month.year, month.month - i),
    ];
    final amounts = [
      for (final m in months) store.spentInCategory(category.id, m),
    ];
    final withSpending = amounts.where((a) => a > 0).length;

    // A rate from two points is noise — the same rule the frequency line follows
    // (spec 5.6).
    if (withSpending < 2) return const SizedBox.shrink();

    final highest = amounts.fold(0.0, (m, a) => a > m ? a : m);
    final axisMax = (highest > monthlyBudget ? highest : monthlyBudget) * 1.15;
    final limitFraction = axisMax <= 0 ? 0.0 : monthlyBudget / axisMax;

    final spentMonths = amounts.where((a) => a > 0).toList();
    final average = spentMonths.isEmpty
        ? 0.0
        : spentMonths.fold(0.0, (s, a) => s + a) / spentMonths.length;
    final overLimitCount = amounts.where((a) => a > monthlyBudget).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bdAgainstLimit, style: AppText.label),
          const SizedBox(height: Insets.md),
          for (var i = 0; i < months.length; i++) ...[
            if (i > 0) const SizedBox(height: Insets.md),
            _historyRow(
              month: months[i],
              amount: amounts[i],
              fraction: axisMax <= 0 ? 0.0 : amounts[i] / axisMax,
              limitFraction: limitFraction,
              color: i == 0 ? selectedColor : _pastMonth,
              l: l,
            ),
          ],
          if (withSpending >= 3) ...[
            const SizedBox(height: Insets.md),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
            const SizedBox(height: Insets.sm),
            Text(
              l.bdAveraging(money(average.roundToDouble()),
                  money(monthlyBudget), '$overLimitCount'),
              style: AppText.caption.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyRow({
    required DateTime month,
    required double amount,
    required double fraction,
    required double limitFraction,
    required Color color,
    required AppLocalizations l,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            monthShort(month.month, l),
            style: AppText.caption.copyWith(fontSize: 12.5),
          ),
        ),
        Expanded(
          child: _HistoryBar(
            fraction: fraction,
            limitFraction: limitFraction,
            color: color,
            limitColor: _limitLine,
          ),
        ),
        const SizedBox(width: Insets.md),
        SizedBox(
          width: 66,
          child: Align(
            alignment: Alignment.centerRight,
            child: AmountText(
              amount,
              style: AppText.amount.copyWith(
                fontSize: 13.5,
                color: color == _pastMonth
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Transactions ───────────────────────────────────────────────────────────

  Widget _transactions(
    BuildContext context,
    AppStore store,
    Category category,
  ) {
    final txns = store
        .txnsInMonth(month)
        .where((t) => t.type == TxnType.expense && t.toRef == category.id)
        .toList();
    final shown = txns.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          '${monthShort(month.month, AppLocalizations.of(context)).toUpperCase()} · '
          '${AppLocalizations.of(context).countTransactions(txns.length)}',
        ),
        if (txns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.gutter,
              vertical: Insets.sm,
            ),
            child: Text(
              AppLocalizations.of(context).bdNothingSpent,
              style: AppText.caption.copyWith(fontSize: 12.5),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const RowDivider(indent: Insets.md),
                    _TxnMiniRow(category: category, txn: shown[i]),
                  ],
                ],
              ),
            ),
          ),
        // Spec 5.6 — See all opens the full category history. LedgerKey is built
        // from a category + direction alone, so the newest month txn is a valid
        // origin for that key.
        if (txns.length > shown.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.sm,
              Insets.gutter,
              0,
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SameTransactionsScreen(
                    originTxnId: txns.first.id,
                    backLabel: category.name,
                    showAll: true,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  AppLocalizations.of(context).balSeeAll(txns.length),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentLight,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A single history bar with a fill and the shared vertical limit line.
class _HistoryBar extends StatelessWidget {
  const _HistoryBar({
    required this.fraction,
    required this.limitFraction,
    required this.color,
    required this.limitColor,
  });

  final double fraction;
  final double limitFraction;
  final Color color;
  final Color limitColor;

  @override
  Widget build(BuildContext context) {
    const height = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (width * limitFraction.clamp(0.0, 1.0) - 0.75)
                    .clamp(0.0, width - 1.5),
                top: -2,
                bottom: -2,
                child: Container(width: 1.5, color: limitColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact read-only transaction row for the budget screen's preview list.
class _TxnMiniRow extends StatelessWidget {
  const _TxnMiniRow({required this.category, required this.txn});

  final Category category;
  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final title = txn.note.isEmpty ? category.name : txn.note;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Row(
        children: [
          IconTile(category.icon, color: category.color, size: 30),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.rowTitle.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(dayMonth(txn.date, AppLocalizations.of(context)),
                    style: AppText.rowSubtitle),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          AmountText(Fx.toBase(txn.amount, txn.currency)),
        ],
      ),
    );
  }
}
