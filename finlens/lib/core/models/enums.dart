import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Account groups. The asset/liability split drives net worth (spec 1.1) and
/// the sign interpretation of Task.expected_amount (spec 3.7).
enum AccountGroup {
  spendable('Spendable', AppColors.spendable, Icons.account_balance_wallet_rounded),
  receivables('Receivables', AppColors.receivables, Icons.receipt_long_rounded),
  investments('Investments', AppColors.investments, Icons.trending_up_rounded),
  valuables('Valuables', AppColors.valuables, Icons.diamond_rounded),
  creditCards('Credit Cards', AppColors.creditCards, Icons.credit_card_rounded),
  payables('Payables', AppColors.payables, Icons.description_rounded),
  bankLoans('Bank Loans', AppColors.bankLoans, Icons.account_balance_rounded);

  const AccountGroup(this.label, this.color, this.icon);

  final String label;
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

/// The six Quick Add entry points (spec 3.1).
enum QuickAddType {
  expense('Expense', AppColors.expense, Icons.south_west_rounded),
  income('Income', AppColors.income, Icons.north_east_rounded),
  transfer('Transfer', AppColors.transfer, Icons.swap_horiz_rounded),
  rebalance('Rebalance', AppColors.rebalance, Icons.donut_large_rounded),
  newGoal('New Goal', AppColors.goal, Icons.flag_rounded),
  newTask('New Task', AppColors.task, Icons.notifications_rounded);

  const QuickAddType(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

/// Ledger record types. `rebalance` is deliberately isolated from income/expense
/// metrics (spec 6.2 "Rebalance izolasyonu").
enum TxnType {
  expense('Expense', AppColors.expense),
  income('Income', AppColors.income),
  transfer('Transfer', AppColors.transfer),
  rebalance('Rebalance', AppColors.rebalance);

  const TxnType(this.label, this.color);

  final String label;
  final Color color;
}

enum CategoryType { expense, income }

/// Goal sub-types share one template + a type parameter (spec 3.6 / 5.2).
enum GoalType {
  saving('Saving', 'SAVING'),
  milestone('Milestone', 'MILESTONE'),
  purchase('Purchasing', 'PURCHASING');

  const GoalType(this.label, this.sectionTitle);

  final String label;
  final String sectionTitle;
}

/// Spec 6.2 — nothing with history is truly deleted; it is archived.
enum GoalStatus { active, reached, abandoned }

enum TaskStatus { open, paid, skipped }

enum Priority {
  low('Low'),
  normal('Normal'),
  high('High');

  const Priority(this.label);
  final String label;
}

enum RepeatFrequency {
  none('Never'),
  weekly('Weekly'),
  monthly('Monthly'),
  quarterly('Quarterly'),
  yearly('Yearly');

  const RepeatFrequency(this.label);
  final String label;
}

/// Comparison window for the Balance header selector (spec 1.1).
enum ComparePeriod {
  today('Today', 'vs yesterday'),
  week('Week', 'vs last week'),
  month('Month', 'vs last month');

  const ComparePeriod(this.label, this.caption);

  final String label;
  final String caption;
}
