import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/change_row.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../ledger/ledger_scope.dart';
import '../ledger/scoped_ledger_screen.dart';
import 'edit_goal_screen.dart';
import 'goal_presentation.dart';

/// A goal's detail (§5). Everything here is *read* from the ledger — the goal
/// keeps no history of its own. The most valuable figure, `AT THIS RATE`,
/// cannot be computed on the card and lives here.
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({
    super.key,
    required this.goalId,
    required this.backLabel,
  });

  final String goalId;

  /// The name of the screen the user came from — the back button's label. The
  /// Goals tab passes `Goals`, the Archive passes `Archive`; the screen never
  /// assumes (§4).
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final goal = store.goalById(goalId);

    // The goal may have been deleted from the ••• menu while this was open, or
    // cleared from the Archive. The empty scaffold covers both.
    if (goal == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    // §2.1 — the mode is read from the goal's own status, never a flag, so a
    // goal restored while this is open flips back to live on the next build.
    final isArchived = goal.status != GoalStatus.active;
    // §3 — frozen at the day the goal ended; a data-error goal with no end date
    // falls back to today rather than crashing.
    final asOf = isArchived ? (goal.endedAt ?? AppStore.today) : null;
    final reachedOutcome = goal.status == GoalStatus.reached;

    final m = store.goalMetrics(goal, asOf: asOf);
    // The archived body never reads the live verdict: its outcome comes from
    // completedAt / stoppedAt, so a source archived after the goal ended cannot
    // rewrite it to "source unavailable" (§3).
    final verdict = isArchived ? null : goalVerdict(l, goal, m);

    // §10 — SafeArea keeps bottom:false so the top bar can hug the notch, which
    // means the scroll view itself must clear the home indicator: the safe-area
    // inset plus a tail so the last CHANGES row scrolls fully into view.
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(goal: goal, backLabel: backLabel),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: safeBottom + Insets.xxl),
                children: [
                  _header(l, store, goal, m, verdict, isArchived: isArchived),
                  // §2 — 16pt clearance above the hero. The rule: a hero with
                  // height:1.0 hugs its glyphs and wants ~5pt more room than
                  // ordinary text. NB this hero uses AppText.hero, which (unlike
                  // heroAmount) does NOT set height:1.0, so it keeps default
                  // leading — 16pt already clears the verdict comfortably.
                  const SizedBox(height: Insets.lg),
                  _figures(l, m,
                      isArchived: isArchived, reachedOutcome: reachedOutcome),
                  const SizedBox(height: Insets.xl),
                  // §2.4 — the reached-at-zero prompt is a live-only action.
                  if (!isArchived && store.goalOffersArchive(goal))
                    _ArchiveActions(store: store, goal: goal),
                  // Forecasts (rate/projection/pace) are replaced by the frozen
                  // outcome on an archived record (§2.5).
                  if (isArchived) _outcome(l, goal, m) else _columns(l, m),
                  _watching(context, l, store, goal, m),
                  if (goal.source.isAccount)
                    _movements(context, l, store, goal, asOf: asOf),
                  if (goal.note.trim().isNotEmpty) _note(l, goal),
                  _changes(l, goal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(
    AppLocalizations l,
    AppStore store,
    Goal goal,
    GoalMetrics m,
    ({String text, bool attention})? verdict, {
    required bool isArchived,
  }) {
    // On an archived record the outcome is known from the goal's status, not
    // from m.reached — a source that grew past target after the goal was
    // abandoned must not read as "reached" (§2.5).
    final reachedOutcome = goal.status == GoalStatus.reached;
    final showReached = isArchived ? reachedOutcome : m.reached;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, 0),
      child: Row(
        children: [
          IconTile(
            showReached ? Icons.check_rounded : store.goalIcon(goal),
            color: showReached ? AppColors.positive : AppColors.goal,
            size: 40,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  // §1 — tighten to 1.15 so a two-line name doesn't gap wide,
                  // then sit the verdict 1pt below it.
                  style: AppText.title.copyWith(fontSize: 21, height: 1.15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                if (isArchived)
                  Text(
                    _outcomeLine(l, goal, reachedOutcome),
                    style: AppText.caption.copyWith(
                      height: 1.2,
                      color: reachedOutcome
                          ? AppColors.positive
                          : AppColors.textSecondary,
                    ),
                  )
                else
                  Text(
                    verdict!.text,
                    style: AppText.rowSubtitle.copyWith(
                      height: 1.2,
                      color: goalVerdictColor(m, verdict.attention),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The header line on an archived goal: `Reached on 14 May 2026` /
  /// `Stopped on 3 Apr 2026`. Deliberately not [goalVerdict] — that is written
  /// for live goals and the Goals-tab card depends on it unchanged (§2.5).
  String _outcomeLine(AppLocalizations l, Goal goal, bool reachedOutcome) {
    final on = goal.endedAt ?? AppStore.today;
    return reachedOutcome
        ? l.goalOutcomeReachedOn(dayMonthYear(on, l))
        : l.goalOutcomeStoppedOn(dayMonthYear(on, l));
  }

  // ── Figures ──────────────────────────────────────────────────────────────

  Widget _figures(
    AppLocalizations l,
    GoalMetrics m, {
    bool isArchived = false,
    bool reachedOutcome = false,
  }) {
    final pct = m.progress;
    final daysElapsed = m.daysTotal > 0 ? m.daysElapsed.clamp(0, m.daysTotal) : m.daysElapsed;
    // Archived: full green when the goal was reached, a frozen muted bar when it
    // was abandoned. Live keeps the shared goal colour (§2.4).
    final barColor = isArchived
        ? (reachedOutcome ? AppColors.positive : AppColors.textSecondary)
        : goalBarColor(m);
    // A finished goal has no pace to keep — the marker is a forecast (§2.4/§3).
    final pace = isArchived ? null : goalPaceFraction(m);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AmountText.balance(
                m.current,
                style: AppText.hero.copyWith(fontSize: 30),
                color: barColor,
              ),
              const SizedBox(width: Insets.sm),
              Flexible(
                child: Text(
                  // Archived reads factually ("of $2,000") — never "$X to go",
                  // which would imply the goal is still being pursued.
                  (isArchived || m.reached)
                      ? '${l.goalOfWord} ${money(m.target)}'
                      : l.goalOfToGo(money(m.target), money(m.remaining)),
                  style: AppText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          ProgressBar(
            value: m.progress,
            color: barColor,
            paceMarker: pace,
            height: 8,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                // §3 — "8% · day 189 of 393", reusing the Budgets summary's
                // day-of clause so the two screens read identically.
                m.targetDate == null
                    ? percent(pct, decimals: 0)
                    : '${percent(pct, decimals: 0)} · '
                        '${l.bdDayOfMonth(daysElapsed, m.daysTotal)}',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
              if (pace != null) ...[
                const Spacer(),
                Container(width: 2, height: 10, color: AppColors.textPrimary),
                const SizedBox(width: 5),
                Text(l.plPace, style: AppText.caption.copyWith(fontSize: 11.5)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── STARTED · TARGET · AT THIS RATE ────────────────────────────────────────

  Widget _columns(AppLocalizations l, GoalMetrics m) {
    final now = AppStore.today;
    final started = DateTime(now.year, now.month - m.monthsElapsed, now.day);
    // AT THIS RATE lands amber when it falls after TARGET, positive when before,
    // neutral when there is nothing to project (§5).
    final Color rateColor;
    final String rateText;
    if (m.actualRate == null || m.projectedEnd == null) {
      rateColor = AppColors.textSecondary;
      rateText = '—';
    } else {
      rateText = monthYear(m.projectedEnd!, l);
      rateColor = (m.targetDate != null && m.projectedEnd!.isAfter(m.targetDate!))
          ? AppColors.warning
          : AppColors.positive;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: AppCard(
        // §2 — vertical space trimmed (top 16→14, bottom 16→7) to take the card
        // from ~116 to ~90. Horizontal padding stays Insets.lg so the card's
        // width and the three columns' geometry are byte-identical to before.
        padding: const EdgeInsets.fromLTRB(Insets.lg, 14, Insets.lg, 7),
        child: Column(
          children: [
            // §4a — the three columns spread to their own edges (left / centre /
            // right) so AT THIS RATE terminates on the card's right inset instead
            // of leaving a wide trailing gap. Flex stays equal.
            Row(
              children: [
                _Col(label: l.goalColStarted, value: monthYear(started, l)),
                _Col(
                  label: l.goalColTarget,
                  value: m.targetDate == null ? '—' : monthYear(m.targetDate!, l),
                  align: CrossAxisAlignment.center,
                ),
                _Col(
                  label: l.goalColAtThisRate,
                  value: rateText,
                  color: rateColor,
                  align: CrossAxisAlignment.end,
                ),
              ],
            ),
            const Padding(
              // §2.1/§2.2 — was a symmetric 12 both sides; now asymmetric so the
              // space comes out of the verdict row: 11pt above the rule (value→
              // divider) and 6pt below it (divider→verdict).
              padding: EdgeInsets.only(top: 11, bottom: 6),
              child: RowDivider(indent: 0),
            ),
            // §4b — centred beneath the divider, matching the Budgets summary's
            // frequency line.
            Align(
              alignment: Alignment.center,
              child: Text(
                _averagingLine(l, m),
                textAlign: TextAlign.center,
                // §2.2 — 12.5pt with an explicit 15pt line box (was 12pt on
                // caption's implicit 1.3 leading). The half-point keeps the row
                // legible while its clearance above the divider drops to 6pt.
                style: AppText.caption.copyWith(fontSize: 12.5, height: 15 / 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _averagingLine(AppLocalizations l, GoalMetrics m) {
    if (m.reached) return l.goalReachedSummary;
    if (m.actualRate == null) return l.goalNotMovingYet;
    final needs = m.requiredRate;
    if (needs == null) return l.goalAveragingOnly(money(m.actualRate!));
    // §4c — no cents on either figure. The current rate rounds normally; the
    // required rate ceils, because paying the rounded-down figure lands short.
    return l.goalAveraging(
      money(m.actualRate!, noDecimals: true),
      money(needs, roundUp: true),
    );
  }

  // ── OUTCOME (archived, replaces _columns) ────────────────────────────────

  /// The frozen three-column record that stands in for `AT THIS RATE` on an
  /// archived goal (§2.5). Reached: `TARGET · REACHED ON · TOOK`. Abandoned:
  /// `TARGET · STOPPED ON · GOT TO`. Same geometry as the app's other
  /// three-column stat cards.
  Widget _outcome(AppLocalizations l, Goal goal, GoalMetrics m) {
    final reachedOutcome = goal.status == GoalStatus.reached;
    final on = dayMonth(goal.endedAt ?? AppStore.today, l);
    final List<({String label, Widget value})> cols = reachedOutcome
        ? [
            (label: l.goalColTarget, value: _outcomeAmount(m.target)),
            (label: l.goalColReachedOn, value: _outcomeText(on)),
            (label: l.goalColTook, value: _outcomeText(_tookText(l, goal))),
          ]
        : [
            (label: l.goalColTarget, value: _outcomeAmount(m.target)),
            (label: l.goalColStoppedOn, value: _outcomeText(on)),
            // The frozen figure — what the source held on the day it stopped.
            (label: l.goalColGotTo, value: _outcomeAmount(m.current)),
          ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 9, 6, 10),
          child: Row(
            children: [
              for (final c in cols)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        c.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      c.value,
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const _outcomeValueStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Values scale down rather than clip, so the third column (`TOOK` / `GOT TO`)
  // survives 320 pt and 130 % text scale without overflow (§4).
  Widget _outcomeAmount(double v) => _shrink(
        AmountText.balance(v, style: _outcomeValueStyle),
      );

  Widget _outcomeText(String t) => _shrink(
        Text(t, maxLines: 1, style: _outcomeValueStyle),
      );

  Widget _shrink(Widget child) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: child,
      );

  /// `TOOK`: reached-only. `durationMonths` is null exactly when the goal was
  /// abandoned (no completedAt), which is why that column is `GOT TO` instead.
  String _tookText(AppLocalizations l, Goal goal) {
    final months = goal.durationMonths;
    if (months == null || months < 1) return l.goalTookUnderMonth;
    return l.goalTookMonths(months);
  }

  // ── WATCHING ─────────────────────────────────────────────────────────────

  Widget _watching(
    BuildContext context,
    AppLocalizations l,
    AppStore store,
    Goal goal,
    GoalMetrics m,
  ) {
    if (goal.source.isCategory) {
      final cat = store.categoryById(goal.source.id);
      final windowEnd = goal.targetDate ?? AppStore.today;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l.goalWatching),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: AppCard(
              child: Padding(
                // §7 — denser row: 7pt vertical padding, 26pt tile, 10pt gap.
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md, vertical: 7),
                child: Row(
                  children: [
                    IconTile(cat?.icon ?? Icons.help_outline_rounded,
                        color: cat?.color ?? AppColors.textSecondary, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat?.name ?? l.goalSourceUnavailable,
                              style: AppText.rowTitle.copyWith(height: 1.15)),
                          const SizedBox(height: 1),
                          Text(
                            l.goalCategoryWindow(
                              dayMonth(goal.createdAt, l),
                              dayMonth(windowEnd, l),
                            ),
                            style: AppText.rowSubtitle
                                .copyWith(fontSize: 11.5, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final acc = store.accountById(goal.source.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l.goalWatching),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: acc == null
                  ? null
                  : () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => ScopedLedgerScreen(
                            initialScope: AccountScope(acc.id),
                          ),
                        ),
                      ),
              child: Padding(
                // §7 — denser row: 7pt vertical padding, 26pt tile, 10pt gap.
                // §8 — right pad cut to 6 so the balance (which the chevron
                // pushes inboard) lands close to the movement amounts below.
                padding: const EdgeInsets.fromLTRB(Insets.md, 7, 6, 7),
                child: Row(
                  children: [
                    IconTile(acc?.displayIcon ?? Icons.help_outline_rounded,
                        color: acc?.color ?? AppColors.textSecondary, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(acc?.name ?? l.goalSourceUnavailable,
                              style: AppText.rowTitle.copyWith(height: 1.15)),
                          const SizedBox(height: 1),
                          Text(
                            acc == null ? '' : acc.group.label(l),
                            style: AppText.rowSubtitle
                                .copyWith(fontSize: 11.5, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    AmountText.balance(m.current),
                    if (acc != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MOVEMENTS ──────────────────────────────────────────────────────────────

  Widget _movements(
    BuildContext context,
    AppLocalizations l,
    AppStore store,
    Goal goal, {
    DateTime? asOf,
  }) {
    var all = store.txnsForAccount(goal.source.id);
    // Archived: the movement window ends at the goal's end date — a record does
    // not gain new movements after it stopped (§2.4).
    if (asOf != null) {
      final cutoff =
          DateTime(asOf.year, asOf.month, asOf.day, 23, 59, 59, 999);
      all = all.where((t) => !t.date.isAfter(cutoff)).toList(growable: false);
    }
    if (all.isEmpty) return const SizedBox.shrink();
    final preview = all.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l.goalMovements),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < preview.length; i++) ...[
                  // §7 — hairline inset to 48 so it starts under the text, past
                  // the smaller 26pt tile.
                  if (i > 0) const RowDivider(indent: 48),
                  _MovementRow(
                    store: store,
                    txn: preview[i],
                    accountId: goal.source.id,
                  ),
                ],
                // Full-bleed above the footer: there is no tile below it to
                // align to, and the footer sits centred.
                const RowDivider(indent: 0),
                InkWell(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => ScopedLedgerScreen(
                        initialScope: AccountScope(goal.source.id),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    // §9 — label + chevron centred as one unit, 3pt apart, both
                    // in the accent colour. The chevron belongs to the label,
                    // not pinned to the card edge.
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l.goalSeeAll(all.length),
                          style: AppText.body.copyWith(
                            color: AppColors.accentSoft,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.accentSoft),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── NOTE ─────────────────────────────────────────────────────────────────

  Widget _note(AppLocalizations l, Goal goal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l.goalNoteSection),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(goal.note, style: AppText.body.copyWith(fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }

  // ── CHANGES (§7) ─────────────────────────────────────────────────────────

  Widget _changes(AppLocalizations l, Goal goal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Insets.md),
        SectionLabel(l.goalChanges),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < goal.history.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  ChangeRow(
                    date: '${goal.history[i].at.day}.${goal.history[i].at.month}',
                    label: _goalChangeLabel(l, goal.history[i].field),
                    value: goal.history[i].field == 'created'
                        ? goal.history[i].to
                        : '${goal.history[i].from} → ${goal.history[i].to}',
                    amber: goal.history[i].amber,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.goal, required this.backLabel});

  final Goal goal;
  final String backLabel;

  bool get _isArchived => goal.status != GoalStatus.active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xs, vertical: Insets.xs),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            label: Text(backLabel),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentSoft,
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 22),
            color: AppColors.textPrimary,
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final store = StoreScope.read(context);
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.sm),
            // Nothing on an archived goal is editable (§2.3): only Restore (for
            // an abandoned goal) and Delete permanently.
            if (_isArchived) ...[
              if (goal.status == GoalStatus.abandoned)
                _MenuRow(
                  icon: Icons.unarchive_rounded,
                  label: l.actionRestore,
                  onTap: () => Navigator.of(sheetContext).pop('restore'),
                ),
              _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: l.goalDeletePermanently,
                danger: true,
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ] else ...[
              _MenuRow(
                icon: Icons.edit_rounded,
                label: l.goalMenuEdit,
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
              _MenuRow(
                icon: Icons.flag_rounded,
                label: l.egMarkReached,
                onTap: () => Navigator.of(sheetContext).pop('reached'),
              ),
              _MenuRow(
                icon: Icons.pause_circle_rounded,
                label: l.goalStopTracking,
                subtitle: l.goalStopTrackingDesc,
                onTap: () => Navigator.of(sheetContext).pop('stop'),
              ),
              _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: l.egDeleteGoal,
                danger: true,
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'edit':
        openGoalEditor(context, goalId: goal.id);
      case 'reached':
        store.markGoalReached(goal);
        Navigator.of(context).pop();
      case 'stop':
        store.abandonGoal(goal);
        Navigator.of(context).pop();
      case 'restore':
        // Same call the Archive row's Restore button makes; pops back to it.
        store.restoreGoal(goal);
        Navigator.of(context).pop();
      case 'delete':
        // The same confirm flow for both a live delete and an archived
        // permanent delete (§2.3).
        final ok = await confirmGoalDelete(context, store, goal);
        if (!ok || !context.mounted) return;
        store.deleteGoal(goal);
        Navigator.of(context).pop();
    }
  }
}

/// §4 — a latched goal whose account has reached \$0 offers two actions, because
/// there are two objects: the goal and the account.
class _ArchiveActions extends StatelessWidget {
  const _ArchiveActions({required this.store, required this.goal});

  final AppStore store;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.goalReachedAtZero, style: AppText.body.copyWith(fontSize: 13.5)),
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        store.markGoalReached(goal);
                        Navigator.of(context).pop();
                      },
                      child: Text(l.goalKeepAccount),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        store.reachGoalAndArchiveAccount(goal);
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l.goalArchiveBoth),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Col extends StatelessWidget {
  const _Col({
    required this.label,
    required this.value,
    this.color,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final Color? color;

  /// Which edge the column packs to (§4a): start / center / end. Both the label
  /// and the value follow it so the value terminates on the chosen edge.
  final CrossAxisAlignment align;

  TextAlign get _textAlign => switch (align) {
        CrossAxisAlignment.center => TextAlign.center,
        CrossAxisAlignment.end => TextAlign.end,
        _ => TextAlign.start,
      };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          // §2.1 — line heights set explicitly (caps key 12, value 21) rather
          // than left to default leading; that implicit leading is what made the
          // block measure taller than its padding. Font size, weight, spacing
          // and colour are untouched.
          Text(label.toUpperCase(),
              style: AppText.label.copyWith(height: 12 / 11),
              textAlign: _textAlign),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: _textAlign,
            style: AppText.rowTitle.copyWith(
              fontSize: 14,
              height: 21 / 14,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.store,
    required this.txn,
    required this.accountId,
  });

  final AppStore store;
  final Txn txn;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final effect = store.effectOfTxnOn(txn, accountId);
    final other = txn.fromRef == accountId ? txn.toRef : txn.fromRef;
    final title = txn.note.trim().isNotEmpty ? txn.note.trim() : store.refName(other);

    // §6 — the sign is gone, so colour is the only visual carrier of direction.
    // The screen reader gets that direction in words (masked amount honoured).
    final moneyIn = effect >= 0;
    final magnitude = money(effect.abs(), masked: store.masked);
    final directionLabel =
        moneyIn ? l.a11yMoneyIn(magnitude) : l.a11yMoneyOut(magnitude);

    return Padding(
      // §7 — denser row: 7pt vertical padding, 26pt tile, 10pt gap. §5 — the
      // title drops its fontSize:14 override to sit at the 15pt token, matching
      // the WATCHING row above.
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 7),
      child: Row(
        children: [
          IconTile(store.refIcon(other), color: store.refColor(other), size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.rowTitle.copyWith(height: 1.15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(dayMonth(txn.date, l),
                    style: AppText.rowSubtitle
                        .copyWith(fontSize: 11.5, height: 1.15)),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Semantics(
            label: directionLabel,
            excludeSemantics: true,
            child: AmountText(
              effect,
              color: effect < 0 ? AppColors.negative : AppColors.positive,
            ),
          ),
        ],
      ),
    );
  }
}

/// The localized label for a goal-history [GoalEdit.field]. Kept beside the row
/// that now delegates rendering to the shared [ChangeRow].
String _goalChangeLabel(AppLocalizations l, String field) => switch (field) {
      'created' => l.goalChangeCreated,
      'target' => l.goalChangeTarget,
      _ => l.goalChangeDate,
    };

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.negative : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: Insets.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.rowTitle.copyWith(color: color)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: AppText.rowSubtitle.copyWith(fontSize: 11.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
