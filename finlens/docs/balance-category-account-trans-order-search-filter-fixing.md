# Balance — Category & Account Trans Order, Search, Filter Fixing

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. The **category detail** and **account detail** screens each show a transactions-count row with three small circular tool buttons — **sort**, **filter**, **search**.

**All three buttons are rendered but do nothing.** This task gives them behavior and designs the surfaces they open. A visible control that does nothing is worse than no control at all, so none of the three may be left inert at the end of this work.

**Match the project's existing conventions.** Use the state management, repository, persistence layer, and design tokens already there. The app already has bottom sheets with a grabber, a caps section title, and rows with a leading checkmark slot — reuse that pattern rather than inventing a second one. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

Do **not**:

- change the three tool buttons' size, background, radius, gap, icon size, or position;
- change the transaction rows, day-group headers, the period chip, the header block, or the pinned action button;
- change any color or type size outside the new surfaces;
- change what a tap, a left-swipe, or a held left-swipe on a row does;
- touch the Ledger, Planner, or Insight tabs, or any export, backup, or sync payload.

The **filter button's active state** follows the pattern already established by the Balance screen's category filter: **the icon fills in and brightens one step; the background never changes.** No badge, no count, no tint. If that button already exists on Balance, reuse its implementation.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · Sort

A bottom sheet, title `SORT`, rows with a leading checkmark slot marking the active option.

**Account detail screen:**

```
SORT
✓  Date — newest first          (default)
   Date — oldest first
   Amount — high to low
   Amount — low to high
   Category — A to Z
```

**Category detail screen:** identical except the last row is `Account — A to Z`. On a category screen every transaction shares one category, so sorting by category would be a no-op; on an account screen the same is true of the account. **Each screen offers the axis that actually varies on it.**

Rules:

- **`Amount` sorts on absolute value**, so a `$900` income and a `$900` expense rank together. Direction is not a tiebreaker; date descending is.
- `Category — A to Z` / `Account — A to Z` sorts by name, then date descending within each group.
- **Day-group headers render only under the two date sorts.** Under amount or name sorting, drop the headers and render one flat list — a `9 AUG` header above rows from five different days is a lie.
- Selecting a row applies immediately and closes the sheet.

---

## 2 · Filter

A bottom sheet: `#1C1C1E`, 26 pt top corner radius, max height **86%** of screen, scrollable body, pinned footer.

**Grabber** — 36 × 5 pt, `#48484A`, radius 999, centered, 8 pt top margin.

**Header row** — padding `11 18 4`: `Filter` on the left (17 pt, weight 650, white); `Reset` on the right (`#5E5CE6`, 15 pt weight 550, **35% opacity and non-interactive when nothing is set**).

**Live count** — directly beneath the header, padding `0 18 10`, 12 pt `#8E8E93`: `14 of 47 transactions`. Updates on every change. This is how the user learns what the filter costs before closing the sheet.

**Body** — padding `0 16`. Four sections, each with a caps label (11 pt, weight 650, letter-spacing 0.07em, `#8E8E93`, padding `8 2 6`; **13 pt** top padding for sections after the first).

### TYPE

Three multi-select chips: `Expense`, `Income`, `Transfer`. Selected: `#5E5CE6` fill, white text. Unselected: `#2C2C2E` fill, `#EBEBF5` text. Radius **7**, padding **`4 11`**, **13 pt**, line-height 1.2 — a **~24 pt** chip. Column spacing **6 pt**, run spacing **8 pt**.

> The 8 pt run spacing is deliberate. A 24 pt chip is below the comfortable tap size, so give each chip a transparent vertical touch inset of 4 pt above and below, bringing its hit area to **32 pt**. The 8 pt gap between rows is exactly what keeps those extended areas from overlapping. Do not reduce it to match the column spacing.

### CATEGORIES *(account screen)* / ACCOUNTS *(category screen)*

Multi-select chips with the same metrics but padding **`4 10`**, each carrying a **6 pt** dot in the category's own color with a **5 pt** gap to the label (accounts use their category's color).

**List only the categories or accounts that actually occur on this screen's transactions**, not every one defined in the app. Order them by transaction count, descending. If there are more than 8, show the first 8 and a `+N more` text button in `#5E5CE6` that expands the rest in place.

### AMOUNT

Two fields side by side, `#2C2C2E`, radius **9**, padding **`5 10`**, **8 pt** apart, with an em dash between them in `#636366`.

**Each field is one line, not two:** the caps key `MIN` / `MAX` (10 pt, weight 650, `#8E8E93`) sits at the left, the value (**14 pt**, weight 600, white, tabular) is **right-aligned** in the remaining space. Stacking the key above the value is what made these fields ~44 pt tall; inline they are **~28 pt**. The field being edited carries an inset 1.5 pt `#5E5CE6` border.

Beneath, 11.5 pt `#636366`: `Transactions here range $12 – $5,000` — the real min and max of the unfiltered set on this screen, so the user does not type into empty space.

**Matching is on absolute value**, so `$900` income and `$900` expense both fall in the same band. Either bound may be left empty, meaning unbounded on that side.

### TAGS

Multi-select chips, same styling, no dot. **Only tags that occur on this screen's transactions.** If no transaction here has a tag, **omit the whole section** — do not render an empty one.

**Footer** — pinned, 1 pt top divider, padding `11 16 13` plus safe-area bottom. Full-width `Done` button: 47 pt tall, radius 14, `#5E5CE6`, white 16 pt weight 650.

### Filter logic

**Within a section, OR. Across sections, AND.**

```
matches(tx) =
      (types.isEmpty      || types.contains(tx.type))
  &&  (groupIds.isEmpty   || groupIds.contains(tx.categoryId or tx.accountId))
  &&  (min == null        || tx.absoluteAmount >= min)
  &&  (max == null        || tx.absoluteAmount <= max)
  &&  (tags.isEmpty       || tx.tags.any(tags.contains))
```

An empty section is **no constraint**, not "match nothing".

**No Apply/Cancel model.** Every change applies immediately to the screen behind the sheet. `Done` only closes it.

---

## 3 · Search

Tapping the search button turns the count row into a search field **in place** — no pushed screen, so the header and period stay visible.

- The count row and the three tool buttons are replaced by: a full-width field (`#1C1C1E`, radius 10, padding `8 10`) with a leading magnifier in `#636366`, the text at 14 pt white, and a trailing clear glyph; then a `Cancel` text button in `#5E5CE6`.
- The field **autofocuses** and the keyboard opens.
- Beneath it, `3 results` at 12.5 pt `#8E8E93`.
- Filtering is **live**, debounced ~200 ms.

**What it matches:** the transaction's description, its category name, its account name, its tags, and the digits of its amount. A query of `120` finds a `$120` transaction.

**Case and diacritic insensitive.** Turkish is the trap here: Dart's default `toLowerCase()` maps `İ` to `i̇` (i plus a combining dot), so `İstanbul` will not match `istanbul`. Use locale-aware folding or normalise diacritics explicitly, and **test with `İ`, `ı`, `Ş`, `ğ`, `Ö`, `Ü`**.

**Highlight the matched substring** in the row's text with `rgba(94,92,230,0.3)` background and white text. Highlight in whichever field matched.

`Cancel` exits search and restores the count row. Clearing the text keeps search mode active with an empty query, which shows the unsearched list.

**Search state is transient** — leaving the screen exits search. It is never persisted.

---

## 4 · How the three compose

Order of operations, applied once per rebuild:

```
1. period    — from the period chip
2. filter    — §2
3. search    — §3
4. sort      — §1
5. grouping  — day headers, only under date sorts
```

- **Search runs inside the selected period.** A query only finds transactions in the window the chip is showing. If a user searches `rent` in `1–31 Aug`, they see August's rent, not every rent ever.
- **Everything on screen reflects the composed result** — the transaction count, the chip's in/out figures, and the list. No unfiltered value may leak through.
- **When a filter or a search is narrowing the list, the count row reads `14 of 47 transactions`** instead of `47 transactions`, so the user always knows the list is incomplete. This is the primary signal; the filled funnel icon is the secondary one.
- Changing the period keeps the filter and the search query applied to the new window.

---

## 5 · Persistence

- **The sort selection persists per screen type** — all account screens share one preference, all category screens share another. Suggested keys: `account_trans_sort`, `category_trans_sort`.
- **The filter persists per screen instance** — per `accountId` on account screens, per `categoryId` on category screens. Returning to Main Checking restores the filter you left there; opening Cash Wallet does not inherit it. Suggested key shape: `trans_filter_account_{id}`, `trans_filter_category_{id}`.
- **Prune stale IDs on load.** A persisted category or tag ID that no longer exists is dropped silently, so a deleted category can never leave the button looking active with nothing behind it.
- **Search never persists.**
- Restore before first paint — the screen must never flash an unfiltered list and then re-render.

---

## 6 · Empty states

| Situation | What renders |
|---|---|
| Period has no transactions at all | `0 transactions`, the app's existing empty state. Chip and tool buttons still render and stay usable. |
| Filter matches nothing | `0 of 47 transactions`, and a centered message `No transactions match your filter` in `#636366` with a `Clear filter` text button in `#5E5CE6` beneath it. |
| Search matches nothing | `0 results`, and a centered message `No results for "rent"` in `#636366`. No button — the user clears the field. |
| Both active, nothing matches | Show the filter message; it is the one with a fix attached. |

The empty state never replaces the chip, the count row, or the tool buttons — only the list area.

---

## 7 · Accessibility

- Each tool button has a `Semantics` label: `Sort transactions`, `Filter transactions`, `Search transactions`.
- The filter button carries a `value`: `Active, 14 of 47 shown` when narrowing, `Off` otherwise. With no background change, this is the only signal a screen-reader user gets.
- Chips are semantically toggles, announcing selected state and their label.
- The sort sheet's rows announce which is selected.
- Entering search moves focus to the field and announces it; `Cancel` is reachable.
- Result-count changes are announced as a live region so a screen-reader user knows the list changed under them.

---

## 8 · Edge cases

| Case | Required behavior |
|---|---|
| Only one category occurs on an account screen | The CATEGORIES section still renders with that one chip — do not hide it; hiding it would make the filter look broken. |
| No transaction on this screen has a tag | Omit the TAGS section entirely. |
| `MIN` greater than `MAX` | Treat as an empty range and show `0 of 47`; do not swap the values silently. Mark the offending field's border `#FF453A`. |
| Non-numeric text typed into an amount field | Reject the keystroke; use a numeric keyboard. |
| Filter active, then the period changes | Filter stays applied to the new period; the count and chip figures recompute. |
| Filter active, then a matching transaction is deleted | Counts recompute; if the list empties, the filter empty state renders. |
| Search query matches an amount and a description | The row appears once; highlight the field that matched, preferring the description. |
| Sort set to amount, then search entered | Results stay in amount order and remain header-less. |
| Screen entered with a persisted filter | Count row reads `N of M` and the funnel icon is filled, on first paint. |
| Very long tag or category name on a chip | Chip grows; the row wraps. Chips never truncate — a half-shown tag is unreadable. |
| Device text scaling at max | Sheets scroll; chips wrap; nothing overflows. |

---

## 9 · Acceptance criteria

- [ ] None of the three buttons is inert; each opens its surface.
- [ ] Sort offers five options; the last is `Category — A to Z` on account screens and `Account — A to Z` on category screens.
- [ ] `Amount — high to low` ranks a `$900` income and a `$900` expense adjacently.
- [ ] Day-group headers disappear under amount and name sorts and return under date sorts.
- [ ] The filter sheet shows all four sections, with TAGS omitted when no transaction here has one.
- [ ] Category and tag chips list only values occurring on this screen, ordered by count.
- [ ] Selecting `Expense` and `Income` shows both; adding `Housing` narrows to Housing only.
- [ ] An empty section imposes no constraint.
- [ ] The amount range matches on absolute value.
- [ ] The live count in the sheet updates on every change.
- [ ] `Reset` is disabled when nothing is set and clears everything when it is not.
- [ ] Every filter change applies immediately behind the sheet; `Done` only closes it.
- [ ] The filter button fills its icon when narrowing, with **no background change**.
- [ ] Search opens in place, autofocuses, filters live, and highlights matches.
- [ ] Searching `İstanbul` matches `istanbul`; searching `sise` matches `şişe`.
- [ ] Search finds a `$120` transaction from the query `120`.
- [ ] Search results are confined to the selected period.
- [ ] The count row reads `14 of 47 transactions` whenever the list is narrowed, and the chip's in/out figures agree with it.
- [ ] Sort persists per screen type; the filter persists per account and per category; search never persists.
- [ ] Re-entering a screen with a saved filter shows the narrowed list on first paint, with no unfiltered flash.
- [ ] A deleted category's ID is pruned and cannot leave the button looking active.
- [ ] Each empty state renders as specified, and never replaces the chip or the tool buttons.
- [ ] Chips measure ~24 pt tall with a 32 pt vertical hit area, and chip rows sit 8 pt apart so those hit areas do not overlap.
- [ ] The `MIN` and `MAX` fields are single-line — key left, value right-aligned — measuring ~28 pt.
- [ ] Screen reader announces each button, the filter's active value, and chip states.
- [ ] No analyzer warnings.

**Tests to write:**

- unit test: `matches()` — OR within a section, AND across sections, empty section as no constraint;
- unit test: amount matching on absolute value, with each bound absent in turn;
- unit test: `MIN > MAX` yields zero matches and does not swap;
- unit test: Turkish case folding — `İ`/`i`, `ı`/`I`, `Ş`/`s`, `ğ`/`g` all match as intended;
- unit test: amount-digit search matches `$120` for the query `120`;
- unit test: absolute-value sort ranks `+900` and `−900` adjacently;
- widget test: day headers present under date sort, absent under amount sort;
- widget test: search results never include a transaction outside the selected period;
- widget test: a persisted filter is applied on first paint with no intermediate unfiltered frame;
- widget test: each of the three empty states renders its specified content.

---

## 10 · Non-goals

- A search screen or a global search across tabs
- Saved filter presets or named views
- Filtering by note content, running balance, or currency
- Fuzzy or typo-tolerant search
- Search history or suggestions
- A chip row, banner, or badge on the screen outside the count row's `N of M`
- Extending any of this to the Ledger, Planner, or Insight tabs
- Any redesign of the screens, rows, or period chip

---

## Deliverable

List the files you created and modified. Report: whether the Balance screen's filter button implementation could be reused for the active state; how you handled Turkish case folding and which API you used; whether the repository could satisfy the filter with an indexed query or needed in-memory work, and on what data volume you measured it; and how the per-instance filter keys are scoped. Flag any deviation from this spec and why.
