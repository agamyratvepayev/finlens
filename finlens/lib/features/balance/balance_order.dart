import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';

/// How accounts are ordered *inside* each group.
///
/// The four automatic orderings never touch group order — groups sit in their
/// fixed [AccountGroup] declaration order. [custom] is the only mode that
/// reorders groups (within their section) and accounts by hand, and it is only
/// ever produced by a press-and-hold drag on the Balance list.
enum AccountSort {
  valueDesc('Value — high to low'),
  valueAsc('Value — low to high'),
  nameAsc('Name — A to Z'),
  activity('Change — most active'),
  custom('Custom');

  const AccountSort(this.label);

  final String label;

  static const defaultSort = AccountSort.valueDesc;

  /// The four automatic options, in sheet order. [custom] is presented on its
  /// own below a divider and never appears in this list.
  static const automatic = <AccountSort>[valueDesc, valueAsc, nameAsc, activity];
}

/// The user's hand-made display order for the Balance list.
///
/// Holds **every** category and account, including ones the filter is currently
/// hiding, so ordering and filtering stay independent: order the full data
/// first, remove the hidden items second. This is purely presentational — no
/// account's group membership and no domain data is ever changed. Categories on
/// the Balance screen are [AccountGroup]s (an enum, no id), matching how
/// `BalanceFilter` keys them.
@immutable
class CustomOrder {
  const CustomOrder({
    this.assetOrder = const [],
    this.liabilityOrder = const [],
    this.accountOrder = const {},
  });

  /// Asset / liability group order, each a permutation of its own section.
  final List<AccountGroup> assetOrder;
  final List<AccountGroup> liabilityOrder;

  /// Account ids in user order, keyed by the owning group. An id here always
  /// belongs to its key group — foreign ids are dropped on load.
  final Map<AccountGroup, List<String>> accountOrder;

  bool get isConfigured =>
      assetOrder.isNotEmpty ||
      liabilityOrder.isNotEmpty ||
      accountOrder.isNotEmpty;

  CustomOrder copyWith({
    List<AccountGroup>? assetOrder,
    List<AccountGroup>? liabilityOrder,
    Map<AccountGroup, List<String>>? accountOrder,
  }) =>
      CustomOrder(
        assetOrder: assetOrder ?? this.assetOrder,
        liabilityOrder: liabilityOrder ?? this.liabilityOrder,
        accountOrder: accountOrder ?? this.accountOrder,
      );

  // ── Resolving the stored order against live data ──────────────────────────
  // Both resolvers use the "known, then unknown appended in data order" shape,
  // which gives the required maintenance behaviour for free: a new category or
  // account appears last in its section/category, a deleted one drops out, and
  // a stale id is ignored.

  /// Groups of a section in user order. Only groups that belong to the section
  /// are honoured (a stored group that somehow lands in the wrong section is
  /// ignored); anything missing is appended in declaration order.
  List<AccountGroup> orderedCategories({required bool assets}) {
    final all = assets ? AccountGroup.assets : AccountGroup.liabilities;
    final stored = assets ? assetOrder : liabilityOrder;
    final known = stored.where(all.contains).toList();
    final unknown = all.where((g) => !known.contains(g)).toList();
    return [...known, ...unknown];
  }

  /// Accounts of [group] in user order, unknown ones appended in data order.
  /// Operates on the full (unfiltered) account set — filtering happens after.
  List<Account> orderedAccounts(AppStore store, AccountGroup group) {
    final accounts = store.accountsIn(group);
    final byId = {for (final a in accounts) a.id: a};
    final stored = accountOrder[group] ?? const <String>[];

    final known = <Account>[];
    for (final id in stored) {
      final a = byId[id];
      if (a != null) known.add(a);
    }
    final knownIds = {for (final a in known) a.id};
    final unknown = accounts.where((a) => !knownIds.contains(a.id)).toList();
    return [...known, ...unknown];
  }

  // ── Moves ─────────────────────────────────────────────────────────────────

  /// A drag is a *relative* move, never an index assignment. The user drags in
  /// the visible list but we edit the full list, so we resolve the drop by its
  /// visible neighbour: the moved item lands immediately before the visible
  /// item it was dropped in front of, or after the last visible item if dropped
  /// at the end. Hidden items keep their positions relative to their visible
  /// neighbours, so un-hiding one returns it somewhere sensible.
  ///
  /// [visibleIds] is the visible list as the user sees it (the moved item
  /// included); [visibleTargetIndex] indexes into it — `visibleIds.length`
  /// means "dropped at the end".
  @visibleForTesting
  static List<T> moveWithinGroup<T>(
    List<T> fullOrder,
    T moved,
    int visibleTargetIndex,
    List<T> visibleIds,
  ) {
    // With no other visible item to move relative to, there is nothing to
    // reorder against — a move against hidden items must never reshuffle the
    // stored order (spec §7).
    final anchors = visibleIds.where((id) => id != moved).toList();
    if (anchors.isEmpty) return List<T>.of(fullOrder);

    final full = List<T>.of(fullOrder)..remove(moved);

    final T? successor = visibleTargetIndex < visibleIds.length
        ? visibleIds[visibleTargetIndex]
        : null;

    int insertAt;
    if (successor == null || successor == moved) {
      // Dropped at (or past) the end: place just after the last visible item
      // that isn't the moved one, so anything hidden after it keeps trailing.
      insertAt = full.indexOf(anchors.last) + 1;
    } else {
      insertAt = full.indexOf(successor);
    }
    if (insertAt < 0) insertAt = full.length;
    full.insert(insertAt.clamp(0, full.length), moved);
    return full;
  }

  /// Returns a new order with [moved] repositioned among its section's groups.
  CustomOrder withCategoryMove({
    required bool assets,
    required AccountGroup moved,
    required int visibleTargetIndex,
    required List<AccountGroup> visibleOrder,
  }) {
    final full = orderedCategories(assets: assets);
    final next = moveWithinGroup(full, moved, visibleTargetIndex, visibleOrder);
    return assets ? copyWith(assetOrder: next) : copyWith(liabilityOrder: next);
  }

  /// Returns a new order with account [moved] repositioned within [group].
  CustomOrder withAccountMove(
    AppStore store, {
    required AccountGroup group,
    required String moved,
    required int visibleTargetIndex,
    required List<String> visibleOrder,
  }) {
    final full = orderedAccounts(store, group).map((a) => a.id).toList();
    final next = moveWithinGroup(full, moved, visibleTargetIndex, visibleOrder);
    final map = {
      for (final e in accountOrder.entries) e.key: List<String>.of(e.value),
    };
    map[group] = next;
    return copyWith(accountOrder: map);
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  static const _orderKey = 'balance_custom_order';
  static const _sortKey = 'balance_sort_mode';

  Map<String, dynamic> toJson() => {
        'assets': assetOrder.map((g) => g.name).toList(),
        'liabilities': liabilityOrder.map((g) => g.name).toList(),
        'accounts': {
          for (final e in accountOrder.entries) e.key.name: e.value,
        },
      };

  /// Rebuilds from decoded JSON against live data. Group names that no longer
  /// map, ids that no longer exist, and — critically — any account id whose
  /// account does not actually belong to its key group are dropped, so a stored
  /// order can never re-parent an account.
  static CustomOrder fromStored(AppStore store, Object? decoded) {
    if (decoded is! Map) return const CustomOrder();
    final byName = {for (final g in AccountGroup.values) g.name: g};

    List<AccountGroup> section(String key, bool assets) {
      final all = assets ? AccountGroup.assets : AccountGroup.liabilities;
      final raw = decoded[key];
      if (raw is! List) return const [];
      return raw
          .whereType<String>()
          .map((n) => byName[n])
          .whereType<AccountGroup>()
          .where(all.contains)
          .toList();
    }

    final accountOrder = <AccountGroup, List<String>>{};
    final rawAccounts = decoded['accounts'];
    if (rawAccounts is Map) {
      for (final entry in rawAccounts.entries) {
        final group = byName[entry.key];
        if (group == null) continue;
        final value = entry.value;
        if (value is! List) continue;
        final valid = value.whereType<String>().where((id) {
          final a = store.accountById(id);
          return a != null && a.group == group;
        }).toList();
        if (valid.isNotEmpty) accountOrder[group] = valid;
      }
    }

    return CustomOrder(
      assetOrder: section('assets', true),
      liabilityOrder: section('liabilities', false),
      accountOrder: accountOrder,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orderKey, jsonEncode(toJson()));
  }

  static Future<CustomOrder> load(AppStore store) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_orderKey);
    if (raw == null || raw.isEmpty) return const CustomOrder();
    try {
      return fromStored(store, jsonDecode(raw));
    } on FormatException {
      return const CustomOrder();
    }
  }

  static Future<void> saveSortMode(AccountSort sort) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortKey, sort.name);
  }

  static Future<AccountSort> loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sortKey);
    for (final s in AccountSort.values) {
      if (s.name == raw) return s;
    }
    return AccountSort.defaultSort;
  }
}
