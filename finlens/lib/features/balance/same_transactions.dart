import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/models.dart';
import '../../core/utils/date_range.dart';

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
  /// - income / expense → category + account + direction
  /// - transfer         → from-account + to-account (directional)
  /// - rebalance is not a spec'd case; it falls back to a per-account ledger key
  ///   so a tapped revaluation row still opens a coherent (if rare) list.
  static SameKey of(Txn txn) {
    switch (txn.type) {
      case TxnType.expense:
        // expense: fromRef = account, toRef = category
        return LedgerKey(txn.toRef, txn.fromRef, TxnType.expense);
      case TxnType.income:
        // income: fromRef = category, toRef = account
        return LedgerKey(txn.fromRef, txn.toRef, TxnType.income);
      case TxnType.transfer:
        return TransferKey(txn.fromRef, txn.toRef);
      case TxnType.rebalance:
        // No category exists; group by the affected account.
        return LedgerKey(txn.toRef, txn.toRef, TxnType.rebalance);
    }
  }

  bool get isTransfer => this is TransferKey;
}

/// Income/expense/rebalance key: one category, on one account, one direction.
class LedgerKey extends SameKey {
  const LedgerKey(this.categoryId, this.accountId, this.direction);

  final String categoryId;
  final String accountId;
  final TxnType direction;

  @override
  bool operator ==(Object other) =>
      other is LedgerKey &&
      other.categoryId == categoryId &&
      other.accountId == accountId &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(categoryId, accountId, direction);
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
    required this.perMonth,
    required this.lastDaysAgo,
  });

  final double total;
  final int count;
  final double average;
  final int spanDays;

  /// null when the span is under 14 days — too little data to claim a rate.
  final double? perMonth;

  /// Whole days since the most recent match, or null when the list is empty.
  final int? lastDaysAgo;

  static const empty = SameStats(
    total: 0,
    count: 0,
    average: 0,
    spanDays: 0,
    perMonth: null,
    lastDaysAgo: null,
  );

  factory SameStats.of(List<Txn> list, DateTime today) {
    if (list.isEmpty) return empty;
    final total = list.fold<double>(0, (sum, t) => sum + t.amount.abs());
    final count = list.length;
    final newest = list.first.date; // list is newest-first
    final oldest = list.last.date;
    final spanDays = newest.difference(oldest).inDays;
    final day = DateTime(today.year, today.month, today.day);
    return SameStats(
      total: total,
      count: count,
      average: total / count,
      spanDays: spanDays,
      // "about N a month" from under two weeks of data is a fabrication.
      perMonth: spanDays < 14 ? null : count / (spanDays / 30.44),
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
