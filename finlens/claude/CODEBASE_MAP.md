# FinLens — Codebase Map

Survey date: 2026-08-16. Read-only pass; nothing in the app was modified.

> **Note on the premise.** The task brief says "Several of those specs already
> exist in the repo under `claude/*.md`." **They do not.** There was no `claude/`
> directory in the repo before this file was written — I created it to hold this
> map. The only pre-existing Claude-related path is `.claude/settings.local.json`
> (permissions config, no specs). The code carries dense references to a
> "Tech Spec v1.1" with numbered sections (1.1, 3.4, 6.2 …) in doc comments, and
> a "FinLens · Tech Spec v1.1" footer on the More tab, but **that document is not
> in the repo.** If you intended to drop spec files in, they did not land.
>
> Some of that spec's section numbering is in Turkish (`"Yön ≠ renk"`,
> `"Starting balance kilidi"`, `"Tek özet kuralı"`), so the source document is
> presumably bilingual.

---

## 0 · Executive summary

- **The project does not currently compile.** `flutter analyze` reports 3
  **errors** (not warnings) in one file, and 5 of the 6 test files fail to load
  as a result. See §1.3 / §1.4. This must be resolved before any spec work
  begins.
- **There is effectively no persistence layer.** The app is an in-memory
  `ChangeNotifier` seeded from a hard-coded fixture file on every launch.
  `shared_preferences` is a dependency but is used by exactly one class, which
  is itself never wired into a screen.
- **Architecture is clean, conventions are strong, and comments are unusually
  good.** Almost every non-obvious decision has a rationale comment. Match that
  register when adding code.
- There are **two parallel Ledger implementations** with different row widgets,
  different day-grouping code, and **opposite sign conventions**. This is the
  single biggest hazard for the specs ahead.

---

## 1 · Project shape

### 1.1 SDK and dependencies

| Item | Value |
|---|---|
| Dart SDK constraint | `^3.12.2` (`pubspec.yaml`) |
| Flutter (installed) | 3.44.9 stable, Dart 3.12.2, engine `5a2a6a42cc` |
| App version | `1.0.0+1` |
| Package name | `finlens`, `publish_to: none` |

Runtime dependencies — there are only three, all trivial:

| Package | Version | What it is actually used for |
|---|---|---|
| `flutter` | sdk | — |
| `cupertino_icons` | `^1.0.8` | **Not referenced anywhere in `lib/`.** Left over from `flutter create`. Every icon in the app comes from Material (`Icons.*_rounded`) or is hand-drawn with `CustomPainter`. |
| `shared_preferences` | `^2.5.5` | Imported by exactly one file: [balance_filter.dart](lib/features/balance/balance_filter.dart) — and that class is never used by any screen (§2.3). |

Dev dependencies: `flutter_test` (sdk), `flutter_lints ^6.0.0`.

**There is no `intl`, no `freezed`, no `json_serializable`, no `build_runner`,
no state-management package, and no database package.** This is deliberate —
[formatters.dart:1](lib/core/utils/formatters.dart:1) states currency
formatting is "Kept dependency-free (no intl) so the money rendering matches the
mockups exactly". No code generation step exists; there are no `*.g.dart` or
`*.freezed.dart` files.

### 1.2 Directory layout and architecture

**Feature-first, with a shared core.** Not clean architecture — there is no
domain/data/presentation split, no use-cases, no repository interfaces.

```
lib/
  main.dart                 runApp(FinLensApp(store: buildSeedStore()))
  theme/                    app_colors · app_typography · app_theme (tokens)
  core/
    models/                 enums.dart · models.dart      (all 5 entities)
    store/app_store.dart    the single ChangeNotifier + StoreScope (DI)
    data/seed_data.dart     hard-coded fixture -> buildSeedStore()
    utils/                  fx.dart · formatters.dart · date_range.dart
  shared/widgets/           cross-feature widgets (11 files)
  features/
    shell/                  AppShell — IndexedStack + bottom nav
    balance/                Balance tab, Assets/Liabilities, account detail,
                            edit account, balance_filter (unused), widgets/
    ledger/                 TWO ledgers: ledger_screen (tab) and
                            scoped_ledger_screen (drill-down), + widgets/
    planner/                Planner tab, edit budget/goal/task, archive
    insight/                Insight tab
    more/                   More tab
    quick_add/              the universal add/edit form + all pickers
test/                       6 files, flutter_test only
```

Total ~17.2k lines across 55 Dart files. Largest:
`quick_add_sheet.dart` (1224), `pickers.dart` (946), `app_store.dart` (919),
`balance_screen.dart` (901), `planner_screen.dart` (849).

**Layering rule observed in practice:** `features/*` may import `core/*`,
`shared/*` and `theme/*`. `shared/*` imports `core/*` and `theme/*`. `core/*`
imports only `theme/app_colors.dart` (enums carry their own colours). Two
cross-feature imports break the pattern and are worth knowing about:

- [ledger_screen.dart:14](lib/features/ledger/ledger_screen.dart:14),
  [account_detail_screen.dart:13](lib/features/balance/account_detail_screen.dart:13)
  and [planner_screen.dart:13](lib/features/planner/planner_screen.dart:13) all
  do `import '../balance/balance_screen.dart' show EmptyState;` — a genuinely
  shared widget that lives in a feature file.
- [balance_screen.dart](lib/features/balance/balance_screen.dart) imports from
  `../ledger/`.

### 1.3 Lint setup and `flutter analyze` status

[analysis_options.yaml](analysis_options.yaml) is the **stock `flutter create`
file, completely unmodified** — `include: package:flutter_lints/flutter.yaml`
with an empty `rules:` block (only commented-out examples). No custom lints, no
`errors:` overrides, no excludes.

**`flutter analyze` is NOT clean. It reports 3 issues, and all 3 are `error`
severity, not warnings:**

```
error • The named parameter 'group' is required, but there's no corresponding argument
      • lib/features/ledger/scoped_ledger_screen.dart:406:38 • missing_required_argument
error • The named parameter 'date' isn't defined
      • lib/features/ledger/scoped_ledger_screen.dart:408:11 • undefined_named_parameter
error • The named parameter 'rows' isn't defined
      • lib/features/ledger/scoped_ledger_screen.dart:409:11 • undefined_named_parameter
```

**Cause — a half-finished refactor.**
[LedgerDayCard](lib/features/ledger/widgets/ledger_txn_row.dart:16) was changed
to take a single `required DayGroup group` (the `DayGroup` class in
[ledger_scope.dart:236](lib/features/ledger/ledger_scope.dart:236) bundles
`date` + `rows` and owns the `total` / `showsDayTotal` logic). The one call site
at [scoped_ledger_screen.dart:406](lib/features/ledger/scoped_ledger_screen.dart:406)
still passes the old `date:` / `rows:` pair. The caller also still does its own
`byDay` grouping into a raw `Map<DateTime, List<ScopedTxn>>` instead of building
`DayGroup`s.

Fixing this is a ~6-line change, but **it is a pre-existing defect, not part of
any spec** — flagging per the working agreement rather than fixing.

### 1.4 Test suite

`test/`, plain `flutter_test` (`testWidgets` + `test`). No `mockito`, no golden
files, no integration tests, no `coverage/`.

| File | Tests | Covers |
|---|---|---|
| `widget_test.dart` | 13 | Net worth = assets − liabilities; derived balances; budget removal keeps category; task skip/pay semantics; rebalance isolation; transfer fee on top; account archived-not-deleted; Spendable default-open; group order; privacy mask |
| `balance_filter_test.dart` | 17 | `BalanceFilter` toggle state machine, acceptance fixtures, stale-id pruning |
| `ledger_layout_test.dart` | ~8 | No-overflow at 3 widths × 3 scopes; 216px action strip fits 320pt; row height 66 vs 52 by scope; sign consistency; range-label compression; internal-transfer exclusion |
| `direction_signs_test.dart` | ~8 | `signless` formatter semantics; period-chip arrows; in-left/out-right ordering; unsigned rows vs signed balances; **WCAG contrast ≥ 4.5:1 against the card background** |
| `quick_add_layout_test.dart` | ~8 | Per-type no-overflow at 3 widths; save-button blocker messages; right-edge alignment; relative-date labels; dimmed zero state |
| `balance_group_row_test.dart` | 3 | Group/child amounts share a right edge; two tap zones per row; amount-side taps navigate, name-side does not |

**Current state: 5 of the 6 files fail to load.** Anything that transitively
imports `scoped_ledger_screen.dart` (i.e. anything reaching `main.dart` or
`balance_screen.dart`) fails to compile because of §1.3. Only
`balance_filter_test.dart` runs, and it passes 17/17.

```bash
flutter test test/balance_filter_test.dart
```

Note the suite's real character: **these are largely layout and
design-invariant tests, not business-logic tests.** They assert pixel heights,
right-edge alignment, overflow-freedom, and colour contrast. Expect specs to
ask for more of the same, and expect additive UI work to break them easily.

### 1.5 Platform targets and minimum width

All six platform folders are scaffolded (`android`, `ios`, `linux`, `macos`,
`web`, `windows`), all from the default `flutter create` — none have been
customised. iOS `IPHONEOS_DEPLOYMENT_TARGET = 13.0`; Android uses
`flutter.minSdkVersion` / `flutter.targetSdkVersion` defaults.

**In practice this is a portrait phone app.** Evidence:

- `AppTheme` only defines `.dark`; `MaterialApp` sets `theme:` with no
  `darkTheme` and no `themeMode` (§5).
- Layout tests pin three viewports: **390×844, 360×640, and 320×568**.
  [ledger_layout_test.dart](test/ledger_layout_test.dart) and
  [quick_add_layout_test.dart](test/quick_add_layout_test.dart) both assert
  no-overflow at all three.
- **Minimum assumed width: 320pt.** The swipe-action strip is explicitly tested
  to fit a 320pt row ("the 216px action strip fits a 320pt row").
- There is **no landscape handling, no `LayoutBuilder`-driven breakpoint, no
  tablet layout, and no `MediaQuery` width branching anywhere.** Adding a fourth
  button to any header row will fail the 320pt tests before it fails anywhere
  else.

---

## 2 · State management and data flow

### 2.1 Approach

**A single `ChangeNotifier` (`AppStore`) distributed by a hand-rolled
`InheritedNotifier`, plus local `setState` for per-screen UI state.** No
package. This is consistent across the entire app — I found no Bloc, no
Riverpod, no `provider`, no `ValueNotifier`-based screen state (except two
module-private notifiers in `swipe_actions.dart` used as a global "which row is
open" latch).

[app_store.dart:903](lib/core/store/app_store.dart:903):

```dart
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>      // subscribes + rebuilds
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) =>    // no subscription
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
```

The `of` / `read` split is meaningful and used correctly — `read` in callbacks
that only mutate, `of` in `build`. **Preserve this distinction.**

**Division of responsibility, consistently applied:** `AppStore` owns all
*data* and everything derived from it. Screens own their own *view* state with
`setState` — Balance holds `_section`, `_sort`, `_searching`, `_query`,
`_opened`/`_closed`; ScopedLedger holds `_scope`, `_range`, `_filter`. Two
exceptions where view state lives in the store because it is shared across tabs:
`masked` (privacy), `asOf` (reporting date), `period` (month, shared by Ledger
tab + Planner + Insight) and `comparePeriod`.

`AppStore` is constructed once in `main()` and never replaced.

### 2.2 Persistence layer

**There is none, for application data.** This is the most important thing to
know about this codebase.

- [main.dart:11](lib/main.dart:11): `runApp(FinLensApp(store: buildSeedStore()))`
- [seed_data.dart](lib/core/data/seed_data.dart) is a 774-line hard-coded
  fixture: 24 accounts, 24 transactions, 14 categories, plus goals and tasks,
  with semantic ids (`'a-cash-usd'`, `'c-groceries'`) and dates pinned to
  August 2026.
- Every mutation goes into an in-memory `List` and calls `notifyListeners()`.
  **Nothing is written to disk. Every launch resets to the seed.**
- [scoped_ledger_screen.dart:44](lib/features/ledger/scoped_ledger_screen.dart:44)
  says so outright: *"Held in memory rather than on disk: the project has no
  persistence layer, and adding one would reach past this screen's scope."*
- `seed_data.dart` is explicitly designed as the seam:
  *"This is the only file that knows the data is fake — swapping it for a
  repository backed by an API means replacing `buildSeedStore` alone."*

**The one real read/write in the app** — `SharedPreferences`, two JSON-encoded
string keys, in
[balance_filter.dart:168](lib/features/balance/balance_filter.dart:168):

```dart
// WRITE
Future<void> save() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_groupsKey, jsonEncode(hiddenGroups.map((g) => g.name).toList()));
  await prefs.setString(_accountsKey, jsonEncode(hiddenAccountIds.toList()));
}

// READ
static Future<BalanceFilter> load(AppStore store) async {
  final prefs = await SharedPreferences.getInstance();
  return fromStored(
    groups:   _decode(prefs.getString(_groupsKey)),    // 'balance_filter_hidden_categories'
    accounts: _decode(prefs.getString(_accountsKey)),  // 'balance_filter_hidden_accounts'
    store: store,
  );
}
```

`_decode` catches `FormatException` and falls back to "nothing hidden";
`fromStored` prunes ids that no longer match a live account. Both behaviours are
tested. **Neither `load()` nor `save()` is ever called** (§2.3).

Also note: `Category.icon` / `Category.color` and `Account.icon` are
`IconData` / `Color` — **Flutter framework types stored directly on the model**.
Any future serialisation will have to solve icon/colour codec, and `IconData`
does not survive tree-shaking of icon fonts without `--no-tree-shake-icons`.

### 2.3 Multiple profiles / users

**Not supported, and nothing is scoped for it.** There is no user, profile,
account-holder, or workspace concept anywhere in the models or the store.

The two `SharedPreferences` keys are **global, flat, and unscoped**:
`'balance_filter_hidden_categories'` and `'balance_filter_hidden_accounts'`.
There is no key prefix, namespace, or profile id. Adding profiles later means
migrating those keys.

> ⚠️ **`BalanceFilter` is fully implemented, fully tested (17 tests), and
> completely unwired.** Grepping `lib/` for `BalanceFilter` outside its own file
> returns **nothing** — only `test/balance_filter_test.dart` references it.
> `BalanceScreen` does its own filtering with `_section` / `_query` and never
> mentions it. It looks like a spec was implemented bottom-up and the UI
> integration never landed. If a coming spec asks for Balance filtering,
> **check whether it wants this class wired up rather than a new one built.**

### 2.4 The "repository layer"

There is no repository. `AppStore` is the query surface. Everything is a linear
scan over `List<Txn>`; **there are no indices, no maps keyed by id, no caches.**
Even the id lookups are `for` loops:

```dart
Account? accountById(String? id) {
  for (final a in _accounts) { if (a.id == id) return a; }   // O(n)
  return null;
}
```

Query methods available on `AppStore`:

| Method | Signature | Notes |
|---|---|---|
| `accountById` / `categoryById` / `goalById` / `taskById` | `(String?) -> T?` | O(n) linear scan |
| `refName` / `refIcon` / `refColor` | `(String) -> …` | Resolves a polymorphic ref by trying account then category |
| `txns` | `-> List<Txn>` | **Copies and re-sorts the whole list on every access** |
| `txnsForAccount` | `(String) -> List<Txn>` | `fromRef == id \|\| toRef == id` |
| `txnsInMonth` | `(DateTime) -> List<Txn>` | Year+month equality |
| `balanceOf` | `(String) -> double` | Full scan of all txns, respects `asOf` cutoff |
| `runningBalanceAt` | `(String, Txn) -> double` | Full scan; **ignores the `asOf` cutoff** (inconsistent with `balanceOf`) |
| `balanceInBase` | `(String) -> double` | `balanceOf` then `Fx.toBase` |
| `groupTotal` / `groupCount` / `accountsIn` / `groupShare` | `(AccountGroup) -> …` | |
| `groupActivity` / `accountActivity` | `(…) -> double` | **O(txns × accounts)** and O(txns) |
| `netWorthDelta` | `-> double` | **O(txns × accounts)** |
| `utilisationOf` | `(String) -> double?` | |
| `monthIncome` / `monthExpense` / `monthLeftOverFraction` | `(DateTime) -> double` | |
| `spentInCategory` | `(String categoryId, DateTime month) -> double` | expense only, `toRef == categoryId` |
| `earnedInCategory` | `(String categoryId, DateTime month) -> double` | income only, `fromRef == categoryId` |
| `txnCountForCategory` | `(String) -> int` | **ignores direction and date entirely** |
| `balanceWithout` / `categorySpendWithout` | | For delete-confirmation impact lines |

**Can transactions be queried by `(categoryId, direction, dateRange)`?**

**Not as such — no.** The closest things are:

- `spentInCategory(categoryId, month)` = (category, direction=expense, **whole
  calendar month only**).
- `earnedInCategory(categoryId, month)` = (category, direction=income, whole
  month only).

Both are hard-wired to a single calendar month via `txnsInMonth`, and both
return a **summed `double`, not the matching rows**. There is no way to ask for
a category's transactions over an arbitrary `DateRange`, and no way to get the
row list back.

The one component that *does* handle arbitrary date ranges and direction is
[`LedgerQuery`](lib/features/ledger/ledger_scope.dart:115) — but it is scoped by
**account**, not category (`scope.accountsIn(store)` builds a `Set<String>` of
*account* ids), and it lives in the ledger feature, not the core.

**So: a spec asking for "category detail with a period selector" has no query
to call.** It will need either a new `AppStore` method or a category-flavoured
`LedgerScope`. Worth deciding once, deliberately, rather than per-screen.

---

## 3 · Domain models

All five entities live in two files: [enums.dart](lib/core/models/enums.dart)
(117 lines) and [models.dart](lib/core/models/models.dart) (317 lines).
`models.dart` re-exports `enums.dart`, so `import '../models/models.dart'` gets
everything.

**All models are hand-written.** None are code-generated — there is no
`freezed`, no `json_serializable`, no `build_runner`, no `part` directives.
There is **no `toJson`/`fromJson` on any model.**

**All models are mutable.** Fields are bare `var`-style public fields mutated in
place by the store using cascade syntax (`account..name = …..hidden = …`). Only
identity/audit fields are `final`. The rationale is in
[app_store.dart:495](lib/core/store/app_store.dart:495): *"Because balances are
derived, mutating in place is enough."* Only `Account` has a `copyWith`, and it
is never called from `lib/`.

**Every id is `String`.** Two id conventions coexist: seed data uses semantic
ids (`'a-cash-usd'`, `'c-groceries'`), and runtime creation uses
[`_nextId`](lib/core/store/app_store.dart:33) — a monotonic counter starting at
1000 with a one-letter prefix: `t`=txn, `a`=account, `c`=category, `g`=goal,
`k`=task. So a new transaction gets `'t1000'`. **The counter is not persisted and
resets to 1000 on every launch** (harmless today because nothing persists).

### 3.1 Account category → `Category`

| | |
|---|---|
| Class | `Category` |
| File | [models.dart:84](lib/core/models/models.dart:84) |
| ID field / type | `final String id` |
| Amount fields | `double? monthlyBudget` (null = not budgeted), `double rolloverAmount`, `double warnThreshold` (0..1, default 0.8) |
| Direction | `CategoryType type` — `expense` \| `income`. No sign on the model. |
| Date field | `DateTime? removedOn` (budget-removal tombstone). No created/updated date. |
| FK links | **None outbound.** Categories are referenced *by* `Txn.fromRef`/`toRef` and `Task.categoryId`. |
| Presentation on model | `IconData icon`, `Color color` — Flutter types on the domain model |
| Derived | `double? get effectiveLimit => monthlyBudget + (budgetRollover ? rolloverAmount : 0)` |

Note the design decision, stated at
[models.dart:81](lib/core/models/models.dart:81): **the budget *is* fields on
the category, not a separate `Budget` entity.** "Removing a budget" =
`monthlyBudget = null` + `removedOn = today`; the category and its transactions
are untouched. `AppStore.budgetedCategories` is literally
`categories.where((c) => c.monthlyBudget != null)`.

**Terminology warning:** the task brief says "account category". In this
codebase, the thing that groups accounts is **`AccountGroup`** (an enum, §3.2),
and **`Category`** is the *transaction* category (Groceries, Salary). They are
unrelated. `BalanceFilter`'s persistence key is even named
`'balance_filter_hidden_categories'` while storing `AccountGroup`s — a naming
collision already baked into a stored key.

### 3.2 `AccountGroup` (the Balance-screen "category rows")

Not a class — an **enum with attached data**,
[enums.dart:7](lib/core/models/enums.dart:7):

```dart
enum AccountGroup {
  spendable, receivables, investments, valuables,   // assets
  creditCards, payables, bankLoans;                 // liabilities
  final String label; final Color color; final IconData icon;
  bool get isAsset => index <= AccountGroup.valuables.index;   // ordinal-based!
  bool get isLiability => !isAsset;
  bool get hasCreditLimit => this == creditCards || this == bankLoans;
  bool get hasStatement => this == creditCards;
}
```

⚠️ **`isAsset` is defined by declaration order** (`index <= valuables.index`).
Inserting a new group in the wrong position silently reclassifies it. Both
`AccountGroup.assets` and `AccountGroup.liabilities` derive from this, as does
net worth.

There is **no `id`** — groups are keyed by the enum itself (`BalanceFilter`
comments on this explicitly). Group order is treated as **screen structure, not
data**: [balance_screen.dart:568](lib/features/balance/balance_screen.dart:568)
says *"groups are screen structure, not data, so no sort option ever touches
it."*

### 3.3 Account

| | |
|---|---|
| Class | `Account` |
| File | [models.dart:11](lib/core/models/models.dart:11) |
| ID field / type | `final String id` |
| Amount | `final double startingBalance` — **write-once**; live balance is always derived (`startingBalance + Σ txns`). `double? creditLimit`. |
| Sign convention | **Liability accounts hold negative balances throughout the app.** Enforced at creation: [app_store.dart:551](lib/core/store/app_store.dart:551) `final signed = group.isLiability ? -startingBalance.abs() : startingBalance;` |
| Date field | `final DateTime? openedOn` — null means "always" (seed accounts predate the ledger); an account opened after the `asOf` cutoff is filtered out of `accounts`. |
| FK links | `AccountGroup group` (enum, not an id) |
| Other | `String currency`, `bool hidden` / `archived` / `countAsSpendable`, `int? statementDay` / `paymentDue`, `IconData? icon` |
| Derived | `displayIcon` (falls back to `group.icon`), `color` (= `group.color`), `isAsset`, `isLiability` |

`hidden` vs `archived` are distinct: **hidden accounts leave the lists but stay
in the totals** (`accounts` includes them, `visibleAccounts` does not, and
`groupTotal` sums `accounts`). `archived` removes them from both.

### 3.4 Transaction

| | |
|---|---|
| Class | `Txn` (**not** `Transaction`) |
| File | [models.dart:121](lib/core/models/models.dart:121) |
| ID field / type | `final String id` |
| Amount | `double amount` — **always a positive magnitude**; direction comes from `type` + which ref matches. Plus `double? toAmount` (cross-currency destination), `double? fee`, `bool feeFromSource`, `double? exchangeRate`. |
| Direction/sign | `final TxnType type` — `expense` \| `income` \| `transfer` \| `rebalance`. **Sign is never stored.** |
| Date field | `DateTime date` (mutable) + `final DateTime createdAt` (defaults to `date`) |
| FK links | `String fromRef` / `String toRef` — **polymorphic**, plus `String? goalId` |
| Audit | `int editedCount`, incremented by `updateTxn` |
| Other | `List<String> tags`, `String note`, `String currency` |
| Derived | `bool get movesCash => type != TxnType.rebalance` |

**The polymorphic ref rule** — critical, and the source of most of the app's
`switch`es:

| Type | `fromRef` | `toRef` |
|---|---|---|
| `expense` | **Account** id | **Category** id |
| `income` | **Category** id | **Account** id |
| `transfer` | Account id | Account id |
| `rebalance` | (unused) | **Account** id |

`refName` / `refIcon` / `refColor` resolve a ref by trying `accountById` then
`categoryById`, falling back to `'—'` / `Icons.circle` / `Colors.grey`.

**The one place ledger sign rules live** —
[`_effectOn`](lib/core/store/app_store.dart:195). Everything numeric funnels
through it:

```dart
double _effectOn(Txn t, String accountId) {
  switch (t.type) {
    case TxnType.expense:  return t.fromRef == accountId ? -t.amount : 0;
    case TxnType.income:   return t.toRef   == accountId ?  t.amount : 0;
    case TxnType.transfer:
      if (t.fromRef == accountId) return -(t.amount + (t.feeFromSource ? (t.fee ?? 0) : 0));
      if (t.toRef   == accountId) return (t.toAmount ?? t.amount) - (t.feeFromSource ? 0 : (t.fee ?? 0));
      return 0;
    case TxnType.rebalance: return t.toRef == accountId ? t.amount : 0;  // delta, signed
  }
}
```

`rebalance` is the exception: its `amount` is a **signed delta**, not a
magnitude, and it is deliberately excluded from income/expense metrics.

### 3.5 Transfer type

**There is no separate transfer class.** A transfer is `Txn` with
`type == TxnType.transfer`, using the cross-currency fields
(`toAmount`, `exchangeRate`) and the fee fields (`fee`, `feeFromSource`).
`feeFromSource: true` (default) deducts the fee from the source *on top of*
`amount`; `false` deducts it from what the destination receives.

A second "transfer-ish" concept exists in the ledger:
[`FlowKind`](lib/features/ledger/ledger_scope.dart:59) —
`inflow` / `outflow` / **`internal`**. A transfer is `internal` **only when both
ends are inside the current scope**, in which case it contributes 0 to day nets
and is excluded from In/Out totals. The same transfer is grey in a group ledger
and red in one of its accounts — documented as intentional at
[ledger_scope.dart:159](lib/features/ledger/ledger_scope.dart:159).

### 3.6 Goal and Task (secondary, Planner-only)

- **`Goal`** — [models.dart:171](lib/core/models/models.dart:171). `final String
  id`; `double targetAmount` / `double saved`; `String linkedAccountId` (FK to
  Account); `GoalType` (saving/milestone/purchase); `GoalStatus`
  (active/reached/abandoned); `DateTime? targetDate` / `completedAt` /
  `stoppedAt` / `final createdAt`; auto-contribute fields. Derived:
  `remaining`, `progress`, `isComplete`, `monthlyNeeded`, `monthsLeft`,
  `durationMonths`.
- **`Task`** — [models.dart:239](lib/core/models/models.dart:239). `final String
  id`; **`double expectedAmount` where the sign IS meaningful** (negative =
  pay-out, positive = pay-in) — the only model where a sign is stored;
  `String linkedAccountId` + `String? categoryId` (FKs); `DateTime dueDate`;
  `RepeatFrequency repeats` + `List<DateTime> skippedDates`. A recurring
  obligation is **one record plus a repeat rule**, never spawned rows; skipping
  appends to `skippedDates` and advances `dueDate`.

`Goal.saved` is a **stored** figure, unlike every account balance in the app
(§7).

---

## 4 · Money and currency

### 4.1 Storage and conversion

Base currency is `USD`, hard-coded at
[fx.dart:8](lib/core/utils/fx.dart:8). The whole FX layer is 30 lines:

```dart
abstract final class Fx {
  static const baseCurrency = 'USD';
  static const _perUnit = <String, double>{
    'USD': 1.0, 'EUR': 1.10, 'GBP': 1.28, 'TRY': 0.031, 'JPY': 0.0067,
  };
  static double rate(String from, String to) => (_perUnit[from] ?? 1.0) / (_perUnit[to] ?? 1.0);
  static double toBase(double amount, String currency) => amount * (_perUnit[currency] ?? 1.0);
  static double convert(double amount, String from, String to) => amount * rate(from, to);
}
```

Rates are **fixed constants**, standing in for a live feed. An unknown currency
silently converts at 1.0.

**Is there a single conversion path? No — there are three, and one class of
aggregate skips conversion entirely.** This is the most consequential finding in
this section.

**Path A — account balances (the intended one).**
`balanceOf(id)` sums raw `t.amount` via `_effectOn`, then `balanceInBase(id)`
multiplies the *whole resulting balance* by **the account's** currency rate.
Everything asset-side flows through this: `groupTotal` → `totalAssets` /
`totalLiabilities` → `netWorth`, `spendable`, `groupShare`, `liabilityRatio`,
`BalanceFilter.filteredTotal`.

⚠️ **This assumes `Txn.currency` always equals the account's currency.**
`_effectOn` never looks at `t.currency`. A USD transaction booked against a EUR
account will be converted as though it were EUR. Nothing enforces the
assumption — `addTxn` takes `currency` as a free parameter.

**Path B — the ledger.**
[`LedgerQuery._resolve`](lib/features/ledger/ledger_scope.dart:148) calls
`Fx.toBase(t.amount, currency)` **per transaction**, where `currency` is taken
from whichever account the row touches. Same assumption, different granularity
(per-row rather than per-balance). `groupActivity` / `accountActivity` /
`netWorthDelta` also convert per-effect this way.

**Path C — no conversion at all.** These sum raw `t.amount` **across
currencies** with no `Fx` call anywhere:

- [`monthIncome`](lib/core/store/app_store.dart:353) / [`monthExpense`](lib/core/store/app_store.dart:357) → and therefore `monthLeftOverFraction`
- [`spentInCategory`](lib/core/store/app_store.dart:370) / [`earnedInCategory`](lib/core/store/app_store.dart:374) → and therefore `totalSpentAgainstBudget`, `leftToSpend`, `projectedOverspend`, all Planner budget bars, and Insight's "Where it went"
- `Goal.saved`, `totalSaved`, `totalGoalTarget`, `goalRemaining`
- `Task.expectedAmount`, `comingIn`, `goingOut`, `overdueAmount`

So **the Balance tab is FX-correct and the Ledger tab is FX-correct, while
Planner budgets, Insight, Goals and Schedule silently add EUR to USD.** With the
current seed data (mostly USD, a couple of EUR/TRY accounts) this is visible but
subtle. **Reporting, not fixing.**

Also unused: `Txn.exchangeRate` is stored and editable in Quick Add but is never
read by any balance calculation — only `toAmount` is. `Fx.convert` and
`Fx.rate` are used only by the Quick Add preview line.

### 4.2 The amount formatter(s)

**Yes — there is one shared function, and it is used with real discipline. I
found no ad-hoc `+`/`−` string prepending anywhere in `lib/`** (I grepped for
literal sign concatenation and for the true-minus glyph `−` outside
`formatters.dart`; zero hits).

Two layers:

**Layer 1 — [`money()`](lib/core/utils/formatters.dart:29)**, the pure function.

```dart
String money(double value, {
  String currency = 'USD',
  bool showSign = false,      // prepend '+' on positives
  bool forceDecimals = false,
  bool masked = false,        // privacy mode -> "$••••"
  bool signless = false,      // drop BOTH signs
})
```

Sign resolution is one line:
`final sign = signless ? '' : (negative ? '−' : (showSign ? '+' : ''));`
Note it uses a **true minus U+2212**, not a hyphen. Decimals appear only when
the value is fractional *and* `< 1000` (headline figures stay whole).
Companions: `moneyCompact()` ("$8.4K"), `percent()`, `signedPercent()`.

**Layer 2 — [`AmountText`](lib/shared/widgets/amount_text.dart:10)**, the
widget. Wraps `money()` and adds one thing: it reads `StoreScope.of(context).masked`
so **no screen has to remember to mask**. It has a named constructor
`AmountText.balance(...)` which forces `signless: true, showSign: false` —
encoding the rule *"a balance is never signed; colour carries asset vs debt."*

**Prefer `AmountText` in new code.** Raw `money()` is correct only where there
is no `BuildContext`/store (semantics labels, string interpolation), and in
those cases the call site must pass `masked:` by hand.

#### Every call site

**`AmountText` / `AmountText.balance` — 31 sites**

| File | Lines |
|---|---|
| [balance_screen.dart](lib/features/balance/balance_screen.dart) | 261 (`.balance`), 730 (`.balance`), 797 (`.balance`) |
| [account_rows.dart](lib/features/balance/widgets/account_rows.dart) | 131 (`.balance`), 329 (`.balance`) |
| [account_detail_screen.dart](lib/features/balance/account_detail_screen.dart) | 148, 220, 259, 269 |
| [assets_screen.dart](lib/features/balance/assets_screen.dart) | 82 |
| [ledger_screen.dart](lib/features/ledger/ledger_screen.dart) | 317 (**`showSign: true`**), 476 |
| [txn_row.dart](lib/shared/widgets/txn_row.dart) | 141, 154, 180 (**`showSign: true`**), 198 |
| [planner_screen.dart](lib/features/planner/planner_screen.dart) | 160, 330, 410, 565, 621, 637, 797 (**`showSign: true`**) |
| [archive_screen.dart](lib/features/planner/archive_screen.dart) | 84 |
| [edit_goal_screen.dart](lib/features/planner/edit_goal_screen.dart) | 202, 209 |
| [insight_screen.dart](lib/features/insight/insight_screen.dart) | 56, 126 |
| [pickers.dart](lib/features/quick_add/pickers.dart) | 159 |

(`amount_hero.dart:104/208` defines a *private* `_AmountText` — the Quick Add
digit-by-digit hero, unrelated to the shared widget.)

**Raw `money()` — 50 sites**

| File | Lines |
|---|---|
| [amount_text.dart](lib/shared/widgets/amount_text.dart) | 48 *(the wrapper itself)* |
| [scoped_ledger_screen.dart](lib/features/ledger/scoped_ledger_screen.dart) | 240 |
| [ledger_txn_row.dart](lib/features/ledger/widgets/ledger_txn_row.dart) | 74, 77, 179, 289, 306 |
| [period_row.dart](lib/features/ledger/widgets/period_row.dart) | 187 |
| [account_rows.dart](lib/features/balance/widgets/account_rows.dart) | 75, 358 |
| [account_detail_screen.dart](lib/features/balance/account_detail_screen.dart) | 172 |
| [edit_account_screen.dart](lib/features/balance/edit_account_screen.dart) | 131, 321 |
| [txn_row.dart](lib/shared/widgets/txn_row.dart) | 164, 275, 276, 288 |
| [quick_add_sheet.dart](lib/features/quick_add/quick_add_sheet.dart) | 450, 507, 516 (**`showSign: true`**), 539 (**`showSign: true`**), 625, 651, 701 |
| [pickers.dart](lib/features/quick_add/pickers.dart) | 312, 313, 818 |
| [planner_screen.dart](lib/features/planner/planner_screen.dart) | 168, 203, 240, 241, 332, 348, 361, 417, 435, 508, 570, 652 |
| [edit_budget_screen.dart](lib/features/planner/edit_budget_screen.dart) | 100, 147, 167, 168, 253, 254 |
| [edit_goal_screen.dart](lib/features/planner/edit_goal_screen.dart) | 123, 146, 174, 288 |
| [edit_task_screen.dart](lib/features/planner/edit_task_screen.dart) | 353 |
| [archive_screen.dart](lib/features/planner/archive_screen.dart) | 101, 102 |
| [insight_screen.dart](lib/features/insight/insight_screen.dart) | 69 |

**`moneyCompact()` — 2 sites:**
[period_row.dart:215](lib/features/ledger/widgets/period_row.dart:215),
[pickers.dart:304](lib/features/quick_add/pickers.dart:304).

**`showSign: true` — only 5 sites total**, listed in bold above. Everything else
is either unsigned-by-colour or negative-only. This is a deliberate,
consistently-held rule (§5, `"Yön ≠ renk"`) that
[direction_signs_test.dart](test/direction_signs_test.dart) exists to protect.

---

## 5 · Design system

### 5.1 Token files

**Yes — a real, complete token system in `lib/theme/`, and screens honour it.**

| File | Holds |
|---|---|
| [app_colors.dart](lib/theme/app_colors.dart) | `AppColors` — ~55 semantic colour constants. Header comment: *"Semantic names only; screens never hard-code hex values."* |
| [app_typography.dart](lib/theme/app_typography.dart) | `AppText` — 24 named `TextStyle`s. Amount styles all carry `FontFeature.tabularFigures()`. |
| [app_theme.dart](lib/theme/app_theme.dart) | `Insets` (spacing), `Radii` (radii), and `AppTheme.dark` (the `ThemeData`) |

```dart
abstract final class Insets { xs=4, sm=8, md=12, lg=16, xl=20, xxl=28, gutter=20 }
abstract final class Radii  { sm=8, md=12, card=16, sheet=22, pill=999 }
```

`Insets.gutter` (20) is the horizontal page gutter used by every screen so
headers, toolbars and rows align pixel-for-pixel.

**Compliance is good but not total.** The Balance feature is near-perfect. The
Ledger feature is the outlier: `scoped_ledger_screen.dart`,
`ledger_txn_row.dart` and `period_row.dart` use **raw numeric padding
(`EdgeInsets.fromLTRB(18, 2, 18, 12)`, `horizontal: 16`, `height: 52/66`) and
inline `TextStyle` literals** rather than `Insets` / `AppText`. There are also a
few inline `Color(0xFF…)` literals in row widgets
([ledger_txn_row.dart:197/203](lib/features/ledger/widgets/ledger_txn_row.dart:197),
[scoped_ledger_screen.dart:579](lib/features/ledger/scoped_ledger_screen.dart:579),
[account_rows.dart:67/258](lib/features/balance/widgets/account_rows.dart:67)).
**Per the working agreement I am reporting this, not normalising it** — and note
that the specs' rule "never introduce a second design-token system" means new
Ledger work should reach for `Insets`/`AppText` rather than copying the
neighbouring raw numbers, without retro-fitting the existing ones.

### 5.2 The dark palette actually in use

**The app is dark-mode only.** `AppTheme` exposes only `.dark`;
[main.dart:26](lib/main.dart:26) sets `theme: AppTheme.dark` with **no
`darkTheme` and no `themeMode`**. There is no light palette anywhere.

| Role | Token | Hex |
|---|---|---|
| App background | `AppColors.bg` | `#0A0A0B` |
| Card / surface | `AppColors.surface` | `#161618` |
| Surface (alt — sheets, pills, tool buttons) | `AppColors.surfaceAlt` | `#1C1C1E` |
| Surface (high — grab handles, progress track) | `AppColors.surfaceHigh` | `#2A2A2C` |
| Divider | `AppColors.divider` | `#2A2A2C` |
| **Accent purple (brand)** | `AppColors.accent` / `accentSoft` | `#5E5CE6` (identical values) |
| **Green (positive)** | `AppColors.positive` | `#30D158` |
| **Red (negative)** | `AppColors.negative` | `#FF453A` |
| Amber (warning) | `AppColors.warning` | `#FF9F0A` |
| Blue (info) | `AppColors.info` | `#0A84FF` |
| Text primary | `AppColors.textPrimary` | `#FFFFFF` |
| **Muted grey (secondary)** | `AppColors.textSecondary` | `#8E8E93` |
| **Muted grey (tertiary)** | `AppColors.textTertiary` | `#636366` |

Transaction-form chrome runs on a **separate, darker set** — the Quick Add and
ScopedLedger screens sit on pure black rather than `bg`:
`formBg #000000`, `fieldCard #141416`, `formDim2 #5E5E63`,
`formChevron #3F3F43`, `hintText #B4B4B9`, `chipText #D8D8DD`,
`chipBg #232326`, `keyPressed #3A3A3D`.

Balance's amount hierarchy is its own four-token ramp:
`amountGroup #FFFFFF`, `amountChild #C7C7CC`, `amountGroupNeg #FF453A`,
`amountChildNeg #D4564D`, plus `nameChild #8E8E93` and
`runningBalance #48484C`.

Quick-Add type accents each carry a dimmed pair:
`expense #FF453A`/`#4D2C2A`, `income #30D158`/`#1C4A29`,
`transfer #0A84FF`/`#0E3459`, `rebalance #FF9F0A`/`#4D3208`,
`goal #BF5AF2`/`#3D1D4D`, `task #8E8E93`/`#3A3A3C`.

Account-group accents: `spendable` green, `receivables` blue,
`investments` purple, `valuables` amber, and **all three liability groups share
`#FF453A`** (credit cards / payables / bank loans) so "liabilities are red"
holds everywhere.

`AppColors.tint(color, [opacity = 0.16])` is the standard tinted-fill helper.

**Two design rules stated in code that every spec should be checked against:**

1. **`"Yön ≠ renk"` (direction ≠ colour)** —
   [app_colors.dart:22](lib/theme/app_colors.dart:22). Colour carries
   good/bad; arrows carry direction. A shrinking debt is a **green ▼**.
   Implemented by `DeltaChip(isLiability:)`.
2. **Balances render unsigned; ledger amounts render signed.**
   [formatters.dart:55](lib/core/utils/formatters.dart:55): a leading minus
   "shifts every digit one place and breaks column alignment", and in the
   ledger "the sign is the only cue a colourblind reader gets."
   `direction_signs_test.dart` asserts both directions clear 4.5:1 contrast.

### 5.3 Shared widget inventory

**`lib/shared/widgets/` — genuinely cross-feature**

| Widget / API | File | Notes |
|---|---|---|
| `AmountText`, `AmountText.balance` | [amount_text.dart](lib/shared/widgets/amount_text.dart) | Masking-aware money text |
| `DeltaChip` | amount_text.dart | ▲/▼ + %, with `isLiability` inversion |
| `SplitBar` | amount_text.dart | Two-tone asset/liability bar, height 7 |
| `ProgressBar` | amount_text.dart | Single-value bar with optional `paceMarker`; fill capped at 100% |
| `AppCard` | [app_card.dart](lib/shared/widgets/app_card.dart) | Standard card |
| **`IconTile`** | app_card.dart | The circular/rounded icon tile used everywhere (`size`, `circle`, `solid`) |
| `RowDivider` | app_card.dart | Indented list divider |
| `ScreenHeader` | [screen_header.dart](lib/shared/widgets/screen_header.dart) | Title + eye + `+` + `trailing`; `showBack`/`showEye`/`showAdd` |
| `SectionLabel` | screen_header.dart | Uppercase section label |
| `SegmentedPicker<T>` | screen_header.dart | Generic segmented control (New/Edit Goal type picker) |
| **`SectionIndicator`** | [section_header.dart](lib/shared/widgets/section_header.dart) | Label + page dots, tap advances/wraps (Balance's section switcher) |
| **`ToolCluster` / `Tool`** | section_header.dart | **The 3-button tool row.** 30×28, radius `Radii.sm`, 5px gaps, `showDot` for non-default state, `filled` for on-toggles |
| `HorizontalSectionSwipe` | section_header.dart | Horizontal swipe that won't steal vertical scroll (55px threshold, 1.6× dominance) |
| `TxnRow` | [txn_row.dart](lib/shared/widgets/txn_row.dart) | Ledger-tab + account-detail row (**signed** amounts) |
| `confirmDeleteTxn()` | txn_row.dart | Builds the impact lines and shows the destructive sheet |
| `SwipeActions` / `SwipeActionItem` | [swipe_actions.dart](lib/shared/widgets/swipe_actions.dart) | Left-swipe strip; global `closeOpenSwipeRow()` / `hintSwipeRow()` |
| `showDestructiveConfirm()` / `ImpactLine` | [destructive_sheet.dart](lib/shared/widgets/destructive_sheet.dart) | Delete confirmation with `.lost` / `.kept` lines |
| `FormSection`, **`FormRow`**, **`ToggleRow`**, `TextFieldRow`, `NoticeBanner`, `InfoNote`, `DestructiveRow` | [form_fields.dart](lib/shared/widgets/form_fields.dart) | The settings/form row kit. **`ToggleRow` is the app's switch.** |
| `AppBottomNav` / `NavTab` / `NavBadge` | [app_bottom_nav.dart](lib/shared/widgets/app_bottom_nav.dart) | 5 tabs + count badges |
| `NavIcon` / `NavGlyph` | [nav_icons.dart](lib/shared/widgets/nav_icons.dart) | Hand-drawn `CustomPainter` nav glyphs |
| ⚠️ `AppToolbar` / `ToolbarTool` | [app_toolbar.dart](lib/shared/widgets/app_toolbar.dart) | **307 lines, entirely unused.** Zero references outside its own file. Superseded by `ToolCluster` + `SectionIndicator`. |

**Feature-local but reusable**

| Widget / API | File |
|---|---|
| **`GroupRow`** (Balance group header, two tap zones) | [account_rows.dart](lib/features/balance/widgets/account_rows.dart) |
| **`AccountRow`** (child row, two tap zones) | account_rows.dart |
| **`PressZone`** (bounded press feedback — the two-zone teaching mechanism) | account_rows.dart |
| `liabilitySubtitle()` (utilisation / due / next payment) | account_rows.dart |
| `kChildIndent = 66.0` | account_rows.dart |
| `EmptyState` | [balance_screen.dart:867](lib/features/balance/balance_screen.dart:867) — imported by 3 other features |
| `LedgerDayCard` / `LedgerTxnRow` (**unsigned** amounts) | [ledger_txn_row.dart](lib/features/ledger/widgets/ledger_txn_row.dart) |
| **`PeriodRow`** (44px: range stepper + In/Out figures that double as filters) | [period_row.dart](lib/features/ledger/widgets/period_row.dart) |
| `TxnFieldRow`, `TxnCard`, `FormToggleBar`, `HintStrip`, `SaveBar`, `FormNavBar` | [form_kit.dart](lib/features/quick_add/widgets/form_kit.dart) |
| `NumericHeroCard`, `TextHeroCard`, `NumericKeypad` | [amount_hero.dart](lib/features/quick_add/widgets/amount_hero.dart) |
| `FormConfig`, `FieldSpec`, `FieldGroup`, `Blocker`, `HintSpec`, `TransactionFormShell` | [transaction_form_shell.dart](lib/features/quick_add/widgets/transaction_form_shell.dart) |
| `EditScaffold` | [edit_scaffold.dart](lib/features/planner/edit_scaffold.dart) |
| `SectionLabelSmall` | [pickers.dart:885](lib/features/quick_add/pickers.dart:885) |

**Bottom sheets** — `showAppSheet<T>()`
([pickers.dart:15](lib/features/quick_add/pickers.dart:15)) is the shared
draggable-sheet wrapper (title + `initialSize` + scroll controller). Several
sheets bypass it and call `showModalBottomSheet` directly; see §6.7.

**Period chips** — note there is **no shared "period chip" widget**. The Ledger
tab uses inline `GestureDetector` + `Container` type chips
([ledger_screen.dart:103](lib/features/ledger/ledger_screen.dart:103)); the
ScopedLedger uses `PeriodRow`'s `_Figure`; Balance uses `_DatePill` (private).
Three different implementations of a similar idea.

---

## 6 · Screen inventory

Root: `main.dart` → `StoreScope` → `MaterialApp` → `AppShell`.
[`AppShell`](lib/features/shell/app_shell.dart) is an `IndexedStack` of the five
tabs (so **all five stay alive and keep their state**) behind `AppBottomNav`.
Detail screens are pushed with `rootNavigator: true` so they cover the bar.
Re-tapping an active tab bumps `_scrollToTopSignal` — **only `BalanceScreen`
consumes it**; the other four ignore it.

### 6.1 Balance tab

**File** [balance_screen.dart](lib/features/balance/balance_screen.dart) ·
**Widget** `BalanceScreen` (`StatefulWidget`) · **Data** `StoreScope.of(context)`

Three "sections" in one screen — `BalanceSection.all` / `.assets` /
`.liabilities` — switched by `SectionIndicator` tap (advances + wraps) **or** by
`HorizontalSectionSwipe` (wraps both ways). Filtering is *focusing*, not
narrowing: a filtered section auto-opens all its groups.

**Header (~106px, pinned, `AnimatedSize`)**

- **Row 1 (34px):** `SectionIndicator` (label + 3 dots) · Spacer ·
  `_DatePill` → `showReportingDateSheet` → `store.setAsOf(...)` ·
  `_CircleButton` eye → `store.toggleMasked()` ·
  `_CircleButton` accent `+` → `showQuickAdd(context)`.
- **Row 2 (`AnimatedSwitcher`):** hero amount (`AppText.heroAmount`, `FittedBox`)
  + `"as of <date>"` line when historical, beside a 3-button **`ToolCluster`**:
  - **Sort** (`swap_vert`) → `_pickSort()` bottom sheet, 4 `AccountSort` options,
    applies immediately; `showDot` when non-default. **Sorts accounts *within*
    each group only — group order never changes.**
  - **Expand/collapse all** (`unfold_more`/`unfold_less`, `filled` when
    collapsed) → `_toggleAll()`.
  - **Search** (`search`) → replaces row 2 in place with a `TextField` +
    Cancel; matches group labels and account names; a group matched only via a
    child auto-opens.
  - Searching swaps the whole row, so **there is no room for a 4th tool button
    without a layout change** (§7).
- **Ratio bar** — shown only on `all` and only when not searching:
  `_RatioBar` (4px, two rounded segments, 1.5px gap, flex from
  `store.liabilityRatio`) + `_RatioLabels` (`Assets $X` green /
  `Liabilities $Y` red, both `FittedBox`).

**List** — `ListView` with `_scrollController`. On `all`, `_ListSectionHeader`
rows for **ASSETS** and **LIABILITIES** (uppercase label + total); on a filtered
section headers are hidden because the header already shows the total.

**Group rows** — [`GroupRow`](lib/features/balance/widgets/account_rows.dart:28),
**two tap zones**:
- left (icon + name + "N accounts", ~250pt) → **toggle open/closed**;
  long-press → `showNewAccountSheet(context, group:)`
- right (amount + share %, plus the 8px lead-in and trailing gutter) →
  **open the group ledger** (`ScopedLedgerScreen(GroupScope(group))`)
- open state = a `#0FFFFFFF` full-row wash + a 9px hand-painted chevron on the
  percentage line (never the amount line — that would move the number column)

Expansion state is `_opened`/`_closed` sets layered over the section default
(`all` → Spendable open; filtered → everything open). **Deliberately not
persisted** across launches. Children animate in with `AnimatedSize`; a closed
group builds no child rows at all.

**Account rows** — [`AccountRow`](lib/features/balance/widgets/account_rows.dart:274),
indented `kChildIndent = 66`, also two zones: **name → `AccountDetailScreen`**,
**amount → `ScopedLedgerScreen(AccountScope(id))`**. Liability children carry a
`liabilitySubtitle` (utilisation / due date / next payment).

**Empty states:** `_emptyState()` (with an "Add your first account" CTA — the
only place account creation is a permanent affordance) and `_noResults()`.

> **Dead / missing on this tab:** nothing is outright dead, but note that
> `AssetsScreen` / `LiabilitiesScreen` (§6.5) are **not reachable from Balance**
> — the section filter replaced them. They survive only behind the More tab.

### 6.2 Ledger tab

**File** [ledger_screen.dart](lib/features/ledger/ledger_screen.dart) ·
**Widget** `LedgerScreen` (`StatefulWidget`) ·
**Data** `store.txnsInMonth(store.period)`

⚠️ **This is not the same screen as the ScopedLedger in §6.3.** Different rows,
different grouping code, different sign convention.

- `ScreenHeader('Ledger', onAdd: showQuickAdd)`
- **`_MonthSummary` card** — month name + chevron (tap → `showDatePicker` in
  year mode) and two `_StepButton`s (`store.shiftPeriod(±1)`); then
  **In / Out / Left over**, where Left over = `(In − Out) / In`.
- **Type chips** — horizontal `ListView`: All + one per `TxnType`; selected chip
  gets a tinted fill + coloured border. Plus a `tune_rounded` `IconButton` →
  `_showAdvancedFilters` sheet (Month → date picker, Account → `pickAccount`,
  Category → `pickCategory`, and "Clear all filters"). Account and category
  filters are **mutually exclusive** — setting one clears the other. An active
  one shows a dismissible `_activeFilterBanner` chip.
- **Day grouping** — `_grouped()` buckets by `dateGroupLabel(t.date).toUpperCase()`,
  i.e. **keyed on the formatted string**, not the date.
- **Day header total** — `fold` where expense subtracts, income adds, and
  **transfer + rebalance contribute 0**, rendered `showSign: true` in
  `textTertiary`.
- **Rows** — [`TxnRow`](lib/shared/widgets/txn_row.dart) inside an `AppCard`:
  `IconTile` + title/note/meta + **signed** amount. A transfer shows
  `"from → to"` with a fee line; a rebalance shows a "no cash" caption.
  Tap → edit; swipe → Edit / Copy / Delete, delete going through
  `confirmDeleteTxn` (a modal confirmation with balance impact lines).

### 6.3 Scoped Ledger (drill-down from Balance)

**File** [scoped_ledger_screen.dart](lib/features/ledger/scoped_ledger_screen.dart) ·
**Widget** `ScopedLedgerScreen(initialScope:)` ·
**Data** [`LedgerQuery`](lib/features/ledger/ledger_scope.dart:115) over
`store.txns`

One screen, three scopes (`AllAccountsScope` / `GroupScope` / `AccountScope`).
Changing scope **does not push a route** — the switcher is a filter, so Back
stays one level deep.

- **Nav bar (42px)** — a back affordance that always reads "Balance", and a
  trailing `more_horiz` icon.
- **Hero** — coloured avatar, the **scope name as a dropdown** (`_pickScope`
  sheet listing All accounts / each group / each account), a meta line, and the
  scope balance.
- **`PeriodRow`** — ‹ range › stepper (forward disabled past today) + In/Out
  figures that **double as direction filters**; tapping the active one clears it.
  Range presets via `_pickRange` (`RangePreset`: this/last week, this/last
  month, last 3 months, this year, all time).
- **Toolbar** — `"N transactions"` / `"M of N transactions"` plus a
  **`ToolCluster`**.
- **List** — `LedgerDayCard` per day, `LedgerTxnRow` rows, **amounts unsigned
  with colour carrying direction** (the opposite of §6.2). Row height **66px in
  group/all scope, 52px in account scope** (line 3 is dropped where the account
  is identical on every row). Tapping a row does nothing — documented as
  deliberate, and there is no press highlight either. Swipe → Edit / Copy /
  Delete; **delete here uses an undo snackbar, not a confirmation dialog** (also
  the opposite of §6.2).
- **Bottom** — a full-width `+ Add expense` button, prefilled with the scope's
  account when there is exactly one.

> ### ⚠️ Dead controls on this screen
>
> **All three `ToolCluster` buttons are wired to `onTap: () {}` and do nothing:**
>
> - **Sort** — [scoped_ledger_screen.dart:325](lib/features/ledger/scoped_ledger_screen.dart:325)
> - **Filter** — [scoped_ledger_screen.dart:331](lib/features/ledger/scoped_ledger_screen.dart:331)
>   (it does show `showDot: _filter != null`, but the dot is driven by the
>   `PeriodRow` figures, not by this button)
> - **Search** — [scoped_ledger_screen.dart:336](lib/features/ledger/scoped_ledger_screen.dart:336)
>
> These are the **only literal `onTap: () {}` / `onPressed: () {}` stubs in the
> entire codebase.**
>
> **Also dead:** the `more_horiz` icon in the nav bar
> ([scoped_ledger_screen.dart:163](lib/features/ledger/scoped_ledger_screen.dart:163))
> is a bare `Icon` inside a `Padding` — **no `GestureDetector`, no `InkWell`, no
> handler at all.** It looks like a menu button and is not one.

### 6.4 Planner tab (brief)

**File** [planner_screen.dart](lib/features/planner/planner_screen.dart) ·
**Widget** `PlannerScreen`

Header row 1 (`ScreenHeader`, its `+` type-aware per tab; `•••` → `ArchiveScreen`;
month control on Budgets only, empty on Goals/Schedule — row 1 is the tab's scope
control) → row 2 a raised-chip **segmented control** (`_SegmentedTabs`, Budgets /
Goals / Schedule) → row 3 the per-tab summary → the tab body. The Planner owns its
own `_month`; it never reads or writes `store.period`, so its arrows leave Ledger
and Insight untouched. Budgets read `store.budgetedCategories` with burn-rate bars and a
projected-overspend banner; Goals read `store.goalsOfType(...)`; Schedule reads
`store.overdueTasks` / `thisWeekTasks` / `laterTasks` with mark-paid and skip.
Editors: [edit_budget_screen.dart](lib/features/planner/edit_budget_screen.dart),
[edit_goal_screen.dart](lib/features/planner/edit_goal_screen.dart),
[edit_task_screen.dart](lib/features/planner/edit_task_screen.dart), all on
`EditScaffold`. [archive_screen.dart](lib/features/planner/archive_screen.dart)
lists archived goals and removed budgets.

> **Dead control:** the month bar's `keyboard_arrow_down_rounded` at
> [planner_screen.dart:95](lib/features/planner/planner_screen.dart:95) sits in a
> plain `Row` beside the month `Text` with **no gesture handler on either**. It
> reads as a dropdown and is inert. (The `‹ ›` `IconButton`s beside it do work.)
> Contrast [ledger_screen.dart:383](lib/features/ledger/ledger_screen.dart:383),
> where the identical-looking month + chevron **is** wrapped in a
> `GestureDetector`.

### 6.5 Insight tab (brief)

**File** [insight_screen.dart](lib/features/insight/insight_screen.dart) ·
**Widget** `InsightScreen` (`StatelessWidget`)

Explicitly marked as unspecified in the source: *"Insight is named in the bottom
navigation but has no screen spec in v1.1… ready to be replaced when the module
is specified."* Three blocks: a **Left over** hero for `store.period`,
**Where it went** (expense categories sorted desc with `ProgressBar`s scaled to
the largest), and **Goal performance** (reached / success rate / avg months).
No interactive controls at all beyond the header `+`.

### 6.6 Detail screens

| Screen | File | Widget | Data | Behaviour |
|---|---|---|---|---|
| **Account detail** | [account_detail_screen.dart](lib/features/balance/account_detail_screen.dart) | `AccountDetailScreen(accountId:)` (`StatelessWidget`) | `accountById`, `balanceOf`, `txnsForAccount`, `runningBalanceAt` | Back + `•••` (→ Edit Account, the only way in). Summary (icon, name, group·currency, balance) + credit-utilisation `ProgressBar` (green/amber/red at 30%/70%). Amber statement banner for credit cards with a `paymentDue`. "Last 30 days" In/Out. Date-grouped history using `TxnRow` **with `runningBalance` and `perspectiveAccountId`**. Sticky footer: `Add expense` (always) + `Pay card`/`Make payment` (liabilities only), both prefilling Quick Add. Renders an "Account removed" `EmptyState` if the account vanishes underneath. |
| **Edit account** | [edit_account_screen.dart](lib/features/balance/edit_account_screen.dart) | `EditAccountScreen(accountId:)` | store | Form rows; starting balance shown read-only (write-once). Destructive remove → archive-if-history. |
| **Assets** | [assets_screen.dart](lib/features/balance/assets_screen.dart) | `AssetsScreen` → `GroupDetailScreen` | store | All groups always expanded. `GroupRow` **without** `onOpenLedger`, so the chevron is correctly suppressed; `AccountRow` in whole-row mode → account detail. **Reachable only from More.** |
| **Liabilities** | [liabilities_screen.dart](lib/features/balance/liabilities_screen.dart) | `LiabilitiesScreen` → `GroupDetailScreen(isAssets: false)` | store | 14 lines; identical but for the per-row subtitle. **Reachable only from More.** |
| **Transaction detail / edit** | [quick_add_sheet.dart](lib/features/quick_add/quick_add_sheet.dart) | `QuickAddScreen` via `showQuickAdd(...)` | store | **There is no separate transaction-detail screen.** `showQuickAdd(context, editing: txn)` opens the same 1224-line form in edit mode with the type locked; `copyOf:` opens a copy dated today. Driven by `FormConfig`/`TransactionFormShell` so a type is a config, not a screen. |
| **Category detail** | — | — | — | **Does not exist.** No `CategoryDetailScreen`, no `category_detail.dart`, nothing. The nearest things are the `pickCategory` sheet and Planner ▸ Budgets. More ▸ Categories just opens the **picker sheet**, which is a selection UI, not a detail screen. |
| **More** | [more_screen.dart](lib/features/more/more_screen.dart) | `MoreScreen` | store | Assets · Liabilities · Categories (→ picker) · Archive · Privacy-mode `ToggleRow` · Add an account. |

### 6.7 Bottom sheets

| Sheet | Entry point | Notes |
|---|---|---|
| Reporting date picker | `showReportingDateSheet` — [date_sheet.dart](lib/features/balance/widgets/date_sheet.dart) | Monday-first calendar, future days disabled, Today/Apply; `liveDate` sentinel = back to live |
| Balance sort | `_pickSort` — [balance_screen.dart:443](lib/features/balance/balance_screen.dart:443) | 4 options, applies immediately |
| Ledger period | `_pickRange` — [scoped_ledger_screen.dart:450](lib/features/ledger/scoped_ledger_screen.dart:450) | `RangePreset` list with resolved labels |
| Ledger scope switcher | `_pickScope` — [scoped_ledger_screen.dart:503](lib/features/ledger/scoped_ledger_screen.dart:503) | All / groups / accounts, max 76% height |
| Advanced filters | `_showAdvancedFilters` — [ledger_screen.dart:198](lib/features/ledger/ledger_screen.dart:198) | Uses `showAppSheet` |
| Account picker | `pickAccount` — [pickers.dart:67](lib/features/quick_add/pickers.dart:67) | Searchable + inline "create" row |
| Category picker | `pickCategory` — [pickers.dart:196](lib/features/quick_add/pickers.dart:196) | Searchable, shows spend vs limit |
| New category | `showNewCategorySheet` — [pickers.dart:465](lib/features/quick_add/pickers.dart:465) | 6-swatch `AppColors.categoryPalette` |
| New account | `showNewAccountSheet` — [pickers.dart:648](lib/features/quick_add/pickers.dart:648) | Optional `group:` prefill |
| Currency picker | `pickCurrency` — [pickers.dart:844](lib/features/quick_add/pickers.dart:844) | |
| Icon picker | [quick_add_sheet.dart:828](lib/features/quick_add/quick_add_sheet.dart:828) | |
| Tag entry | [quick_add_sheet.dart:883](lib/features/quick_add/quick_add_sheet.dart:883) | |
| Budget suggestion | [edit_budget_screen.dart:195](lib/features/planner/edit_budget_screen.dart:195) | |
| Destructive confirm | `showDestructiveConfirm` — [destructive_sheet.dart:19](lib/shared/widgets/destructive_sheet.dart:19) | `ImpactLine.lost` / `.kept` |

Only 3 of these route through the shared `showAppSheet` wrapper; the rest call
`showModalBottomSheet` directly and re-implement the grab handle and title
themselves (§7).

### 6.8 Full list of controls that currently do nothing

1. **ScopedLedger ▸ Sort** — [scoped_ledger_screen.dart:325](lib/features/ledger/scoped_ledger_screen.dart:325) — `onTap: () {}`
2. **ScopedLedger ▸ Filter** — [scoped_ledger_screen.dart:331](lib/features/ledger/scoped_ledger_screen.dart:331) — `onTap: () {}`
3. **ScopedLedger ▸ Search** — [scoped_ledger_screen.dart:336](lib/features/ledger/scoped_ledger_screen.dart:336) — `onTap: () {}`
4. **ScopedLedger ▸ nav-bar `•••`** — [scoped_ledger_screen.dart:163](lib/features/ledger/scoped_ledger_screen.dart:163) — bare `Icon`, no gesture at all
5. **Planner ▸ month-bar chevron** — [planner_screen.dart:95](lib/features/planner/planner_screen.dart:95) — decorative; neither the label nor the chevron is tappable
6. **`AppToolbar`** — [app_toolbar.dart](lib/shared/widgets/app_toolbar.dart) — 307 lines, zero call sites
7. **`BalanceFilter`** — [balance_filter.dart](lib/features/balance/balance_filter.dart) — 197 lines + 17 tests, zero call sites in `lib/`
8. **`Account.copyWith`** — [models.dart:52](lib/core/models/models.dart:52) — never called from `lib/`
9. **`Txn.exchangeRate`** — stored and editable, never read by any balance calculation
10. **`cupertino_icons`** — declared dependency, never imported
11. **Tab re-select → scroll to top** — works on Balance only; Ledger, Planner, Insight and More receive no signal

---

## 7 · Risks and friction

Reported, not fixed, per the working agreement.

1. **The build is broken (§1.3).** 3 analyze errors in
   `scoped_ledger_screen.dart` from a half-finished `LedgerDayCard` refactor;
   5 of 6 test files won't compile. **Nothing can be verified until this is
   resolved**, and requirement 5 of the working agreement ("finish with
   `flutter analyze` clean") is unsatisfiable on a spec that touches anything
   importing this file. Worth clearing deliberately as its own change, before
   spec work, rather than smuggling it into the first feature.

2. **Two Ledger implementations with opposite conventions.** `LedgerScreen` (tab)
   vs `ScopedLedgerScreen` (drill-down) have:
   - different row widgets (`TxnRow` vs `LedgerTxnRow`)
   - **opposite sign conventions** — tab is signed (`showSign: true`), scoped is
     unsigned-with-colour
   - **opposite delete UX** — tab shows `confirmDeleteTxn` (a modal), scoped uses
     an undo snackbar
   - different day-total maths — the tab counts transfers as 0 unconditionally;
     the scoped screen counts them per `FlowKind` (0 only when *internal to the
     scope*)
   - independent day-grouping code, one keyed on a **formatted string**, one on
     a `DateTime`

   **A "Ledger tab" spec and a "transaction row" spec will mean different files.
   Always confirm which one a spec means before touching either.**

3. **`dateGroupLabel` reads the wall clock, but the app pins "today".**
   [formatters.dart:144](lib/core/utils/formatters.dart:144) uses
   `DateTime.now()`, while the whole app runs off
   `AppStore.today = DateTime(2026, 8, 9)`. `dateTimeLabel` right above it takes
   an explicit `now` parameter **precisely to avoid this** ("comparing against
   `DateTime.now()` made a transaction dated 'today' render as an absolute
   date"). `dateGroupLabel` never got the same treatment, so **day headers on
   both ledgers and on Account Detail will not say "Today"/"Yesterday"** unless
   the wall clock happens to be 2026-08-09. Any spec touching day headers hits
   this immediately.

4. **No indices, and several quadratic paths on hot render code.**
   - `accountById` is an O(n) `for` loop, called several times per row.
   - `AppStore.txns` **copies and re-sorts the entire list on every access** —
     and it is called inside `txnsForAccount`, `txnsInMonth`, and
     `LedgerQuery.rows()`.
   - `LedgerQuery.totalIn` and `totalOut` **each call `rows()` again**, so the
     ScopedLedger walks the transaction list **three times per build**.
   - `AccountDetailScreen._effect` is
     `balanceOf(id) - balanceWithout(id, t)`, and `balanceWithout` itself calls
     `balanceOf` — **two full transaction scans per row**, inside a loop over
     rows.
   - `netWorthDelta`, `groupActivity` are O(txns × accounts) and run in `build`.

   Fine at 24 seed transactions; it will not survive a realistic dataset. A spec
   that adds a per-row derived figure multiplies this.

5. **Multi-currency correctness is inconsistent (§4.1).** Balance and Ledger
   convert; **Planner budgets, Insight, Goals and Schedule do not convert at
   all** and sum raw amounts across currencies. Separately, all conversion
   assumes `Txn.currency == account.currency`, which nothing enforces. Any spec
   asking for a cross-cutting total needs an explicit decision about which path
   it is on.

6. **`Goal.saved` is a stored value that should be derived.** Every account
   balance in the app is computed from transactions — that is the codebase's
   central principle, and `startingBalance` is write-once specifically to
   protect it. `Goal.saved` breaks the rule: it is a plain mutable field, and
   `addGoal`'s initial deposit writes **both** a real `Txn` **and** `saved:
   initialDeposit`. Any later contribution transfer will move the account
   balance without moving `saved`. Expect drift.

7. **The 3-button `ToolCluster` has no room for a fourth.** On Balance, row 2
   is `Expanded(amount) + ToolCluster`, and search **replaces the entire row**.
   `ToolCluster` is 30px buttons with 5px gaps: 3 buttons = 100px, 4 = 135px.
   At the tested 320pt width, with `Insets.gutter` × 2 = 40px, that leaves the
   amount 145px — and `heroAmount` is 33px type. **A fourth button will fail
   `quick_add_layout_test` / `ledger_layout_test`-style overflow assertions at
   320×568 before anything else.** Same constraint on the ScopedLedger toolbar,
   which additionally holds a `"N of M transactions"` `RichText`.

8. **`AccountGroup.isAsset` depends on enum declaration order** (§3.2) —
   `index <= valuables.index`. Adding a group in the wrong slot silently
   reclassifies it and corrupts net worth. There is no test guarding the
   boundary (the existing test only checks *listed* order).

9. **`runningBalanceAt` ignores the `asOf` cutoff** that `balanceOf` respects,
   so in a historical view the running balance under each row and the account's
   headline balance are computed on different data. It also tie-breaks on
   `other.id.compareTo(t.id) <= 0`, which mixes `'t1000'`-style generated ids
   with `'a-cash-usd'`-style seed ids — **string ordering of ids as a proxy for
   insertion order**, which will misbehave once the counter passes `t9999`.

10. **Two live, tested-but-unwired subsystems.** `BalanceFilter` (197 lines,
    17 passing tests) and `AppToolbar` (307 lines) are complete and unreferenced.
    Before building anything that looks like Balance filtering or a screen
    toolbar, **check these first** — a spec may well be asking for the missing
    integration rather than a new implementation.

11. **Bottom-sheet chrome is duplicated ~10 times.** `showAppSheet` exists but
    only 3 sheets use it; the rest hand-roll the 36×4 grab handle, the title
    padding and the `SafeArea`. Adding a sheet by copying a neighbour is the
    path of least resistance and will deepen this.

12. **`EmptyState` lives in `balance_screen.dart`** and is imported by Ledger,
    Planner and Account Detail via `show EmptyState`. Any spec that restructures
    `balance_screen.dart` touches three other features by accident.

13. **Design-token compliance is uneven (§5.1).** Balance uses `Insets`/`AppText`
    throughout; the Ledger feature uses raw numbers and inline `TextStyle`s.
    Since the standing rules forbid tokenising existing code, new Ledger work
    will sit *next to* untokenised code — write the new code with tokens and
    leave the old alone, expecting the file to look mixed.

14. **`IconData` and `Color` are stored on domain models** (`Category.icon`,
    `Category.color`, `Account.icon`, `Goal.icon`, `Task.icon`). Harmless today;
    it will block any serialisation or backup/export spec until an icon/colour
    codec exists, and `IconData` needs `--no-tree-shake-icons` to survive a
    release build if constructed dynamically.

15. **No persistence means "exports, backups, and sync payloads carry true
    unfiltered data" (working-agreement rule 4) has nothing to read from yet.**
    Any spec in that area needs the `seed_data.dart` seam replaced first.

---

## 8 · Conventions to match

Distilled from reading the code — follow these unless a spec says otherwise.

- **State:** `AppStore` + `StoreScope.of` (subscribing) / `StoreScope.read`
  (callbacks only). Screen-local UI state via `setState`. **Never add a
  state-management package.**
- **Ids:** `String`, always. New ids from `AppStore._nextId(prefix)`.
- **Amounts:** `double`. Positive magnitude on `Txn.amount`; sign derived from
  `type` via `_effectOn`. Liabilities are negative balances. `Task.expectedAmount`
  is the one signed field.
- **Money on screen:** `AmountText` where a `BuildContext` exists;
  `AmountText.balance` for balances; raw `money()` only for semantics labels and
  string interpolation, passing `masked:` explicitly.
- **Balances are always derived**, never stored or cached.
- **Tokens:** `AppColors`, `AppText`, `Insets`, `Radii`. No new hex literals, no
  raw padding numbers in new code.
- **Enums carry their own data** (`label`, `color`, `icon`) — the established
  pattern for anything with a fixed set of variants.
- **Exhaustive `switch` expressions** over enums and sealed classes; no
  `default:` on `TxnType`/`AccountGroup`/`LedgerScope` (the analyzer catches
  missing cases).
- **Semantics are not optional.** Rows wrap content in
  `Semantics(label:) + ExcludeSemantics(child:)`, swipe actions are exposed via
  `customSemanticsActions`, and tap targets clear 44pt. `direction_signs_test`
  asserts 4.5:1 contrast. Match this.
- **Comment the *why*, not the *what*.** This codebase's defining trait is that
  every non-obvious choice carries a short rationale, often citing a spec
  section. New code should read the same way.
