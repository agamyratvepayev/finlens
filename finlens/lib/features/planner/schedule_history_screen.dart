import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'archive_screen.dart';
import 'schedule_tab.dart' show ScheduleEventRow;

/// A backward period for the History screen — independent of the tab's forward
/// horizon (§6). Changing one never changes the other.
enum HistoryPreset { last7, last20, last30, last90, thisMonth, lastMonth }

enum HistoryFilter { all, paid, skipped, cancelled }

/// §6 — "what happened in the last N days", with its own period and filter.
class ScheduleHistoryScreen extends StatefulWidget {
  const ScheduleHistoryScreen({super.key});

  @override
  State<ScheduleHistoryScreen> createState() => _ScheduleHistoryScreenState();
}

class _ScheduleHistoryScreenState extends State<ScheduleHistoryScreen> {
  HistoryPreset _preset = HistoryPreset.last20;
  DateTime? _sinceDate;
  HistoryFilter _filter = HistoryFilter.all;

  DateRange _range(DateTime today) {
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
    DateTime start;
    switch (_preset) {
      case HistoryPreset.last7:
        start = _minus(today, 7);
      case HistoryPreset.last20:
        start = _minus(today, 20);
      case HistoryPreset.last30:
        start = _minus(today, 30);
      case HistoryPreset.last90:
        start = _minus(today, 90);
      case HistoryPreset.thisMonth:
        start = DateTime(today.year, today.month, 1);
      case HistoryPreset.lastMonth:
        final prev = DateTime(today.year, today.month - 1, 1);
        return DateRange(prev, DateTime(today.year, today.month, 0, 23, 59, 59, 999));
    }
    if (_sinceDate != null) start = _sinceDate!;
    return DateRange(start, end);
  }

  static DateTime _minus(DateTime today, int days) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: days));

  String _periodLabel(AppLocalizations l) {
    if (_sinceDate != null) return l.histSinceDate(dayMonth(_sinceDate!, l));
    switch (_preset) {
      case HistoryPreset.last7:
        return l.histLastDays(7);
      case HistoryPreset.last20:
        return l.histLastDays(20);
      case HistoryPreset.last30:
        return l.histLastDays(30);
      case HistoryPreset.last90:
        return l.histLastDays(90);
      case HistoryPreset.thisMonth:
        return l.histThisMonth;
      case HistoryPreset.lastMonth:
        return l.histLastMonth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final today = AppStore.today;
    final all = store.scheduleEvents(_range(today));
    final filtered = all.where(_matches).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _navBar(context, l),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _chips(l, all),
                  _summary(store, l, filtered),
                  if (filtered.isEmpty)
                    _emptyRow(l)
                  else
                    ..._grouped(store, l, filtered),
                  _footer(context, store, l, today),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matches(ScheduleEvent e) {
    switch (_filter) {
      case HistoryFilter.all:
        return true;
      case HistoryFilter.paid:
        return e.outcome == ScheduleOutcome.paid ||
            e.outcome == ScheduleOutcome.received;
      case HistoryFilter.skipped:
        return e.outcome == ScheduleOutcome.skipped;
      case HistoryFilter.cancelled:
        return e.outcome == ScheduleOutcome.cancelled;
    }
  }

  Widget _navBar(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, 4, Insets.gutter, 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            label: Text(l.plTabSchedule),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentLight),
          ),
          const Spacer(),
          InkWell(
            onTap: _pickPeriod,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _periodLabel(l),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4),
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(AppLocalizations l, List<ScheduleEvent> all) {
    int count(HistoryFilter f) {
      switch (f) {
        case HistoryFilter.all:
          return all.length;
        case HistoryFilter.paid:
          return all
              .where((e) =>
                  e.outcome == ScheduleOutcome.paid ||
                  e.outcome == ScheduleOutcome.received)
              .length;
        case HistoryFilter.skipped:
          return all.where((e) => e.outcome == ScheduleOutcome.skipped).length;
        case HistoryFilter.cancelled:
          return all
              .where((e) => e.outcome == ScheduleOutcome.cancelled)
              .length;
      }
    }

    String label(HistoryFilter f) {
      final n = count(f);
      switch (f) {
        case HistoryFilter.all:
          return l.histFilterAll(n);
        case HistoryFilter.paid:
          return l.histFilterPaid(n);
        case HistoryFilter.skipped:
          return l.histFilterSkipped(n);
        case HistoryFilter.cancelled:
          return l.histFilterCancelled(n);
      }
    }

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        children: [
          for (final f in HistoryFilter.values) ...[
            _chip(label(f), f == _filter, () => setState(() => _filter = f)),
            const SizedBox(width: Insets.sm),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.chipActive : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.textPrimary : AppColors.chipText,
          ),
        ),
      ),
    );
  }

  Widget _summary(
      AppStore store, AppLocalizations l, List<ScheduleEvent> events) {
    var out = 0.0, income = 0.0, didnt = 0.0;
    for (final e in events) {
      switch (e.outcome) {
        case ScheduleOutcome.paid:
          out += e.amountInBase;
        case ScheduleOutcome.received:
          income += e.amountInBase;
        case ScheduleOutcome.skipped:
        case ScheduleOutcome.cancelled:
          didnt += e.amountInBase;
      }
    }

    Widget col(String key, double value, Color color) => Expanded(
          child: Column(
            children: [
              Text(key,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                money(value, masked: store.masked),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, Insets.sm),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 9, 6, 10),
          child: Row(
            children: [
              col(l.histOut, out, AppColors.negative),
              col(l.histIn, income, AppColors.positive),
              col(l.histDidntHappen, didnt, AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _grouped(
      AppStore store, AppLocalizations l, List<ScheduleEvent> events) {
    final byMonth = <String, List<ScheduleEvent>>{};
    final order = <String>[];
    for (final e in events) {
      final key = '${e.date.year}-${e.date.month}';
      (byMonth[key] ??= (order..add(key), <ScheduleEvent>[]).$2).add(e);
    }
    final out = <Widget>[];
    for (final key in order) {
      final group = byMonth[key]!;
      out.add(SectionLabel(
        monthYearLong(group.first.date, l),
        trailing: Text(l.schItemsCount(group.length),
            style: AppText.label.copyWith(color: AppColors.textSecondary)),
      ));
      out.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: AppCard(
          child: Column(
            children: [
              for (var i = 0; i < group.length; i++) ...[
                if (i > 0) const RowDivider(indent: 51),
                ScheduleEventRow(store: store, event: group[i]),
              ],
            ],
          ),
        ),
      ));
    }
    return out;
  }

  Widget _emptyRow(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: Insets.gutter),
      child: Center(
        child: Text(
          l.histNothingHere,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, AppStore store, AppLocalizations l,
      DateTime today) {
    final range = _range(today);
    bool inPeriod(DateTime? d) {
      if (d == null) return false;
      return !d.isBefore(range.start) && !d.isAfter(range.end);
    }

    final paused = store.pausedTasks
        .where((t) => inPeriod(t.statusChangedAt))
        .length;
    final deleted = store.deletedTasks
        .where((t) => inPeriod(t.statusChangedAt))
        .length;
    if (paused == 0 && deleted == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, 0),
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const ArchiveScreen()),
        ),
        child: Text(
          l.histPausedDeleted(paused, deleted),
          style: AppText.caption.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }

  Future<void> _pickPeriod() async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PeriodSheet(current: _preset, hasSince: _sinceDate != null),
    );
    if (picked == null || !mounted) return;
    if (picked == 'since') {
      final date = await showDatePicker(
        context: context,
        initialDate: AppStore.today,
        firstDate: DateTime(2024),
        lastDate: AppStore.today,
      );
      if (date != null) {
        setState(() {
          _sinceDate = DateTime(date.year, date.month, date.day);
        });
      }
      return;
    }
    if (picked is HistoryPreset) {
      setState(() {
        _preset = picked;
        _sinceDate = null;
      });
    }
  }
}

class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.current, required this.hasSince});

  final HistoryPreset current;
  final bool hasSince;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String label(HistoryPreset p) => switch (p) {
          HistoryPreset.last7 => l.histLastDays(7),
          HistoryPreset.last20 => l.histLastDays(20),
          HistoryPreset.last30 => l.histLastDays(30),
          HistoryPreset.last90 => l.histLastDays(90),
          HistoryPreset.thisMonth => l.histThisMonth,
          HistoryPreset.lastMonth => l.histLastMonth,
        };

    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Insets.md),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.sheetGrabber,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            for (final p in HistoryPreset.values)
              InkWell(
                onTap: () => Navigator.of(context).pop(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Insets.gutter, vertical: 13),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: (!hasSince && p == current)
                            ? const Icon(Icons.check_rounded,
                                size: 18, color: AppColors.accentLight)
                            : null,
                      ),
                      Text(label(p), style: AppText.rowTitle),
                    ],
                  ),
                ),
              ),
            InkWell(
              onTap: () => Navigator.of(context).pop('since'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.gutter, vertical: 13),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Text(l.histSincePrompt,
                        style: AppText.rowTitle
                            .copyWith(color: AppColors.accentLight)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
  }
}
