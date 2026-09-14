/// The clock — damage report (spec §5).
///
/// **Read-only. This produces a report and writes nothing, deletes nothing,
/// changes nothing.** It never touches the user's data; it only reads the
/// store's snapshot lists and returns a value object plus a formatted string.
///
/// ## Lower bound vs upper bound
///
/// The spec's §5a suspect test needs a `createdAt` that is independent of the
/// (user-editable) transaction `date`. In this codebase the field *exists* on
/// [Txn] and round-trips through SQLite, but the pre-clock `addTxn` never set it
/// — the constructor defaulted `createdAt` to `date`. So for every record
/// written before the clock fix, `createdAt == date`, and the suspect test can
/// never fire. The report therefore degrades to §5b: **an upper bound that
/// includes genuinely-correct records** — the count and sum of everything dated
/// 9 August 2026.
///
/// From the clock fix onward `addTxn` stamps `createdAt` from `store.now`, so a
/// record misfiled to a past date *would* become detectable; the §5a machinery
/// is kept and reported (it will read 0 until such a record exists).
library;

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';

/// The frozen constant the pre-clock app used as "today".
final DateTime frozenTodayDay = DateTime(2026, 8, 9);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A record is *suspect* when the day it claims to have happened on is the
/// frozen constant's day, and the day it was actually recorded on is later. That
/// combination is only producible by the bug (spec §5a). A lower bound, not a
/// diagnosis: a record genuinely entered on 9 August is indistinguishable from a
/// correct one, and correctly so.
bool isSuspectTxn(Txn t) =>
    _sameDay(t.date, frozenTodayDay) &&
    t.createdAt.isAfter(DateTime(2026, 8, 10));

/// One row of the report table.
class DamageRow {
  const DamageRow({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.refs,
    required this.storedDate,
    required this.createdAt,
  });

  final String id;
  final String type;
  final double amount;
  final String currency;
  final String refs;
  final DateTime storedDate;
  final DateTime? createdAt;

  /// Whole days between the claimed date and the recording day. Null when there
  /// is no independent `createdAt`.
  int? get daysApart => createdAt == null
      ? null
      : DateTime(createdAt!.year, createdAt!.month, createdAt!.day)
          .difference(DateTime(storedDate.year, storedDate.month, storedDate.day))
          .inDays;
}

/// The whole report. Immutable; carries the numbers so tests can assert on them
/// without parsing [toText].
class ClockDamageReport {
  ClockDamageReport({
    required this.createdAtInformative,
    required this.suspectTxns,
    required this.aug9Txns,
    required this.aug9TxnSumByCurrency,
    required this.aug9GoalCount,
    required this.aug9TaskCount,
    required this.aug9BudgetCount,
    required this.createdAtRange,
  });

  /// False when no transaction's `createdAt` day differs from its `date` day —
  /// i.e. the field carries no independent recording time, so the report is an
  /// UPPER bound (§5b), not a lower bound (§5a).
  final bool createdAtInformative;

  /// §5a — records the suspect test flags (empty while `createdAt == date`).
  final List<DamageRow> suspectTxns;

  /// §5b — every transaction dated 9 Aug 2026 (the upper bound).
  final List<DamageRow> aug9Txns;

  /// The upper-bound sum, kept per currency because the ledger mixes currencies
  /// and summing raw magnitudes across them would be a fiction.
  final Map<String, double> aug9TxnSumByCurrency;

  /// Other entities dated / created on 9 Aug 2026 — upper bounds too.
  final int aug9GoalCount; // goals whose createdAt day is 9 Aug
  final int aug9TaskCount; // tasks whose dueDate day is 9 Aug (no createdAt)
  final int aug9BudgetCount; // budgets whose 'created' history entry is 9 Aug

  /// The min/max `createdAt` across the flagged transactions, or null when none.
  final (DateTime, DateTime)? createdAtRange;

  bool get isLowerBound => createdAtInformative && suspectTxns.isNotEmpty;

  String toText() {
    final b = StringBuffer();
    b.writeln('══ FinLens · clock damage report (§5) ══');
    b.writeln('Read-only. Nothing was changed.');
    b.writeln('');
    if (!createdAtInformative) {
      b.writeln('createdAt is NON-INFORMATIVE: every transaction has '
          'createdAt == date (the pre-clock addTxn never stamped a real '
          'recording instant). This report is therefore an UPPER BOUND that '
          'INCLUDES genuinely-correct records (§5b).');
    } else {
      b.writeln('createdAt is informative for at least one record; the suspect '
          'list below is a LOWER BOUND (§5a).');
    }
    b.writeln('');

    b.writeln('§5a suspects (date = 9 Aug 2026 AND createdAt later): '
        '${suspectTxns.length}');
    for (final r in suspectTxns) {
      b.writeln(_row(r));
    }
    b.writeln('');

    b.writeln('§5b upper bound — transactions dated 9 Aug 2026: '
        '${aug9Txns.length}');
    b.writeln('| id | type | amount | refs | stored date | createdAt | days apart |');
    for (final r in aug9Txns) {
      b.writeln(_row(r));
    }
    b.writeln('');
    b.write('Sum (per currency): ');
    if (aug9TxnSumByCurrency.isEmpty) {
      b.writeln('—');
    } else {
      b.writeln(aug9TxnSumByCurrency.entries
          .map((e) => money(e.value, currency: e.key))
          .join(', '));
    }
    final range = createdAtRange;
    b.writeln('createdAt range of flagged txns: '
        '${range == null ? '—' : '${_d(range.$1)} … ${_d(range.$2)}'}');
    b.writeln('');
    b.writeln('Other entities on 9 Aug 2026 (upper bounds):');
    b.writeln('  goals created:   $aug9GoalCount');
    b.writeln('  tasks due:       $aug9TaskCount  (Task carries no createdAt)');
    b.writeln('  budgets created: $aug9BudgetCount  (Budget carries no createdAt)');
    b.writeln('══════════════════════════════════════');
    return b.toString();
  }

  static String _row(DamageRow r) {
    final apart = r.daysApart == null ? '?' : '${r.daysApart}';
    return '| ${r.id} | ${r.type} | ${money(r.amount, currency: r.currency)} '
        '| ${r.refs} | ${_d(r.storedDate)} '
        '| ${r.createdAt == null ? '—' : _dt(r.createdAt!)} | $apart |';
  }

  static String _d(DateTime d) =>
      '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';
  static String _dt(DateTime d) =>
      '${_d(d)} ${_pad2(d.hour)}:${_pad2(d.minute)}';
  static String _pad2(int n) => n.toString().padLeft(2, '0');
}

/// Analyse [store] and return the report. Reads the store's snapshot lists only
/// — the same unfiltered views the persister reads — and mutates nothing.
ClockDamageReport analyzeClockDamage(AppStore store) {
  final txns = store.snapshotTxns;

  final informative =
      txns.any((t) => !_sameDay(t.createdAt, t.date));

  DamageRow rowOf(Txn t) => DamageRow(
        id: t.id,
        type: t.type.name,
        amount: t.amount,
        currency: t.currency,
        refs: '${t.fromRef}→${t.toRef}',
        storedDate: t.date,
        // Report createdAt only when it is independent of date; a value that
        // merely mirrors date is not a recording time and must not read as one.
        createdAt: _sameDay(t.createdAt, t.date) ? null : t.createdAt,
      );

  final suspects =
      txns.where(isSuspectTxn).map(rowOf).toList(growable: false);

  final aug9 = txns
      .where((t) => _sameDay(t.date, frozenTodayDay))
      .map(rowOf)
      .toList(growable: false);

  final sumByCurrency = <String, double>{};
  DateTime? lo, hi;
  for (final t in txns.where((t) => _sameDay(t.date, frozenTodayDay))) {
    sumByCurrency[t.currency] = (sumByCurrency[t.currency] ?? 0) + t.amount;
    if (!_sameDay(t.createdAt, t.date)) {
      if (lo == null || t.createdAt.isBefore(lo)) lo = t.createdAt;
      if (hi == null || t.createdAt.isAfter(hi)) hi = t.createdAt;
    }
  }

  final goalCount = store.snapshotGoals
      .where((g) => _sameDay(g.createdAt, frozenTodayDay))
      .length;
  final taskCount = store.snapshotTasks
      .where((t) => _sameDay(t.dueDate, frozenTodayDay))
      .length;
  final budgetCount = store.snapshotBudgets.where((bd) {
    final created = bd.history.where((e) => e.field == 'created');
    return created.isNotEmpty && _sameDay(created.first.at, frozenTodayDay);
  }).length;

  return ClockDamageReport(
    createdAtInformative: informative,
    suspectTxns: suspects,
    aug9Txns: aug9,
    aug9TxnSumByCurrency: sumByCurrency,
    aug9GoalCount: goalCount,
    aug9TaskCount: taskCount,
    aug9BudgetCount: budgetCount,
    createdAtRange: (lo != null && hi != null) ? (lo, hi) : null,
  );
}
