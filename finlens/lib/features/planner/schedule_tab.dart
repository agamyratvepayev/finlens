import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/repeat_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/ratio_bar.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/swipe_actions.dart';
import '../../shared/widgets/undo_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'archive_screen.dart';
import 'edit_task_screen.dart';
import 'mark_paid_sheet.dart';
import 'schedule_history_screen.dart';
import 'schedule_horizon.dart';
import 'task_actions.dart';
import 'task_detail_screen.dart';
import 'widgets/planner_empty.dart';

// ── One dated event in the list (§1) ────────────────────────────────────────

/// One dated event in the list: a task and the day it falls on (§1a). A one-off
/// has exactly one; a monthly series has as many as the window holds.
class _Occurrence {
  const _Occurrence(this.task, this.date, {required this.isNext});
  final Task task;

  /// The day this event falls on, at day granularity.
  final DateTime date;

  /// True for the series' live occurrence — [Task.dueDate] — the only one that
  /// can be paid, skipped or marked. Later turns are read-only (§2c).
  final bool isNext;
}

// ── A section of the list (§3) ──────────────────────────────────────────────

class _Section {
  _Section(this.label, this.occurrences, {this.isOverdue = false});
  final String label;
  final List<_Occurrence> occurrences;
  final bool isOverdue;

  /// Show the count and the ratio bar from two rows up (task 062 §3a): a
  /// one-row section never repeats its own number. No overdue exception — the
  /// Overdue section follows the same rule.
  bool get showsSectionTotal => occurrences.length > 1;
}

/// Orders a section by date, then priority (high first), then amount (§1c/§3.1).
int _compareOccurrences(_Occurrence a, _Occurrence b, AppStore store) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byPriority = b.task.priority.index.compareTo(a.task.priority.index);
  if (byPriority != 0) return byPriority;
  return store
      .taskAmountInBaseOn(b.task, b.date)
      .compareTo(store.taskAmountInBaseOn(a.task, a.date));
}

/// Every occurrence the list shows for [h] (§1b): one per overdue task at its own
/// due date, then every open task's in-horizon occurrences. Label-free, so the
/// breach lookup can reuse it.
List<_Occurrence> _occurrencesIn(AppStore store, DateRange h) {
  final startDay = DateTime(h.start.year, h.start.month, h.start.day);
  final endDay = DateTime(h.end.year, h.end.month, h.end.day);
  final out = <_Occurrence>[];
  // Overdue stays horizon-independent (§1b), each at its own due date.
  for (final t in store.overdueTasks) {
    final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    out.add(_Occurrence(t, d, isNext: true));
  }
  for (final t in store.openTasks) {
    final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    for (final d in t.occurrencesIn(startDay, endDay)) {
      out.add(_Occurrence(t, d, isNext: d == due));
    }
  }
  return out;
}

List<_Section> _buildSections(
    AppStore store, DateRange h, DateTime today, AppLocalizations l) {
  final sections = <_Section>[];
  final all = _occurrencesIn(store, h);

  final overdue = all
      .where((o) => o.task.daysUntilDue(today) < 0 && o.isNext)
      .toList()
    ..sort((a, b) => _compareOccurrences(a, b, store));
  if (overdue.isNotEmpty) {
    sections.add(_Section(l.schOverdue, overdue, isOverdue: true));
  }

  int daysUntil(_Occurrence o) {
    final d = DateTime(o.date.year, o.date.month, o.date.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.difference(t).inDays;
  }

  // The in-horizon occurrences (overdue ones already taken above), sorted once.
  final inHorizon = all.where((o) => daysUntil(o) >= 0).toList()
    ..sort((a, b) => _compareOccurrences(a, b, store));

  final todayOcc = inHorizon.where((o) => daysUntil(o) == 0).toList();
  if (todayOcc.isNotEmpty) sections.add(_Section(l.schToday, todayOcc));

  final weekOcc = inHorizon
      .where((o) => daysUntil(o) >= 1 && daysUntil(o) <= 7)
      .toList();
  if (weekOcc.isNotEmpty) sections.add(_Section(l.schThisWeek, weekOcc));

  // Everything beyond seven days is grouped under its own calendar month, so
  // the header is true by construction (§3.1).
  final later = inHorizon.where((o) => daysUntil(o) > 7).toList();
  final byMonth = <String, List<_Occurrence>>{};
  final order = <String>[];
  for (final o in later) {
    final key = '${o.date.year}-${o.date.month}';
    (byMonth[key] ??= (order..add(key), <_Occurrence>[]).$2).add(o);
  }
  for (final key in order) {
    final occ = byMonth[key]!;
    sections.add(_Section(monthLong(occ.first.date.month, l), occ));
  }
  return sections;
}

/// The single occurrence §4e's marker blames for the first breach: the first
/// pay-out occurrence on the breach day, or — when the breach is on day 0 from
/// overdue alone — the first overdue pay-out. Matched by (task id, date), never
/// by [Task] equality, since a series has many rows (§1d).
_Occurrence? _breachOccurrence(
    AppStore store, DateRange h, DateTime? breachDay) {
  if (breachDay == null) return null;
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  final all = _occurrencesIn(store, h)
    ..sort((a, b) => _compareOccurrences(a, b, store));
  for (final o in all) {
    if (o.task.isPayOut && sameDay(o.date, breachDay)) return o;
  }
  // A breach on day 0 from overdue alone: mark the first overdue pay-out.
  for (final o in all) {
    if (o.task.isPayOut && o.task.daysUntilDue(store.today) < 0) return o;
  }
  return null;
}

// ── The list (§3–§5) ────────────────────────────────────────────────────────

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({
    super.key,
    required this.store,
    required this.horizon,
    required this.onHorizonChange,
  });

  final AppStore store;
  final ScheduleHorizon horizon;
  final ValueChanged<ScheduleHorizon> onHorizonChange;

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final l = AppLocalizations.of(context);
    final today = store.today;
    final h = widget.horizon.range(today);

    // "No tasks at all" (§3), named so the header can gate on the same test:
    // openTasks is empty ⇒ overdue (a subset) is empty too. Paused tasks are not
    // in openTasks, so a paused-only store also reads as no tasks. Distinct from
    // `_nothingDue`, which fires on an empty section list within this horizon.
    final noTasksAtAll = store.openTasks.isEmpty;
    if (noTasksAtAll) {
      // No pill — the header + is the only action, named by the hint line; the
      // block centres below the tabs (§4). The gate is unchanged.
      return const PlannerEmptyState(tab: PlannerEmptyTab.schedule);
    }

    final sections = _buildSections(store, h, today, l);
    final breach = store.firstShortfall(h);
    final breachOcc = _breachOccurrence(store, h, breach?.day);

    // Done this month is fixed to the current calendar month (task 062 §4b):
    // the tab no longer reads or writes store.completedRange — History carries
    // the period control for every other range.
    final events =
        store.scheduleEvents(RangePreset.thisMonth.resolve(today));

    // The empty window (task 062 §1): open tasks exist but none falls inside
    // the horizon (overdue is always inside, so nothing is owed either). The
    // block centres in the free space above the Done section and names the
    // next payment; at very small sizes it scrolls instead of overflowing.
    if (sections.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: _EmptyWindow(
                      store: store,
                      horizon: widget.horizon,
                      onShow: (day) => widget
                          .onHorizonChange(ScheduleHorizon.until(day)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _DoneSection(store: store, events: events),
          const SizedBox(height: Insets.xxl),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
          for (final section in sections) ...[
            SectionLabel(
              section.label,
              // The count, not the figures (task 062 §3b): the total moved
              // under the label as a ratio bar with its ends on the gutters.
              trailing: section.showsSectionTotal
                  ? Text(
                      l.schItemsCount(section.occurrences.length),
                      style: AppText.label.copyWith(letterSpacing: 0.3),
                    )
                  : null,
            ),
            if (section.showsSectionTotal) _sectionBar(l, section),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              // The swipe strip paints to the row's edge; clip it to the card's
              // rounded corners (§7).
              child: AppCard(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < section.occurrences.length; i++) ...[
                      if (i > 0) const RowDivider(indent: 51),
                      _OccurrenceRow(
                        store: store,
                        occurrence: section.occurrences[i],
                        isBreach: _isBreach(section.occurrences[i], breachOcc),
                      ),
                      // The shortfall marker sits directly under the row it blames
                      // (§4e), inside the card so nothing paints outside its
                      // corners.
                      if (breach != null &&
                          _isBreach(section.occurrences[i], breachOcc))
                        _ShortfallMarker(store: store, breach: breach),
                    ],
                  ],
                ),
              ),
            ),
          ],
        _DoneSection(store: store, events: events),
      ],
    );
  }

  /// Matches an occurrence to the breach by identity — (task id, date) — never by
  /// [Task] equality, since one series has many rows (§1d).
  bool _isBreach(_Occurrence o, _Occurrence? breach) =>
      breach != null && o.task.id == breach.task.id && o.date == breach.date;

  /// A section's total as a proportion, not a floating pair of numbers
  /// (task 062 §3c): a 2 pt bar between the label and the card, its two
  /// segments flexed to what leaves and what lands, and the unsigned figures
  /// on the gutters — `{out} out` left, `{in} in` right. The words carry the
  /// direction; there is no sign. A side with no amount is omitted but the
  /// other keeps its edge; a section with no amounts at all draws no block.
  Widget _sectionBar(AppLocalizations l, _Section section) {
    final store = widget.store;
    var out = 0.0, income = 0.0;
    for (final o in section.occurrences) {
      // Per occurrence (task 064 §7c): an overridden month totals as itself.
      final amt = store.taskAmountInBaseOn(o.task, o.date);
      if (o.task.isPayOut) {
        out += amt;
      } else {
        income += amt;
      }
    }
    if (out <= 0 && income <= 0) return const SizedBox.shrink();

    const figStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RatioBar(
            left: out,
            right: income,
            leftColor: AppColors.negative,
            rightColor: AppColors.positive,
            height: 2,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (out > 0)
                Text(
                  l.schAmountOut(money(out, masked: store.masked)),
                  style: figStyle.copyWith(color: AppColors.amountChildNeg),
                )
              else
                const SizedBox.shrink(),
              if (income > 0)
                Text(
                  l.schAmountIn(money(income, masked: store.masked)),
                  style: figStyle.copyWith(
                      color: AppColors.positive.withValues(alpha: 0.85)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── The empty window (task 062 §1) ───────────────────────────────────────────

/// Open tasks exist, none inside the horizon: name the next payment and offer
/// one button that shows it. With no next occurrence at all only the icon and
/// the title render.
class _EmptyWindow extends StatelessWidget {
  const _EmptyWindow({
    required this.store,
    required this.horizon,
    required this.onShow,
  });

  final AppStore store;
  final ScheduleHorizon horizon;
  final ValueChanged<DateTime> onShow;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = store.today;
    final h = horizon.range(today);
    final next = store.nextOccurrenceAfter(h.end);

    final title = switch (horizon.preset) {
      SchedulePreset.thisWeek => l.schEmptyThisWeek,
      SchedulePreset.next30 => l.schEmptyNext30,
      SchedulePreset.thisMonth => l.schEmptyThisMonth,
      SchedulePreset.next3Months => l.schEmptyNext3Months,
      null => l.schEmptyThrough(dayMonth(horizon.customEnd!, l)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.positive, 0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 34, color: AppColors.positive),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 25 / 21,
              color: AppColors.textPrimary,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 8),
            Text(
              _nextLine(l, next),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 18 / 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            Semantics(
              button: true,
              child: Material(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(Radii.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  // Nothing is paid, created or scrolled (§1d): the horizon
                  // widens to the next occurrence's own day and the tab
                  // re-renders with it in its first section.
                  onTap: () => onShow(next.date),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: Text(
                      l.schShowNextPayment,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// `Next: {name} on {date} · {amount}` — the date via [dayMonth], with the
  /// year only when it is not this year; the amount unsigned, in the task's
  /// own currency (its account's), masked mode respected. Same-day ties read
  /// `and {count} more` with the first task's amount.
  String _nextLine(
      AppLocalizations l, ({Task task, DateTime date, int sameDay}) next) {
    final task = next.task;
    final account = store.accountById(task.linkedAccountId);
    final amount = money(task.amountOn(next.date).abs(),
        currency: account?.currency, masked: store.masked);
    final date = next.date.year == store.today.year
        ? dayMonth(next.date, l)
        : dayMonthYear(next.date, l);
    return next.sameDay > 0
        ? l.schNextLineMore(task.title, next.sameDay, date, amount)
        : l.schNextLine(task.title, date, amount);
  }
}

// ── The row — one occurrence (§2) ────────────────────────────────────────────

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow(
      {required this.store, required this.occurrence, required this.isBreach});

  final AppStore store;
  final _Occurrence occurrence;
  final bool isBreach;

  Task get task => occurrence.task;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final payOut = task.isPayOut;
    final color = payOut ? AppColors.negative : AppColors.positive;
    final today = store.today;
    final todayDay = DateTime(today.year, today.month, today.day);
    final overdue = occurrence.date.isBefore(todayDay);
    final account = store.accountById(task.linkedAccountId)?.name;

    final row = InkWell(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
      ),
      child: Padding(
        // 3 pt vertical (§2d): the 44 pt tick still drives the row envelope to
        // ~50 pt; the breach tint and left border are gone (§2e).
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          children: [
            IconTile(task.icon, color: color, size: 28),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      AmountText(
                        // This occurrence's own amount (task 064 §7c).
                        task.amountOn(occurrence.date),
                        kind: AmountKind.magnitude,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()]),
                        color: color,
                        forceDecimals:
                            task.amountOn(occurrence.date).abs() % 1 != 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  _subtitle(l, overdue, account),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // The live occurrence is an empty ring that opens the confirm sheet;
            // a later turn is a dashed, non-tappable ring (§2b/§2c).
            if (occurrence.isNext)
              _MarkPaidRing(store: store, task: task)
            else
              const _DashedRing(),
          ],
        ),
      ),
    );

    final semanticRow = Semantics(
      container: true,
      button: true,
      label: _semantics(l, payOut, overdue, account),
      child: ExcludeSemantics(child: row),
    );

    // Edit · Skip · Delete (§7). Skip only on the live occurrence of a recurring
    // series — a one-off has none, a later turn nothing to skip yet.
    final canSkip = occurrence.isNext && task.isRecurring;
    final actions = <SwipeActionItem>[
      SwipeActionItem(
        icon: Icons.edit_outlined,
        label: l.actionEdit,
        color: AppColors.surfaceHigh,
        onTap: () => _edit(context),
      ),
      if (canSkip)
        SwipeActionItem(
          icon: Icons.skip_next_rounded,
          label: l.actionSkip,
          color: AppColors.info,
          onTap: () => _skip(context),
        ),
      SwipeActionItem(
        icon: Icons.delete_outline_rounded,
        label: l.actionDelete,
        color: AppColors.negative,
        onTap: () => _delete(context),
      ),
    ];

    // A swipe-only action is unreachable to a screen reader; expose it as a
    // custom action too, exactly as the account picker does.
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: l.actionEdit): () => _edit(context),
        if (canSkip)
          CustomSemanticsAction(label: l.actionSkip): () => _skip(context),
        CustomSemanticsAction(label: l.actionDelete): () => _delete(context),
      },
      child: SwipeActions(actions: actions, child: semanticRow),
    );
  }

  /// §6c — the swipe Skip gets the same undo bar as Mark as done.
  void _skip(BuildContext context) {
    final l = AppLocalizations.of(context);
    final skip = store.skipTask(task);
    showUndoBar(
      context,
      message: l.etSkippedNext(dayMonth(task.dueDate, l)),
      onUndo: () => store.undoSkipTask(skip),
    );
  }

  void _edit(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => EditTaskScreen(taskId: task.id)),
    );
  }

  /// Swipe Delete follows the ••• menu's rule (task 065 §3c — no UI soft-
  /// deletes any more): a series with history is archived (it can't be hard-
  /// deleted in one step); one without is removed for good, with an undo bar.
  Future<void> _delete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final hasHistory = store.paymentsForTask(task.id).isNotEmpty;
    if (hasHistory) {
      final ok = await confirmArchiveTask(context, store, task);
      if (ok) store.archiveTask(task);
      return;
    }
    final ok = await confirmDeleteTask(context, store, task);
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final snapshot = store.deleteTaskForGood(task);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.tdDeletedBar(task.title)),
        duration: undoBarWindow,
        action: SnackBarAction(
          label: l.actionUndo,
          onPressed: () => store.undoDeleteForGood(snapshot),
        ),
      ));
  }

  /// One unbreakable line, the repeat glyph moved to the **front** so truncation
  /// cuts the account name, never a dangling `mo…` (§2a):
  /// `⟳␣␣{date}[ · N days][ · account][ · won't cover]`. No frequency word — the
  /// long "on the 7th" form lives on the Task detail screen.
  Widget _subtitle(AppLocalizations l, bool overdue, String? account) {
    final subColor = overdue ? AppColors.negative : AppColors.textSecondary;
    // Overdue paints the whole line negative, glyph included (§D.3); otherwise
    // the ⟳ keeps its tertiary tone.
    final glyphColor = overdue ? AppColors.negative : AppColors.textTertiary;
    final base = AppText.rowSubtitle
        .copyWith(fontSize: 11.5, height: 1.15, color: subColor);

    final date = dayMonth(occurrence.date, l);
    final late =
        overdue ? l.schOverdueDays(-task.daysUntilDue(store.today)) : null;

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          if (task.isRecurring) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.repeat_rounded, size: 10.5, color: glyphColor),
            ),
            const TextSpan(text: '  '),
          ],
          TextSpan(text: date),
          if (late != null) TextSpan(text: ' · $late'),
          if (account != null) TextSpan(text: ' · $account'),
          if (isBreach)
            TextSpan(
              text: ' · ${l.schWontCover}',
              style: base.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.warning),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _semantics(
      AppLocalizations l, bool payOut, bool overdue, String? account) {
    final amount = formatAmount(task.amountOn(occurrence.date), null,
        kind: AmountKind.magnitude, masked: store.masked);
    final parts = <String>[
      task.title,
      '${payOut ? l.schSemPayingOut : l.schSemComingIn} $amount',
      '${l.schSemDue} ${dayMonth(occurrence.date, l)}',
      if (overdue) l.schDaysLate(-task.daysUntilDue(store.today)),
      if (account != null)
        '${payOut ? l.schSemFrom : l.schSemInto} $account',
      if (task.isRecurring)
        l.schSemRepeats(repeatCadenceLabel(
            task.repeats, task.weekdays, task.daysOfMonth, task.dueDate, l)),
      if (isBreach) l.schWontCover,
    ];
    return parts.join(', ');
  }
}

/// The mark-paid ring — an empty 24 pt circle inside a ≥ 44 pt tap target
/// (§2b). A ✓ on an unpaid row reads as done, so the ring stays empty; the tap
/// opens the confirm sheet and never writes on its own.
class _MarkPaidRing extends StatelessWidget {
  const _MarkPaidRing({required this.store, required this.task});

  final AppStore store;
  final Task task;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final result = await showMarkPaidSheet(context, task: task);
        if (result != null && context.mounted) {
          showMarkPaidUndoBar(context, store, result);
        }
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.textTertiary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// A later occurrence of a series (§2c): a dashed, non-tappable 24 pt ring in
/// the same 44 pt slot. Not a button — there is nothing to pay until the series
/// reaches it.
class _DashedRing extends StatelessWidget {
  const _DashedRing();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _DashedRingPainter()),
        ),
      ),
    );
  }
}

/// Draws a 4-on/3-off dashed circle in [AppColors.surfaceHigh], 1.5 pt (§2c),
/// by hand rather than pulling in a package.
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 1.5) / 2;
    const dash = 4.0, gap = 3.0;
    final circumference = 2 * math.pi * radius;
    final step = (dash + gap) / radius; // angular step per dash+gap
    var a = 0.0;
    final end = 2 * math.pi;
    // Guard against pathological radii producing an unbounded loop.
    if (circumference <= 0) return;
    while (a < end) {
      final sweep = (dash / radius).clamp(0.0, end - a);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a,
        sweep,
        false,
        paint,
      );
      a += step;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) => false;
}

/// The shortfall marker (§4e/§D.4): a labelled hairline `Spendable below 0 from
/// {day} ——— −{amount}`, both ends [AppColors.warning], drawn inside the card
/// directly under the row that causes the breach.
class _ShortfallMarker extends StatelessWidget {
  const _ShortfallMarker({required this.store, required this.breach});

  final AppStore store;
  final ({DateTime day, double amount}) breach;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = AppText.caption.copyWith(
        fontSize: 11.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.warning);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
      child: Row(
        children: [
          Flexible(
            child: Text(l.schSpendableBelowFrom(dayMonth(breach.day, l)),
                style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
                height: 1,
                color: AppColors.warning.withValues(alpha: 0.45)),
          ),
          const SizedBox(width: 8),
          AmountText(
            -breach.amount,
            style: style,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

// ── Done this month — one thin row at the end (task 062 §4) ──────────────────

/// The tab's last section: a DONE THIS MONTH label and a single 34 pt row that
/// opens History. Always the current calendar month — History's own period
/// control is where another period is chosen. Transfers are counted in the
/// `{n} done` text but never summed: a transfer moves the user's own money and
/// is neither a gain nor a loss (§5). The row's figures carry direction by
/// colour alone — the user's explicit choice for this one row.
class _DoneSection extends StatelessWidget {
  const _DoneSection({required this.store, required this.events});

  final AppStore store;
  final List<ScheduleEvent> events;

  void _openHistory(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const ScheduleHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    var done = 0, skipped = 0;
    var red = 0.0, green = 0.0;
    for (final e in events) {
      switch (e.outcome) {
        case ScheduleOutcome.paid:
          done++;
          // Counted, never summed (§5): paid covers transfer tasks too.
          if (!e.task.isTransfer) red += e.amountInBase;
        case ScheduleOutcome.received:
          done++;
          green += e.amountInBase;
        case ScheduleOutcome.skipped:
        case ScheduleOutcome.cancelled:
          // Cancelled counts as skipped in the row's fallback text.
          skipped++;
      }
    }
    final text = events.isEmpty
        ? l.schNothingDoneThisMonth
        : done > 0
            ? l.schDoneCount(done)
            : l.schSkippedCount(skipped);
    final textColor =
        events.isEmpty ? AppColors.textTertiary : AppColors.chipText;

    const figStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    final row = Row(
      children: [
        const Icon(Icons.check_circle_outline_rounded,
            size: 15, color: AppColors.positive),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
          ),
        ),
        if (red > 0)
          AmountText(red,
              kind: AmountKind.magnitude,
              style: figStyle,
              color: AppColors.negative),
        if (red > 0 && green > 0) const SizedBox(width: 8),
        if (green > 0)
          AmountText(green,
              kind: AmountKind.magnitude,
              style: figStyle,
              color: AppColors.positive),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded,
            size: 14, color: AppColors.formChevron),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          l.schDoneThisMonth,
          // Top 22 (Insets.lg + 6, §4a). The bottom gives back the 5 pt the
          // 44 pt hit area adds above the 34 pt card, so the visual label→card
          // gap stays the standard Insets.sm.
          padding: const EdgeInsets.fromLTRB(
              Insets.gutter, Insets.lg + 6, Insets.gutter, Insets.sm - 5),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          // The tap target is 44 while the card stays a visible 34 (§4c): the
          // opaque hit area is the 44 pt box, the card centred inside it.
          child: Semantics(
            button: true,
            label: '${l.schDoneThisMonth} $text',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openHistory(context),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: AppCard(
                    radius: Radii.md,
                    child: Container(
                      height: 34,
                      padding:
                          const EdgeInsets.symmetric(horizontal: Insets.md),
                      child: row,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (store.pausedTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.sm, Insets.gutter, 0),
            child: InkWell(
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const ArchiveScreen()),
              ),
              child: Text(
                l.schPausedArchiveLine(store.pausedTasks.length),
                style: AppText.caption.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Schedule event row — shared by the completed section and History (§5.1) ──

class ScheduleEventRow extends StatelessWidget {
  const ScheduleEventRow({super.key, required this.store, required this.event});

  final AppStore store;
  final ScheduleEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final task = event.task;
    final didNot = event.didNotHappen;
    final color = event.outcome == ScheduleOutcome.received
        ? AppColors.positive
        : (event.outcome == ScheduleOutcome.paid
            ? AppColors.negative
            : AppColors.textTertiary);

    final when = _whenLabel(context, l);
    final account = event.txn == null
        ? null
        : store
            .accountById(event.txn!.type == TxnType.income
                ? event.txn!.toRef
                : event.txn!.fromRef)
            ?.name;

    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            IconTile(task.icon,
                color: didNot ? AppColors.textTertiary : color, size: 28),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(
                    _subtitle(l, when, account),
                    style: AppText.rowSubtitle
                        .copyWith(fontSize: 11.5, height: 1.15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              money(
                  didNot
                      ? store.taskAmountInBaseOn(task, event.date)
                      : event.amountInBase,
                  masked: store.masked,
                  forceDecimals: (didNot
                              ? store.taskAmountInBaseOn(task, event.date)
                              : event.amountInBase) %
                          1 !=
                      0),
              style: AppText.amount.copyWith(
                fontSize: 14.5,
                color: didNot ? AppColors.textTertiary : color,
                decoration: didNot ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(width: 6),
            _badge(),
          ],
        ),
      ),
    );
  }

  String _whenLabel(BuildContext context, AppLocalizations l) {
    final today = StoreScope.read(context).today;
    final d = event.date;
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return l.schToday;
    }
    return dayMonth(d, l);
  }

  String _subtitle(AppLocalizations l, String when, String? account) {
    switch (event.outcome) {
      case ScheduleOutcome.paid:
        return l.schPaidLine(when, account ?? '—');
      case ScheduleOutcome.received:
        return l.schReceivedLine(when, account ?? '—');
      case ScheduleOutcome.skipped:
        return l.schSkippedLine(when);
      case ScheduleOutcome.cancelled:
        return l.schCancelledLine(when);
    }
  }

  Widget _badge() {
    switch (event.outcome) {
      case ScheduleOutcome.paid:
      case ScheduleOutcome.received:
        return _circle(AppColors.tint(AppColors.positive, 0.20),
            Icons.check_rounded, AppColors.positive);
      case ScheduleOutcome.skipped:
        return _circle(AppColors.tint(AppColors.textSecondary, 0.16),
            Icons.skip_next_rounded, AppColors.textSecondary);
      case ScheduleOutcome.cancelled:
        return _circle(AppColors.tint(AppColors.textSecondary, 0.16),
            Icons.close_rounded, AppColors.textSecondary);
    }
  }

  Widget _circle(Color bg, IconData icon, Color fg) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: Icon(icon, size: 16, color: fg),
      );

  void _open(BuildContext context) {
    // A paid/received row opens the undo sheet — a completed payment can be undone
    // at any time, not only in the snackbar's five seconds (§6b/§6e). A
    // skipped/cancelled row has no entry, so it opens the Task detail (§5.1).
    if (event.txn != null) {
      showUndoPaymentSheet(context, store, event);
    } else {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: event.task.id)),
      );
    }
  }
}
