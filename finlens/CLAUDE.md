# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

FinLens — a Flutter personal-finance app (Balance / Ledger / Planner / Insight / More).
**Dark-mode-only, portrait phone app.** Minimum supported width is **320pt**; layout
tests pin 390×844, 360×640, and 320×568.

A dense, up-to-date architecture survey already exists at
[`claude/CODEBASE_MAP.md`](claude/CODEBASE_MAP.md) — read it before non-trivial work.
It documents every model, query method, FX path, design token, shared widget, and screen.
This file is the short operational layer on top of it.

## Commands

```bash
flutter pub get              # install deps
flutter analyze              # THE verification step — must be clean before you finish
flutter run                  # run on a connected device/emulator
flutter run -d <deviceId>    # target a specific device (flutter devices to list)
```

- **Do not run `flutter test` (or single-file variants).** It hangs on this machine.
  Verify your work with `flutter analyze` only, and at the end tell the user which
  test files to run themselves (tests live in `test/`, plain `flutter_test`).
- No code-generation step: there is no `build_runner`, no `*.g.dart` / `*.freezed.dart`.
- Currency formatting is intentionally dependency-free (no `intl`) to match mockups exactly.

## Architecture essentials

**Feature-first with a shared core** (not clean-architecture; no repository/use-case layer):
```
lib/
  theme/    tokens — app_colors · app_typography · app_theme (Insets, Radii)
  core/     models · store/app_store.dart · data/seed_data.dart · utils (fx, formatters, date_range)
  shared/   cross-feature widgets
  features/ shell · balance · ledger · planner · insight · more · quick_add
```
Import direction: `features → shared/core/theme`, `shared → core/theme`, `core → theme` only.

**State** — one `ChangeNotifier` (`AppStore`) distributed via a hand-rolled
`InheritedNotifier` (`StoreScope`). `AppStore` owns all data and everything derived;
screens own view state with local `setState`.
- `StoreScope.of(context)` subscribes + rebuilds → use in `build`.
- `StoreScope.read(context)` no subscription → use in callbacks that only mutate.
- **Preserve this `of`/`read` distinction.**

**No persistence.** `main()` calls `buildSeedStore()`; every launch resets to the
hard-coded fixture in `seed_data.dart`. All mutations are in-memory + `notifyListeners()`.
`seed_data.dart` is the intended seam for a future backend. (`SharedPreferences` is
wired into `BalanceFilter` only, and that class is currently unused.)

## Conventions and hazards you must respect

- **Sign convention lives in exactly one place:** `AppStore._effectOn`. `Txn.amount` is
  always a positive magnitude; direction comes from `TxnType` + which ref matched.
  Liability accounts hold **negative** balances throughout. `rebalance` amounts are a
  signed delta (the one exception) and are excluded from income/expense metrics.
- **Polymorphic refs:** `Txn.fromRef`/`toRef` are Account **or** Category ids depending on
  `type` (expense: from=Account,to=Category; income: from=Category,to=Account;
  transfer: Account→Account; rebalance: to=Account). Resolve with
  `refName`/`refIcon`/`refColor`.
- **Money display:** use the `AmountText` widget (it auto-reads privacy `masked` state);
  drop to the raw `money()` function only without a `BuildContext`. `AmountText.balance`
  renders unsigned. Two hard rules the tests protect:
  1. **Direction ≠ colour** (`"Yön ≠ renk"`): colour = good/bad, arrows = direction
     (a shrinking debt is a green ▼).
  2. **Balances are unsigned; ledger amounts are signed.** `showSign: true` is used at
     only ~5 sites deliberately.
- **Design tokens:** never hard-code hex or raw padding — use `AppColors`, `AppText`,
  `Insets`, `Radii`. New Ledger-feature work should adopt tokens even though existing
  Ledger files use raw numbers (do not retro-fit the old ones). Never introduce a second
  token system.
- **`AccountGroup.isAsset` is defined by enum declaration order** (`index <= valuables`).
  Inserting a group in the wrong position silently reclassifies it and net worth.
- **Two parallel Ledger implementations** exist (`ledger_screen` tab vs
  `scoped_ledger_screen` drill-down) with different row widgets and day-grouping — the
  biggest footgun; check which one you're touching.
- Adding a fourth control to any header row breaks the 320pt overflow tests first.

## Product context

- **Target market: Turkmenistan.** Currency TMT (manat / teňňe), end-user UI in Turkmen,
  speech in Russian/Turkmen. Spec docs stay in Russian. (Base currency in `Fx` is still
  hard-coded `USD` — a known gap.)
- **Commits: no co-author / Claude attribution trailer.**
