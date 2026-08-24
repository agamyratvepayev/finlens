import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';

/// How accounts are ordered *inside* each group.
///
/// Groups always sit in their fixed [AccountGroup] declaration order — no sort
/// mode, including [custom], ever reorders them. [custom] is a hand-made
/// **account** order only, produced by a press-and-hold drag on the Balance
/// list.
/// Labels localized — see [AccountSortL10n.label].
enum AccountSort {
  valueDesc,
  valueAsc,
  nameAsc,
  activity,
  custom;

  static const defaultSort = AccountSort.valueDesc;

  /// The four automatic options, in sheet order. [custom] is presented on its
  /// own below a divider and never appears in this list.
  static const automatic = <AccountSort>[valueDesc, valueAsc, nameAsc, activity];
}

extension AccountSortL10n on AccountSort {
  String label(AppLocalizations l) => switch (this) {
        AccountSort.valueDesc => l.accountSortValueDesc,
        AccountSort.valueAsc => l.accountSortValueAsc,
        AccountSort.nameAsc => l.accountSortNameAsc,
        AccountSort.activity => l.accountSortActivity,
        AccountSort.custom => l.accountSortCustom,
      };
}

/// The user's hand-made account order for the Balance list.
///
/// Holds **every** account, including ones the filter is currently hiding, so
/// ordering and filtering stay independent: order the full data first, remove
/// the hidden items second. Groups (categories) are never reordered — they are
/// fixed [AccountGroup] declaration order — so this holds accounts only. Purely
/// presentational: no account's group membership and no domain data is ever
/// changed.
@immutable
class CustomOrder {
  const CustomOrder({this.accountOrder = const {}});

  /// Account ids in user order, keyed by the owning group. An id here always
  /// belongs to its key group — foreign ids are dropped on load.
  final Map<AccountGroup, List<String>> accountOrder;

  bool get isConfigured => accountOrder.isNotEmpty;

  CustomOrder copyWith({Map<AccountGroup, List<String>>? accountOrder}) =>
      CustomOrder(accountOrder: accountOrder ?? this.accountOrder);

  // ── Resolving the stored order against live data ──────────────────────────
  // The resolver uses the "known, then unknown appended in data order" shape,
  // which gives the required maintenance behaviour for free: a new account
  // appears last in its category, a deleted one drops out, a stale id is
  // ignored.

  /// Groups of a section, always in fixed declaration order — no custom order
  /// reorders categories any more. Kept as a method so the Balance filter sheet
  /// (which asks for "the same order the list uses") needs no change.
  List<AccountGroup> orderedCategories({required bool assets}) =>
      assets ? AccountGroup.assets : AccountGroup.liabilities;

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

  // No 'assets' / 'liabilities' keys any more: categories are fixed order, so
  // only the account order is persisted. A prior version's stored category keys
  // are simply not read (see [fromStored]) and are dropped on the next save.
  Map<String, dynamic> toJson() => {
        'accounts': {
          for (final e in accountOrder.entries) e.key.name: e.value,
        },
      };

  /// Rebuilds from decoded JSON against live data. Ids that no longer exist and
  /// — critically — any account id whose account does not actually belong to
  /// its key group are dropped, so a stored order can never re-parent an
  /// account. Legacy top-level 'assets' / 'liabilities' category keys from an
  /// older build are ignored silently (never read), so one load-save cycle
  /// cleans them out of the stored JSON.
  static CustomOrder fromStored(AppStore store, Object? decoded) {
    if (decoded is! Map) return const CustomOrder();
    final byName = {for (final g in AccountGroup.values) g.name: g};

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

    return CustomOrder(accountOrder: accountOrder);
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
