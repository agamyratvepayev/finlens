# Balance — Adding Varied Transactions for Each Account to Analyze

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. The app currently has too little sample data to evaluate the Balance tab, the category and account detail screens, the date-range presets, the day-group totals, and the Same-transactions screen. Several of those features cannot be judged at all without months of varied history behind them.

Build a **development-only seeder** that populates the database with realistic, varied transactions across every account.

**Match the project's existing conventions.** If the project already has a fixture, factory, or seeding mechanism, extend it rather than writing a parallel one. Use the existing repository and models — do not write raw SQL that bypasses them. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary — safety first

This is test data. It must never reach a real user's database.

- The seeder is **debug-only**. Guard it with `kDebugMode` (or the project's existing debug flag) so it cannot be invoked from a release build. If the project has a developer/debug menu, put the entry point there; if not, expose it as a function called from a debug entry point, not from any user-facing screen.
- It must **not** run automatically on launch. It runs only when explicitly invoked.
- Provide two operations: **seed** (add the data) and **reset** (remove everything the seeder created and restore the prior state). Seeding twice must not double the data — either make it idempotent or have it wipe its own previous output first.
- **Never modify or delete data the seeder did not create.** Tag seeded records so they can be identified and removed cleanly.
- Do not change any production code path, model, screen, or repository method to accommodate the seeder. If a repository lacks a bulk-insert method, add one **only if** it is a genuine addition and not a change to existing behavior — and say so in your report.

---

## 1 · Accounts to cover

Seed against the accounts the app already defines. For reference, the expected structure is:

| Category | Accounts |
|---|---|
| Spendable | Main Checking, Cash (USD Wallet), Cash (EUR Wallet), Family Wallet |
| Receivables | 4 accounts (e.g. Personal Loan, Client Invoice, Pending Refund, Dinner Split) |
| Investments | US Stocks (S&P 500), Gold Portfolio, Crypto Wallet (BTC/ETH), Tech ETFs (QQQ), Private Pension |
| Valuables | 4 accounts (e.g. Primary Residence, Personal Car) |
| Credit Cards | Main Credit Card (Amex) and at least one more |
| Payables | 2 accounts |
| Bank Loans | 1 account |

If the app's real account list differs, **use the real one** — do not create or rename accounts to match this table.

---

## 2 · Volume and type coverage

**At least 5–6 transactions of every type that applies to an account.** Which types apply depends on what the account is — do not force income onto a mortgage or groceries onto a car.

| Account kind | Expenses | Income | Transfers | Notes |
|---|---|---|---|---|
| Spendable (checking, wallets) | 15–30 each | 5–8 each | 6–10 each | The busiest accounts. Main Checking is the primary account and should have the most. |
| Credit Cards | 12–20 each | — | 5–8 payments in | Purchases out, payments arriving from Spendable. |
| Receivables | 1–2 each | 5–6 each | — | Money owed to the user arriving over time. |
| Payables | 5–6 each | — | 5–6 each | Amounts owed, paid down by transfer. |
| Bank Loans | — | — | 6–8 each | Monthly repayments arriving from Main Checking. |
| Investments | 2–3 each | 5–6 each | 5–6 each | Contributions in by transfer, dividends/gains as income, fees as expenses. |
| Valuables | 1–2 each | — | 0–1 each | Property and a car barely transact. **Do not** invent 6 transactions for a house — realism matters more than symmetry here. |

**Report the final count per account.**

Every **category** the app defines must appear on at least 5 transactions, so category screens are never near-empty.

---

## 3 · Time span and distribution

- Cover **at least 14 months back from today**, so `This year`, `Last 12 months`, and `All time` differ from each other meaningfully.
- Generate dates **relative to `DateTime.now()` at seed time**, never hardcoded — otherwise the data goes stale and the range presets stop being exercised.
- Seed the random number generator with a **fixed constant** so every run produces the same data. Reproducibility matters more than novelty here.

Distribution must be uneven, the way real spending is:

- **Recurring transactions land on consistent days** — rent on the 1st, salary on the 28th, a transit pass monthly, a subscription on the same date each month. These are what make the Same-transactions screen's frequency line meaningful.
- **Groceries and dining cluster on weekends**; a few weekdays have nothing at all.
- **Amounts vary within a category** — groceries between roughly 80 and 220, not always 150. Recurring bills stay near-constant with occasional variation (a higher utility bill in winter).
- Include a few **larger irregular items** — an annual insurance payment, a holiday, a one-off repair.

---

## 4 · Balance reconciliation

Seeded transactions must not contradict the account balances the rest of the app is specified against.

For each account, **back-compute the opening balance** so that after applying every seeded transaction the current balance equals the account's documented figure:

```
openingBalance = targetBalance − Σ(signed contribution of every seeded transaction)
```

Reference targets: Main Checking `$12,198`, Cash (USD Wallet) `$5,430`, Cash (EUR Wallet) `€2,797`, Family Wallet `$1,700`, Spendable total `$22,405`, Receivables `$3,200`, Investments `$47,700`, Valuables `$150,000`, Credit Cards `$6,470`, Payables `$3,200`, Bank Loans `$20,000` — giving Assets `$223,305`, Liabilities `$29,670`, Net Worth `$193,635`.

**If the app's real balances differ from these, reconcile to the real ones** and report the mismatch. After seeding, the Balance tab's Net Worth must be internally consistent with the transaction history — a running balance the user can scroll through and have it arrive at the figure on the Balance screen.

Every transfer must be applied to **both** accounts consistently, so both sides reconcile.

---

## 5 · The data must exercise these specific features

This is the point of the task. Generic random data will not surface these.

**Day-group totals** (shown only when a day has 3+ transactions):
- at least 10 days with exactly **1** transaction;
- at least 8 days with exactly **2**;
- at least 6 days with **3 or more**;
- at least one day with **5+**;
- at least one day whose transactions **net to zero**;
- at least one day with a large income and a large expense (e.g. `+$5,000` salary and `−$4,800` rent) — the two-row case where the total stays hidden.

**Same-transactions screen** (keyed on category + account + direction):
- at least 3 category/account pairs with **8 or more** transactions each, so `See all` and the frequency line are exercised;
- at least one pair with exactly **1** transaction;
- at least one pair with exactly **2**;
- at least one pair whose transactions all fall within a **span under 14 days**, so the frequency line hides;
- the same category on **two different accounts** (e.g. Groceries on both Main Checking and Cash (USD Wallet)) — these must produce two separate lists.

**Date range presets** — every preset must return a non-zero count for at least some keys, and at least one key must return **zero** for `This week` so the disabled-preset state can be seen.

**Transfers**:
- at least one pair of accounts with transfers in **both directions** (Main Checking → Credit Card and Credit Card → Main Checking), which must produce two separate lists;
- at least 5 transfers on the same directional pair, so that list has substance;
- at least one transfer between accounts of **different currencies** (Cash EUR Wallet ↔ Cash USD Wallet).

**Negative running balance** — at least one stretch where Main Checking or a wallet goes **below zero** for a few days before recovering. This is the only way to verify that balances keep their minus sign while amounts do not.

**Text and layout stress**:
- transactions **with no description** at all;
- at least one description long enough to ellipsize (60+ characters);
- descriptions containing Turkish characters with descenders — `Ağustos kirası`, `Şubat faturası`, `Yıllık sigorta ödemesi` — to verify no clipping;
- at least 10 transactions carrying a **tag**, with at least 3 distinct tags;
- if the model has a separate note field, at least 5 transactions carrying a note.

**Multi-currency** — the EUR wallet's transactions are stored in EUR and must convert correctly into base-currency totals.

---

## 6 · Realism rules

- **Descriptions read like a person wrote them**: `Weekly shop`, `Bakery & fruit`, `Monthly transit pass`, `August rent`, `Landing page project`, `Partial payment before statement`. Not `Transaction 42` or `Test expense 7`.
- Repeat a description across occurrences of the same recurring item — `Weekly shop` should appear many times, because that is what makes the Same-transactions list realistic.
- Vary description across one-off items in the same category, so a category list is not seven identical strings.
- **No placeholder text, no lorem ipsum, no sequential numbering** in user-visible fields.
- Merchant-style names may repeat across accounts; that is realistic.
- Amounts use sensible precision for their currency — no `$127.4399`.

---

## 7 · Edge cases

| Case | Required behavior |
|---|---|
| Seeder run twice | No duplicated data. Either idempotent or self-wiping. |
| Reset after seed | Database returns to its pre-seed state; no orphaned transactions, no drifted balances. |
| An account in the table does not exist in the app | Skip it and report; do not create accounts. |
| A category referenced does not exist | Skip and report; do not create categories. |
| Currency conversion rate unavailable | Use the app's existing conversion path; if it needs a rate that is not present, report rather than inventing one. |
| Transfer between different currencies | Follow whatever the app does today. If it cannot represent this, skip those and **report it**. |
| Future-dated or scheduled transactions | Include 2–3 if the model supports them; skip and report if it does not. |
| Seeding a large volume | Insert in a batch or a single transaction, not row by row, so it completes in seconds. |

---

## 8 · Acceptance criteria

- [ ] The seeder cannot be invoked from a release build.
- [ ] It never runs automatically on launch.
- [ ] Running it twice produces the same database state as running it once.
- [ ] Reset removes every seeded record and leaves pre-existing data untouched.
- [ ] Every account has at least 5–6 transactions of each type that applies to it, per §2, and the counts are reported.
- [ ] Every category appears on at least 5 transactions.
- [ ] Data spans at least 14 months and is generated relative to today, with a fixed RNG seed.
- [ ] Running the seeder twice on different days produces data shifted to match, not stale dates.
- [ ] Each account's running balance, scrolled to the newest transaction, arrives at the balance shown on the Balance tab.
- [ ] Net Worth on the Balance tab equals filtered assets minus liabilities and is consistent with the seeded history.
- [ ] All the coverage requirements in §5 are present — verify each one by opening the relevant screen, not by reading the code.
- [ ] At least one account dips below zero at some point in its history.
- [ ] No user-visible field contains placeholder or sequentially numbered text.
- [ ] Turkish descriptions render without clipping on the transaction rows.
- [ ] Seeding completes in a few seconds, not minutes.
- [ ] No production code path was modified to accommodate the seeder.
- [ ] No analyzer warnings.

**Tests to write:**

- unit test: after seeding, each account's opening balance plus the sum of its transactions equals its target balance;
- unit test: every transfer appears on both accounts with matching amounts and dates;
- unit test: the day-distribution requirements in §5 hold — counts of 1-, 2-, and 3+-transaction days meet the minimums;
- unit test: at least one category/account/direction key has 8+ transactions and at least one has exactly 1;
- unit test: seeding twice yields the same record count as seeding once;
- unit test: reset returns the record count to its pre-seed value.

---

## 9 · Non-goals

- Shipping sample data to production or to any release build
- A user-facing "load demo data" feature
- Changing models, screens, or repository behavior to make seeding easier
- Generating data for the Planner or Insight tabs beyond what these transactions naturally produce
- Perfectly symmetric coverage at the cost of realism — a house does not need six transactions
- Randomised data that differs on every run

---

## Deliverable

List the files you created and modified. Report: the final transaction count per account and per category; the opening balance computed for each account; which of the §5 coverage requirements you could not satisfy and why; whether the model supports notes, tags, scheduled transactions, and cross-currency transfers; how you tagged seeded records for clean removal; and how long a full seed takes. Flag any deviation from this spec and why.
