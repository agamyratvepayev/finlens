# Balance — Net Worth, Assets and Liabilities Swiping Order Fixing

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. At the top of the **Balance** tab sits a horizontally swipeable card with a page indicator. It has three pages: **Net Worth**, **Assets**, and **Liabilities**.

The pages are currently ordered **Net Worth, Liabilities, Assets**, so swiping right-to-left goes `Net Worth → Liabilities → Assets → Net Worth`.

They should be ordered **Net Worth, Assets, Liabilities**, so swiping right-to-left goes `Net Worth → Assets → Liabilities → Net Worth`.

This is the order everything else on the screen already uses: the `ASSETS` section is listed above the `LIABILITIES` section, and the ratio bar puts the green assets segment on the left and the red liabilities segment on the right. The carousel is the only place that disagrees.

**Match the project's existing conventions.** Use the page controller, widgets, and design tokens already there. Do not introduce a new carousel package. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

This is a reordering and nothing else. Do **not**:

- change the content, layout, typography, colors, or figures of any of the three pages;
- change the card's height, background, radius, margins, or padding;
- change the page indicator's styling — dot size, spacing, colors, or the active dot's shape;
- change the swipe physics, transition curve, or duration;
- change whether the carousel wraps — keep exactly the wrapping behavior it has today;
- add, remove, or merge pages;
- change the `ASSETS` / `LIABILITIES` sections below, the ratio bar, the header controls, or the tab bar;
- touch the Ledger, Planner, or Insight tabs.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · The order

| Index | Page |
|---|---|
| 0 | **Net Worth** |
| 1 | **Assets** |
| 2 | **Liabilities** |

- Swiping **right to left** advances: `Net Worth → Assets → Liabilities`.
- Swiping **left to right** goes back: `Liabilities → Assets → Net Worth`.
- Net Worth remains the page shown on entry.
- If the carousel wraps today, it keeps wrapping: right-to-left from Liabilities reaches Net Worth, and left-to-right from Net Worth reaches Liabilities. If it does not wrap today, do not add wrapping. **Report which it does.**

---

## 2 · The page indicator

The dots must follow the same order as the pages. Dot 1 is Net Worth, dot 2 is Assets, dot 3 is Liabilities.

If the indicator is driven directly by the page controller's index, this happens for free — verify it does rather than assuming. If the indicator has its own hardcoded list or its own ordering logic, fix it in the same place so the two can never drift apart again. **Report which of the two you found.**

---

## 3 · Audit every hardcoded page index

This is the part that breaks silently. Any code that refers to a page by number now points at a different page.

`git grep` the page controller and its index for:

- `jumpToPage` / `animateToPage` calls with a literal index;
- conditionals like `if (pageIndex == 1)` that assumed Liabilities;
- analytics or logging that records a page index or a page name;
- deep links, notifications, or shortcuts that open a specific page;
- any test asserting a page index.

Fix each one to point at the page it was always meant to reach. **List every site you changed in your report.**

Prefer referring to pages by a named enum (`BalancePage.netWorth`, `.assets`, `.liabilities`) rather than by integer, so the next reorder cannot cause this class of bug. If the project already has such an enum, use it; if it does not, introducing one here is in scope.

---

## 4 · Persisted page index

If the app remembers which page the user was last on, a stored index written before this change now resolves to a different page — someone who left the app on Liabilities reopens it on Assets.

- If the stored value is an **integer index**, treat old values as stale: reset to Net Worth on the first launch after this change, or migrate the stored value through the old→new mapping (`0 → 0`, `1 → 2`, `2 → 1`).
- If it stores a **page name**, nothing needs migrating.
- If nothing is persisted, nothing to do.

**Report which case applies and what you did.**

---

## 5 · Accessibility

- Each page announces its position and name, e.g. `Assets, page 2 of 3`. Update these so the numbers match the new order.
- The page indicator itself is decorative and should stay excluded from the semantics tree, or keep whatever treatment it has today.
- Screen-reader users must be able to move between pages with the standard swipe gestures in the new order.

---

## 6 · Edge cases

| Case | Required behavior |
|---|---|
| Swipe released mid-way | Settles to whichever page it was closest to, as today. |
| Rapid repeated swipes | Advances one page per swipe, as today. |
| Data refresh while on Assets | Stays on Assets; the figure updates in place. |
| Filter active (categories or accounts hidden) | All three pages show filtered figures, exactly as they do today. Do not change which values each page reads. |
| RTL locale | Swipe direction mirrors as the framework already handles it; the logical order `Net Worth, Assets, Liabilities` is unchanged. Verify the indicator mirrors with it. |
| Device text scaling at max | Unchanged; this task does not touch page content. |

---

## 7 · Acceptance criteria

- [ ] Entering the Balance tab shows **Net Worth**.
- [ ] One right-to-left swipe shows **Assets**; a second shows **Liabilities**.
- [ ] One left-to-right swipe from Assets shows **Net Worth**.
- [ ] Wrapping behavior is identical to before the change.
- [ ] The page indicator's active dot matches the visible page on all three pages.
- [ ] No hardcoded index anywhere still points at the wrong page; every site is listed in your report.
- [ ] A persisted last-page value cannot land the user on the wrong page after updating.
- [ ] Screen reader announces `page 1 of 3`, `page 2 of 3`, `page 3 of 3` matching Net Worth, Assets, Liabilities.
- [ ] `git diff` contains no change to page content, card geometry, indicator styling, or swipe physics.
- [ ] In an RTL locale the pages traverse in the same logical order.
- [ ] No analyzer warnings.

**Tests to write:**

- widget test: the initial page is Net Worth; one forward swipe lands on Assets; two land on Liabilities;
- widget test: a backward swipe from Assets lands on Net Worth;
- widget test: the indicator's active dot index equals the page controller's index on every page;
- unit test: the stored-index migration maps `1 → 2` and `2 → 1` (only if an integer index is persisted);
- widget test: each page's semantics label reports the correct position out of three.

---

## 8 · Non-goals

- Adding, removing, or merging pages
- Changing any page's content, figures, or styling
- Changing the page indicator's appearance
- Adding or removing wrapping
- Changing swipe physics, curves, or durations
- Adding tap-to-advance or a page-switching control
- Any redesign of the Balance screen

---

## Deliverable

List the files you created and modified. Report: whether the carousel wraps today; whether the page indicator reads the controller index or keeps its own ordering; every hardcoded page index you found and fixed; whether a last-page index is persisted and how you handled stale values; and whether you introduced a named page enum. Flag any deviation from this spec and why.
