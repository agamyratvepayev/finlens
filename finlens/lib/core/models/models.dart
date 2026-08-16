import 'package:flutter/material.dart';

import 'enums.dart';

export 'enums.dart';

/// Spec 6.1 — Account.
///
/// `startingBalance` is write-once: after creation the live balance is derived
/// from transactions only (spec 6.2, "Starting balance kilidi").
class Account {
  Account({
    required this.id,
    required this.name,
    required this.group,
    required this.currency,
    required this.startingBalance,
    this.creditLimit,
    this.statementDay,
    this.paymentDue,
    this.hidden = false,
    this.archived = false,
    this.countAsSpendable = true,
    this.icon,
    this.openedOn,
  });

  final String id;
  String name;
  AccountGroup group;
  String currency;
  final double startingBalance;
  double? creditLimit;
  int? statementDay;
  int? paymentDue;

  /// Spec 1.5 — hidden accounts leave the list but stay in the totals.
  bool hidden;
  bool archived;
  bool countAsSpendable;
  IconData? icon;

  /// When the account started existing. null means "always" — seed accounts
  /// predate the ledger, so they show on any reporting date.
  final DateTime? openedOn;

  IconData get displayIcon => icon ?? group.icon;
  Color get color => group.color;
  bool get isAsset => group.isAsset;
  bool get isLiability => group.isLiability;

  Account copyWith({
    String? name,
    AccountGroup? group,
    String? currency,
    double? creditLimit,
    int? statementDay,
    int? paymentDue,
    bool? hidden,
    bool? archived,
    bool? countAsSpendable,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      group: group ?? this.group,
      currency: currency ?? this.currency,
      startingBalance: startingBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      statementDay: statementDay ?? this.statementDay,
      paymentDue: paymentDue ?? this.paymentDue,
      hidden: hidden ?? this.hidden,
      archived: archived ?? this.archived,
      countAsSpendable: countAsSpendable ?? this.countAsSpendable,
      icon: icon,
      openedOn: openedOn,
    );
  }
}

/// Spec 6.1 — Category. The budget is *fields on the category*, not a separate
/// entity: Quick Add's picker and Planner > Budgets read the same record
/// (spec 4.1 / 5.4). Removing a budget sets [monthlyBudget] to null (spec 5.5).
class Category {
  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.monthlyBudget,
    this.budgetRollover = false,
    this.warnThreshold = 0.8,
    this.rolloverAmount = 0,
    this.archived = false,
    this.removedOn,
  });

  final String id;
  String name;
  CategoryType type;
  IconData icon;
  Color color;

  /// null == not budgeted. Presence is what puts it in Planner > Budgets.
  double? monthlyBudget;
  bool budgetRollover;
  double warnThreshold;
  double rolloverAmount;

  bool archived;
  DateTime? removedOn;

  /// Spec 5.4 — rollover adds last month's leftover on top of the limit.
  double? get effectiveLimit =>
      monthlyBudget == null ? null : monthlyBudget! + (budgetRollover ? rolloverAmount : 0);
}

/// Spec 6.1 — Transaction. `fromRef`/`toRef` are polymorphic: they hold an
/// Account id or a Category id depending on [type].
class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.fromRef,
    required this.toRef,
    required this.date,
    this.exchangeRate,
    this.toAmount,
    this.fee,
    this.feeFromSource = true,
    this.tags = const [],
    this.note = '',
    this.editedCount = 0,
    DateTime? createdAt,
    this.goalId,
  }) : createdAt = createdAt ?? date;

  final String id;
  final TxnType type;
  double amount;
  String currency;

  /// Account id for expense(from)/income(to)/transfer(both)/rebalance(asset).
  /// Category id for expense(to)/income(from).
  String fromRef;
  String toRef;

  DateTime date;
  double? exchangeRate;

  /// Destination amount for cross-currency transfers (spec 3.4).
  double? toAmount;
  double? fee;
  bool feeFromSource;

  List<String> tags;
  String note;

  /// Spec 2.3 — audit trail ("Created 9 Aug, 14:32 · edited once").
  int editedCount;
  final DateTime createdAt;
  String? goalId;

  bool get movesCash => type != TxnType.rebalance;
}

/// Spec 6.1 — Goal. One template, three sub-types (spec 3.6).
class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.type,
    required this.targetAmount,
    required this.linkedAccountId,
    required this.icon,
    this.targetDate,
    this.saved = 0,
    this.autoContribute = false,
    this.autoContributeAmount,
    this.autoContributeDay = 1,
    this.status = GoalStatus.active,
    this.completedAt,
    this.stoppedAt,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  GoalType type;
  double targetAmount;
  String linkedAccountId;
  IconData icon;
  DateTime? targetDate;
  double saved;
  bool autoContribute;
  double? autoContributeAmount;
  int autoContributeDay;
  GoalStatus status;
  DateTime? completedAt;
  DateTime? stoppedAt;
  String note;
  final DateTime createdAt;

  double get remaining => (targetAmount - saved).clamp(0, double.infinity);
  double get progress =>
      targetAmount <= 0 ? 0 : (saved / targetAmount).clamp(0.0, 1.0);
  bool get isComplete => saved >= targetAmount;

  /// Spec 5.2 — (target − saved) / months left. Null when no target date, in
  /// which case the row shows "No target date set" instead.
  double? get monthlyNeeded {
    if (targetDate == null || isComplete) return null;
    final months = monthsLeft;
    if (months <= 0) return remaining;
    return remaining / months;
  }

  int get monthsLeft {
    if (targetDate == null) return 0;
    final now = DateTime.now();
    return (targetDate!.year - now.year) * 12 + (targetDate!.month - now.month);
  }

  /// How long a reached goal took — feeds Insight > Goal Performance (spec 5.6).
  int? get durationMonths {
    if (completedAt == null) return null;
    return (completedAt!.year - createdAt.year) * 12 +
        (completedAt!.month - createdAt.month);
  }
}

/// Spec 6.1 — Task. A recurring obligation is ONE record plus a repeat rule;
/// skipping a single occurrence appends to [skippedDates] rather than spawning
/// rows (spec 5.7, "Seri vs örnek").
class Task {
  Task({
    required this.id,
    required this.title,
    required this.linkedAccountId,
    required this.expectedAmount,
    required this.dueDate,
    required this.icon,
    this.categoryId,
    this.repeats = RepeatFrequency.none,
    this.skippedDates = const [],
    this.priority = Priority.normal,
    this.reminderDaysBefore,
    this.reminderTime,
    this.status = TaskStatus.open,
  });

  final String id;
  String title;
  String linkedAccountId;

  /// Sign is meaningful: negative == pay-out, positive == pay-in (spec 3.7).
  double expectedAmount;
  DateTime dueDate;
  IconData icon;

  /// Which budget category "Mark as paid" books the entry against (spec 5.3).
  /// Without it the entry would silently land in an arbitrary category and
  /// distort that budget.
  String? categoryId;
  RepeatFrequency repeats;
  List<DateTime> skippedDates;
  Priority priority;
  int? reminderDaysBefore;
  TimeOfDay? reminderTime;
  TaskStatus status;

  bool get isPayOut => expectedAmount < 0;
  bool get isRecurring => repeats != RepeatFrequency.none;

  bool get isOverdue =>
      status == TaskStatus.open && dueDate.isBefore(DateTime.now());

  int get daysUntilDue {
    final now = DateTime.now();
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return due.difference(today).inDays;
  }

  /// Advances the series past [from] honouring the repeat rule.
  DateTime nextOccurrence(DateTime from) {
    var next = from;
    switch (repeats) {
      case RepeatFrequency.none:
        return from;
      case RepeatFrequency.weekly:
        next = from.add(const Duration(days: 7));
      case RepeatFrequency.monthly:
        next = DateTime(from.year, from.month + 1, from.day);
      case RepeatFrequency.quarterly:
        next = DateTime(from.year, from.month + 3, from.day);
      case RepeatFrequency.yearly:
        next = DateTime(from.year + 1, from.month, from.day);
    }
    return next;
  }

  /// The next 3 dates shown as a preview in New/Edit Task (spec 3.7 / 5.7).
  List<DateTime> upcomingPreview([int count = 3]) {
    final out = <DateTime>[];
    var d = dueDate;
    while (out.length < count && isRecurring) {
      out.add(d);
      d = nextOccurrence(d);
    }
    return out;
  }
}
