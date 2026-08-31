import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';

/// Which groups and accounts the Balance screen is currently hiding.
///
/// Stores what is *hidden* rather than what is visible, so a newly added
/// account or group defaults to visible and needs no migration.
///
/// Hiding is presentational and fully reversible — nothing is deleted or
/// archived, and no other tab or export consults this.
@immutable
class BalanceFilter {
  const BalanceFilter({
    this.hiddenGroups = const {},
    this.hiddenAccountIds = const {},
  });

  /// [AccountGroup] is an enum in this project, so groups are keyed by the
  /// enum itself rather than by a string id.
  final Set<AccountGroup> hiddenGroups;
  final Set<String> hiddenAccountIds;

  bool get isActive =>
      hiddenGroups.isNotEmpty || hiddenAccountIds.isNotEmpty;

  BalanceFilter copyWith({
    Set<AccountGroup>? hiddenGroups,
    Set<String>? hiddenAccountIds,
  }) =>
      BalanceFilter(
        hiddenGroups: hiddenGroups ?? this.hiddenGroups,
        hiddenAccountIds: hiddenAccountIds ?? this.hiddenAccountIds,
      );

  // ── Derived, pure ─────────────────────────────────────────────────────────

  List<Account> visibleAccounts(AppStore store, AccountGroup group) {
    if (hiddenGroups.contains(group)) return const [];
    return store
        .accountsIn(group)
        .where((a) => !hiddenAccountIds.contains(a.id))
        .toList(growable: false);
  }

  /// The ids of every account this filter leaves visible, across all groups —
  /// the set Insight's windowed store getters restrict to (spec §9.2). A group
  /// hidden via [hiddenGroups] drops all its accounts here just as it does in
  /// [visibleAccounts], so the two surfaces can never disagree.
  Set<String> visibleAccountIds(AppStore store) {
    final ids = <String>{};
    for (final g in AccountGroup.values) {
      for (final a in visibleAccounts(store, g)) {
        ids.add(a.id);
      }
    }
    return ids;
  }

  /// The single source of truth for whether a group renders. Never read
  /// [hiddenGroups] directly in the UI: a group with every account hidden is
  /// `off` whether or not its own id was ever added to the set.
  bool isGroupVisible(AppStore store, AccountGroup group) =>
      visibleAccounts(store, group).isNotEmpty;

  /// Sums the already-converted base-currency figure the screen uses today.
  double filteredTotal(AppStore store, AccountGroup group) =>
      visibleAccounts(store, group)
          .fold(0.0, (sum, a) => sum + store.balanceInBase(a.id));

  ToggleState toggleState(AppStore store, AccountGroup group) {
    final visible = visibleAccounts(store, group).length;
    if (visible == 0) return ToggleState.off;
    return visible == store.accountsIn(group).length
        ? ToggleState.on
        : ToggleState.mixed;
  }

  /// A fully hidden group counts as one item; a partly hidden one counts its
  /// hidden accounts. Drives the screen-reader value on the filter button.
  int hiddenItemCount(AppStore store) {
    var total = 0;
    for (final g in AccountGroup.values) {
      if (toggleState(store, g) == ToggleState.off) {
        total += 1;
      } else {
        total += store
            .accountsIn(g)
            .where((a) => hiddenAccountIds.contains(a.id))
            .length;
      }
    }
    return total;
  }

  double sectionTotal(AppStore store, {required bool assets}) {
    final groups = assets ? AccountGroup.assets : AccountGroup.liabilities;
    return groups
        .where((g) => isGroupVisible(store, g))
        .fold(0.0, (sum, g) => sum + filteredTotal(store, g));
  }

  double netWorth(AppStore store) =>
      sectionTotal(store, assets: true) -
      sectionTotal(store, assets: false).abs();

  // ── Transitions ───────────────────────────────────────────────────────────

  /// A partly filtered group always resolves to fully shown, never to hidden:
  /// the user who hid two of four accounts is mid-edit, and collapsing that to
  /// "hide everything" would throw the work away.
  BalanceFilter toggleGroup(AppStore store, AccountGroup group) {
    final ids = store.accountsIn(group).map((a) => a.id);
    final groups = Set<AccountGroup>.from(hiddenGroups);
    final accounts = Set<String>.from(hiddenAccountIds);

    if (toggleState(store, group) == ToggleState.on) {
      groups.add(group);
      accounts.addAll(ids);
    } else {
      groups.remove(group);
      accounts.removeAll(ids);
    }
    return BalanceFilter(hiddenGroups: groups, hiddenAccountIds: accounts);
  }

  BalanceFilter toggleAccount(AppStore store, Account account) {
    final group = account.group;
    final groups = Set<AccountGroup>.from(hiddenGroups);
    final accounts = Set<String>.from(hiddenAccountIds);
    final siblings = store.accountsIn(group).map((a) => a.id);

    if (toggleState(store, group) == ToggleState.off) {
      // Reviving a hidden group through one account leaves *only* that account
      // visible — switching one thing on must not switch three others on too.
      groups.remove(group);
      accounts
        ..addAll(siblings)
        ..remove(account.id);
    } else if (accounts.contains(account.id)) {
      accounts.remove(account.id);
      groups.remove(group);
    } else {
      accounts.add(account.id);
      // Hiding the last visible account closes the group itself, so the list
      // never shows an empty $0 group row.
      final stillVisible =
          siblings.where((id) => !accounts.contains(id)).isEmpty;
      if (stillVisible) groups.add(group);
    }
    return BalanceFilter(hiddenGroups: groups, hiddenAccountIds: accounts);
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  static const _groupsKey = 'balance_filter_hidden_categories';
  static const _accountsKey = 'balance_filter_hidden_accounts';

  /// Insight holds a *second*, independent filter (spec §9.1) persisted under
  /// its own keys, so hiding an account on Insight never touches Balance.
  static const insightGroupsKey = 'insight_account_filter_groups';
  static const insightAccountsKey = 'insight_account_filter_accounts';

  /// Ids that no longer match anything are dropped, so a deleted account can
  /// never leave the filter button looking active with nothing behind it.
  static BalanceFilter fromStored({
    required List<String> groups,
    required List<String> accounts,
    required AppStore store,
  }) {
    final byName = {for (final g in AccountGroup.values) g.name: g};
    final liveIds = store.accounts.map((a) => a.id).toSet();
    return BalanceFilter(
      hiddenGroups: groups
          .map((n) => byName[n])
          .whereType<AccountGroup>()
          .toSet(),
      hiddenAccountIds:
          accounts.where(liveIds.contains).toSet(),
    );
  }

  /// [groupsKey]/[accountsKey] default to Balance's own keys, so every existing
  /// call is byte-identical; Insight passes its pair (spec §9.1).
  static Future<BalanceFilter> load(
    AppStore store, {
    String groupsKey = _groupsKey,
    String accountsKey = _accountsKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return fromStored(
      groups: _decode(prefs.getString(groupsKey)),
      accounts: _decode(prefs.getString(accountsKey)),
      store: store,
    );
  }

  Future<void> save({
    String groupsKey = _groupsKey,
    String accountsKey = _accountsKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        groupsKey, jsonEncode(hiddenGroups.map((g) => g.name).toList()));
    await prefs.setString(
        accountsKey, jsonEncode(hiddenAccountIds.toList()));
  }

  static List<String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      return list is List ? list.whereType<String>().toList() : const [];
    } on FormatException {
      // Corrupt preference: fall back to "nothing hidden" rather than crash.
      return const [];
    }
  }
}

enum ToggleState { on, mixed, off }
