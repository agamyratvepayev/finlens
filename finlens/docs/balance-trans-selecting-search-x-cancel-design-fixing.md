# Balance — Trans Selecting Search (X) Cancel Design Fixing

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. On the add/edit transaction screen, tapping the `From` / `To` field opens the **account picker** bottom sheet and tapping the category field opens the **expense category picker** bottom sheet. Both carry a search field at the top: a `#2C2C2E` rounded field with a leading magnifier and placeholder text (`Search accounts`, `Search categories`).

**Once the user has typed, there is no way to clear the query except backspacing it character by character.** Add a clear button inside the field.

**Match the project's existing conventions.** Use the widgets and design tokens already there. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

Do **not**:

- change the search field's background, radius, height, padding, placeholder text, font size, or its leading magnifier;
- change the sheet's title, grabber, background, radius, or dismissal behavior;
- change the results below the field — rows, grouping, balances, ordering, or the grid;
- change what typing in the field does;
- add a `Cancel` text button beside the field, or any other new control;
- touch the Balance, Ledger, Planner, or Insight tabs.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · The clear button

A single glyph inside the field, at its trailing edge.

| Property | Value |
|---|---|
| Glyph | The app's existing filled circle-x, or its closest equivalent in the icon set already in use |
| Size | 16 pt |
| Colour | `#8E8E93` |
| Position | Inside the field, after the text, at the trailing edge; 8 pt from the text |
| Visible when | The query is **non-empty** |
| Hidden when | The query is empty — render **nothing**, not a dimmed or disabled glyph |

**Tap target 44 × 44 pt**, centred on the glyph and extending beyond the field's vertical bounds if needed. A 16 pt hit area is unusable.

The field's text must never run underneath the glyph. Reserve its width in the field's content padding so that a long query ellipsizes before it reaches the button, rather than sliding beneath it.

---

## 2 · What it does

**It clears the query. It does not close the sheet.**

- Tapping it empties the field, restores the unfiltered results, and hides itself.
- **Keyboard focus stays in the field and the keyboard stays open**, so the user can immediately type a different query. Clearing is a correction, not an exit.
- Dismissing the sheet remains the job of tapping outside or dragging down. Do not overload this button with dismissal.
- Clearing does not change the sheet's height, scroll position of the sheet itself, or any selection already made.

The results list scrolls back to its top when cleared, since the previous scroll offset belonged to a different, shorter list.

---

## 3 · Both pickers, one implementation

Both sheets use the same search field. **Fix it once, in the shared widget**, so the button appears on both.

- If the two sheets currently build their own search fields separately, extract one shared field and use it in both, **changing no other value while you do**. That extraction must be pixel-neutral apart from the new button.
- Apply the same treatment to **every other sheet in the app that uses this search field**. List them in your report.
- If a screen uses a visually similar but structurally different search field, leave it alone and **report it** rather than unifying it in this task.

---

## 4 · Accessibility

- The button is a `Semantics` button labelled `Clear search`.
- It is announced only when present; when the query is empty it must be absent from the semantics tree, not present-and-hidden.
- Activating it announces that the search was cleared, so a screen-reader user knows the list changed beneath them.
- It is reachable in the traversal order immediately after the text field.

---

## 5 · Edge cases

| Case | Required behavior |
|---|---|
| Query typed then fully backspaced | The button disappears as the field empties — no lingering glyph on an empty field. |
| Query is a single character | Button visible. |
| Query is only whitespace | Treated as non-empty: the button shows, and tapping it clears the whitespace. |
| Query longer than the field | Text ellipsizes before reaching the button and never renders underneath it. |
| Search returns no results | The button stays visible — this is exactly when the user wants to clear and retry. |
| Cleared while results are scrolled down | Results return to the top; the sheet's own height and position are unchanged. |
| Cleared while the keyboard is closed (query typed, keyboard dismissed) | Clearing works, and does **not** reopen the keyboard. Focus behavior follows the field's current focus state. |
| Sheet reopened after a previous search | The field opens empty, as it does today. Do not persist queries. |
| RTL locale | The button sits at the field's trailing edge, which is the left. |
| Device text scaling at max | The glyph stays 16 pt; the field grows with the text; the button stays vertically centred. |

---

## 6 · Acceptance criteria

- [ ] Typing in the account picker's search field reveals a clear button at its trailing edge; the empty field shows none.
- [ ] The same holds in the category picker.
- [ ] Tapping it empties the field and restores the unfiltered results.
- [ ] Focus stays in the field and the keyboard stays open after clearing.
- [ ] Tapping it never closes the sheet.
- [ ] Its tap target measures at least 44 × 44 pt.
- [ ] A long query ellipsizes and never renders under the button.
- [ ] With a query that matches nothing, the button is still visible.
- [ ] The button is implemented once in a shared field; every sheet using that field gets it, and each is listed in the report.
- [ ] Screen reader announces `Clear search`, and the button is absent from the tree when the query is empty.
- [ ] `git diff` contains no change to the field's background, radius, height, padding, placeholder, magnifier, or to any result row.
- [ ] No `Cancel` button or other control was added.
- [ ] No analyzer warnings.

**Tests to write:**

- widget test: with an empty query the clear button is absent from the tree; after entering text it is present;
- widget test: tapping it empties the controller and the unfiltered result count returns;
- widget test: after tapping it, the field still holds focus;
- widget test: tapping it does not pop the sheet's route;
- widget test: its hit area measures at least 44 × 44 pt;
- widget test: a whitespace-only query still shows the button.

---

## 7 · Non-goals

- A `Cancel` text button beside the field
- Closing the sheet from this button
- Search history, suggestions, or recent queries
- Persisting a query across sheet openings
- Changing what the search matches or how it filters
- Unifying search fields that are structurally different from this one
- Any redesign of the sheets or their results

---

## Deliverable

List the files you created and modified. Report: whether the two pickers shared a search field already or you had to extract one; every other sheet that inherits the button through that shared widget; any visually similar search field you deliberately left alone and why; and confirmation that the extraction changed no existing value. Flag any deviation from this spec and why.
