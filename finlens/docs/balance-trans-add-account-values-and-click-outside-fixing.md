# Balance — Trans Add Account Values & Click Outside Fixing

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. On the add/edit transaction screen, tapping the `From` / `To` field opens an **account picker** bottom sheet, and tapping the category field opens an **expense category picker** bottom sheet. Both share the same sheet pattern: a grabber, a title, a search field, then a scrollable body.

Three problems, all on these picker sheets.

1. **Tapping outside does not always dismiss.** When a sheet sits at its default height, tapping the area above it closes it. When the sheet has been dragged up to its full height, tapping that same area does nothing.
2. **The expense category rows carry two amounts each** — `$650 / $1,000`, spent against budget, with over-budget rows in red. These do not belong in a picker.
3. **The expense categories are a vertical list**, showing five or six at a time. They should be a grid.

**Match the project's existing conventions.** Use the sheet, widgets, and design tokens already there. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

Do **not**:

- change the sheet's background, corner radius, grabber, scrim color, or entry animation;
- change the search field's position, styling, or behavior on either picker;
- change the **account** picker's rows, its grouping by category, its balances, or its ordering — §2 and §3 apply to the **category** picker only;
- change the transaction form behind the sheets;
- change budget data, budget calculations, or anything on the Planner tab;
- touch the Balance, Ledger, or Insight tabs.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · Dismiss on tap outside, at every height

### The bug

At full expansion the sheet's own widget fills the screen, with the area above the visible body rendered transparent. Taps land on that transparent region, are absorbed by the sheet, and never reach the modal barrier — so nothing happens. At the default height the region above genuinely is the barrier, which is why it works there.

**Confirm this is the cause before fixing it, and report what you actually found.**

### Required behavior

- **Tapping anywhere above the sheet's visible top edge dismisses it, at any expansion state.** No exceptions and no dependence on how far the sheet has been dragged.
- The transparent area above the sheet body must **not** be hit-testable by the sheet. Either size the sheet's container to its visible content, or set the transparent region's hit-test behavior so taps fall through to the barrier. Do not fix this by stacking an extra full-screen `GestureDetector` over the barrier — that hides the real problem and tends to break the drag gesture.
- **Dragging down dismisses immediately**, from any height. A fully expanded sheet does not first collapse to its default height — one downward drag closes it.
- Dragging up still expands, as today.

### A sheet must never make its own dismiss area untappable

Cap the sheet's maximum height so that **at least 44 pt of barrier always remains above it.** In the current build a fully expanded sheet leaves a strip too thin to hit reliably, so even a correct hit-test would be a poor target. This cap applies to both pickers and to any sibling sheet built from the same component.

**Report the maximum height you set and whether it was previously unbounded.**

---

## 2 · Remove the amounts from the category picker

Every category row currently shows `spent / budget` — `$650 / $1,000`, `$1,140 / $1,200`, and `$440 / $400` in red when over.

**Remove them entirely.** No amount, no progress bar, no coloured dot standing in for budget state, no "over budget" marker.

This is a picker. Its job is to answer *which category is this?* — a question the numbers do not help with, and the grid in §3 has no room for them. Budget progress lives on the Planner tab.

**Do not delete or change the underlying budget data or its calculations.** This removes a display, nothing more. **Report which query or view-model field became unused**, so it can be cleaned up separately if it now costs work for nothing.

---

## 3 · The category picker becomes a grid

### Layout

Replace the vertical list with a **3-column grid**, padding `0 14`, column gap 8 pt, row gap 10 pt.

Each cell is a column, centred:

- **Icon tile** — 46 × 46 pt, radius 13. Unselected: a dark tint of the category's colour as the background with the glyph in the category's colour. Selected: the category's full colour as the background, the glyph in white, and a **2 pt white ring**.
- **Label** — 12 pt, centred, line-height 1.25, `#EBEBF5`; the selected one goes white at weight 600. **Up to two lines, then ellipsis.** Names like `Transportation` and `Subscriptions` must not truncate on one line — that is why the grid is three columns and not four.
- 6 pt between tile and label.

Tapping a cell selects the category and closes the sheet, as tapping a row does today.

### The search field stays

Unchanged in position and styling. Filtering narrows the grid, which reflows to fewer rows. When a search matches nothing, show the app's existing empty state.

### A `New` cell closes the grid

The last cell is a **create action**: a 46 pt tile, radius 13, `#2C2C2E`, 1.5 pt dashed `#5E5CE6` border, a `+` glyph in `#A5A3FF`, labelled `New` in `#A5A3FF`.

It sits at the **end of the grid**, not in the header. Categories are a bounded set that fits on roughly one screen, so the end of the grid is reachable — unlike the account list, where the same action had to move to the header. **Do not move it to the header here.**

Tapping it opens the app's existing new-category flow. On success the new category is **selected and the sheet closes**, matching how the account picker behaves. On cancel, return to the grid with the search query intact.

If no create flow exists today, **omit this cell and report that** — do not build one.

---

## 4 · Accessibility

- Each grid cell is a `Semantics` button labelled with the category name, announcing its selected state.
- Grid traversal order is left to right, then down.
- Each cell's tap target covers the tile **and** its label, and is at least 44 pt in both dimensions.
- The barrier above the sheet is not announced as an interactive element, but the sheet itself must remain dismissible by the screen reader's standard dismiss gesture at every height.
- The `New` cell is labelled `New category`.

---

## 5 · Edge cases

| Case | Required behavior |
|---|---|
| Sheet dragged to full height, then tapped above | Dismisses. |
| Sheet at default height, then tapped above | Dismisses, as today. |
| Sheet dragged half-way and released | Settles to the nearest snap point, then obeys both rules above. |
| Downward drag from full height | Dismisses in one gesture. |
| Keyboard open from the search field, then tap outside | Dismiss the keyboard **and** the sheet; do not require two taps. |
| Category count not divisible by three | The last row is left-aligned with empty cells after it — do not stretch the remaining cells to fill the row. |
| Very long category name | Wraps to two lines, then ellipsizes. The tile never shrinks to make room. |
| Only one category exists | Grid renders one cell plus the `New` cell. |
| Search matches nothing | Existing empty state; the `New` cell stays visible so the user can create what they were looking for. |
| Device text scaling at max | Labels grow and may take two lines; tiles stay 46 pt; rows grow taller. Do not reduce to two columns. |
| RTL locale | Grid fills right to left; the `New` cell stays last in reading order. |

---

## 6 · Acceptance criteria

**Dismiss**

- [ ] Tapping above the sheet dismisses it at the default height **and** at full height.
- [ ] A single downward drag dismisses from any height, with no intermediate collapse.
- [ ] At least 44 pt of barrier remains above the sheet at its maximum height.
- [ ] Tapping outside while the search keyboard is open closes both in one gesture.
- [ ] The fix is in hit-testing or sizing, not an extra full-screen gesture layer over the barrier.
- [ ] Dragging up still expands the sheet as before.
- [ ] The same behavior holds for the account picker and every sibling sheet using this component.

**Amounts**

- [ ] No category row or cell shows a spent, budget, or `spent / budget` figure anywhere in the picker.
- [ ] No red over-budget styling remains in the picker.
- [ ] Budget data and its calculations are untouched; the Planner tab is byte-identical.
- [ ] Any now-unused query or view-model field is named in the report.

**Grid**

- [ ] Categories render in a 3-column grid with 46 pt tiles and centred labels.
- [ ] `Transportation` and `Subscriptions` render in full across two lines without truncating.
- [ ] The selected category's tile is filled with its colour, has a white glyph and a 2 pt white ring, and its label is white at weight 600.
- [ ] Tapping a cell selects the category and closes the sheet.
- [ ] Roughly twice as many categories are visible without scrolling as before — measure it.
- [ ] The search field is unchanged and filtering reflows the grid.
- [ ] A `New` cell sits at the end of the grid, not in the header, and is omitted if no create flow exists.
- [ ] Creating a category selects it and closes the sheet.
- [ ] The last partial row is left-aligned, with no stretched cells.
- [ ] `git diff` contains no change to the account picker's rows, grouping, balances, or ordering.
- [ ] No analyzer warnings.

**Tests to write:**

- widget test: a tap above the sheet pops the route when the sheet is at its maximum extent;
- widget test: a tap above the sheet pops the route at the default extent;
- widget test: a downward fling from full extent pops the route in one gesture;
- widget test: the sheet's maximum height leaves at least 44 pt of barrier;
- widget test: no widget in the category picker renders a currency string;
- widget test: the grid lays out three columns and a 13-category set produces five rows with the last row left-aligned;
- widget test: selecting a cell returns that category and pops the sheet;
- widget test: a search returning nothing still renders the `New` cell.

---

## 7 · Non-goals

- Changing the account picker's rows, grouping, balances, or ordering
- Moving the category create action into the sheet header
- Showing budget progress anywhere in a picker
- Changing budget data, budget logic, or the Planner tab
- Adding sections, headers, or ordering rules to the category grid
- A four-column grid, or dropping to two columns at large text scales
- Any redesign of the transaction form

---

## Deliverable

List the files you created and modified. Report: the actual cause of the dismiss bug and how you fixed it; whether the sheet's maximum height was previously unbounded and what you set it to; every sibling sheet that shares the component and now inherits both fixes; which budget query or view-model field became unused; whether a new-category flow exists; and how many categories now fit without scrolling at 375 × 812. Flag any deviation from this spec and why.
