import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/models.dart';

/// The order the scoped-ledger list is sorted in (spec §1). One preference per
/// screen *type* (account vs the group/all bucket); see [AppStore] persistence.
enum TransSort {
  dateNewest('Date — newest first'),
  dateOldest('Date — oldest first'),
  amountHigh('Amount — high to low'),
  amountLow('Amount — low to high'),
  // Label is scope-dependent ("Category — A to Z" / "Account — A to Z"); the
  // sheet supplies it. This enum value's own label is the account-screen form.
  byName('Category — A to Z');

  const TransSort(this.label);

  final String label;

  /// Day-group headers render only under the two date sorts — a "9 AUG" header
  /// above rows from five different days would be a lie (spec §1).
  bool get groupsByDay => this == dateNewest || this == dateOldest;

  bool get isDefault => this == dateNewest;

  static TransSort byName2(String? raw) {
    for (final s in values) {
      if (s.name == raw) return s;
    }
    return dateNewest;
  }
}

/// The pre-resolved facts a filter needs from one transaction. Keeping [matches]
/// off the store makes it a pure predicate the tests can exercise directly.
@immutable
class TxnFacts {
  const TxnFacts({
    required this.type,
    required this.groupIds,
    required this.absAmount,
    required this.tags,
  });

  final TxnType type;

  /// The transaction's ids in the active grouping dimension — the category on
  /// an account screen, or the in-scope account(s) on a group/all screen. A
  /// transfer touches two accounts, hence a set.
  final Set<String> groupIds;

  /// Base-currency magnitude, always positive — matching is on absolute value
  /// so a $900 income and a $900 expense fall in the same band (spec §2).
  final double absAmount;

  final List<String> tags;
}

/// The scoped-ledger transaction filter (spec §2). Immutable; every mutation
/// returns a new instance so the sheet and the screen can share it freely.
///
/// **Within a section, OR. Across sections, AND. An empty section is no
/// constraint, not "match nothing".**
@immutable
class TransFilter {
  const TransFilter({
    this.types = const {},
    this.groupIds = const {},
    this.tags = const {},
    this.min,
    this.max,
  });

  final Set<TxnType> types;

  /// Selected category ids (account screen) or account ids (group/all screen).
  final Set<String> groupIds;

  final Set<String> tags;

  /// Bounds on absolute amount; null means unbounded on that side. A min above
  /// the max is left as-is (never swapped) and simply matches nothing (spec §8).
  final double? min;
  final double? max;

  static const empty = TransFilter();

  bool get isActive =>
      types.isNotEmpty ||
      groupIds.isNotEmpty ||
      tags.isNotEmpty ||
      min != null ||
      max != null;

  bool matches(TxnFacts f) {
    if (types.isNotEmpty && !types.contains(f.type)) return false;
    if (groupIds.isNotEmpty && !f.groupIds.any(groupIds.contains)) return false;
    // min > max yields no overlap here, so it matches nothing without a swap.
    if (min != null && f.absAmount < min!) return false;
    if (max != null && f.absAmount > max!) return false;
    if (tags.isNotEmpty && !f.tags.any(tags.contains)) return false;
    return true;
  }

  TransFilter copyWith({
    Set<TxnType>? types,
    Set<String>? groupIds,
    Set<String>? tags,
    double? min,
    double? max,
    bool clearMin = false,
    bool clearMax = false,
  }) =>
      TransFilter(
        types: types ?? this.types,
        groupIds: groupIds ?? this.groupIds,
        tags: tags ?? this.tags,
        min: clearMin ? null : (min ?? this.min),
        max: clearMax ? null : (max ?? this.max),
      );

  TransFilter toggleType(TxnType t) =>
      copyWith(types: _toggle(types, t));

  TransFilter toggleGroup(String id) =>
      copyWith(groupIds: _toggle(groupIds, id));

  TransFilter toggleTag(String tag) => copyWith(tags: _toggle(tags, tag));

  TransFilter withMin(double? v) =>
      v == null ? copyWith(clearMin: true) : copyWith(min: v);

  TransFilter withMax(double? v) =>
      v == null ? copyWith(clearMax: true) : copyWith(max: v);

  static Set<T> _toggle<T>(Set<T> set, T value) {
    final next = Set<T>.of(set);
    next.contains(value) ? next.remove(value) : next.add(value);
    return next;
  }

  // ── Persistence (spec §5) ─────────────────────────────────────────────────

  Map<String, dynamic> _toJson() => {
        if (types.isNotEmpty) 'types': types.map((t) => t.name).toList(),
        if (groupIds.isNotEmpty) 'groups': groupIds.toList(),
        if (tags.isNotEmpty) 'tags': tags.toList(),
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };

  Future<void> save(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (!isActive) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(_toJson()));
  }

  /// Loads and **prunes stale ids** (spec §5): a persisted group or tag id no
  /// longer present in [validGroups] / [validTags] is dropped silently, so a
  /// deleted category can never leave the button looking active with nothing
  /// behind it.
  static Future<TransFilter> load(
    String key,
    Set<String> validGroups,
    Set<String> validTags,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;

      final types = <TxnType>{};
      for (final n in (json['types'] as List? ?? const [])) {
        for (final t in TxnType.values) {
          if (t.name == n) types.add(t);
        }
      }
      final groups = <String>{
        for (final g in (json['groups'] as List? ?? const []))
          if (g is String && validGroups.contains(g)) g,
      };
      final tags = <String>{
        for (final t in (json['tags'] as List? ?? const []))
          if (t is String && validTags.contains(t)) t,
      };
      final min = (json['min'] as num?)?.toDouble();
      final max = (json['max'] as num?)?.toDouble();
      return TransFilter(
          types: types, groupIds: groups, tags: tags, min: min, max: max);
    } on FormatException {
      return empty;
    }
  }
}
