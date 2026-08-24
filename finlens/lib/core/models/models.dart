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
    this.splitGroupId,
    this.recurrenceTaskId,
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

  /// Split: every line of one divided payment shares this id; null when the
  /// transaction is not part of a split. Nothing else in the app treats these
  /// rows specially — they are ordinary transactions (spec §2).
  String? splitGroupId;

  /// Repeat: the id of the Planner Task that generates this transaction's future
  /// occurrences, or null when it does not repeat (spec §1).
  String? recurrenceTaskId;

  bool get movesCash => type != TxnType.rebalance;
}

/// What a goal watches — an account or an income category. `linkedAccountId`
/// of the old model is promoted here and is now required: a goal is a *lens*
/// over one real source, and the source decides the section, the direction and
/// the default target (§1). Locked after creation — changing it would
/// invalidate `startAmount`, every rate, the projection and the whole history.
class GoalSource {
  const GoalSource.account(this.id) : kind = GoalSourceKind.account;
  const GoalSource.category(this.id) : kind = GoalSourceKind.category;

  final GoalSourceKind kind;
  final String id;

  bool get isAccount => kind == GoalSourceKind.account;
  bool get isCategory => kind == GoalSourceKind.category;

  @override
  bool operator ==(Object other) =>
      other is GoalSource && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// One entry in a goal's change log (§7). Records only `targetAmount` and
/// `targetDate` moves, plus a `created` seed — because the verdict judges the
/// user against a target and a date the user sets, and without a record the app
/// would have amnesia and always report that things are fine.
class GoalEdit {
  const GoalEdit({
    required this.at,
    required this.field,
    required this.from,
    required this.to,
    this.amber = false,
  });

  final DateTime at;
  final String field; // 'created' | 'target' | 'targetDate'
  final String from; // formatted
  final String to; // formatted

  /// §7 — a pushed-out deadline is coloured amber; everything else is neutral.
  /// Colour states a fact; the reader forms the opinion.
  final bool amber;
}

/// Spec 6.1 — Goal, rebuilt on real balances (§1).
///
/// **A goal watches one source climb to a target by a date. Progress is read,
/// never stored.** There is no `saved` field: every figure — start, current,
/// progress, the rates, the projection — is derived from the ledger by
/// [AppStore], so nothing can drift when a past transaction is edited.
class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.source,
    required this.targetAmount,
    required this.createdAt,
    this.targetDate,
    this.endsWhenReached = true,
    this.status = GoalStatus.active,
    this.note = '',
    this.completedAt,
    this.stoppedAt,
    List<GoalEdit>? history,
  }) : history = history ?? <GoalEdit>[];

  final String id;
  String name;

  /// The account or income category this goal watches. Required and locked
  /// after creation (§3).
  GoalSource source;

  /// The balance or income total to reach. A liability source defaults this to
  /// zero (§3).
  double targetAmount;
  DateTime? targetDate;

  /// §4 — when true, the goal latches to "reached" the moment `current` first
  /// meets `target` and never un-reaches. When false (the emergency-fund case)
  /// it never latches: below target it reads "Refill", at/above it reads
  /// "Funded".
  bool endsWhenReached;

  GoalStatus status;
  String note;

  /// The reached date. Set by the latch (§4) while the goal stays *active* and
  /// keeps rendering on the Goals tab; archiving flips [status] to `reached`.
  /// Not progress storage — an audit timestamp, like `Txn.createdAt`.
  DateTime? completedAt;
  DateTime? stoppedAt;

  final DateTime createdAt;

  /// §7 — target/date change history, seeded with a `created` entry.
  List<GoalEdit> history;

  /// True once the target was met at some point (§4). Persisted through
  /// [completedAt] so later movement cannot un-reach a latched goal.
  bool get isLatched => completedAt != null;

  int? get durationMonths {
    if (completedAt == null) return null;
    return (completedAt!.year - createdAt.year) * 12 +
        (completedAt!.month - createdAt.month);
  }
}

/// Everything a goal's card and detail screen need, derived from the ledger by
/// [AppStore.goalMetrics] (§1). The Goal itself stores none of this.
class GoalMetrics {
  const GoalMetrics({
    required this.section,
    required this.start,
    required this.current,
    required this.target,
    required this.targetDate,
    required this.progress,
    required this.reached,
    required this.atTarget,
    required this.sourceAvailable,
    required this.monthsElapsed,
    required this.monthsRemaining,
    required this.requiredRate,
    required this.actualRate,
    required this.projectedEnd,
    required this.daysElapsed,
    required this.daysTotal,
  });

  final GoalSection section;
  final double start;
  final double current;
  final double target;
  final DateTime? targetDate;

  /// 0..1 — `((current - start).abs() / (target - start).abs()).clamp(0,1)`.
  final double progress;

  /// current has met target *and* the goal latches (endsWhenReached). Drives the
  /// green check and "Reached" verdict.
  final bool reached;

  /// current is at or past target in the goal's direction, regardless of
  /// endsWhenReached — the Funded/Refill decision for a refillable fund (§4).
  final bool atTarget;

  /// false when the watched account was archived or deleted elsewhere; the
  /// card keeps rendering from the last balance and offers "Stop tracking".
  final bool sourceAvailable;

  final int monthsElapsed;
  final int monthsRemaining;

  /// |target − current| / months remaining. Null when there is no target date.
  final double? requiredRate;

  /// |current − start| / months elapsed. Null when no month has elapsed or the
  /// source has not moved forward (`AT THIS RATE` then shows `—`).
  final double? actualRate;

  /// now + |target − current| / actualRate months. Null when `actualRate <= 0`.
  final DateTime? projectedEnd;

  final int daysElapsed;
  final int daysTotal;

  double get gap => (target - current).abs();

  /// Below target, the amount still needed — used by the "Refill \$X" verdict.
  double get remaining => (target - current).abs();

  /// Behind schedule: the projection lands after the target date. Drives the
  /// amber "needs attention" sort and the behind/ahead verdict split. A goal
  /// that has not moved at all (`projectedEnd == null`) but has a date to miss
  /// counts as behind.
  bool get behind =>
      !reached &&
      targetDate != null &&
      monthsElapsed > 0 &&
      (projectedEnd == null || projectedEnd!.isAfter(targetDate!));

  /// The one figure the card leads with: needs attention first, then by date.
  bool get needsAttention => sourceAvailable ? behind : true;
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
