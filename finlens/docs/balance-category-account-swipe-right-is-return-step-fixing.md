# Balance — Category & Account Swipe Right is Return Step Fixing

> Implementation prompt (Flutter)

## Role and context

**FinLens**, a Flutter personal-finance app. Two screens are in scope, both reached from the **Balance** tab:

- **Category detail** — `‹ Balance` back label, category name and total, a period chip, an `11 transactions` row with tool buttons, day-grouped transaction rows, a pinned `+ Add expense`.
- **Account detail** — the same shape for a single account.

Today the only way back to Balance is tapping the `‹ Balance` label. There is no swipe gesture. This adds one.

Transaction rows on both screens already reveal an action menu (`Edit · Copy · Move · Delete`) when dragged **right to left**. The new gesture uses the same direction, so §2 is the part that must be exactly right.

**Match the project's existing conventions.** Use the navigation, routing, and animation approach already there. Do not introduce a new navigation package. The Dart below is a behavioral specification, not code to paste.

---

## Hard boundary

Strictly additive. Do **not**:

- remove or restyle the `‹ Balance` back label — the gesture is an addition, never a replacement;
- change the existing row action menu: its direction, its four actions, their order, their widths, or when they trigger;
- change any screen's layout, colors, type scale, row heights, or padding;
- change the forward (push) transition;
- change or disable the platform's own system back gesture — leave whatever it does today untouched;
- touch the Ledger, Planner, or Insight tabs.

If something existing looks wrong, **report it — do not change it.**

---

## 1 · The gesture

**Press and hold, then drag right to left, to go back one screen.**

| Phase | Behavior |
|---|---|
| Touch down | Nothing yet. |
| Hold ~**300 ms** without moving more than ~8 pt | The gesture arms. Fire a **light haptic** — this is the only signal that the drag will now navigate rather than open a row menu. Match the app's existing long-press duration and haptic if it has one. |
| Drag left ≥ **12 pt** after arming | The screen begins following the finger horizontally, 1:1. |
| Release past **40%** of screen width, or with horizontal velocity > **700 pt/s** | The screen completes its exit and pops. |
| Release before that | The screen animates back to rest over **220 ms**, decelerating. Nothing pops. |

The gesture starts **anywhere on the screen body** — it is not restricted to an edge. The hold is what makes it unambiguous, not the starting position.

Vertical movement during the hold cancels it: if the finger moves more than ~8 pt vertically before arming, treat the gesture as a scroll and let the list handle it normally.

---

## 2 · Conflict with the row action menu — the critical part

Both gestures drag right-to-left. **The hold is the discriminator, and it must be resolved before either gesture claims the pointer.**

| Gesture | Result |
|---|---|
| Drag left **immediately**, no hold | Row action menu opens, exactly as today. |
| Hold ~300 ms, **then** drag left | Screen pops. The row underneath must **not** open its menu, not even partially. |

Requirements:

- Once the back gesture arms, **the row's slidable must be cancelled for that pointer** and must not animate at all. A row that slides open by 10 pt and snaps shut while the screen is also moving is the failure mode to watch for.
- If a row's action menu is **already open**, the first held drag **closes the menu and does not pop.** Getting out of an open menu must not also throw the user off the screen. The second held drag pops.
- Use the gesture arena deliberately — a `LongPressDraggable`-style recognizer, or a custom `OneSequenceGestureRecognizer` that declares victory only after the hold, so the slidable's horizontal drag recognizer loses cleanly. Do not implement this by putting an absorbing overlay on top of the rows.
- Dragging left on the screen's **non-row areas** (the header, the period chip, empty space below the list) follows the same rule: hold first, then drag.

---

## 3 · The transition

The current screen **translates left**, following the finger, and exits to the left. The previous screen sits beneath it, revealed as it leaves.

> **This is deliberate and is not a bug.** A pushed screen enters from the right; under this gesture it leaves to the left, so navigation reads as one continuous leftward motion rather than a there-and-back. Do **not** "correct" it to slide right, do **not** invert the finger-to-screen mapping, and do **not** change the push transition to match. The screen always moves the same direction as the finger.

- The previous screen may take a subtle parallax offset if the app already uses one on its transitions; otherwise it stays static beneath.
- A scrim or shadow on the leaving screen's trailing edge is optional — only if the app already does this elsewhere.
- The pop animation completes at the same duration the app already uses for route transitions.
- If the drag is released mid-way, the previous screen's parallax reverses in step with the snap-back.

---

## 4 · Returning to Balance

Popping must reveal Balance **exactly as the user left it**. Nothing may reset.

- Which categories are **expanded** stays as it was — in the reference state, `Spendable`, `Receivables`, `Investments`, and `Valuables` are all expanded and must still be.
- **Scroll offset** is preserved. The list must not jump to the top.
- The **filter**, the **sort selection**, and any **custom order** are preserved.
- The eye/visibility toggle and the period pill keep their state.

If the previous route is being rebuilt from scratch on pop, that is the bug — keep it alive (`PageStorageKey`, an `AutomaticKeepAlive`, or whatever the project already uses) rather than restoring state manually. **Report which mechanism you used.**

---

## 5 · Accessibility

- The `‹ Balance` label remains the primary, discoverable way back. The gesture never becomes the only route out of a screen.
- The gesture is **not** exposed to screen readers as an action — screen-reader users navigate with the back button, which already carries its own label.
- With a screen reader running, the hold-then-drag gesture is intercepted by the accessibility layer anyway; do not fight it or try to re-implement it under VoiceOver/TalkBack.
- Respect the system "reduce motion" setting: when it is on, skip the follow-the-finger animation and pop directly on a completed gesture.

---

## 6 · Edge cases

| Case | Required behavior |
|---|---|
| A row's action menu is open | First held drag closes it, does not pop. Second held drag pops. |
| Drag begins on the pinned `+ Add expense` button | Held drag pops; a plain tap still adds an expense. The button must not fire on the drag. |
| Drag begins on the period chip or a tool button | Same: held drag pops, tap still activates the control. |
| Drag armed, then finger moves vertically | The screen follows only the horizontal component; do not let the route drift vertically. |
| Drag released exactly at the threshold | Commit. Do not leave the screen parked mid-transition. |
| A bottom sheet is open (sort, filter, period) | The gesture is **inactive**. The sheet's own dismissal handles that layer. |
| A dialog or confirmation is showing | Inactive. |
| Screen is the root of the tab | Inactive — nothing to pop to. Do not pop the tab itself. |
| Rapid repeated gestures | Only one pop per gesture; ignore input while a pop animation is running. |
| Data reload lands mid-drag | The drag continues; the pop is unaffected. |

---

## 7 · Acceptance criteria

- [ ] On the category detail screen, holding ~300 ms then dragging left pops back to Balance.
- [ ] The same works on the account detail screen.
- [ ] A **quick** left drag on a transaction row still opens `Edit · Copy · Move · Delete`, unchanged.
- [ ] A **held** left drag over a transaction row pops the screen and the row's menu does **not** open or animate at all.
- [ ] A light haptic fires when the gesture arms.
- [ ] With a row menu already open, the first held drag closes it without popping; the second pops.
- [ ] Releasing before 40% snaps the screen back over ~220 ms and does not pop.
- [ ] The screen moves in the same direction as the finger throughout, and exits to the left.
- [ ] The `‹ Balance` label still works and is unchanged.
- [ ] Returning to Balance preserves expanded categories, scroll offset, filter, sort, and custom order.
- [ ] The gesture is inactive while a bottom sheet or dialog is open.
- [ ] Vertical scrolling of the transaction list is unaffected — a normal scroll never arms the gesture.
- [ ] With "reduce motion" enabled, a completed gesture pops without the follow-the-finger animation.
- [ ] The platform's own system back gesture behaves exactly as it did before this change.
- [ ] No analyzer warnings.

**Tests to write:**

- widget test: a horizontal drag without a preceding hold opens the row's action menu and does not pop;
- widget test: a long-press followed by a horizontal drag pops the route and leaves the row's slidable closed;
- widget test: a drag released at 20% of width does not pop; at 60% it does;
- widget test: with a row menu open, the first held drag closes it and the route is still on top;
- widget test: a vertical drag scrolls the list and never arms the gesture;
- widget test: with a bottom sheet open, a held drag does not pop;
- widget test: after popping, the Balance list reports the same scroll offset and the same expanded categories as before the push.

---

## 8 · Non-goals

- A left-edge, left-to-right back swipe
- Removing or restyling the `‹ Balance` label
- Changing the row action menu in any way
- Changing the forward push transition
- Reversing the exit direction so the screen slides right
- Extending the gesture to the Ledger, Planner, or Insight tabs
- Any redesign of the screens involved

---

## Deliverable

List the files you created and modified. Report: how you resolved the gesture arena between the back gesture and the row slidable; which mechanism preserves the Balance screen's state across the pop; whether the platform's system back gesture is currently enabled on these routes; and any place where the 300 ms hold felt wrong in testing. Flag any deviation from this spec and why.
