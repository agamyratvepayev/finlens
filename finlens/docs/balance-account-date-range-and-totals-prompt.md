# Balance — Account Transaction Date Range and Total Amount Fixing

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. On the **Balance** tab, expanding a category reveals its accounts. Each account row has a name on the left and an amount on the right.

**Those two halves currently open two different screens.**

- Tapping the **amount** opens the current screen: `‹ Balance` back label, a `•••` menu, the account name and balance, `Spendable · USD`, a **period chip** (`‹ 1–31 Aug ›` with in/out figures), an `8 transactions` row with sort/filter/search buttons, day-grouped rows with running balances, and a pinned `+ Add expense`.
- Tapping the **name** opens a legacy screen: a plain `←` back arrow, a static `Last 30 days   In $6,100  Out $3,102` line, **no** transactions-count row, **no** tool buttons, and signed amounts (`+$900`).

They also disagree on the numbers, because they use different period models — one a calendar month, the other a rolling 30-day window.

A **period sheet already exists** and opens from the chip. It lists `This week`, `Last week`, `This month`, `Last month`, `Last 3 months`, `This year`, each with a date-range preview on the right. **It has three defects, fixed in §4.**

**Match the project's existing conventions.** Use the state management, models, repository, persistence layer, and design tokens already there. Do not introduce a new state-management library or a new design-token system. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

Strictly a consolidation plus targeted fixes. Do **not**:

- redesign the surviving screen — its colors, type scale, row heights, card radii, day-group structure, running-balance column, tool buttons, or pinned button all stay as they are;
- redesign the period sheet — its background, radius, grabber, row height, padding, type sizes, and colors stay as they are. §4 changes **which rows it lists, what they say, and how it is sized** — nothing else;
- change the Balance list itself — the account row's layout, the category rows, the ratio bar, the header controls;
- change how any amount is formatted or signed (that is a separate task);
- change the day-group total rule on this screen;
- touch the Ledger, Planner, or Insight tabs, or any export, backup, or sync payload.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · One screen, both taps

The screen reached by tapping the **amount** is canonical. The legacy screen is deleted.

- Tapping **anywhere on an account row** — name, amount, icon, or the space between — opens the canonical screen. Make the whole row one tap target rather than two.
- Delete the legacy screen widget and its route. `git grep` its class name and route name; if any other entry point in the app pushes it (search results, notifications, deep links, the Ledger), point those at the canonical screen too. **Report every entry point you repointed.**
- Nothing from the legacy screen is carried over. Its `Last 30 days` line, its `←` back arrow, and its signed amounts all go with it.

---

## 2 · The period model

The category detail screen and the account detail screen must share **one period model and one chip widget** — not two implementations that happen to look alike. If they currently have separate period logic, unify it and **say so in your report**.

A period has two parts:

- a **unit** — week, month, quarter, or year;
- a **cursor** — which week, month, quarter, or year is shown.

Every row in the period sheet sets both at once:

| Row | Unit | Cursor set to |
|---|---|---|
| `This week` | week | current week |
| `Last week` | week | previous week |
| `This month` *(default)* | month | current month |
| `Last month` | month | previous month |
| `Last 3 months` | quarter (3-month block) | the block ending with the current month |
| `This year` | year | current year |

`‹` and `›` then step the cursor by **one unit** — one week, one month, one 3-month block, or one year. This is what makes the arrows meaningful for every row: `Last week` is not a separate mode, it is the weekly unit with the cursor moved back one, and `‹` keeps walking backwards from there.

Navigating to a period with no transactions is allowed — show the empty state, do not block the arrows. Future periods are reachable too; do not clamp the arrows to today.

### Period bounds are whole periods

Bounds always run from the first day to the last day of the period, **never clamped to today**:

- `This week` → `3–9 Aug`
- `This month` → `1–31 Aug`
- `Last 3 months` → `1 Jun – 31 Aug`
- `This year` → `1 Jan – 31 Dec`

The sheet currently previews `This year` as `1 Jan – 9 Aug`, clamped to today, while `This month` previews the whole month. **That inconsistency is a bug — fix it to whole periods.** Clamping is the wrong choice here because the chip already displays `1–31 Aug` for the current month; clamping would have to change that too, which the hard boundary forbids.

---

## 3 · The chip

Keep the chip's existing height, background, radius, margins, padding, font sizes, colors, and chevron glyphs. Two things change.

**3a. The label becomes a control.** Tapping the label opens the period sheet. The `‹` and `›` arrows keep stepping the cursor and do **not** open the sheet — they must stay independently tappable, so give the label its own hit area between them.

A **`▾` at 10 pt in `#A5A3FF`** sits immediately after the label, before the `›`, marking the label as tappable.

> There is already a small mark rendering between the label and the forward chevron — earlier notes described it as a stray dash. **Find its source, name it in your report, and replace it with this `▾`.** If it turns out to be something else entirely, stop and report before changing it.

The label always shows the **date range**, not the row name: `1–31 Aug`, `3–9 Aug`, `1 Jun – 31 Aug`, `1 Jan – 31 Dec`. Short form with no year when both ends fall in the current year; otherwise include the year.

**3b. The in/out figures move to the right edge.** They currently sit just after the chevron, leaving a gap at the chip's right end. The chip is a `Row`: keep the navigation group (`‹` + label + `▾` + `›`) at the start and push the figures to the end with a `Spacer()` or `MainAxisAlignment.spaceBetween`.

The figures render in **full form, not abbreviated**: `↓ $6,100` and `↑ $3,102`, not `↓ $6.1K`. Tabular figures. The `↓` / `↑` glyphs stay exactly as they are — they are direction indicators, not signs. The gap between the two figures is unchanged.

At 320 pt width and maximum text scaling, the **label** truncates with an ellipsis; the figures never wrap and never shrink.

---

## 4 · The period sheet — three fixes

The sheet exists. Do not rebuild it and do not restyle it. Fix these three things.

### 4a. It overflows

The sheet currently renders a `BOTTOM OVERFLOWED BY 2.4 PIXELS` stripe. Its content is taller than the box it is given.

- Wrap the row list so it **sizes to its content and scrolls if it exceeds the available height** — do not hard-code a height and do not let a fixed-height `Column` run past the sheet's constraints.
- Add **bottom safe-area padding** below the last row, so the home indicator never sits on top of it. A missing safe-area inset is the most likely cause of a small, constant overflow like 2.4 pt.
- Verify at 320 × 568 (smallest supported), at 375 × 812, and at **130% text scale** — the overflow must not reappear at any of them.

### 4b. The active row has no checkmark

Nothing on the sheet indicates which period is currently selected. The active row gets a **`✓` in `#A5A3FF`** in a left slot, and its label goes to weight 600 — matching how the app marks the active option in its other option sheets. Every other row keeps an empty slot of the same width so the labels stay aligned.

### 4c. The preview dates are inconsistent

Right-hand previews are 12.5 pt `#636366` and show that row's **whole-period bounds** per §2 — the same string the chip will display after selecting it. `This year` becomes `1 Jan – 31 Dec`.

### The row list

Exactly these six rows, in this order:

```
Period
✓  This month              1–31 Aug
   Last month              1–31 Jul
   This week                3–9 Aug
   Last week           27 Jul – 2 Aug
   Last 3 months      1 Jun – 31 Aug
   This year          1 Jan – 31 Dec
```

`This month` moves to the top because it is the default and the most-used. If the existing sheet has additional rows below the visible area (an `All time` or a custom-range entry), **keep them, place them last, and report that they exist** — they are not visible in the current screenshot and must not be dropped by accident.

Selecting a row applies the period immediately and closes the sheet. There is no Apply button and no Cancel. Tint the chip `rgba(94,92,230,0.16)` while the sheet is open.

---

## 5 · Persistence and independence

- **The unit persists across relaunch; the cursor does not.** Opening the screen always lands on the period containing today, at the saved unit. A user who left it on `This year` sees this year, not the year they were browsing last week. A user who left it on `Last month` sees the month unit with the cursor on the current month.
- The preference is stored **per screen type**: all account screens share one, all category screens share another. Suggested keys: `account_period_unit`, `category_period_unit`.
- This period is **independent** of the range control on the Same-transactions screen. Neither writes to the other; they must not share state.

---

## 6 · The in/out totals

Everything on the screen recomputes from the selected period — the two chip figures, the `N transactions` count, and the transaction list itself. No cached value from a previous period may survive.

```
inTotal(period)  = Σ amount of money-in transactions on this account in period
outTotal(period) = Σ amount of money-out transactions on this account in period
```

- Both are rendered as positive magnitudes; the `↓` / `↑` glyphs and the green/red colors carry direction.
- **Transfers count on the side that affects this account.** A transfer leaving this account counts toward `out`; a transfer arriving counts toward `in`. A transfer between two *other* accounts does not appear on this screen at all. If the repository models a transfer as two rows, make sure this account's side is counted exactly once. **Report how transfers are modelled and how you handled it.**
- Sum in the **account's own display currency** — every transaction on the screen belongs to this account, so there is one currency and no conversion is needed. If the app's established convention is base currency, follow that and reuse the existing conversion path; do not add a second one.
- Query through an **indexed** `(accountId, dateRange)` repository method. Do not load all transactions and filter in Dart. If the index does not exist, add it and say so.

---

## 7 · Edge cases

| Case | Required behavior |
|---|---|
| Period has 0 transactions | `0 transactions`, `↓ $0` and `↑ $0`, empty state below. The chip and tool buttons still render and stay usable. |
| Period has only income | `↑ $0` still renders — do not hide a zero figure, or the layout shifts between periods. |
| Week unit near a year boundary | The week spans both years; the label includes the year on both ends. |
| 3-month block stepping backwards | Steps a whole block at a time — `1 Jun – 31 Aug` → `1 Mar – 31 May`. Do not step one month. |
| Account has a future-dated transaction | It appears when the cursor reaches that period; do not clamp the arrows to today. |
| Account renamed or its category changed while open | Header follows the current values; matching is by ID. |
| Very long account name | Truncates with an ellipsis; the balance figure never shrinks or wraps. |
| Device text scaling at max | Chip label ellipsises; both figures stay on one line (§3b); the sheet scrolls rather than overflows (§4a). |
| Pull-to-refresh | Period selection survives; everything recomputes for the same period. |

---

## 8 · Acceptance criteria

Fixture: `Main Checking`, `$12,198`, `Spendable · USD`, 8 transactions in `1–31 Aug`.

**Consolidation**

- [ ] Tapping the account **name** and tapping the account **amount** open the **same** screen.
- [ ] That screen has the `‹ Balance` back label, the period chip, the `N transactions` row, and the tool buttons.
- [ ] The legacy screen's widget and route no longer exist in the codebase; every entry point that used it is repointed and listed in your report.
- [ ] The account screen and the category screen use the **same** chip widget and the **same** period model — confirmed in your report.

**Chip**

- [ ] The chip reads `‹ 1–31 Aug ▾ ›` with the in/out figures flush against the chip's right inset.
- [ ] Figures render full-form (`↓ $6,100`), not abbreviated, with `↓` / `↑` unchanged.
- [ ] The small mark formerly rendering before `›` is gone; its source is named in your report.
- [ ] Tapping the label opens the sheet; tapping `‹` or `›` steps the cursor and does **not** open the sheet.

**Sheet**

- [ ] **No overflow stripe** at 320 × 568, 375 × 812, or 130% text scale.
- [ ] The bottom row clears the home indicator.
- [ ] The active row shows a `✓` in `#A5A3FF` and weight 600; inactive rows keep an aligned empty slot.
- [ ] `This month` is first; the six rows appear in the §4 order; any pre-existing extra rows are kept and reported.
- [ ] `This year` previews `1 Jan – 31 Dec`, matching what the chip shows after selecting it.
- [ ] Selecting a row applies immediately and closes the sheet.

**Period behavior**

- [ ] `This week` makes `‹ ›` step weeks; `This month` months; `Last 3 months` whole 3-month blocks; `This year` years.
- [ ] `Last month` puts the cursor on the previous month, and `‹` from there reaches the month before it.
- [ ] Changing the period recomputes the two figures, the transaction count, and the list together.
- [ ] The two chip figures equal the sums of the money-in and money-out transactions listed for that period.
- [ ] The unit survives relaunch; the cursor resets to the period containing today.
- [ ] The Same-transactions screen's own range is unaffected by changes here, and vice versa.
- [ ] The account query is index-backed; no full-table scan in the diff.
- [ ] No analyzer warnings.

**Tests to write:**

- widget test: tapping the account name and tapping the account amount push the same route;
- widget test: tapping `‹` steps the period and does not open the sheet; tapping the label opens the sheet;
- unit test: bounds for each of the six rows, asserting whole periods and not today-clamped;
- unit test: stepping backwards from `Last 3 months` yields `1 Mar – 31 May`;
- unit test: in/out totals for a period containing income, expense, an outgoing transfer, and an incoming transfer;
- unit test: a transfer between two other accounts is excluded;
- widget test: the sheet renders without overflow at 320 × 568 and at 130% text scale;
- widget test: the unit survives a restart while the cursor resets to today's period.

---

## 9 · Non-goals

- Redesigning the surviving account screen or the period sheet's styling
- Changing amount formatting or sign handling
- Changing the day-group total rule on this screen
- Adding a period control to the Ledger, Planner, or Insight tabs
- Wiring the filter or search tool buttons (separate task)
- Any cleanup or normalization of unrelated style values

---

## Deliverable

List the files you created and modified. Report: every entry point that used the legacy screen and where you repointed it; the source of the small mark before `›`; whether the period sheet had rows hidden below the overflow and what they were; the cause of the 2.4 pt overflow; confirmation that the account and category screens now share one period model and one chip widget; how transfers are modelled and how you counted this account's side; and any repository index you had to add.

Also **report without changing**: on the surviving screen, day-group headers render a day total even on days with only two transactions. That contradicts the three-transaction threshold defined for the Ledger tab. It is out of scope here — flag it so it can be decided separately.
