import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/models.dart';

/// Row mappers between the six persisted domain entities and SQLite rows.
///
/// The models themselves stay Flutter-pure (no db code in `models.dart`); all
/// serialization concerns live here. Column values are always SQLite-native
/// (int / double / String / null) — the hazardous field types are encoded:
///   - enums  → `.name` string (never index; declaration order is load-bearing
///     for `AccountGroup.isAsset`, so an index would be fragile across reorders)
///   - IconData → codePoint + fontFamily + fontPackage + matchTextDirection
///   - Color  → ARGB int via `toARGB32()`
///   - TimeOfDay → minutes since midnight
///   - DateTime → millisecondsSinceEpoch
///   - embedded lists / value objects → a JSON TEXT column (never queried
///     relationally, so join tables would be pure overhead)
///
/// `fromMap` is defensive: unknown enum names fall back to a safe default and
/// malformed JSON decodes to empty, so a partially-corrupt row degrades rather
/// than crashing the launch.

// ── Accounts ────────────────────────────────────────────────────────────────

Map<String, Object?> accountToMap(Account a) => {
      'id': a.id,
      'name': a.name,
      'group_name': a.group.name,
      'currency': a.currency,
      'starting_balance': a.startingBalance,
      'credit_limit': a.creditLimit,
      'statement_day': a.statementDay,
      'payment_due': a.paymentDue,
      'hidden': _b(a.hidden),
      'archived': _b(a.archived),
      'count_as_spendable': _b(a.countAsSpendable),
      ..._iconColumns(a.icon),
      'opened_on': _dt(a.openedOn),
      'opening_date': _dt(a.openingDate),
    };

Account accountFromMap(Map<String, Object?> m) => Account(
      id: m['id'] as String,
      name: m['name'] as String,
      group: _enumByName(AccountGroup.values, m['group_name'], AccountGroup.spendable),
      currency: m['currency'] as String,
      startingBalance: _d(m['starting_balance']),
      creditLimit: _dn(m['credit_limit']),
      statementDay: m['statement_day'] as int?,
      paymentDue: m['payment_due'] as int?,
      hidden: _bf(m['hidden']),
      archived: _bf(m['archived']),
      countAsSpendable: _bf(m['count_as_spendable']),
      icon: _iconFromRow(m),
      openedOn: _dtn(m['opened_on']),
      openingDate: _dtn(m['opening_date']),
    );

// ── Categories ──────────────────────────────────────────────────────────────

Map<String, Object?> categoryToMap(Category c) => {
      'id': c.id,
      'name': c.name,
      'type_name': c.type.name,
      ..._iconColumns(c.icon),
      'color_argb': c.color.toARGB32(),
      'monthly_budget': c.monthlyBudget,
      'budget_rollover': _b(c.budgetRollover),
      'warn_threshold': c.warnThreshold,
      'rollover_amount': c.rolloverAmount,
      'archived': _b(c.archived),
      'removed_on': _dt(c.removedOn),
      'budget_history':
          jsonEncode(c.budgetHistory.map(_budgetEditToJson).toList()),
    };

Category categoryFromMap(Map<String, Object?> m) => Category(
      id: m['id'] as String,
      name: m['name'] as String,
      type: _enumByName(CategoryType.values, m['type_name'], CategoryType.expense),
      icon: _iconFromRow(m) ?? Icons.category_rounded,
      color: Color((m['color_argb'] as int?) ?? 0xFF9E9E9E),
      monthlyBudget: _dn(m['monthly_budget']),
      budgetRollover: _bf(m['budget_rollover']),
      warnThreshold: _d(m['warn_threshold']),
      rolloverAmount: _d(m['rollover_amount']),
      archived: _bf(m['archived']),
      removedOn: _dtn(m['removed_on']),
      budgetHistory: _decodeList(m['budget_history'])
          .map((e) => _budgetEditFromJson(e as Map<String, dynamic>))
          .toList(),
    );

// ── Transactions ────────────────────────────────────────────────────────────

Map<String, Object?> txnToMap(Txn t) => {
      'id': t.id,
      'type_name': t.type.name,
      'amount': t.amount,
      'currency': t.currency,
      'from_ref': t.fromRef,
      'to_ref': t.toRef,
      'date': _dt(t.date),
      'exchange_rate': t.exchangeRate,
      'to_amount': t.toAmount,
      'fee': t.fee,
      'fee_from_source': _b(t.feeFromSource),
      'tag_ids': jsonEncode(t.tagIds),
      'note': t.note,
      'edited_count': t.editedCount,
      'created_at': _dt(t.createdAt),
      'goal_id': t.goalId,
      'split_group_id': t.splitGroupId,
      'recurrence_task_id': t.recurrenceTaskId,
    };

Txn txnFromMap(Map<String, Object?> m) => Txn(
      id: m['id'] as String,
      type: _enumByName(TxnType.values, m['type_name'], TxnType.expense),
      amount: _d(m['amount']),
      currency: m['currency'] as String,
      fromRef: m['from_ref'] as String,
      toRef: m['to_ref'] as String,
      date: _dtn(m['date'])!,
      exchangeRate: _dn(m['exchange_rate']),
      toAmount: _dn(m['to_amount']),
      fee: _dn(m['fee']),
      feeFromSource: _bf(m['fee_from_source']),
      tagIds: _decodeList(m['tag_ids']).map((e) => e as String).toList(),
      note: (m['note'] as String?) ?? '',
      editedCount: (m['edited_count'] as int?) ?? 0,
      createdAt: _dtn(m['created_at']),
      goalId: m['goal_id'] as String?,
      splitGroupId: m['split_group_id'] as String?,
      recurrenceTaskId: m['recurrence_task_id'] as String?,
    );

// ── Tags ────────────────────────────────────────────────────────────────────

Map<String, Object?> tagToMap(Tag t) => {
      'id': t.id,
      'name': t.name,
      'archived': _b(t.archived),
      'created_at': _dt(t.createdAt),
      'last_used_at': _dt(t.lastUsedAt),
    };

Tag tagFromMap(Map<String, Object?> m) => Tag(
      id: m['id'] as String,
      name: m['name'] as String,
      archived: _bf(m['archived']),
      createdAt: _dtn(m['created_at'])!,
      lastUsedAt: _dtn(m['last_used_at'])!,
    );

// ── Goals ───────────────────────────────────────────────────────────────────

Map<String, Object?> goalToMap(Goal g) => {
      'id': g.id,
      'name': g.name,
      'source_kind': g.source.kind.name,
      'source_id': g.source.id,
      'target_amount': g.targetAmount,
      'target_date': _dt(g.targetDate),
      'ends_when_reached': _b(g.endsWhenReached),
      'status_name': g.status.name,
      'note': g.note,
      'completed_at': _dt(g.completedAt),
      'stopped_at': _dt(g.stoppedAt),
      'created_at': _dt(g.createdAt),
      'history': jsonEncode(g.history.map(_goalEditToJson).toList()),
    };

Goal goalFromMap(Map<String, Object?> m) {
  final kind =
      _enumByName(GoalSourceKind.values, m['source_kind'], GoalSourceKind.account);
  final sourceId = m['source_id'] as String;
  final source = kind == GoalSourceKind.account
      ? GoalSource.account(sourceId)
      : GoalSource.category(sourceId);
  return Goal(
    id: m['id'] as String,
    name: m['name'] as String,
    source: source,
    targetAmount: _d(m['target_amount']),
    createdAt: _dtn(m['created_at'])!,
    targetDate: _dtn(m['target_date']),
    endsWhenReached: _bf(m['ends_when_reached']),
    status: _enumByName(GoalStatus.values, m['status_name'], GoalStatus.active),
    note: (m['note'] as String?) ?? '',
    completedAt: _dtn(m['completed_at']),
    stoppedAt: _dtn(m['stopped_at']),
    history: _decodeList(m['history'])
        .map((e) => _goalEditFromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ── Tasks ───────────────────────────────────────────────────────────────────

Map<String, Object?> taskToMap(Task t) => {
      'id': t.id,
      'title': t.title,
      'linked_account_id': t.linkedAccountId,
      'expected_amount': t.expectedAmount,
      'due_date': _dt(t.dueDate),
      ..._iconColumns(t.icon),
      'category_id': t.categoryId,
      'pay_to_account_id': t.payToAccountId,
      'note': t.note,
      'status_changed_at': _dt(t.statusChangedAt),
      'repeats_name': t.repeats.name,
      'weekdays': jsonEncode(t.weekdays.toList()),
      'days_of_month': jsonEncode(t.daysOfMonth.toList()),
      'skipped_dates':
          jsonEncode(t.skippedDates.map((d) => d.millisecondsSinceEpoch).toList()),
      'priority_name': t.priority.name,
      'reminder_days_before': t.reminderDaysBefore,
      'reminder_time_minutes': _timeOfDay(t.reminderTime),
      'status_name': t.status.name,
    };

Task taskFromMap(Map<String, Object?> m) => Task(
      id: m['id'] as String,
      title: m['title'] as String,
      linkedAccountId: m['linked_account_id'] as String,
      expectedAmount: _d(m['expected_amount']),
      dueDate: _dtn(m['due_date'])!,
      icon: _iconFromRow(m) ?? Icons.notifications_rounded,
      categoryId: m['category_id'] as String?,
      payToAccountId: m['pay_to_account_id'] as String?,
      note: m['note'] as String?,
      statusChangedAt: _dtn(m['status_changed_at']),
      repeats:
          _enumByName(RepeatFrequency.values, m['repeats_name'], RepeatFrequency.none),
      weekdays: _decodeList(m['weekdays']).map((e) => (e as num).toInt()).toSet(),
      daysOfMonth:
          _decodeList(m['days_of_month']).map((e) => (e as num).toInt()).toSet(),
      skippedDates: _decodeList(m['skipped_dates'])
          .map((e) => DateTime.fromMillisecondsSinceEpoch((e as num).toInt()))
          .toList(),
      priority: _enumByName(Priority.values, m['priority_name'], Priority.normal),
      reminderDaysBefore: m['reminder_days_before'] as int?,
      reminderTime: _timeOfDayFrom(m['reminder_time_minutes']),
      status: _enumByName(TaskStatus.values, m['status_name'], TaskStatus.open),
    );

// ── Embedded value objects ──────────────────────────────────────────────────

Map<String, Object?> _budgetEditToJson(BudgetEdit b) => {
      'at': b.at.millisecondsSinceEpoch,
      'field': b.field,
      'from': b.from,
      'to': b.to,
      'amber': b.amber,
    };

BudgetEdit _budgetEditFromJson(Map<String, dynamic> j) => BudgetEdit(
      at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
      field: j['field'] as String,
      from: j['from'] as String? ?? '',
      to: j['to'] as String? ?? '',
      amber: (j['amber'] as bool?) ?? false,
    );

Map<String, Object?> _goalEditToJson(GoalEdit g) => {
      'at': g.at.millisecondsSinceEpoch,
      'field': g.field,
      'from': g.from,
      'to': g.to,
      'amber': g.amber,
    };

GoalEdit _goalEditFromJson(Map<String, dynamic> j) => GoalEdit(
      at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
      field: j['field'] as String,
      from: j['from'] as String? ?? '',
      to: j['to'] as String? ?? '',
      amber: (j['amber'] as bool?) ?? false,
    );

// ── Codec helpers ───────────────────────────────────────────────────────────

int _b(bool v) => v ? 1 : 0;
bool _bf(Object? v) => (v as int? ?? 0) != 0;

/// Non-null double read (SQLite may hand back an int for a whole number).
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
double? _dn(Object? v) => (v as num?)?.toDouble();

int? _dt(DateTime? d) => d?.millisecondsSinceEpoch;
DateTime? _dtn(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

int? _timeOfDay(TimeOfDay? t) => t == null ? null : t.hour * 60 + t.minute;
TimeOfDay? _timeOfDayFrom(Object? v) {
  if (v == null) return null;
  final mins = (v as num).toInt();
  return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
}

Map<String, Object?> _iconColumns(IconData? icon) => {
      'icon_code_point': icon?.codePoint,
      'icon_font_family': icon?.fontFamily,
      'icon_font_package': icon?.fontPackage,
      'icon_match_text_direction':
          icon == null ? null : _b(icon.matchTextDirection),
    };

IconData? _iconFromRow(Map<String, Object?> m) {
  final cp = m['icon_code_point'] as int?;
  if (cp == null) return null;
  // Reconstructed dynamically from stored codepoints — the const IconData
  // constructor flags non-const args, which is exactly the intent here. The app
  // must be built with `--no-tree-shake-icons` so these glyphs still ship.
  // ignore: non_const_argument_for_const_parameter
  return IconData(cp, fontFamily: m['icon_font_family'] as String?, fontPackage: m['icon_font_package'] as String?, matchTextDirection: _bf(m['icon_match_text_direction']));
}

List<dynamic> _decodeList(Object? v) {
  if (v == null) return const [];
  try {
    final decoded = jsonDecode(v as String);
    return decoded is List ? decoded : const [];
  } on FormatException {
    return const [];
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
