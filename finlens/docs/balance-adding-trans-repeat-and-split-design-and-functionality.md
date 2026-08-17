# Balance — Adding Trans Repeat & Split Design and Functionality

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. The add/edit transaction screen shows: a `Cancel` / type pill (`Expense`) / `Save` nav bar; an `Amount` field with a currency selector; a `REQUIRED` card with `From` and `To` rows; an `OPTIONAL` card with `Date`, `Tag`, and `Note` rows; two buttons side by side, **`Repeat`** and **`Split`**; and a full-width bar pinned near the bottom that reads `Enter an amount` or `Choose an account` depending on what is missing.

**`Repeat` and `Split` are rendered but do nothing.** This task gives them behavior and designs their surfaces. It also removes the bottom bar.

The **Planner** tab already owns recurring transactions. `Repeat` must use that system — **do not build a second recurrence engine.** Find Planner's recurrence rule model and editor first, and **report what you found before implementing §1.**

**Match the project's existing conventions.** Use the state management, models, repository, and design tokens already there. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

Do **not**:

- change the nav bar, the `Amount` field, the currency selector, the `REQUIRED` or `OPTIONAL` cards, or their rows;
- change the two buttons' size, position, spacing, background, radius, or icons — only what they do and what their labels read;
- change Planner's recurrence model, its editor, or anything on the Planner tab;
- change transaction rows, day-group headers, running balances, or any screen that lists transactions;
- touch the Balance, Ledger, or Insight tabs.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · Repeat

### The sheet

Bottom sheet, `#1C1C1E`, top radius 20, grabber 34 × 4 pt `#48484A`. Header row padding `0 14 12`: title `Repeat` (17 pt, weight 650, white) left, `Done` (`#5E5CE6`, 14.5 pt) right.

**`HOW OFTEN`** — caps label (10.5 pt, weight 650, letter-spacing 0.07em, `#636366`, padding `0 16 5`), then a `#2C2C2E` card, radius 10, margin `0 14 12`, rows padding `8 12` split by 1 pt `rgba(255,255,255,0.06)`:

```
   Never                    (default)
   Every week
   Every 2 weeks
   Every month
   Every year
   Custom…                        ›
```

Selected row: `rgba(94,92,230,0.16)` background, label white weight 600, trailing `✓` in `#A5A3FF`. `Custom…` is `#A5A3FF` with a `#636366` chevron and opens Planner's own custom-recurrence editor — **do not write a second one.** If Planner has no custom editor, omit that row and **report it**.

**`ENDS`** — same card treatment, only shown when the frequency is not `Never`:

```
   Never                    (default)
   On a date                      —
   After a number of times        —
```

Selecting `On a date` opens the app's existing date picker; `After a number of times` reveals a numeric field. The trailing value replaces the `—` once set.

**Summary** — margin `0 14`, `rgba(94,92,230,0.13)` background, radius 10, padding `9 12`, 12.5 pt `#A5A3FF`, line-height 1.45:

> `Repeats on the 15th of every month, starting 15 Aug. Managed in Planner.`

The second sentence is required. Without it a user has no idea where the repeat lives after saving, or how to stop it.

The day and starting date are **derived from the transaction's own `Date` row** — never asked for separately. Changing the date changes the summary.

### Behavior

- The button's label reflects state: `Repeat` when off, the chosen frequency (`Every month`) when set. Its icon, size, and styling do not change.
- **Saving the transaction creates two things**: the transaction itself, dated as entered, and a Planner recurrence rule that generates the future occurrences. The entered transaction is the first occurrence and is a normal transaction in every respect.
- Future occurrences are **not** created up front as real transactions. Planner generates them on its existing schedule. **Report how Planner does this** and follow it.
- Editing a saved transaction that has a repeat opens the sheet with its current rule selected.
- Removing the repeat (`Never`) deletes the rule but leaves the already-created transaction alone.
- Repeat is available for expenses, income, and transfers alike, unless Planner's model cannot represent one of them — **report it** if so.

---

## 2 · Split

**Split divides one payment across several categories.** A `$200` supermarket receipt becomes `$150` Groceries and `$50` Household. One payment, one account, one date — several categories.

**This is not splitting a bill with other people.** Do not build shares, participants, or receivables.

### The sheet

Bottom sheet, same shell as §1. Header: title `Split by category` left, `Done` right. Beneath the title, 12 pt `#8E8E93`: `Total $200.00 · Cash (USD Wallet)`.

**Split lines** — `#2C2C2E` card, radius 11, margin `0 14 8`, rows padding `9 11` split by 1 pt `rgba(255,255,255,0.07)`. Each row:

- a 30 × 30 pt icon tile, radius 9, in the category's colour;
- the category name, 14.5 pt white — tapping it opens the existing category picker;
- the amount, 14.5 pt weight 600, right-aligned, tabular — tapping it opens a numeric field;
- a remove glyph, `#636366`, 15 pt, with a 44 pt tap target.

The last row is **`+ Add category`**: a 30 pt tile with a 1.5 pt dashed `#5E5CE6` border and a `+` in `#A5A3FF`, label in `#A5A3FF`.

**Remaining** — margin `0 14 10`, padding `0 2`, a row: `Remaining` on the left (13 pt `#8E8E93`), the figure on the right (14.5 pt, weight 600, tabular). **`#30D158` when it is exactly zero, `#FF453A` otherwise.**

**Helpers** — margin `0 14 12`, two equal buttons 8 pt apart, `#2C2C2E`, radius 9, padding `7 10`, centred 13 pt `#A5A3FF`: `Split evenly` and `Rest to last`.

**`Apply split`** — full-width, margin `0 14`, 45 pt, radius 13, `#5E5CE6`, white 15.5 pt weight 650.

### Rules

- **`Split` is disabled until the transaction has an amount.** There is nothing to divide otherwise. Show it at 35% opacity and non-interactive; do not hide it.
- **`Apply split` is disabled until `Remaining` is exactly zero.** Compare with the same rounding or epsilon the app already uses for money equality — do not introduce a new one.
- A split needs **at least two lines**. One line is not a split; `Apply split` stays disabled.
- **No line may be zero or negative.**
- `Split evenly` divides the total across the current lines, giving any rounding remainder to the **first** line so the sum stays exact.
- `Rest to last` sets the last line to whatever makes `Remaining` zero.
- Applying replaces the form's `To` row value with `2 categories` (the count), keeping the row's styling. Tapping it reopens the split sheet.
- Changing the transaction's **amount** after a split re-opens the question: keep the lines and show a non-zero `Remaining` in red, blocking save until the user fixes it. **Do not silently rescale the lines** — the user's numbers are theirs.
- Removing the split (deleting lines down to one, or a `Remove split` action) returns the `To` row to a single category picker.

### How a split is stored

**Write each line as its own transaction, and link them with a shared `splitGroupId`.**

- Every line becomes a normal transaction: same account, same date, same note, same tag, its own category and amount.
- All lines carry the same `splitGroupId`; a non-split transaction's is null.
- **Nothing else in the app needs to change.** Category screens, the Ledger, day-group totals, running balances, the Same-transactions screen, and every export keep treating them as ordinary transactions, because they are.
- **Deleting one line offers to delete the whole group**, with a confirmation naming how many transactions will go. Deleting a single line is allowed; the remaining lines stay linked.
- Editing one line's amount does **not** rebalance the others. The group is a record of how the payment was divided, not a live constraint.

> Two consequences to accept, not to fix: a split into three categories makes the Ledger show three rows for that day, which can push the day past the three-transaction threshold and reveal a day total; and a split appears as several rows rather than one. Both are correct — the money really did go to several categories.

**Report whether the transaction model can carry `splitGroupId` without a migration**, and what you did if it could not.

---

## 3 · Remove the bottom bar

Delete the pinned full-width bar that reads `Enter an amount` / `Choose an account`. The nav bar's `Save` becomes the only way to save.

That bar was doing two jobs: saving, and telling the user what was missing. Removing it drops the second job, so it has to be replaced.

- **`Save` stays visually enabled**, at full opacity, whether or not the form is valid. A greyed-out button that does nothing when tapped explains nothing.
- **Tapping `Save` on an incomplete form does not save.** Two things happen together:
  1. **A brief message names what is missing** — `Enter an amount`, `Choose an account`, `Choose a category` — using the app's existing snackbar or toast component. **Do not build a new one and do not invent new colours.** The wording is deliberately the same as the removed bar's: that message was useful, it just did not deserve permanent space.
  2. **The corresponding field flashes**: its value text goes `#FF453A` and the row's background pulses once over ~200 ms, twice. Nothing moves or resizes.
- **One message at a time.** If several fields are missing, name the **first one in form order** — amount, then `From`, then `To`. A list of three problems is harder to act on than one.
- Once the user fills the flagged field, its flag clears immediately. Tapping `Save` again names the next missing one.
- No dialog, and no permanent inline error text under the rows. The message is transient; the flash is the pointer to where.
- The vertical space the bar occupied is simply gone; nothing takes its place and nothing else moves up beyond the layout closing naturally.

---

## 4 · Accessibility

- Both buttons announce their state: `Repeat, off` / `Repeat, every month`; `Split, off` / `Split, 2 categories`. A disabled `Split` announces why: `Split, unavailable until an amount is entered`.
- Sheet rows are single-select options announcing selected state.
- `Remaining` is a live region: as lines change, screen-reader users hear the new figure.
- `Apply split` announces why it is unavailable while `Remaining` is non-zero.
- The validation message is announced as a live region, which is what carries the meaning for a screen reader — the colour pulse conveys nothing on its own. Focus moves to the flagged field so the user lands where the fix is.
- Every tap target, including the remove glyph on a split line, is at least 44 pt.

---

## 5 · Edge cases

| Case | Required behavior |
|---|---|
| Amount empty | `Split` disabled at 35% opacity, non-interactive, with a semantics reason. |
| Amount changed after applying a split | Lines kept; `Remaining` goes red; saving is blocked until it is zero. |
| Split down to one line | Treated as not a split; `Apply split` disabled. |
| Same category chosen on two lines | Allowed — merge them or leave them, but **report which you chose**. Do not block it silently. |
| `Split evenly` across 3 lines of `$100` | `33.34 / 33.33 / 33.33`, the extra cent on the first line; the sum is exactly `$100`. |
| Repeat set, then the transaction's date changed | The summary and the rule's start date follow the new date. |
| Repeat set on a transaction that is then deleted | The rule is deleted with it; confirm this matches Planner's existing behavior and **report it**. |
| Repeat + Split together | Allowed. The rule regenerates the whole split group each occurrence. **If Planner cannot represent a multi-transaction occurrence, block the combination with a clear message and report it.** |
| Editing an existing split transaction | Opens the sheet with the whole group loaded. |
| Deleting one line of a saved split | Offer to delete the group; allow deleting just the one. |
| Save tapped on a valid form | Saves as today. |
| Device text scaling at max | Sheets scroll; rows grow; `Remaining` stays on one line. |

---

## 6 · Acceptance criteria

**Repeat**

- [ ] The `Repeat` button opens the sheet; its label shows the chosen frequency when set.
- [ ] The sheet uses Planner's existing recurrence model — no second rule engine exists in the diff.
- [ ] `ENDS` appears only when a frequency other than `Never` is chosen.
- [ ] The summary names the day, the frequency, the start date, and says the repeat is managed in Planner.
- [ ] The day and start date come from the transaction's `Date` row and follow it when changed.
- [ ] Saving creates one transaction now plus a Planner rule; no future transactions are written up front.
- [ ] Setting `Never` removes the rule and leaves the transaction intact.

**Split**

- [ ] `Split` is disabled and 35% opaque until an amount is entered.
- [ ] `Apply split` is disabled until `Remaining` is exactly zero and there are at least two lines.
- [ ] `Remaining` is green at zero and red otherwise.
- [ ] `Split evenly` on `$100` across three lines yields `33.34 / 33.33 / 33.33`.
- [ ] `Rest to last` zeroes `Remaining` in one tap.
- [ ] Applying makes the `To` row read `2 categories`; tapping it reopens the sheet.
- [ ] Changing the amount afterwards turns `Remaining` red and blocks saving; the lines are not rescaled.
- [ ] Saving writes one transaction per line, all sharing a `splitGroupId`, each with the same account, date, note, and tag.
- [ ] The Ledger, category screens, day totals, running balances, and the Same-transactions screen need no changes to display them.
- [ ] Deleting one line offers to delete the group and names the count.

**Bottom bar**

- [ ] The `Enter an amount` / `Choose an account` bar no longer exists.
- [ ] `Save` renders at full opacity regardless of validity.
- [ ] Tapping `Save` on an incomplete form shows a brief message naming the first missing field, flashes that field twice over ~200 ms, and does not save.
- [ ] The message uses the app's existing snackbar or toast — no new component, no new colours in the diff.
- [ ] With amount, `From`, and `To` all empty, the message names the amount; filling it and tapping again names `From`.
- [ ] Nothing moves or resizes during the flash, and no dialog appears.
- [ ] Filling a flagged field clears its flag immediately.

**General**

- [ ] `git diff` contains no change to the nav bar, `Amount` field, `REQUIRED` / `OPTIONAL` cards, or the two buttons' geometry.
- [ ] Planner is byte-identical apart from rules created through this screen.
- [ ] No analyzer warnings.

**Tests to write:**

- unit test: `Split evenly` distributes remainders so the lines sum exactly to the total, for `$100 / 3` and `$0.05 / 3`;
- unit test: `Apply split` is blocked at one line, at a non-zero remainder, and at a zero-amount line;
- unit test: saving a two-line split writes two transactions sharing one `splitGroupId` with identical account, date, note, and tag;
- unit test: changing the amount after applying leaves the lines untouched and the remainder non-zero;
- widget test: `Split` is non-interactive with an empty amount;
- widget test: tapping `Save` on an incomplete form does not pop the route, shows a message naming the amount, and marks that field; after filling the amount, tapping again names `From`;
- widget test: setting a repeat creates exactly one transaction and one Planner rule;
- widget test: clearing a repeat removes the rule and leaves the transaction.

---

## 7 · Non-goals

- A second recurrence engine, or any change to Planner's model or UI
- Splitting a bill between people, shares, participants, or receivables
- Rescaling split lines automatically when the total changes
- Percentage-based splits
- Templates or saved split presets
- Restoring the bottom bar in any form
- Permanent inline error text under the rows, or a dialog for validation
- Naming every missing field at once
- Any redesign of the transaction form's existing rows

---

## Deliverable

List the files you created and modified. Report: where Planner's recurrence model and editor live and how you reused them; whether Planner can represent a repeat whose occurrence is a multi-transaction split, and what you did if not; whether the transaction model could carry `splitGroupId` without a migration; what you chose when the same category appears on two split lines; how Planner generates future occurrences; and what happens to a rule when its originating transaction is deleted. Flag any deviation from this spec and why.
