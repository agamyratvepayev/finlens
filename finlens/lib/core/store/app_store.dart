import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/balance/balance_filter.dart';
import '../../features/balance/balance_order.dart';
import '../../features/balance/same_transactions.dart';
import '../utils/date_range.dart';
import '../models/models.dart';
import '../utils/fx.dart';

/// Single source of truth for the whole app (spec 6.1/6.2).
///
/// Balances are never stored — they are always derived from
/// `startingBalance + Σ transactions`, which is what makes the "starting
/// balance is locked" rule (spec 6.2) enforceable rather than decorative.
class AppStore extends ChangeNotifier {
  AppStore({
    required List<Account> accounts,
    required List<Category> categories,
    required List<Txn> txns,
    required List<Goal> goals,
    required List<Task> tasks,
  })  : _accounts = List.of(accounts),
        _categories = List.of(categories),
        _txns = List.of(txns),
        _goals = List.of(goals),
        _tasks = List.of(tasks);

  // Copied on the way in so the seed lists can be const-ish literals and no
  // caller can mutate the store's collections behind its back.
  final List<Account> _accounts;
  final List<Category> _categories;
  final List<Txn> _txns;
  final List<Goal> _goals;
  final List<Task> _tasks;

  int _idSeq = 1000;
  String _nextId(String prefix) => '$prefix${_idSeq++}';

  // ── Reference date ────────────────────────────────────────────────────────
  // The seed data is authored around the mockups' "August 2026". Pinning
  // "today" keeps the documented screens reproducible instead of drifting.
  static final DateTime today = DateTime(2026, 8, 9, 14, 32);

  // ── Privacy mode (spec 1.1 — eye icon masks every amount) ─────────────────
  bool _masked = false;
  bool get masked => _masked;
  void toggleMasked() {
    _masked = !_masked;
    notifyListeners();
  }

  /// The date the whole page is reported as of. null == live.
  ///
  /// Because every balance is derived rather than stored, pointing this at a
  /// past date is enough to make the entire screen historical — no separate
  /// snapshot pipeline is needed.
  DateTime? _asOf;
  DateTime? get asOf => _asOf;
  bool get isHistorical => _asOf != null;

  /// End of the reporting day, so same-day transactions are included.
  DateTime get _cutoff {
    final d = _asOf ?? today;
    return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
  }

  void setAsOf(DateTime? date) {
    _asOf = date == null ? null : DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  /// Which account groups and accounts the Balance screen is hiding from its
  /// net-worth figures. Presentational and Balance-only: the store merely holds
  /// it so it can persist and notify — the screen does the actual filtering
  /// through [BalanceFilter]'s pure methods, so no other tab, total or export
  /// is affected.
  BalanceFilter _balanceFilter = const BalanceFilter();
  BalanceFilter get balanceFilter => _balanceFilter;

  /// Applies a new filter and persists it. Persistence is fire-and-forget to
  /// match the app's in-memory mutation style — the UI updates immediately and
  /// the write lands whenever it lands.
  void setBalanceFilter(BalanceFilter filter) {
    _balanceFilter = filter;
    notifyListeners();
    unawaited(filter.save());
  }

  /// Restores the persisted filter at startup (call before the first frame so
  /// the screen never flashes unfiltered values). Ids that no longer match a
  /// live account are pruned inside [BalanceFilter.load].
  Future<void> loadBalanceFilter() async {
    _balanceFilter = await BalanceFilter.load(this);
    notifyListeners();
  }

  /// Which sort the Balance list is in, and the user's hand-made order. Held
  /// here (like [balanceFilter]) so both persist and can be restored before the
  /// first frame; the screen does the actual ordering through [CustomOrder]'s
  /// pure resolvers, so nothing outside Balance is affected.
  AccountSort _balanceSort = AccountSort.defaultSort;
  AccountSort get balanceSort => _balanceSort;

  CustomOrder _balanceOrder = const CustomOrder();
  CustomOrder get balanceOrder => _balanceOrder;

  /// Selecting an option in the SORT sheet. Persisted so the choice survives a
  /// relaunch, alongside the custom order.
  void setBalanceSort(AccountSort sort) {
    _balanceSort = sort;
    notifyListeners();
    unawaited(CustomOrder.saveSortMode(sort));
  }

  /// Applies a completed drag (or an Undo): the new order, and optionally the
  /// sort mode when the drag flipped it to (or an Undo restored it from)
  /// [AccountSort.custom]. One notify, so the whole list settles at once.
  void setBalanceOrder(CustomOrder order, {AccountSort? sort}) {
    _balanceOrder = order;
    if (sort != null) _balanceSort = sort;
    notifyListeners();
    unawaited(order.save());
    if (sort != null) unawaited(CustomOrder.saveSortMode(sort));
  }

  /// Restores the persisted sort mode and custom order at startup — before the
  /// first frame, so the list never flashes a different order. Stale/foreign
  /// ids are pruned inside [CustomOrder.load].
  Future<void> loadBalanceOrder() async {
    _balanceSort = await CustomOrder.loadSortMode();
    _balanceOrder = await CustomOrder.load(this);
    notifyListeners();
  }

  // ── Same-transactions: composite-key index + range ────────────────────────

  /// Transactions bucketed by their [SameKey], each bucket newest-first. Built
  /// once and reused; invalidated (set null) by every txn mutation. This is the
  /// one index in the store — it turns the Same-transactions lookups into an
  /// O(1) map hit plus a small in-bucket filter, instead of a full scan.
  Map<SameKey, List<Txn>>? _sameIndex;

  Map<SameKey, List<Txn>> get _sameKeyIndex {
    final cached = _sameIndex;
    if (cached != null) return cached;
    final index = <SameKey, List<Txn>>{};
    for (final t in _txns) {
      (index[SameKey.of(t)] ??= <Txn>[]).add(t);
    }
    for (final bucket in index.values) {
      bucket.sort((a, b) => b.date.compareTo(a.date));
    }
    return _sameIndex = index;
  }

  Txn? txnById(String id) {
    for (final t in _txns) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Every transaction sharing [key], optionally within [from]..[to]
  /// (inclusive). Newest-first. A transfer is a single row, so it appears — and
  /// is counted — exactly once.
  List<Txn> sameTransactions(SameKey key, {DateTime? from, DateTime? to}) {
    final bucket = _sameKeyIndex[key] ?? const <Txn>[];
    if (from == null && to == null) return List<Txn>.of(bucket);
    return bucket.where((t) {
      if (from != null && t.date.isBefore(from)) return false;
      if (to != null && t.date.isAfter(to)) return false;
      return true;
    }).toList(growable: false);
  }

  /// The count under [key] for each preset range, from a single bucket read —
  /// so the range sheet can show all seven counts without seven queries.
  Map<SameRangePreset, int> sameRangeCounts(SameKey key) {
    final bucket = _sameKeyIndex[key] ?? const <Txn>[];
    final counts = <SameRangePreset, int>{};
    for (final preset in SameRangePreset.values) {
      final range = preset.resolve(today);
      counts[preset] = bucket
          .where((t) => !t.date.isBefore(range.start) && !t.date.isAfter(range.end))
          .length;
    }
    return counts;
  }

  /// Count under [key] within an arbitrary window — drives the live count on
  /// the custom-range picker's Apply button.
  int sameCountBetween(SameKey key, DateTime from, DateTime to) {
    final bucket = _sameKeyIndex[key] ?? const <Txn>[];
    return bucket
        .where((t) => !t.date.isBefore(from) && !t.date.isAfter(to))
        .length;
  }

  /// The date range the Same-transactions screens share — one preference, not
  /// per key (spec §4). Persisted, restored before first paint.
  SameRangeChoice _sameListRange =
      const SameRangeChoice.preset(SameRangePreset.defaultPreset);
  SameRangeChoice get sameListRange => _sameListRange;

  void setSameListRange(SameRangeChoice choice) {
    _sameListRange = choice;
    notifyListeners();
    unawaited(choice.save());
  }

  Future<void> loadSameListRange() async {
    _sameListRange = await SameRangeChoice.load();
    notifyListeners();
  }

  // ── Scoped-ledger period unit (per screen type) ───────────────────────────
  // Only the *unit* persists; the cursor always resets to the period containing
  // today on launch (spec §5). Kept separately for account vs category screens.

  PeriodUnit _accountPeriodUnit = PeriodUnit.month;
  PeriodUnit get accountPeriodUnit => _accountPeriodUnit;

  PeriodUnit _categoryPeriodUnit = PeriodUnit.month;
  PeriodUnit get categoryPeriodUnit => _categoryPeriodUnit;

  void setAccountPeriodUnit(PeriodUnit unit) {
    _accountPeriodUnit = unit;
    unawaited(savePeriodUnit('account_period_unit', unit));
  }

  void setCategoryPeriodUnit(PeriodUnit unit) {
    _categoryPeriodUnit = unit;
    unawaited(savePeriodUnit('category_period_unit', unit));
  }

  Future<void> loadPeriodUnits() async {
    _accountPeriodUnit = await loadPeriodUnit('account_period_unit');
    _categoryPeriodUnit = await loadPeriodUnit('category_period_unit');
  }

  // ── Per-account transaction index ─────────────────────────────────────────
  // A transaction is bucketed under every account it touches (its account-side
  // ref(s)). The scoped ledger queries by account + date range through this,
  // instead of scanning the whole txn list. Invalidated by every txn mutation,
  // alongside the same-key index.

  Map<String, List<Txn>>? _accountIndex;

  Map<String, List<Txn>> get _accountBuckets {
    final cached = _accountIndex;
    if (cached != null) return cached;
    final index = <String, List<Txn>>{};
    for (final t in _txns) {
      // A txn touches at most two account-side refs; categories are skipped.
      for (final ref in {t.fromRef, t.toRef}) {
        if (accountById(ref) != null) {
          (index[ref] ??= <Txn>[]).add(t);
        }
      }
    }
    return _accountIndex = index;
  }

  /// Every transaction touching any account in [accountIds], each once — the
  /// candidate set the ledger query filters by date. Index-backed: no full scan.
  List<Txn> txnsForAccounts(Set<String> accountIds) {
    final seen = <String>{};
    final out = <Txn>[];
    for (final id in accountIds) {
      for (final t in _accountBuckets[id] ?? const <Txn>[]) {
        if (seen.add(t.id)) out.add(t);
      }
    }
    return out;
  }

  ComparePeriod _comparePeriod = ComparePeriod.today;
  ComparePeriod get comparePeriod => _comparePeriod;
  set comparePeriod(ComparePeriod p) {
    _comparePeriod = p;
    notifyListeners();
  }

  /// Month currently in focus for Ledger + Planner headers.
  DateTime _period = DateTime(2026, 8);
  DateTime get period => _period;
  void shiftPeriod(int months) {
    _period = DateTime(_period.year, _period.month + months);
    notifyListeners();
  }

  set period(DateTime p) {
    _period = DateTime(p.year, p.month);
    notifyListeners();
  }

  // ── Collections ───────────────────────────────────────────────────────────
  List<Account> get accounts => _accounts
      .where((a) => !a.archived && !_openedAfterCutoff(a))
      .toList(growable: false);

  /// An account that did not exist yet on the reporting date must not appear.
  bool _openedAfterCutoff(Account a) =>
      a.openedOn != null && a.openedOn!.isAfter(_cutoff);

  /// Hidden accounts stay in the totals but leave the lists (spec 1.5).
  List<Account> get visibleAccounts =>
      accounts.where((a) => !a.hidden).toList(growable: false);

  List<Category> get categories =>
      _categories.where((c) => !c.archived).toList(growable: false);

  List<Category> categoriesOfType(CategoryType type) =>
      categories.where((c) => c.type == type).toList(growable: false);

  /// Categories with a limit set — Planner > Budgets reads exactly this
  /// (spec 5.1: budgets are fields on Category, not a separate entity).
  List<Category> get budgetedCategories => categories
      .where((c) => c.monthlyBudget != null)
      .toList(growable: false);

  List<Txn> get txns {
    final list = List<Txn>.from(_txns);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<Goal> get goals =>
      _goals.where((g) => g.status == GoalStatus.active).toList(growable: false);

  List<Goal> get archivedGoals => _goals
      .where((g) => g.status != GoalStatus.active)
      .toList(growable: false);

  List<Task> get tasks =>
      _tasks.where((t) => t.status != TaskStatus.paid).toList(growable: false);

  List<Category> get removedBudgets => _categories
      .where((c) => c.removedOn != null && c.monthlyBudget == null)
      .toList(growable: false);

  int get archivedCount => archivedGoals.length + removedBudgets.length;

  // ── Lookups ───────────────────────────────────────────────────────────────
  Account? accountById(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Category? categoryById(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Goal? goalById(String? id) {
    if (id == null) return null;
    for (final g in _goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  Task? taskById(String? id) {
    if (id == null) return null;
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Display name for a polymorphic from/to reference (spec 6.1).
  String refName(String ref) =>
      accountById(ref)?.name ?? categoryById(ref)?.name ?? '—';

  IconData refIcon(String ref) =>
      accountById(ref)?.displayIcon ?? categoryById(ref)?.icon ?? Icons.circle;

  Color refColor(String ref) =>
      accountById(ref)?.color ?? categoryById(ref)?.color ?? Colors.grey;

  // ── Derived balances ──────────────────────────────────────────────────────

  /// Live balance = starting balance + every transaction that touches it.
  /// Liability accounts carry negative balances throughout.
  double balanceOf(String accountId) {
    final account = accountById(accountId);
    if (account == null) return 0;
    var balance = account.startingBalance;
    final cutoff = _cutoff;
    for (final t in _txns) {
      if (t.date.isAfter(cutoff)) continue;
      balance += _effectOn(t, accountId);
    }
    return balance;
  }

  /// Signed effect of [t] on [accountId] — the one place the ledger rules live.
  double _effectOn(Txn t, String accountId) {
    switch (t.type) {
      case TxnType.expense:
        return t.fromRef == accountId ? -t.amount : 0;
      case TxnType.income:
        return t.toRef == accountId ? t.amount : 0;
      case TxnType.transfer:
        if (t.fromRef == accountId) {
          // Spec 3.4 — the fee is deducted from the source on top of the amount.
          return -(t.amount + (t.feeFromSource ? (t.fee ?? 0) : 0));
        }
        if (t.toRef == accountId) {
          final received = t.toAmount ?? t.amount;
          return received - (t.feeFromSource ? 0 : (t.fee ?? 0));
        }
        return 0;
      case TxnType.rebalance:
        // Spec 3.5 — amount holds the delta; it moves net worth, not cash.
        return t.toRef == accountId ? t.amount : 0;
    }
  }

  /// Balance as it stood immediately after [t] — the running figure under each
  /// amount in the Account Detail list.
  double runningBalanceAt(String accountId, Txn t) {
    final account = accountById(accountId);
    if (account == null) return 0;
    var balance = account.startingBalance;
    for (final other in _txns) {
      final isEarlier = other.date.isBefore(t.date) ||
          (other.date == t.date && other.id.compareTo(t.id) <= 0);
      if (isEarlier) balance += _effectOn(other, accountId);
    }
    return balance;
  }

  /// Balance converted to the base currency — the only form safe to add up
  /// across accounts (spec 3.4 FX rule).
  double balanceInBase(String accountId) => Fx.toBase(
        balanceOf(accountId),
        accountById(accountId)?.currency ?? Fx.baseCurrency,
      );

  double groupTotal(AccountGroup group) => accounts
      .where((a) => a.group == group)
      .fold(0.0, (sum, a) => sum + balanceInBase(a.id));

  int groupCount(AccountGroup group) =>
      accounts.where((a) => a.group == group).length;

  List<Account> accountsIn(AccountGroup group) =>
      visibleAccounts.where((a) => a.group == group).toList(growable: false);

  double get totalAssets => AccountGroup.assets
      .fold(0.0, (sum, g) => sum + groupTotal(g));

  /// Positive magnitude of what is owed.
  double get totalLiabilities => AccountGroup.liabilities
      .fold(0.0, (sum, g) => sum + groupTotal(g))
      .abs();

  double get netWorth => totalAssets - totalLiabilities;

  /// Spendable cash — the green highlight card on Balance (spec 1.1).
  double get spendable => accounts
      .where((a) => a.group == AccountGroup.spendable && a.countAsSpendable)
      .fold(0.0, (sum, a) => sum + balanceInBase(a.id));

  /// Liabilities as a share of assets — drives the red segment of the bar.
  double get liabilityRatio =>
      totalAssets <= 0 ? 0 : (totalLiabilities / totalAssets).clamp(0.0, 1.0);

  /// Share of total assets held by [group] — the "6.7%" under each row.
  double groupShare(AccountGroup group) {
    final base = group.isAsset ? totalAssets : totalLiabilities;
    if (base <= 0) return 0;
    return (groupTotal(group).abs() / base).clamp(0.0, 1.0);
  }

  /// How much money moved through a group over the comparison window — the
  /// "most active" sort on Balance orders by this.
  double groupActivity(AccountGroup group) {
    final since = _compareSince();
    var activity = 0.0;
    for (final t in _txns) {
      if (t.date.isBefore(since)) continue;
      for (final a in accounts) {
        if (a.group != group) continue;
        activity += Fx.toBase(_effectOn(t, a.id), a.currency).abs();
      }
    }
    return activity;
  }

  /// The account-level analogue of [groupActivity] — how much money moved
  /// through a single account over the comparison window. Powers Balance's
  /// "Change — most active" sort, which orders accounts within a group
  /// rather than the groups themselves.
  double accountActivity(String accountId) {
    final account = accountById(accountId);
    if (account == null) return 0;
    final since = _compareSince();
    var activity = 0.0;
    for (final t in _txns) {
      if (t.date.isBefore(since)) continue;
      activity += Fx.toBase(_effectOn(t, accountId), account.currency).abs();
    }
    return activity;
  }

  DateTime _compareSince() => switch (_comparePeriod) {
        ComparePeriod.today => today.subtract(const Duration(days: 1)),
        ComparePeriod.week => today.subtract(const Duration(days: 7)),
        ComparePeriod.month => DateTime(today.year, today.month - 1, today.day),
      };

  /// Credit utilisation = current debt ÷ credit limit (spec 1.3).
  double? utilisationOf(String accountId) {
    final account = accountById(accountId);
    final limit = account?.creditLimit;
    if (account == null || limit == null || limit <= 0) return null;
    return (balanceOf(accountId).abs() / limit).clamp(0.0, 1.0);
  }

  /// Net-worth change over the selected comparison window (spec 1.1).
  double get netWorthDelta {
    final since = _compareSince();
    var delta = 0.0;
    for (final t in _txns) {
      if (t.date.isBefore(since)) continue;
      for (final a in _accounts) {
        // An expense lowers an asset and raises a liability; both shrink net
        // worth, and the sign convention (liabilities negative) handles it.
        delta += Fx.toBase(_effectOn(t, a.id), a.currency);
      }
    }
    return delta;
  }

  double get netWorthDeltaFraction {
    final previous = netWorth - netWorthDelta;
    if (previous == 0) return 0;
    return netWorthDelta / previous.abs();
  }

  // ── Ledger ────────────────────────────────────────────────────────────────

  List<Txn> txnsForAccount(String accountId) => txns
      .where((t) =>
          t.fromRef == accountId ||
          t.toRef == accountId)
      .toList(growable: false);

  List<Txn> txnsInMonth(DateTime month) => txns
      .where((t) => t.date.year == month.year && t.date.month == month.month)
      .toList(growable: false);

  /// Money in for the month — rebalances excluded (spec 6.2 isolation rule).
  double monthIncome(DateTime month) => txnsInMonth(month)
      .where((t) => t.type == TxnType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double monthExpense(DateTime month) => txnsInMonth(month)
      .where((t) => t.type == TxnType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Left over = (In − Out) / In (spec 2.1).
  double monthLeftOverFraction(DateTime month) {
    final income = monthIncome(month);
    if (income <= 0) return 0;
    return (income - monthExpense(month)) / income;
  }

  // ── Budgets (spec 5.1) ────────────────────────────────────────────────────

  double spentInCategory(String categoryId, DateTime month) => txnsInMonth(month)
      .where((t) => t.type == TxnType.expense && t.toRef == categoryId)
      .fold(0.0, (sum, t) => sum + t.amount);

  double earnedInCategory(String categoryId, DateTime month) =>
      txnsInMonth(month)
          .where((t) => t.type == TxnType.income && t.fromRef == categoryId)
          .fold(0.0, (sum, t) => sum + t.amount);

  int txnCountForCategory(String categoryId) => _txns
      .where((t) => t.fromRef == categoryId || t.toRef == categoryId)
      .length;

  double get totalBudget => budgetedCategories
      .fold(0.0, (sum, c) => sum + (c.effectiveLimit ?? 0));

  double get totalSpentAgainstBudget => budgetedCategories
      .fold(0.0, (sum, c) => sum + spentInCategory(c.id, _period));

  double get leftToSpend => totalBudget - totalSpentAgainstBudget;

  /// Fraction of the month elapsed — the pace marker on the burn-rate bar.
  double get monthProgress {
    final days = DateTime(_period.year, _period.month + 1, 0).day;
    final isCurrentMonth =
        _period.year == today.year && _period.month == today.month;
    if (!isCurrentMonth) return _period.isBefore(today) ? 1.0 : 0.0;
    return (today.day / days).clamp(0.0, 1.0);
  }

  int get dayOfMonth =>
      (_period.year == today.year && _period.month == today.month)
          ? today.day
          : DateTime(_period.year, _period.month + 1, 0).day;

  int get daysInPeriod => DateTime(_period.year, _period.month + 1, 0).day;

  /// Spec 5.1 — (spent / days elapsed) × days in month − budget. Positive means
  /// the amber projection banner is shown.
  double get projectedOverspend {
    if (dayOfMonth <= 0) return 0;
    final projected = (totalSpentAgainstBudget / dayOfMonth) * daysInPeriod;
    return projected - totalBudget;
  }

  // ── Goals (spec 5.2) ──────────────────────────────────────────────────────

  List<Goal> goalsOfType(GoalType type) =>
      goals.where((g) => g.type == type).toList(growable: false);

  double get totalSaved => goals.fold(0.0, (sum, g) => sum + g.saved);
  double get totalGoalTarget =>
      goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  double get goalRemaining =>
      (totalGoalTarget - totalSaved).clamp(0, double.infinity);

  // ── Schedule (spec 5.3) ───────────────────────────────────────────────────

  List<Task> get openTasks {
    final list = tasks.where((t) => t.status == TaskStatus.open).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  List<Task> get overdueTasks =>
      openTasks.where((t) => t.daysUntilDue < 0).toList(growable: false);

  List<Task> get thisWeekTasks => openTasks
      .where((t) => t.daysUntilDue >= 0 && t.daysUntilDue <= 7)
      .toList(growable: false);

  List<Task> get laterTasks =>
      openTasks.where((t) => t.daysUntilDue > 7).toList(growable: false);

  double get comingIn => openTasks
      .where((t) => t.expectedAmount > 0)
      .fold(0.0, (sum, t) => sum + t.expectedAmount);

  double get goingOut => openTasks
      .where((t) => t.expectedAmount < 0)
      .fold(0.0, (sum, t) => sum + t.expectedAmount.abs());

  double get overdueAmount => overdueTasks
      .fold(0.0, (sum, t) => sum + t.expectedAmount.abs());

  // ── Mutations: transactions ───────────────────────────────────────────────

  Txn addTxn({
    required TxnType type,
    required double amount,
    required String currency,
    required String fromRef,
    required String toRef,
    required DateTime date,
    double? exchangeRate,
    double? toAmount,
    double? fee,
    bool feeFromSource = true,
    List<String> tags = const [],
    String note = '',
    String? goalId,
  }) {
    final txn = Txn(
      id: _nextId('t'),
      type: type,
      amount: amount,
      currency: currency,
      fromRef: fromRef,
      toRef: toRef,
      date: date,
      exchangeRate: exchangeRate,
      toAmount: toAmount,
      fee: fee,
      feeFromSource: feeFromSource,
      tags: tags,
      note: note,
      goalId: goalId,
    );
    _txns.add(txn);
    _sameIndex = null;
    _accountIndex = null;
    notifyListeners();
    return txn;
  }

  /// Spec 2.3 — saving an edit re-applies the delta and bumps the audit trail.
  /// Because balances are derived, mutating in place is enough.
  void updateTxn(
    Txn txn, {
    double? amount,
    String? fromRef,
    String? toRef,
    DateTime? date,
    List<String>? tags,
    String? note,
    double? fee,
    double? toAmount,
    double? exchangeRate,
  }) {
    txn
      ..amount = amount ?? txn.amount
      ..fromRef = fromRef ?? txn.fromRef
      ..toRef = toRef ?? txn.toRef
      ..date = date ?? txn.date
      ..tags = tags ?? txn.tags
      ..note = note ?? txn.note
      ..fee = fee ?? txn.fee
      ..toAmount = toAmount ?? txn.toAmount
      ..exchangeRate = exchangeRate ?? txn.exchangeRate
      ..editedCount += 1;
    // An edit can change fromRef/toRef/date, so the same-key index is stale.
    _sameIndex = null;
    _accountIndex = null;
    notifyListeners();
  }

  void deleteTxn(Txn txn) {
    _txns.removeWhere((t) => t.id == txn.id);
    _sameIndex = null;
    _accountIndex = null;
    notifyListeners();
  }

  /// Balance an account would return to if [txn] were deleted — the concrete
  /// figure the Destructive Confirmation shows (spec 2.4).
  double balanceWithout(String accountId, Txn txn) =>
      balanceOf(accountId) - _effectOn(txn, accountId);

  double categorySpendWithout(String categoryId, Txn txn) {
    final current = spentInCategory(categoryId, DateTime(txn.date.year, txn.date.month));
    if (txn.type == TxnType.expense && txn.toRef == categoryId) {
      return current - txn.amount;
    }
    return current;
  }

  // ── Mutations: accounts ───────────────────────────────────────────────────

  Account addAccount({
    required String name,
    required AccountGroup group,
    required String currency,
    required double startingBalance,
    double? creditLimit,
    bool countAsSpendable = true,
    IconData? icon,
  }) {
    // Liabilities are held as negative balances throughout the app.
    final signed = group.isLiability
        ? -startingBalance.abs()
        : startingBalance;
    final account = Account(
      id: _nextId('a'),
      name: name,
      group: group,
      currency: currency,
      startingBalance: signed,
      creditLimit: creditLimit,
      countAsSpendable: countAsSpendable,
      icon: icon,
      openedOn: today,
    );
    _accounts.add(account);
    notifyListeners();
    return account;
  }

  void updateAccount(
    Account account, {
    String? name,
    AccountGroup? group,
    String? currency,
    double? creditLimit,
    int? statementDay,
    int? paymentDue,
    bool? hidden,
  }) {
    account
      ..name = name ?? account.name
      ..group = group ?? account.group
      ..currency = currency ?? account.currency
      ..creditLimit = creditLimit ?? account.creditLimit
      ..statementDay = statementDay ?? account.statementDay
      ..paymentDue = paymentDue ?? account.paymentDue
      ..hidden = hidden ?? account.hidden;
    notifyListeners();
  }

  /// Spec 6.2 — anything with history is archived, never truly removed.
  void removeAccount(Account account) {
    if (txnsForAccount(account.id).isEmpty) {
      _accounts.removeWhere((a) => a.id == account.id);
    } else {
      account.archived = true;
    }
    notifyListeners();
  }

  // ── Mutations: categories & budgets ───────────────────────────────────────

  Category addCategory({
    required String name,
    required CategoryType type,
    required IconData icon,
    required Color color,
    double? monthlyBudget,
  }) {
    final category = Category(
      id: _nextId('c'),
      name: name,
      type: type,
      icon: icon,
      color: color,
      monthlyBudget: monthlyBudget,
    );
    _categories.add(category);
    notifyListeners();
    return category;
  }

  void updateBudget(
    Category category, {
    double? monthlyBudget,
    bool? rollover,
    double? warnThreshold,
  }) {
    category
      ..monthlyBudget = monthlyBudget ?? category.monthlyBudget
      ..budgetRollover = rollover ?? category.budgetRollover
      ..warnThreshold = warnThreshold ?? category.warnThreshold;
    notifyListeners();
  }

  /// Spec 5.5 — removing a budget is `Category.monthly_budget = null`. The
  /// category and its transactions are deliberately untouched.
  void removeBudget(Category category) {
    category
      ..monthlyBudget = null
      ..removedOn = today;
    notifyListeners();
  }

  void restoreBudget(Category category, double limit) {
    category
      ..monthlyBudget = limit
      ..removedOn = null;
    notifyListeners();
  }

  // ── Mutations: goals ──────────────────────────────────────────────────────

  Goal addGoal({
    required String name,
    required GoalType type,
    required double targetAmount,
    required String linkedAccountId,
    required IconData icon,
    DateTime? targetDate,
    double initialDeposit = 0,
    String? depositFromAccountId,
    String note = '',
  }) {
    final goal = Goal(
      id: _nextId('g'),
      name: name,
      type: type,
      targetAmount: targetAmount,
      linkedAccountId: linkedAccountId,
      icon: icon,
      targetDate: targetDate,
      saved: initialDeposit,
      note: note,
      createdAt: today,
    );
    _goals.add(goal);
    // Spec 3.6 — the initial deposit physically moves money into the goal's
    // account, so it is a real Transfer, not a bookkeeping-only number.
    if (initialDeposit > 0 && depositFromAccountId != null) {
      addTxn(
        type: TxnType.transfer,
        amount: initialDeposit,
        currency: accountById(depositFromAccountId)?.currency ?? 'USD',
        fromRef: depositFromAccountId,
        toRef: linkedAccountId,
        date: today,
        note: 'Initial deposit · $name',
        goalId: goal.id,
      );
    }
    notifyListeners();
    return goal;
  }

  void updateGoal(
    Goal goal, {
    String? name,
    GoalType? type,
    double? targetAmount,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? linkedAccountId,
    bool? autoContribute,
    double? autoContributeAmount,
    int? autoContributeDay,
  }) {
    goal
      ..name = name ?? goal.name
      ..type = type ?? goal.type
      ..targetAmount = targetAmount ?? goal.targetAmount
      ..targetDate = clearTargetDate ? null : (targetDate ?? goal.targetDate)
      ..linkedAccountId = linkedAccountId ?? goal.linkedAccountId
      ..autoContribute = autoContribute ?? goal.autoContribute
      ..autoContributeAmount =
          autoContributeAmount ?? goal.autoContributeAmount
      ..autoContributeDay = autoContributeDay ?? goal.autoContributeDay;
    notifyListeners();
  }

  /// Spec 5.6 — three distinct exits, because the fate of the saved money and
  /// the goal-success metric differ in each case.
  void markGoalReached(Goal goal) {
    goal
      ..status = GoalStatus.reached
      ..completedAt = today;
    _cancelAutoContribute(goal);
    notifyListeners();
  }

  void abandonGoal(Goal goal) {
    goal
      ..status = GoalStatus.abandoned
      ..stoppedAt = today;
    _cancelAutoContribute(goal);
    notifyListeners();
  }

  void deleteGoal(Goal goal) {
    _cancelAutoContribute(goal);
    _goals.removeWhere((g) => g.id == goal.id);
    notifyListeners();
  }

  void restoreGoal(Goal goal) {
    goal
      ..status = GoalStatus.active
      ..stoppedAt = null
      ..completedAt = null;
    notifyListeners();
  }

  /// Spec 5.6 — never leave an orphaned recurring Transfer behind.
  void _cancelAutoContribute(Goal goal) {
    goal.autoContribute = false;
    _tasks.removeWhere((t) => t.id == 'auto-${goal.id}');
  }

  void clearArchive() {
    _goals.removeWhere((g) => g.status != GoalStatus.active);
    for (final c in _categories) {
      c.removedOn = null;
    }
    notifyListeners();
  }

  // ── Mutations: tasks ──────────────────────────────────────────────────────

  Task addTask({
    required String title,
    required String linkedAccountId,
    required double expectedAmount,
    required DateTime dueDate,
    required IconData icon,
    String? categoryId,
    RepeatFrequency repeats = RepeatFrequency.none,
    Priority priority = Priority.normal,
    int? reminderDaysBefore,
    TimeOfDay? reminderTime,
  }) {
    final task = Task(
      id: _nextId('k'),
      title: title,
      linkedAccountId: linkedAccountId,
      expectedAmount: expectedAmount,
      dueDate: dueDate,
      icon: icon,
      categoryId: categoryId,
      repeats: repeats,
      priority: priority,
      reminderDaysBefore: reminderDaysBefore,
      reminderTime: reminderTime,
    );
    _tasks.add(task);
    notifyListeners();
    return task;
  }

  void updateTask(
    Task task, {
    String? title,
    String? linkedAccountId,
    double? expectedAmount,
    DateTime? dueDate,
    String? categoryId,
    RepeatFrequency? repeats,
    Priority? priority,
    int? reminderDaysBefore,
    TimeOfDay? reminderTime,
    bool clearReminder = false,
  }) {
    task
      ..title = title ?? task.title
      ..categoryId = categoryId ?? task.categoryId
      ..linkedAccountId = linkedAccountId ?? task.linkedAccountId
      ..expectedAmount = expectedAmount ?? task.expectedAmount
      ..dueDate = dueDate ?? task.dueDate
      ..repeats = repeats ?? task.repeats
      ..priority = priority ?? task.priority
      ..reminderDaysBefore =
          clearReminder ? null : (reminderDaysBefore ?? task.reminderDaysBefore)
      ..reminderTime = clearReminder ? null : (reminderTime ?? task.reminderTime);
    notifyListeners();
  }

  /// Spec 5.3/5.7 — writes the real Ledger entry, then advances the series.
  /// A one-off task closes; a recurring one just moves to its next date.
  Txn markTaskPaid(Task task) {
    final account = accountById(task.linkedAccountId);
    final isPayOut = task.expectedAmount < 0;
    final txn = addTxn(
      type: isPayOut ? TxnType.expense : TxnType.income,
      amount: task.expectedAmount.abs(),
      currency: account?.currency ?? 'USD',
      fromRef: isPayOut
          ? task.linkedAccountId
          : (task.categoryId ?? _uncategorisedId(CategoryType.income)),
      toRef: isPayOut
          ? (task.categoryId ?? _uncategorisedId(CategoryType.expense))
          : task.linkedAccountId,
      date: task.dueDate,
      note: task.title,
    );
    _advance(task);
    notifyListeners();
    return txn;
  }

  /// Spec 5.7 — skip writes no transaction but still advances the series.
  void skipTask(Task task) {
    if (task.isRecurring) {
      task.skippedDates = [...task.skippedDates, task.dueDate];
      _advance(task);
    } else {
      task.status = TaskStatus.skipped;
    }
    notifyListeners();
  }

  void _advance(Task task) {
    if (task.isRecurring) {
      task.dueDate = task.nextOccurrence(task.dueDate);
    } else {
      task.status = TaskStatus.paid;
    }
  }

  /// Spec 5.7 — "Delete only `<date>`" appends to skipped_dates, it never spawns
  /// or destroys rows; "Delete the whole series" removes the single record.
  void deleteTaskOccurrence(Task task) {
    if (task.isRecurring) {
      task.skippedDates = [...task.skippedDates, task.dueDate];
      task.dueDate = task.nextOccurrence(task.dueDate);
    } else {
      _tasks.removeWhere((t) => t.id == task.id);
    }
    notifyListeners();
  }

  void deleteTaskSeries(Task task) {
    _tasks.removeWhere((t) => t.id == task.id);
    notifyListeners();
  }

  /// Last-resort bucket so a task without a category never pollutes a real
  /// budget. Created on demand rather than seeded, so it only exists if used.
  String _uncategorisedId(CategoryType type) {
    final existing = _categories.where(
      (c) => c.type == type && c.name == 'Uncategorised',
    );
    if (existing.isNotEmpty) return existing.first.id;
    return addCategory(
      name: 'Uncategorised',
      type: type,
      icon: Icons.help_outline_rounded,
      color: const Color(0xFF8E8E93),
    ).id;
  }
}

/// Dependency injection without a package — [AppStore] rebuilds its dependents
/// through [InheritedNotifier].
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope found in context');
    return scope!.notifier!;
  }

  /// Read without subscribing — for callbacks that only mutate.
  static AppStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope found in context');
    return scope!.notifier!;
  }
}
