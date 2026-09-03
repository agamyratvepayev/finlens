import 'package:flutter/material.dart';

import 'enums.dart';

export 'enums.dart';
export 'currency_def.dart';

/// Spec 6.1 — Account.
///
/// [startingBalance] is the account's **opening balance**: the floor its whole
/// running-balance column is built on (`startingBalance + Σ transactions`). It
/// was write-once ("Starting balance kilidi"), but the Opening-balance receipt
/// makes that floor a first-class, editable value — a floor, not a transaction:
/// it is a row with a date, but it takes no part in the ledger's arithmetic.
/// Editing it is the one blessed way to move a past balance directly (Opening
/// balance sheet / Edit Account), so it is now mutable; every other balance is
/// still derived and never stored. [openingDate] is the day that history begins,
/// where the synthesized opening row is filed. Amount 0 means "no floor" and no
/// row renders.
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
    this.emoji,
    this.colorValue,
    this.openedOn,
    this.openingDate,
  });

  final String id;
  String name;
  AccountGroup group;
  String currency;

  /// The opening balance (signed like every balance: negative for liabilities).
  /// Mutable so the Opening-balance receipt can edit/clear it; still the single
  /// seed the running-balance column derives from.
  double startingBalance;
  double? creditLimit;
  int? statementDay;
  int? paymentDue;

  /// Spec 1.5 — hidden accounts leave the list but stay in the totals.
  bool hidden;
  bool archived;
  bool countAsSpendable;
  IconData? icon;

  /// An emoji chosen in the icon picker's Emoji tab (spec §7b). When set it is
  /// the account's glyph, drawn on a tile tinted with [color]; the emoji keeps
  /// its own colours. Mutually exclusive with a deliberately-chosen [icon] —
  /// picking one clears the other at the call site.
  String? emoji;

  /// A colour the user picked freely in the icon picker (spec §7b), stored as an
  /// ARGB int. Null means "follow the type", so [color] falls back to
  /// [group]'s colour — the app's long-standing default. The account's type
  /// stays legible regardless: Balance conveys it through its group heading, not
  /// this colour.
  int? colorValue;

  /// When the account started existing. null means "always" — seed accounts
  /// predate the ledger, so they show on any reporting date.
  final DateTime? openedOn;

  /// The day the account's history begins — where the Opening-balance row is
  /// filed (spec §1). null means the account carries no opening receipt (no
  /// floor to render), independent of [startingBalance].
  DateTime? openingDate;

  IconData get displayIcon => icon ?? group.icon;

  /// The account's own colour: a freely-chosen [colorValue] when set, else the
  /// type's colour (spec §7b). Callers that draw the account's glyph tile pick
  /// this up automatically; the type dot in the New-account form still shows
  /// `group.color` so the type reads true.
  Color? get customColor => colorValue == null ? null : Color(colorValue!);
  Color get color => customColor ?? group.color;

  /// True when the glyph should render as an emoji rather than an [IconData].
  bool get hasEmoji => emoji != null && emoji!.isNotEmpty;
  bool get isAsset => group.isAsset;
  bool get isLiability => group.isLiability;

  /// Whether an opening receipt should render for this account: it must have a
  /// non-zero floor *and* a date to file it under (spec §1 / §9 — "Amount 0
  /// means no floor").
  bool get hasOpeningReceipt =>
      openingDate != null && startingBalance.abs() >= 0.005;

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
      emoji: emoji,
      colorValue: colorValue,
      openedOn: openedOn,
      openingDate: openingDate,
    );
  }
}

/// One recorded change to a category's budget (budget-detail CHANGES). Written
/// by the store on every budget write path; never derived, never edited, never
/// deleted. A deliberate sibling of [GoalEdit], not a shared class: a budget
/// edit has its own field vocabulary and the two must be free to diverge.
class BudgetEdit {
  const BudgetEdit({
    required this.at,
    required this.field,
    required this.from,
    required this.to,
    this.amber = false,
  });

  final DateTime at;

  /// 'created' | 'limit' | 'rollover' | 'warn' | 'removed' | 'restored'
  /// | 'categoryArchived'
  final String field;

  /// Formatted, and language-neutral: money via `money()`, percent via
  /// `percent()`, or a machine token ('on'/'off') the render layer localises —
  /// the store holds no [AppLocalizations]. Empty for entries with no prior
  /// value ('created' repurposes it to carry the rollover token). For a
  /// 'created' entry it holds the rollover state ('on'/'off'), never displayed
  /// as-is.
  final String from;

  /// Formatted (see [from]); empty for 'categoryArchived'.
  final String to;

  /// A raised limit is amber; everything else is neutral. Colour states a fact;
  /// the reader forms the opinion.
  final bool amber;
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
    List<BudgetEdit>? budgetHistory,
  }) : budgetHistory = budgetHistory ?? <BudgetEdit>[];

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

  /// Budget edit history (budget-detail CHANGES). Empty for a category that has
  /// never been budgeted, and for budgets that predate this feature — the store
  /// does not backfill a guessed `created` entry.
  List<BudgetEdit> budgetHistory;

  /// Spec 5.4 — rollover adds last month's leftover on top of the limit.
  double? get effectiveLimit =>
      monthlyBudget == null ? null : monthlyBudget! + (budgetRollover ? rolloverAmount : 0);
}

/// A tag is a real entity, not a bare string on a transaction.
///
/// It became one the moment tags needed to be *archived*: a tag with no
/// existence apart from its uses has nothing to mark. Promoting it to an id-bearing
/// record also makes rename a single field update (not a bulk rewrite of every
/// transaction carrying the old text) and collapses case/whitespace duplicates
/// (`#Fun`, `#fun `) into one thing.
///
/// [name] is stored **without** the leading `#`, case-preserved for display but
/// compared case-insensitively for uniqueness (`foldTag`). [lastUsedAt] is
/// stored, never derived: it orders the picker and the management list, so a full
/// ledger scan on every build is not acceptable. It advances when a transaction
/// gains the tag and when a transaction carrying it is edited to a later date —
/// see `AppStore._touchTags`.
class Tag {
  Tag({
    required this.id,
    required this.name,
    this.archived = false,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final String id;
  String name;
  bool archived;
  DateTime createdAt;

  /// Stored, not derived (see class doc). Monotonic — only ever moves forward.
  DateTime lastUsedAt;
}

/// The folded key two tag names are compared under for uniqueness: trimmed and
/// lower-cased, so `#Fun`, `#fun` and `#fun ` are the same tag. Display keeps the
/// user's casing; only equality folds. Kept beside [Tag] so every call site —
/// migration, create, rename/merge — folds identically.
String foldTag(String name) => name.trim().toLowerCase();

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
    this.tagIds = const [],
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

  /// Tag ids ([Tag.id]), not names. Resolve to display names through
  /// `AppStore.tagNames`; the migration in `AppStore` rewrites legacy name-lists
  /// into id-lists once on load.
  List<String> tagIds;
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

/// What happened to a scheduled occurrence, for the completed section (§5),
/// the History screen (§6) and a task's own history (§11.5).
enum ScheduleOutcome { paid, received, skipped, cancelled }

/// One resolved occurrence — a payment made, money received, a recurring skip,
/// or a cancelled one-off. Built by [AppStore.scheduleEvents]. For `paid` /
/// `received` the amount and date come from the [txn]; for `skipped` /
/// `cancelled` there is no transaction and the amount is the task's current
/// expected amount (no snapshot is taken at skip time — see §11.5).
class ScheduleEvent {
  ScheduleEvent({
    required this.date,
    required this.task,
    required this.outcome,
    required this.amountInBase,
    this.txn,
  });

  final DateTime date;
  final Task task;
  final Txn? txn;
  final ScheduleOutcome outcome;
  final double amountInBase;

  bool get didNotHappen =>
      outcome == ScheduleOutcome.skipped || outcome == ScheduleOutcome.cancelled;
}

/// The record [AppStore.markTaskPaid] returns — everything needed to reverse the
/// three effects of a mark-paid (the written Txn, the advanced series, an
/// optionally remembered amount) from a snackbar Undo (§10.3).
class MarkPaidResult {
  MarkPaidResult({
    required this.task,
    required this.txn,
    required this.previousDueDate,
    required this.previousStatus,
    required this.previousStatusChangedAt,
    required this.previousExpected,
  });

  final Task task;
  final Txn txn;
  final DateTime previousDueDate;
  final TaskStatus previousStatus;
  final DateTime? previousStatusChangedAt;
  final double previousExpected;
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

  /// The day this goal stopped being live — the as-of date for every figure on
  /// its archived record. A reached goal freezes on [completedAt], an abandoned
  /// one on [stoppedAt]; an active goal has no end and returns null.
  DateTime? get endedAt => completedAt ?? stoppedAt;
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
    this.weekdays = const {},
    this.daysOfMonth = const {},
    this.skippedDates = const [],
    this.priority = Priority.normal,
    this.reminderDaysBefore,
    this.reminderTime,
    this.status = TaskStatus.open,
    this.note,
    this.payToAccountId,
    this.statusChangedAt,
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
  /// distort that budget. Null for a transfer task (its money moves between two
  /// accounts, so it carries no budget category — see [payToAccountId]).
  String? categoryId;

  /// Set ⇒ "Mark as paid" writes a **transfer** into this account rather than an
  /// expense against a category (§10.4). Used for paying down a liability (a
  /// credit-card statement): a spend would grow the debt it settles, so paying
  /// it must move money between two of the user's own accounts. Mutually
  /// exclusive with [categoryId].
  String? payToAccountId;

  /// A free-text note attached to the task itself (not to any one payment) —
  /// rendered on the Task detail screen, edited from ••• → Edit (§7.4). Null or
  /// empty ⇒ the NOTE section does not render.
  String? note;

  /// When [status] last moved to paid / skipped / paused / deleted — powers the
  /// Archive subtitles ("Paused 9 Aug") and the detail-screen paused banner
  /// (§7.7 / §9). Null while the task is open.
  DateTime? statusChangedAt;

  RepeatFrequency repeats;

  /// Weekdays a weekly series fires on, [DateTime.monday]..[DateTime.sunday].
  /// Empty means "the seed date's own weekday". Ignored unless
  /// `repeats == weekly`.
  Set<int> weekdays;

  /// Days of the month a series fires on, 1..31. For `monthly` this is the set
  /// of days the user *chose* (one or several); for `quarterly`/`yearly` it
  /// carries the single chosen day so the cadence never drifts (there is no
  /// grid for those — see the Repeat sheet). Empty means "the seed date's own
  /// day".
  ///
  /// These are the days the user chose, never rewritten to a day a short month
  /// forced: a month too short fires on its last day (clamped), and the next
  /// long-enough month returns to the chosen day.
  Set<int> daysOfMonth;

  List<DateTime> skippedDates;
  Priority priority;
  int? reminderDaysBefore;
  TimeOfDay? reminderTime;
  TaskStatus status;

  bool get isPayOut => expectedAmount < 0;
  bool get isRecurring => repeats != RepeatFrequency.none;

  /// Whether the money moves between two of the user's own accounts (§10.4).
  /// A pay-out with a [payToAccountId] pays down a liability and is booked as a
  /// transfer, not a spend.
  bool get isTransfer => isPayOut && payToAccountId != null;

  /// Overdue relative to [today] — the app's single clock (`AppStore.today`),
  /// never `DateTime.now()`. Schedule was the only surface reading the wall
  /// clock; passing the reference date in keeps it in sync with every other tab
  /// (§11.1). A model importing the store would be the wrong layering direction.
  bool isOverdue(DateTime today) =>
      status == TaskStatus.open && daysUntilDue(today) < 0;

  /// Whole days from [today] to [dueDate], at day granularity (time-of-day on
  /// either side is discarded). Negative ⇒ overdue. See [isOverdue] on why the
  /// reference date is a parameter.
  int daysUntilDue(DateTime today) {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final ref = DateTime(today.year, today.month, today.day);
    return due.difference(ref).inDays;
  }

  /// Advances the series past [from] honouring the repeat rule. Pure — takes no
  /// clock reading, so a preview and a real advance always agree.
  ///
  /// The chosen day/weekday is read from [daysOfMonth]/[weekdays] (or, when
  /// those are empty, from [from] itself for backward compatibility). Month
  /// candidates are *clamped* to the month's length, never allowed to roll
  /// forward — so a series due on the 31st fires on a short month's last day and
  /// returns to the 31st afterwards instead of drifting to the 1st.
  DateTime nextOccurrence(DateTime from) {
    switch (repeats) {
      case RepeatFrequency.none:
        return from;
      case RepeatFrequency.weekly:
        if (weekdays.isEmpty) return from.add(const Duration(days: 7));
        return _nextWeekday(from, weekdays);
      case RepeatFrequency.biweekly:
        return from.add(const Duration(days: 14));
      case RepeatFrequency.monthly:
        return _nextMonthly(from, daysOfMonth.isEmpty ? {from.day} : daysOfMonth);
      case RepeatFrequency.quarterly:
        return _monthStep(from, 3);
      case RepeatFrequency.yearly:
        return _monthStep(from, 12);
    }
  }

  /// The next day strictly after [from] whose weekday is in [wds]. Searches the
  /// following seven days; with all seven weekdays selected this yields the very
  /// next day (a daily cadence).
  DateTime _nextWeekday(DateTime from, Set<int> wds) {
    for (var i = 1; i <= 7; i++) {
      final cand =
          DateTime(from.year, from.month, from.day + i, from.hour, from.minute);
      if (wds.contains(cand.weekday)) return cand;
    }
    return from.add(const Duration(days: 7));
  }

  /// The next date strictly after [from] whose day-of-month is in [days],
  /// searching forward month by month. Each chosen day is clamped to the
  /// candidate month's length (so 31 becomes 30/28/29 in short months) and the
  /// clamped days are visited in ascending order.
  DateTime _nextMonthly(DateTime from, Set<int> days) {
    var y = from.year, m = from.month;
    // A guard well past any real gap between two chosen days.
    for (var guard = 0; guard < 48; guard++) {
      final dim = _daysInMonth(y, m);
      final clamped = days.map((d) => d > dim ? dim : d).toSet().toList()..sort();
      for (final d in clamped) {
        final cand = DateTime(y, m, d, from.hour, from.minute);
        if (cand.isAfter(from)) return cand;
      }
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    // Unreachable in practice; keeps the return type non-null.
    return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
  }

  /// Adds [months] to [from] with the chosen day clamped to the target month.
  /// The chosen day comes from [daysOfMonth] (the seed day the user picked) so
  /// quarterly/yearly series clamp for a short month yet return to that day —
  /// e.g. 31 Jan → 30 Apr → 31 Jul, 29 Feb → 28 Feb → 29 Feb in the next leap
  /// year — rather than drifting.
  DateTime _monthStep(DateTime from, int months) {
    final seedDay = daysOfMonth.isEmpty ? from.day : daysOfMonth.first;
    final total = from.month - 1 + months;
    final y = from.year + total ~/ 12;
    final m = total % 12 + 1;
    final day = seedDay > _daysInMonth(y, m) ? _daysInMonth(y, m) : seedDay;
    return DateTime(y, m, day, from.hour, from.minute);
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// How many times this series fires in a year — drives the detail screen's
  /// `PER YEAR` figure (§7.3). A one-off has none.
  int? get occurrencesPerYear {
    switch (repeats) {
      case RepeatFrequency.none:
        return null;
      case RepeatFrequency.weekly:
        return 52;
      case RepeatFrequency.biweekly:
        return 26;
      case RepeatFrequency.monthly:
        return 12 * (daysOfMonth.isEmpty ? 1 : daysOfMonth.length);
      case RepeatFrequency.quarterly:
        return 4;
      case RepeatFrequency.yearly:
        return 1;
    }
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
