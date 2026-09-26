import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/balance/balance_filter.dart';
import '../../features/balance/balance_order.dart';
import '../../features/balance/same_transactions.dart';
import '../../features/ledger/trans_filter.dart';
import '../utils/clock.dart';
import '../utils/date_range.dart';
import '../models/forecast.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/fx.dart';
import '../utils/uuid.dart';

/// Single source of truth for the whole app (spec 6.1/6.2).
///
/// Balances are never stored — they are always derived from
/// `startingBalance + Σ transactions`, which is what makes the "starting
/// balance is locked" rule (spec 6.2) enforceable rather than decorative.
class AppStore extends ChangeNotifier {
  AppStore({
    Clock clock = Clock.system,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Txn> txns,
    required List<Goal> goals,
    required List<Task> tasks,
    List<Budget> budgets = const [],
    List<Tag> tags = const [],
    List<CurrencyDef> customCurrencies = const [],
    DateTime? budgetHistorySince,
    int? idSeq,
    int? tagSchema,
    String? baseCurrency,
    Map<String, double>? rates,
    Map<String, DateTime>? rateSetAt,
    List<BaseCurrencyChange>? baseCurrencyChanges,
  })  : _clock = clock,
        _baseCurrencyChanges = List.of(baseCurrencyChanges ?? const []),
        _accounts = List.of(accounts),
        _categories = List.of(categories),
        _txns = List.of(txns),
        _goals = List.of(goals),
        _tasks = List.of(tasks),
        _budgets = List.of(budgets),
        _tags = List.of(tags),
        _customCurrencies = List.of(customCurrencies),
        // Budget-detail CHANGES records forward-only: the day this store first
        // ran with the feature. A persistence layer would pass its stored value
        // so the footnote never moves; absent one (this app resets every launch),
        // it resolves to `today` for both a migrated and a fresh store. Never
        // AppStore.today at render, which would drift daily. Existing budgets are
        // NOT backfilled — history begins empty and fills from the first edit.
        budgetHistorySince = budgetHistorySince ?? _dayOf(clock) {
    // Derived period controls that used to read the pinned constant in a field
    // initializer. They can only be set once the clock is available (an instance
    // getter is unreachable from an initializer list), so they land here at the
    // top of the body: the Ledger's month and the Schedule completed range both
    // open on the period containing the real today (spec §3).
    _period = DateTime(today.year, today.month);
    _completedRange = RangePreset.thisMonth.resolve(today);
    // Persistence seam: restore the id counter (so hydrated ids never collide
    // with freshly minted ones) and the tag schema (so already-reified tag ids
    // are never re-migrated). Both no-op on the seed path where they are null.
    if (idSeq != null) _idSeq = idSeq;
    if (tagSchema != null) _tagSchema = tagSchema;
    // The display base currency (spec §12). Restored here for a backup that
    // carries it; a backup written before this change passes null, and the
    // derive-from-oldest fallback runs in [loadFrom] when this store is adopted.
    _baseCurrency = baseCurrency;
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
    // Seed the exchange-rate table so a fresh store is never in the missing-rate
    // state (spec 021a §5). A no-op once rates exist; [loadRates] later replaces
    // the seed with the user's persisted values.
    if (rates != null && rates.isNotEmpty) {
      _rates.addAll(rates);
      if (rateSetAt != null) _rateSetAt.addAll(rateSetAt);
    }
    _seedRatesIfEmpty();
    _backfillFrozenRates();
  }

  /// Normalises any transaction that predates per-entry freezing (spec 021b) —
  /// the seed fixture, and rows restored from a pre-v8 database or backup, whose
  /// missing `rate_to_base` defaulted to 1 and so mis-froze a foreign entry as
  /// if it were in the reporting currency. For a foreign entry left at rate 1 we
  /// freeze it at the currency's current rate and recompute its base value. A
  /// genuine post-021b entry carries its real (non-1) rate and is untouched; an
  /// entry already in the reporting currency is correct at rate 1 and skipped.
  void _backfillFrozenRates() {
    final base = baseCurrency;
    for (final t in _txns) {
      if (t.currency == base) continue;
      if (t.rateToBase != 1.0) continue;
      final r = rateFor(t.currency);
      if (r == null || r == 1.0) continue;
      t.rateToBase = r;
      t.amountBase = roundToCurrency(t.amount / r, base);
    }
  }

  /// An empty store — the first-run state before anything has been persisted.
  /// `main()` uses this when the local database is still empty (spec: fresh
  /// installs start blank, not seeded with demo data).
  factory AppStore.empty({Clock clock = Clock.system}) => AppStore(
        clock: clock,
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  /// The app's injected clock. Production reads the real time; tests pin it with
  /// [Clock.fixed]. This is the only clock in the app (spec §1).
  final Clock _clock;

  /// Midnight of a clock's current day — the same computation as [today], but
  /// static so it can seed [budgetHistorySince] from an initializer list, where
  /// the instance getter is unreachable.
  static DateTime _dayOf(Clock clock) {
    final n = clock.now();
    return DateTime(n.year, n.month, n.day);
  }

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

  /// Budgets are their own objects now (budgets-as-object spec §A), no longer
  /// three fields on a [Category]. Migrated from the legacy per-category columns
  /// at the persistence seam; the seed authors them directly.
  final List<Budget> _budgets;
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

  // The counter survives only to round-trip old backups' `id_seq` meta; new ids
  // are UUID-suffixed so records minted on different devices can never collide
  // once group sync merges them.
  int _idSeq = 1000;
  String _nextId(String prefix) => '${prefix}_${uuidV4()}';

  // ── Persistence seam ──────────────────────────────────────────────────────
  // Raw, unfiltered views of the canonical collections for the snapshot writer.
  // The public getters (`accounts`, `categories`, `goals`, `tasks`, …) are all
  // filtered — archived/status-scoped — so a backup that used them would silently
  // drop rows. A round-trippable snapshot reads the private lists directly.
  List<Account> get snapshotAccounts => List.unmodifiable(_accounts);
  List<Category> get snapshotCategories => List.unmodifiable(_categories);
  List<Budget> get snapshotBudgets => List.unmodifiable(_budgets);
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
  // One clock, injected. Production reads the real time; tests and the demo
  // fixtures pin it with [Clock.fixed]. There is no wall-clock read outside the
  // system clock — a second reading is how Schedule drifted out of sync with
  // Balance while both believed they agreed (spec §1).

  /// Midnight of the current day.
  ///
  /// It used to be a timestamp (`14:32`), which made every day-comparison depend
  /// on what time the app happened to be opened. Date arithmetic across this app
  /// compares *days*; give it days. Keeps its name so its readers do not change.
  DateTime get today {
    final n = _clock.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// The actual instant. Use this only where the time of day is part of the fact
  /// being recorded — a record's `createdAt`, never a comparison.
  DateTime get now => _clock.now();

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

  // ── Base currency (spec §12 — every total is shown in this one currency) ────
  // The currency every *aggregate* (net worth, group totals, Spendable, ledger
  // scopes, Insight, goal metrics) is converted to and displayed in. It replaces
  // the old `baseCurrency = 'USD'` compile-time constant: nobody chose USD,
  // it was simply what the constant said. Now it is a stored setting, seeded
  // silently from the first account's currency and changeable only in
  // More ▸ Preferences.
  //
  // Stored via SharedPreferences (alongside [_localeKey]), NOT the SQLite
  // snapshot — like the locale, it is device-preference state. The backup file
  // carries its own copy in `meta` (see backup_codec).
  static const _baseCurrencyKey = 'base_currency';

  /// The persisted base, or null when none has ever been written (no account
  /// has ever existed). Never re-derived on account deletion/edit once set — a
  /// silent setting must not silently move the biggest number on the home
  /// screen.
  String? _baseCurrency;

  /// The currency ISO code the device locale suggests, resolved once at load.
  /// Used only as the last-resort seed when there is no stored base and no
  /// account yet (so the new-account form offers TMT on a Turkmen device).
  String? _deviceLocaleCurrency;

  /// Every reporting-currency switch, oldest first (spec 021e §5). Persisted
  /// alongside the base currency and carried in the backup `meta`.
  static const _baseChangesKey = 'base_currency_changes';
  final List<BaseCurrencyChange> _baseCurrencyChanges;
  List<BaseCurrencyChange> get snapshotBaseCurrencyChanges =>
      List.unmodifiable(_baseCurrencyChanges);

  /// The most recent reporting-currency switch, or null — the Currencies
  /// screen's `REPORTING` subtitle (spec 021e §4b).
  BaseCurrencyChange? get lastBaseCurrencyChange =>
      _baseCurrencyChanges.isEmpty ? null : _baseCurrencyChanges.last;

  /// The base currency every total is displayed in — the resolved value, never
  /// null. Reads live so a change in Preferences repaints every aggregate
  /// without an app restart (nothing caches it).
  String get baseCurrency {
    final resolved =
        resolveBaseCurrency(_baseCurrency, _accounts, _deviceLocaleCurrency);
    // Mirror the resolved base into the money formatters so a bare `money(x)`
    // (no currency argument) renders in the base rather than a hard-coded
    // dollar. This getter is read live by every aggregate on every rebuild, so
    // it is the natural single point to keep the formatter default current —
    // including after a Preferences change, a sync/group hydration, or the
    // first account seeding the base.
    setFormatterBaseCurrency(resolved);
    return resolved;
  }

  /// The user's explicit choice (More ▸ Preferences), now a **migration** rather
  /// than an assignment (spec 021e §2). Every stored base value is anchored to
  /// the reporting currency in force when it was entered, so flipping the setting
  /// must re-express the whole history through one [factor] — how many units of
  /// [code] one unit of the old base buys — chosen at the moment of the switch:
  ///
  ///   - `Txn.amountBase` × factor, re-rounded to [code]'s decimals;
  ///   - `Txn.rateToBase` ÷ factor;
  ///   - every rate ÷ factor; the old base joins the table at `1/factor`; the new
  ///     base leaves it (the base is never in the map);
  ///   - budgets and goals are **untouched** — they are explicit promises, not
  ///     reporting artefacts.
  ///
  /// [factor] defaults to the target's stored rate; a caller (the confirm sheet)
  /// may override it. The switch is refused when no positive factor is available.
  void setBaseCurrency(String code, {double? factor}) {
    if (code.isEmpty) return;
    final old = baseCurrency;
    if (code == old) return;
    final f = factor ?? rateFor(code);
    if (f == null || f <= 0) return;

    for (final t in _txns) {
      t.amountBase = roundToCurrency(t.amountBase * f, code);
      t.rateToBase = t.rateToBase / f;
    }
    final migrated = <String, double>{};
    _rates.forEach((c, r) => migrated[c] = r / f);
    migrated[old] = 1 / f; // the old base is a foreign currency now
    migrated.remove(code); // the new base leaves the map
    _rates
      ..clear()
      ..addAll(migrated);
    final at = _dayOf(_clock);
    _rateSetAt[old] = at;
    _rateSetAt.remove(code);

    _baseCurrencyChanges
        .add(BaseCurrencyChange(from: old, to: code, factor: f, at: at));
    _baseCurrency = code;
    notifyListeners();
    unawaited(_saveBaseCurrency(code));
    unawaited(_saveRates());
    unawaited(_saveBaseChanges());
  }

  /// Pure, parameterised resolver — the base-currency analogue of
  /// [resolveInitialLocale], unit-testable without SharedPreferences or a
  /// platform. Precedence (spec §1/§7): a stored value wins; else the oldest
  /// account's currency (the upgrade repair); else the device locale's currency;
  /// else USD.
  static String resolveBaseCurrency(
    String? stored,
    List<Account> accounts,
    String? deviceLocaleCurrency,
  ) {
    if (stored != null && stored.isNotEmpty) return stored;
    final oldest = oldestAccountCurrency(accounts);
    if (oldest != null) return oldest;
    if (deviceLocaleCurrency != null && deviceLocaleCurrency.isNotEmpty) {
      return deviceLocaleCurrency;
    }
    return 'USD';
  }

  /// The currency of the oldest account (earliest [Account.openedOn]; accounts
  /// with no recorded open date predate the field and so sort oldest, with list
  /// insertion order breaking ties). Null when there are no accounts. This is
  /// what repairs an existing install's `$143` without asking anyone.
  static String? oldestAccountCurrency(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    DateTime key(Account a) =>
        a.openedOn ?? DateTime.fromMillisecondsSinceEpoch(0);
    var oldest = accounts.first;
    for (final a in accounts.skip(1)) {
      if (key(a).isBefore(key(oldest))) oldest = a;
    }
    return oldest.currency;
  }

  /// The ISO currency code the device [locale] implies, via `intl`'s
  /// locale→currency mapping, or null when it yields nothing or a code the
  /// catalog does not know (spec §2b). `intl` carries no data for some locales
  /// (Turkmen among them), so the lookup is guarded.
  static String? currencyForLocale(Locale locale) {
    try {
      final name =
          NumberFormat.simpleCurrency(locale: locale.toString()).currencyName;
      if (name != null && name.isNotEmpty && currencyCodeExists(name)) {
        return name;
      }
    } catch (_) {
      // Unsupported locale — fall through to null (caller defaults to USD).
    }
    return null;
  }

  /// Restores the base currency before the first frame (called from `main`), so
  /// no screen paints a `$143` and then corrects itself. Derives-and-pins for an
  /// existing install that has no stored value yet (the upgrade path).
  Future<void> loadBaseCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceLocaleCurrency =
        currencyForLocale(WidgetsBinding.instance.platformDispatcher.locale);
    final stored = prefs.getString(_baseCurrencyKey);
    if (stored != null && stored.isNotEmpty) {
      _baseCurrency = stored;
    } else if (_accounts.isNotEmpty) {
      // Upgrade: derive once from the oldest account and pin it, so the figure
      // is repaired and deleting that account can never move the base.
      _baseCurrency = oldestAccountCurrency(_accounts);
      if (_baseCurrency != null) {
        unawaited(_saveBaseCurrency(_baseCurrency!));
      }
    }
    // No accounts and nothing stored: leave null — there is nothing to total, so
    // no base is needed. The new-account form seeds from the device locale.
  }

  // ── Exchange rates (spec 021a — rates are data the user owns) ───────────────
  // How many units of a currency one unit of [baseCurrency] buys — the direction
  // rates are quoted out loud ("the dollar is 40 lira"). The base is never in the
  // map; its rate is 1 by definition. A code that is absent has **no rate** —
  // that is a state, not a zero, and every total that needs it goes quiet rather
  // than converting at a fabricated 1.0 (§2).
  //
  // Persisted the same way [baseCurrency] is — a SharedPreferences JSON blob,
  // NOT the SQLite snapshot — and carried in the backup `meta`. Seeded on first
  // run from [Fx.seedRates] so a fresh store is never in the missing-rate state.
  static const _ratesKey = 'fx_rates';
  final Map<String, double> _rates = {};
  final Map<String, DateTime> _rateSetAt = {};

  /// The whole rate table, code → units-per-base. The base is absent (rate 1).
  Map<String, double> get snapshotRates => Map.unmodifiable(_rates);
  Map<String, DateTime> get snapshotRateSetAt => Map.unmodifiable(_rateSetAt);

  /// Units of [code] per one unit of [baseCurrency]: `1.0` for the base itself,
  /// the stored value for a known code, and **null** when the code has no rate
  /// (the caller must decide what to show — §2).
  double? rateFor(String code) =>
      code == baseCurrency ? 1.0 : _rates[code];

  /// When [code]'s rate was last written, or null. The base has no stored date.
  DateTime? rateSetAt(String code) => _rateSetAt[code];

  /// Sets [code]'s rate against the reporting currency, stamping today. Refuses
  /// `<= 0` at the store, not only in the UI (§1a): a zero rate silently zeroes
  /// an account's whole balance. The base is `1` by definition and is never
  /// stored. Notifies so every silenced total returns immediately.
  void setRate(String code, double rate) {
    if (rate <= 0) return;
    if (code == baseCurrency) return;
    _rates[code] = rate;
    _rateSetAt[code] = _dayOf(_clock);
    notifyListeners();
    unawaited(_saveRates());
  }

  /// Seeds the rate table from [Fx.seedRates] when it is empty (first run — §5),
  /// stamped with the seed date, so the demo data and any test fixture start with
  /// every used currency rated and never meet the missing-rate warning.
  void _seedRatesIfEmpty() {
    if (_rates.isNotEmpty) return;
    final at = _dayOf(_clock);
    Fx.seedRates(baseCurrency).forEach((code, r) {
      _rates[code] = r;
      _rateSetAt[code] = at;
    });
  }

  /// base-currency conversion for the store's own aggregates: convert [amount]
  /// from [currency] into the current [baseCurrency], reading the live rate
  /// table. **Null when [currency] has no rate** — the caller must decide what to
  /// show, and `?? 1.0` is exactly the bug 021a removes. Public mirror
  /// [convertToBase] lets per-row displays and screens reach the same maths.
  double? _toBase(double amount, String currency) =>
      Fx.convertWith(amount, rateFor(currency), rateFor(baseCurrency));

  /// Public form of [_toBase] for screens and per-row displays.
  double? convertToBase(double amount, String currency) =>
      _toBase(amount, currency);

  /// Convert [amount] from one arbitrary currency to another through the live
  /// rate table. Null when either currency has no rate.
  double? convertBetween(double amount, String from, String to) =>
      Fx.convertWith(amount, rateFor(from), rateFor(to));

  /// [_toBase] with a native fallback for **intermediates** (§2d) — a conversion
  /// used only to sort, weight, or partition, where a missing rate must degrade
  /// (the row keeps its native magnitude) rather than crash or silence a headline
  /// total. Never use this where the figure is shown to the user as a base total.
  double _toBaseOr(double amount, String currency) =>
      _toBase(amount, currency) ?? amount;

  /// Codes referenced by an account or transaction (i.e. that a total needs) that
  /// have no rate — what §4b's warning card names. Empty for a fully-rated store.
  List<String> missingRateCodes() {
    final out = <String>[];
    for (final code in currencyCodesInUse()) {
      if (rateFor(code) == null) out.add(code);
    }
    return out;
  }

  /// Whether any in-use currency lacks a rate — the cheap guard a screen checks
  /// before deciding to show a total or the warning.
  bool get hasMissingRate => missingRateCodes().isNotEmpty;

  /// Convert a reporting-currency figure into [currency] at **today's** rate —
  /// the inverse of [_toBase], for the budget-currency spend fold (021d §1b) and
  /// the reporting-currency switch (021e). Null when [currency] has no rate.
  double? convertFromBase(double baseAmount, String currency) =>
      Fx.convertWith(baseAmount, rateFor(baseCurrency), rateFor(currency));

  /// The reporting currency at which the marker source of a proposed rate is
  /// resolved (spec 021b §3a). Where the proposal came from, for the rate row's
  /// history/manual marker.
  RateProposal rateProposal(String currency, DateTime date) {
    if (currency == baseCurrency) {
      return const RateProposal(rate: 1.0, source: RateProposalSource.base);
    }
    // A back-dated entry proposes the nearest earlier entry's frozen rate; an
    // entry dated today proposes the currency's current stored rate.
    if (!_sameDay(date, today)) {
      Txn? best;
      for (final t in _txns) {
        if (t.currency != currency) continue;
        if (t.date.isAfter(date)) continue;
        if (best == null || t.date.isAfter(best.date)) best = t;
      }
      if (best != null) {
        return RateProposal(
            rate: best.rateToBase,
            source: RateProposalSource.earlierEntry,
            entryDate: best.date);
      }
    }
    return RateProposal(rate: rateFor(currency), source: RateProposalSource.stored);
  }

  /// The concrete currency a budget's limit and spend are measured in (021d) —
  /// its own [Budget.currency], or the reporting currency when unset (the
  /// single-currency default and the migration value).
  String budgetCurrencyOf(Budget b) =>
      b.currency.isEmpty ? baseCurrency : b.currency;

  /// The concrete currency a goal's target and progress are measured in (021d).
  String goalCurrencyOf(Goal g) =>
      g.currency.isEmpty ? baseCurrency : g.currency;

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

  /// Best-effort persistence of the base currency. Unlike the language/toggle
  /// saves, this fires from [addAccount] and [loadFrom] — mutations exercised by
  /// unit tests that do not register a SharedPreferences mock — so a plugin-less
  /// environment must not turn the silent seed into an unhandled exception.
  static Future<void> _saveBaseCurrency(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baseCurrencyKey, code);
    } catch (_) {
      // No platform / no mock: the in-memory value still stands for this run.
    }
  }

  /// Best-effort persistence of the rate table (spec 021a §1a). Mirrors
  /// [_saveBaseCurrency]: a plugin-less test environment must not throw. Stored
  /// as one JSON blob `{code: {r, t}}` under [_ratesKey].
  Future<void> _saveRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blob = <String, Object?>{
        for (final entry in _rates.entries)
          entry.key: {
            'r': entry.value,
            't': _rateSetAt[entry.key]?.millisecondsSinceEpoch,
          },
      };
      await prefs.setString(_ratesKey, jsonEncode(blob));
    } catch (_) {
      // No platform / no mock: the in-memory table still stands for this run.
    }
  }

  /// Best-effort persistence of the reporting-currency change log (spec 021e §5).
  Future<void> _saveBaseChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baseChangesKey,
          jsonEncode(_baseCurrencyChanges.map((c) => c.toJson()).toList()));
    } catch (_) {
      // No platform / no mock: the in-memory log still stands for this run.
    }
  }

  /// Restores the rate table and reporting-currency change log before the first
  /// frame (called from `main`), replacing the constructor's seed with the
  /// user's persisted values. When nothing is stored the seed is persisted so
  /// later launches are stable.
  Future<void> loadRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_ratesKey);
      if (stored != null && stored.isNotEmpty) {
        final decoded = jsonDecode(stored);
        if (decoded is Map) {
          _rates.clear();
          _rateSetAt.clear();
          decoded.forEach((code, v) {
            if (v is Map && v['r'] is num) {
              _rates[code as String] = (v['r'] as num).toDouble();
              final t = v['t'];
              if (t is num) {
                _rateSetAt[code] =
                    DateTime.fromMillisecondsSinceEpoch(t.toInt());
              }
            }
          });
        }
      } else {
        // Nothing stored yet (fresh install or upgrade): keep the constructor's
        // seed and persist it so it is stable across launches.
        unawaited(_saveRates());
      }
      final changes = prefs.getString(_baseChangesKey);
      if (changes != null && changes.isNotEmpty) {
        final decoded = jsonDecode(changes);
        if (decoded is List) {
          _baseCurrencyChanges
            ..clear()
            ..addAll(decoded
                .whereType<Map>()
                .map((m) => BaseCurrencyChange.fromJson(m.cast<String, dynamic>())));
        }
      }
    } catch (_) {
      // Unreadable prefs: the seeded table stands.
    }
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
  late DateRange _completedRange; // set in the constructor body from `today`
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
      currentPresetFor(_insightPeriodUnit).resolve(today);

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

  /// Month currently in focus for Ledger + Planner headers. Set in the
  /// constructor body to the month containing the real today (spec §3).
  late DateTime _period;
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

  /// When an account starts existing for reporting. The opening receipt's date
  /// is the one the user can actually set — [Account.openedOn] only ever records
  /// the day the row was created, which is not a claim about the money (task 025
  /// §2). Null when neither field is set, meaning "always" (seed accounts
  /// predate both).
  DateTime? existsFrom(Account a) => a.openingDate ?? a.openedOn;

  /// An account that did not exist yet on the reporting date must not appear.
  bool _openedAfterCutoff(Account a) {
    final from = existsFrom(a);
    return from != null && from.isAfter(_cutoff);
  }

  /// The earliest date any account began existing, across the whole non-archived
  /// book — deliberately including accounts the reporting cutoff currently hides,
  /// so the historical-empty pane can name the date that ends the emptiness (task
  /// 025 §1.1). Reads the PRIVATE list because [accounts] is already cutoff-
  /// filtered. Null when no non-archived account carries a date.
  DateTime? get earliestAccountOpening {
    DateTime? earliest;
    for (final a in _accounts) {
      if (a.archived) continue;
      final from = existsFrom(a);
      if (from == null) continue;
      if (earliest == null || from.isBefore(earliest)) earliest = from;
    }
    return earliest;
  }

  /// Hidden accounts stay in the totals but leave the lists (spec 1.5).
  List<Account> get visibleAccounts =>
      accounts.where((a) => !a.hidden).toList(growable: false);

  /// Archived accounts — read from the PRIVATE list on purpose: [accounts]
  /// filters `archived` out, so the Archive screen is the only place these
  /// resolve. Restoring one returns it to every list, picker and total.
  List<Account> get archivedAccounts =>
      _accounts.where((a) => a.archived).toList(growable: false);

  /// Every account the More ▸ Accounts screen manages — non-archived, and
  /// deliberately independent of the reporting cutoff [accounts] applies: that
  /// screen is a setup surface, not a report, so an account opened after the
  /// current `asOf` is still one whose name and type you can edit. Preserves the
  /// private list's insertion order (the app's existing account order); the
  /// screen adds no sort. Mirrors [archivedAccounts], which also reads the
  /// private list.
  List<Account> get manageableAccounts =>
      _accounts.where((a) => !a.archived).toList(growable: false);

  /// Non-archived account count — the More ▸ Accounts cell (§1.2). Cutoff-
  /// independent, so it always equals the length of the list the Accounts
  /// screen renders, and never double-counts the archived ones the Archive row
  /// already carries.
  int get activeAccountCount => manageableAccounts.length;

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

  /// Categories claimed by an active monthly category budget — Planner > Budgets
  /// reads exactly this. Budgets are their own objects now
  /// (budgets-as-object spec §A); this preserves the old surface by resolving
  /// each category to its monthly budget.
  List<Category> get budgetedCategories => categories
      .where((c) => monthlyBudgetForCategory(c.id) != null)
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

  /// Archived (soft-deleted) tasks — the legacy Recently-deleted group,
  /// reversible until the Archive is cleared. No UI produces this status any
  /// more (task 065 §1c); it lingers only for existing rows and Undo.
  List<Task> get deletedTasks => _tasks
      .where((t) => t.status == TaskStatus.deleted)
      .toList(growable: false);

  /// Archived series — ended and kept (task 065 §1). Newest first by the date
  /// they were archived. Their Ledger entries are never touched; a Restore
  /// (§1b) resumes them at the first occurrence at or after today.
  List<Task> get archivedTasks {
    final list = _tasks
        .where((t) => t.status == TaskStatus.archived)
        .toList(growable: false);
    list.sort((a, b) => (b.statusChangedAt ?? b.dueDate)
        .compareTo(a.statusChangedAt ?? a.dueDate));
    return list;
  }

  /// Categories whose monthly budget is archived and has no active replacement —
  /// the Archive's `REMOVED BUDGETS` section. A migrated `removedOn` becomes the
  /// budget's `archivedAt`, so this reads the same rows as before.
  List<Category> get removedBudgets => _budgets
      .where((b) =>
          _isMonthlyCategoryBudget(b) &&
          b.isArchived &&
          b.targets.length == 1 &&
          monthlyBudgetForCategory(b.targets.first) == null)
      .map((b) => categoryById(b.targets.first))
      .whereType<Category>()
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
    final now = this.now;
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
  /// across accounts (spec 3.4 FX rule). **Null when the account's currency has
  /// no rate** (021a §2a): a balance that cannot be converted is not a zero.
  double? balanceInBase(String accountId) => _toBase(
        balanceOf(accountId),
        accountById(accountId)?.currency ?? baseCurrency,
      );

  /// [balanceInBase] with a native fallback (§2d) — for the filter sheet's
  /// secondary per-group totals, which degrade rather than silence the way the
  /// headline Balance totals do.
  double balanceInBaseOr(String accountId) => _toBaseOr(
        balanceOf(accountId),
        accountById(accountId)?.currency ?? baseCurrency,
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
  /// account source. Null when the account's currency has no rate.
  double? balanceOnInBase(String accountId, DateTime date) => _toBase(
        balanceOn(accountId, date),
        accountById(accountId)?.currency ?? baseCurrency,
      );

  /// The group's total, in the reporting currency. **Null when any account in
  /// it has no rate** (021a §2a) — a total with a piece missing is not the
  /// total, and skipping the unrated ones is the same lie in a smaller number.
  double? groupTotal(AccountGroup group) {
    var sum = 0.0;
    for (final a in accounts.where((a) => a.group == group)) {
      final b = balanceInBase(a.id);
      if (b == null) return null;
      sum += b;
    }
    return sum;
  }

  int groupCount(AccountGroup group) =>
      accounts.where((a) => a.group == group).length;

  List<Account> accountsIn(AccountGroup group) =>
      visibleAccounts.where((a) => a.group == group).toList(growable: false);

  /// Null when any asset account has no rate (021a §2a).
  double? get totalAssets {
    var sum = 0.0;
    for (final g in AccountGroup.assets) {
      final t = groupTotal(g);
      if (t == null) return null;
      sum += t;
    }
    return sum;
  }

  /// Positive magnitude of what is owed. Null when any liability account has no
  /// rate.
  double? get totalLiabilities {
    var sum = 0.0;
    for (final g in AccountGroup.liabilities) {
      final t = groupTotal(g);
      if (t == null) return null;
      sum += t;
    }
    return sum.abs();
  }

  double? get netWorth {
    final a = totalAssets;
    final l = totalLiabilities;
    if (a == null || l == null) return null;
    return a - l;
  }

  /// Spendable cash — the green highlight card on Balance (spec 1.1).
  ///
  /// NOTE: currently has no callers. [AccountGroup.setAside] now expresses the
  /// same "earmarked cash is not spendable" intent structurally (its own group,
  /// excluded from Spendable by group membership rather than a per-account
  /// flag), so both this getter and [Account.countAsSpendable] are candidates
  /// for removal once nothing depends on them. Left in place here — deleting a
  /// public getter and a model field is a larger change than the group warrants
  /// and wants its own decision.
  double? get spendable {
    var sum = 0.0;
    for (final a in accounts.where(
        (a) => a.group == AccountGroup.spendable && a.countAsSpendable)) {
      final b = balanceInBase(a.id);
      if (b == null) return null;
      sum += b;
    }
    return sum;
  }

  /// Liabilities as a share of assets — drives the red segment of the bar. A
  /// missing rate degrades this ratio to 0 (§2d, an intermediate): the headline
  /// totals beside it already carry the warning.
  double get liabilityRatio {
    final a = totalAssets;
    final l = totalLiabilities;
    if (a == null || l == null || a <= 0) return 0;
    return (l / a).clamp(0.0, 1.0);
  }

  /// Share of total assets held by [group] — the "6.7%" under each row. Degrades
  /// to 0 when a rate is missing (§2d).
  double groupShare(AccountGroup group) {
    final base = group.isAsset ? totalAssets : totalLiabilities;
    final gt = groupTotal(group);
    if (base == null || gt == null || base <= 0) return 0;
    return (gt.abs() / base).clamp(0.0, 1.0);
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
        activity += _toBaseOr(_effectOn(t, a.id), a.currency).abs();
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
      activity += _toBaseOr(_effectOn(t, accountId), account.currency).abs();
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
        delta += _toBaseOr(_effectOn(t, a.id), a.currency);
      }
    }
    return delta;
  }

  double get netWorthDeltaFraction {
    final nw = netWorth;
    if (nw == null) return 0;
    final previous = nw - netWorthDelta;
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
  /// Sums each entry's **frozen** base value (spec 021b §2): what a foreign row
  /// was worth is decided once, at entry, so correcting a rate today never
  /// rewrites a past month. Always computable (`amountBase` is never null), so
  /// unlike the balance side this figure never goes quiet.
  /// Delegates to the windowed twin so the fold lives once.
  double monthIncome(DateTime month) =>
      incomeInWindow(DateRange(_monthStart(month), _monthEnd(month)));

  double monthExpense(DateTime month) =>
      expenseInWindow(DateRange(_monthStart(month), _monthEnd(month)));

  /// Range-lens twins of [monthIncome]/[monthExpense] — same fold, windowed, and
  /// **frozen** (spec 021b §2). Aliased by [inflowInWindow]/[outflowInWindow],
  /// the names Insight reads.
  double incomeInWindow(DateRange window, {Set<String>? visible}) =>
      txnsInWindow(window)
          .where((t) =>
              t.type == TxnType.income &&
              (visible == null || visible.contains(t.toRef)))
          .fold(0.0, (sum, t) => sum + t.amountBase);

  double expenseInWindow(DateRange window, {Set<String>? visible}) =>
      txnsInWindow(window)
          .where((t) =>
              t.type == TxnType.expense &&
              (visible == null || visible.contains(t.fromRef)))
          .fold(0.0, (sum, t) => sum + t.amountBase);

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

  // ── Budgets (budgets-as-object spec §A) ────────────────────────────────────
  // Budgets are their own objects. The window and spend live here so every
  // screen shares one definition; nothing derived is ever stored.

  /// Every budget, live and archived — the tab and the Archive read from this.
  List<Budget> get budgets => List.unmodifiable(_budgets);

  Budget? budgetById(String? id) {
    if (id == null) return null;
    for (final b in _budgets) {
      if (b.id == id) return b;
    }
    return null;
  }

  bool _isMonthlyCategoryBudget(Budget b) =>
      b.scope == BudgetScope.categories &&
      b.period == BudgetPeriod.month &&
      b.repeats;

  /// The single active (not archived, not finished) monthly **category** budget
  /// claiming [categoryId], or null. Migration is 1:1, so this is unambiguous;
  /// it is the seam the old `Category.monthlyBudget` field is read through.
  Budget? monthlyBudgetForCategory(String categoryId) {
    for (final b in _budgets) {
      if (_isMonthlyCategoryBudget(b) &&
          !b.isArchived &&
          !b.isFinished &&
          b.targets.contains(categoryId)) {
        return b;
      }
    }
    return null;
  }

  /// The monthly category budget claiming [categoryId] whether active or
  /// archived — for reading history / removal date of a removed budget.
  Budget? _anyMonthlyBudgetForCategory(String categoryId) {
    for (final b in _budgets) {
      if (_isMonthlyCategoryBudget(b) && b.targets.contains(categoryId)) {
        return b;
      }
    }
    return null;
  }

  /// A one-off whose end has passed. Its `endedAt` is set at creation (it is the
  /// window's close), so [Budget.isFinished] is true from birth; "finished" in
  /// the everyday sense — done, dimmed on the tab — is this: the end is in the
  /// past. A repeating budget is never past.
  bool _isPastOnce(Budget b) =>
      !b.repeats && b.endedAt != null && today.isAfter(b.endedAt!);

  /// Still running today: not archived, and not a finished one-off (spec §4a).
  /// This is the "is it live?" test the budgeted/hero seams ask.
  bool _isRunning(Budget b) => !b.isArchived && !_isPastOnce(b);

  /// When a budget was created — the first history entry ('created'), falling
  /// back to the anchor for a budget that predates history. The tiebreaker for
  /// "the most recently created" in [primaryBudgetForCategory].
  DateTime _budgetCreatedAt(Budget b) =>
      b.history.isNotEmpty ? b.history.first.at : b.anchor;

  /// The first day of [b]'s first period when the user set it to start after the
  /// period it was created in (task 067.1 §2a); null for every retroactive
  /// budget (the default — a budget created in September also measures August).
  /// Covers Runs · From a future month and a one-off whose dates are ahead.
  DateTime? budgetStartsLater(Budget b) {
    final first = budgetWindow(b, b.anchor).start;
    final created = budgetWindow(b, _budgetCreatedAt(b)).start;
    return first.isAfter(created) ? first : null;
  }

  /// Whether [b] is measured in [window] (task 067.1 §2b): not before it starts,
  /// not after it ends.
  bool budgetRunsIn(Budget b, DateRange window) {
    final start = budgetStartsLater(b);
    if (start != null && window.end.isBefore(start)) return false;
    if (b.runsUntil != null && window.start.isAfter(b.runsUntil!)) return false;
    return true;
  }

  /// Every active category-scope budget that lists [categoryId] — **any** period,
  /// repeating or one-off (spec §4a). A category is "budgeted" exactly when this
  /// is non-empty; that is the test the unbudgeted seams now ask, replacing
  /// "has a monthly budget". Callers that must name one budget use
  /// [primaryBudgetForCategory].
  List<Budget> budgetsForCategory(String categoryId) => _budgets
      .where((b) =>
          b.scope == BudgetScope.categories &&
          _isRunning(b) &&
          b.targets.contains(categoryId))
      .toList(growable: false);

  /// The one budget to show beside a category when only one fits — Insight's
  /// row, Quick Add's candidate list, the category screens (spec §4b). A category
  /// may sit in several lenses; this picks the one that is most about *it*:
  ///   1. active category-scope budgets containing [categoryId];
  ///   2. prefer a budget whose only target is this category;
  ///   3. then the shorter period (a week is more specific than a month);
  ///   4. then the most recently created.
  /// Callers that can show several use [budgetsForCategory] instead.
  Budget? primaryBudgetForCategory(String categoryId) {
    final claims = budgetsForCategory(categoryId);
    if (claims.isEmpty) return null;
    int span(Budget b) =>
        b.period == BudgetPeriod.month ? 30 : (b.lengthDays ?? 30);
    claims.sort((a, b) {
      // 1/2 — a single-target lens is more "about" this category than a shared one.
      final byTargets = (a.targets.length == 1 ? 0 : 1)
          .compareTo(b.targets.length == 1 ? 0 : 1);
      if (byTargets != 0) return byTargets;
      // 3 — the shorter period is the more specific one.
      final bySpan = span(a).compareTo(span(b));
      if (bySpan != 0) return bySpan;
      // 4 — newest first.
      return _budgetCreatedAt(b).compareTo(_budgetCreatedAt(a));
    });
    return claims.first;
  }

  /// Every active budget whose window contains [t] and whose scope claims it —
  /// the same test the spend folds apply, so this list and the figures on the
  /// Budgets tab can never disagree (spec §6). Expenses only; empty for any other
  /// type. The COUNTED IN card reads exactly this.
  List<Budget> budgetsCounting(Txn t) {
    if (t.type != TxnType.expense) return const <Budget>[];
    return _budgets.where((b) {
      // Not archived; a finished one-off still counted its own historical rows,
      // so the window (which only spans its dates) is what scopes it, not "live".
      if (b.isArchived) return false;
      if (!_budgetClaims(b, t)) return false;
      final w = budgetWindow(b, t.date);
      return !t.date.isBefore(w.start) && !t.date.isAfter(w.end);
    }).toList(growable: false);
  }

  /// The period of [b] containing [on], or the last one if [b] has ended
  /// (spec §A.2). `month` walks whole calendar months from [Budget.anchor]'s
  /// day-of-month (so the 13th yields 13 Aug – 12 Sep and its length is read
  /// from the calendar, not fixed at 30); `days` walks fixed [Budget.lengthDays]
  /// strides from the anchor.
  DateRange budgetWindow(Budget b, DateTime on) {
    // A finished budget freezes on its last period: never advance past the end.
    // A repeating budget with an end (task 067.1 §2c) freezes the same way on
    // [Budget.runsUntil]; no period past a budget's end is ever computed.
    final end = b.endedAt ?? b.runsUntil;
    final ref = (end != null && on.isAfter(end)) ? end : on;
    if (b.period == BudgetPeriod.month) {
      return _monthWindow(b.anchor.day, ref);
    }
    return _daysWindow(b.anchor, b.lengthDays ?? 30, ref);
  }

  /// Day-of-month [anchorDay] cycle containing [on]. A short month clamps the
  /// boundary to its last day (anchor 31 → the 30th/28th) so no period is
  /// skipped.
  DateRange _monthWindow(int anchorDay, DateTime on) {
    int clamp(int y, int m) {
      final dim = DateTime(y, m + 1, 0).day;
      return anchorDay > dim ? dim : anchorDay;
    }

    var y = on.year, m = on.month;
    var start = DateTime(y, m, clamp(y, m));
    final onFloor = DateTime(on.year, on.month, on.day);
    if (start.isAfter(onFloor)) {
      m -= 1;
      if (m < 1) {
        m = 12;
        y--;
      }
      start = DateTime(y, m, clamp(y, m));
    }
    var ny = y, nm = m + 1;
    if (nm > 12) {
      nm = 1;
      ny++;
    }
    final nextStart = DateTime(ny, nm, clamp(ny, nm));
    final end = nextStart.subtract(const Duration(days: 1));
    return DateRange(start, DateTime(end.year, end.month, end.day, 23, 59, 59, 999));
  }

  /// Fixed-stride window: the [len]-day block, aligned to [anchor], containing
  /// [on].
  DateRange _daysWindow(DateTime anchor, int len, DateTime on) {
    final n = len < 1 ? 1 : len;
    final a = DateTime(anchor.year, anchor.month, anchor.day);
    final onFloor = DateTime(on.year, on.month, on.day);
    final diff = onFloor.difference(a).inDays;
    // Floor-divide toward negative infinity so a date before the anchor lands in
    // the correct earlier block.
    final idx = diff >= 0 ? diff ~/ n : -((-diff + n - 1) ~/ n);
    final start = a.add(Duration(days: idx * n));
    final end = start.add(Duration(days: n - 1));
    return DateRange(start, DateTime(end.year, end.month, end.day, 23, 59, 59, 999));
  }

  /// Spend inside a concrete [window] for [b] — categories sum each target's
  /// windowed spend; account sums windowed expense paid *from* the account. Both
  /// reuse the existing FX-correct folds; no new arithmetic (Hard boundary).
  double budgetSpendOverWindow(Budget b, DateRange window) {
    final cur = budgetCurrencyOf(b);
    var sum = 0.0;
    for (final t in _budgetRows(b, window)) {
      // Spending in the budget's own currency counts as itself — no conversion,
      // no rate, no rounding (spec 021d §1b). A ₺8,000 budget must not widen
      // because the dollar moved. For a single-currency user this is every row.
      if (t.currency == cur) {
        sum += t.amount;
        continue;
      }
      // A foreign row is worth what it was worth in the reporting currency
      // (frozen `amountBase`), re-expressed in the budget's currency at TODAY's
      // rate — a deliberate approximation (021d §1b): there is no dated rate
      // table. When the budget's currency has no rate the row cannot convert,
      // so the reporting value stands in (the card shows the §1d warning).
      sum += convertFromBase(t.amountBase, cur) ?? t.amountBase;
    }
    return sum;
  }

  /// Expense rows a budget's spend is measured over — its account's outflows, its
  /// categories' expenses, or (021d/022) its tagged expenses.
  Iterable<Txn> _budgetRows(Budget b, DateRange window) =>
      txnsInWindow(window).where((t) => _budgetClaims(b, t));

  /// Whether [b]'s scope claims [t] — the one predicate every spend fold and
  /// [budgetsCounting] share, so a budget's figures and the "counted in" card can
  /// never disagree (spec §6). Scope only; the window/active tests live at the
  /// call sites. An expense tagged with two of a tag budget's tags matches once
  /// (`any`), never twice (spec §1d).
  bool _budgetClaims(Budget b, Txn t) {
    if (t.type != TxnType.expense) return false;
    switch (b.scope) {
      case BudgetScope.account:
        return b.targets.contains(t.fromRef);
      case BudgetScope.tag:
        return t.tagIds.any(b.targets.contains);
      case BudgetScope.categories:
        return b.targets.contains(t.toRef);
    }
  }

  /// Whether [b]'s spend figure is silenced (021d §1d): its currency has no rate
  /// **and** it has at least one foreign row that therefore cannot be converted.
  /// A budget with no foreign rows computes regardless.
  bool budgetSpendSilenced(Budget b, DateRange window) {
    final cur = budgetCurrencyOf(b);
    if (rateFor(cur) != null) return false;
    return _budgetRows(b, window).any((t) => t.currency != cur);
  }

  /// Spend in the period of [b] containing [on].
  double budgetSpend(Budget b, DateTime on) =>
      budgetSpendOverWindow(b, budgetWindow(b, on));

  /// Rollover carried into the period containing [on] — from the immediately
  /// preceding period only, and only when [repeats] && [rollover] (spec §A.3). A
  /// negative carry (overspending the prior period) is clamped to zero so one
  /// month's overspend never silently shrinks the next.
  /// The **usual** limit of [b]'s period containing [on] (task 067.2 §1): the
  /// earlier value from [Budget.limitBefore] when this period predates a later
  /// change, else the current [Budget.limit]. This is the limit before any
  /// single-period override.
  double budgetUsualLimitFor(Budget b, DateTime on) {
    final ps = budgetWindow(b, on).start;
    DateTime? firstAfter;
    for (final k in b.limitBefore.keys) {
      if (k.isAfter(ps) && (firstAfter == null || k.isBefore(firstAfter))) {
        firstAfter = k;
      }
    }
    return firstAfter == null ? b.limit : b.limitBefore[firstAfter]!;
  }

  /// The limit of [b]'s period containing [on] (task 067.2 §1): its own override
  /// if one exists, else the usual limit. Rollover is added on top by
  /// [budgetEffectiveLimit], never here.
  double budgetLimitFor(Budget b, DateTime on) =>
      b.limitOverrides[budgetWindow(b, on).start] ?? budgetUsualLimitFor(b, on);

  /// Whether [b]'s period containing [on] carries its own limit (task 067.2 §1).
  /// An override is never stored equal to the usual limit (§2), so this is true
  /// exactly when the period's limit differs from the usual one.
  bool budgetLimitIsOwn(Budget b, DateTime on) =>
      b.limitOverrides.containsKey(budgetWindow(b, on).start);

  double budgetRolloverCarry(Budget b, DateTime on) {
    if (!(b.repeats && b.rollover)) return 0;
    final current = budgetWindow(b, on);
    final prevRef = current.start.subtract(const Duration(days: 1));
    // No period before the anchor to carry from.
    if (prevRef.isBefore(DateTime(b.anchor.year, b.anchor.month, b.anchor.day))) {
      return 0;
    }
    final prev = budgetWindow(b, prevRef);
    // Carry that period's own limit, not the usual one (task 067.2 §1).
    final carry = budgetLimitFor(b, prevRef) - budgetSpendOverWindow(b, prev);
    return carry > 0 ? carry : 0;
  }

  /// The limit that applies in the period containing [on] — the period's own
  /// limit (task 067.2 §1) plus any rollover carry (spec §A.3).
  double budgetEffectiveLimit(Budget b, DateTime on) =>
      budgetLimitFor(b, on) + budgetRolloverCarry(b, on);

  // ── Category ⇄ budget compatibility seams ──────────────────────────────────
  // The old code read `category.monthlyBudget` / `.effectiveLimit` /
  // `.warnThreshold` / `.budgetHistory` / `.removedOn` directly. Those fields
  // moved to [Budget]; these resolve a category to its monthly budget so the
  // screens keep rendering identically (spec §A.5).

  /// The raw monthly limit set for [c], or null when it has no active budget —
  /// the old `Category.monthlyBudget`.
  double? monthlyLimitOf(Category c) => monthlyBudgetForCategory(c.id)?.limit;

  /// The effective monthly limit for [c] (rollover included), or null — the old
  /// `Category.effectiveLimit`. Evaluated at the current [period].
  double? effectiveLimitOf(Category c) {
    final b = monthlyBudgetForCategory(c.id);
    return b == null ? null : budgetEffectiveLimit(b, _period);
  }

  /// The warn threshold for [c]'s budget, or the default — the old
  /// `Category.warnThreshold`.
  double warnThresholdOf(Category c) =>
      monthlyBudgetForCategory(c.id)?.warnThreshold ?? 0.8;

  /// Whether [c]'s budget rolls over — the old `Category.budgetRollover`.
  bool rolloverOf(Category c) => monthlyBudgetForCategory(c.id)?.rollover ?? false;

  /// [c]'s budget change log (active or removed) — the old
  /// `Category.budgetHistory`.
  List<BudgetEdit> budgetHistoryOf(Category c) =>
      _anyMonthlyBudgetForCategory(c.id)?.history ?? const <BudgetEdit>[];

  /// When [c]'s budget was removed, or null — the old `Category.removedOn`.
  DateTime? removedOnOf(Category c) {
    final b = _anyMonthlyBudgetForCategory(c.id);
    return b != null && b.isArchived ? b.archivedAt : null;
  }

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

  /// Whether [b] is summed into the month hero (spec §4c): a monthly, repeating
  /// **category** budget, still running, measured in the reporting currency. A
  /// weekly limit is not prorated into a month and a foreign-currency limit is
  /// not converted into it — either would be inventing money — so both sit
  /// outside the total and are counted by [budgetsOffMonthHero] instead.
  bool _countsInMonthHero(Budget b) =>
      _isMonthlyCategoryBudget(b) &&
      _isRunning(b) &&
      budgetCurrencyOf(b) == baseCurrency;

  /// Sum of every month-hero budget's effective limit (rollover included). No
  /// month argument because a limit is the same every month — only spend varies.
  /// Planner's headline divides against this.
  double get totalBudget => _budgets
      .where(_countsInMonthHero)
      .fold(0.0, (sum, b) => sum + budgetEffectiveLimit(b, _period));

  /// [totalBudget] for a given [month] (task 067.1 §2e): sums the month-hero
  /// budgets that actually run in it — a budget that starts later is excluded
  /// until its first period. Never tests against today.
  double totalBudgetFor(DateTime month) {
    final window = DateRange(_monthStart(month), _monthEnd(month));
    return _budgets
        .where((b) => _countsInMonthHero(b) && budgetRunsIn(b, window))
        .fold(0.0, (sum, b) => sum + budgetEffectiveLimit(b, month));
  }

  /// Active budgets the month hero does **not** sum — non-monthly, one-off, or
  /// (021d) foreign-currency (spec §4c). The hero's caption counts these as
  /// "N more run on their own clock"; a finished one-off still counts (it stays
  /// on the tab, dimmed). Archived budgets are excluded — they have left the tab.
  int get budgetsOffMonthHero =>
      _budgets.where((b) => !b.isArchived && !_countsInMonthHero(b)).length;

  /// [budgetsOffMonthHero] for a given [month] (task 067.1 §2e): the other
  /// budgets that run in the month. A budget that has not started is not counted.
  int budgetsOffMonthHeroFor(DateTime month) {
    final window = DateRange(_monthStart(month), _monthEnd(month));
    return _budgets
        .where((b) =>
            !b.isArchived &&
            !_countsInMonthHero(b) &&
            budgetRunsIn(b, window))
        .length;
  }

  /// A one-off whose end has passed — the Budgets tab's "finished" card (task
  /// 067.3 §1e / §5). It sits below the reorderable group and cannot be dragged.
  bool budgetPastEnd(Budget b) => _isPastOnce(b);

  /// The reader's order within a scope (task 067.3 §5b), independent of the
  /// month on screen: running budgets first — indexed by [Budget.sortIndex]
  /// ascending, then the unindexed ones oldest-created-first — then one-offs past
  /// their end, most recently ended first. Ties break by id so it is total.
  int _budgetOrder(Budget a, Budget b) {
    final pa = budgetPastEnd(a), pb = budgetPastEnd(b);
    if (pa != pb) return pa ? 1 : -1;
    if (pa && pb) {
      final ae = a.endedAt ?? a.anchor;
      final be = b.endedAt ?? b.anchor;
      final c = be.compareTo(ae); // most recently ended first
      return c != 0 ? c : a.id.compareTo(b.id);
    }
    final ai = a.sortIndex, bi = b.sortIndex;
    if (ai != null && bi != null) {
      final c = ai.compareTo(bi);
      return c != 0 ? c : a.id.compareTo(b.id);
    }
    if (ai != null) return -1; // indexed before unindexed
    if (bi != null) return 1;
    final c = _budgetCreatedAt(a).compareTo(_budgetCreatedAt(b)); // oldest first
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  /// Every active budget in [scope], for the Budgets tab (spec §5a), in the
  /// reader's order (task 067.3 §5b). A finished one-off stays in its section,
  /// dimmed (spec §5c); an archived one is gone.
  List<Budget> activeBudgetsByScope(BudgetScope scope, DateTime month) {
    final window = DateRange(_monthStart(month), _monthEnd(month));
    final monthStart = _monthStart(month);
    final thisMonthStart = DateTime(today.year, today.month, 1);
    final list = _budgets.where((b) {
      if (b.scope != scope || b.isArchived) return false;
      // Budgets that run in the month (task 067.1 §2d).
      if (budgetRunsIn(b, window)) return true;
      // Plus a not-yet-started budget, kept reachable to edit/remove — but only
      // in the current month or a later one before it starts, never in a past
      // month (§2d).
      final start = budgetStartsLater(b);
      if (start == null) return false;
      if (monthStart.isBefore(thisMonthStart)) return false;
      return window.end.isBefore(start);
    }).toList()
      ..sort(_budgetOrder);
    return list;
  }

  /// Move [moved] within its scope to just before [before] (task 067.3 §5), or
  /// to the end of the running budgets when [before] is null. Renumbers the whole
  /// scope 0…n−1 so indices never collide, and persists.
  void moveBudget(Budget moved, {Budget? before}) {
    final all = _budgets
        .where((b) => b.scope == moved.scope && !b.isArchived)
        .toList()
      ..sort(_budgetOrder);
    all.remove(moved);
    int idx;
    if (before != null) {
      idx = all.indexOf(before);
      if (idx < 0) idx = all.length;
    } else {
      // The end of the running ones = before the first past-end budget.
      idx = all.indexWhere(budgetPastEnd);
      if (idx < 0) idx = all.length;
    }
    all.insert(idx, moved);
    for (var i = 0; i < all.length; i++) {
      all[i].sortIndex = i;
    }
    notifyListeners();
  }

  /// Spent against budgeted categories in [month]. Planner passes its own month
  /// here — it no longer reads the global [period].
  double budgetedSpend(DateTime month) => budgetedCategories
      .fold(0.0, (sum, c) => sum + spentInCategory(c.id, month));

  /// [budgetedSpend] restricted to categories whose monthly budget actually
  /// runs in [month] (task 067.1 §2e) — a not-yet-started budget's category is
  /// excluded, so the hero total and its spend describe the same budget set.
  double budgetedSpendFor(DateTime month) {
    final window = DateRange(_monthStart(month), _monthEnd(month));
    return budgetedCategories.where((c) {
      final b = monthlyBudgetForCategory(c.id);
      return b != null && budgetRunsIn(b, window);
    }).fold(0.0, (sum, c) => sum + spentInCategory(c.id, month));
  }

  /// Whether [categoryId] has no active category budget of **any** period — the
  /// test "unbudgeted" now asks (spec §4a). A category with a weekly limit is
  /// budgeted, so it is not unbudgeted, even though the month hero does not sum
  /// its weekly budget.
  bool _categoryUnbudgeted(String categoryId) =>
      budgetsForCategory(categoryId).isEmpty;

  /// Spent in [month] on expense categories that carry **no** budget — the
  /// spend the old "left to spend" figure ignored (spec 5.1: Eating out et al.).
  double unbudgetedSpend(DateTime month) => categories
      .where((c) =>
          c.type == CategoryType.expense && _categoryUnbudgeted(c.id))
      .fold(0.0, (sum, c) => sum + spentInCategory(c.id, month));

  /// The headline figure: budget minus *budgeted* spend. Unbudgeted spend sits
  /// outside the budget entirely, so it is excluded here — the hero describes
  /// the budget and nothing else, and agrees with the tab's own
  /// `budgeted of total` line (spec 5.1 §2). Goes negative — with its minus
  /// sign — when budgeted spend alone passes the budget.
  double leftThisMonth(DateTime month) =>
      totalBudgetFor(month) - budgetedSpendFor(month);

  /// Expense categories with no budget that have spending in [month], amount
  /// descending — the `NO BUDGET SET` list. A category with nothing spent is
  /// omitted (nothing is uncovered).
  List<Category> unbudgetedSpendingCategories(DateTime month) {
    final rows = categories
        .where((c) =>
            c.type == CategoryType.expense &&
            _categoryUnbudgeted(c.id) &&
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
      .fold(0.0, (sum, a) => sum + _toBaseOr(balanceOn(a.id, date), a.currency));

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
        delta += _toBaseOr(_effectOn(t, a.id), a.currency);
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
        delta += _toBaseOr(_effectOn(t, a.id), a.currency);
      }
    }
    return delta;
  }

  /// Revaluation booked in [window] — the DEĞER DEĞİŞİMİ block. Sums each
  /// rebalance's frozen base delta (spec 021b §2); the figure income/expense
  /// metrics deliberately exclude (spec 6.2).
  double revaluedInWindow(DateRange window, {Set<String>? visible}) =>
      txnsInWindow(window)
          .where((t) =>
              t.type == TxnType.rebalance &&
              (visible == null || visible.contains(t.toRef)))
          .fold(0.0, (sum, t) => sum + t.amountBase);

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
      leak -= _toBaseOr(_effectOn(t, from!.id), from.currency);
      leak -= _toBaseOr(_effectOn(t, to!.id), to.currency);
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
      moved += _toBaseOr(_effectOn(t, acc.id), acc.currency);
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
          expense[t.toRef] = (expense[t.toRef] ?? 0) + t.amountBase;
        case TxnType.income:
          // The account credited is `toRef`; the row counts when it is visible.
          if (visible != null && !visible.contains(t.toRef)) break;
          income[t.fromRef] = (income[t.fromRef] ?? 0) + t.amountBase;
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
          .fold(0.0, (sum, t) => sum + t.amountBase);

  double earnedInCategoryWindow(String categoryId, DateRange window) =>
      txnsInWindow(window)
          .where((t) => t.type == TxnType.income && t.fromRef == categoryId)
          .fold(0.0, (sum, t) => sum + t.amountBase);

  /// Spent in [window] on expense categories that carry no budget — the windowed
  /// twin of [unbudgetedSpend], for the see-all screen's `Bütçesiz…` strip.
  double unbudgetedSpendWindow(DateRange window) => categories
      .where((c) =>
          c.type == CategoryType.expense && _categoryUnbudgeted(c.id))
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
          .fold(0.0, (sum, t) => sum + t.amountBase);

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
      paid += _toBaseOr(t.toAmount ?? t.amount, dest.currency);
    }
    return paid;
  }

  /// Total liabilities as they stood at the end of [date] — positive magnitude.
  /// A balance snapshot converted at today's rate, degrading to native on a
  /// missing rate (§2d); the DEBT block's before/after pair.
  double totalLiabilitiesOn(DateTime date, {Set<String>? visible}) => _accounts
      .where((a) =>
          a.group.isLiability && (visible == null || visible.contains(a.id)))
      .fold(0.0, (sum, a) => sum + _toBaseOr(balanceOn(a.id, date), a.currency))
      .abs();

  /// Total receivables as they stood at the end of [date] — the ALACAĞIN cell.
  double totalReceivablesOn(DateTime date, {Set<String>? visible}) => _accounts
      .where((a) =>
          a.group == AccountGroup.receivables &&
          (visible == null || visible.contains(a.id)))
      .fold(0.0, (sum, a) => sum + _toBaseOr(balanceOn(a.id, date), a.currency));

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
      // Measured in the account's OWN currency (spec 021d §2b): target, start
      // and current are all native, so the rate cannot move the bar — a lira
      // account with a lira target does not slip when the dollar moves. Progress
      // is the account's real balance, never `balanceInBase`.
      start = balanceOn(g.source.id, g.createdAt);
      // Frozen: the balance the account actually held on [asOf], not today's.
      current = asOf == null
          ? balanceOf(g.source.id)
          : balanceOn(g.source.id, asOf);
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
  double _taskAmountInBase(Task t) => _toBaseOr(
        t.expectedAmount.abs(),
        accountById(t.linkedAccountId)?.currency ?? baseCurrency,
      );

  /// Public read of a task's expected amount in base currency — the detail
  /// screen's `PER YEAR` figure and row amounts (§7.3).
  double taskAmountInBase(Task t) => _taskAmountInBase(t);

  /// A specific occurrence's expected amount in base currency (task 064 §7c):
  /// [Task.amountOn]'s magnitude through the same conversion as
  /// [_taskAmountInBase]. Every reader that knows which occurrence it is
  /// pricing goes through here, so a per-month override moves the Schedule
  /// totals, the shortfall and the forecast — never amount × count.
  double taskAmountInBaseOn(Task t, DateTime day) => _toBaseOr(
        t.amountOn(day).abs(),
        accountById(t.linkedAccountId)?.currency ?? baseCurrency,
      );

  /// Task 064 §7c — writes one occurrence's expected amount. [magnitude] is
  /// unsigned; the sign follows the task's direction.
  ///
  /// `andAfter: false` overrides [day] alone; an override equal to the usual
  /// amount is removed instead (a no-op override is not stored).
  /// `andAfter: true` first pins every open occurrence before [day] (from the
  /// due date up to, not including, [day]) at the old usual amount unless it
  /// already carries an override, then makes [magnitude] the new usual
  /// [Task.expectedAmount] and drops every override at or after [day]. Past
  /// (recorded) occurrences are never touched — they are transactions.
  void setOccurrenceAmount(
    Task task,
    DateTime day,
    double magnitude, {
    required bool andAfter,
  }) {
    final d = DateTime(day.year, day.month, day.day);
    final signed = task.isPayOut ? -magnitude.abs() : magnitude.abs();
    if (!andAfter) {
      if ((signed - task.expectedAmount).abs() < 0.005) {
        task.amountOverrides.remove(d);
      } else {
        task.amountOverrides[d] = signed;
      }
    } else {
      final old = task.expectedAmount;
      var cur =
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      for (var guard = 0; guard < 400 && cur.isBefore(d); guard++) {
        task.amountOverrides.putIfAbsent(cur, () => old);
        final next = task.nextOccurrence(cur);
        final nextDay = DateTime(next.year, next.month, next.day);
        if (!nextDay.isAfter(cur)) break;
        cur = nextDay;
      }
      task.expectedAmount = signed;
      task.amountOverrides.removeWhere((k, _) => !k.isBefore(d));
    }
    notifyListeners();
  }

  /// Overdue is horizon-independent by design (§3.1): a filter cannot make money
  /// not owed, so narrowing the horizon never hides an unpaid bill. Shape
  /// unchanged for the nav badge (app_shell) and the summary banner.
  List<Task> get overdueTasks => openTasks
      .where((t) => t.daysUntilDue(today) < 0)
      .toList(growable: false);

  /// The first open occurrence strictly after [day]'s day (task 062 §1b): the
  /// earliest [Task.dueDate] over [openTasks] whose day is after [day]. Among
  /// tasks due that same day, ordered as the Schedule list orders them —
  /// priority (high first), then amount in base (large first); [sameDay] is
  /// how many *more* share the date. Pure, no side effects. Null when nothing
  /// is due after [day].
  ({Task task, DateTime date, int sameDay})? nextOccurrenceAfter(DateTime day) {
    final after = DateTime(day.year, day.month, day.day);
    DateTime dayOf(Task t) =>
        DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    final beyond = openTasks.where((t) => dayOf(t).isAfter(after)).toList();
    if (beyond.isEmpty) return null;
    var earliest = dayOf(beyond.first);
    for (final t in beyond.skip(1)) {
      final d = dayOf(t);
      if (d.isBefore(earliest)) earliest = d;
    }
    final due = beyond.where((t) => dayOf(t) == earliest).toList()
      ..sort((a, b) {
        final byPriority = b.priority.index.compareTo(a.priority.index);
        if (byPriority != 0) return byPriority;
        return taskAmountInBaseOn(b, earliest)
            .compareTo(taskAmountInBaseOn(a, earliest));
      });
    return (task: due.first, date: earliest, sameDay: due.length - 1);
  }

  /// Overdue pay-outs still owed. Applied at day 0 of the projection (§2.4).
  List<Task> get overdueOutflows =>
      overdueTasks.where((t) => t.isPayOut).toList(growable: false);

  /// Overdue pay-ins. Excluded from the projection — a salary that did not
  /// arrive is not money (§2.1) — but still shown in the banner (§2.5).
  List<Task> get overdueInflows =>
      overdueTasks.where((t) => !t.isPayOut).toList(growable: false);

  double get overdueOutAmount => overdueOutflows.fold(
      0.0, (s, t) => s + taskAmountInBaseOn(t, t.dueDate));

  double get overdueInAmount => overdueInflows.fold(
      0.0, (s, t) => s + taskAmountInBaseOn(t, t.dueDate));

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

  /// Σ over **every occurrence** of the open tasks matching [keep] that falls in
  /// [h] (task 058 §4b): the same events the Schedule list counts, so the list
  /// and the tab-card summary can never disagree. A monthly series contributes
  /// once per occurrence, not once per series. The overdue occurrence (before the
  /// horizon's start) is not counted here — [goingOut] adds it back for pay-outs.
  double _occurrenceSum(DateRange h, bool Function(Task) keep) {
    final startDay = DateTime(h.start.year, h.start.month, h.start.day);
    final endDay = DateTime(h.end.year, h.end.month, h.end.day);
    var sum = 0.0;
    for (final t in openTasks) {
      if (!keep(t)) continue;
      // Per occurrence, never amount × count (task 064 §7c): a month with its
      // own amount moves this total by exactly that amount.
      for (final day in t.occurrencesIn(startDay, endDay)) {
        sum += taskAmountInBaseOn(t, day);
      }
    }
    return sum;
  }

  /// Σ inflow across every in-horizon occurrence, excluding overdue inflows
  /// (§2.1/§2.3/§4b). The overdue occurrence falls before the horizon's start, so
  /// it is naturally left out.
  double comingIn(DateRange h) => _occurrenceSum(h, (t) => !t.isPayOut);

  /// Σ outflow across every in-horizon occurrence **plus** every overdue outflow
  /// (§2.1/§2.3/§4b).
  double goingOut(DateRange h) =>
      _occurrenceSum(h, (t) => t.isPayOut) + overdueOutAmount;

  /// How many rows the Schedule list shows for [h] — the tab-card summary's
  /// `{n} payments` (§4a): one per overdue task, plus every open task's in-horizon
  /// occurrences. No double count: an overdue task's overdue occurrence is counted
  /// here, its future recurrences by [Task.occurrencesIn] (which skips the one
  /// before the horizon's start).
  int scheduleOccurrenceCount(DateRange h) {
    final startDay = DateTime(h.start.year, h.start.month, h.start.day);
    final endDay = DateTime(h.end.year, h.end.month, h.end.day);
    var n = overdueTasks.length;
    for (final t in openTasks) {
      n += t.occurrencesIn(startDay, endDay).length;
    }
    return n;
  }

  /// The hero figure (§2.1): what is left after everything already committed —
  /// spendable cash, plus horizon inflows, minus horizon and overdue outflows.
  ///
  /// **No longer rendered as the Schedule hero (task 057):** the Planner's one
  /// forecast row above the tabs now answers "what will I have on a chosen date"
  /// through [forecastTo], which counts budgets and goals too and respects the
  /// account kind. This one-occurrence, spendable-only figure is retained as
  /// tested API (and 058 may reuse [firstShortfall]'s shape); the cash-flow
  /// picker in the horizon sheet is its remaining caller.
  double projection(DateRange h) => _spendableOr + comingIn(h) - goingOut(h);

  /// [spendable] with a native fallback for the projection's day-by-day run
  /// (§2d intermediate): a spendable account whose currency lost its rate keeps
  /// its native magnitude rather than nulling the whole projection.
  double get _spendableOr => accounts
      .where((a) => a.group == AccountGroup.spendable && a.countAsSpendable)
      .fold(0.0, (sum, a) => sum + _toBaseOr(balanceOf(a.id), a.currency));

  /// The first day the running balance goes negative within [h], and by how
  /// much — the highest-value output on the tab (§2.4). Overdue outflows land at
  /// day 0; inflows are applied before outflows on the same day. Only the first
  /// breach is reported.
  ///
  /// **No longer the Schedule summary's shortfall line (task 057):** the summary
  /// dropped its projection block. This still drives the list's breach-row
  /// highlight and the cash-flow picker; [forecastTo] carries the forecast-row
  /// forecast, with its own [ForecastResult.spendableBelowZero].
  ({DateTime day, double amount})? firstShortfall(DateRange h) {
    var running = _spendableOr - overdueOutAmount;
    final inRange = tasksInHorizon(h);
    final start = DateTime(h.start.year, h.start.month, h.start.day);
    final end = DateTime(h.end.year, h.end.month, h.end.day);
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      for (final t in inRange) {
        if (_sameDay(t.dueDate, d) && !t.isPayOut) {
          running += taskAmountInBaseOn(t, d);
        }
      }
      for (final t in inRange) {
        if (_sameDay(t.dueDate, d) && t.isPayOut) {
          running -= taskAmountInBaseOn(t, d);
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
    var running = _spendableOr - overdueOutAmount;
    final inRange = tasksInHorizon(h);
    final start = DateTime(h.start.year, h.start.month, h.start.day);
    final end = DateTime(h.end.year, h.end.month, h.end.day);
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      for (final t in inRange) {
        if (_sameDay(t.dueDate, d) && !t.isPayOut) {
          running += taskAmountInBaseOn(t, d);
        }
      }
      for (final t in inRange) {
        if (_sameDay(t.dueDate, d) && t.isPayOut) {
          running -= taskAmountInBaseOn(t, d);
        }
      }
      if (running < 0) out.add(DateTime(d.year, d.month, d.day));
    }
    return out;
  }

  // ── The Planner forecast (task 057) ───────────────────────────────────────

  /// The forecast from today to [end] (inclusive), in the reporting currency:
  /// two lenses — Spendable (cash you can actually use) and Net worth
  /// (everything owned minus owed) — walked day by day so the curve, the two
  /// end figures, and the first below-zero day can never disagree (§1b).
  ///
  /// It counts every planned thing: scheduled tasks (every occurrence, §1f),
  /// budgets at their planned daily pace (§1d), goals due inside the window
  /// (§1e), and overdue pay-outs on day 0 (§1c). Where the money lands decides
  /// which lens moves (the §1c table). A rate missing anywhere inside a lens
  /// silences **that lens only** — it is null for every day and its code lands
  /// in [ForecastResult.missingRateCodes] (§1h); a lens that can be computed
  /// still is. [end] before today yields today's figures unchanged (§1a).
  ForecastResult forecastTo(DateTime end) {
    final startDay = _todayDay;
    final endDay = DateTime(end.year, end.month, end.day);

    // Today's figures — null-propagating, exactly like balanceInBase.
    final spendToday = spendable;
    final nwToday = netWorth;

    // [end] before today: an empty forecast whose lenses equal today (§1a).
    if (endDay.isBefore(startDay)) {
      final missing = (spendToday == null || nwToday == null)
          ? missingRateCodes()
          : const <String>[];
      return ForecastResult(
        start: startDay,
        end: endDay,
        spendableToday: spendToday,
        netWorthToday: nwToday,
        spendable: spendToday,
        netWorth: nwToday,
        spendableBelowZero: null,
        spendableByDay: [spendToday],
        netWorthByDay: [nwToday],
        lines: const [],
        missingRateCodes: missing,
      );
    }

    final n = endDay.difference(startDay).inDays + 1; // days, inclusive
    final spendDaily = List<double>.filled(n, 0);
    final nwDaily = List<double>.filled(n, 0);
    final lines = <ForecastLine>[];
    final missing = <String>{};

    // A lens is silenced the moment an input it depends on cannot convert. Seed
    // from today: if today's figure is already null, that lens is silenced.
    var spendSilenced = spendToday == null;
    var nwSilenced = nwToday == null;
    if (spendSilenced || nwSilenced) missing.addAll(missingRateCodes());

    int idxOf(DateTime d) =>
        DateTime(d.year, d.month, d.day).difference(startDay).inDays;

    bool isSpendable(Account? a) =>
        a != null && a.group == AccountGroup.spendable && a.countAsSpendable;

    // Scheduled outflow (base) booked against a budget category, per day — used
    // to keep a bill inside a budgeted category from being counted twice (§1d).
    final schedByCatDay = <String, List<double>>{};

    // ── Scheduled tasks — every occurrence (§1f) ──────────────────────────────
    for (final t in openTasks) {
      final occ = t.occurrencesIn(startDay, endDay);
      if (occ.isEmpty) continue;
      final acc = accountById(t.linkedAccountId);
      final cur = acc?.currency ?? baseCurrency;
      final amt = convertToBase(t.expectedAmount.abs(), cur);
      final fromSpendable = isSpendable(acc);

      // Which lenses this occurrence moves, and by how much per occurrence.
      final double spendPer;
      final double nwPer;
      if (t.isPayOut) {
        if (t.isTransfer) {
          spendPer = fromSpendable ? -1.0 : 0.0; // leaves spendable; NW nets 0
          nwPer = 0.0;
        } else {
          spendPer = fromSpendable ? -1.0 : 0.0; // card pay-out: spendable 0
          nwPer = -1.0;
        }
      } else {
        spendPer = fromSpendable ? 1.0 : 0.0; // pay-in into non-cash: spendable 0
        nwPer = 1.0;
      }
      final touchesSpend = spendPer != 0;
      final touchesNw = nwPer != 0;

      if (amt == null) {
        // The figure is shown, so a missing rate silences the lenses it touches
        // (not _toBaseOr, which is for intermediates — §1f).
        if (touchesSpend) spendSilenced = true;
        if (touchesNw) nwSilenced = true;
        if (cur != baseCurrency) missing.add(cur);
        continue;
      }

      // Per occurrence (task 064 §7c): a month with its own amount moves the
      // curve by that amount. The rate is per-currency, so once [amt] converted
      // every override converts too — the `?? amt` never actually fires.
      double amountOf(DateTime day) =>
          convertToBase(t.amountOn(day).abs(), cur) ?? amt;

      var total = 0.0;
      for (final day in occ) {
        final i = idxOf(day);
        if (i < 0 || i >= n) continue;
        final a = amountOf(day);
        spendDaily[i] += spendPer * a;
        nwDaily[i] += nwPer * a;
        total += a;
      }
      // A pay-out with a category feeds the budget-pace de-duplication (§1d).
      if (t.isPayOut && !t.isTransfer && t.categoryId != null) {
        final byDay = schedByCatDay.putIfAbsent(
            t.categoryId!, () => List<double>.filled(n, 0));
        for (final day in occ) {
          final i = idxOf(day);
          if (i >= 0 && i < n) byDay[i] += amountOf(day);
        }
      }
      lines.add(ForecastLine(
        kind: ForecastKind.scheduled,
        refId: t.id,
        name: t.title,
        amount: t.isPayOut ? -total : total,
        count: occ.length,
        inSpendable: touchesSpend,
        inNetWorth: touchesNw,
      ));
    }

    // ── Overdue pay-outs — day 0, both lenses (§1c) ───────────────────────────
    for (final t in overdueOutflows) {
      final acc = accountById(t.linkedAccountId);
      final cur = acc?.currency ?? baseCurrency;
      final amt = convertToBase(t.amountOn(t.dueDate).abs(), cur);
      if (amt == null) {
        spendSilenced = true;
        nwSilenced = true;
        if (cur != baseCurrency) missing.add(cur);
        continue;
      }
      spendDaily[0] -= amt;
      nwDaily[0] -= amt;
      lines.add(ForecastLine(
        kind: ForecastKind.overdue,
        refId: t.id,
        name: t.title,
        amount: -amt,
        count: 1,
        inSpendable: true,
        inNetWorth: true,
      ));
    }

    // ── Budgets — planned pace, not actual pace (§1d) ─────────────────────────
    for (final b in _budgets) {
      if (!_isRunning(b)) continue;
      // A budget scoped to a non-spendable account leaves cash on the
      // card-payment day instead, so it is not paced here.
      if (b.scope == BudgetScope.account) {
        final target =
            b.targets.isEmpty ? null : accountById(b.targets.first);
        if (!isSpendable(target)) continue;
      }
      final cur = budgetCurrencyOf(b);
      final limitBase = convertToBase(b.limit, cur); // never rollover carry
      if (limitBase == null) {
        // A missing rate silences both lenses (§1d).
        spendSilenced = true;
        nwSilenced = true;
        if (cur != baseCurrency) missing.add(cur);
        continue;
      }
      final catDays = <String, List<double>>{
        for (final id in b.targets)
          if (schedByCatDay[id] != null) id: schedByCatDay[id]!,
      };
      var lineTotal = 0.0;
      var lineDays = 0;
      // From tomorrow to end: today's pace is already in the balance.
      for (var i = 1; i < n; i++) {
        final day = startDay.add(Duration(days: i));
        // A non-repeating budget contributes nothing past its window's end.
        if (!b.repeats && b.endedAt != null && day.isAfter(b.endedAt!)) break;
        final window = budgetWindow(b, day);
        final windowLen = window.end.difference(window.start).inDays + 1;
        // That day's period may carry its own limit (task 067.2 §1); a later
        // period (December's 2,500) paces higher than the usual one.
        final dayLimitBase = convertToBase(budgetLimitFor(b, day), cur) ?? limitBase;
        var pace = windowLen <= 0 ? 0.0 : dayLimitBase / windowLen;
        // A bill in a budgeted category is subtracted from that day's share,
        // never below zero, so it is not counted twice (§1d).
        if (b.scope == BudgetScope.categories && catDays.isNotEmpty) {
          var claimed = 0.0;
          for (final list in catDays.values) {
            claimed += list[i];
          }
          pace -= claimed;
          if (pace < 0) pace = 0;
        }
        if (pace == 0) continue;
        spendDaily[i] -= pace;
        nwDaily[i] -= pace;
        lineTotal += pace;
        lineDays++;
      }
      if (lineTotal > 0) {
        lines.add(ForecastLine(
          kind: ForecastKind.budget,
          refId: b.id,
          name: b.name,
          amount: -lineTotal,
          count: lineDays,
          inSpendable: true,
          inNetWorth: true,
        ));
      }
    }

    // ── Goals — by target date, Spendable only (§1e) ──────────────────────────
    for (final g in goals) {
      final m = goalMetrics(g);
      if (m.reached) continue;
      if (m.section == GoalSection.earning ||
          m.section == GoalSection.waitingOn) {
        continue;
      }
      final td = m.targetDate;
      if (td == null) continue;
      final tdDay = DateTime(td.year, td.month, td.day);
      if (tdDay.isBefore(startDay) || tdDay.isAfter(endDay)) continue;
      final cur = goalCurrencyOf(g);
      final remainingBase = convertToBase(m.remaining, cur);
      if (remainingBase == null) {
        // A goal moves only Spendable, so only that lens is silenced (§1h).
        spendSilenced = true;
        if (cur != baseCurrency) missing.add(cur);
        continue;
      }
      if (remainingBase <= 0) continue;
      final targetIdx = idxOf(tdDay); // 0..n-1
      final span = targetIdx + 1; // today..target inclusive
      final perDay = remainingBase / span;
      for (var i = 0; i <= targetIdx; i++) {
        spendDaily[i] -= perDay;
      }
      lines.add(ForecastLine(
        kind: ForecastKind.goal,
        refId: g.id,
        name: g.name,
        amount: -remainingBase,
        count: span,
        inSpendable: true,
        inNetWorth: false,
      ));
    }

    // ── Walk the days, accumulating both running lenses (§1b) ──────────────────
    final spendByDay = List<double?>.filled(n, null);
    final nwByDay = List<double?>.filled(n, null);
    var runS = spendToday ?? 0;
    var runN = nwToday ?? 0;
    DateTime? belowZero;
    for (var i = 0; i < n; i++) {
      runS += spendDaily[i];
      runN += nwDaily[i];
      if (!spendSilenced) {
        spendByDay[i] = runS;
        if (belowZero == null && runS < 0) {
          belowZero = startDay.add(Duration(days: i));
        }
      }
      if (!nwSilenced) nwByDay[i] = runN;
    }

    return ForecastResult(
      start: startDay,
      end: endDay,
      spendableToday: spendSilenced ? null : spendToday,
      netWorthToday: nwSilenced ? null : nwToday,
      spendable: spendSilenced ? null : runS,
      netWorth: nwSilenced ? null : runN,
      spendableBelowZero: belowZero,
      spendableByDay: spendByDay,
      netWorthByDay: nwByDay,
      lines: lines,
      missingRateCodes: missing.toList(growable: false),
    );
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
      .fold(0.0, (s, t) => s + t.amountBase);

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
        amountInBase: t.amountBase,
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
          amountInBase: taskAmountInBaseOn(task, sd),
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
          amountInBase: taskAmountInBaseOn(task, task.dueDate),
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
    double? rateToBase,
    double? amountBase,
    double? fee,
    bool feeFromSource = true,
    List<String> tagIds = const [],
    String note = '',
    String? goalId,
    String? splitGroupId,
    String? recurrenceTaskId,
    String? feeTxnId,
  }) {
    // Freeze the entry's rate against the reporting currency (spec 021b §1). A
    // caller with an opinion (the Quick Add form) passes both; a caller with none
    // (the seed, the recurrence materialiser) uses the currency's stored rate at
    // this moment — falling back to 1 only when nothing is known.
    final frozenRate = rateToBase ?? rateFor(currency) ?? 1.0;
    final frozenBase =
        amountBase ?? roundToCurrency(amount / frozenRate, baseCurrency);
    final txn = Txn(
      id: _nextId('t'),
      type: type,
      amount: amount,
      currency: currency,
      fromRef: fromRef,
      toRef: toRef,
      date: date,
      rateToBase: frozenRate,
      amountBase: frozenBase,
      // Stamp the real recording instant, distinct from the (user-editable)
      // transaction date (spec §5b). Before this, `createdAt` defaulted to
      // `date`, so a misfiled record was indistinguishable from a correct one;
      // from now on the two are independent facts. Existing records are NOT
      // backfilled — a null/derived past value stays as it was.
      createdAt: now,
      exchangeRate: exchangeRate,
      toAmount: toAmount,
      fee: fee,
      feeFromSource: feeFromSource,
      tagIds: tagIds,
      note: note,
      goalId: goalId,
      splitGroupId: splitGroupId,
      recurrenceTaskId: recurrenceTaskId,
      feeTxnId: feeTxnId,
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
    String? currency,
    String? fromRef,
    String? toRef,
    DateTime? date,
    double? rateToBase,
    double? amountBase,
    List<String>? tagIds,
    String? note,
    double? fee,
    double? toAmount,
    double? exchangeRate,
    String? recurrenceTaskId,
    String? feeTxnId,
    bool clearRecurrence = false,
    bool clearExchange = false,
    bool clearFee = false,
    bool clearFeeLink = false,
  }) {
    final newAmount = amount ?? txn.amount;
    // The rate is only replaced when the caller passes one (a currency change or
    // an explicit re-freeze — spec 021b §3c); otherwise it stays frozen. Changing
    // the amount recomputes [amountBase] at the STORED rate, never today's.
    final newRate = rateToBase ?? txn.rateToBase;
    txn
      ..amount = newAmount
      ..currency = currency ?? txn.currency
      ..rateToBase = newRate
      ..amountBase =
          amountBase ?? roundToCurrency(newAmount / newRate, baseCurrency)
      ..fromRef = fromRef ?? txn.fromRef
      ..toRef = toRef ?? txn.toRef
      ..date = date ?? txn.date
      ..tagIds = tagIds ?? txn.tagIds
      ..note = note ?? txn.note
      // [clearFee] nulls the legacy on-transfer fee amount outright (a null
      // argument means "keep"); the Transfer-fee spec moves the fee to a linked
      // expense, so a rewritten transfer must carry no fee amount of its own.
      // [clearFeeLink] independently nulls the join to that expense — the two
      // are separate because an edited transfer clears its legacy amount while
      // still pointing at (or newly creating) its fee expense.
      ..fee = clearFee ? null : (fee ?? txn.fee)
      ..feeTxnId = clearFeeLink ? null : (feeTxnId ?? txn.feeTxnId)
      // [clearExchange] wins over the `?? keep` fallback so an edit that turns a
      // cross-currency transfer into a same-currency one can null both FX fields
      // (mirroring [clearRecurrence]). Without it there is no way to erase a
      // stored value — passing null means "keep" — so the destination figure
      // would keep a rate that no longer applies.
      ..toAmount = clearExchange ? null : (toAmount ?? txn.toAmount)
      ..exchangeRate = clearExchange ? null : (exchangeRate ?? txn.exchangeRate)
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
    // A transfer's fee is a joined expense (Transfer-fee spec §4.1): deleting the
    // transfer deletes its fee, so no orphan cost survives. The fee record itself
    // carries no [Txn.feeTxnId], so this never recurses.
    final feeId = txn.feeTxnId;
    _txns.removeWhere((t) => t.id == txn.id || (feeId != null && t.id == feeId));
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
    _budgets
      ..clear()
      ..addAll(source._budgets);
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
    // Adopt the restored base currency, and persist it. A backup written after
    // this change carries it on the source; one written before does not, so
    // derive it from the oldest account (spec §4). Persisting pins it, so it
    // survives the relaunch and cannot move if that account is later deleted.
    _baseCurrency = source._baseCurrency ?? oldestAccountCurrency(_accounts);
    if (_baseCurrency != null) {
      unawaited(_saveString(_baseCurrencyKey, _baseCurrency!));
    }
    // Adopt the restored rate table and reporting-currency change log, then
    // re-seed anything still missing so a pre-021 backup never lands in the
    // missing-rate state (spec 021a §5). Persist so it survives the relaunch.
    _rates
      ..clear()
      ..addAll(source._rates);
    _rateSetAt
      ..clear()
      ..addAll(source._rateSetAt);
    _baseCurrencyChanges
      ..clear()
      ..addAll(source._baseCurrencyChanges);
    _seedRatesIfEmpty();
    unawaited(_saveRates());
    unawaited(_saveBaseChanges());
    _sameIndex = null;
    _accountIndex = null;
    // A moved balance can newly meet a goal's target; latch any that reached
    // (§4). Progress itself is never stored — only the reached *date* is.
    _syncGoalLatches();
    notifyListeners();
  }

  /// Applies a batch of remote (group-sync) records in place: upserts replace
  /// by id or append, deletions remove by id. Typed lists keep the mappers in
  /// the persistence layer where they live. One [notifyListeners] at the end —
  /// the attached persister then snapshots the merged state locally, and the
  /// sync engine's own listener sees an empty diff because it updated its
  /// shadow before calling this.
  void applySyncedRecords({
    List<Account> accounts = const [],
    List<Category> categories = const [],
    List<Budget> budgets = const [],
    List<Txn> txns = const [],
    List<Tag> tags = const [],
    List<Goal> goals = const [],
    List<Task> tasks = const [],
    List<CurrencyDef> currencies = const [],
    Set<String> deletedAccountIds = const {},
    Set<String> deletedCategoryIds = const {},
    Set<String> deletedBudgetIds = const {},
    Set<String> deletedTxnIds = const {},
    Set<String> deletedTagIds = const {},
    Set<String> deletedGoalIds = const {},
    Set<String> deletedTaskIds = const {},
    Set<String> deletedCurrencyCodes = const {},
    int? tagSchema,
    DateTime? budgetHistorySince,
  }) {
    void merge<T>(List<T> target, List<T> incoming, Set<String> deleted,
        String Function(T) idOf) {
      for (final item in incoming) {
        final id = idOf(item);
        final index = target.indexWhere((e) => idOf(e) == id);
        if (index >= 0) {
          target[index] = item;
        } else {
          target.add(item);
        }
      }
      if (deleted.isNotEmpty) {
        target.removeWhere((e) => deleted.contains(idOf(e)));
      }
    }

    merge(_accounts, accounts, deletedAccountIds, (Account a) => a.id);
    merge(_categories, categories, deletedCategoryIds, (Category c) => c.id);
    merge(_budgets, budgets, deletedBudgetIds, (Budget b) => b.id);
    merge(_txns, txns, deletedTxnIds, (Txn t) => t.id);
    merge(_tags, tags, deletedTagIds, (Tag t) => t.id);
    merge(_goals, goals, deletedGoalIds, (Goal g) => g.id);
    merge(_tasks, tasks, deletedTaskIds, (Task t) => t.id);
    merge(_customCurrencies, currencies, deletedCurrencyCodes,
        (CurrencyDef c) => c.code);

    if (currencies.isNotEmpty || deletedCurrencyCodes.isNotEmpty) {
      setCustomCurrencies(_customCurrencies);
    }
    if (tagSchema != null) _tagSchema = tagSchema;
    // (budgetHistorySince has no live setter — the epoch only matters at
    // construction; the persister writes the store's current value back.)

    _sameIndex = null;
    _accountIndex = null;
    _syncGoalLatches();
    notifyListeners();
  }

  /// Balance an account would return to if [txn] were deleted — the concrete
  /// figure the Destructive Confirmation shows (spec 2.4).
  double balanceWithout(String accountId, Txn txn) =>
      balanceOf(accountId) - _effectOn(txn, accountId);

  /// The balance [accountId] would hold if [prospective] were saved, with
  /// [replacing] — the entry being edited — taken out first. Writes nothing
  /// (task 011).
  ///
  /// This exists so a form can ask "what would happen" without re-deriving the
  /// ledger rules: [_effectOn] stays the one place they live.
  double balanceIfSaved(String accountId, Txn prospective, {Txn? replacing}) {
    final base = replacing == null
        ? balanceOf(accountId)
        : balanceWithout(accountId, replacing);
    return base + _effectOn(prospective, accountId);
  }

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

  /// Writes the display metadata for [def]'s code, replacing any override that
  /// already exists for it (spec §2). Editing a **built-in** lands here too: the
  /// result is a custom def under the built-in's own code, which
  /// [currencyDef] already prefers and [customCurrencyDef] already routes
  /// through the metadata formatter — so no formatter changes hands.
  ///
  /// Upsert, never append: one override per code, so editing the same built-in
  /// twice cannot leave two rows fighting over it (§6).
  void updateCustomCurrency(CurrencyDef def) {
    final normalised = def.copyWith(custom: true);
    final i = _customCurrencies.indexWhere((c) => c.code == normalised.code);
    if (i >= 0) {
      _customCurrencies[i] = normalised;
    } else {
      _customCurrencies.add(normalised);
    }
    // Re-register before notifying so the rows already on screen behind the
    // sheet reformat on this same frame (spec §5).
    setCustomCurrencies(_customCurrencies);
    notifyListeners();
  }

  /// Drops the override for [code]. For a custom currency this deletes it; for
  /// an overridden built-in it is "Reset to default" — the shipped definition
  /// takes over again. Either way it touches **no** account and no transaction
  /// (spec §2): deleting a currency in use is blocked upstream, never cascaded.
  void removeCustomCurrency(String code) {
    final c = code.trim().toUpperCase();
    if (!_customCurrencies.any((x) => x.code == c)) return;
    _customCurrencies.removeWhere((x) => x.code == c);
    setCustomCurrencies(_customCurrencies);
    notifyListeners();
  }

  /// Accounts denominated in [code] — the first thing that blocks a delete, and
  /// what the block message names (spec §2).
  List<Account> accountsUsingCurrency(String code) =>
      [for (final a in _accounts) if (a.currency == code) a];

  /// Transactions carrying [code]. Counted, not listed: the message names an
  /// account when there is one, and otherwise says how many entries hold it.
  int txnCountForCurrency(String code) =>
      _txns.where((t) => t.currency == code).length;

  /// Whether anything at all still names [code].
  bool currencyInUse(String code) =>
      accountsUsingCurrency(code).isNotEmpty || txnCountForCurrency(code) > 0;

  /// How many rows the currency screen lists — the More ▸ Data count (spec §1).
  ///
  /// The screen's two sections are IN USE (every referenced code, custom ones
  /// included) and ADDED, NOT USED (custom codes nothing references). Their union
  /// is `currencyCodesInUse ∪ custom codes`, each code once, which is exactly
  /// what this counts: the in-use codes that are *not* custom, plus every custom
  /// code (whether in use — counted in IN USE — or not — counted in ADDED, NOT
  /// USED). So it matches the rows rendered without double-counting a custom
  /// currency that is also in use.
  int get currencyRowCount {
    final customCodes = {for (final c in _customCurrencies) c.code};
    final inUse =
        currencyCodesInUse().where((c) => !customCodes.contains(c)).length;
    return inUse + customCodes.length;
  }

  /// Codes actually referenced by an account or a transaction, plus the base
  /// currency — the IN USE section of the currency screen (spec §1). Not all 180
  /// ISO codes: this screen lists what this store actually touches.
  List<String> currencyCodesInUse() {
    final seen = <String>{baseCurrency};
    for (final a in _accounts) {
      seen.add(a.currency);
    }
    for (final t in _txns) {
      seen.add(t.currency);
    }
    final out = seen.toList()..sort();
    return out;
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
    // First account ever: silently seed the base currency from it, once
    // (spec §1). `_baseCurrency` is null only before any account has existed, so
    // this fires exactly on the first account and never on later ones — creating
    // a second account, or deleting/editing this one, leaves the base alone.
    if (_baseCurrency == null) {
      _baseCurrency = currency;
      unawaited(_saveBaseCurrency(currency));
    }
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
    bool? inactive,
  }) {
    account
      ..name = name ?? account.name
      ..group = group ?? account.group
      ..currency = currency ?? account.currency
      ..creditLimit = creditLimit ?? account.creditLimit
      ..statementDay = statementDay ?? account.statementDay
      ..paymentDue = paymentDue ?? account.paymentDue
      ..hidden = hidden ?? account.hidden
      ..inactive = inactive ?? account.inactive;
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
    );
    _categories.add(category);
    // A budget born with the category is its own object with a `created` entry —
    // history is complete from birth (no backfill needed). rollover defaults off.
    if (monthlyBudget != null) {
      _budgets.add(_newMonthlyCategoryBudget(category, monthlyBudget));
    }
    notifyListeners();
    return category;
  }

  /// A fresh monthly category budget for [category] with the given [limit],
  /// seeded with a `created` history entry (budgets-as-object spec §A / §C).
  Budget _newMonthlyCategoryBudget(Category category, double limit,
      {bool rollover = false, double warnThreshold = 0.8}) {
    return Budget(
      id: _nextId('b'),
      name: category.name,
      scope: BudgetScope.categories,
      targets: {category.id},
      limit: limit,
      period: BudgetPeriod.month,
      anchor: DateTime(today.year, today.month, 1),
      repeats: true,
      rollover: rollover,
      warnThreshold: warnThreshold,
      history: [
        BudgetEdit(
          at: today,
          field: 'created',
          from: rollover ? 'on' : 'off',
          to: money(limit),
        ),
      ],
    );
  }

  /// Create a budget of any scope and period (budgets-as-object §A / spec 022).
  /// [rollover] is forced off on a non-repeating ('once') budget — there is no
  /// next period to carry into (spec §2b). Seeds one `created` history entry,
  /// printed in the budget's own currency. The full-scope path the reworked
  /// New-budget form calls; [updateBudget]/[_newMonthlyCategoryBudget] stay the
  /// monthly-single-category path Task 005 and the migration use.
  Budget addBudget({
    required BudgetScope scope,
    required Set<String> targets,
    required String name,
    required double limit,
    required BudgetPeriod period,
    required DateTime anchor,
    required bool repeats,
    String? currency,
    int? lengthDays,
    bool rollover = false,
    double warnThreshold = 0.8,
    DateTime? endedAt,
    DateTime? runsUntil,
    String note = '',
  }) {
    final cur = (currency == null || currency.isEmpty) ? null : currency;
    final rolls = repeats && rollover;
    final b = Budget(
      id: _nextId('b'),
      name: name,
      scope: scope,
      targets: targets,
      limit: limit,
      currency: cur,
      period: period,
      lengthDays: lengthDays,
      anchor: anchor,
      repeats: repeats,
      rollover: rolls,
      warnThreshold: warnThreshold,
      endedAt: endedAt,
      runsUntil: repeats ? runsUntil : null,
      note: note.trim(),
      history: [
        BudgetEdit(
          at: today,
          field: 'created',
          from: rolls ? 'on' : 'off',
          to: money(limit, currency: cur),
        ),
      ],
    );
    _budgets.add(b);
    notifyListeners();
    return b;
  }

  /// Edit the amount-side fields of any budget in place (spec 022 §3). Scope,
  /// targets and period are fixed after creation — changing them would detach the
  /// budget from its spend history — so they are not editable here. Logs the same
  /// `limit`/`rollover`/`warn` rows [updateBudget] does, in the budget's own
  /// currency, only for fields that actually moved.
  void updateBudgetGeneral(
    Budget b, {
    String? name,
    double? limit,
    bool? rollover,
    double? warnThreshold,
  }) {
    final bc = b.currency.isEmpty ? null : b.currency;
    if (limit != null && limit != b.limit) {
      b.history.add(BudgetEdit(
        at: today,
        field: 'limit',
        from: money(b.limit, currency: bc),
        to: money(limit, currency: bc),
        amber: limit > b.limit,
      ));
    }
    // Rollover is meaningless on a non-repeating budget (spec §2b); ignore it.
    if (rollover != null && b.repeats && rollover != b.rollover) {
      b.history.add(BudgetEdit(
        at: today,
        field: 'rollover',
        from: b.rollover ? 'on' : 'off',
        to: rollover ? 'on' : 'off',
      ));
    }
    if (warnThreshold != null && warnThreshold != b.warnThreshold) {
      b.history.add(BudgetEdit(
        at: today,
        field: 'warn',
        from: percent(b.warnThreshold, decimals: 0),
        to: percent(warnThreshold, decimals: 0),
      ));
    }
    b
      ..name = (name == null || name.isEmpty) ? b.name : name
      ..limit = limit ?? b.limit
      ..rollover = b.repeats ? (rollover ?? b.rollover) : false
      ..warnThreshold = warnThreshold ?? b.warnThreshold;
    // A changed usual limit may make an override redundant (task 067.2 §2).
    _pruneRedundantOverrides(b);
    notifyListeners();
  }

  /// Sets a budget's free-text note (task 067.1 §1). Stored trimmed; not logged.
  void setBudgetNote(Budget b, String note) {
    final trimmed = note.trim();
    if (trimmed == b.note) return;
    b.note = trimmed;
    notifyListeners();
  }

  /// Sets a budget's display name (task 067.1 §8) — the Task 005 path has no name
  /// parameter, so this fills it. Not logged, matching [updateBudgetGeneral].
  void setBudgetName(Budget b, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == b.name) return;
    b.name = trimmed;
    notifyListeners();
  }

  /// Moves a repeating budget's end (task 067.1 §1/§6e). Logs an `'until'` edit
  /// with the old/new last day as epoch-ms strings (or '' for no end). A no-op
  /// on a one-off, which ends through [endedAt].
  void setBudgetRunsUntil(Budget b, DateTime? runsUntil) {
    if (!b.repeats) return;
    final next = runsUntil == null
        ? null
        : DateTime(runsUntil.year, runsUntil.month, runsUntil.day);
    if (next == b.runsUntil) return;
    b.history.add(BudgetEdit(
      at: today,
      field: 'until',
      from: b.runsUntil == null
          ? ''
          : '${b.runsUntil!.millisecondsSinceEpoch}',
      to: next == null ? '' : '${next.millisecondsSinceEpoch}',
    ));
    b.runsUntil = next;
    notifyListeners();
  }

  /// Give one period of [b] its own limit, or change the limit from that period
  /// onward (task 067.2 §2), with the same "Only this" / "…and after" choice
  /// [setOccurrenceAmount] offers a scheduled item. [periodStart] is normalised
  /// to the period's own start.
  ///
  /// `andAfter: false` — only that period changes; an entry equal to the usual
  /// limit is never stored. `andAfter: true` — every period before it keeps
  /// exactly the limit it had (recorded in [Budget.limitBefore]), and it and
  /// every later period take the new limit. Nothing before it changes.
  void setBudgetPeriodLimit(Budget b, DateTime periodStart, double limit,
      {required bool andAfter}) {
    final d = budgetWindow(b, periodStart).start;
    final bc = b.currency.isEmpty ? null : b.currency;
    final oldLimit = budgetLimitFor(b, d);
    if (!andAfter) {
      final usual = budgetUsualLimitFor(b, d);
      if ((limit - usual).abs() < 0.005) {
        b.limitOverrides.remove(d);
      } else {
        b.limitOverrides[d] = limit;
      }
      if ((limit - oldLimit).abs() >= 0.005) {
        b.history.add(BudgetEdit(
          at: today,
          field: 'periodLimit',
          period: d,
          from: money(oldLimit, currency: bc),
          to: money(limit, currency: bc),
          amber: limit > oldLimit,
        ));
      }
    } else {
      // Read the usual limit of the period just before D before mutating.
      final before = budgetUsualLimitFor(b, d.subtract(const Duration(days: 1)));
      // Periods on/after D now take the new usual limit, so any earlier boundary
      // at or after D is dropped; a boundary at D is re-established below.
      b.limitBefore.removeWhere((k, _) => !k.isBefore(d));
      if ((before - limit).abs() >= 0.005) {
        b.limitBefore[d] = before;
      }
      b.limit = limit;
      // Overrides from D on are superseded by the new usual limit.
      b.limitOverrides.removeWhere((k, _) => !k.isBefore(d));
      if ((limit - oldLimit).abs() >= 0.005) {
        b.history.add(BudgetEdit(
          at: today,
          field: 'limit',
          period: d,
          from: money(oldLimit, currency: bc),
          to: money(limit, currency: bc),
          amber: limit > oldLimit,
        ));
      }
    }
    _pruneRedundantOverrides(b);
    notifyListeners();
  }

  /// Remove a period's own limit (task 067.2 §2) — it returns to the usual one.
  void resetBudgetPeriodLimit(Budget b, DateTime periodStart) {
    final d = budgetWindow(b, periodStart).start;
    final old = b.limitOverrides[d];
    if (old == null) return;
    b.limitOverrides.remove(d);
    final usual = budgetUsualLimitFor(b, d);
    if ((old - usual).abs() >= 0.005) {
      final bc = b.currency.isEmpty ? null : b.currency;
      b.history.add(BudgetEdit(
        at: today,
        field: 'periodLimit',
        period: d,
        from: money(old, currency: bc),
        to: money(usual, currency: bc),
      ));
    }
    _pruneRedundantOverrides(b);
    notifyListeners();
  }

  /// Drop every override that now equals its period's usual limit (task 067.2
  /// §2) — called after any limit change, here or in the edit form, so a stored
  /// override never merely restates the usual limit.
  void _pruneRedundantOverrides(Budget b) {
    b.limitOverrides.removeWhere((ps, v) {
      final usual = budgetUsualLimitFor(b, ps);
      return (v - usual).abs() < 0.005;
    });
  }

  /// Archive any budget (spec §5c/§C.5) — it leaves the Budgets tab. Used to
  /// remove a finished one-off the reader is done with, from the detail menu.
  void archiveBudget(Budget b) {
    if (b.isArchived) return;
    b.history.add(BudgetEdit(
      at: today,
      field: 'removed',
      from: '',
      to: money(b.limit, currency: b.currency.isEmpty ? null : b.currency),
    ));
    b.archivedAt = today;
    notifyListeners();
  }

  /// Every budget-field change is logged to [Category.budgetHistory] — but only
  /// a *real* change: this method writes `x ?? category.x`, so a save that
  /// touched nothing must append nothing. Compare before assigning. A null→value
  /// transition is a `created` entry (money + rollover state), not a `limit`
  /// one; on that birth call the rollover/warn moves fold into `created` rather
  /// than logging separately. One save can legitimately emit three rows (limit,
  /// rollover, warn), all carrying the same [today].
  /// Changes a budget's currency (021d §1e). The limit is **never** converted:
  /// 8,000 stays 8,000 and now means 8,000 of [code]. The caller confirms with a
  /// dialog naming both readings before this runs.
  void changeBudgetCurrency(Budget b, String code) {
    if (code.isEmpty || code == budgetCurrencyOf(b)) return;
    b.currency = code;
    notifyListeners();
  }

  void updateBudget(
    Category category, {
    double? monthlyBudget,
    bool? rollover,
    double? warnThreshold,
  }) {
    final existing = monthlyBudgetForCategory(category.id);
    final creating = monthlyBudget != null && existing == null;

    if (creating) {
      _budgets.add(_newMonthlyCategoryBudget(
        category,
        monthlyBudget,
        rollover: rollover ?? false,
        warnThreshold: warnThreshold ?? 0.8,
      ));
      notifyListeners();
      return;
    }
    if (existing == null) return; // nothing to update, nothing to create.

    final newLimit = monthlyBudget ?? existing.limit;
    final newRollover = rollover ?? existing.rollover;
    final newWarn = warnThreshold ?? existing.warnThreshold;

    if (monthlyBudget != null && monthlyBudget != existing.limit) {
      // History prints in the budget's own currency (021d §2c-analogue).
      final bc = existing.currency.isEmpty ? null : existing.currency;
      existing.history.add(BudgetEdit(
        at: today,
        field: 'limit',
        from: money(existing.limit, currency: bc),
        to: money(monthlyBudget, currency: bc),
        // A raised limit is amber; a lowered one is not.
        amber: monthlyBudget > existing.limit,
      ));
    }
    if (rollover != null && rollover != existing.rollover) {
      existing.history.add(BudgetEdit(
        at: today,
        field: 'rollover',
        from: existing.rollover ? 'on' : 'off',
        to: rollover ? 'on' : 'off',
      ));
    }
    if (warnThreshold != null && warnThreshold != existing.warnThreshold) {
      existing.history.add(BudgetEdit(
        at: today,
        field: 'warn',
        from: percent(existing.warnThreshold, decimals: 0),
        to: percent(warnThreshold, decimals: 0),
      ));
    }

    existing
      ..limit = newLimit
      ..rollover = newRollover
      ..warnThreshold = newWarn;
    // A changed usual limit may make an override redundant (task 067.2 §2).
    _pruneRedundantOverrides(existing);
    notifyListeners();
  }

  /// Spec 5.5 — removing a budget archives its [Budget] (the category and its
  /// transactions are deliberately untouched). Logs `removed` with the last
  /// limit; the history outlives the removal.
  void removeBudget(Category category) => _removeBudget(category, log: true);

  /// The shared removal. [archiveCategory] passes `log: false` so one user
  /// action (archiving) writes one `categoryArchived` row, not a `removed` row
  /// as well.
  void _removeBudget(Category category, {required bool log}) {
    final b = monthlyBudgetForCategory(category.id);
    if (b == null) return;
    if (log) {
      b.history.add(BudgetEdit(
        at: today,
        field: 'removed',
        from: '',
        to: money(b.limit),
      ));
    }
    b.archivedAt = today;
    notifyListeners();
  }

  void restoreBudget(Category category, double limit) {
    final b = _anyMonthlyBudgetForCategory(category.id);
    if (b == null) {
      // No trace survived (e.g. hard reset) — recreate the budget outright.
      _budgets.add(_newMonthlyCategoryBudget(category, limit));
      notifyListeners();
      return;
    }
    b.history.add(BudgetEdit(
      at: today,
      field: 'restored',
      from: '',
      to: money(limit),
    ));
    b
      ..limit = limit
      ..archivedAt = null;
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
    final b = monthlyBudgetForCategory(category.id);
    if (b != null) {
      b.history.add(BudgetEdit(
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
    if (budgetsForCategory(category.id).isNotEmpty) return false;
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
    GoalPace pace = GoalPace.month,
    bool endsWhenReached = true,
    String note = '',
  }) {
    // An account-sourced goal is measured in the account's own currency (021d
    // §2a); a category-sourced one spans accounts, so it uses the reporting
    // currency (stored as '').
    final goalCur =
        source.isAccount ? (accountById(source.id)?.currency ?? '') : '';
    final moneyCur = goalCur.isEmpty ? null : goalCur;
    final createdTo = targetDate == null
        ? money(targetAmount, currency: moneyCur)
        : '${money(targetAmount, currency: moneyCur)} · ${_histDate(targetDate)}';
    final goal = Goal(
      id: _nextId('g'),
      name: name,
      source: source,
      targetAmount: targetAmount,
      currency: goalCur,
      targetDate: targetDate,
      pace: pace,
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
    GoalPace? pace,
    bool? endsWhenReached,
    String? note,
  }) {
    if (targetAmount != null && targetAmount != goal.targetAmount) {
      // History prints in the goal's own currency (021d §2c).
      final gc = goal.currency.isEmpty ? null : goal.currency;
      goal.history.add(GoalEdit(
        at: today,
        field: 'target',
        from: money(goal.targetAmount, currency: gc),
        to: money(targetAmount, currency: gc),
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
      ..pace = pace ?? goal.pace
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
      // Archived series live in FINISHED too (task 065 §4c), so clearing the
      // group deletes them for good like the paid one-offs beside them.
      for (final t in archivedTasks) t.id,
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
    // What the user typed stays with the item (task 063 §1). Trimmed; an
    // empty string stores null, matching how updateTask treats ''.
    String? note,
  }) {
    final trimmedNote = note?.trim();
    final task = Task(
      id: _nextId('k'),
      title: title,
      linkedAccountId: linkedAccountId,
      expectedAmount: expectedAmount,
      dueDate: dueDate,
      icon: icon,
      categoryId: categoryId,
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
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
    IconData? icon,
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
      ..icon = icon ?? task.icon
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
    // The occurrence this payment closes — the due date before the series
    // advances, at day granularity (§6). Stamped on the Txn so a completed
    // payment can be undone later, walking the series back to exactly this day.
    final occurrenceDue = DateTime(prevDue.year, prevDue.month, prevDue.day);

    final isPayOut = task.expectedAmount < 0;
    final toIsAccount = accountById(toRef) != null;
    final Txn txn;
    if (isPayOut && toIsAccount) {
      final from = accountById(fromAccountId);
      txn = addTxn(
        type: TxnType.transfer,
        amount: amount,
        currency: from?.currency ?? baseCurrency,
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
        currency: from?.currency ?? baseCurrency,
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
        currency: into?.currency ?? baseCurrency,
        fromRef: toRef,
        toRef: fromAccountId,
        date: date,
        note: task.title,
        recurrenceTaskId: task.id,
      );
    }

    txn.recurrenceDueDate = occurrenceDue;

    if (rememberAmount) {
      task.expectedAmount = isPayOut ? -amount : amount;
    }
    // The settled occurrence's per-month override, if any — [_advance] drops
    // it, so Undo needs it snapshotted (task 064 §7e).
    final prevOverride = task.amountOverrides[occurrenceDue];
    _advance(task);
    notifyListeners();
    return MarkPaidResult(
      task: task,
      txn: txn,
      previousDueDate: prevDue,
      previousStatus: prevStatus,
      previousStatusChangedAt: prevChanged,
      previousExpected: prevExpected,
      previousOverride: prevOverride,
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
    // Put back the override the advance consumed with the occurrence (§7e).
    if (r.previousOverride != null) {
      final d = DateTime(r.previousDueDate.year, r.previousDueDate.month,
          r.previousDueDate.day);
      r.task.amountOverrides[d] = r.previousOverride!;
    }
    _syncGoalLatches();
    notifyListeners();
  }

  /// Reverses a recorded task payment from its [Txn] alone (task 058 §6c) — the
  /// durable twin of [undoMarkTaskPaid], which needs a [MarkPaidResult] only the
  /// current session holds. Deletes the entry, and when the settled occurrence is
  /// known ([Txn.recurrenceDueDate]) walks the series back to it, reopening a task
  /// that this payment had closed. With a null occurrence it never guesses: it
  /// deletes the entry and leaves the task where it is.
  void undoTaskPayment(Txn txn) {
    _txns.removeWhere((t) => t.id == txn.id);
    _sameIndex = null;
    _accountIndex = null;
    final task = txn.recurrenceTaskId == null
        ? null
        : taskById(txn.recurrenceTaskId!);
    final due = txn.recurrenceDueDate;
    if (task != null && due != null) {
      task.dueDate = due;
      // If this payment is what closed the task (a one-off advances to `paid`),
      // reopen it. A still-open recurring series just steps its due date back.
      if (task.status == TaskStatus.paid) {
        task
          ..status = TaskStatus.open
          ..statusChangedAt = null;
      }
    }
    _syncGoalLatches();
    notifyListeners();
  }

  /// §8 — skip writes nothing to the Ledger. A recurring skip is recorded in
  /// [Task.skippedDates] and the series advances; a one-off is cancelled.
  /// Returns the snapshot [undoSkipTask] needs (task 065 §6b), mirroring
  /// [markTaskPaid]'s [MarkPaidResult].
  TaskSkip skipTask(Task task) {
    final prevDue = task.dueDate;
    final prevStatus = task.status;
    final prevChanged = task.statusChangedAt;
    if (task.isRecurring) {
      final skippedDay =
          DateTime(prevDue.year, prevDue.month, prevDue.day);
      // The advance drops any override on the skipped occurrence (§064 §7d);
      // capture it so Undo restores it with the due date.
      final prevOverride = task.amountOverrides[skippedDay];
      task.skippedDates = [...task.skippedDates, task.dueDate];
      _advance(task);
      notifyListeners();
      return TaskSkip(
        task: task,
        previousDue: prevDue,
        previousStatus: prevStatus,
        previousStatusChangedAt: prevChanged,
        skippedDate: skippedDay,
        previousOverride: prevOverride,
      );
    }
    task
      ..status = TaskStatus.skipped
      ..statusChangedAt = today;
    notifyListeners();
    return TaskSkip(
      task: task,
      previousDue: prevDue,
      previousStatus: prevStatus,
      previousStatusChangedAt: prevChanged,
    );
  }

  /// §6b — reverses exactly what [skipTask] did: a recurring skip drops the
  /// skipped date, restores the previous due date and any override the advance
  /// consumed; a cancelled one-off returns to its previous status.
  void undoSkipTask(TaskSkip s) {
    final task = s.task;
    if (s.skippedDate != null) {
      final d = s.skippedDate!;
      task.skippedDates = task.skippedDates
          .where((x) => !(x.year == d.year && x.month == d.month && x.day == d.day))
          .toList();
      task.dueDate = s.previousDue;
      if (s.previousOverride != null) {
        task.amountOverrides[d] = s.previousOverride!;
      }
    }
    task
      ..status = s.previousStatus
      ..statusChangedAt = s.previousStatusChangedAt;
    notifyListeners();
  }

  void _advance(Task task) {
    if (task.isRecurring) {
      task.dueDate = task.nextOccurrence(task.dueDate);
      // Overrides for occurrences the series has moved past are spent
      // (task 064 §7d) — the recorded transaction keeps its own amount.
      final dueDay =
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      task.amountOverrides.removeWhere((k, _) => k.isBefore(dueDay));
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
  /// replaced, not archived).
  void deleteTaskSeries(Task task) {
    _tasks.removeWhere((t) => t.id == task.id);
    _taskPriorStatus.remove(task.id);
    notifyListeners();
  }

  /// §1 — archive a series: end it, keep its history. No future occurrence is
  /// produced; recorded entries stay linked and the Ledger is untouched. Works
  /// from `open` or `paused`. [statusChangedAt] holds the archive date.
  void archiveTask(Task task) {
    task
      ..status = TaskStatus.archived
      ..statusChangedAt = today;
    notifyListeners();
  }

  /// §1b — restore an archived series. Exactly [resumeTask]: a recurring series
  /// resumes at the first occurrence at or after today; a one-off returns as
  /// overdue if its date has passed.
  void restoreTask(Task task) => resumeTask(task);

  /// The date [restoreTask] would land a recurring series on, computed without
  /// mutating it (task 065 §5 — the "Continues from" / "Back as overdue" line).
  DateTime restoreDueDate(Task task) {
    if (!task.isRecurring) return task.dueDate;
    var d = task.dueDate;
    var guard = 0;
    while (DateTime(d.year, d.month, d.day).isBefore(_todayDay) &&
        guard++ < 600) {
      final next = task.nextOccurrence(d);
      if (!next.isAfter(d)) break;
      d = next;
    }
    return d;
  }

  /// §3 — remove a task for good. The Ledger keeps every entry (only the
  /// `recurrenceTaskId` link is nulled, as [_purgeTasks] does). Returns the
  /// snapshot [undoDeleteForGood] needs to re-insert it identically (§3a).
  TaskDeletion deleteTaskForGood(Task task) {
    final txnIds = [
      for (final t in _txns)
        if (t.recurrenceTaskId == task.id) t.id,
    ];
    _purgeTasks({task.id});
    notifyListeners();
    return TaskDeletion(task: task, linkedTxnIds: txnIds);
  }

  /// §3a — Undo a [deleteTaskForGood]: re-insert the task exactly as it was
  /// (its object is unchanged) and re-link the transactions the purge unlinked.
  void undoDeleteForGood(TaskDeletion snapshot) {
    if (_tasks.any((t) => t.id == snapshot.task.id)) return;
    _tasks.add(snapshot.task);
    final ids = snapshot.linkedTxnIds.toSet();
    for (final t in _txns) {
      if (ids.contains(t.id)) t.recurrenceTaskId = snapshot.task.id;
    }
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
