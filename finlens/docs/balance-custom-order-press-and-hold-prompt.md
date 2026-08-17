# Implementation Prompt — Custom Order by Press and Hold (Flutter)

## Role and context

You are adding one option to the **SORT** bottom sheet on the **Balance** tab of **FinLens**, a Flutter personal-finance app, and one gesture to the Balance list itself.

The Balance screen lists account categories in two sections — `ASSETS` (Spendable, Receivables, Investments, Valuables) and `LIABILITIES` (Credit Cards, Payables, Bank Loans). Each category row shows an icon tile, name, account count, amount, and percentage-of-section, and expands to reveal its member accounts. A small circular sort button in the header opens a bottom sheet with four mutually-exclusive options, the active one marked by a purple checkmark on the left:

```
SORT
✓  Value — high to low
   Value — low to high
   Name — A to Z
   Change — most active
```

**Match the project's existing conventions.** Use the state management, domain models, persistence layer, and design tokens that are already there — if the project uses Bloc, write a Bloc; if IDs are `int`, use `int`; if colors and text styles live in a theme file, read them from it. Do not introduce a new state-management library, a new persistence mechanism, a new drag-and-drop package, or a new design-token system. The Dart in this document is a behavioral specification, not code to paste.

---

## Goal

Add a fifth sort option, **Custom**, and let the user arrange categories and accounts by hand **directly on the Balance list** by pressing and holding a row and dragging it.

**The one hard rule: an account can never move to a different category.** Accounts reorder only within their own category. Categories reorder only within their own section (`ASSETS` or `LIABILITIES`). This is a *display order* — no account's category membership, and no domain data whatsoever, is ever modified.

There is **no separate arrange/edit screen.** Reordering happens in place, on the real list.

---

## Hard boundary

Strictly additive. Do **not**:

- change the four existing sort options, their labels, their order, or their behavior;
- restyle the SORT sheet, the Balance list rows, the header controls, the ratio bar, the section headers, or the tab bar;
- change any existing spacing, type size, or color value;
- change what a **tap** on a row does — tapping a category or account row must keep navigating exactly where it navigates today;
- move accounts between categories, or write anything to the domain layer;
- add any new **permanent** element to the Balance screen — no drag handles, no grip glyphs, no "reorder mode" banner, no edit button, no chip. The only new on-screen elements are transient and appear during or immediately after a drag.

The Balance screen already has a funnel **filter button** next to search that hides categories and accounts. Do not modify it, its bottom sheet, or its filtering logic. §6 describes how ordering and filtering compose.

Scope is the **Balance tab only**. Do not touch the Ledger, Planner, or Insight tabs. If something existing looks wrong, **report it — do not change it.**

---

## 1 · The SORT sheet gets a fifth row

Below `Change — most active`, add a **1 pt divider** inset 20 pt on each side, then:

```
   Custom
   Press and hold a row to move it
```

- Same row height, padding, and label type as the four existing options.
- Reuses the same left checkmark slot: shows the purple checkmark when Custom is the active sort, empty otherwise.
- **Differs in one way only:** a secondary line beneath the label (12 pt, `#8E8E93`).
- **No disclosure chevron. Tapping the row does not push anything.** It selects Custom, exactly like the four rows above it, and the sheet dismisses the same way it does for them.

The divider separates "pick an automatic ordering" from "use the order I made myself."

That subtitle is the **only** place the press-and-hold gesture is advertised. Nothing on the Balance list hints at it. Do not compensate by adding a hint elsewhere — but do not drop the subtitle either.

---

## 2 · The gesture

**Press and hold any category or account row on the Balance list, then drag.**

- Use the project's reorderable list with a **delayed** drag start (Flutter's `ReorderableDelayedDragStartListener`, or the equivalent long-press recognizer if the project already uses a different package). The delay is what keeps a fast vertical flick scrolling the list normally instead of lifting a row.
- **The whole row is the drag target.** There is no handle and no grip icon anywhere.
- A **tap** keeps its current behavior — navigating to the category or account. A tap and a press-and-hold are different gestures and must not interfere; verify that a quick tap never lifts a row and a long press never navigates.
- Expanding/collapsing a category keeps whatever control it uses today (the caret or the row tap, whichever it is now). Do not change it.
- **Haptic feedback on pick-up and on each reorder step**, matching whatever the app already uses. With no handle on screen, the haptic is the only confirmation that the lift registered — it is required, not decorative.
- **The gesture is always available**, whatever sort is currently active. The user does not have to select Custom first. See §4.

### Lifted row

- Scales to **1.02**, background `#3A3A3C`, radius 10, shadow `0 12 28 rgba(0,0,0,0.65)`, and follows the finger.
- Its original slot becomes a **dashed placeholder**: 1.5 pt dashed `rgba(94,92,230,0.6)`, radius 9, fill `rgba(94,92,230,0.06)`, same height as the row it replaced. The placeholder moves as the drop target changes.
- A lifted **category** carries its accounts with it as one block, whether it is expanded or collapsed. Do not expand it, collapse it, or re-parent anything while it travels.

### Account rows

An account can only be dragged while its category is **expanded**, because that is the only time it is on screen. This needs no special handling — it falls out of the list structure.

---

## 3 · Containment

The boundary is shown, not enforced with errors.

**Dragging a category:**

- It may only be dropped among the categories of **its own section**. The section headers are the boundaries.
- The **opposite section** — its header, its rows, and its total — drops to **42% opacity** over 200 ms.

**Dragging an account:**

- It may only be dropped between the first and last position **of its own category**.
- Every **other** category row in both sections, and the opposite section, drops to **42% opacity** over 200 ms. The owning category's row and its account rows stay at full opacity, so the legal region reads as the only lit part of the screen.

**In both cases:**

- If the finger travels past the legal bounds, the lifted row **stops at the boundary and stays there** — it does not bounce back, vanish, snap into another group, or trigger auto-scroll toward one. The drop target simply clamps to the group's first/last slot.
- Releasing outside the group drops it at the clamped position. **There is no failure state, no error toast, no rejected drop** — the interaction makes the invalid move unreachable rather than punishing it.
- Auto-scroll near the viewport edges is allowed **only within the current group's bounds** — never scroll toward a region the item cannot legally reach.
- Everything returns to full opacity over 200 ms on release.

Implementation note: the simplest correct structure is **one reorderable group per set** — one per section for its categories, and one per expanded category for its accounts — rather than a single flat list whose indices you have to police. If you do flatten, you must clamp `newIndex` to the group's index range in `onReorder` and reject nothing.

---

## 4 · Switching to Custom, and undoing it

- **If a different sort is active when the user completes a drag**, the sort selection flips to **Custom** at that moment. It has to — otherwise the automatic comparator would snap the row back the instant the finger lifts.
- **If Custom has never been configured**, it is seeded with **the order that was on screen when the drag started** — whatever sort was active — with the dragged item moved. The user's list never rearranges itself beyond the move they just made.
- **Selecting one of the four automatic sorts later does not erase the custom order.** It is retained and restored the next time Custom is picked.

### The undo bar

**Every completed drag shows a transient bar containing `Undo` and nothing else.** No message, no `Switched to Custom`, no description of what moved. The bar exists to offer a way back from a move, not to narrate state.

The switch to Custom is never announced anywhere — not in this bar, not in the list, not as a banner or toast. A user who wants to know which sort is active opens the SORT sheet and sees the checkmark.

- Use the app's existing snackbar/toast pattern and styling. **Do not build a new component and do not invent new colors.**
- It floats above the pinned `+ Add expense` button. It must **not** push, reflow, or scroll anything in the list.
- Duration ~5 s. Dismissed early by scrolling, tapping elsewhere, or leaving the tab.
- **`Undo` reverts everything that drag did.** Always the row's position; and when that same drag also flipped the sort selection to Custom (§4), the selection goes back too. The flip was part of the action being undone, so undoing it partially would leave the user in Custom with no sign of it.
- **Only the most recent move is undoable.** A new drag replaces any visible bar with a fresh one for the new move; the previous move's undo is gone. Do not build an undo stack.
- Once a bar times out there is no undo for that move. Nothing is lost: the user can drag the item back, or reselect their previous sort from the SORT sheet, since the custom order is retained either way.
- Announce it to screen readers as a live region, keep `Undo` focusable, and respect the platform's accessibility timeout setting if the app already does so elsewhere — 5 s is short for some users.

---

## 5 · The order model

```dart
class CustomOrder {
  /// Category IDs in user order, per section.
  final List<String> assetCategoryIds;
  final List<String> liabilityCategoryIds;

  /// Account IDs in user order, keyed by their owning category ID.
  final Map<String, List<String>> accountIdsByCategory;
}
```

### 5.1 The stored order is always the complete list

`CustomOrder` holds **every** category and account, including ones the filter is currently hiding. The Balance list renders a filtered subset, but the order you persist is the full one.

### 5.2 A drag is a relative move, not an index assignment

This is the part that must be exactly right.

The user drags within the *visible* list, but you are editing the *full* list. Never write the visible index into the stored order — with hidden items present, the two index spaces do not correspond, and hidden items would silently drift.

Resolve every drop by its **visible neighbour**:

```
moveWithinGroup(fullOrder, movedId, visibleTargetIndex, visibleIds):
    fullOrder.remove(movedId)

    // The visible item the moved row was dropped in front of.
    successorId = visibleTargetIndex < visibleIds.length
                    ? visibleIds[visibleTargetIndex]
                    : null

    if successorId == null:
        // Dropped at the end: place just after the last visible item,
        // so anything hidden after it keeps trailing.
        anchor = lastVisibleIdInGroup(visibleIds)
        insertAt = anchor == null ? fullOrder.length
                                  : fullOrder.indexOf(anchor) + 1
    else:
        insertAt = fullOrder.indexOf(successorId)

    fullOrder.insert(insertAt, movedId)
```

The rule in words: **the moved item is placed immediately before the visible item it was dropped in front of** — or immediately after the last visible item, if it was dropped at the end. Hidden items keep their positions relative to the visible neighbours they sit between, so unhiding one always returns it somewhere sensible rather than to the end of the list.

Worked example. Full order `[Spendable, Receivables, Investments, Valuables]`, with `Valuables` hidden, so the user sees `[Spendable, Receivables, Investments]`. The user drags `Investments` to the top. Result: `[Investments, Spendable, Receivables, Valuables]`. Unhiding `Valuables` puts it back at the end, exactly where it was relative to `Receivables`.

### 5.3 Applying the order

```
orderedCategories(section):
    known   = [id for id in section.orderList if id exists in data]
    unknown = [c for c in data.categoriesIn(section) if c.id ∉ section.orderList]
    return known.map(byId) + unknown            // unknown appended, in data order

orderedAccounts(category):
    list    = accountIdsByCategory[category.id] ?? []
    known   = [id for id in list if id ∈ category.accounts]
    unknown = [a for a in category.accounts if a.id ∉ list]
    return known.map(byId) + unknown
```

This "known, then unknown appended" shape gives you the required maintenance behavior for free:

| Event | Result |
|---|---|
| New account created | Appears **last in its own category**. |
| New category created | Appears **last in its own section**. |
| Account or category deleted | Drops out; everything else keeps its relative order. |
| Account moved between categories elsewhere in the app | It leaves the old category's list and appends to the new one's. **It never reorders itself into a foreign list.** |
| Stored ID matches nothing | Silently ignored; prune on load. |

**Never write an account ID into a category list it does not belong to.** Validate on load: any ID in `accountIdsByCategory[c]` whose account's parent is not `c` is dropped.

### 5.4 Persistence

- Persist through the existing layer, alongside the existing sort selection.
- Suggested keys: `balance_sort_mode` (extended with a `custom` value) and `balance_custom_order` (JSON).
- Restore before first paint — no flash of a different order.
- Scope per profile if the app supports multiple.

---

## 6 · Composition with the category filter

- **The two features are independent.** Custom order is stored for *all* categories and accounts, including hidden ones (§5.1).
- **Order first, filter second.** Apply `orderedCategories` / `orderedAccounts` to the full data, then remove the hidden items. Never the other way around.
- Un-hiding an item returns it to **exactly its stored position**, not to the end (§5.2).
- The filter's own bottom sheet lists categories and accounts in the **same order the Balance list uses**, so the two surfaces agree.
- Do not add reorder gestures to the filter sheet, and do not add filter switches to the Balance list.

---

## 7 · Edge cases

| Case | Required behavior |
|---|---|
| Category has one account | It can still be lifted; dragging is a no-op. Expose no rotor move actions for it. |
| Section has one visible category | Same: liftable, no-op, no rotor actions. |
| Category is collapsed | It drags as a whole; its accounts are simply not on screen. |
| Only one visible item in a group, others hidden | The drag is a no-op — do not let a move against hidden items reshuffle the stored order. |
| User drags while a search or filter is active | Allowed. Resolve by visible neighbour (§5.2). |
| Data refreshes mid-drag | Cancel the drag gracefully; do not apply a half-finished reorder. |
| Drag released outside the legal group | Drops at the clamped boundary position (§3). |
| Very long list | Auto-scroll near the viewport edges only within the current group's bounds. |
| Device text scaling at max | Rows grow; the drag target is the whole row, so hit targets scale with it. |
| Undo tapped after a data reload | Apply what still resolves; silently skip IDs that no longer exist. |

---

## 8 · Accessibility

The gesture is unreachable for anyone who cannot press and drag, so every reorderable row needs a non-gesture path:

```
Semantics(
  label: '{Row name}, position {i} of {n} in {group name}',
  customSemanticsActions: {
    'Move up':   () => moveWithinGroup(-1),
    'Move down': () => moveWithinGroup(1),
  },
)
```

- `Move up` at the first position and `Move down` at the last must be **absent from the rotor**, not present-and-failing.
- These actions go on the row itself — there is no handle to attach them to.
- Moving via the rotor follows all the same rules as dragging: same containment, same relative-position resolution, same switch to Custom, same undo bar.
- The undo bar is announced as a live region and `Undo` is reachable.

---

## 9 · Acceptance criteria

- [ ] SORT sheet shows five rows; the first four are untouched in label, order, and behavior; a divider separates `Custom`.
- [ ] `Custom` shows a subtitle, **no chevron**, and selecting it pushes no screen.
- [ ] No drag handle, grip glyph, or any other new permanent element appears anywhere on the Balance list.
- [ ] Tapping a category or account row still navigates exactly where it did before.
- [ ] A fast vertical flick scrolls the list and never lifts a row.
- [ ] Pressing and holding a row lifts it with haptic feedback and leaves a dashed placeholder.
- [ ] Dragging an account **inside** its category reorders it; the list keeps the new order after release.
- [ ] Dragging an account **toward another category** clamps at its own category's first/last slot — no re-parent, no bounce-back, no error.
- [ ] While dragging an account, every other category and the opposite section sit at 42% opacity; the owning category stays lit.
- [ ] Dragging a category reorders it within its section only; it cannot cross the `ASSETS`/`LIABILITIES` boundary, and the opposite section dims.
- [ ] A dragged category carries its accounts as one block, expanded or collapsed.
- [ ] The first drag while `Value — high to low` is active flips the selection to `Custom` **silently** — no message, banner, or toast text anywhere on screen.
- [ ] Every completed drag shows a bar containing `Undo` and no message text; the bar does not push or reflow the list.
- [ ] `Undo` returns the moved row to its exact previous position.
- [ ] When that drag also flipped the sort selection, `Undo` restores the previous selection as well.
- [ ] A new drag replaces any visible bar; only the most recent move is undoable and there is no undo stack.
- [ ] With `Valuables` hidden, dragging `Investments` to the top yields the stored order `[Investments, Spendable, Receivables, Valuables]`; un-hiding `Valuables` shows it last, not first.
- [ ] Selecting `Name — A to Z` then `Custom` again restores the saved custom order intact.
- [ ] A newly created account appears **last in its own category**; a new category appears **last in its section**.
- [ ] Deleting an account leaves the remaining order unchanged.
- [ ] Order survives force-quit and relaunch, with no flash of a different order on first paint.
- [ ] Screen reader can move every row up and down via custom actions; the actions are absent at the ends of a group.
- [ ] No analyzer warnings; **no domain-layer writes anywhere in the diff**.

**Tests to write:**

- unit tests for `orderedCategories` and `orderedAccounts` covering the new / deleted / stale-ID / foreign-ID cases;
- unit tests for the relative-move resolver in §5.2: a drop in front of a visible item with a hidden item between them; a drop at the end of a group whose last entries are hidden; a group with exactly one visible item (no-op);
- a unit test asserting `onReorder` clamps `newIndex` to the group's index range;
- a widget test asserting an account drag across a category boundary leaves parentage unchanged;
- a widget test asserting a tap navigates and a long press does not;
- a widget test asserting the first drag from an automatic sort flips the mode to Custom and that `Undo` restores both the order and the mode.

---

## 10 · Non-goals

- A separate arrange / reorder-mode screen
- Drag handles or any always-visible reorder affordance
- Any on-screen announcement that the sort mode changed to Custom
- A multi-step undo history
- Moving accounts between categories
- Reordering the `ASSETS` / `LIABILITIES` sections relative to each other
- Multiple saved arrangements or named layouts
- Reordering anything on the Ledger, Planner, or Insight tabs
- Any redesign of the existing Balance screen, SORT sheet, or filter feature

---

## Deliverable

List the files you created and modified, and flag any deviation from this spec and why.
