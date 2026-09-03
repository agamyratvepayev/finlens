import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/repeat_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/range_picker_sheet.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/same_transactions_screen.dart';
import '../ledger/transfer_detail_screen.dart';
import 'archive_screen.dart';
import 'mark_paid_sheet.dart';
import 'schedule_history_screen.dart';
import 'schedule_horizon.dart';
import 'task_detail_screen.dart';
import 'widgets/planner_empty.dart';

// ── A section of the list (§3) ──────────────────────────────────────────────

class _Section {
  _Section(this.label, this.tasks, {this.isOverdue = false});
  final String label;
  final List<Task> tasks;
  final bool isOverdue;

  /// Print the net only when the reader cannot get it at a glance (§3.2). The
  /// OVERDUE section always prints its net — it is the number the banner and the
  /// projection both hang on.
  bool get showsSectionTotal => isOverdue || tasks.length > 2;
}

/// Orders a section by date, then priority (high first), then amount (§3.1).
int _compareTasks(Task a, Task b, AppStore store) {
  final byDate = a.dueDate.compareTo(b.dueDate);
  if (byDate != 0) return byDate;
  final byPriority = b.priority.index.compareTo(a.priority.index);
  if (byPriority != 0) return byPriority;
  return store.taskAmountInBase(b).compareTo(store.taskAmountInBase(a));
}

/// The tasks the list shows, in display order (§3.1): overdue first, then the
/// in-horizon tasks sorted by date/priority/amount. Label-free, so the breach
/// lookup can reuse it.
List<Task> _orderedTasks(AppStore store, DateRange h) => [
      ...store.overdueTasks,
      ...(store.tasksInHorizon(h)..sort((a, b) => _compareTasks(a, b, store))),
    ];

List<_Section> _buildSections(
    AppStore store, DateRange h, DateTime today, AppLocalizations l) {
  final sections = <_Section>[];
  final overdue = store.overdueTasks;
  if (overdue.isNotEmpty) {
    sections.add(_Section(l.schOverdue, overdue, isOverdue: true));
  }

  final inHorizon = store.tasksInHorizon(h)
    ..sort((a, b) => _compareTasks(a, b, store));

  final todayTasks =
      inHorizon.where((t) => t.daysUntilDue(today) == 0).toList();
  if (todayTasks.isNotEmpty) sections.add(_Section(l.schToday, todayTasks));

  final weekTasks = inHorizon
      .where((t) => t.daysUntilDue(today) >= 1 && t.daysUntilDue(today) <= 7)
      .toList();
  if (weekTasks.isNotEmpty) sections.add(_Section(l.schThisWeek, weekTasks));

  // Everything beyond seven days is grouped under its own calendar month, so
  // the header is true by construction (§3.1).
  final later = inHorizon.where((t) => t.daysUntilDue(today) > 7).toList();
  final byMonth = <String, List<Task>>{};
  final order = <String>[];
  for (final t in later) {
    final key = '${t.dueDate.year}-${t.dueDate.month}';
    (byMonth[key] ??= (order..add(key), <Task>[]).$2).add(t);
  }
  for (final key in order) {
    final tasks = byMonth[key]!;
    sections.add(_Section(monthLong(tasks.first.dueDate.month, l), tasks));
  }
  return sections;
}

/// The single row §2.4 blames for the first breach (§4.5): the first pay-out due
/// on the breach day, or — when the breach is on day 0 from overdue alone — the
/// first overdue pay-out.
Task? _breachTask(AppStore store, DateRange h, DateTime? breachDay) {
  if (breachDay == null) return null;
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  for (final t in _orderedTasks(store, h)) {
    if (t.isPayOut && sameDay(t.dueDate, breachDay)) return t;
  }
  // A breach on day 0 from overdue alone: mark the first overdue pay-out.
  final overdueOut = store.overdueOutflows;
  return overdueOut.isEmpty ? null : overdueOut.first;
}

// ── Summary (§2) ────────────────────────────────────────────────────────────

class ScheduleSummary extends StatelessWidget {
  const ScheduleSummary({super.key, required this.store, required this.horizon});

  final AppStore store;
  final ScheduleHorizon horizon;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = AppStore.today;
    final h = horizon.range(today);

    final projection = store.projection(h);
    final short = projection < 0;
    final breach = store.firstShortfall(h);
    final inSum = store.comingIn(h);
    final outSum = store.goingOut(h);
    final overdue = store.overdueTasks;

    final span = horizon.spanDays(today);
    final barValue = breach == null
        ? 1.0
        : (breach.day.difference(h.start).inDays / (span == 0 ? 1 : span))
            .clamp(0.0, 1.0);
    final barColor = breach == null ? AppColors.positive : AppColors.negative;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, 0, Insets.gutter, Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AmountText(
                  short ? -projection : projection,
                  style: AppText.hero.copyWith(fontSize: 32, height: 1.0),
                  color: short ? AppColors.negative : null,
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  short ? l.schShortAfter : l.schLeftAfter,
                  style: AppText.caption.copyWith(
                      color: short
                          ? AppColors.negative
                          : AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          ProgressBar(value: barValue, color: barColor, height: 8),
          const SizedBox(height: Insets.sm),
          if (inSum > 0 || outSum > 0)
            Text(
              _caption(l, inSum, outSum),
              style: AppText.caption.copyWith(fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (breach != null) ...[
            const SizedBox(height: 4),
            Text(
              _shortfallLine(l, breach, today),
              style: AppText.caption.copyWith(color: AppColors.negative),
            ),
          ],
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            NoticeBanner(
              margin: EdgeInsets.zero,
              color: AppColors.negative,
              icon: Icons.error_outline_rounded,
              text: _bannerCopy(l),
              dense: true,
            ),
          ],
        ],
      ),
    );
  }

  String _caption(AppLocalizations l, double inSum, double outSum) {
    final parts = <String>[
      if (inSum > 0) l.schCaptionIn(money(inSum, masked: store.masked)),
      if (outSum > 0) l.schCaptionOut(money(outSum, masked: store.masked)),
    ];
    return parts.join(' · ');
  }

  String _shortfallLine(
      AppLocalizations l, ({DateTime day, double amount}) breach, DateTime today) {
    final amount = money(breach.amount, masked: store.masked);
    final onToday = breach.day.year == today.year &&
        breach.day.month == today.month &&
        breach.day.day == today.day;
    return onToday
        ? l.schShortToday(amount)
        : l.schShortOnDay(amount, dayMonth(breach.day, l));
  }

  String _bannerCopy(AppLocalizations l) {
    final outN = store.overdueOutflows.length;
    final inN = store.overdueInflows.length;
    final masked = store.masked;
    if (inN == 0) {
      return l.schBannerOut(outN, money(store.overdueOutAmount, masked: masked));
    }
    if (outN == 0) {
      return l.schBannerIn(inN, money(store.overdueInAmount, masked: masked));
    }
    return l.schBannerBoth(
      outN + inN,
      money(store.overdueOutAmount, masked: masked),
      money(store.overdueInAmount, masked: masked),
    );
  }
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
    final today = AppStore.today;
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
    final breachTask = _breachTask(store, h, breach?.day);

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
              trailing: section.showsSectionTotal
                  ? _sectionNet(section)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              child: AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < section.tasks.length; i++) ...[
                      if (i > 0) const RowDivider(indent: 51),
                      _TaskRow(
                        store: store,
                        task: section.tasks[i],
                        isBreach: section.tasks[i] == breachTask,
                      ),
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

  Widget _sectionNet(_Section section) {
    var net = 0.0;
    for (final t in section.tasks) {
      net += t.isPayOut
          ? -widget.store.taskAmountInBase(t)
          : widget.store.taskAmountInBase(t);
    }
    final color = net == 0
        ? AppColors.textSecondary
        : (net > 0 ? AppColors.positive : AppColors.negative);
    return AmountText(
      net.abs(),
      style: AppText.label.copyWith(color: color),
      color: color,
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

// ── Task row (§4) ───────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  const _TaskRow(
      {required this.store, required this.task, required this.isBreach});

  final AppStore store;
  final Task task;
  final bool isBreach;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final payOut = task.isPayOut;
    final color = payOut ? AppColors.negative : AppColors.positive;
    final overdue = task.daysUntilDue(AppStore.today) < 0;
    final account = store.accountById(task.linkedAccountId)?.name;

    final row = InkWell(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
      ),
      child: Container(
        decoration: isBreach
            ? BoxDecoration(
                color: AppColors.tint(AppColors.warning, 0.10),
                border: const Border(
                  left: BorderSide(color: AppColors.warning, width: 2.5),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            IconTile(task.icon, color: color, size: 28),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and amount share line one, so the amount only costs
                  // width to the line it belongs to; the subtitle then runs the
                  // full column width (§A1). Baseline alignment because the title
                  // carries height:1.2 and AmountText does not — centring would
                  // sit them a hair off each other's baseline.
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
                        task.expectedAmount.abs(),
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
            _MarkPaidTick(store: store, task: task),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      label: _semantics(l, payOut, overdue, account),
      child: ExcludeSemantics(child: row),
    );
  }

  /// One unbreakable line: `date · [N late ·] account [ · won't cover] ⟳ freq`.
  ///
  /// It is a single [Text.rich] with [TextOverflow.ellipsis] on purpose — there
  /// are no rigid siblings to push past the edge, so a stripe is structurally
  /// impossible, and truncation lands at the line's end, cutting the cadence
  /// footnote before the account name (§4.2). The cadence is the frequency word
  /// only ([repeatShortLabel]); the long "on the 7th" form lives on the Task
  /// detail screen.
  Widget _subtitle(AppLocalizations l, bool overdue, String? account) {
    final subColor = overdue ? AppColors.negative : AppColors.textSecondary;
    // Overdue paints the whole line negative, cadence included; otherwise the
    // ⟳ run keeps its tertiary tone (as before).
    final cadenceColor = overdue ? AppColors.negative : AppColors.textTertiary;
    final base = AppText.rowSubtitle
        .copyWith(fontSize: 11.5, height: 1.15, color: subColor);
    final cadenceStyle =
        AppText.caption.copyWith(fontSize: 10.5, color: cadenceColor);

    final date = dayMonth(task.dueDate, l);
    // Just the count here — the OVERDUE header, the negative colour and the red
    // section total already say "late" three times over (§A3). The full "late"
    // wording moves to the screen reader (§A4), which sees none of those.
    final late = overdue
        ? l.schOverdueDays(-task.daysUntilDue(AppStore.today))
        : null;

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: date),
          if (late != null) TextSpan(text: ' · $late'),
          if (account != null) TextSpan(text: ' · $account'),
          if (isBreach)
            TextSpan(
              text: ' · ${l.schWontCover}',
              style: base.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.warning),
            ),
          if (task.isRecurring) ...[
            const TextSpan(text: '  '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.repeat_rounded,
                  size: 10.5, color: cadenceColor),
            ),
            TextSpan(
                text: ' ${repeatShortLabel(task.repeats, l)}',
                style: cadenceStyle),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _semantics(
      AppLocalizations l, bool payOut, bool overdue, String? account) {
    final amount = money(task.expectedAmount.abs(), masked: store.masked);
    final parts = <String>[
      task.title,
      '${payOut ? l.schSemPayingOut : l.schSemComingIn} $amount',
      '${l.schSemDue} ${dayMonth(task.dueDate, l)}',
      // The eye lost the word "late" (§A3); the screen reader, which cannot see
      // the red header or total, gains the full phrase here — right after the
      // due date (§A4).
      if (overdue) l.schDaysLate(-task.daysUntilDue(AppStore.today)),
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

/// The mark-paid tick — a 30 pt circle inside a ≥ 44 pt tap target (§4.1). It
/// opens the confirm sheet (§10); it never writes on tap, and its target does
/// not trigger the row's tap.
class _MarkPaidTick extends StatelessWidget {
  const _MarkPaidTick({required this.store, required this.task});

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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceHigh, width: 1.5),
            ),
            child: const Icon(Icons.check_rounded,
                size: 16, color: AppColors.textTertiary),
          ),
        ),
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
    final rangeLabel =
        range.preset?.label(l) ?? range.label(AppStore.today, l);
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

  /// Zero items: two lines, no card, no divider (§B5). A sentence, then a link
  /// — no background, no border, no chevron — to the same sheet as the header.
  Widget _emptyLines(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.schCompletedEmpty,
            style: AppText.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onPickRange,
            child: Text(
              l.schCompletedLongerPeriod,
              style: AppText.caption.copyWith(color: AppColors.accentLight),
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
    final today = AppStore.today;
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
    // A paid/received row opens its Ledger entry; a skipped/cancelled row has no
    // entry, so it opens the Task detail (§5.1).
    final txn = event.txn;
    if (txn != null) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => txn.type == TxnType.transfer
              ? TransferDetailScreen(txnId: txn.id)
              : SameTransactionsScreen(originTxnId: txn.id),
        ),
      );
    } else {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: event.task.id)),
      );
    }
  }
}
