# Implementation Prompt — Balance Category & Account Filter (Flutter)

## Role and context

You are adding one feature to **FinLens**, a Flutter personal-finance app, on the **Balance** tab (first tab).

The Balance screen today shows: a `NET WORTH` label with page dots; a row of header controls (a "Today" period pill, an eye visibility toggle, a purple `+` button); the Net Worth figure; a right-aligned group of **three small circular icon buttons — sort, collapse, search**; a green/red assets-vs-liabilities ratio bar with two labels; then an `ASSETS` section and a `LIABILITIES` section. Each section lists categories (Spendable, Receivables, Investments, Valuables / Credit Cards, Payables, Bank Loans). Each category row shows an icon tile, name, account count, amount, and percentage-of-section, and expands to reveal its member accounts.

**This design is approved and final. You are not redesigning it.** You are adding a fourth icon button and the panel it opens.

**Match the project's existing conventions.** Use the state management, domain models, persistence layer, and design tokens that are already there — if the project uses Bloc, write a Bloc; if IDs are `int`, use `int`; if colors and text styles live in a theme file, read them from it. Do not introduce a new state-management library, a new persistence mechanism, or a new design-token system. The Dart in this document is a behavioral specification, not code to paste.

---

## The four tasks

1. Place a **filter icon button to the right of the search button**, identical in size to the other three.
2. When a filter is applied, that button switches to a **filled** icon — no other change.
3. Tapping it opens a **bottom sheet** for choosing which categories and accounts are visible.
4. Implement the **filtering logic** carefully and completely, per §4.

---

## Hard boundary — the existing UI does not change

This is a **strictly additive** change. Do **not**:

- resize, recolor, re-space, or **re-icon** any existing control — the sort/collapse/search buttons keep their current glyphs exactly as they are, as do the eye toggle, the `+` button, and the "Today" pill;
- change the tool group's gap, padding, or alignment;
- change the Net Worth typography, the ratio bar, the section headers, the row heights, the expanded-row highlight, the category icon tiles, the percentage placement, or the chevrons;
- touch the tab bar or any other tab;
- "clean up", normalize, or tokenize any existing style value while you are in these files;
- add any new permanent element to the Balance screen — no chip, no banner, no summary row, no badge, no count.

If you think something existing is wrong, **say so in your report — do not change it.**

Scope is the **Balance tab only**. The Ledger, Planner, and Insight tabs, and every export/backup/sync payload, must continue to show true unfiltered data. Nothing is deleted, archived, or soft-deleted — hiding is a presentational preference and fully reversible.

---

## 1 · The filter button

**Clone the existing button; change only the icon.** Locate the widget, builder method, or constant that renders sort/collapse/search and instantiate a **fourth instance of that same thing**. Diameter, background color, corner radius, icon box size, stroke width, the gap to its neighbour, press feedback, and hit-target treatment all come from the existing implementation. Introduce **no new size, spacing, or color value** for this button.

If those three buttons are currently written out inline three times, extract them into one reusable widget **without changing any of their values**, then add the fourth. That refactor must be pixel-neutral — a before/after screenshot of the idle header has to be identical apart from the new button.

Position: **last in the group, immediately to the right of search.** The group stays right-aligned and grows leftward, exactly as it does today.

Icon: a **funnel** glyph. Not a sliders/equalizer glyph — that reads as "sort" and the sort button is adjacent.

Overflow: a fourth button consumes roughly one more button-width on the row shared with the Net Worth figure. Verify the layout at 375 pt width. *Only if it actually overflows*, stop and report before changing anything.

---

## 2 · Active state — icon fill only

| | Idle | Active |
|---|---|---|
| Background | sibling value | **sibling value — unchanged** |
| Icon shape | funnel, **outline** | funnel, **filled** |
| Icon color | sibling value (the group's muted icon color) | the app's **high-emphasis icon color** |
| Animation | — | 160 ms ease on color; icon shape cross-fades |

**The background never changes.** No purple, no tint, no badge, no count. The entire signal is: the funnel fills in and brightens one step. Two simultaneous cues on one small glyph.

Take both icon colors from the existing theme — the idle one is already whatever sort/collapse/search use; the active one should be the token the app already uses for primary/high-emphasis icons. Do not invent hex values.

`isActive` is true when at least one category or account is hidden. It flips **the moment a switch is toggled in the sheet**, not when the sheet is dismissed, so the user sees the change behind the sheet.

**Accessibility.** Because there is no color change at all, `Semantics.value` is the only signal a screen-reader user gets. It must be present and accurate:

```
Semantics(
  label: 'Filter categories',
  value: isActive ? 'Active, $hiddenCount items hidden' : 'Off',
  button: true,
)
```

Do not reduce the visual state change to brightness alone — the outline→filled shape change is the non-color cue for sighted users.

> **Known trade-off, accepted deliberately.** This is the quietest possible indicator. With Valuables hidden, Net Worth drops from `$193,635` to `$43,635` and the only thing on screen saying so is a filled glyph. That makes the **live Net Worth preview inside the sheet (§3) mandatory, not optional.** Do not simplify it away.

---

## 3 · The bottom sheet

`showModalBottomSheet` with `isScrollControlled: true`, `backgroundColor: Colors.transparent`, and a body clipped to a **26 pt** top corner radius. Background `#1C1C1E`. Max height **86%** of screen. Scrim `rgba(0,0,0,0.55)`. Standard slide-up (~340 ms, decelerating). Dismissible by scrim tap, swipe-down, and the Done button.

A bottom sheet — not a pushed full-screen page — so the Balance screen stays visible behind it and the user can see the Net Worth figure react as they toggle.

Type sizes below are intentionally one step smaller than the Balance list's, so the sheet reads as a denser utility surface.

### Layout, top to bottom

**Grabber** — 36 × 5 pt, `#48484A`, radius 999, centered, 8 pt top margin.

**Header row** — padding 11 / 18 / 9 pt.
- Left: `Filter` — 17 pt, weight 650, white.
- Right: `Reset` — text button, `#5E5CE6`, 15 pt weight 550. When nothing is hidden it is **35% opacity and non-interactive**. Tapping it clears both hidden sets.

**Live preview card** — margin `0 16 4`, background `#2C2C2E`, radius 13, padding 10 / 13.
- Left: label `NET WORTH · FILTERED` (11 pt, weight 600, letter-spacing 0.04em, `#8E8E93`) above the value (19 pt, weight 700, white, tabular figures).
- Right, right-aligned, two lines at 11 pt `#8E8E93`: `{n} of {total} categories` and `{n} of {total} accounts`.
- **Updates live on every toggle.** This is the only place the user learns what the filter costs. Required.

**Scrollable body** — padding `6 12 0`. Two labelled sections: `ASSETS` then `LIABILITIES` — 11 pt, weight 650, letter-spacing 0.07em, `#8E8E93`, padding `10 8 6`.

Each **category group** is a `#2C2C2E` card, radius 14, 7 pt bottom margin:

- Category row — padding 8 / 11, gap 10:
  - **Disclosure caret** — 7 × 12 pt chevron, `#636366`, rotates 90° when expanded (200 ms).
  - **Icon tile** — 28 × 28 pt, radius 8, filled with the category's own color, white glyph (reuse the Balance list's category icons and colors — do not pick new ones).
  - **Name** 14.5 pt weight 600 white; **subtitle** 11.5 pt `#8E8E93`:
    - state `on` or `off` → `{n} accounts · {full category total}`
    - state `mixed` → `{visible} of {n} · {filtered category total}`
  - **Tri-state switch**, right-aligned.
- Expanded account list, separated by a 1 pt `rgba(255,255,255,0.07)` divider. Each account row: padding `6 11 6 20`, name 14 pt `#EBEBF5`, amount 13 pt `#8E8E93` tabular in the account's own display currency, then a small switch.

A row in state `off` dims its **caret, icon, name, and subtitle to 35% opacity** but keeps its **switch at full opacity** so it stays discoverable. 200 ms transition. Account rows dim the same way, including when they are off only because their parent category is off.

**Footer** — pinned, 1 pt top divider, `#1C1C1E`, padding `11 16 13` plus safe-area bottom. Full-width `Done` button: 47 pt tall, radius 14, `#5E5CE6`, white 16 pt weight 650.

**No Apply/Cancel model.** Every toggle applies immediately to the screen behind. `Done` only closes the sheet.

### Tri-state switch

| State | Track | Knob |
|---|---|---|
| `on` | `#30D158` | right |
| `mixed` | `#5E5CE6` | **centered** |
| `off` | `#48484A` | left |

Category switch 45 × 27 pt, knob 23 pt. Account switch 38 × 22 pt, knob 18 pt. Knob white with a subtle shadow. Animate track color and knob position together over 220 ms.

Flutter's `Switch` cannot render a centered knob — build a small custom widget (`GestureDetector` + `AnimatedContainer` + `AnimatedAlign`, or `CustomPaint`).

Semantics: `'{Category name}, {shown|partially shown|hidden}'`, hint `'Double tap to {show|hide} all accounts'`.

---

## 4 · The filtering logic

This is the part that must be exactly right. Implement it as a small, testable unit — not as conditionals scattered through the widget tree.

### 4.1 State

Store **hidden** IDs, not visible ones, so new categories and accounts default to visible with no migration.

```dart
class BalanceFilter {
  final Set<String> hiddenCategoryIds;
  final Set<String> hiddenAccountIds;

  const BalanceFilter({
    this.hiddenCategoryIds = const {},
    this.hiddenAccountIds = const {},
  });

  bool get isActive => hiddenCategoryIds.isNotEmpty || hiddenAccountIds.isNotEmpty;

  BalanceFilter copyWith({
    Set<String>? hiddenCategoryIds,
    Set<String>? hiddenAccountIds,
  });
}
```

### 4.2 Derived functions — implement exactly these, as pure functions

```
visibleAccounts(category):
    if category.id ∈ hiddenCategoryIds  ->  []
    else -> [a for a in category.accounts if a.id ∉ hiddenAccountIds]

isCategoryVisible(category):
    visibleAccounts(category).isNotEmpty

filteredTotal(category):
    sum of a.baseAmount for a in visibleAccounts(category)

toggleState(category) -> {on, mixed, off}:
    if visibleAccounts(category).isEmpty                              -> off
    if visibleAccounts(category).length == category.accounts.length   -> on
    otherwise                                                        -> mixed

hiddenItemCount():
    total = 0
    for each category:
        if toggleState(category) == off:  total += 1
        else:                             total += count of that category's accounts in hiddenAccountIds
    return total
```

**Invariant:** a category with zero visible accounts is `off`, whether or not its ID is in `hiddenCategoryIds`. Derive visibility from `isCategoryVisible` everywhere; **never read `hiddenCategoryIds` directly in the UI.**

**Currency:** sum the already-converted base-currency amount the screen uses today. Reuse the existing conversion path; do not reimplement it.

### 4.3 Toggle transitions — implement exactly these tables

**Tapping a category switch:**

| Current state | Action | Result |
|---|---|---|
| `on` | add category ID to `hiddenCategoryIds`; add **all** its account IDs to `hiddenAccountIds` | `off` |
| `mixed` | remove category ID from `hiddenCategoryIds`; remove **all** its account IDs from `hiddenAccountIds` | `on` |
| `off` | same as `mixed` | `on` |

A partially-filtered category always resolves to **fully shown** on tap — never to fully hidden.

**Tapping an account switch:**

| Parent state | Action | Result |
|---|---|---|
| `off` | remove the category from `hiddenCategoryIds`; add **every sibling** account ID to `hiddenAccountIds`; remove **this** account's ID | `mixed`, with exactly this one account visible |
| `on` / `mixed`, account visible | add this account ID to `hiddenAccountIds`; **then** if the category now has zero visible accounts, add the category ID to `hiddenCategoryIds` | `mixed`, or `off` if it was the last one |
| `on` / `mixed`, account hidden | remove this account ID from `hiddenAccountIds` | `mixed` or `on` |

The first row is the subtle one: **reviving a fully-hidden category by switching on a single account must leave only that account visible, not all of them.** Getting this backwards is the most likely bug here.

### 4.4 Recomputation — every figure on Balance

No cached unfiltered value may leak through. Compute a filtered view-model once per rebuild.

1. **Category list** — render only categories where `isCategoryVisible`. Hidden ones are **absent from the tree**, not collapsed, dimmed, or struck through.
2. **Account sub-rows** — inside a visible category, render only its visible accounts.
3. **Account count subtitle** — the visible count: `4 accounts` becomes `3 accounts`.
4. **Category amount** — `filteredTotal(category)`.
5. **ASSETS total** — sum of `filteredTotal` over visible asset categories.
6. **LIABILITIES total** — same over visible liability categories.
7. **Net Worth** — filtered assets − filtered liabilities.
8. **Ratio bar** — asset segment = `filteredAssets / (filteredAssets + filteredLiabilities)`; liability segment is the remainder. Both labels use filtered values.
9. **Category percentage** — `filteredTotal / filteredSectionTotal × 100`, one decimal, **recomputed against the new denominator.** With Valuables hidden, Investments goes 21.4% → 65.1%. Never carry the unfiltered percentage over.
10. **Sort** — operates on the filtered set.
11. **Search** — matches only visible categories and accounts. An account inside a hidden category must not appear in results.
12. **Collapse/expand** — unchanged behavior, applied to the filtered tree.

Guard every division against a zero denominator.

### 4.5 Persistence

The filter is **persistent across app launches** — that is the core of the use case ("I keep Valuables in the app but don't want them in my day-to-day Net Worth").

- Write through the project's existing persistence layer.
- Suggested keys: `balance_filter_hidden_categories`, `balance_filter_hidden_accounts` (JSON string arrays).
- Restore during initialization, **before first paint** — the screen must never flash unfiltered values and then re-render filtered.
- A persisted ID that no longer matches anything (the user deleted that account) is ignored silently; prune such IDs on load so a stale ID can never make the button look active.
- If FinLens supports multiple profiles, scope the keys per profile.

---

## 5 · Edge cases

| Case | Required behavior |
|---|---|
| All asset categories hidden | `ASSETS` header shows `$0`; below it one centered row `No visible categories` in `#636366` with an `Adjust filter` text button that opens the sheet. Ratio bar renders fully red. |
| All liability categories hidden | Symmetric: `$0`, same empty row, bar fully green. |
| Everything hidden | Net Worth `$0`. Both sections show the empty row. Bar renders as a flat `#2C2C2E` track. No crash on the zero denominator. |
| Last visible account in a category switched off | Category becomes `off` and leaves the list. **Never render a `$0` empty category row.** |
| New account added later | Defaults to **visible**. If added to a category that is currently `off`, the category stays `off`, but the account is not in `hiddenAccountIds` — so it appears when the user re-enables the category. |
| New category added later | Defaults to visible. |
| Account or category deleted | Its ID is pruned from both sets on next load. |
| Pull-to-refresh / data reload while filtered | Filter survives; re-apply after new data lands. |
| Sheet opened with nothing hidden | `Reset` disabled; preview shows the true Net Worth and `7 of 7 categories`. |

---

## 6 · Acceptance criteria

Fixture (base currency USD):

- **Spendable `$22,405`** — Main Checking `$12,198`, Cash (USD Wallet) `$5,430`, Cash (EUR Wallet) `€2,797` = `$3,077`, Family Wallet `$1,700`
- **Receivables `$3,200`** — 4 accounts
- **Investments `$47,700`** — US Stocks (S&P 500) `$20,000`, Gold Portfolio `$15,000`, Crypto Wallet (BTC/ETH) `$7,700`, Tech ETFs (QQQ) `$3,000`, Private Pension (BES) `$2,000`
- **Valuables `$150,000`** — 4 accounts
- **Credit Cards `$6,470`** · **Payables `$3,200`** · **Bank Loans `$20,000`**
- Unfiltered: Assets `$223,305`, Liabilities `$29,670`, Net Worth `$193,635`

Checklist:

- [ ] Filter button sits immediately right of search, same diameter/background/gap/icon size as its three siblings.
- [ ] The sort, collapse, and search glyphs are byte-identical to before — no icon was swapped while adding the fourth.
- [ ] Idle-state screenshot of the header is identical to before apart from the new button; `git diff` touches no style value of an existing widget.
- [ ] No overlap with the `+` or "Today" controls at 375 pt width.
- [ ] **Hide Valuables** → Assets `$73,305`, Net Worth `$43,635`, Spendable `30.6%`, Receivables `4.4%`, Investments `65.1%`, Valuables row absent, filter icon filled and brighter **with no background change**.
- [ ] **Hide Valuables except Car** → Assets `$95,305`, Net Worth `$65,635`; Valuables row present reading `1 account` / `$22,000`; its sheet switch is `mixed` with a centered knob.
- [ ] **Hide only Family Wallet** → Assets `$221,605`, Net Worth `$191,935`; Spendable reads `3 accounts` / `$20,705`; sheet subtitle reads `3 of 4 · $20,705`.
- [ ] Switching on a single account inside a fully-hidden category leaves **exactly that one** account visible.
- [ ] Switching off the last visible account removes the category from the list entirely.
- [ ] `Reset` restores `$193,635` and returns the icon to outline.
- [ ] Force-quit and relaunch preserves the filter, with no unfiltered flash on first paint.
- [ ] Ledger, Planner, and Insight show unchanged unfiltered numbers while the filter is active.
- [ ] Screen reader announces the button's active state and each switch's tri-state.
- [ ] No analyzer warnings; toggling does not rebuild the whole tree.

**Tests to write:** unit tests for `toggleState`, `hiddenItemCount`, and both transition tables in §4.3; a widget test asserting the Net Worth figure and the three percentages after hiding Valuables.

---

## 7 · Non-goals

- Saved filter presets ("Liquid only", "Everything")
- A quick-filter chip row on the screen
- Any filter indicator outside this one button
- Filtering by amount, date, currency, or tag
- Extending the filter to any other tab
- Any redesign, cleanup, or normalization of the existing Balance screen

---

## Deliverable

List the files you created and modified, and flag any deviation from this spec and why.
