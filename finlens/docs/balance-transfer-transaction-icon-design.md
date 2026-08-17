# Balance — Category & Account Transfer Transaction Design

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. Transaction rows render on the **Ledger** tab, on the **category detail** and **account detail** screens reached from Balance, and in the Same-transactions list.

A transfer row currently renders its title as:

```
Transfer → Main Credit Card (A…
Partial payment before statement
```

The word `Transfer` occupies the front of the line, so the destination account name gets truncated and the **source account is never shown at all**. Meanwhile the row already carries a distinct transfer icon in its tile, which says "this is a transfer" without any words.

**Match the project's existing conventions.** Use the models, widgets, and design tokens already there. Do not introduce a new design-token system. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

This changes **the text of a transfer row's title line and nothing else.** Do **not**:

- change the transfer icon, its glyph, its tile size, or its tile color — the icon is what identifies a transfer and it stays exactly as it is;
- change amount color or sign handling (separate task);
- change row height, padding, type sizes, weights, colors, the running-balance column, or the subtitle's styling;
- change non-transfer rows in any way;
- change day-group headers, period chips, or any screen layout;
- touch the Planner or Insight tabs, or any export, backup, or sync payload.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · The rule

**A transfer row's title is `{Source account} → {Destination account}`.** The word `Transfer` is removed entirely.

- The same format applies **everywhere** a transfer row renders — Ledger, account detail, category detail, Same-transactions list, search results, and any widget or summary that shows transaction rows. There is no context-dependent short form.
- The arrow always points **source → destination**, regardless of whose screen you are on. On the destination account's screen the arrow therefore points toward that account: `Cash (EUR Wallet) → Main Checking`.
- Account names render at the row title's existing size, weight, and color. The **arrow renders in `#8E8E93`** so the two names stay dominant and the arrow reads as a connector rather than a word.
- The arrow is the character `→` (U+2192) inside the text, not an icon widget.

**The subtitle is unchanged**: it keeps showing the transfer's description (`Partial payment before statement`). It must not be repurposed to carry account names.

---

## 2 · Truncation

Two account names rarely fit. Build the title as a `Row` of **two `Flexible` texts with the arrow fixed between them**, each text `TextOverflow.ellipsis` and `maxLines: 1`.

This is the point of the change: both sides shrink together —

```
Main Check… → Main Credi…
```

— instead of one long string whose tail disappears, which is what hides the destination today. **Never let either side truncate to nothing.** Give each `Flexible` the same flex factor so a long name on one side does not consume the other's space.

The title stays on **one line**. Do not wrap to two.

---

## 3 · Accessibility

The icon and the arrow glyph convey nothing to a screen reader, and with the word `Transfer` gone the row would otherwise announce two account names and a symbol.

Every transfer row's semantics label must name the transaction type and both accounts in words:

```
'Transfer from Main Checking to Main Credit Card, 500 dollars'
```

Combine this with the direction wording required for amounts by the amount-formatting task; do not emit two competing labels for the same row.

**Right-to-left locales:** the arrow must point in the reading direction. Do not hard-code `→`; resolve it from the ambient `Directionality` (`→` in LTR, `←` in RTL) and let the `Row` mirror naturally. Verify with an RTL locale.

---

## 4 · Edge cases

| Case | Required behavior |
|---|---|
| Both account names long | Both ellipsize; the arrow stays visible and centered between them. |
| One name short, one long | The long one ellipsizes; the short one renders in full. Equal flex factors, no greedy side. |
| Transfer has no description | Subtitle is omitted and the row renders single-line, keeping its existing vertical padding and any minimum row height the app already enforces. **Do not** insert placeholder text and **do not** move the account names into the subtitle. |
| One side's account was deleted | Show whatever name the transaction stores for it; if nothing is stored, `Deleted account` in the row's normal title color. Never render an empty side or a bare arrow. |
| Cross-currency transfer | Title format is unchanged. Amount display follows whatever the app does today — out of scope here; **report it** if the two sides show different figures. |
| Source and destination are the same account | Should not exist. If the data contains one, render it as-is and **report it** — do not add validation. |
| Very large text scale | The title still occupies one line; both names ellipsize further. Nothing wraps or overlaps the amount. |

---

## 5 · Consistency with the Same-transactions screen

The Same-transactions screen already titles a transfer key `{From} → {To}` and labels its list `ALL MAIN CHECKING → CREDIT CARD`. **Use the same formatting helper for both** — one function that takes a transfer and returns its display title, called from the row widget and from that screen's header. Do not write the string twice.

---

## 6 · Acceptance criteria

Fixture: a transfer on `5 AUG`, `Main Checking → Main Credit Card (Amex)`, description `Partial payment before statement`, amount `$500`, running balance `$11,430`.

- [ ] No transfer row anywhere in the app renders the word `Transfer` in its title.
- [ ] The fixture row's title reads `Main Checking → Main Credit Card (Amex)`, ellipsizing both sides as needed.
- [ ] The source account is visible on the row — it was not shown at all before.
- [ ] The arrow renders in `#8E8E93`; the account names keep the title's existing size, weight, and color.
- [ ] The transfer icon and its tile are byte-identical to before.
- [ ] The subtitle still shows the description, unchanged.
- [ ] On the destination account's own screen, the title still reads source-first with the arrow pointing toward that account.
- [ ] A transfer with no description renders single-line with no placeholder text.
- [ ] Both names ellipsize when both are long; neither side collapses to zero width.
- [ ] The row's semantics label names the type and both accounts in words.
- [ ] In an RTL locale the arrow points in the reading direction.
- [ ] One helper produces the title for both the row widget and the Same-transactions header; `git grep` finds no second implementation.
- [ ] `git diff` contains no change to non-transfer rows, row heights, padding, colors, or the icon.
- [ ] No analyzer warnings.

**Tests to write:**

- unit test: the title helper returns `Main Checking → Main Credit Card` for a transfer, and contains no `Transfer` substring;
- unit test: a missing account name falls back to `Deleted account`;
- widget test: with both account names long, both `Text` widgets report ellipsized overflow and both are non-empty;
- widget test: a transfer with an empty description renders one line and no subtitle widget;
- widget test: the row's semantics label contains `Transfer from` and both account names;
- widget test: rendered under an RTL `Directionality`, the arrow resolves to `←`.

---

## 7 · Non-goals

- Changing the transfer icon or introducing a transfer-specific tile color
- Changing amount color, sign, or currency handling
- A context-dependent short form that hides the account you are already looking at
- Wrapping the title to two lines
- Adding a `Transfer` badge, chip, or type label anywhere on the row
- Validating or repairing transfer data
- Any redesign of the rows, screens, or tabs involved

---

## Deliverable

List the files you created and modified. Report: every place a transfer title was being composed before this change; how cross-currency transfers display their amount today; and any data anomaly you hit (missing account names, self-transfers). Flag any deviation from this spec and why.
