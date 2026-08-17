# Balance — Category & Account Trans Horizontal Height Design

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. Transaction rows render on the **category detail** and **account detail** screens reached from Balance, and on the **Ledger** tab.

A row today is about **70 pt tall**. Its left column always carries three lines of text — category name, description, account name — while its right column carries two: amount and running balance. The third line is laid out as if the right column sat beside it, so it is squeezed into the same narrow width as the two lines above, even though nothing is to its right.

Rows are too airy, and the squeezed third line truncates account names for no reason.

**Match the project's existing conventions.** Use the widgets and design tokens already there. Do not introduce a new design-token system. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

This changes **geometry and layout structure only.** Do **not**:

- change any **font size, weight, or color** — the category name stays 14.5, the description 11.5, the account 11.5, the amount 14.5, the balance 11.5, and every color stays as it is;
- change amount formatting, sign handling, or the green/red direction colors;
- change the tag chip's styling, size, or color;
- change the card background, the card's horizontal inset, or the 1 pt inter-row separator;
- change day-group headers, period chips, tool buttons, or the pinned action button;
- change what a tap, a left-swipe, or a held left-swipe on a row does;
- **add anything new to the row** — no glyphs, no badges, no indicators, no expandable sections;
- touch the Planner or Insight tabs, or any export, backup, or sync payload.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · Structure

The row becomes a vertical stack of a **top block** and an optional **meta line**, not a single `Row` with a three-line column.

```
Row  ── padding 9 / 12
├── Top block (Row)
│   ├── Icon tile  34 × 34, radius 9, glyph 17     ── gap 10
│   └── Column (expanded)
│       ├── Line 1 (Row):  title       | amount
│       └── Line 2 (Row):  description | balance
└── Meta line (Row)  ── indented 44 pt to align with the text column
        account  ·  tag chip
```

**The meta line spans the full row width.** Nothing sits to its right, because the right column only occupies the two lines above it. This is the point of the restructure: the account name stops competing for space it never needed to share.

The meta line's left edge aligns with the text column above it — indent = icon width + gap = **44 pt**. It is not indented to the icon's left edge.

---

## 2 · Lines render only when they carry content

A row is as tall as the information it holds. Never render an empty line, a placeholder, or filler text.

| Line | Rendered when |
|---|---|
| Line 1 — title + amount | Always. |
| Line 2 — description + balance | The transaction has a description. If it does not, **the balance moves up to line 1's right side** and line 2 is absent. |
| Meta line | It has at least one of: an account name that the screen does not already imply, a tag. |

**The account name is omitted where the screen already states it.** On the **account detail** screen every row belongs to that account, so printing it on each row repeats the header — drop it there. On the **category detail** screen and the **Ledger**, the account varies row to row, so it stays.

For a **transfer** row the title already names both accounts, so the meta line carries no account name — it renders only when the transfer has a tag, and is absent otherwise.

Resulting heights:

| Content | Height |
|---|---|
| Title + description + meta line | **~66 pt** |
| Title + description, no meta line | **~52 pt** |
| Title + meta line, no description | **~52 pt** |
| Title only | clamped to the **44 pt** minimum |

**Enforce a 44 pt minimum row height.** The row is both a tap target and a swipe target; a 36 pt row would fail both. Do not set a fixed height anywhere else — every other height comes from padding plus intrinsic content, so the row grows correctly at large text scales.

---

## 3 · Metrics

| Token | Before | After |
|---|---|---|
| Row vertical padding | 11 pt | **9 pt** |
| Row horizontal padding | 12 pt | 12 pt — unchanged |
| Icon tile | 36 × 36, radius 9 | **34 × 34, radius 9** |
| Icon glyph | 18 pt | **17 pt** |
| Gap: tile → text | 11 pt | **10 pt** |
| Title line-height | 1.3 | **1.22** |
| Description line-height | 1.35 | **1.2** |
| Meta line-height | 1.35 | **1.2** |
| Gap between lines | 2 pt | 2 pt — unchanged |
| Meta line indent | — | **44 pt** |

> **Do not tighten the line-heights further.** 1.2 on 11.5 pt text is the floor: below it, descenders on `ğ`, `ş`, `y`, `p` start clipping. **Verify with a Turkish locale string** before you consider the values settled. This is why the row lands at ~66 pt rather than ~60 — the extra few points buy descender clearance in every locale.

The icon tile keeps its proportions: radius ÷ side stays ≈ 0.26, and the glyph stays optically centred. Do not shrink the box and leave an 18 pt glyph crowding a 34 pt tile.

---

## 4 · The description line is the only free-text on the row

Line 2 carries whatever free text the transaction has — the description the user typed (`Bakery & fruit`, `Landing page project`, `Partial payment before statement`). It is shown when present and skipped when absent. That is the whole rule.

- It renders on **one line**, ellipsized. It never wraps, never expands, and never pushes the balance.
- If the data model also holds a separate longer note field, **it stays on the transaction detail screen and is not surfaced on the row at all** — no indicator, no glyph, no expandable section. **Report whether such a field exists.**

---

## 5 · Accessibility

- The row's semantics announce its parts in reading order — title, amount, description, balance, account, tag — and are not merged into one unlabelled string.
- Verify every row reports a height of at least 44 pt at default scale **and at 130% text scale**, where rows grow rather than clip.

---

## 6 · Edge cases

| Case | Required behavior |
|---|---|
| No description | Line 2 absent; the balance moves to line 1's right side. |
| No description and no meta line | Row clamps to 44 pt; the balance sits beside the amount. |
| Long description | Ellipsizes on one line. It never wraps and never pushes the balance. |
| Long account name on the meta line | Ellipsizes, but only after the tag chip has its space — the chip is fixed-size and laid out first. |
| Account name present, no tag | Meta line renders with the account alone. |
| Tag present, no account name (account screen, or a transfer) | Meta line renders with the chip alone, left-aligned at the 44 pt indent. |
| Transfer with no tag | No meta line at all. |
| Multiple tags, if the app supports them | They lay out in a row; the account name ellipsizes first to make room. |
| Turkish or other descender-heavy locale | No clipping at 1.2 line-height. Verify. |
| 130% text scale | Rows grow from intrinsic height; nothing clips or overlaps the amount column. |
| Very long title | Ellipsizes; the amount never shrinks or wraps. |

---

## 7 · Acceptance criteria

Fixture rows:

- `Groceries` / `Bakery & fruit` / `Cash (USD Wallet)` — `$120`, balance `$5,430`
- `Freelance` / `Landing page project` / `Main Checking` + tag `side` — `$900`, balance `$12,198`
- `Transportation` / *(no description)* / `Main Checking` — `$132`, balance `$11,298`
- `Main Checking → Main Credit Card` / `Partial payment before statement` / *(no tag)* — `$500`, balance `$11,430`

Checklist:

- [ ] A three-line row measures **~66 pt**; a row without a meta line measures **~52 pt**; no row is under **44 pt**.
- [ ] The meta line spans the full row width and its left edge aligns with the text column, 44 pt from the content's left edge.
- [ ] `Cash (USD Wallet)` no longer truncates where it used to.
- [ ] On the **account detail** screen no row prints the account name; on the **category detail** screen and the **Ledger** every row does.
- [ ] A transaction with no description renders two lines with the balance beside the amount — no empty line, no placeholder.
- [ ] The transfer fixture row renders **no meta line**.
- [ ] No font size, weight, or color differs from before, anywhere in the diff.
- [ ] The tag chip is byte-identical to before.
- [ ] Nothing new was added to the row — `git diff` introduces no glyph, badge, or indicator widget.
- [ ] Left-swipe, held-left-swipe, and row tap all behave exactly as before.
- [ ] Turkish descenders (`ğ`, `ş`, `y`, `p`) do not clip at any line, at default scale or 130%.
- [ ] No fixed row height anywhere except the 44 pt minimum.
- [ ] Scrolling a long list is as smooth as before.
- [ ] No analyzer warnings.

**Tests to write:**

- widget test: a row with description and meta line measures within tolerance of 66 pt; without a meta line, 52 pt; with neither, exactly 44 pt;
- widget test: on the account detail screen the account name is absent from rows; on the category screen it is present;
- widget test: with no description, the balance renders on the same line as the amount;
- widget test: a transfer without a tag renders no meta line;
- widget test: a long account name ellipsizes while the tag chip stays fully visible;
- golden or layout test at 130% text scale asserting no overflow.

---

## 8 · Non-goals

- Changing any font size, weight, or color
- Adding a note indicator, glyph, badge, or expandable section to the row
- Surfacing a separate note field on the row
- Wrapping the description to a second line
- A user-facing density setting
- Changing tap, swipe, or hold behavior on rows
- Applying these values outside the transaction rows on these screens
- Any further redesign of the screens involved

---

## Deliverable

List the files you created and modified. Report: the measured heights for each of the four fixture rows; whether the row height was fixed or intrinsic before this change; whether the transaction model holds a note field separate from the description; and the result of the Turkish descender check at 1.2 line-height. Flag any deviation from this spec and why.
