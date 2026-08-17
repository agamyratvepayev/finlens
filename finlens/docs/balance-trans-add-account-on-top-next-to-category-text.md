# Balance — Trans Add Account on Top Next to Category Text

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. When adding or editing a transaction, tapping the `From` or `To` field opens an **account picker** bottom sheet: a grabber, a `Pay from` title, a `Search accounts` field, then accounts grouped by category (`SPENDABLE`, `RECEIVABLES`, `INVESTMENTS`, `VALUABLES`, `CREDIT CARDS`, `PAYABLES`, `BANK LOANS`), each row showing an icon tile, the account name, and its balance.

This task covers two connected changes.

**First**, a `+ New account` row currently sits at the **very bottom of the picker's list**, after every account in every category. That is the worst possible place for it: the moment a user needs it is the moment the account they want is not in the list, and to reach it they must scroll past all fourteen accounts that are not what they want. **Move it into the sheet's header row.**

**Second**, the **New account sheet** it opens already exists but is incomplete. Today it has: an account name field, a wrapping grid of seven group chips, a `Currency` row, a `Starting balance` row, a hint line, and a `Create & select` button. It has no icon selection, no fields specific to cards or loans, and it asks for a "starting balance" identically whether the account is an asset or a debt. **Complete it to the design in §5.**

**Before implementing §5, identify what is currently broken or missing in that sheet and report it.** Fix the existing sheet — do not delete it and write a new one.

**Match the project's existing conventions.** Use the widgets, models, repository, and design tokens already there. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

Do **not**:

- change the picker sheet's background, corner radius, grabber, or height behavior;
- change the picker's search field, section headers, account rows, icon tiles, balances, or ordering;
- change how balances are signed in the picker — liability accounts keep showing `−$3,812` exactly as they do today;
- change the transaction form behind the sheet;
- touch the Balance tab, the Ledger, the Planner, or the Insight tabs;
- introduce a new design-token system or a second sheet component.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · Move the create action into the header

**Remove** the `+ New account` row from the bottom of the picker's list entirely. It must not exist in two places.

**Add** a trailing action to the picker's header row:

- The header becomes a `Row`: title on the left, action on the right, padding `12 18 10`.
- The title (`Pay from`, or whatever the sheet's current title is) keeps its existing size, weight, and color.
- The action reads **`+ New account`** — a `+` glyph at 14 pt then the label at 14.5 pt, both `#5E5CE6`, 4 pt apart.
- A text button, not a filled one. It must not compete with the title.
- **Tap target at least 44 pt tall**, extending above and below the visible text.

The header must stay fixed while the account list scrolls, as the search field does today. Verify that it does; if the whole sheet content currently scrolls as one, pin the header and search field together and **report that you changed it**.

---

## 2 · After creating an account

The user opened the picker to pick an account. Creating one is a detour, not a destination.

- On success, **the new account is selected and the picker closes**, returning to the transaction form with that account filled in. The user does not have to find it in the list and tap it again. This is why the button reads `Create & select`.
- On cancel, return to the picker with its previous scroll position and search query intact.
- The New account sheet opens **over** the picker; do not dismiss the picker on the way there.

---

## 3 · Interaction with the picker's search

- The header action stays visible and enabled while a search query is active. **This is when it matters most** — a user searching for an account that does not exist is exactly the user who needs to create one.
- Do not prefill the new account's name with the search query. **Report whether the sheet makes that easy**, so it can be considered separately.
- When a search returns no results, the empty state may say `No accounts match "…"`, but do **not** add a second create button there. One action, always in the same place.

---

## 4 · Sibling pickers

The app has sibling pickers built from the same sheet pattern — category, tag, and the `To` account picker among them.

- If any also carries a create action at the bottom of its list, **move it to the header the same way**, so "create a new one" lives in a learnable place rather than a per-screen one.
- If a picker has no create action today, **do not add one**. This task moves an existing affordance; it does not introduce new ones.
- **List every picker you touched and every one you left alone, with the reason.**

---

## 5 · The New account sheet

Bottom sheet, `#1C1C1E`, presented over the picker, scrollable body, max height 86% of screen.

### 5.1 Order, top to bottom

1. Grabber — 34 × 4 pt, `#48484A`, centered.
2. Title `New account` — 17 pt, weight 650, white, padding `0 14 12`.
3. **Account name** field.
4. **Group** selection — `ASSETS` list, then `LIABILITIES` list.
5. **Details card** — currency, balance, and any group-specific fields.
6. **Hint line**.
7. **Icon** row.
8. **`Create & select`** button.

### 5.2 Account name

`#2C2C2E`, radius 11, margin `0 14 14`, padding `7 11`. Caps label `ACCOUNT NAME` (10 pt, weight 650, letter-spacing 0.05em, `#8E8E93`) above the field (14.5 pt, white; placeholder `e.g. Main Checking` in `#636366`).

### 5.3 Group selection — two labelled lists, not a chip grid

Replace the current wrapping chip grid. Chips wrapped raggedly and, more importantly, said nothing about the one thing that matters most at this moment: **whether this account adds to net worth or subtracts from it.**

Two sections, each a caps label (10.5 pt, weight 650, letter-spacing 0.07em, `#636366`, padding `0 16 5`) above a `#2C2C2E` card, radius 9, margin `0 14`:

```
ASSETS
  ● Spendable
  ● Receivables
  ● Investments
  ● Valuables

LIABILITIES
  ● Credit Cards
  ● Payables
  ● Bank Loans
```

- Rows: padding `7 11`, separated by 1 pt `rgba(255,255,255,0.06)`.
- A **7 pt dot** in the group's own color, 8 pt before the label.
- Label 13.5 pt `#EBEBF5`.
- **Selected row**: background `rgba(94,92,230,0.16)`, label white weight 600, and a trailing `✓` in `#A5A3FF`.
- **Single select.** Selecting in one section clears the other.
- Nothing is selected initially; `Create & select` stays disabled until something is.

Take the group names, order, and colors from the app's existing account-category definitions. Do not hardcode this list — if a group is added or renamed elsewhere, this sheet must follow. **Report where that definition lives.**

### 5.4 The group drives the rest of the form

Changing the group rebuilds everything below it. Animate appearing and disappearing rows over ~180 ms; do not let the sheet jump.

**Details card** — `#2C2C2E`, radius 11, margin `0 14`, rows padding `9 12` separated by 1 pt `rgba(255,255,255,0.07)`. Each row: label 14.5 pt white on the left, value 14.5 pt weight 600 right-aligned.

| Row | When | Notes |
|---|---|---|
| `Currency` | always | Defaults to the app's base currency. Opens the existing currency picker; trailing `#636366` chevron. |
| `Starting balance` | asset groups | Right-aligned amount with its currency symbol attached — `$0`, not `0` with a `$` at the far edge. |
| `Amount owed` | liability groups | Same row, relabelled. **Value renders in `#FF453A`.** |
| `Credit limit` | Credit Cards only | Optional. Must be greater than 0 if entered. |
| `Interest rate` | Bank Loans only | Optional. `0`–`100`, up to two decimals, suffixed `%`. |
| `Payment day` | Bank Loans only | Optional. `1`–`31`. |

**Sign handling — get this right.** For a liability, the user types **what they owe as a positive number** and it is **stored negative**, which is why the picker shows `−$15,000`. Never ask the user to type a minus sign, and never store their positive entry as positive.

**Hint line** — 11 pt `#636366`, padding `7 18 0`, line-height 1.45:

- assets → `Enter this once. From now on the balance is calculated from your transactions.`
- liabilities → `Enter what you owe as a positive number — it counts against your net worth.`

**Values survive a group change within the session.** If the user types a credit limit, switches to Bank Loans, then switches back, the limit is still there. On save, **only the fields belonging to the final group are persisted**; the rest are discarded.

### 5.5 Icon — inline row

Caps label `ICON` (10.5 pt, weight 650, letter-spacing 0.07em, `#636366`, padding `14 16 6`), then a row with padding `0 14 14`, 7 pt gaps:

- **Six suggestion tiles**, 36 × 36 pt, radius 10, showing the icons most likely for the selected group (a bank, cash, a wallet, people for Spendable; a building, a car, a school, a briefcase for Bank Loans).
- **The selected tile is filled with the group's color and carries a 2 pt white ring.** Unselected tiles use a dark tint of the group's color with the glyph in the group's color.
- **The last item, pushed to the right end, is a grid button** — 36 pt, radius 10, `#3A3A3C`, a grid glyph in `#A5A3FF` — which opens the full picker (§5.6).

**A default icon is selected the instant a group is chosen**, so the field is never empty and a user who ignores this row still gets a sensible account. Changing the group **keeps the chosen glyph and recolors it**; it only replaces the glyph if the current one is not in the new group's set.

**The user picks a glyph, never a color.** Color comes from the group. Do not add a color picker.

### 5.6 Icon — full picker

A bottom sheet over the New account sheet: `#161618`, top radius 20, 34 × 4 pt `#48484A` grabber.

- Header row: title `Choose icon` (16 pt, weight 650, white) left, `Done` (`#5E5CE6`, 14 pt) right.
- **Search field** — `#2C2C2E`, radius 10, margin `0 14 10`, padding `7 10`, leading magnifier `#636366`, placeholder `Search icons`.
- **Grouped grid** — caps section labels (10.5 pt, weight 650, letter-spacing 0.07em, `#8E8E93`, padding `2 16 6`), tiles 42 × 42 pt, radius 11, 7 pt gaps, padding `0 14`.
- Roughly **100 icons across about 12 groups**: `Banking & cash`, `Cards`, `Work & income`, `Home & bills`, `Transport`, `Food & shopping`, `Health`, `Education`, `Travel & leisure`, `Investments & savings`, `Property & valuables`, `Other`. Use the icon set the app already ships; do not add a second icon package.
- **Every tile renders in the selected group's color** — the whole grid is green for Spendable, red for Bank Loans. The selected tile is filled with a 2 pt white ring.
- Tapping a tile selects it and closes the sheet.

**Search matters more than the grid.** A hundred icons is too many to scroll. Every icon carries a set of search keywords, and **those keywords must be localized**: a user in Turkish typing `araba` must find the car icon. Putting only English keywords in makes search work for some users and not others. **Report how you stored the keywords and which locales you covered.**

### 5.7 Icon — the user's own image

At the top of the picker, before the icon groups, a `YOUR OWN` section:

- An **upload tile** — 42 pt, radius 11, `#2C2C2E`, 1.5 pt dashed `#5E5CE6` border, a photo-plus glyph in `#A5A3FF`. Tapping it opens the photo library.
- Once an image is chosen, it appears as a tile in that section beside the upload tile and can be reselected later.

Rules:

- **Square crop.** After picking, show a square crop step. A portrait photo squeezed into a rounded square is not acceptable.
- **Downscale to 256 × 256** and store the result in the app's own documents directory. **Do not reference the gallery path** — the user deleting the photo would break the icon.
- **The category color survives as a 2 pt ring** around the image wherever the tile renders. The image fills the tile, so the coloured background is gone; without the ring the account's group becomes unreadable in the list.
- **If the file is missing** — a backup restored on another device, a cleared cache — fall back silently to the group's default glyph. Never render a broken image.
- **Delete the file when the account is deleted**, or stale images accumulate forever.
- **Backups and sync must carry these images.** If the app's backup format cannot include binary attachments, say so and fall back gracefully. **Report what you found.**
- **Handle permission denial explicitly**: a clear message and a link to system settings. Silence on a denied permission looks like a broken button.

Accept a known cost: a photograph among flat monochrome glyphs reads busier and brighter. That is the user's deliberate choice and is acceptable.

### 5.8 Create & select

Full-width button, margin `0 14`, 45 pt tall, radius 13, `#5E5CE6`, white 15.5 pt weight 650.

**Disabled at 35% opacity until the form is valid.** Valid means: a non-empty trimmed name, and a group selected. Everything else is optional.

Validation:

| Field | Rule | On failure |
|---|---|---|
| Name | Non-empty after trim; **unique across all accounts, case-insensitively** | Inline message under the field in `#FF453A`: `An account with this name already exists`. Keep the button disabled. |
| Balance / Amount owed | Optional; empty means 0 | — |
| Credit limit | If entered, greater than 0 | Field border `#FF453A`; button disabled. |
| Interest rate | If entered, 0–100, max two decimals | Same. |
| Payment day | If entered, 1–31 | Same, plus a hint: `Months shorter than this use their last day.` |

Amount fields use a numeric keyboard and reject non-numeric input at the keystroke.

---

## 6 · Accessibility

- The picker's header action is a `Semantics` button labelled `New account`, positioned in the reading order **after the title and before the search field**.
- Group rows are single-select options announcing their selected state and their section (`Bank Loans, liabilities, selected`).
- The section labels `ASSETS` and `LIABILITIES` are headers.
- The `Amount owed` field's label and the hint line must both be reachable, so a screen-reader user learns the sign convention.
- Icon tiles are buttons labelled with the icon's name; the selected one announces its state.
- The upload tile is labelled `Choose a photo`.
- Validation errors are announced when they appear.
- Every tap target — group rows, icon tiles, the header action — is at least 44 pt in its smaller dimension, extending the hit area invisibly where the visual is smaller.

---

## 7 · Edge cases

| Case | Required behavior |
|---|---|
| No accounts exist at all | The picker's list is empty; the header action still renders and is the way forward. |
| Long picker title in another language | Title ellipsizes; the action never wraps, shrinks, or gets pushed off. |
| Picker search active with zero results | Header action visible and enabled. |
| New-account sheet cancelled | Return to the picker unchanged, query and scroll intact. |
| Group changed after entering group-specific values | Values kept in memory for the session; only the final group's fields are saved. |
| Account created with a type invalid for the field that opened the picker | Select it only if valid; otherwise return to the picker with the list refreshed and the new account visible. **Report whether such a restriction exists.** |
| Duplicate name entered | Inline error, button stays disabled. |
| Currency differs from the base currency | Accepted; the account stores its own currency, as existing accounts do. |
| Photo permission denied | Clear message plus a settings link; the rest of the picker keeps working. |
| Chosen photo is enormous | Downscaled before storage; the sheet must not freeze while processing. |
| Custom image file missing at render time | Group's default glyph, silently. |
| Device text scaling at max | The sheet scrolls; rows grow; nothing clips or overlaps. |
| RTL locale | The header action moves to the left of the title; group rows mirror; the check moves to the leading edge. |

---

## 8 · Acceptance criteria

**The move**

- [ ] `+ New account` no longer appears at the bottom of the account list.
- [ ] It appears once, on the right of the picker's header row, in `#5E5CE6`.
- [ ] It is visible without scrolling the instant the picker opens, and stays put while the list scrolls.
- [ ] Its tap target measures at least 44 pt tall.
- [ ] It stays visible and enabled while a search is active and while a search returns zero results.
- [ ] No second create button exists anywhere in the picker, including in its empty state.
- [ ] Sibling pickers with a bottom create row got the same treatment; every picker touched or skipped is listed in the report.

**The sheet**

- [ ] Groups render as two labelled lists — `ASSETS` and `LIABILITIES` — not as a wrapping chip grid.
- [ ] The group list is built from the app's existing category definitions, not a hardcoded list.
- [ ] Selecting a group shows a `✓` and a tinted row; selecting in the other section clears the first.
- [ ] Choosing a liability group relabels `Starting balance` to `Amount owed`, renders its value in `#FF453A`, and swaps the hint line.
- [ ] A positive `Amount owed` of `15000` produces an account the picker displays as `−$15,000`.
- [ ] `Credit limit` appears only for Credit Cards; `Interest rate` and `Payment day` appear only for Bank Loans.
- [ ] Switching group and back preserves what was typed; saving persists only the final group's fields.
- [ ] The balance value renders with its currency symbol attached and right-aligned.
- [ ] A default icon is selected as soon as a group is chosen.
- [ ] Six suggestions plus a grid button render on the icon row; the grid button opens the full picker.
- [ ] The full picker shows about 100 icons in about 12 labelled groups, all rendered in the selected group's color.
- [ ] Searching the icon picker in Turkish finds the expected icons.
- [ ] A user-supplied photo can be chosen, is square-cropped, is stored at 256 × 256 in app storage, and renders with a 2 pt group-colour ring.
- [ ] A missing custom image falls back to the group's default glyph with no broken-image state.
- [ ] Deleting an account removes its custom image file.
- [ ] Denying photo permission shows a message and a settings link.
- [ ] `Create & select` is disabled until a name and a group are set.
- [ ] A duplicate name shows an inline error and keeps the button disabled.
- [ ] `Create & select` creates the account, selects it, closes both sheets, and leaves the transaction form showing it.
- [ ] `git diff` contains no change to the picker's background, radius, search field, section headers, account rows, or balance formatting.
- [ ] No analyzer warnings.

**Tests to write:**

- widget test: the picker's list contains no create row and its header contains exactly one;
- widget test: the header action is hit-testable without scrolling on a 320 × 568 viewport;
- widget test: with a picker search returning zero results, the action is present and enabled;
- widget test: selecting `Bank Loans` renames the balance row to `Amount owed` and reveals `Interest rate` and `Payment day`;
- unit test: a liability created with `15000` is stored as `−15000`;
- unit test: name validation rejects duplicates case-insensitively and accepts a name differing only by surrounding whitespace after trimming;
- unit test: switching group and back preserves in-session values, and saving persists only the final group's fields;
- unit test: icon keyword search returns the car icon for both `car` and `araba`;
- widget test: a missing custom image renders the group's default glyph;
- widget test: completing the flow closes both sheets and reports the new account as the transaction's selection;
- widget test: cancelling leaves the picker open with its query intact.

---

## 9 · Non-goals

- Redesigning the account picker beyond moving one action into its header
- Adding a create action to pickers that do not have one today
- Prefilling the new account's name from the picker's search query
- A colour picker — colour comes from the group
- A second icon package or a second sheet component
- Editing an existing account from this sheet
- Any redesign of the transaction form or the Balance tab

---

## Deliverable

List the files you created and modified. Report: what was incomplete or broken in the existing New account sheet before you touched it; whether the picker's header and search field were already pinned; every sibling picker you changed and every one you left alone; where the account-group definitions live; how icon search keywords are stored and which locales you covered; whether the app's backup format can carry custom images; whether any transaction field restricts which account types are valid; and whether the sheet can be prefilled from the picker's search query. Flag any deviation from this spec and why.
