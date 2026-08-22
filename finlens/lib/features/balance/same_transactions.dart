import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/models.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/fx.dart';

/// The composite key a tapped transaction resolves to. Every transaction that
/// shares this key belongs on the Same-transactions screen.
///
/// Matching is always by **id**, never by name — a renamed category or account
/// keeps its list intact. The description is deliberately *not* part of the key.
@immutable
sealed class SameKey {
  const SameKey();

  /// Resolves a transaction to its key.
  ///
  /// - income / expense → category + direction (NOT the account: one Groceries
  ///   list spans every account it was paid from — see [LedgerKey]).
  /// - transfer         → from-account + to-account (directional)
  /// - rebalance is not a spec'd case; it falls back to a per-account ledger key
  ///   so a tapped revaluation row still opens a coherent (if rare) list.
  static SameKey of(Txn txn) {
    switch (txn.type) {
      case TxnType.expense:
        // expense: toRef = category
        return LedgerKey(txn.toRef, TxnType.expense);
      case TxnType.income:
        // income: fromRef = category
        return LedgerKey(txn.fromRef, TxnType.income);
      case TxnType.transfer:
        return TransferKey(txn.fromRef, txn.toRef);
      case TxnType.rebalance:
        // No category exists; group by the affected account.
        return LedgerKey(txn.toRef, TxnType.rebalance);
    }
  }

  bool get isTransfer => this is TransferKey;
}

/// Income/expense/rebalance key: one category, one direction — deliberately
/// *not* scoped to an account, so a category's list spans every account it
/// touched (spec §2). For a rebalance there is no category, so [categoryId]
/// holds the affected account id instead.
class LedgerKey extends SameKey {
  const LedgerKey(this.categoryId, this.direction);

  final String categoryId;
  final TxnType direction;

  @override
  bool operator ==(Object other) =>
      other is LedgerKey &&
      other.categoryId == categoryId &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(categoryId, direction);
}

/// Directional transfer key: `A → B` and `B → A` are different lists.
class TransferKey extends SameKey {
  const TransferKey(this.fromAccountId, this.toAccountId);

  final String fromAccountId;
  final String toAccountId;

  @override
  bool operator ==(Object other) =>
      other is TransferKey &&
      other.fromAccountId == fromAccountId &&
      other.toAccountId == toAccountId;

  @override
  int get hashCode => Object.hash(fromAccountId, toAccountId);
}

/// The summary metrics for a range-filtered list. Pure; [list] must be sorted
/// newest-first.
@immutable
class SameStats {
  const SameStats({
    required this.total,
    required this.count,
    required this.average,
    required this.spanDays,
    required this.denominatorDays,
    required this.perMonth,
    required this.lastDaysAgo,
  });

  final double total;
  final int count;
  final double average;

  /// Days between the oldest and newest match. Still meaningful on its own, but
  /// no longer the rate's denominator — see [denominatorDays].
  final int spanDays;

  /// The observed time the rate is measured over: the selected window, or the
  /// transaction span, whichever is longer (see [SameStats.of]). This is what
  /// [perMonth] divides by, and what the 14-day floor is applied to.
  final int denominatorDays;

  /// null when [denominatorDays] is under 14 — too little observed time to
  /// claim a rate.
  final double? perMonth;

  /// Whole days since the most recent match, or null when the list is empty.
  final int? lastDaysAgo;

  static const empty = SameStats(
    total: 0,
    count: 0,
    average: 0,
    spanDays: 0,
    denominatorDays: 0,
    perMonth: null,
    lastDaysAgo: null,
  );

  /// [window] is the range the user selected, or null when that range is
  /// unbounded (All time), whose year-2000 start is artificial rather than
  /// chosen and so must not become a denominator.
  factory SameStats.of(
    List<Txn> list,
    DateTime today, {
    required DateRange? window,
  }) {
    if (list.isEmpty) return empty;
    // A widened key can span accounts in different currencies (spec §3), so the
    // aggregate is summed in base currency — a €42 row must not land as $42.
    // Rows themselves still print in their own currency; only TOTAL/AVERAGE
    // (which read [total]) are base.
    final total = list.fold<double>(
        0, (sum, t) => sum + Fx.toBase(t.amount, t.currency).abs());
    final count = list.length;
    final newest = list.first.date; // list is newest-first
    final oldest = list.last.date;
    final spanDays = newest.difference(oldest).inDays;

    // The rate is measured over the window the user is looking at — or over the
    // transactions themselves, whichever is longer. A null window keeps the
    // span (All time). For a bounded window the transactions sit inside it, so
    // it normally wins; [max] only matters for future-dated transactions in a
    // range whose end was clamped, keeping the denominator ≥ the real span.
    final int denominatorDays;
    if (window == null) {
      denominatorDays = spanDays;
    } else {
      // Clamp to today: the future has not happened, so days past today in the
      // window are not observed time (a range ending 31 Aug on the 9th, or a
      // custom range reaching into the future).
      final end = window.end.isBefore(today) ? window.end : today;
      final windowDays = end.isAfter(window.start)
          ? end.difference(window.start).inDays + 1
          : 0;
      denominatorDays = spanDays > windowDays ? spanDays : windowDays;
    }

    final day = DateTime(today.year, today.month, today.day);
    return SameStats(
      total: total,
      count: count,
      average: total / count,
      spanDays: spanDays,
      denominatorDays: denominatorDays,
      // "about N a month" from under two weeks of observed time is a
      // fabrication. The floor guards the divide, so nothing below reaches it
      // with a zero denominator.
      perMonth:
          denominatorDays < 14 ? null : count / (denominatorDays / 30.44),
      lastDaysAgo: day
          .difference(DateTime(newest.year, newest.month, newest.day))
          .inDays,
    );
  }
}

/// The seven presets offered on the Same-transactions range sheet.
///
/// A dedicated enum rather than the ledger's [RangePreset]: this set omits the
/// week presets, adds 6- and 12-month, and must not leak into the ledger's own
/// range sheet.
enum SameRangePreset {
  thisMonth('This month'),
  lastMonth('Last month'),
  last3Months('Last 3 months'),
  last6Months('Last 6 months'),
  last12Months('Last 12 months'),
  thisYear('This year'),
  allTime('All time');

  const SameRangePreset(this.label);

  final String label;

  static const defaultPreset = SameRangePreset.last3Months;

  DateRange resolve(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    DateTime endOfMonth(DateTime d) =>
        DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);
    switch (this) {
      case SameRangePreset.thisMonth:
        return DateRange(DateTime(day.year, day.month, 1), endOfMonth(day));
      case SameRangePreset.lastMonth:
        final prev = DateTime(day.year, day.month - 1, 1);
        return DateRange(prev, endOfMonth(prev));
      case SameRangePreset.last3Months:
        return DateRange(DateTime(day.year, day.month - 2, 1), endOfMonth(day));
      case SameRangePreset.last6Months:
        return DateRange(DateTime(day.year, day.month - 5, 1), endOfMonth(day));
      case SameRangePreset.last12Months:
        return DateRange(DateTime(day.year, day.month - 11, 1), endOfMonth(day));
      case SameRangePreset.thisYear:
        return DateRange(DateTime(day.year, 1, 1),
            DateTime(day.year, day.month, day.day, 23, 59, 59, 999));
      case SameRangePreset.allTime:
        return DateRange(DateTime(2000),
            DateTime(day.year, day.month, day.day, 23, 59, 59, 999));
    }
  }
}

/// The shared range choice: a preset, or a hand-picked custom window. One
/// preference for all Same-transactions screens (spec §4).
@immutable
class SameRangeChoice {
  const SameRangeChoice.preset(this.preset) : customStart = null, customEnd = null;
  const SameRangeChoice.custom(DateTime this.customStart, DateTime this.customEnd)
      : preset = null;

  final SameRangePreset? preset;
  final DateTime? customStart;
  final DateTime? customEnd;

  bool get isCustom => preset == null;

  DateRange resolve(DateTime today) => isCustom
      ? DateRange(
          DateTime(customStart!.year, customStart!.month, customStart!.day),
          DateTime(customEnd!.year, customEnd!.month, customEnd!.day,
              23, 59, 59, 999),
        )
      : preset!.resolve(today);

  static const _key = 'same_list_range';

  Map<String, dynamic> _toJson() => isCustom
      ? {'from': customStart!.toIso8601String(), 'to': customEnd!.toIso8601String()}
      : {'preset': preset!.name};

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_toJson()));
  }

  static Future<SameRangeChoice> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const SameRangeChoice.preset(SameRangePreset.defaultPreset);
    }
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        final from = json['from'], to = json['to'];
        if (from is String && to is String) {
          final start = DateTime.tryParse(from), end = DateTime.tryParse(to);
          if (start != null && end != null) {
            return SameRangeChoice.custom(start, end);
          }
        }
        final presetName = json['preset'];
        for (final p in SameRangePreset.values) {
          if (p.name == presetName) return SameRangeChoice.preset(p);
        }
      }
    } on FormatException {
      // Corrupt preference: fall back to the default.
    }
    return const SameRangeChoice.preset(SameRangePreset.defaultPreset);
  }
}
