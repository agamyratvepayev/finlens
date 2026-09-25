import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/repeat_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/range_picker_sheet.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/swipe_actions.dart';
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

  /// Print the out/in figures only when the reader cannot add them up at a
  /// glance — three rows or more (§3b). No overdue exception any more: a section
  /// of one or two rows never repeats its own numbers.
  bool get showsSectionTotal => occurrences.length > 2;
}

/// Orders a section by date, then priority (high first), then amount (§1c/§3.1).
int _compareOccurrences(_Occurrence a, _Occurrence b, AppStore store) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byPriority = b.task.priority.index.compareTo(a.task.priority.index);
  if (byPriority != 0) return byPriority;
  return store.taskAmountInBase(b.task).compareTo(store.taskAmountInBase(a.task));
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
  bool _completedExpanded = false;

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

    // The completed section ranges over the past with its own stored control,
    // wholly independent of the forward horizon (§B2).
    final completedRange = store.completedRange;
    final events = store.scheduleEvents(completedRange);

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        if (sections.isEmpty)
          _nothingDue(context, l)
        else
          for (final section in sections) ...[
            SectionLabel(
              section.label,
              // The figures end where the row amounts do — 62 pt from the screen
              // edge (12 pad + 44 tick + 6 gap), so 42 past the gutter (§3c).
              trailing: section.showsSectionTotal
                  ? Padding(
                      padding: const EdgeInsets.only(right: 42),
                      child: _sectionFigures(section),
                    )
                  : null,
            ),
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
        _CompletedSection(
          store: store,
          events: events,
          range: completedRange,
          expanded: _completedExpanded,
          onToggle: () =>
              setState(() => _completedExpanded = !_completedExpanded),
          onPickRange: _pickCompletedRange,
        ),
      ],
    );
  }

  /// Opens the shared range-picker sheet for the completed section and stores the
  /// choice (§B1, §B3). A preset persists as its preset; a custom range as its
  /// dates. `disableFuture` is the sheet's default — completed events are past.
  Future<void> _pickCompletedRange() async {
    final store = widget.store;
    final picked = await showRangePickerSheet(
      context,
      current: store.completedRange,
      hasData: (day) => store
          .scheduleEvents(DateRange(
            DateTime(day.year, day.month, day.day),
            DateTime(day.year, day.month, day.day, 23, 59, 59, 999),
          ))
          .isNotEmpty,
      countBetween: (from, to) =>
          store.scheduleEvents(DateRange(from, to)).length,
    );
    if (picked == null || !mounted) return;
    store.setCompletedRange(picked);
  }

  /// Matches an occurrence to the breach by identity — (task id, date) — never by
  /// [Task] equality, since one series has many rows (§1d).
  bool _isBreach(_Occurrence o, _Occurrence? breach) =>
      breach != null && o.task.id == breach.task.id && o.date == breach.date;

  /// A section prints what leaves and what lands, never a net (§3a): `−out` in
  /// negative at 85 %, `+in` in positive at 85 %, 8 pt apart. A side with no
  /// amount is omitted entirely.
  Widget _sectionFigures(_Section section) {
    var out = 0.0, income = 0.0;
    for (final o in section.occurrences) {
      final amt = widget.store.taskAmountInBase(o.task);
      if (o.task.isPayOut) {
        out += amt;
      } else {
        income += amt;
      }
    }
    final style = AppText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (out > 0)
          AmountText(
            -out,
            style: style,
            color: AppColors.negative.withValues(alpha: 0.85),
          ),
        if (out > 0 && income > 0) const SizedBox(width: 8),
        if (income > 0)
          AmountText(
            income,
            showSign: true,
            style: style,
            color: AppColors.positive.withValues(alpha: 0.85),
          ),
      ],
    );
  }

  Widget _nothingDue(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: Insets.gutter),
      child: Column(
        children: [
          Center(
            child: Text(l.schNothingInHorizon,
                style: AppText.body.copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: () => widget.onHorizonChange(
                const ScheduleHorizon.preset(SchedulePreset.next3Months)),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentLight),
            child: Text(l.schShowNext3Months),
          ),
        ],
      ),
    );
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
                        task.expectedAmount,
                        kind: AmountKind.magnitude,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()]),
                        color: color,
                        forceDecimals: task.expectedAmount.abs() % 1 != 0,
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
          onTap: () => store.skipTask(task),
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
          CustomSemanticsAction(label: l.actionSkip): () =>
              store.skipTask(task),
        CustomSemanticsAction(label: l.actionDelete): () => _delete(context),
      },
      child: SwipeActions(actions: actions, child: semanticRow),
    );
  }

  void _edit(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => EditTaskScreen(taskId: task.id)),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDeleteTask(context, store, task);
    if (ok) store.deleteTask(task);
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
    final amount = formatAmount(task.expectedAmount, null,
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

// ── Completed section, in-tab (§5) ──────────────────────────────────────────

class _CompletedSection extends StatelessWidget {
  const _CompletedSection({
    required this.store,
    required this.events,
    required this.range,
    required this.expanded,
    required this.onToggle,
    required this.onPickRange,
  });

  final AppStore store;
  final List<ScheduleEvent> events;
  final DateRange range;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final headerStyle = AppText.label.copyWith(color: AppColors.textSecondary);
    final hasEvents = events.isNotEmpty;

    // The chosen range's own name — a preset by its preset label, a custom range
    // by its compressed day-range label — folded into "… completed" (§B1).
    final rangeLabel = range.preset?.label(l) ??
        range.label(StoreScope.of(context).today, l);
    final headerText = l.schCompletedIn(rangeLabel).toUpperCase();

    final count = Text(l.schItemsCount(events.length), style: headerStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Vertical whitespace comes from the two ≥44pt tap targets below, not
          // the outer padding — keeping the header near its old height (§B4).
          padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xs, Insets.gutter, 0),
          child: Row(
            children: [
              // Left: the period control — a real choice (§B1). Accent, so it
              // reads as a chooser, not a toggle.
              Expanded(
                child: InkWell(
                  onTap: onPickRange,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            headerText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.63, // 0.06em @ 10.5pt
                              color: AppColors.accentLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: AppColors.accentLight),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              // Right: the count. Grey, so it reads as expand/collapse rather
              // than competing with the accent picker (§B4). At zero items there
              // is nothing to open — no chevron, and the count is not tappable.
              if (hasEvents)
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        count,
                        const SizedBox(width: Insets.xs),
                        AnimatedRotation(
                          turns: expanded ? 0.25 : 0.0,
                          duration: const Duration(milliseconds: 160),
                          child: const Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                count,
            ],
          ),
        ),
        if (expanded && hasEvents) _expanded(context, l),
        if (!hasEvents) _emptyLines(context, l),
        if (store.pausedTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, 0),
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

  /// Zero items: one line (§5/§D.5). A sentence, then a `History ›` link that
  /// opens the History screen — not the period sheet: changing the period from an
  /// empty state is a surprise, and History carries its own period control.
  Widget _emptyLines(BuildContext context, AppLocalizations l) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, 0),
      child: Row(
        children: [
          Flexible(
            child: Text(
              l.schCompletedEmpty,
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const ScheduleHistoryScreen()),
            ),
            child: Text(
              l.schHistoryLink,
              style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w500, color: AppColors.accentLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expanded(BuildContext context, AppLocalizations l) {
    // Fill the space left below the last section, then a See all footer (§5.1).
    // A viewport-relative estimate stands in for a true measurement.
    final h = MediaQuery.of(context).size.height;
    final fit = ((h - 480) / 45).floor().clamp(3, 12);
    final shown = events.take(fit).toList();
    final hasMore = events.length > fit;

    var out = 0.0, income = 0.0, didnt = 0;
    for (final e in events) {
      switch (e.outcome) {
        case ScheduleOutcome.paid:
          out += e.amountInBase;
        case ScheduleOutcome.received:
          income += e.amountInBase;
        case ScheduleOutcome.skipped:
        case ScheduleOutcome.cancelled:
          didnt++;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: AppCard(
        child: Column(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const RowDivider(indent: 51),
              ScheduleEventRow(store: store, event: shown[i]),
            ],
            const RowDivider(indent: Insets.md),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  l.schCompletedFooter(
                    money(out, masked: store.masked),
                    money(income, masked: store.masked),
                    didnt,
                  ),
                  style: AppText.caption,
                ),
              ),
            ),
            if (hasMore) ...[
              const RowDivider(indent: Insets.md),
              InkWell(
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                      builder: (_) => const ScheduleHistoryScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(l.schSeeAll(events.length),
                        style: AppText.caption.copyWith(
                            fontSize: 13.5, color: AppColors.accentLight)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
              money(didNot ? store.taskAmountInBase(task) : event.amountInBase,
                  masked: store.masked,
                  forceDecimals: (didNot
                              ? store.taskAmountInBase(task)
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
