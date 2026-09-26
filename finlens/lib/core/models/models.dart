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
    this.inactive = false,
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

  /// Task 048 — an account the user no longer reaches for. It stays in every
  /// list, total and report; only the account picker leaves it out, behind a
  /// "Show inactive" row. Independent of [hidden] (Balance visibility) and
  /// [archived] (gone everywhere).
  bool inactive;
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
    bool? inactive,
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
      inactive: inactive ?? this.inactive,
      countAsSpendable: countAsSpendable ?? this.countAsSpendable,
      icon: icon,
      emoji: emoji,
      colorValue: colorValue,
      openedOn: openedOn,
      openingDate: openingDate,
    );
  }
}

/// Every reporting-currency switch (spec 021e §5): what it was, what it became,
/// the single factor applied to the whole history at the moment of the switch,
/// and when. Kept because a figure that looks wrong a year from now is only
/// explicable with this row. [factor] is *how many of [to] one unit of [from]
/// buys* — the number every stored base value was multiplied by.
class BaseCurrencyChange {
  const BaseCurrencyChange({
    required this.from,
    required this.to,
    required this.factor,
    required this.at,
  });

  final String from;
  final String to;
  final double factor;
  final DateTime at;

  Map<String, Object?> toJson() => {
        'from': from,
        'to': to,
        'factor': factor,
        'at': at.millisecondsSinceEpoch,
      };

  static BaseCurrencyChange fromJson(Map<String, dynamic> j) => BaseCurrencyChange(
        from: j['from'] as String,
        to: j['to'] as String,
        factor: (j['factor'] as num).toDouble(),
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
      );
}

/// One recorded change to a budget (budget-detail CHANGES). Written by the store
/// on every budget write path; never derived, never edited, never deleted. A
/// deliberate sibling of [GoalEdit], not a shared class: a budget edit has its
/// own field vocabulary and the two must be free to diverge.
///
/// History now lives on [Budget], not [Category] — the budget became its own
/// object (budgets-as-object spec §A). The migration carries each category's
/// old `budgetHistory` onto the synthesized [Budget] verbatim.
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
  /// | 'categoryArchived' | 'categories' (targets changed — budgets-as-object
  /// spec §C.3)
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

/// What a budget's [Budget.targets] point at (budgets-as-object spec §A.1).
/// `tag` is reserved: the field exists so the enum need not be reshaped later,
/// but nothing reads it (spec §G — tag budgets are a non-goal).
enum BudgetScope { categories, account, tag }

/// How a budget's period is measured (spec §A.1). `month` walks whole calendar
/// months from [Budget.anchor]'s day-of-month, so its length is read from the
/// calendar every period (28–31 days) and is *not* `lengthDays: 30`. `days`
/// walks a fixed [Budget.lengthDays] stride from [Budget.anchor].
enum BudgetPeriod { month, days }

/// A budget — its own object, no longer three fields on a [Category]
/// (budgets-as-object spec §A). It fixes three independent axes that the old
/// `Category.monthlyBudget` conflated: the period ([period]/[lengthDays]),
/// the scope ([scope]/[targets]) and the lifetime ([repeats]/[endedAt]).
///
/// Nothing derived is stored: spend, percentages, days elapsed and the
/// pass/fail outcome are always recomputed from the ledger through
/// `AppStore.budgetWindow` / `budgetSpend`, so a budget can never drift from the
/// transactions (spec §C.3 / Hard boundary).
class Budget {
  Budget({
    required this.id,
    required this.name,
    required this.scope,
    required Set<String> targets,
    required this.limit,
    String? currency,
    this.period = BudgetPeriod.month,
    this.lengthDays,
    required this.anchor,
    this.repeats = true,
    this.rollover = false,
    this.warnThreshold = 0.8,
    this.endedAt,
    this.archivedAt,
    List<BudgetEdit>? history,
  })  : targets = {...targets},
        currency = currency ?? '',
        history = history ?? <BudgetEdit>[];

  final String id;

  /// Required: a multi-category budget has no single category name to borrow
  /// (spec §A.1). For a migrated single-category budget it is the category's
  /// name.
  String name;

  BudgetScope scope;

  /// Category ids (for [BudgetScope.categories]) or exactly one account id (for
  /// [BudgetScope.account]).
  Set<String> targets;

  /// The limit, in [currency] (spec 021d §1). It is **never** converted: a
  /// ₺8,000 budget stays 8,000 whatever the dollar does.
  double limit;

  /// The currency this promise is made in (spec 021d §1a). Spending in it counts
  /// natively, with no conversion; other currencies convert into it at today's
  /// rate. Empty string means "the reporting currency" — the live default, used
  /// by every single-currency user and by budgets created/persisted before this
  /// field existed. Resolve through `AppStore.budgetCurrencyOf`, never read raw.
  String currency;

  BudgetPeriod period;

  /// Null when [period] is [BudgetPeriod.month]; the fixed stride otherwise.
  int? lengthDays;

  /// The first period's start. For [BudgetPeriod.month] only its day-of-month is
  /// read (an anchor on the 13th yields 13 Aug – 12 Sep); for [BudgetPeriod.days]
  /// it is the concrete first day the stride steps from.
  DateTime anchor;

  bool repeats;

  /// Carried from the immediately preceding period only, and only when
  /// [repeats] && [rollover] (spec §A.3). Meaningless — and hidden — when
  /// [repeats] is false.
  bool rollover;

  /// 0..1; carried over unchanged from the old `Category.warnThreshold`.
  double warnThreshold;

  /// Set when a non-repeating budget's window closed, or the reader stopped it
  /// (spec §C.5). A finished budget's definition is then locked so recomputing
  /// over the closed window is stable.
  DateTime? endedAt;

  /// Set when the budget is archived — it then leaves the Budgets tab in every
  /// month and lives only in the Archive (spec §C.5). The migration maps a
  /// removed budget's `removedOn` here so the Archive keeps its contents.
  DateTime? archivedAt;

  /// Change log (budget-detail CHANGES), same shape as the old
  /// `Category.budgetHistory`, carried across by the migration.
  List<BudgetEdit> history;

  bool get isArchived => archivedAt != null;
  bool get isFinished => endedAt != null;
}

/// Spec 6.1 — Category. The budget is no longer fields on the category: it moved
/// to its own [Budget] object (budgets-as-object spec §A). A category is only a
/// name, type, glyph and colour now; whether it is budgeted is answered by
/// `AppStore.monthlyBudgetForCategory`, not a field here.
class Category {
  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.emoji,
    this.createdAt,
    this.archived = false,
  });

  final String id;
  String name;
  CategoryType type;
  IconData icon;
  Color color;

  /// An emoji chosen in the shared icon picker's Emoji tab (category-picker
  /// spec §6/§7), mirroring [Account.emoji]. When set it is the category's glyph,
  /// drawn on a tile tinted with [color]; the emoji keeps its own colours.
  /// Null means "use [icon]", the app's long-standing behaviour, so existing
  /// rows and pre-change backups render exactly as before.
  String? emoji;

  /// When the category was created — the tiebreaker for the usage-ordered picker
  /// grid (equal use ⇒ newest first, category-picker spec §3). Null for seed
  /// categories and any row that predates this field (a backup restored from an
  /// older `schemaVersion`); a null [createdAt] sorts oldest, so those settle
  /// below equally-unused newer ones and rendering is otherwise unchanged.
  DateTime? createdAt;

  /// True when the glyph should render as an emoji rather than an [icon]
  /// (mirrors [Account.hasEmoji]).
  bool get hasEmoji => emoji != null && emoji!.isNotEmpty;

  bool archived;
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
    double? rateToBase,
    double? amountBase,
    this.fee,
    this.feeFromSource = true,
    this.tagIds = const [],
    this.note = '',
    this.editedCount = 0,
    DateTime? createdAt,
    this.goalId,
    this.splitGroupId,
    this.recurrenceTaskId,
    this.recurrenceDueDate,
    this.feeTxnId,
  })  : createdAt = createdAt ?? date,
        // Both fields are conceptually non-nullable (spec 021b §1): every entry
        // owns a frozen rate and base value. The constructor still accepts them
        // as optional so pre-021b construction sites keep compiling — an omitted
        // pair defaults to "already in the reporting currency" (rate 1, base ==
        // amount). `addTxn`/`updateTxn` and the seed always pass real values.
        rateToBase = rateToBase ?? 1.0,
        amountBase = amountBase ??
            ((rateToBase == null || rateToBase == 0)
                ? amount
                : amount / rateToBase);

  final String id;
  final TxnType type;
  double amount;
  String currency;

  /// Account id for expense(from)/income(to)/transfer(both)/rebalance(asset).
  /// Category id for expense(to)/income(from).
  String fromRef;
  String toRef;

  DateTime date;

  /// Cross rate of a cross-currency **transfer** only: the *from→to* rate. From
  /// 021c its provenance inverts — it is *derived* from the entered arrival
  /// (`toAmount / amount`), no longer the input. Null on every non-transfer
  /// record and on same-currency transfers. Distinct from [rateToBase]: this
  /// relates the two accounts, [rateToBase] relates the entry to the reporting
  /// currency.
  double? exchangeRate;

  /// Destination amount for cross-currency transfers (spec 3.4). From 021c this
  /// is the number the user types (what actually landed), not a derived figure.
  double? toAmount;

  /// Units of this entry's currency per one unit of the reporting currency, as
  /// it stood when the entry was made — `1 USD = 40.125 TRY` is stored as
  /// 40.125 (spec 021b §1). **Frozen:** correcting the currency's rate later
  /// never touches it. `1` when the entry is already in the reporting currency.
  double rateToBase;

  /// [amount] in the reporting currency at [rateToBase] (`amount / rateToBase`),
  /// rounded once — at entry — to the reporting currency's decimals (spec 021b
  /// §1). Every flow figure sums this field, so a category total and the rows
  /// inside it agree to the cent. Deriving it per read would round each row and
  /// then the sum diverge.
  double amountBase;

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

  /// The occurrence a task payment closed — [Task.dueDate] at the moment
  /// Mark-as-paid ran, at day granularity (task 058 §6). Null on every other
  /// entry, and on task payments written before this field existed — such a
  /// payment can still be undone, but the series is left on its current date.
  DateTime? recurrenceDueDate;

  /// Transfer fee link: on a `transfer`, the id of the separate `expense` Txn
  /// that books this transfer's fee (Transfer-fee spec §4). A transfer moves
  /// money and spends nothing, so the fee — money that genuinely leaves — is a
  /// second record against its own category, joined here so the two are deleted
  /// and edited together. Null on transfers with no fee and on every non-transfer
  /// record. The legacy `fee`/`feeFromSource` fields are no longer written by the
  /// form; they remain for older data and are reported, not removed.
  String? feeTxnId;

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
    this.previousOverride,
  });

  final Task task;
  final Txn txn;
  final DateTime previousDueDate;
  final TaskStatus previousStatus;
  final DateTime? previousStatusChangedAt;
  final double previousExpected;

  /// The per-occurrence override the settled occurrence carried, if any
  /// (task 064 §7e) — advancing past the occurrence drops it, so Undo puts it
  /// back alongside the due date it belongs to.
  final double? previousOverride;
}

/// The snapshot [AppStore.skipTask] returns so a skip can be undone (task 065
/// §6b). For a recurring skip [skippedDate] is the day appended to
/// [Task.skippedDates] and [previousDue] the due date before the advance; for a
/// cancelled one-off both are null/unused and only the status is restored.
class TaskSkip {
  const TaskSkip({
    required this.task,
    required this.previousDue,
    required this.previousStatus,
    required this.previousStatusChangedAt,
    this.skippedDate,
    this.previousOverride,
  });

  final Task task;
  final DateTime previousDue;
  final TaskStatus previousStatus;
  final DateTime? previousStatusChangedAt;
  final DateTime? skippedDate;
  final double? previousOverride;
}

/// The snapshot [AppStore.deleteTaskForGood] returns so a delete can be undone
/// (task 065 §3a): the removed task (its object is untouched) and the ids of
/// the transactions whose recurrence link the purge nulled, to re-link.
class TaskDeletion {
  const TaskDeletion({required this.task, required this.linkedTxnIds});

  final Task task;
  final List<String> linkedTxnIds;
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
    String? currency,
    this.targetDate,
    this.endsWhenReached = true,
    this.status = GoalStatus.active,
    this.note = '',
    this.completedAt,
    this.stoppedAt,
    List<GoalEdit>? history,
  })  : currency = currency ?? '',
        history = history ?? <GoalEdit>[];

  final String id;
  String name;

  /// The account or income category this goal watches. Required and locked
  /// after creation (§3).
  GoalSource source;

  /// The balance or income total to reach. A liability source defaults this to
  /// zero (§3).
  double targetAmount;

  /// The currency [targetAmount] is in (spec 021d §2a). An account-sourced goal
  /// inherits the account's — progress is that account's *native* balance, so
  /// measuring the target in any other currency would let the rate move the bar
  /// when nothing was saved. A category-sourced goal spans accounts, so it uses
  /// the reporting currency. Empty string means "the reporting currency" (the
  /// live default and the migration value); resolve through
  /// `AppStore.goalCurrencyOf`. Set at creation and locked with [source].
  final String currency;
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
    this.repeatInterval = 1,
    this.repeatUnit,
    this.repeatEndDate,
    this.repeatEndCount,
    this.skippedDates = const [],
    this.priority = Priority.normal,
    this.reminderDaysBefore,
    this.reminderTime,
    this.status = TaskStatus.open,
    this.note,
    this.payToAccountId,
    this.statusChangedAt,
    Map<DateTime, double> amountOverrides = const {},
  }) : amountOverrides = Map.of(amountOverrides);

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

  /// `Every N unit` step size for a `custom` repeat (1..99). 1 for every other
  /// cadence. See the transaction form's Custom sheet.
  int repeatInterval;

  /// The unit a `custom` repeat steps by; null unless `repeats == custom`.
  RepeatUnit? repeatUnit;

  /// End condition, set by the transaction form's Ends sheet. At most one of
  /// [repeatEndDate] / [repeatEndCount] is non-null; both null means the series
  /// never ends. [repeatEndCount] counts the **first occurrence** toward the
  /// total (so 2 is the floor — one occurrence is not a repeat) and is ≥ 2.
  ///
  /// Stored and round-tripped, but the Planner's on-demand advance does not yet
  /// stop the series at the limit — enforcing that is recurrence-engine work
  /// kept out of scope. See the transaction Repeat spec §1 / §6.
  DateTime? repeatEndDate;
  int? repeatEndCount;

  List<DateTime> skippedDates;

  /// Per-occurrence expected amounts (task 064 §7a), keyed by the occurrence's
  /// day (local midnight). Signed like [expectedAmount]. An occurrence with no
  /// entry expects [expectedAmount]. Entries before [dueDate] are dropped when
  /// the series advances past them.
  final Map<DateTime, double> amountOverrides;

  Priority priority;
  int? reminderDaysBefore;
  TimeOfDay? reminderTime;
  TaskStatus status;

  bool get isPayOut => expectedAmount < 0;
  bool get isRecurring => repeats != RepeatFrequency.none;

  /// The amount this occurrence expects (task 064 §7c): its override, or the
  /// series' [expectedAmount]. [day] is compared at day granularity.
  double amountOn(DateTime day) =>
      amountOverrides[DateTime(day.year, day.month, day.day)] ?? expectedAmount;

  /// Whether [day]'s occurrence carries its own amount (the Upcoming dot).
  bool hasOverrideOn(DateTime day) =>
      amountOverrides.containsKey(DateTime(day.year, day.month, day.day));

  /// Whether the money moves between two of the user's own accounts (§10.4).
  /// A pay-out with a [payToAccountId] pays down a liability and is booked as a
  /// transfer, not a spend.
  bool get isTransfer => isPayOut && payToAccountId != null;

  /// Overdue relative to [today] — the app's single clock (`store.today`),
  /// never the wall clock. Schedule was the only surface reading the wall
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
      case RepeatFrequency.daily:
        return DateTime(
            from.year, from.month, from.day + 1, from.hour, from.minute);
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
      case RepeatFrequency.custom:
        return _nextCustom(from);
    }
  }

  /// Steps a `custom` rule by `repeatInterval` units. For a single-interval week
  /// or month cadence the chosen day-sets are honoured through the same helpers
  /// weekly/monthly use (so the 29/30/31 short-month clamp applies); for
  /// multi-interval cadences the step advances whole periods from the anchor —
  /// honouring day-sets *across* an interval is Planner-engine work left out of
  /// scope (transaction Repeat spec §1). Pure, like [nextOccurrence].
  DateTime _nextCustom(DateTime from) {
    final n = repeatInterval < 1 ? 1 : repeatInterval;
    switch (repeatUnit ?? RepeatUnit.month) {
      case RepeatUnit.day:
        return DateTime(
            from.year, from.month, from.day + n, from.hour, from.minute);
      case RepeatUnit.week:
        if (n == 1 && weekdays.isNotEmpty) return _nextWeekday(from, weekdays);
        return DateTime(
            from.year, from.month, from.day + 7 * n, from.hour, from.minute);
      case RepeatUnit.month:
        if (n == 1 && daysOfMonth.isNotEmpty) return _nextMonthly(from, daysOfMonth);
        return _monthStep(from, n);
      case RepeatUnit.year:
        return _monthStep(from, 12 * n);
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
      case RepeatFrequency.daily:
        return 365;
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
      case RepeatFrequency.custom:
        final n = repeatInterval < 1 ? 1 : repeatInterval;
        switch (repeatUnit ?? RepeatUnit.month) {
          case RepeatUnit.day:
            return (365 / n).round();
          case RepeatUnit.week:
            return (52 / n).round() * (weekdays.isEmpty ? 1 : weekdays.length);
          case RepeatUnit.month:
            return (12 / n).round() *
                (daysOfMonth.isEmpty ? 1 : daysOfMonth.length);
          case RepeatUnit.year:
            return n <= 1 ? 1 : 0;
        }
    }
  }

  /// The whole series from [first] (which counts as occurrence #1), honouring
  /// the end condition ([repeatEndDate] / [repeatEndCount]). Pure — writes
  /// nothing and does not touch the Planner's on-demand advance; used for
  /// previews and tests. `12 times` yields twelve dates including [first], and
  /// an end date stops the series at the last occurrence on or before it
  /// (transaction Repeat spec §6). [cap] bounds a never-ending rule.
  List<DateTime> boundedSeries(DateTime first, {int cap = 2000}) {
    final out = <DateTime>[first];
    if (!isRecurring) return out;
    var d = first;
    while (out.length < cap) {
      if (repeatEndCount != null && out.length >= repeatEndCount!) break;
      final next = nextOccurrence(d);
      if (repeatEndDate != null && next.isAfter(repeatEndDate!)) break;
      out.add(next);
      d = next;
    }
    return out;
  }

  /// Every occurrence of this series that falls inside `[from, to]`, inclusive,
  /// at day granularity (task 057 §2). A non-repeating task yields its own
  /// [dueDate] when it is in range. Honours [repeatEndDate] / [repeatEndCount]
  /// exactly as [boundedSeries] does — [dueDate] is occurrence #1 of the live
  /// series — and drops [skippedDates]. Pure, and bounded: it walks with
  /// [nextOccurrence] and stops at [to], at the end condition, or after [cap]
  /// **in-range** occurrences.
  ///
  /// Occurrences before [from] are skipped without counting against [cap], so a
  /// slightly-overdue recurring task still fills the window; a large hard
  /// ceiling guards the pathological case (a long-unpaid high-frequency series)
  /// so the walk always terminates. On a daily rule over a 3-month window this
  /// collects ~90 dates (well under the default cap); on a never-ending weekly
  /// rule it stops at [to] far sooner, and only an unbounded window would reach
  /// the cap.
  List<DateTime> occurrencesIn(DateTime from, DateTime to, {int cap = 400}) {
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);
    final out = <DateTime>[];
    if (toDay.isBefore(fromDay)) return out;

    bool isSkipped(DateTime d) => skippedDates
        .any((s) => s.year == d.year && s.month == d.month && s.day == d.day);
    void keep(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      if (!isSkipped(day)) out.add(day);
    }

    if (!isRecurring) {
      final day = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (!day.isBefore(fromDay) && !day.isAfter(toDay)) keep(day);
      return out;
    }

    var d = dueDate; // occurrence #1 of the live series
    var index = 1; // toward repeatEndCount
    var collected = 0; // in-range occurrences, toward cap
    // Pathological-termination guard: bounds the pre-[from] walk of a
    // long-overdue high-frequency series, which does not spend [cap].
    for (var iters = 0; iters < 20000; iters++) {
      final day = DateTime(d.year, d.month, d.day);
      if (day.isAfter(toDay)) break;
      if (repeatEndCount != null && index > repeatEndCount!) break;
      if (!day.isBefore(fromDay)) {
        keep(day);
        if (++collected >= cap) break;
      }
      final next = nextOccurrence(d);
      if (repeatEndDate != null && next.isAfter(repeatEndDate!)) break;
      if (!next.isAfter(d)) break; // no forward progress — stop
      d = next;
      index++;
    }
    return out;
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
