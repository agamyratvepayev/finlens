# Balance — Remove Account Transaction Amount (−) Sign

> Implementation prompt (Flutter)

## Role and context

You are making one change across **FinLens**, a Flutter personal-finance app: **transaction amounts stop carrying a leading `+` or `−` sign.** Direction is carried by color, which the design already uses consistently — red `#FF453A` for money out, green `#30D158` for money in.

This is app-wide. It applies on the **Ledger** tab, the **category detail** and **account detail** screens reached from Balance, the transaction detail screen, and anywhere else a transaction amount is rendered.

**Match the project's existing conventions.** Use the formatter, models, and design tokens that are already there. Do not introduce a new formatting library or a new design-token system. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

This change touches **number formatting and nothing else.** Do **not**:

- change any color, type size, weight, row height, padding, card radius, or alignment;
- change tabular-figure treatment or right-edge alignment of amounts;
- change how any figure is *calculated* — only how it is rendered;
- change the `↓` / `↑` glyphs in the period chip. They are direction indicators, not signs, and they stay exactly as they are;
- restyle or relayout any screen while you are in these files;
- "clean up", normalize, or tokenize unrelated style values.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · The rule, and the test for applying it

The distinction is not "transaction vs. total" — it is **whether the figure already carries direction in its color.**

> **If a figure is rendered in the red/green direction colors, it shows no sign.**
> **If a figure is rendered neutral (white or muted), it keeps its sign, because nothing else tells the reader it is negative.**

### Unsigned — remove the sign

| Figure | Before | After |
|---|---|---|
| Transaction row amount | `−$120` | `$120` |
| Transaction row amount, income | `+$900` | `$900` |
| Transfer row amount | `−€500` | `€500` |
| Day-group header total (Ledger) | `−$522` | `$522` |
| Transaction detail hero amount | `−$120` | `$120` |
| Same-transactions list rows and `TOTAL` / `AVERAGE` | `−$1,032` | `$1,032` |
| `ASSETS` / `LIABILITIES` section totals on Balance | as today | unsigned, as today |

### Signed — the sign stays

| Figure | Why |
|---|---|
| **Running balance under a row** (`$5,430`, `€2,797`) | Can legitimately go below zero — overdraft, credit balance. A minus here means *"below zero"*, not *"money out"*. Dropping it turns a `−$300` debt into a `$300` credit: a factual error. |
| **`Balance after`** on the transaction detail | Same reason. |
| **Account balances** anywhere they render neutral | Same reason. |
| **Net Worth** on Balance | Rendered neutral and can be negative. |
| Any other neutral-colored figure that can be negative | Same test. |

**The running balance is the trap in this task.** In the fixture rows below, the muted figure sitting directly under the colored amount is a balance, not a second copy of the amount. It must come out of this change untouched.

---

## 2 · Implement it in one place

There must be exactly **one** function or extension that turns a signed amount into display text, and it takes an explicit parameter:

```dart
String format(Money amount, {bool signed = ...});
```

- Call it with `signed: false` for every figure in the unsigned table, `signed: true` for every figure in the signed table.
- **Do not strip characters from already-formatted strings** at call sites. No `replaceAll('-', '')`, no `substring(1)`, no regex over formatted output. That breaks for locales that place the sign differently and for right-to-left text.
- If the project currently prepends `'+'` / `'−'` ad hoc at individual call sites, consolidate those into the formatter first, then apply the parameter. `git grep` for `'+'`, `'-'`, `'−'`, and `'\u2212'` near currency formatting and fix every hit.
- If a formatter already exists but has no such parameter, add it rather than writing a second formatter.

---

## 3 · Transfers

Transfers render **red and unsigned**, exactly like an expense: `€500`, not `−€500` and not a neutral color.

A transfer moves money between the user's own accounts, so its color depends on **which side of it the reader is looking at**:

- On the **source** account's detail screen, and in the **Ledger** where the row is shown from the source side, it is an outflow → **red**.
- On the **destination** account's detail screen, it is an inflow → **green**, because that account's running balance goes *up* on that row. Rendering it red beside a rising balance would read as a bug.

**Verify how the repository and the Ledger currently model transfers before implementing this** — whether a transfer is one row or two, and whether the Ledger already picks a side. Do not change that model; only make the color and sign follow the side already being displayed. **Report what you found.**

---

## 4 · Accessibility — mandatory, not optional

Removing the sign makes **color the sole visual carrier of direction**. That fails for colorblind users and conveys nothing to a screen reader. Both mitigations ship with this change:

- **Every amount gets a semantics label stating direction in words**, e.g. `'Expense, 120 dollars'`, `'Income, 900 dollars'`, `'Transfer out, 500 euros'`. The label is on the amount, not on the whole row, so it is not lost among other row text.
- **Verify contrast.** Both `#FF453A` and `#30D158` must meet 4.5:1 against the surface they sit on (`#1C1C1E` for cards, `#000000` where rows sit on the page background). **If either fails, report it — do not silently ship it, and do not change the color to fix it.**

> If the team later wants a non-color visual cue back, the cheapest option is a small `↓` / `↑` glyph before the amount, matching the period chip's existing convention. **Do not add it unless asked.**

---

## 5 · Edge cases

| Case | Required behavior |
|---|---|
| Amount is exactly `$0` | Renders `$0`, no sign, in whatever color the app uses for zero today. |
| Running balance is exactly `$0` | Renders `$0`. |
| Running balance is negative | Keeps its `−`. |
| Day-group total is negative | Unsigned, red — as the Ledger already does. |
| Day-group total is zero on a 3+ transaction day | `$0`, unsigned. |
| Foreign-currency amount | Sign handling is identical; the currency symbol and its position are unchanged. |
| Locale places the minus after the number, or uses parentheses | Handled inside the formatter, never by string surgery. |
| Right-to-left locale | Formatter output stays correct; do not hand-assemble sign + symbol + digits. |
| Export / backup / sync / CSV / PDF payloads | **Unchanged.** These carry signed machine-readable values. This task is presentation only. |
| Amount used inside an editable text field | **Unchanged.** Editing fields keep whatever they do today. |

---

## 6 · Acceptance criteria

Fixture rows:

- Ledger, `9 AUG`: `Groceries` / `Bakery & fruit` / `Cash (USD Wallet)` — amount `$120` red, balance `$5,430` beneath.
- Ledger, `4 AUG`: `Transfer` / `Holiday cash swap` / `Cash (EUR Wallet) → Cash (USD Wallet)` — amount `€500` red, balance `€2,797` beneath.

Checklist:

- [ ] No transaction amount anywhere in the app renders a leading `+` or `−`.
- [ ] The `4 AUG` transfer reads `€500`, not `−€500`, and stays red.
- [ ] The `9 AUG` row reads `$120`, and the `$5,430` beneath it is untouched.
- [ ] A row whose running balance is negative still renders it with a minus.
- [ ] `Balance after` on the transaction detail keeps its sign when negative.
- [ ] Net Worth keeps its sign when negative.
- [ ] Day-group header totals render unsigned.
- [ ] Sign suppression lives in **one** formatter; `git grep` finds no ad-hoc `'+'` / `'−'` prefixing and no sign-stripping at any call site.
- [ ] The period chip's `↓` and `↑` glyphs are unchanged.
- [ ] Every amount exposes a semantics label naming its direction in words.
- [ ] Red and green contrast is measured against both `#1C1C1E` and `#000000`, and the result is reported.
- [ ] Exports, backups, and sync payloads are byte-identical to before.
- [ ] `git diff` contains no color, size, weight, padding, or alignment change.
- [ ] No analyzer warnings.

**Tests to write:**

- unit tests for the formatter: positive, negative, and zero amounts with `signed: false` and `signed: true`;
- a unit test asserting a negative **balance** formats with its minus while a negative **amount** does not;
- a unit test for a foreign-currency negative amount, and for a locale whose minus placement differs;
- a widget test asserting a Ledger expense row renders `$120` and its balance renders `$5,430`;
- a widget test asserting a transfer row renders unsigned and red;
- a widget test asserting each amount carries a direction semantics label.

---

## 7 · Non-goals

- Adding a `↓` / `↑` glyph or any other non-color direction cue
- Changing the red/green tokens, or any other color
- Changing how any figure is calculated, grouped, or aggregated
- Changing signs in exports, backups, sync payloads, or editable fields
- Removing signs from balances or any neutral-colored figure
- Any redesign, cleanup, or normalization of the screens you touch

---

## Deliverable

List the files you created and modified. Report: every call site that was prepending a sign ad hoc; how transfers are modelled and which side the Ledger displays; and the measured contrast ratios for red and green. Flag any deviation from this spec and why.
