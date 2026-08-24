import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Account groups. The asset/liability split drives net worth (spec 1.1) and
/// the sign interpretation of Task.expected_amount (spec 3.7).
///
/// Display labels are localized — see `AccountGroupL10n.label` in
/// `core/l10n/enum_labels.dart`. The enum carries only colour + icon.
enum AccountGroup {
  spendable(AppColors.spendable, Icons.account_balance_wallet_rounded),
  receivables(AppColors.receivables, Icons.receipt_long_rounded),
  investments(AppColors.investments, Icons.trending_up_rounded),
  valuables(AppColors.valuables, Icons.diamond_rounded),
  creditCards(AppColors.creditCards, Icons.credit_card_rounded),
  payables(AppColors.payables, Icons.description_rounded),
  bankLoans(AppColors.bankLoans, Icons.account_balance_rounded);

  const AccountGroup(this.color, this.icon);

  final Color color;
  final IconData icon;

  bool get isAsset => index <= AccountGroup.valuables.index;
  bool get isLiability => !isAsset;

  /// Credit limit / utilisation only apply to borrowing accounts (spec 1.5).
  bool get hasCreditLimit =>
      this == AccountGroup.creditCards || this == AccountGroup.bankLoans;

  /// Statement day & payment due are credit-card only (spec 1.5).
  bool get hasStatement => this == AccountGroup.creditCards;

  static List<AccountGroup> get assets =>
      values.where((g) => g.isAsset).toList(growable: false);
  static List<AccountGroup> get liabilities =>
      values.where((g) => g.isLiability).toList(growable: false);
}

/// The six Quick Add entry points (spec 3.1). Labels localized — see
/// `QuickAddTypeL10n.label`.
enum QuickAddType {
  expense(AppColors.expense, Icons.south_west_rounded),
  income(AppColors.income, Icons.north_east_rounded),
  transfer(AppColors.transfer, Icons.swap_horiz_rounded),
  rebalance(AppColors.rebalance, Icons.donut_large_rounded),
  newGoal(AppColors.goal, Icons.flag_rounded),
  newTask(AppColors.task, Icons.notifications_rounded);

  const QuickAddType(this.color, this.icon);

  final Color color;
  final IconData icon;
}

/// Ledger record types. `rebalance` is deliberately isolated from income/expense
/// metrics (spec 6.2 "Rebalance izolasyonu"). Labels localized — see
/// `TxnTypeL10n.label`.
enum TxnType {
  expense(AppColors.expense),
  income(AppColors.income),
  transfer(AppColors.transfer),
  rebalance(AppColors.rebalance);

  const TxnType(this.color);

  final Color color;
}

enum CategoryType { expense, income }

/// Goal sub-types share one template + a type parameter (spec 3.6 / 5.2).
/// Labels + section titles localized — see `GoalTypeL10n`.
enum GoalType { saving, milestone, purchase }

/// Spec 6.2 — nothing with history is truly deleted; it is archived.
enum GoalStatus { active, reached, abandoned }

enum TaskStatus { open, paid, skipped }

/// Priority labels localized — see `PriorityL10n.label`.
enum Priority { low, normal, high }

/// Repeat cadences. Labels localized — see `RepeatFrequencyL10n.label`.
enum RepeatFrequency { none, weekly, monthly, quarterly, yearly }

/// Comparison window for the Balance header selector (spec 1.1). Label +
/// caption localized — see `ComparePeriodL10n`.
enum ComparePeriod { today, week, month }
