# Implementation Prompt — Tap a Transaction → "Same" Transactions (Flutter)

## This supersedes two earlier rules

Two earlier specs in this project defined how a tapped transaction finds its related transactions. **Both are now void.** Do not implement either:

- ~~"Matching rule: same category. That is the whole rule."~~ (similar-transactions spec)
- ~~"Whatever label the user tapped is what the next screen lists."~~ (transaction-drilldown spec)

**The rule is now a composite key, defined in §2.** If you find code implementing either old rule, replace it. If you find both, replace both with one implementation.

---

## Role and context

You are working on **FinLens**, a Flutter personal-finance app. Transaction rows appear on the **category detail** screen and the **account detail** screen, both reached from the Balance tab.

Tapping a transaction row currently opens the **edit** screen. That is the correctness problem this work fixes: a stray tap while scrolling can silently change financial data.

**Match the project's existing conventions.** Use the state management, domain models, repository, persistence layer, and design tokens that are already there. Do not introduce a new state-management library, a new persistence mechanism, or a new design-token system. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

Do **not** change: colors, the type scale, row heights, card radii, section headers, the day-grouping structure, the category and account header blocks, the period chip, the pinned action button, the tab bar, or the Balance tab's own list. Do not touch the Ledger, Planner, or Insight tabs, or any export, backup, or sync payload.

Do not add: filter chips, a bar chart, a `THIS ONE` text pill, or any scope selector on the new screen.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · A tap never opens the edit screen

Tapping a transaction row now opens the **read-only Same-transactions screen** (§3). This applies on the category detail screen and the account detail screen.

Editing stays reachable only through deliberate gestures:

- the **left-swipe** menu on the row (`Edit · Copy · Move · Delete`), which already exists;
- the **`•••`** menu in the new screen's nav bar, offering the same four actions on the transaction you came from.

Nothing on the new screen is editable in place.

---

## 2 · The key

The tapped transaction resolves to a **key**, and the screen lists every transaction sharing that key.

| Transaction type | Key | List contains |
|---|---|---|
| Income or expense | `categoryId` + `accountId` + `direction` | every transaction in that category, **on that account**, in that direction |
| Transfer | `fromAccountId` + `toAccountId` | every transfer **from that account to that account** |

Rules:

- **The account is part of the key.** `Groceries` on `Main Checking` and `Groceries` on `Cash Wallet` are two different lists. Do not pool them.
- **Direction is part of the key.** Income and expense never appear in the same list; a mixed total would be meaningless.
- **The description is *not* part of the key.** `Weekly shop`, `Bakery & fruit`, and `Market run` all appear together because all three are `Groceries` on `Main Checking`.
- **Transfers are directional.** `Main Checking → Credit Card` and `Credit Card → Main Checking` are two different keys. Do not merge them.
- Matching is always **by ID**, never by name string. A renamed category keeps its list intact.

### Rows in this list are not tappable

Every row on the screen shares the key of the screen, so tapping one could only reopen the same screen. Rows therefore carry **no tap action and no chevron**. There is no recursion and no narrowing mechanism to build.

Rows **do** keep the left-swipe menu (`Edit · Copy · Move · Delete`), so a wrong entry spotted in the history can be fixed where it is seen. Reuse the existing swipe implementation; do not write a second one.

---

## 3 · The screen

Reuse existing design tokens wherever the app already has them. The values below are the intended result, not an invitation to introduce a second token set.

### 3a. Nav bar

`‹ Back` on the left in `#A5A3FF` — use the app's existing back-label convention if it labels back buttons with the originating screen. `•••` on the right in `#A5A3FF`, opening `Edit · Copy · Move · Delete` for the **originating** transaction.

### 3b. Header block

Padding `12 20 2`, a row of: a **40 pt** rounded-square icon tile (radius 12, the category's color at ~20% opacity, the category's existing icon), then a column:

- **Title** — 21 pt, weight 700, letter-spacing −0.02em, white. Wraps to at most two lines, then ellipsis.
  - income/expense → the category name, e.g. `Groceries`
  - transfer → `{From} → {To}`, e.g. `Main Checking → Credit Card`
- **Subtitle** — 12.5 pt `#8E8E93`.
  - income/expense → `{Account} · {Expense|Income}`, e.g. `Main Checking · Expense`
  - transfer → `Transfer`

For a transfer, use the app's transfer icon and its accent; if none exists, a `#5E5CE6` tile at 20% opacity with an exchange glyph.

### 3c. Summary card

`#1C1C1E`, radius 14, margin `0 12 8`. It is deliberately compact — this is a reference block, not the subject of the screen.

1. **Range row** — the range value centered, **13 pt**, weight 600, `#A5A3FF`, followed by a `▾` at 10 pt; padding `7 14`; 1 pt `rgba(255,255,255,0.07)` bottom divider. **The value is the control — there is no "Range" label.** The whole row is the tap target and opens the sheet in §4. Tinted `rgba(94,92,230,0.16)` while the sheet is open.
2. **Three equal columns**, padding `9 6 0`: caps key (**10 pt**, weight 650, letter-spacing 0.05em, `#8E8E93`) above a value (**17 pt**, weight 700, tabular, white) with **1 pt** between them: `TOTAL`, `AVERAGE`, `COUNT`.
3. **Frequency line** — margin `7 14 0`, 1 pt `rgba(255,255,255,0.07)` top divider, padding `6 0 8`, centered **11.5 pt** `#8E8E93`, variables `#D4D4DA` weight 600: `About 4 times a month · last one 7 days ago`.

The summary values must stay one visual step above the list rows below them. Do not shrink them to the row amounts' size.

### 3d. Section label

Padding `14 20 6`, 11 pt, weight 650, letter-spacing 0.06em, `#8E8E93`:

- income/expense → `ALL GROCERIES · MAIN CHECKING`
- transfer → `ALL MAIN CHECKING → CREDIT CARD`
- append the range **only when it is a custom range**: `ALL GROCERIES · MAIN CHECKING · 1 JUN – 15 AUG`

### 3e. List card

`#1C1C1E`, radius 14, margin `0 12`, rows split by 1 pt `rgba(255,255,255,0.06)`. Row padding `8 12`:

- date in a fixed **48 pt** column, 12.5 pt `#8E8E93` (`9 Aug`, `28 Jul`);
- **title on one line**, 14.5 pt white — the transaction's description; fall back to the category name when the description is empty, or `Transfer` for a transfer with no description;
- amount right-aligned, 14.5 pt weight 650, **unsigned**, through the shared formatter.

**There is no account line under the title.** The account is fixed by the key, so printing it on every row would repeat the header.

Amount color: expense red, income green, as elsewhere in the app. **Transfers are neither** — money moves between the user's own accounts and net worth does not change. Use the app's existing transfer color if it has one; otherwise render transfer amounts neutral (`#EBEBF5`). Do not invent a new red/green rule for them. **Report which you used.**

Newest first. Show the 5 most recent, then a centered `See all {n} ›` footer row in `#A5A3FF` (14 pt, weight 550) pushing the same screen with the full list.

**The transaction the user came from stays in this list, in date order — do not filter it out.** Highlight it with background `rgba(94,92,230,0.13)` and a 2.5 pt `#5E5CE6` left edge, square corners on that edge. **No text pill.** Because the highlight is purely visual, that row's semantics label must include **`current transaction`**, or a screen-reader user cannot tell which row they came from.

---

## 4 · Date range

Tapping the range row opens a bottom sheet: `#161618`, top radius 20, a 34 × 4 `#48484A` grabber, title `DATE RANGE` (11 pt, weight 650, letter-spacing 0.06em, `#8E8E93`), rows at 15 pt with padding `11 20` split by 1 pt `rgba(255,255,255,0.06)`.

```
DATE RANGE
   This month              2
   Last month              3
✓  Last 3 months           7      ← default
   Last 6 months          14
   Last 12 months         26
   This year              21
   All time               38
🗓 Custom range…
```

- The **right-hand number is the transaction count for that range under the current key** — the user must see an empty range before entering it. Compute all seven counts in **one grouped query**, not seven round-trips.
- The active row is bold with a `✓` in `#A5A3FF`.
- A preset whose count is `0` renders dimmed and is **not selectable**.
- `Custom range…` is an accent-colored row that pushes the picker below.

### Custom range picker

Same sheet style, title `CUSTOM RANGE`. Two fields side by side, `#2C2C2E`, radius 10, padding `8 11`: caps key `FROM` / `TO` (10 pt, weight 650, `#8E8E93`) above the date (14.5 pt, weight 600). The field being edited carries an inset 1.5 pt `#5E5CE6` border.

Below, one month of a calendar: month name 14.5 pt weight 650 with `‹ ›` month navigation in `#A5A3FF`; a `S M T W T F S` header row (10.5 pt, weight 600, `#636366`); square day cells, 13 pt tabular, radius 8. In-range days get `rgba(94,92,230,0.18)` with square corners so the run reads as one band; the two endpoints get solid `#5E5CE6`, weight 700, with the outer corner rounded. Days outside the selection are white; days with no transactions under the current key are `#4A4A4E`.

A full-width `#5E5CE6` button, radius 12, margin `14 16 0`, padding 12, 15 pt weight 650: **`Apply · 3 transactions`** — the count updates live as the selection changes, and the button is **disabled when the count is 0**.

Rules:

- `TO` may not precede `FROM`; tapping an earlier day than `FROM` restarts the selection with that day as the new `FROM`.
- Future dates are selectable but expected to be empty; do not block them.
- Applying returns to the screen with the range row reading `1 Jun – 15 Aug ▾` (short form, no year when both ends are in the current year; otherwise include the year).

### Range behavior

- **Default `Last 3 months`.** One month is too short to support a frequency figure.
- The choice **persists across relaunch**, shared by all Same-transactions screens — **one preference, not per key.** Suggested key: `same_list_range`.
- **`TOTAL`, `AVERAGE`, `COUNT`, the frequency line and the list all recompute from the selected range.** Nothing on the screen may be left showing a different window.
- **If the listed transactions span fewer than 14 days, hide the frequency line entirely** — "about N times a month" from 3 days of data is a fabrication.
- This range is **independent of the period chip** on the category and account screens. The chip may read `1–31 Aug` while this reads `Last 3 months`. Neither writes to the other; they must not share state.

---

## 5 · Computation

```
keyOf(tx):
    if tx.isTransfer:  TransferKey(tx.fromAccountId, tx.toAccountId)     // directional
    else:              LedgerKey(tx.categoryId, tx.accountId, tx.direction)

same(key, range):
    repository.transactions(key, from: range.from, to: range.to)
              .sortedByDateDescending()

stats(list):
    total    = Σ |amount|
    count    = list.length
    average  = count == 0 ? 0 : total / count
    spanDays = (list.first.date - list.last.date).inDays
    perMonth = spanDays < 14 ? null : count / (spanDays / 30.44)
```

- Round `perMonth` for display; if it rounds to 0, show `Less than once a month`.
- **Currency.** Because the account is part of the key, every row in a ledger-key list shares one account and therefore one currency — sum and display in that account's own display currency, with no conversion. For a transfer key, use the **source** account's currency. If the app's established convention is to show totals in base currency, follow that instead and reuse the existing conversion path — do not add a second one.
- **Transfers are counted once.** If the repository models a transfer as two rows (a debit on one account and a credit on the other), the list must show it **once** and `TOTAL` must include it **once**. Double-counting doubles every figure on the card. **Report how the repository models transfers and how you handled it.**
- Query through **indexed** repository methods — `(categoryId, accountId, direction, date)` for ledger keys and `(fromAccountId, toAccountId, date)` for transfers. Do **not** load all transactions and filter in Dart. If the indexes do not exist, add them and say so in your report.
- Amounts render **unsigned** through the shared formatter — direction is carried by color, as elsewhere in the app.

---

## 6 · Edge cases

| Case | Required behavior |
|---|---|
| Count 1 — only the transaction you came from | Still show the screen: `COUNT 1`, no frequency line, one highlighted row. Do not show an empty state. |
| Count 0 for the selected range | Keep the summary at `$0 / $0 / 0`, hide the frequency line, and show an empty-list message naming the range — `No Groceries on Main Checking between 1 Jun and 15 Aug`. |
| Span under 14 days | Frequency line hidden. |
| Fewer than 6 matches | List them all; hide `See all` when the range count equals the total shown. |
| Originating transaction deleted via `•••` | After the delete confirms, **pop back** to where the user came from. Never leave the screen showing a key with no subject. |
| Originating transaction edited via `•••` or swipe so its key changes | On return, re-resolve the key from the updated transaction and rebuild the screen for the new key. |
| A row in the list deleted via swipe | Remove it, recompute the summary; if it was the originating transaction, pop back. |
| Category renamed | Title and label follow the current name; matching is by ID. |
| Account renamed | Same. |
| Transfer where the two accounts hold different currencies | Use the source account's currency; do not silently mix. |
| Very large key (1000+ matches) | Show 5; `See all` paginates if the repository supports it; stats come from an aggregate query, not by materializing every row. |

---

## 7 · Acceptance criteria

**Tap and key**

- [ ] Tapping a transaction row **never** opens the edit screen — from the category screen, the account screen, and from within the new screen.
- [ ] `Groceries` on `Main Checking` and `Groceries` on `Cash Wallet` produce **two different lists**.
- [ ] `Weekly shop`, `Bakery & fruit` and `Market run` all appear in one list when they share category, account, and direction.
- [ ] An income key never returns expenses.
- [ ] `Main Checking → Credit Card` and `Credit Card → Main Checking` produce two different lists.
- [ ] Rows on the screen have no tap action and no chevron; swiping a row still offers `Edit · Copy · Move · Delete`.

**Screen**

- [ ] Header shows the category name over `{Account} · Expense`; a transfer shows `{From} → {To}` over `Transfer`.
- [ ] The summary card renders at the compact metrics (13 / 10 / 17 / 11.5 pt) and its values stay visibly larger than the 14.5 pt row amounts.
- [ ] Section label reads `ALL GROCERIES · MAIN CHECKING`, and appends the range only for a custom range.
- [ ] List rows show date, description and amount on one line, with **no account line**.
- [ ] Transfer amounts are neutral (or the app's existing transfer color), not red or green.
- [ ] The originating row is present, highlighted, has no text pill, and carries a `current transaction` semantics label.
- [ ] No filter chips, no bar chart, no `THIS ONE` pill anywhere.

**Range**

- [ ] The range control is the **first row of the summary card**, has no `"Range"` label, and the whole row is tappable.
- [ ] Every preset shows its real count from **one** grouped query; zero-count presets are dimmed and not selectable; `Apply` is disabled at 0.
- [ ] Changing the range recomputes summary **and** list together.
- [ ] Frequency line hidden when the listed transactions span under 14 days.
- [ ] The range choice survives relaunch, is shared by all these screens, and leaves the period chip untouched.

**Data**

- [ ] A transfer appears once and is counted once in `TOTAL`.
- [ ] Deleting the originating transaction pops the screen.
- [ ] Queries are index-backed; no full-table scan in the diff.
- [ ] No analyzer warnings.

**Fixture** — `Groceries` · `Main Checking` · expense, last 3 months, today 16 Aug:

`9 Aug 120` · `1 Aug 186` · `28 Jul 142` · `19 Jul 168` · `5 Jul 155` · `21 Jun 163` · `12 Jun 98`
→ `TOTAL $1,032`, `AVERAGE $147`, `COUNT 7`; span 12 Jun – 9 Aug = 58 days → `7 / (58/30.44) ≈ 3.7` → **`About 4 times a month · last one 7 days ago`**; list shows the 5 newest with `9 Aug` highlighted, then `See all 7`.

**Tests to write:**

- widget test: a row tap pushes the read-only screen and **never** the edit screen;
- unit test: two transactions in the same category on different accounts resolve to different keys;
- unit test: two transactions in the same category and account but opposite directions resolve to different keys;
- unit test: `A → B` and `B → A` transfers resolve to different keys;
- unit test: differing descriptions in the same category and account resolve to **one** key;
- unit test: a transfer stored as two rows is listed once and counted once;
- unit test: `stats()` for 1 transaction, 2 transactions, and a span under 14 days (`perMonth == null`);
- widget test: selecting `Last 6 months` updates `TOTAL`, `COUNT` and the row count together;
- widget test: a preset with count 0 is not selectable, and `Apply` is disabled when the custom selection is empty;
- widget test: the range choice survives a restart and leaves the period chip untouched;
- widget test: deleting the originating transaction pops the screen.

---

## 8 · Non-goals

- Matching by description, merchant, or amount
- Any fuzzy or "smart" matching
- Tappable rows, recursive drill-down, or any narrowing mechanism inside the screen
- Scope filter chips, a monthly bar chart, or a `THIS ONE` pill
- Bulk actions or multi-select
- Extending this screen to the Ledger, Planner, or Insight tabs
- Any redesign of the category screen, the account screen, or the swipe menu

---

## Deliverable

List the files you created and modified. Report: how the repository models transfers and how you avoided double-counting; which color you used for transfer amounts; and any repository index you had to add. Flag any deviation from this spec and why.
