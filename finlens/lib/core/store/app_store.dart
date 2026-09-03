import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/balance/balance_filter.dart';
import '../../features/balance/balance_order.dart';
import '../../features/balance/same_transactions.dart';
import '../../features/ledger/trans_filter.dart';
import '../utils/date_range.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
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
    List<Tag> tags = const [],
    List<CurrencyDef> customCurrencies = const [],
    DateTime? budgetHistorySince,
    int? idSeq,
    int? tagSchema,
  })  : _accounts = List.of(accounts),
        _categories = List.of(categories),
        _txns = List.of(txns),
        _goals = List.of(goals),
        _tasks = List.of(tasks),
        _tags = List.of(tags),
        _customCurrencies = List.of(customCurrencies),
        // Budget-detail CHANGES records forward-only: the day this store first
        // ran with the feature. A persistence layer would pass its stored value
        // so the footnote never moves; absent one (this app resets every launch),
        // it resolves to `today` for both a migrated and a fresh store. Never
        // AppStore.today at render, which would drift daily. Existing budgets are
        // NOT backfilled — history begins empty and fills from the first edit.
        budgetHistorySince = budgetHistorySince ?? today {
    // Persistence seam: restore the id counter (so hydrated ids never collide
    // with freshly minted ones) and the tag schema (so already-reified tag ids
    // are never re-migrated). Both no-op on the seed path where they are null.
    if (idSeq != null) _idSeq = idSeq;
    if (tagSchema != null) _tagSchema = tagSchema;
    // On load: reify tags (turn the fixture's legacy name-lists into Tag
    // entities and rewrite each txn's tagIds — §1 migration), drop goals whose
    // source no longer resolves to anything (§9), seed a `created` history entry
    // for any goal that lacks one (so CHANGES is never empty — §7), then latch
    // any goal already sitting at or past its target.
    _migrateTags();
    _pruneOrphanGoals();
    _seedGoalHistory();
    _syncGoalLatches();
    // Make any restored custom currencies formattable app-wide immediately.
    setCustomCurrencies(_customCurrencies);
  }

  /// An empty store — the first-run state before anything has been persisted.
  /// `main()` uses this when the local database is still empty (spec: fresh
  /// installs start blank, not seeded with demo data).
  factory AppStore.empty() => AppStore(
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  /// Current on-load tag schema. Bumping this re-runs [_migrateTags].
  static const int tagSchemaVersion = 1;
  int _tagSchema = 0;

  /// One-pass migration from the legacy model (`Txn.tags` held literal names)
  /// to the entity model (`Txn.tagIds` holds [Tag.id]). Guarded by
  /// [_tagSchema]: it runs only when the store is still at schema 0 **and** no
  /// tags have been reified yet, so it can never run twice (a store built with a
  /// non-empty [_tags] — e.g. via [loadFrom] copying an already-migrated source —
  /// is left untouched).
  ///
  /// For each distinct folded name found across every transaction it mints one
  /// [Tag], with `createdAt`/`lastUsedAt` taken from the oldest/newest
  /// transaction carrying it, and rewrites that transaction's list to the
  /// matching ids (deduplicated). Case-folded duplicates (`#Fun` / `#fun`)
  /// collapse into a single tag here.
  void _migrateTags() {
    if (_tagSchema >= tagSchemaVersion) return;
    if (_tags.isEmpty) {
      final byFold = <String, Tag>{};
      var merged = 0;
      for (final t in _txns) {
        for (final raw in t.tagIds) {
          final name = _legacyName(raw);
          if (name == null) continue;
          final fold = foldTag(name);
          final existing = byFold[fold];
          if (existing == null) {
            byFold[fold] = Tag(
              id: _nextId('tg'),
              name: name,
              createdAt: t.date,
              lastUsedAt: t.date,
            );
          } else {
            merged++;
            if (t.date.isBefore(existing.createdAt)) existing.createdAt = t.date;
            if (t.date.isAfter(existing.lastUsedAt)) existing.lastUsedAt = t.date;
          }
        }
      }
      _tags
        ..clear()
        ..addAll(byFold.values);
      // Rewrite each txn's list to ids, deduplicated and order-preserving.
      for (final t in _txns) {
        final seen = <String>{};
        final ids = <String>[];
        for (final raw in t.tagIds) {
          final name = _legacyName(raw);
          if (name == null) continue;
          final tag = byFold[foldTag(name)];
          if (tag != null && seen.add(tag.id)) ids.add(tag.id);
        }
        t.tagIds = ids;
      }
      // `merged` counts every folded-duplicate occurrence collapsed away; it is
      // surfaced through [tagMigrationMergedCount] for the deliverable's report.
      _tagMigrationMerged = merged;
    }
    _tagSchema = tagSchemaVersion;
  }

  /// Normalise a legacy tag string for migration: trim, strip a single leading
  /// `#`, trim again. Returns null for an empty result so blank tags vanish.
  /// Folding happens on this stripped form, so `#fun` and `fun` are one tag.
  static String? _legacyName(String raw) {
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    s = s.trim();
    return s.isEmpty ? null : s;
  }

  int _tagMigrationMerged = 0;

  /// How many case-folded duplicate tag *occurrences* the load migration
  /// collapsed (0 when the store was built already-migrated). Diagnostic only.
  int get tagMigrationMergedCount => _tagMigrationMerged;

  void _seedGoalHistory() {
    for (final g in _goals) {
      if (g.history.isNotEmpty) continue;
      g.history.add(GoalEdit(
        at: g.createdAt,
        field: 'created',
        from: '',
        to: g.targetDate == null
            ? money(g.targetAmount)
            : '${money(g.targetAmount)} · ${_histDate(g.targetDate)}',
      ));
    }
  }

  // Copied on the way in so the seed lists can be const-ish literals and no
  // caller can mutate the store's collections behind its back.
  final List<Account> _accounts;
  final List<Category> _categories;
  final List<Txn> _txns;
  final List<Goal> _goals;
  final List<Task> _tasks;
  final List<Tag> _tags;

  /// User-defined currencies (spec §7a). Display metadata only — no rate is
  /// stored or applied (§10). Registered into the module-global currency catalog
  /// on construction and on every mutation so the dependency-free [money]
  /// formatter can render them anywhere without reaching the store.
  final List<CurrencyDef> _customCurrencies;

  /// Remembers a task's status just before it was archived (deleted), so Archive
  /// > Undo can restore `open` or `paused` (§9). In-memory only — like every
  /// other piece of view/undo state, it does not survive a relaunch.
  final Map<String, TaskStatus> _taskPriorStatus = {};

  int _idSeq = 1000;
  String _nextId(String prefix) => '$prefix${_idSeq++}';

  // ── Persistence seam ──────────────────────────────────────────────────────
  // Raw, unfiltered views of the canonical collections for the snapshot writer.
  // The public getters (`accounts`, `categories`, `goals`, `tasks`, …) are all
  // filtered — archived/status-scoped — so a backup that used them would silently
  // drop rows. A round-trippable snapshot reads the private lists directly.
  List<Account> get snapshotAccounts => List.unmodifiable(_accounts);
  List<Category> get snapshotCategories => List.unmodifiable(_categories);
  List<Txn> get snapshotTxns => List.unmodifiable(_txns);
  List<Goal> get snapshotGoals => List.unmodifiable(_goals);
  List<Task> get snapshotTasks => List.unmodifiable(_tasks);
  List<Tag> get snapshotTags => List.unmodifiable(_tags);
  List<CurrencyDef> get snapshotCustomCurrencies =>
      List.unmodifiable(_customCurrencies);

  /// The id counter to persist and restore across launches (see the constructor).
  int get idSeq => _idSeq;

  /// The tag-migration schema to persist, so a reload does not re-run
  /// [_migrateTags] over already-reified tag ids.
  int get tagSchema => _tagSchema;

  // ── Reference date ────────────────────────────────────────────────────────
  // The seed data is authored around the mockups' "August 2026". Pinning
  // "today" keeps the documented screens reproducible instead of drifting.
  static final DateTime today = DateTime(2026, 8, 9, 14, 32);

  /// The day this store first ran with budget-detail CHANGES (see constructor).
  /// Displayed in the section's footnote; fixed for the store's lifetime.
  final DateTime budgetHistorySince;

  // ── Privacy mode (spec 1.1 — eye icon masks every amount) ─────────────────
  bool _masked = false;
  bool get masked => _masked;
  void toggleMasked() {
    _masked = !_masked;
    notifyListeners();
  }

  // ── Language (spec: multilingual UI) ──────────────────────────────────────
  // The stored language, never null (§7.1). The picker offers only real
  // languages — there is no "system default" row, because there is no live
  // system link left to represent once a value is stored. Only the language
  // code is persisted ('en'/'ru'/'tr'/'tk'). Unlike the presentational toggles
  // above, [setLocale] DOES notify: every visible string changes, so the whole
  // app must rebuild.
  static const _localeKey = 'app_locale';

  /// The languages FinLens ships. Doubles as the seeding oracle in
  /// [resolveInitialLocale] and mirrors `AppLocalizations.supportedLocales`.
  static const _supportedLanguageCodes = {'en', 'ru', 'tr', 'tk'};

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  void setLocale(Locale value) {
    _locale = value;
    notifyListeners();
    unawaited(_saveString(_localeKey, value.languageCode));
  }

  /// Language is a stored value, not a live mirror of the device. On the very
  /// first launch — nothing persisted yet — the device's language seeds it when
  /// FinLens speaks it, and English does otherwise. From then on the stored
  /// value wins, which is why the picker has no "system default" row: there is
  /// no live system link left to offer.
  ///
  /// Pure and parameterised so the seeding rule is unit-testable without a real
  /// platform or SharedPreferences (§9 locale-seeding test).
  static Locale resolveInitialLocale(String? stored, List<Locale> deviceLocales) {
    if (stored != null && stored.isNotEmpty) return Locale(stored);
    for (final device in deviceLocales) {
      if (_supportedLanguageCodes.contains(device.languageCode)) {
        return Locale(device.languageCode);
      }
    }
    return const Locale('en');
  }

  /// Restores the language preference before the first frame (called from
  /// `main`), so the app never paints in the wrong language and then re-renders.
  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = resolveInitialLocale(
      prefs.getString(_localeKey),
      WidgetsBinding.instance.platformDispatcher.locales,
    );
  }

  // ── Ledger view preferences ───────────────────────────────────────────────
  // Whether the Ledger tab reveals each noted row's description line. Unlike the
  // filter/search lens, this is a lasting view preference: it persists and never
  // resets on a month change. The Ledger reaches it through a screen-owned
  // ValueNotifier (seeded from here at initState) and passes the flag to each
  // row, so a toggle rebuilds only the list — never the header zone — which is
  // why [setLedgerShowDescriptions] persists WITHOUT notifying: no store-derived
  // figure changes, only a presentational flag consumed as a widget parameter.
  static const _showDescriptionsKey = 'ledger_show_descriptions';
  bool _ledgerShowDescriptions = false;
  bool get ledgerShowDescriptions => _ledgerShowDescriptions;

  void setLedgerShowDescriptions(bool value) {
    _ledgerShowDescriptions = value;
    unawaited(_saveBool(_showDescriptionsKey, value));
  }

  // The scoped ledgers (group / account drill-downs) carry the same descriptions
  // toggle, but default the *other* way: their titles repeat (a category or the
  // scope's own name), so the description is the row's identity rather than
  // decoration. One shared preference — both scoped screen types want the same
  // default, so unlike the sort/period split there is nothing to gain from two.
  static const _scopedShowDescriptionsKey = 'scoped_show_descriptions';
  bool _scopedShowDescriptions = true;
  bool get scopedShowDescriptions => _scopedShowDescriptions;

  void setScopedShowDescriptions(bool value) {
    _scopedShowDescriptions = value;
    unawaited(_saveBool(_scopedShowDescriptionsKey, value));
  }

  static Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// Restores the descriptions toggles before the first frame (called from
  /// `main`), so neither list flashes the other state.
  Future<void> loadLedgerPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _ledgerShowDescriptions = prefs.getBool(_showDescriptionsKey) ?? false;
    _scopedShowDescriptions = prefs.getBool(_scopedShowDescriptionsKey) ?? true;
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

  /// Insight's own account filter (spec §9.1). Reuses the [BalanceFilter] value
  /// type but is a *second, independent* instance persisted under its own keys —
  /// deliberately not shared with Balance, so the two can disagree; that cost is
  /// accepted so hiding an account on one tab never silently reshapes the other.
  BalanceFilter _insightAccountFilter = const BalanceFilter();
  BalanceFilter get insightAccountFilter => _insightAccountFilter;

  void setInsightAccountFilter(BalanceFilter filter) {
    _insightAccountFilter = filter;
    notifyListeners();
    unawaited(filter.save(
      groupsKey: BalanceFilter.insightGroupsKey,
      accountsKey: BalanceFilter.insightAccountsKey,
    ));
  }

  Future<void> loadInsightAccountFilter() async {
    _insightAccountFilter = await BalanceFilter.load(
      this,
      groupsKey: BalanceFilter.insightGroupsKey,
      accountsKey: BalanceFilter.insightAccountsKey,
    );
    notifyListeners();
  }

  /// Insight's category filter (spec §2.4): the set of hidden expense/income
  /// category ids. Unlike the account filter it moves only the spending/income
  /// *lists* — a category is a label, not money, so hiding one cannot change net
  /// worth (spec §2.1). Persistent and shared with the see-all screen (spec §5);
  /// it never touches Balance.
  static const _insightCategoryFilterKey = 'insight_category_filter';
  Set<String> _insightCategoryFilter = <String>{};
  Set<String> get insightCategoryFilter => _insightCategoryFilter;

  void setInsightCategoryFilter(Set<String> hiddenIds) {
    _insightCategoryFilter = {...hiddenIds};
    notifyListeners();
    unawaited(_saveInsightCategoryFilter());
  }

  Future<void> _saveInsightCategoryFilter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _insightCategoryFilterKey, jsonEncode(_insightCategoryFilter.toList()));
  }

  Future<void> loadInsightCategoryFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_insightCategoryFilterKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        // Prune ids that no longer match a live category, mirroring the account
        // filter's stale-id pruning.
        _insightCategoryFilter = {
          for (final v in decoded)
            if (v is String && categoryById(v) != null) v
        };
        notifyListeners();
      }
    } on FormatException {
      // Corrupt preference: leave the filter empty.
    }
  }

  /// Which sort the Balance list is in, and the user's hand-made order. Held
  /// here (like [balanceFilter]) so both persist and can be restored before the
  /// first frame; the screen does the actual ordering through [CustomOrder]'s
  /// pure resolvers, so nothing outside Balance is affected.
  AccountSort _balanceSort = AccountSort.defaultSort;
  AccountSort get balanceSort => _balanceSort;

  CustomOrder _balanceOrder = const CustomOrder();
  CustomOrder get balanceOrder => _balanceOrder;

  /// True only when the list is genuinely not in its default order. Custom with
  /// nothing arranged yet renders identically to the default, so it must not
  /// claim to be active — an indicator that fires while nothing on screen has
  /// changed teaches the user to ignore it. Lives here beside [balanceSort] so
  /// the sort sheet and the toolbar indicator cannot drift apart.
  bool get sortIsActive =>
      _balanceSort != AccountSort.defaultSort &&
      (_balanceSort != AccountSort.custom || _balanceOrder.isConfigured);

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

  // ── Schedule completed-section range (Part B) ─────────────────────────────
  // The completed section ranges over the past with its own control, wholly
  // independent of the forward horizon (spec Part B §B2). Defaults to
  // `This month` — a preset that is in the shared sheet, so its checkmark is
  // right on first open. A preset persists as its preset and re-resolves against
  // today; a custom range persists its dates. Restored before first paint.
  static const _completedRangeKey = 'schedule_completed_range';
  DateRange _completedRange = RangePreset.thisMonth.resolve(today);
  DateRange get completedRange => _completedRange;

  void setCompletedRange(DateRange range) {
    _completedRange = range;
    notifyListeners();
    unawaited(saveScheduleCompletedRange(_completedRangeKey, range));
  }

  Future<void> loadCompletedRange() async {
    final loaded =
        await loadScheduleCompletedRange(_completedRangeKey, today);
    if (loaded != null) {
      _completedRange = loaded;
      notifyListeners();
    }
  }

  // ── Scoped-ledger period unit (per screen type) ───────────────────────────
  // Only the *unit* persists; the cursor always resets to the period containing
  // today on launch (spec §5). Kept separately for account vs category screens.

  PeriodUnit _accountPeriodUnit = PeriodUnit.month;
  PeriodUnit get accountPeriodUnit => _accountPeriodUnit;

  PeriodUnit _categoryPeriodUnit = PeriodUnit.month;
  PeriodUnit get categoryPeriodUnit => _categoryPeriodUnit;

  // Insight's own period unit (spec §2.5). Only the unit persists; the cursor
  // resets to the period containing today on launch, and a custom range is never
  // persisted — it is a question, not a setting. Held here beside the scoped
  // units so the same save/load path serves it; Insight owns its live cursor.
  PeriodUnit _insightPeriodUnit = PeriodUnit.month;
  PeriodUnit get insightPeriodUnit => _insightPeriodUnit;

  void setAccountPeriodUnit(PeriodUnit unit) {
    _accountPeriodUnit = unit;
    unawaited(savePeriodUnit('account_period_unit', unit));
  }

  void setCategoryPeriodUnit(PeriodUnit unit) {
    _categoryPeriodUnit = unit;
    unawaited(savePeriodUnit('category_period_unit', unit));
  }

  void setInsightPeriodUnit(PeriodUnit unit) {
    _insightPeriodUnit = unit;
    unawaited(savePeriodUnit('insight_period_unit', unit));
  }

  /// Insight's live window (spec §6.1). Separate from [period] (Ledger +
  /// Planner) — writing this never moves theirs, which the isolation test pins.
  /// Not persisted; only `insight_period_unit` is, and the cursor resets to the
  /// period containing today on launch. The category detail's bar tap/swipe and
  /// the main screen's stepper both write here, so returning to the main screen
  /// shows the period the reader ended on.
  DateRange? _insightWindow;
  DateRange get insightWindow => _insightWindow ??=
      currentPresetFor(_insightPeriodUnit).resolve(AppStore.today);

  void setInsightWindow(DateRange window) {
    _insightWindow = window;
    notifyListeners();
  }

  Future<void> loadPeriodUnits() async {
    _accountPeriodUnit = await loadPeriodUnit('account_period_unit');
    _categoryPeriodUnit = await loadPeriodUnit('category_period_unit');
    _insightPeriodUnit = await loadPeriodUnit('insight_period_unit');
  }

  // ── Scoped-ledger sort (per screen type) & filter (per instance) ───────────
  // Sort persists per screen *type* — account screens share one preference, the
  // group/all bucket another — mirroring the period-unit split. The filter
  // persists per screen *instance*, keyed by a scope string the screen builds
  // (`account:{id}` / `group:{name}` / `all`). Both restore before first paint.

  TransSort _accountTransSort = TransSort.dateNewest;
  TransSort _categoryTransSort = TransSort.dateNewest;

  TransSort transSort({required bool account}) =>
      account ? _accountTransSort : _categoryTransSort;

  void setTransSort({required bool account, required TransSort sort}) {
    if (account) {
      _accountTransSort = sort;
    } else {
      _categoryTransSort = sort;
    }
    notifyListeners();
    unawaited(_saveTransSort(account ? 'account_trans_sort' : 'category_trans_sort', sort));
  }

  static Future<void> _saveTransSort(String key, TransSort sort) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, sort.name);
  }

  final Map<String, TransFilter> _transFilters = {};

  TransFilter transFilter(String scopeKey) =>
      _transFilters[scopeKey] ?? TransFilter.empty;

  void setTransFilter(String scopeKey, TransFilter filter) {
    if (filter.isActive) {
      _transFilters[scopeKey] = filter;
    } else {
      _transFilters.remove(scopeKey);
    }
    notifyListeners();
    unawaited(filter.save('trans_filter_$scopeKey'));
  }

  /// Every scope a filter can be stored under — 'all', each group, each account.
  List<String> _transScopeKeys() => [
        'all',
        for (final g in AccountGroup.values) 'group:${g.name}',
        for (final a in _accounts) 'account:${a.id}',
      ];

  Future<void> loadTransPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _accountTransSort = TransSort.byName2(prefs.getString('account_trans_sort'));
    _categoryTransSort =
        TransSort.byName2(prefs.getString('category_trans_sort'));

    // Prune targets: an id that no longer resolves to a live category/account
    // or tag is dropped on load (spec §5).
    final validGroups = <String>{
      for (final c in _categories) c.id,
      for (final a in _accounts) a.id,
    };
    // Filters persist tag IDS; a stored id that no longer resolves to a live tag
    // is pruned on load (spec §5). Archived tags stay valid — past transactions
    // still carry them and must remain filterable.
    final validTags = <String>{
      for (final t in _tags) t.id,
    };
    _transFilters.clear();
    for (final key in _transScopeKeys()) {
      final f =
          await TransFilter.load('trans_filter_$key', validGroups, validTags);
      if (f.isActive) _transFilters[key] = f;
    }
    notifyListeners();
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
    // Ledger range lens: a header swipe exits the lens onto the month it was set
    // from (`_period` is left untouched); the swipe direction is ignored. This
    // agrees with the header's × clear button, which also returns to `_period` —
    // two exits that both land in the same place. (An earlier design sent the
    // swipe to today's month, but a second exit with a different destination is
    // the kind of inconsistency a user notices without being able to name.)
    // Subsequent swipes (lens now null) step months normally. Only the Ledger
    // tab ever sets a lens, so Planner/Insight (lens always null) keep the old
    // path.
    if (_rangeLens != null) {
      _rangeLens = null;
      notifyListeners();
      return;
    }
    _period = DateTime(_period.year, _period.month + months);
    notifyListeners();
  }

  set period(DateTime p) {
    // Picking a month exits any active range lens through the same path, so the
    // Ledger's filter/search reset fires identically to a plain month change.
    _period = DateTime(p.year, p.month);
    _rangeLens = null;
    notifyListeners();
  }

  // ── Ledger range lens (spec: Period picker) ───────────────────────────────
  // A temporary, never-persisted window that replaces the month on the Ledger
  // tab only. Held parallel to `_period` (rather than widening `period`'s type)
  // because `period` is shared with Planner + Insight, which must stay
  // month-only. The summary, list and header all read the effective window
  // through [ledgerWindow]; nothing outside the Ledger tab consults the lens.
  DateRange? _rangeLens;
  DateRange? get rangeLens => _rangeLens;
  bool get isRangeLensActive => _rangeLens != null;

  /// The window the Ledger tab summarises, lists and labels over: the lens when
  /// active, otherwise the calendar month of [period].
  DateRange get ledgerWindow =>
      _rangeLens ?? DateRange(_monthStart(_period), _monthEnd(_period));

  void applyRangeLens(DateRange range) {
    _rangeLens = range;
    notifyListeners();
  }

  void clearRangeLens() {
    if (_rangeLens == null) return;
    _rangeLens = null;
    notifyListeners();
  }

  static DateTime _monthStart(DateTime m) => DateTime(m.year, m.month, 1);
  static DateTime _monthEnd(DateTime m) =>
      DateTime(m.year, m.month + 1, 0, 23, 59, 59, 999);

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

  /// Archived accounts — read from the PRIVATE list on purpose: [accounts]
  /// filters `archived` out, so the Archive screen is the only place these
  /// resolve. Restoring one returns it to every list, picker and total.
  List<Account> get archivedAccounts =>
      _accounts.where((a) => a.archived).toList(growable: false);

  List<Category> get categories =>
      _categories.where((c) => !c.archived).toList(growable: false);

  /// Archived categories — read from the PRIVATE list for the same reason as
  /// [archivedAccounts]: the public [categories] getter hides them.
  List<Category> get archivedCategories =>
      _categories.where((c) => c.archived).toList(growable: false);

  List<Category> categoriesOfType(CategoryType type) =>
      categories.where((c) => c.type == type).toList(growable: false);

  /// The category-picker grid order (spec §3): most-used first, ties broken by
  /// newest-created first so a just-made category is not buried under equally
  /// unused older ones. Archived categories are already excluded by [categories].
  ///
  /// Usage is counted from the ledger rather than stored — the category set is
  /// small (well under a hundred) and this runs once when the picker opens (and
  /// again only on a keystroke), so a full [txnCountForCategory] scan per
  /// category is cheap enough to avoid adding a persisted counter to the model.
  List<Category> categoriesOfTypeByUsage(CategoryType type) {
    final list = categoriesOfType(type).toList();
    // A tie needs a stable, deterministic order; the counts are memoised so the
    // comparator does not rescan the ledger on every pairwise call.
    final uses = {for (final c in list) c.id: txnCountForCategory(c.id)};
    list.sort((a, b) {
      final byUse = uses[b.id]!.compareTo(uses[a.id]!);
      if (byUse != 0) return byUse;
      final da = a.createdAt, db = b.createdAt;
      if (da != null && db != null) {
        final byDate = db.compareTo(da); // newest first
        if (byDate != 0) return byDate;
      } else if (da == null && db != null) {
        return 1; // null (seed/legacy) sorts oldest, i.e. after
      } else if (da != null && db == null) {
        return -1;
      }
      // A final, stable tiebreak so the grid order is deterministic when both
      // usage and createdAt tie (Dart's List.sort is not itself stable).
      return a.id.compareTo(b.id);
    });
    return List.unmodifiable(list);
  }

  /// Categories the user can file against today — archived excluded, both types
  /// included. The More screen's Categories count; the public [categories]
  /// getter already hides archived, so this is its length by another name, kept
  /// as a named getter so the screen reads a domain concept rather than a list.
  int get categoryCount => categories.length;

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

  /// The Schedule list's tasks: open only (§11.2). Paid, paused, deleted and
  /// cancelled tasks are excluded here but stay reachable by id ([taskById]) for
  /// the Archive and the detail screens. A separate accessor rather than
  /// loosening this one, so callers that mean "on the schedule" keep meaning it.
  List<Task> get tasks =>
      _tasks.where((t) => t.status == TaskStatus.open).toList(growable: false);

  /// Paused series — removed from the list and the projection, fully reversible
  /// from the Archive (§8/§9). Newest change first.
  List<Task> get pausedTasks => _tasks
      .where((t) => t.status == TaskStatus.paused)
      .toList(growable: false);

  /// Finished one-offs — paid or cancelled. They vanish from the Schedule but
  /// remain reachable here so the task and its history stay findable (§9,
  /// problem 12). Not restorable.
  List<Task> get completedTasks => _tasks
      .where((t) =>
          !t.isRecurring &&
          (t.status == TaskStatus.paid || t.status == TaskStatus.skipped))
      .toList(growable: false);

  /// Archived (soft-deleted) tasks — reversible until the Archive is cleared
  /// (§8/§9). Their Ledger entries are never touched.
  List<Task> get deletedTasks => _tasks
      .where((t) => t.status == TaskStatus.deleted)
      .toList(growable: false);

  List<Category> get removedBudgets => _categories
      .where((c) => c.removedOn != null && c.monthlyBudget == null)
      .toList(growable: false);

  /// What the Archive holds — and only that. A thing with a management screen of
  /// its own keeps its archived items there and stays out of this count: tags
  /// always have, categories now do (§2.4). The Archive is for what has nowhere
  /// else to go.
  int get archivedCount =>
      archivedGoals.length +
      removedBudgets.length +
      archivedAccounts.length +
      pausedTasks.length +
      completedTasks.length +
      deletedTasks.length;

  /// Open tasks that book into [categoryId] — a scheduled item whose
  /// "Mark as paid" would otherwise write a fresh Ledger entry against an
  /// archived category (§6). Archiving is blocked while this is non-empty.
  List<Task> tasksUsingCategory(String categoryId) =>
      tasks.where((t) => t.categoryId == categoryId).toList(growable: false);

  // ── Tags (§1–§7) ──────────────────────────────────────────────────────────
  // Tags are a first-class entity so they can be renamed (one field, not a bulk
  // rewrite), merged, and archived. `lastUsedAt` is stored and orders every
  // surface; `_touchTags` advances it. `Txn.tagIds` holds ids, never names.

  /// Every tag, most-recently-used first — the base order both the picker and the
  /// management screen present in (recency lets finished tags sink on their own).
  List<Tag> get allTags => [..._tags]
    ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

  /// The tags the picker offers: never-archived, newest use first. Archiving a
  /// tag is exactly what removes it from here.
  List<Tag> get activeTags =>
      allTags.where((t) => !t.archived).toList(growable: false);

  /// Archived tags, newest use first — the management screen's ARCHIVED section.
  List<Tag> get archivedTags =>
      allTags.where((t) => t.archived).toList(growable: false);

  Tag? tagById(String? id) {
    if (id == null) return null;
    for (final t in _tags) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The tag whose folded name equals [name]'s, across ALL tags (archived too),
  /// or null. The uniqueness oracle for create/rename/merge.
  Tag? tagByFoldedName(String name, {String? exceptId}) {
    final fold = foldTag(name);
    for (final t in _tags) {
      if (t.id != exceptId && foldTag(t.name) == fold) return t;
    }
    return null;
  }

  /// Resolve a row's tag ids to display names, dropping any that no longer
  /// resolve. The layout widgets keep taking names — the model stops here.
  List<String> tagNames(List<String> ids) => [
        for (final id in ids)
          if (tagById(id) case final t?) t.name,
      ];

  /// How many transactions carry [tagId]. O(n); called for the management list,
  /// not per row-build.
  int txnCountForTag(String tagId) {
    var n = 0;
    for (final t in _txns) {
      if (t.tagIds.contains(tagId)) n++;
    }
    return n;
  }

  /// Usage count for every tag id in one O(n) pass over the ledger — the whole
  /// map at once, for callers that need counts for many tags (the picker rows,
  /// the management screen's IN USE / UNUSED split) without an O(n) scan per tag.
  Map<String, int> tagUsageCounts() {
    final counts = <String, int>{};
    for (final t in _txns) {
      for (final id in t.tagIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  int get tagsInUseCount => _tags.where((t) => !t.archived).length;
  int get tagsArchivedCount => _tags.where((t) => t.archived).length;

  /// Advance every listed tag's `lastUsedAt` to at least [when] (monotonic —
  /// never moves backward). Called whenever a transaction gains a tag or is
  /// edited to a later date (§1).
  void _touchTags(Iterable<String> tagIds, DateTime when) {
    for (final id in tagIds) {
      final tag = tagById(id);
      if (tag != null && when.isAfter(tag.lastUsedAt)) tag.lastUsedAt = when;
    }
  }

  /// Create a tag from a typed name and return it. A leading `#` is stripped and
  /// the name is trimmed; an empty result is rejected (returns null). If a tag
  /// with the same folded name already exists it is returned instead of a
  /// duplicate — and if that existing tag was archived, creating/using its name
  /// restores it (the user is explicitly reaching for it again).
  Tag? createTag(String rawName) {
    final name = rawName.trim().replaceFirst(RegExp(r'^#'), '').trim();
    if (name.isEmpty) return null;
    final existing = tagByFoldedName(name);
    if (existing != null) {
      if (existing.archived) {
        existing.archived = false;
        notifyListeners();
      }
      return existing;
    }
    final now = DateTime.now();
    final tag = Tag(id: _nextId('tg'), name: name, createdAt: now, lastUsedAt: now);
    _tags.add(tag);
    notifyListeners();
    return tag;
  }

  /// The tag a rename of [source] to [newName] would MERGE into, or null when the
  /// rename is a plain relabel. A merge is triggered only by a folded collision
  /// with a *different* existing tag; renaming a tag to its own name in different
  /// casing is a plain rename (§5).
  Tag? mergeTargetFor(Tag source, String newName) =>
      tagByFoldedName(newName, exceptId: source.id);

  /// Rename [source] to [newName], merging into an existing tag when the folded
  /// name collides with a different one (§5). Returns the surviving tag.
  ///
  /// Plain rename touches only the Tag row — no transaction is rewritten, because
  /// every row references the id. A merge repoints every referencing transaction
  /// to the target (deduplicated so one carrying both ids never ends up with it
  /// twice), deletes the source, and moves the target's `lastUsedAt` to the later
  /// of the two.
  Tag renameTag(Tag source, String newName) {
    final name = newName.trim().replaceFirst(RegExp(r'^#'), '').trim();
    if (name.isEmpty) return source;
    final target = mergeTargetFor(source, name);
    if (target == null) {
      source.name = name;
      notifyListeners();
      return source;
    }
    // Merge source → target.
    for (final t in _txns) {
      if (!t.tagIds.contains(source.id)) continue;
      final next = <String>[];
      final seen = <String>{};
      for (final id in t.tagIds) {
        final mapped = id == source.id ? target.id : id;
        if (seen.add(mapped)) next.add(mapped);
      }
      t.tagIds = next;
    }
    if (source.lastUsedAt.isAfter(target.lastUsedAt)) {
      target.lastUsedAt = source.lastUsedAt;
    }
    if (source.createdAt.isBefore(target.createdAt)) {
      target.createdAt = source.createdAt;
    }
    _tags.remove(source);
    notifyListeners();
    return target;
  }

  /// Archive a tag — take it out of circulation without touching its
  /// transactions (they keep it and keep matching it in the filter). Reversible,
  /// destroys nothing, so no confirmation (§4).
  void archiveTag(Tag tag) {
    tag.archived = true;
    notifyListeners();
  }

  void restoreTag(Tag tag) {
    tag.archived = false;
    notifyListeners();
  }

  /// Delete a tag outright — offered only when it is on no transactions (§4), so
  /// nothing is stripped from any history. A no-op (returns false) if it is still
  /// in use, as a guard against a caller that skipped the check.
  bool deleteTag(Tag tag) {
    if (txnCountForTag(tag.id) > 0) return false;
    _tags.remove(tag);
    notifyListeners();
    return true;
  }

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

  /// Source and destination account names for a transfer — the single source of
  /// truth for a transfer's "{from} → {to}" title, used by the row widgets and
  /// the Same-transactions header alike. A deleted (unresolvable) side falls
  /// back to 'Deleted account' so no side is ever empty.
  ({String from, String to}) transferParties(Txn txn) => (
        from: accountById(txn.fromRef)?.name ?? 'Deleted account',
        to: accountById(txn.toRef)?.name ?? 'Deleted account',
      );

  /// The joined "{from} → {to}" string, for single-Text call sites (the
  /// Same-transactions header) and semantics. Row widgets that need independent
  /// truncation build a two-`Flexible` row from [transferParties] instead.
  String transferTitle(Txn txn) {
    final p = transferParties(txn);
    return '${p.from} → ${p.to}';
  }

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

  /// Signed effect of [t] on [accountId] — public read-only wrapper for the
  /// goal MOVEMENTS preview, which shows each entry's effect on the watched
  /// account without opening the full ledger.
  double effectOfTxnOn(Txn t, String accountId) => _effectOn(t, accountId);

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

  /// Balance as it stood at the end of [date], ignoring the `asOf` cutoff — the
  /// account balance a goal reads for its starting figure (§1). Unlike
  /// [balanceOf] this is anchored to a calendar date, not a reporting lens.
  double balanceOn(String accountId, DateTime date) {
    final account = accountById(accountId);
    if (account == null) return 0;
    final cutoff = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    var balance = account.startingBalance;
    for (final t in _txns) {
      if (t.date.isAfter(cutoff)) continue;
      balance += _effectOn(t, accountId);
    }
    return balance;
  }

  /// [balanceOn] converted to base currency — a goal's `startAmount` for an
  /// account source.
  double balanceOnInBase(String accountId, DateTime date) => Fx.toBase(
        balanceOn(accountId, date),
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
  ///
  /// NOTE: currently has no callers. [AccountGroup.setAside] now expresses the
  /// same "earmarked cash is not spendable" intent structurally (its own group,
  /// excluded from Spendable by group membership rather than a per-account
  /// flag), so both this getter and [Account.countAsSpendable] are candidates
  /// for removal once nothing depends on them. Left in place here — deleting a
  /// public getter and a model field is a larger change than the group warrants
  /// and wants its own decision.
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

  /// Every transaction whose date falls inside [window] (inclusive both ends),
  /// newest first. The Ledger tab's range-lens twin of [txnsInMonth]: identical
  /// downstream math (grouping, day nets, after-balances), only the window
  /// bounds differ. A calendar month is just the window `[1st … last 23:59:59]`.
  List<Txn> txnsInWindow(DateRange window) => txns
      .where((t) =>
          !t.date.isBefore(window.start) && !t.date.isAfter(window.end))
      .toList(growable: false);

  /// Money in for the month — rebalances excluded (spec 6.2 isolation rule).
  /// Converted through [Fx.toBase] (spec §9): a foreign-currency income row must
  /// count as its base value, or this figure disagrees with the category budgets
  /// (which already convert) and the Insight flow identity cannot close.
  /// Delegates to the windowed twin so the fold — and its conversion — lives once.
  double monthIncome(DateTime month) =>
      incomeInWindow(DateRange(_monthStart(month), _monthEnd(month)));

  double monthExpense(DateTime month) =>
      expenseInWindow(DateRange(_monthStart(month), _monthEnd(month)));

  /// Range-lens twins of [monthIncome]/[monthExpense] — same fold, windowed, and
  /// **converted** (spec §9). Aliased by [inflowInWindow]/[outflowInWindow], the
  /// names Insight reads, which promise conversion in the getter name itself.
  double incomeInWindow(DateRange window, {Set<String>? visible}) =>
      txnsInWindow(window)
          .where((t) =>
              t.type == TxnType.income &&
              (visible == null || visible.contains(t.toRef)))
          .fold(0.0, (sum, t) => sum + Fx.toBase(t.amount, t.currency));

  double expenseInWindow(DateRange window, {Set<String>? visible}) =>
      txnsInWindow(window)
          .where((t) =>
              t.type == TxnType.expense &&
              (visible == null || visible.contains(t.fromRef)))
          .fold(0.0, (sum, t) => sum + Fx.toBase(t.amount, t.currency));

  /// The set of months (1–12) in [year] that hold at least one transaction —
  /// the Period sheet's has-data dots. One grouped pass per displayed year per
  /// sheet-open (the sheet caches the result per year while it is open), never
  /// a per-chip scan.
  Set<int> ledgerMonthsWithData(int year) {
    final months = <int>{};
    for (final t in _txns) {
      if (t.date.year == year) months.add(t.date.month);
    }
    return months;
  }

  /// The set of day-only dates in [month] that hold at least one transaction —
  /// the custom-range calendar's dimmed/undimmed cells (one pass per open).
  Set<DateTime> ledgerDaysWithData(DateTime month) {
    final days = <DateTime>{};
    for (final t in _txns) {
      if (t.date.year == month.year && t.date.month == month.month) {
        days.add(DateTime(t.date.year, t.date.month, t.date.day));
      }
    }
    return days;
  }

  /// The year of the earliest transaction — the Period sheet's `‹` floor. Falls
  /// back to the current period's year when there are no transactions.
  int get earliestTxnYear {
    if (_txns.isEmpty) return _period.year;
    var earliest = _txns.first.date.year;
    for (final t in _txns) {
      if (t.date.year < earliest) earliest = t.date.year;
    }
    return earliest;
  }

  /// The earliest transaction date across all accounts, or null when there are
  /// none — the anchor `All time` prints as `Since {month year}` in the range
  /// picker rather than the epoch floor (spec §1.1).
  DateTime? get firstTxnDate {
    DateTime? earliest;
    for (final t in _txns) {
      if (earliest == null || t.date.isBefore(earliest)) earliest = t.date;
    }
    return earliest;
  }

  /// The window nearest to [from] that contains at least one record, searching
  /// backwards first and then forwards, in the same unit as [from]. Null when
  /// the ledger is empty (or no reachable window holds a visible record). The
  /// search is bounded by the dates of the first and last transaction, so an
  /// empty ledger, or a window centuries away from the data, always terminates.
  ///
  /// The Insight empty-state back link's destination (spec §5): stepping back
  /// exactly one period lands the reader on another empty screen when two or
  /// more periods are quiet, so this finds the first window that actually has
  /// data. [visible], when non-null, restricts a "hit" to windows holding a
  /// record the reader can currently see — the account filter (spec §5) — so the
  /// link never lands on a screen that is empty for a different reason.
  DateRange? nearestWindowWithRecords(DateRange from, {Set<String>? visible}) {
    if (_txns.isEmpty) return null;
    // An all-time window cannot step (copyShifted returns itself) and already
    // spans the whole ledger, so there is never a nearer window to find.
    if (from.preset == RangePreset.allTime) return null;

    var first = _txns.first.date;
    var last = _txns.first.date;
    for (final t in _txns) {
      if (t.date.isBefore(first)) first = t.date;
      if (t.date.isAfter(last)) last = t.date;
    }

    bool hits(DateRange w) => txnsInWindow(w).any((t) =>
        visible == null ||
        visible.contains(t.fromRef) ||
        visible.contains(t.toRef));

    // Backwards: each step lowers the window's end by a fixed amount; stop once
    // it slips past the earliest record.
    for (var w = from.copyShifted(-1);
        !w.end.isBefore(first);
        w = w.copyShifted(-1)) {
      if (hits(w)) return w;
    }
    // Forwards: each step raises the window's start; stop once it passes the
    // latest record.
    for (var w = from.copyShifted(1);
        !w.start.isAfter(last);
        w = w.copyShifted(1)) {
      if (hits(w)) return w;
    }
    return null;
  }

  /// Left over = (In − Out) / In (spec 2.1).
  double monthLeftOverFraction(DateTime month) {
    final income = monthIncome(month);
    if (income <= 0) return 0;
    return (income - monthExpense(month)) / income;
  }

  // ── Budgets (spec 5.1) ────────────────────────────────────────────────────

  /// Spent in a category over [month], in base currency. A foreign-currency
  /// expense is converted through [Fx.toBase] before it is summed — every
  /// Planner budget figure depends on this, so a raw fold would understate (or
  /// overstate) burn for any non-base spending.
  ///
  /// One-line delegate to [spentInCategoryWindow] over the month's window — one
  /// fold, three entry points (spec §1 refactor rule). A calendar month is just
  /// the window `[1st … last 23:59:59]`, so this returns bit-identical values.
  double spentInCategory(String categoryId, DateTime month) =>
      spentInCategoryWindow(
          categoryId, DateRange(_monthStart(month), _monthEnd(month)));

  double earnedInCategory(String categoryId, DateTime month) =>
      earnedInCategoryWindow(
          categoryId, DateRange(_monthStart(month), _monthEnd(month)));

  /// Income booked against [categoryId] over an arbitrary window (inclusive),
  /// in base currency — an `EARNING` goal's `current` figure (§1/§6). Delegates
  /// to [earnedInCategoryWindow]; `txnsInWindow`'s `!isBefore/!isAfter` bounds
  /// match the old inline predicate exactly, so every caller is unchanged.
  double earnedInWindow(String categoryId, DateTime from, DateTime to) =>
      earnedInCategoryWindow(categoryId, DateRange(from, to));

  int txnCountForCategory(String categoryId) => _txns
      .where((t) => t.fromRef == categoryId || t.toRef == categoryId)
      .length;

  /// Sum of every budget's [Category.effectiveLimit] (rollover included). It has
  /// no month argument because a limit is the same every month — only spend
  /// varies. Planner's headline divides against this.
  double get totalBudget => budgetedCategories
      .fold(0.0, (sum, c) => sum + (c.effectiveLimit ?? 0));

  /// Spent against budgeted categories in [month]. Planner passes its own month
  /// here — it no longer reads the global [period].
  double budgetedSpend(DateTime month) => budgetedCategories
      .fold(0.0, (sum, c) => sum + spentInCategory(c.id, month));

  /// Spent in [month] on expense categories that carry **no** budget — the
  /// spend the old "left to spend" figure ignored (spec 5.1: Eating out et al.).
  double unbudgetedSpend(DateTime month) => categories
      .where((c) => c.type == CategoryType.expense && c.monthlyBudget == null)
      .fold(0.0, (sum, c) => sum + spentInCategory(c.id, month));

  /// The headline figure: budget minus *budgeted* spend. Unbudgeted spend sits
  /// outside the budget entirely, so it is excluded here — the hero describes
  /// the budget and nothing else, and agrees with the tab's own
  /// `budgeted of total` line (spec 5.1 §2). Goes negative — with its minus
  /// sign — when budgeted spend alone passes the budget.
  double leftThisMonth(DateTime month) =>
      totalBudget - budgetedSpend(month);

  /// Expense categories with no budget that have spending in [month], amount
  /// descending — the `NO BUDGET SET` list. A category with nothing spent is
  /// omitted (nothing is uncovered).
  List<Category> unbudgetedSpendingCategories(DateTime month) {
    final rows = categories
        .where((c) =>
            c.type == CategoryType.expense &&
            c.monthlyBudget == null &&
            spentInCategory(c.id, month) > 0)
        .toList();
    rows.sort((a, b) =>
        spentInCategory(b.id, month).compareTo(spentInCategory(a.id, month)));
    return rows;
  }

  bool isCurrentMonth(DateTime month) =>
      month.year == today.year && month.month == today.month;

  int daysInMonthOf(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  /// Fraction of [month] elapsed — the pace marker on the burn-rate bar. A past
  /// month reads full, a future month empty; only the current month is partial.
  double monthProgressFor(DateTime month) {
    if (!isCurrentMonth(month)) {
      final firstOfThisMonth = DateTime(today.year, today.month);
      return month.isBefore(firstOfThisMonth) ? 1.0 : 0.0;
    }
    return (today.day / daysInMonthOf(month)).clamp(0.0, 1.0);
  }

  int dayOfMonthFor(DateTime month) =>
      isCurrentMonth(month) ? today.day : daysInMonthOf(month);

  // Legacy `_period`-scoped getters, kept as thin delegates so any incidental
  // caller (and the FX fix) flows through the parameterised versions above.
  // Planner itself no longer reads these — it drives its own month.
  double get totalSpentAgainstBudget => budgetedSpend(_period);
  double get leftToSpend => totalBudget - totalSpentAgainstBudget;
  double get monthProgress => monthProgressFor(_period);
  int get dayOfMonth => dayOfMonthFor(_period);
  int get daysInPeriod => daysInMonthOf(_period);

  /// Spec 5.1 — (spent / days elapsed) × days in month − budget.
  double get projectedOverspend {
    if (dayOfMonth <= 0) return 0;
    final projected = (totalSpentAgainstBudget / dayOfMonth) * daysInPeriod;
    return projected - totalBudget;
  }

  // ── Insight (spec §6.5) ────────────────────────────────────────────────────
  // Insight's own window API. Ledger says *how much*; Insight says *where from,
  // where to, and what it did to what you own* — so these figures include the
  // revaluation the income/expense metrics deliberately exclude, and are all in
  // base currency. Two conversion bases, matching how the app already works:
  // balance-derived numbers fold through each ACCOUNT's currency (like
  // [netWorthDelta]); flow numbers fold through each TRANSACTION's currency
  // (like [spentInCategory]). Both identities in spec §0 close to the cent.
  //
  // Performance: [netWorthChangeInWindow] plus one [groupChangeInWindow] per
  // group is nine passes over `_txns` per build. Compute the whole report once
  // per build into a local record in the screen; do not call these from inside
  // row builders.

  /// Base-currency net worth at the end of [date] — every account's signed
  /// converted balance summed (liabilities carry negative balances, so this is
  /// assets − liabilities). The Insight hero's `before → after` pair reads this
  /// at each end of the window. Summed over ALL accounts (hidden included, like
  /// every net-worth total; archived included so a windowed history stays whole)
  /// — the same set [groupChangeInWindow] partitions.
  /// [visible], when non-null, restricts the sum to that set of account ids —
  /// Insight's account filter (spec §9.2). Null means every account, so every
  /// existing caller is unchanged and an empty filter is bit-identical.
  double netWorthOn(DateTime date, {Set<String>? visible}) => _accounts
      .where((a) => visible == null || visible.contains(a.id))
      .fold(0.0, (sum, a) => sum + balanceOnInBase(a.id, date));

  /// Net worth change across [window] — the Insight hero. The windowed twin of
  /// [netWorthDelta], which is anchored to the Balance header's ComparePeriod and
  /// therefore cannot answer "what did August do". One pass over the window
  /// (like [netWorthDelta]); equals `netWorthOn(end) − netWorthOn(before)` and,
  /// by construction, the sum of [groupChangeInWindow] over every group (§0
  /// stock identity).
  double netWorthChangeInWindow(DateRange window, {Set<String>? visible}) {
    var delta = 0.0;
    for (final t in txnsInWindow(window)) {
      for (final a in _accounts) {
        if (visible != null && !visible.contains(a.id)) continue;
        delta += Fx.toBase(_effectOn(t, a.id), a.currency);
      }
    }
    return delta;
  }

  /// Change in the summed base-currency balances of one [group] across [window].
  /// The stock identity: these sum to [netWorthChangeInWindow]. One pass.
  /// Under a filter, both sides restrict to [visible], so the identity still
  /// closes on the filtered set — the crossing-transfer effect on a visible
  /// account lands in that account's own group, so no MOVED term is needed here.
  double groupChangeInWindow(AccountGroup group, DateRange window,
      {Set<String>? visible}) {
    var delta = 0.0;
    for (final t in txnsInWindow(window)) {
      for (final a in _accounts) {
        if (a.group != group) continue;
        if (visible != null && !visible.contains(a.id)) continue;
        delta += Fx.toBase(_effectOn(t, a.id), a.currency);
      }
    }
    return delta;
  }

  /// Revaluation booked in [window], in base currency — the DEĞER DEĞİŞİMİ block.
  /// This is the figure income/expense metrics deliberately exclude (spec 6.2).
  double revaluedInWindow(DateRange window, {Set<String>? visible}) =>
      txnsInWindow(window)
          .where((t) =>
              t.type == TxnType.rebalance &&
              (visible == null || visible.contains(t.toRef)))
          .fold(0.0, (sum, t) => sum + Fx.toBase(t.amount, t.currency));

  /// What a window's transfers actually cost: the fee, plus any gap between what
  /// left the source and what landed in the destination once both are converted
  /// (spec §0). A same-currency transfer with no fee leaks 0 — which is why card
  /// payments and goal contributions never distort the hero. Defined as the
  /// negated sum of each transfer's own effects on the two accounts it touches.
  /// Never negative in practice, but not clamped — a negative leak is a data
  /// error worth surfacing, not hiding.
  double transferLeakInWindow(DateRange window, {Set<String>? visible}) {
    var leak = 0.0;
    for (final t in txnsInWindow(window)) {
      if (t.type != TxnType.transfer) continue;
      final from = accountById(t.fromRef);
      final to = accountById(t.toRef);
      // A leak belongs to a transfer only when BOTH ends are counted. Under a
      // filter, a transfer that crosses the boundary is not a leak on the
      // visible set — its visible end is real money leaving/arriving, counted by
      // [movedAcrossFilterInWindow] instead. With no filter both ends count, so
      // this is bit-identical to the old per-ref fold.
      bool inSet(Account? a) =>
          a != null && (visible == null || visible.contains(a.id));
      if (!inSet(from) || !inSet(to)) continue;
      leak -= Fx.toBase(_effectOn(t, from!.id), from.currency);
      leak -= Fx.toBase(_effectOn(t, to!.id), to.currency);
    }
    return leak;
  }

  /// Net effect on the *visible* accounts of transfers that cross the filter
  /// boundary in [window]. Zero when the filter is empty — with nothing hidden
  /// there is no boundary to cross. This is the waterfall's MOVED step (§9.3):
  /// money genuinely leaving (or arriving at) the visible set, which is neither
  /// income, expense, revaluation nor a leak, so the flow identity needs it to
  /// close on the filtered set.
  double movedAcrossFilterInWindow(DateRange window, {Set<String>? visible}) {
    if (visible == null) return 0;
    var moved = 0.0;
    for (final t in txnsInWindow(window)) {
      if (t.type != TxnType.transfer) continue;
      final from = accountById(t.fromRef);
      final to = accountById(t.toRef);
      final fromV = from != null && visible.contains(from.id);
      final toV = to != null && visible.contains(to.id);
      if (fromV == toV) continue; // both in or both out → not crossing
      final acc = fromV ? from : to;
      if (acc == null) continue;
      moved += Fx.toBase(_effectOn(t, acc.id), acc.currency);
    }
    return moved;
  }

  /// One grouped pass over [window], bucketed by category id, in base currency —
  /// the INCOME and SPENDING lists. Insight renders every category, so a
  /// per-category scan would be N passes over the ledger; this is one.
  ({Map<String, double> income, Map<String, double> expense})
      categoryFlowInWindow(DateRange window, {Set<String>? visible}) {
    final income = <String, double>{};
    final expense = <String, double>{};
    for (final t in txnsInWindow(window)) {
      switch (t.type) {
        case TxnType.expense:
          // The account charged is `fromRef`; the row counts when it is visible.
          if (visible != null && !visible.contains(t.fromRef)) break;
          expense[t.toRef] =
              (expense[t.toRef] ?? 0) + Fx.toBase(t.amount, t.currency);
        case TxnType.income:
          // The account credited is `toRef`; the row counts when it is visible.
          if (visible != null && !visible.contains(t.toRef)) break;
          income[t.fromRef] =
              (income[t.fromRef] ?? 0) + Fx.toBase(t.amount, t.currency);
        case TxnType.transfer:
        case TxnType.rebalance:
          break;
      }
    }
    return (income: income, expense: expense);
  }

  /// Windowed twins of [spentInCategory] / [earnedInCategory] — the category
  /// detail screen's per-period figure (§6). The month versions delegate here.
  double spentInCategoryWindow(String categoryId, DateRange window) =>
      txnsInWindow(window)
          .where((t) => t.type == TxnType.expense && t.toRef == categoryId)
          .fold(0.0, (sum, t) => sum + Fx.toBase(t.amount, t.currency));

  double earnedInCategoryWindow(String categoryId, DateRange window) =>
      txnsInWindow(window)
          .where((t) => t.type == TxnType.income && t.fromRef == categoryId)
          .fold(0.0, (sum, t) => sum + Fx.toBase(t.amount, t.currency));

  /// Spent in [window] on expense categories that carry no budget — the windowed
  /// twin of [unbudgetedSpend], for the see-all screen's `Bütçesiz…` strip.
  double unbudgetedSpendWindow(DateRange window) => categories
      .where((c) => c.type == CategoryType.expense && c.monthlyBudget == null)
      .fold(0.0, (sum, c) => sum + spentInCategoryWindow(c.id, window));

  /// Every rebalance in [window], newest first — the rows of the revaluation
  /// block, each naming its account.
  List<Txn> revaluationsInWindow(DateRange window, {Set<String>? visible}) =>
      txnsInWindow(window)
          .where((t) =>
              t.type == TxnType.rebalance &&
              (visible == null || visible.contains(t.toRef)))
          .toList(growable: false);

  /// Every transfer in [window], newest first — the transfer footnote's count
  /// and total.
  List<Txn> transfersInWindow(DateRange window) => txnsInWindow(window)
      .where((t) => t.type == TxnType.transfer)
      .toList(growable: false);

  /// Spent on credit-card accounts in [window]: expense transactions whose
  /// `fromRef` is an account in [AccountGroup.creditCards], in base — the DEBT
  /// block's "charged" figure.
  double chargedToCardsInWindow(DateRange window, {Set<String>? visible}) =>
      txnsInWindow(window)
          .where((t) =>
              t.type == TxnType.expense &&
              accountById(t.fromRef)?.group == AccountGroup.creditCards &&
              (visible == null || visible.contains(t.fromRef)))
          .fold(0.0, (sum, t) => sum + Fx.toBase(t.amount, t.currency));

  /// Paid *into* liability accounts in [window] via transfer — the DEBT block's
  /// "paid" figure, a positive magnitude. Uses what actually landed in the
  /// destination (`toAmount`), in the destination account's currency, so a
  /// cross-currency payment counts what the debt actually received.
  double paidToLiabilitiesInWindow(DateRange window, {Set<String>? visible}) {
    var paid = 0.0;
    for (final t in txnsInWindow(window)) {
      if (t.type != TxnType.transfer) continue;
      final dest = accountById(t.toRef);
      if (dest == null || !dest.group.isLiability) continue;
      if (visible != null && !visible.contains(dest.id)) continue;
      paid += Fx.toBase(t.toAmount ?? t.amount, dest.currency);
    }
    return paid;
  }

  /// Total liabilities as they stood at the end of [date] — positive magnitude.
  /// Built from [balanceOnInBase]; the DEBT block's before/after pair.
  double totalLiabilitiesOn(DateTime date, {Set<String>? visible}) => _accounts
      .where((a) =>
          a.group.isLiability && (visible == null || visible.contains(a.id)))
      .fold(0.0, (sum, a) => sum + balanceOnInBase(a.id, date))
      .abs();

  /// Total receivables as they stood at the end of [date] — the ALACAĞIN cell.
  double totalReceivablesOn(DateTime date, {Set<String>? visible}) => _accounts
      .where((a) =>
          a.group == AccountGroup.receivables &&
          (visible == null || visible.contains(a.id)))
      .fold(0.0, (sum, a) => sum + balanceOnInBase(a.id, date));

  /// The window's income/expense, **converted** (spec §9). Insight reads these —
  /// the getter name promises the conversion [incomeInWindow]/[expenseInWindow]
  /// now also perform, so a reader of Insight never has to wonder.
  double inflowInWindow(DateRange window, {Set<String>? visible}) =>
      incomeInWindow(window, visible: visible);
  double outflowInWindow(DateRange window, {Set<String>? visible}) =>
      expenseInWindow(window, visible: visible);

  // ── Goals, rebuilt on real balances (§1) ──────────────────────────────────
  //
  // A goal stores nothing derived. `start`, `current`, `progress`, the rates,
  // the projection and the section are all *read* from the ledger here, so a
  // transfer into a goal's account moves its bar with no write to the Goal.

  /// The section a goal appears under — derived from its source, never asked
  /// (§1). Asset accounts climb (SAVING), liabilities fall to zero (PAYING
  /// OFF), a receivable is collected by someone else (WAITING ON), an income
  /// category accrues (EARNING).
  GoalSection goalSection(Goal g) {
    if (g.source.isCategory) return GoalSection.earning;
    final acc = accountById(g.source.id);
    if (acc == null) return GoalSection.saving;
    if (acc.group == AccountGroup.receivables) return GoalSection.waitingOn;
    if (acc.isLiability) return GoalSection.payingOff;
    return GoalSection.saving;
  }

  static int _monthsBetween(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + (b.month - a.month);

  static DateTime _addMonths(DateTime d, int months) =>
      DateTime(d.year, d.month + months, d.day);

  /// Everything a goal's card and detail screen read (§1). Pure over the
  /// current ledger; nothing here mutates the goal.
  ///
  /// [asOf] freezes every figure at a past date — an archived goal's record must
  /// not keep moving after the goal ended, so its detail passes the goal's
  /// [Goal.endedAt]. Omitted (null) for a live goal, where every figure tracks
  /// [today] exactly as before.
  GoalMetrics goalMetrics(Goal g, {DateTime? asOf}) {
    final section = goalSection(g);
    final now = asOf ?? today;

    final double start;
    final double current;
    final bool sourceAvailable;
    if (g.source.isAccount) {
      final acc = accountById(g.source.id);
      sourceAvailable = acc != null && !acc.archived;
      start = balanceOnInBase(g.source.id, g.createdAt);
      // Frozen: the balance the account actually held on [asOf], not today's.
      current = asOf == null
          ? balanceInBase(g.source.id)
          : balanceOnInBase(g.source.id, asOf);
    } else {
      final cat = categoryById(g.source.id);
      sourceAvailable = cat != null && !cat.archived;
      start = 0;
      // The window ends at [asOf] when frozen — never past it, whatever the
      // targetDate says.
      current =
          earnedInWindow(g.source.id, g.createdAt, asOf ?? g.targetDate ?? now);
    }

    final target = g.targetAmount;
    final span = (target - start).abs();
    final progress =
        span == 0 ? 1.0 : ((current - start).abs() / span).clamp(0.0, 1.0);

    // Direction is set by the section, not by start-vs-target: saving, earning
    // and paying-off all climb in signed value toward the target; only a
    // receivable falls. This is what lets a goal created on an account already
    // past its target latch immediately (§9), which the abs `progress` cannot
    // express.
    final up = section != GoalSection.waitingOn;
    final atTarget = up ? current >= target : current <= target;

    // Only endsWhenReached goals can read "reached"; a refillable goal reads
    // Funded/Refill instead and never latches (§4).
    final reached = g.endsWhenReached && (g.isLatched || atTarget);

    final monthsElapsed = _monthsBetween(g.createdAt, now).clamp(0, 100000);
    final monthsRemaining =
        g.targetDate == null ? 0 : _monthsBetween(now, g.targetDate!);
    final gap = (target - current).abs();

    // Every division is guarded: both spans can be zero (§1).
    double? requiredRate;
    if (g.targetDate != null) {
      requiredRate = monthsRemaining > 0 ? gap / monthsRemaining : gap;
    }

    final moved = (current - start).abs();
    final actualRate =
        (monthsElapsed > 0 && moved > 0) ? moved / monthsElapsed : null;

    DateTime? projectedEnd;
    if (actualRate != null && actualRate > 0) {
      final monthsNeeded = (gap / actualRate).round();
      projectedEnd = _addMonths(now, monthsNeeded);
    }

    final daysTotal =
        g.targetDate == null ? 0 : g.targetDate!.difference(g.createdAt).inDays;
    final daysElapsed = now.difference(g.createdAt).inDays;

    return GoalMetrics(
      section: section,
      start: start,
      current: current,
      target: target,
      targetDate: g.targetDate,
      progress: progress,
      reached: reached,
      atTarget: atTarget,
      sourceAvailable: sourceAvailable,
      monthsElapsed: monthsElapsed,
      monthsRemaining: monthsRemaining,
      requiredRate: requiredRate,
      actualRate: actualRate,
      projectedEnd: projectedEnd,
      daysElapsed: daysElapsed,
      daysTotal: daysTotal,
    );
  }

  /// Whether [g] survives the Goals-tab header filter (Planner §1). The split
  /// runs off [GoalMetrics.needsAttention] and nothing else — the same predicate
  /// the sort uses — so a filtered list and the sort can never disagree.
  bool _matchesGoalFilter(Goal g, GoalFilter filter) => switch (filter) {
        GoalFilter.all => true,
        GoalFilter.needsAttention => goalMetrics(g).needsAttention,
        GoalFilter.onTrack => !goalMetrics(g).needsAttention,
      };

  /// The three header-filter counts over every active goal, in a single pass
  /// (Planner §1/§2): `all` is `goals.length`, `needsAttention` counts the goals
  /// `GoalMetrics.needsAttention` flags, and `onTrack` is the remainder. Feeds
  /// both the control's label and the sheet's row counts.
  ({int all, int needsAttention, int onTrack}) goalFilterCounts() {
    final list = goals;
    var attention = 0;
    for (final g in list) {
      if (goalMetrics(g).needsAttention) attention++;
    }
    return (
      all: list.length,
      needsAttention: attention,
      onTrack: list.length - attention,
    );
  }

  /// Active goals in [section], unsorted, narrowed to [filter] (Planner §3.2).
  /// The default `all` keeps every earlier caller (the Archive, the sums) on the
  /// unfiltered list.
  List<Goal> goalsInSection(GoalSection section,
          {GoalFilter filter = GoalFilter.all}) =>
      goals
          .where((g) =>
              goalSection(g) == section && _matchesGoalFilter(g, filter))
          .toList(growable: false);

  /// Active goals in [section], needs-attention first, then by target date
  /// (§2). A goal with no date sorts last within its group. [filter] removes
  /// rows *before* the sort; the sort rule itself is untouched (Planner §3.2).
  List<Goal> sortedGoalsInSection(GoalSection section,
      {GoalFilter filter = GoalFilter.all}) {
    final list = goalsInSection(section, filter: filter).toList();
    list.sort((a, b) {
      final ma = goalMetrics(a);
      final mb = goalMetrics(b);
      if (ma.needsAttention != mb.needsAttention) {
        return ma.needsAttention ? -1 : 1;
      }
      final da = a.targetDate;
      final db = b.targetDate;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return list;
  }

  /// The current/target sums a section header shows on the right (§2). The
  /// header formats them per section (`of`, `left`, `owed`). Under a [filter]
  /// the sums recompute over the visible goals only — a header must never carry
  /// its unfiltered total above a filtered card (Planner §3.2).
  ({double current, double target}) goalSectionSums(GoalSection section,
      {GoalFilter filter = GoalFilter.all}) {
    var c = 0.0;
    var t = 0.0;
    for (final g in goalsInSection(section, filter: filter)) {
      final m = goalMetrics(g);
      c += m.current;
      t += m.target;
    }
    return (current: c, target: t);
  }

  /// The sections that have at least one goal matching [filter], in display
  /// order (§2). A section whose goals all filter out drops from the list, so
  /// the Goals tab never renders an empty section (Planner §3.2).
  List<GoalSection> activeGoalSections({GoalFilter filter = GoalFilter.all}) =>
      GoalSection.values
          .where((s) => goalsInSection(s, filter: filter).isNotEmpty)
          .toList(growable: false);

  /// The account or category id backing the goal, for name/icon/colour lookups.
  IconData goalIcon(Goal g) => refIcon(g.source.id);

  /// §4 — the reached-but-at-\$0 card offers "Archive both" / "Keep account".
  /// True only for an account-backed, latched goal whose balance is now zero.
  bool goalOffersArchive(Goal g) {
    if (!g.isLatched || !g.source.isAccount) return false;
    return balanceOf(g.source.id).abs() < 0.005;
  }

  /// Latches any active, endsWhenReached goal that has met its target (§4).
  /// Records only the reached *date*; progress is never stored. Called after
  /// every ledger mutation and at load.
  void _syncGoalLatches() {
    for (final g in _goals) {
      if (g.status != GoalStatus.active) continue;
      if (!g.endsWhenReached || g.completedAt != null) continue;
      if (goalMetrics(g).atTarget) g.completedAt = today;
    }
  }

  /// Drops goals whose source id resolves to nothing (§9). Archived accounts
  /// still resolve — those keep rendering; only a truly deleted source is
  /// pruned.
  void _pruneOrphanGoals() {
    _goals.removeWhere((g) => g.source.isAccount
        ? accountById(g.source.id) == null
        : categoryById(g.source.id) == null);
  }

  // ── Schedule (spec §1–§11) ────────────────────────────────────────────────

  /// [today] at day granularity — the reference clock for everything on the tab.
  DateTime get _todayDay => DateTime(today.year, today.month, today.day);

  List<Task> get openTasks {
    final list = _tasks.where((t) => t.status == TaskStatus.open).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// The task's expected amount in base currency (§2.1). Converts through the
  /// **linked account's** currency exactly as mark-paid does; an absent account
  /// falls back to the base currency and never crashes.
  double _taskAmountInBase(Task t) => Fx.toBase(
        t.expectedAmount.abs(),
        accountById(t.linkedAccountId)?.currency ?? Fx.baseCurrency,
      );

  /// Public read of a task's expected amount in base currency — the detail
  /// screen's `PER YEAR` figure and row amounts (§7.3).
  double taskAmountInBase(Task t) => _taskAmountInBase(t);

  /// Overdue is horizon-independent by design (§3.1): a filter cannot make money
  /// not owed, so narrowing the horizon never hides an unpaid bill. Shape
  /// unchanged for the nav badge (app_shell) and the summary banner.
  List<Task> get overdueTasks => openTasks
      .where((t) => t.daysUntilDue(today) < 0)
      .toList(growable: false);

  /// Overdue pay-outs still owed. Applied at day 0 of the projection (§2.4).
  List<Task> get overdueOutflows =>
      overdueTasks.where((t) => t.isPayOut).toList(growable: false);

  /// Overdue pay-ins. Excluded from the projection — a salary that did not
  /// arrive is not money (§2.1) — but still shown in the banner (§2.5).
  List<Task> get overdueInflows =>
      overdueTasks.where((t) => !t.isPayOut).toList(growable: false);

  double get overdueOutAmount =>
      overdueOutflows.fold(0.0, (s, t) => s + _taskAmountInBase(t));

  double get overdueInAmount =>
      overdueInflows.fold(0.0, (s, t) => s + _taskAmountInBase(t));

  /// Total magnitude overdue — the banner's masked figure (§2.5).
  double get overdueAmount => overdueOutAmount + overdueInAmount;

  bool _dueInRange(Task t, DateRange h) {
    final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    final start = DateTime(h.start.year, h.start.month, h.start.day);
    final end = DateTime(h.end.year, h.end.month, h.end.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Open tasks whose due date falls inside [h]. Overdue tasks (due before the
  /// horizon's start, which is always today) fall out naturally (§3.1).
  List<Task> tasksInHorizon(DateRange h) =>
      openTasks.where((t) => _dueInRange(t, h)).toList(growable: false);

  /// Σ inflow in the horizon, excluding overdue inflows (§2.1/§2.3).
  double comingIn(DateRange h) => tasksInHorizon(h)
      .where((t) => !t.isPayOut)
      .fold(0.0, (s, t) => s + _taskAmountInBase(t));

  /// Σ outflow in the horizon **plus** every overdue outflow (§2.1/§2.3).
  double goingOut(DateRange h) {
    var out = tasksInHorizon(h)
        .where((t) => t.isPayOut)
        .fold(0.0, (s, t) => s + _taskAmountInBase(t));
    out += overdueOutAmount;
    return out;
  }

  /// The hero figure (§2.1): what is left after everything already committed —
  /// spendable cash, plus horizon inflows, minus horizon and overdue outflows.
  /// The projection is the only figure in Planner that converts currency; the
  /// app-wide FX gap in budgets/insight is out of this spec's scope.
  double projection(DateRange h) => spendable + comingIn(h) - goingOut(h);

  /// The first day the running balance goes negative within [h], and by how
  /// much — the highest-value output on the tab (§2.4). Overdue outflows land at
  /// day 0; inflows are applied before outflows on the same day. Only the first
  /// breach is reported.
  ({DateTime day, double amount})? firstShortfall(DateRange h) {
    var running = spendable - overdueOutAmount;
    final inRange = tasksInHorizon(h);
    final start = DateTime(h.start.year, h.start.month, h.start.day);
    final end = DateTime(h.end.year, h.end.month, h.end.day);
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      for (final t in inRange) {
        if (_sameDay(t.dueDate, d) && !t.isPayOut) {
          running += _taskAmountInBase(t);
        }
      }
      for (final t in inRange) {
        if (_sameDay(t.dueDate, d) && t.isPayOut) {
          running -= _taskAmountInBase(t);
        }
      }
      if (running < 0) return (day: d, amount: -running);
    }
    return null;
  }

  /// Days in [h] that carry a task — the calendar dots (§1.2).
  Set<DateTime> daysWithTasks(DateRange h) => {
        for (final t in tasksInHorizon(h))
          DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day),
      };

  /// Days in [h] on which the running balance is negative — the red dots
  /// (§1.2), using the same day-by-day run as [firstShortfall].
  Set<DateTime> negativeDays(DateRange h) {
    final out = <DateTime>{};
    var running = spendable - overdueOutAmount;
    final inRange = tasksInHorizon(h);
    final start = DateTime(h.start.year, h.start.month, h.start.day);
    final end = DateTime(h.end.year, h.end.month, h.end.day);
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      for (final t in inRange) {
        if (_sameDay(t.dueDate, d) && !t.isPayOut) {
          running += _taskAmountInBase(t);
        }
      }
      for (final t in inRange) {
        if (_sameDay(t.dueDate, d) && t.isPayOut) {
          running -= _taskAmountInBase(t);
        }
      }
      if (running < 0) out.add(DateTime(d.year, d.month, d.day));
    }
    return out;
  }

  /// The count of open, non-overdue tasks due in each of [ranges], in ONE pass
  /// over [openTasks] (§1). Overdue tasks are outside every horizon and excluded
  /// from every count.
  List<int> horizonCounts(List<DateRange> ranges) {
    final counts = List<int>.filled(ranges.length, 0);
    for (final t in openTasks) {
      if (t.daysUntilDue(today) < 0) continue;
      for (var i = 0; i < ranges.length; i++) {
        if (_dueInRange(t, ranges[i])) counts[i]++;
      }
    }
    return counts;
  }

  /// Every Ledger entry a task produced, newest first — the detail screen's
  /// PAYMENT HISTORY (§7.6). Empty until the first payment is booked after this
  /// ships, because [markTaskPaid] only started stamping `recurrenceTaskId` now.
  List<Txn> paymentsForTask(String taskId) => txns
      .where((t) => t.recurrenceTaskId == taskId)
      .toList(growable: false);

  double paymentTotalForTask(String taskId) => paymentsForTask(taskId)
      .fold(0.0, (s, t) => s + Fx.toBase(t.amount, t.currency));

  /// Completed / skipped / cancelled events over [period], newest first (§11.5).
  /// Merged from three sources: paid & received transactions (amount and date
  /// from the Txn, never the task), recurring skips, and cancelled one-offs.
  /// A permanently-deleted task's payments lose their link and drop out — the
  /// reason Delete archives rather than destroys.
  List<ScheduleEvent> scheduleEvents(DateRange period) {
    bool inPeriod(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      final s = DateTime(period.start.year, period.start.month, period.start.day);
      final e = DateTime(period.end.year, period.end.month, period.end.day);
      return !day.isBefore(s) && !day.isAfter(e);
    }

    final events = <ScheduleEvent>[];
    // 1 · paid / received — real transactions linked back to their task.
    for (final t in _txns) {
      final rid = t.recurrenceTaskId;
      if (rid == null || !inPeriod(t.date)) continue;
      final task = taskById(rid);
      if (task == null) continue;
      final received = t.type == TxnType.income;
      events.add(ScheduleEvent(
        date: t.date,
        task: task,
        txn: t,
        outcome:
            received ? ScheduleOutcome.received : ScheduleOutcome.paid,
        amountInBase: Fx.toBase(t.amount, t.currency),
      ));
    }
    // 2 · skipped — every recurring skip, including on paused/archived tasks.
    for (final task in _tasks) {
      for (final sd in task.skippedDates) {
        if (!inPeriod(sd)) continue;
        events.add(ScheduleEvent(
          date: sd,
          task: task,
          outcome: ScheduleOutcome.skipped,
          amountInBase: _taskAmountInBase(task),
        ));
      }
    }
    // 3 · cancelled — one-off tasks whose single occurrence was skipped.
    for (final task in _tasks) {
      if (!task.isRecurring &&
          task.status == TaskStatus.skipped &&
          inPeriod(task.dueDate)) {
        events.add(ScheduleEvent(
          date: task.dueDate,
          task: task,
          outcome: ScheduleOutcome.cancelled,
          amountInBase: _taskAmountInBase(task),
        ));
      }
    }
    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

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
    List<String> tagIds = const [],
    String note = '',
    String? goalId,
    String? splitGroupId,
    String? recurrenceTaskId,
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
      tagIds: tagIds,
      note: note,
      goalId: goalId,
      splitGroupId: splitGroupId,
      recurrenceTaskId: recurrenceTaskId,
    );
    _txns.add(txn);
    // Every tag this transaction carries was just used (§1 — lastUsedAt).
    _touchTags(txn.tagIds, txn.date);
    _sameIndex = null;
    _accountIndex = null;
    // A moved balance can newly meet a goal's target; latch any that reached
    // (§4). Progress itself is never stored — only the reached *date* is.
    _syncGoalLatches();
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
    List<String>? tagIds,
    String? note,
    double? fee,
    double? toAmount,
    double? exchangeRate,
    String? recurrenceTaskId,
    bool clearRecurrence = false,
  }) {
    txn
      ..amount = amount ?? txn.amount
      ..fromRef = fromRef ?? txn.fromRef
      ..toRef = toRef ?? txn.toRef
      ..date = date ?? txn.date
      ..tagIds = tagIds ?? txn.tagIds
      ..note = note ?? txn.note
      ..fee = fee ?? txn.fee
      ..toAmount = toAmount ?? txn.toAmount
      ..exchangeRate = exchangeRate ?? txn.exchangeRate
      ..recurrenceTaskId =
          clearRecurrence ? null : (recurrenceTaskId ?? txn.recurrenceTaskId)
      ..editedCount += 1;
    // A tag the edit added, or a date pushed later, counts as a fresh use (§1).
    _touchTags(txn.tagIds, txn.date);
    // An edit can change fromRef/toRef/date, so the same-key index is stale.
    _sameIndex = null;
    _accountIndex = null;
    // A moved balance can newly meet a goal's target; latch any that reached
    // (§4). Progress itself is never stored — only the reached *date* is.
    _syncGoalLatches();
    notifyListeners();
  }

  void deleteTxn(Txn txn) {
    _txns.removeWhere((t) => t.id == txn.id);
    _sameIndex = null;
    _accountIndex = null;
    // A moved balance can newly meet a goal's target; latch any that reached
    // (§4). Progress itself is never stored — only the reached *date* is.
    _syncGoalLatches();
    notifyListeners();
  }

  /// Debug-only: replace the entire in-memory dataset with [source]'s, in place.
  /// Replaces this store's data with [source]'s. Backs both the developer
  /// Seed/Reset menu and the user-facing Restore-from-backup flow (see
  /// [MoreScreen]). Because this mutates the existing store rather than swapping
  /// the instance, loaded preferences (privacy, balance filter/order, ranges)
  /// survive the swap, and the attached persister — a listener — writes the
  /// restored data straight back to disk on the trailing [notifyListeners].
  /// Copies [source]'s full goal list so archived goals come across too (the
  /// public [goals] getter filters them out).
  void loadFrom(AppStore source) {
    _accounts
      ..clear()
      ..addAll(source._accounts);
    _categories
      ..clear()
      ..addAll(source._categories);
    _txns
      ..clear()
      ..addAll(source._txns);
    _goals
      ..clear()
      ..addAll(source._goals);
    _tasks
      ..clear()
      ..addAll(source._tasks);
    _tags
      ..clear()
      ..addAll(source._tags);
    _customCurrencies
      ..clear()
      ..addAll(source._customCurrencies);
    // Adopt the restored custom currencies into the global catalog so a Restore
    // makes them formattable immediately (spec §7a round-trip).
    setCustomCurrencies(_customCurrencies);
    // The source store already ran [_migrateTags] in its own constructor; adopt
    // its schema so this store does not re-migrate already-reified ids.
    _tagSchema = source._tagSchema;
    _tagMigrationMerged = source._tagMigrationMerged;
    // Adopt the source's id counter too. Without this a Restore into a store
    // that started blank (_idSeq == 1000) would mint colliding ids for the next
    // new entity, since the restored rows already carry ids well past 1000.
    _idSeq = source._idSeq;
    _sameIndex = null;
    _accountIndex = null;
    // A moved balance can newly meet a goal's target; latch any that reached
    // (§4). Progress itself is never stored — only the reached *date* is.
    _syncGoalLatches();
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

  // ── Currencies (user-defined) ─────────────────────────────────────────────

  /// The currency codes already in use across the user's accounts, most-recent
  /// first — the `RECENT` group in the currency picker (spec §6). Recency is
  /// approximated by reverse account order (newer accounts sit later in the
  /// list). Returns an empty list when nothing has been chosen yet, so the
  /// caller can omit the group entirely.
  List<String> get recentCurrencyCodes {
    final seen = <String>{};
    final out = <String>[];
    for (final a in _accounts.reversed) {
      if (seen.add(a.currency)) out.add(a.currency);
    }
    return out;
  }

  /// Adds a user-defined currency (spec §7a) and re-registers the catalog so it
  /// formats everywhere at once. The caller is responsible for the duplicate-code
  /// guard ([currencyCodeExists]); this assumes a fresh, upper-cased code.
  void addCustomCurrency(CurrencyDef def) {
    _customCurrencies.add(def.copyWith(custom: true));
    setCustomCurrencies(_customCurrencies);
    notifyListeners();
  }

  // ── Mutations: accounts ───────────────────────────────────────────────────

  Account addAccount({
    required String name,
    required AccountGroup group,
    required String currency,
    required double startingBalance,
    double? creditLimit,
    int? paymentDue,
    bool countAsSpendable = true,
    IconData? icon,
    String? emoji,
    int? colorValue,
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
      paymentDue: paymentDue,
      countAsSpendable: countAsSpendable,
      icon: icon,
      emoji: emoji,
      colorValue: colorValue,
      openedOn: today,
      // A new account's history begins the day it is created, so its opening
      // receipt is filed under today (spec §9 "Account created today").
      openingDate: DateTime(today.year, today.month, today.day),
    );
    _accounts.add(account);
    notifyListeners();
    return account;
  }

  /// Sets (or clears, with [amount] 0) an account's opening balance — the one
  /// blessed way to move a past balance directly (spec §5/§6). [amount] is an
  /// unsigned magnitude in the account's own currency; the liability sign is
  /// applied here so the floor matches the running-balance column's convention
  /// (spec §2.4). Because balances are derived, mutating the floor and notifying
  /// is enough to shift every running balance on the account at once.
  void setOpeningBalance(
    Account account, {
    required double amount,
    DateTime? date,
  }) {
    account.startingBalance =
        account.isLiability ? -amount.abs() : amount;
    if (date != null) {
      account.openingDate = DateTime(date.year, date.month, date.day);
    }
    notifyListeners();
  }

  /// The earliest transaction date touching [accountId], or null when the
  /// account has none — the ceiling the opening date may not exceed (spec §5:
  /// "A floor cannot sit above what rests on it").
  DateTime? earliestTxnDateForAccount(String accountId) {
    DateTime? earliest;
    for (final t in _txns) {
      if (t.fromRef != accountId && t.toRef != accountId) continue;
      if (earliest == null || t.date.isBefore(earliest)) earliest = t.date;
    }
    return earliest;
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

  /// The reversal of [removeAccount]'s archive: the account returns to its
  /// group with its balance and full history. No transaction is created — the
  /// money was never removed from the ledger, only hidden from the lists.
  void restoreAccount(Account account) {
    account.archived = false;
    notifyListeners();
  }

  // ── Mutations: categories & budgets ───────────────────────────────────────

  Category addCategory({
    required String name,
    required CategoryType type,
    required IconData icon,
    required Color color,
    String? emoji,
    double? monthlyBudget,
  }) {
    final category = Category(
      id: _nextId('c'),
      name: name,
      type: type,
      icon: icon,
      color: color,
      emoji: emoji,
      // Stamped so the picker can break usage ties by newest-first (spec §3).
      createdAt: today,
      monthlyBudget: monthlyBudget,
    );
    // A budget born with the category is its own `created` entry — history is
    // complete from birth (no backfill needed). rollover defaults off here.
    if (monthlyBudget != null) {
      category.budgetHistory.add(BudgetEdit(
        at: today,
        field: 'created',
        from: category.budgetRollover ? 'on' : 'off',
        to: money(monthlyBudget),
      ));
    }
    _categories.add(category);
    notifyListeners();
    return category;
  }

  /// Every budget-field change is logged to [Category.budgetHistory] — but only
  /// a *real* change: this method writes `x ?? category.x`, so a save that
  /// touched nothing must append nothing. Compare before assigning. A null→value
  /// transition is a `created` entry (money + rollover state), not a `limit`
  /// one; on that birth call the rollover/warn moves fold into `created` rather
  /// than logging separately. One save can legitimately emit three rows (limit,
  /// rollover, warn), all carrying the same [today].
  void updateBudget(
    Category category, {
    double? monthlyBudget,
    bool? rollover,
    double? warnThreshold,
  }) {
    final creating = monthlyBudget != null && category.monthlyBudget == null;
    final newLimit = monthlyBudget ?? category.monthlyBudget;
    final newRollover = rollover ?? category.budgetRollover;
    final newWarn = warnThreshold ?? category.warnThreshold;

    if (creating) {
      category.budgetHistory.add(BudgetEdit(
        at: today,
        field: 'created',
        from: newRollover ? 'on' : 'off',
        to: money(newLimit!),
      ));
    } else {
      if (monthlyBudget != null && monthlyBudget != category.monthlyBudget) {
        category.budgetHistory.add(BudgetEdit(
          at: today,
          field: 'limit',
          from: money(category.monthlyBudget!),
          to: money(monthlyBudget),
          // A raised limit is amber; a lowered one is not.
          amber: monthlyBudget > category.monthlyBudget!,
        ));
      }
      if (rollover != null && rollover != category.budgetRollover) {
        category.budgetHistory.add(BudgetEdit(
          at: today,
          field: 'rollover',
          from: category.budgetRollover ? 'on' : 'off',
          to: rollover ? 'on' : 'off',
        ));
      }
      if (warnThreshold != null && warnThreshold != category.warnThreshold) {
        category.budgetHistory.add(BudgetEdit(
          at: today,
          field: 'warn',
          from: percent(category.warnThreshold, decimals: 0),
          to: percent(warnThreshold, decimals: 0),
        ));
      }
    }

    category
      ..monthlyBudget = newLimit
      ..budgetRollover = newRollover
      ..warnThreshold = newWarn;
    notifyListeners();
  }

  /// Spec 5.5 — removing a budget is `Category.monthly_budget = null`. The
  /// category and its transactions are deliberately untouched. Logs `removed`
  /// with the last limit. The history outlives the removal.
  void removeBudget(Category category) => _removeBudget(category, log: true);

  /// The shared removal. [archiveCategory] passes `log: false` so one user
  /// action (archiving) writes one `categoryArchived` row, not a `removed` row
  /// as well.
  void _removeBudget(Category category, {required bool log}) {
    if (log && category.monthlyBudget != null) {
      category.budgetHistory.add(BudgetEdit(
        at: today,
        field: 'removed',
        from: '',
        to: money(category.monthlyBudget!),
      ));
    }
    category
      ..monthlyBudget = null
      ..removedOn = today;
    notifyListeners();
  }

  void restoreBudget(Category category, double limit) {
    category.budgetHistory.add(BudgetEdit(
      at: today,
      field: 'restored',
      from: '',
      to: money(limit),
    ));
    category
      ..monthlyBudget = limit
      ..removedOn = null;
    notifyListeners();
  }

  /// Retire a category from every picker while leaving its history intact.
  /// Nothing already filed changes: past transactions keep rendering with this
  /// category's name and icon. A budget on it would sit at $0/limit forever
  /// with nothing left to file, so it is removed (which sets `removedOn`,
  /// landing it in the Archive's own removed-budgets section to be restored
  /// independently). Direction/type are untouched. The budget's CHANGES record
  /// gets a single `categoryArchived` row — the nested removal is logged as
  /// `false` so this one action does not write two rows.
  void archiveCategory(Category category) {
    if (category.monthlyBudget != null) {
      category.budgetHistory.add(BudgetEdit(
        at: today,
        field: 'categoryArchived',
        from: '',
        to: '',
      ));
      _removeBudget(category, log: false);
    }
    category.archived = true;
    notifyListeners();
  }

  /// The reversal of [archiveCategory]: the category reappears in every picker.
  /// Its old budget does not come back automatically — that has its own Restore
  /// in the removed-budgets section.
  void restoreCategory(Category category) {
    category.archived = false;
    notifyListeners();
  }

  /// §3.4 — rename / re-icon / recolour. Type is deliberately absent: flipping a
  /// category's direction would reverse every transaction already filed against
  /// it, and nothing in the app is allowed to do that silently.
  void updateCategory(Category category,
      {String? name, IconData? icon, Color? color}) {
    category
      ..name = name ?? category.name
      ..icon = icon ?? category.icon
      ..color = color ?? category.color;
    notifyListeners();
  }

  /// §3.4 — erase a category outright. Only legal when nothing references it — no
  /// transaction, no budget. Returns false and changes nothing otherwise, so the
  /// caller can never delete history by passing the wrong id.
  bool deleteCategory(Category category) {
    if (txnCountForCategory(category.id) > 0) return false;
    if (category.monthlyBudget != null) return false;
    _categories.removeWhere((c) => c.id == category.id);
    notifyListeners();
    return true;
  }

  // ── Mutations: goals ──────────────────────────────────────────────────────

  static String _histDate(DateTime? d) =>
      d == null ? '—' : '${d.day}.${d.month}.${d.year}';

  /// §1/§3 — a goal is created watching a real source. No money moves: the goal
  /// is a lens, and its `startAmount` is read from the source's balance at
  /// creation, not deposited. The history is seeded with a `created` entry (§7).
  Goal addGoal({
    required String name,
    required GoalSource source,
    required double targetAmount,
    DateTime? targetDate,
    bool endsWhenReached = true,
    String note = '',
  }) {
    final createdTo = targetDate == null
        ? money(targetAmount)
        : '${money(targetAmount)} · ${_histDate(targetDate)}';
    final goal = Goal(
      id: _nextId('g'),
      name: name,
      source: source,
      targetAmount: targetAmount,
      targetDate: targetDate,
      endsWhenReached: endsWhenReached,
      note: note,
      createdAt: today,
      history: [
        GoalEdit(at: today, field: 'created', from: '', to: createdTo),
      ],
    );
    _goals.add(goal);
    // A target already met at creation latches immediately (§9).
    _syncGoalLatches();
    notifyListeners();
    return goal;
  }

  /// §3/§7 — the source is **not** editable (locked after creation). Target and
  /// date changes are logged to [Goal.history]; name and note changes are not.
  void updateGoal(
    Goal goal, {
    String? name,
    double? targetAmount,
    DateTime? targetDate,
    bool clearTargetDate = false,
    bool? endsWhenReached,
    String? note,
  }) {
    if (targetAmount != null && targetAmount != goal.targetAmount) {
      goal.history.add(GoalEdit(
        at: today,
        field: 'target',
        from: money(goal.targetAmount),
        to: money(targetAmount),
      ));
    }
    final newDate = clearTargetDate ? null : (targetDate ?? goal.targetDate);
    if (newDate != goal.targetDate) {
      // A pushed-out deadline (later than before) is flagged amber (§7).
      final pushedOut = newDate != null &&
          goal.targetDate != null &&
          newDate.isAfter(goal.targetDate!);
      goal.history.add(GoalEdit(
        at: today,
        field: 'targetDate',
        from: _histDate(goal.targetDate),
        to: _histDate(newDate),
        amber: pushedOut,
      ));
    }
    goal
      ..name = name ?? goal.name
      ..targetAmount = targetAmount ?? goal.targetAmount
      ..targetDate = newDate
      ..endsWhenReached = endsWhenReached ?? goal.endsWhenReached
      ..note = note ?? goal.note;
    _syncGoalLatches();
    notifyListeners();
  }

  /// §5 — retire a goal into the Archive as reached. Keeps the reached date if
  /// the goal already latched.
  void markGoalReached(Goal goal) {
    goal
      ..status = GoalStatus.reached
      ..completedAt = goal.completedAt ?? today;
    notifyListeners();
  }

  /// §4 "Archive both" — retire the goal *and* archive its account. The goal is
  /// the only object allowed to archive an account, and only through this path.
  void reachGoalAndArchiveAccount(Goal goal) {
    goal
      ..status = GoalStatus.reached
      ..completedAt = goal.completedAt ?? today;
    if (goal.source.isAccount) {
      final acc = accountById(goal.source.id);
      if (acc != null) acc.archived = true;
    }
    notifyListeners();
  }

  /// §5 — "Stop tracking": the everyday exit. Leaves the record in Archive.
  void abandonGoal(Goal goal) {
    goal
      ..status = GoalStatus.abandoned
      ..stoppedAt = today;
    notifyListeners();
  }

  /// §5/§8 — a goal is a lens, never a container. Deleting it touches neither
  /// the account nor its money nor its transactions.
  void deleteGoal(Goal goal) {
    _goals.removeWhere((g) => g.id == goal.id);
    notifyListeners();
  }

  void restoreGoal(Goal goal) {
    goal
      ..status = GoalStatus.active
      ..stoppedAt = null
      ..completedAt = null;
    _syncGoalLatches();
    notifyListeners();
  }

  /// Hard-delete a set of tasks and sever every payment that pointed at them, so
  /// no orphan `recurrenceTaskId` survives (§6.3/§9). Ledger entries stay — only
  /// the link is nulled. Does not notify; the public caller does, once.
  void _purgeTasks(Set<String> ids) {
    if (ids.isEmpty) return;
    for (final t in _txns) {
      if (t.recurrenceTaskId != null && ids.contains(t.recurrenceTaskId)) {
        t.recurrenceTaskId = null;
      }
    }
    _tasks.removeWhere((t) => ids.contains(t.id));
    _taskPriorStatus.removeWhere((id, _) => ids.contains(id));
  }

  /// §6.3 — clear the Archive's FINISHED section: reached goals and paid one-off
  /// tasks. Leaves everything else (paused tasks, removed budgets, archived
  /// accounts, the UNFINISHED and RECENTLY DELETED sections) untouched.
  void clearFinished() {
    _goals.removeWhere((g) => g.status == GoalStatus.reached);
    _purgeTasks({
      for (final t in completedTasks)
        if (t.status == TaskStatus.paid) t.id,
    });
    notifyListeners();
  }

  /// §6.3 — clear the Archive's UNFINISHED section: abandoned goals and cancelled
  /// (skipped) one-off tasks. Nothing restorable is touched.
  void clearUnfinished() {
    _goals.removeWhere((g) => g.status == GoalStatus.abandoned);
    _purgeTasks({
      for (final t in completedTasks)
        if (t.status == TaskStatus.skipped) t.id,
    });
    notifyListeners();
  }

  /// §6.3 — empty the Archive's RECENTLY DELETED section: the soft-deleted tasks,
  /// for good.
  void deleteRecycledTasks() {
    _purgeTasks({for (final t in deletedTasks) t.id});
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
    Set<int> weekdays = const {},
    Set<int> daysOfMonth = const {},
    int repeatInterval = 1,
    RepeatUnit? repeatUnit,
    DateTime? repeatEndDate,
    int? repeatEndCount,
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
      weekdays: weekdays,
      daysOfMonth: daysOfMonth,
      repeatInterval: repeatInterval,
      repeatUnit: repeatUnit,
      repeatEndDate: repeatEndDate,
      repeatEndCount: repeatEndCount,
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
    String? payToAccountId,
    String? note,
    RepeatFrequency? repeats,
    Set<int>? weekdays,
    Set<int>? daysOfMonth,
    Priority? priority,
    int? reminderDaysBefore,
    TimeOfDay? reminderTime,
    bool clearReminder = false,
    bool clearCategory = false,
    bool clearPayTo = false,
  }) {
    task
      ..title = title ?? task.title
      // A transfer task carries no budget category and vice versa (§10.4).
      ..categoryId = clearCategory ? null : (categoryId ?? task.categoryId)
      ..payToAccountId = clearPayTo ? null : (payToAccountId ?? task.payToAccountId)
      ..note = note ?? task.note
      ..linkedAccountId = linkedAccountId ?? task.linkedAccountId
      ..expectedAmount = expectedAmount ?? task.expectedAmount
      ..dueDate = dueDate ?? task.dueDate
      ..repeats = repeats ?? task.repeats
      ..weekdays = weekdays ?? task.weekdays
      ..daysOfMonth = daysOfMonth ?? task.daysOfMonth
      ..priority = priority ?? task.priority
      ..reminderDaysBefore =
          clearReminder ? null : (reminderDaysBefore ?? task.reminderDaysBefore)
      ..reminderTime = clearReminder ? null : (reminderTime ?? task.reminderTime);
    notifyListeners();
  }

  /// §10.3/§10.4 — books the real Ledger entry for one occurrence, then advances
  /// the series (or closes a one-off). The caller supplies the actual amount,
  /// pay date, source account and destination, so the entry never needs
  /// correcting afterwards.
  ///
  /// [toRef] is a **category id** (ordinary spend / income) or an **account id**
  /// (paying down a liability). A pay-out into an account is a **transfer**, not
  /// a spend: a spend would grow the debt it settles (§10.4). The returned
  /// [MarkPaidResult] carries everything [undoMarkTaskPaid] needs to reverse it.
  MarkPaidResult markTaskPaid(
    Task task, {
    required double amount,
    required DateTime date,
    required String fromAccountId,
    required String toRef,
    bool rememberAmount = false,
  }) {
    final prevDue = task.dueDate;
    final prevStatus = task.status;
    final prevChanged = task.statusChangedAt;
    final prevExpected = task.expectedAmount;

    final isPayOut = task.expectedAmount < 0;
    final toIsAccount = accountById(toRef) != null;
    final Txn txn;
    if (isPayOut && toIsAccount) {
      final from = accountById(fromAccountId);
      txn = addTxn(
        type: TxnType.transfer,
        amount: amount,
        currency: from?.currency ?? Fx.baseCurrency,
        fromRef: fromAccountId,
        toRef: toRef,
        date: date,
        note: task.title,
        recurrenceTaskId: task.id,
      );
    } else if (isPayOut) {
      final from = accountById(fromAccountId);
      txn = addTxn(
        type: TxnType.expense,
        amount: amount,
        currency: from?.currency ?? Fx.baseCurrency,
        fromRef: fromAccountId,
        toRef: toRef,
        date: date,
        note: task.title,
        recurrenceTaskId: task.id,
      );
    } else {
      // Pay-in: income from a category into an account. Here [fromAccountId] is
      // the destination account (where the money lands) and [toRef] the income
      // category.
      final into = accountById(fromAccountId);
      txn = addTxn(
        type: TxnType.income,
        amount: amount,
        currency: into?.currency ?? Fx.baseCurrency,
        fromRef: toRef,
        toRef: fromAccountId,
        date: date,
        note: task.title,
        recurrenceTaskId: task.id,
      );
    }

    if (rememberAmount) {
      task.expectedAmount = isPayOut ? -amount : amount;
    }
    _advance(task);
    notifyListeners();
    return MarkPaidResult(
      task: task,
      txn: txn,
      previousDueDate: prevDue,
      previousStatus: prevStatus,
      previousStatusChangedAt: prevChanged,
      previousExpected: prevExpected,
    );
  }

  /// Reverses a [markTaskPaid]: deletes the written Txn and restores the due
  /// date, status and (if the sheet changed it) the expected amount (§10.3).
  void undoMarkTaskPaid(MarkPaidResult r) {
    _txns.removeWhere((t) => t.id == r.txn.id);
    _sameIndex = null;
    _accountIndex = null;
    r.task
      ..dueDate = r.previousDueDate
      ..status = r.previousStatus
      ..statusChangedAt = r.previousStatusChangedAt
      ..expectedAmount = r.previousExpected;
    _syncGoalLatches();
    notifyListeners();
  }

  /// §8 — skip writes nothing to the Ledger. A recurring skip is recorded in
  /// [Task.skippedDates] and the series advances; a one-off is cancelled.
  void skipTask(Task task) {
    if (task.isRecurring) {
      task.skippedDates = [...task.skippedDates, task.dueDate];
      _advance(task);
    } else {
      task
        ..status = TaskStatus.skipped
        ..statusChangedAt = today;
    }
    notifyListeners();
  }

  void _advance(Task task) {
    if (task.isRecurring) {
      task.dueDate = task.nextOccurrence(task.dueDate);
    } else {
      task
        ..status = TaskStatus.paid
        ..statusChangedAt = today;
    }
  }

  /// §8 — pause: the whole series leaves the list and the projection, fully
  /// reversible. History and future dates are kept; nothing is written.
  void pauseTask(Task task) {
    task
      ..status = TaskStatus.paused
      ..statusChangedAt = today;
    notifyListeners();
  }

  /// §9 — resume a paused (or, via Undo, deleted) task. A recurring series whose
  /// due date slipped into the past while paused is advanced to the next
  /// occurrence at or after today, so it does not return already overdue. A
  /// one-off whose date has passed returns as overdue — it genuinely is.
  void resumeTask(Task task) {
    if (task.isRecurring) {
      var d = task.dueDate;
      var guard = 0;
      while (DateTime(d.year, d.month, d.day).isBefore(_todayDay) &&
          guard++ < 600) {
        final next = task.nextOccurrence(d);
        if (!next.isAfter(d)) break;
        d = next;
      }
      task.dueDate = d;
    }
    task
      ..status = TaskStatus.open
      ..statusChangedAt = null;
    notifyListeners();
  }

  /// §8 — delete: archive the series (reversible until the Archive is cleared).
  /// Its Ledger entries are never touched. The prior status is remembered so
  /// Undo can restore `open` or `paused` (§9).
  void deleteTask(Task task) {
    _taskPriorStatus[task.id] = task.status;
    task
      ..status = TaskStatus.deleted
      ..statusChangedAt = today;
    notifyListeners();
  }

  /// §9 — Archive > Undo on a deleted task: restore the status it had before.
  void undoDeleteTask(Task task) {
    final prior = _taskPriorStatus.remove(task.id) ?? TaskStatus.open;
    task
      ..status = prior
      ..statusChangedAt = prior == TaskStatus.paused ? today : null;
    notifyListeners();
  }

  /// Hard-removes a task record. Still used by Quick Add when an edited
  /// transaction's recurrence link is rewritten (the old generating task is
  /// replaced, not archived). The Schedule UI never calls this — it uses
  /// [deleteTask] (archive) instead.
  void deleteTaskSeries(Task task) {
    _tasks.removeWhere((t) => t.id == task.id);
    _taskPriorStatus.remove(task.id);
    notifyListeners();
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
