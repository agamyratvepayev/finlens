import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/store/app_store.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/range_calendar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// The Ledger tab's PERIOD sheet: a Custom range… row, a year stepper and a
/// single horizontally scrollable month-chip strip, with a custom-range
/// calendar as a second page inside the same sheet.
///
/// Every choice routes through the store (`period` for a month, `applyRangeLens`
/// for a range), so the Ledger's filter/search reset fires identically however
/// the period changed. Opens on the calendar page — pre-filled with the active
/// range — when a lens is already active.
Future<void> showLedgerPeriodSheet(
  BuildContext context,
  AppStore store, {
  bool openOnCalendar = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PeriodSheet(store: store, openOnCalendar: openOnCalendar),
  );
}

class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({required this.store, required this.openOnCalendar});

  final AppStore store;
  final bool openOnCalendar;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late bool _onCalendar = widget.openOnCalendar;

  void _goCalendar() => setState(() => _onCalendar = true);
  void _goPeriod() => setState(() => _onCalendar = false);

  void _pickMonth(DateTime month) {
    widget.store.period = month; // clears any lens through the shared path
    Navigator.of(context).pop();
  }

  void _applyRange(DateTime from, DateTime to) {
    // TO is inclusive: extend it to end-of-day so DateRange.days and the window
    // filter both count the whole final day.
    widget.store.applyRangeLens(
      DateRange(
        DateTime(from.year, from.month, from.day),
        DateTime(to.year, to.month, to.day, 23, 59, 59, 999),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lens = widget.store.rangeLens;
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Period ⇄ Calendar as a horizontal slide, matching the app's
            // stateful sheet-content swap (there is no push-navigation sheet).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) {
                final incoming = child.key == const ValueKey('calendar');
                final begin = Offset(incoming ? 1 : -1, 0);
                return ClipRect(
                  child: SlideTransition(
                    position: Tween(begin: begin, end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                );
              },
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              ),
              child: _onCalendar
                  ? _CalendarPage(
                      key: const ValueKey('calendar'),
                      store: widget.store,
                      initialFrom: lens?.start ?? _seedFrom(),
                      initialTo: lens?.end ?? AppStore.today,
                      onBack: _goPeriod,
                      onApply: _applyRange,
                    )
                  : _PeriodPage(
                      key: const ValueKey('period'),
                      store: widget.store,
                      onCustom: _goCalendar,
                      onPickMonth: _pickMonth,
                    ),
            ),
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
  }

  /// A friendly 4-day starter window: today−3 … today.
  DateTime _seedFrom() =>
      DateTime(AppStore.today.year, AppStore.today.month, AppStore.today.day)
          .subtract(const Duration(days: 3));
}

// ── Period page ──────────────────────────────────────────────────────────────

class _PeriodPage extends StatefulWidget {
  const _PeriodPage({
    super.key,
    required this.store,
    required this.onCustom,
    required this.onPickMonth,
  });

  final AppStore store;
  final VoidCallback onCustom;
  final ValueChanged<DateTime> onPickMonth;

  @override
  State<_PeriodPage> createState() => _PeriodPageState();
}

class _PeriodPageState extends State<_PeriodPage> {
  late int _year = widget.store.period.year;

  /// Has-data months per displayed year — one grouped query per year, cached
  /// for the lifetime of the sheet (never a per-chip scan).
  final Map<int, Set<int>> _monthsWithData = {};

  Set<int> _monthsFor(int year) =>
      _monthsWithData[year] ??= widget.store.ledgerMonthsWithData(year);

  int get _minYear => widget.store.earliestTxnYear;
  int get _maxYear => AppStore.today.year;

  void _stepYear(int delta) {
    final next = _year + delta;
    if (next < _minYear || next > _maxYear) return;
    HapticFeedback.selectionClick();
    setState(() => _year = next);
  }

  @override
  Widget build(BuildContext context) {
    final lens = widget.store.rangeLens;
    return Column(
      key: const ValueKey('period'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('PERIOD'),
        // Custom range… — an accent row that opens the calendar page. While a
        // lens is active it states what is applied: the lens's own label plus a
        // checkmark (the app's selection mark). It still opens the calendar to
        // change the range — clearing lives on the header (§1), not here.
        InkWell(
          onTap: widget.onCustom,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.gutter, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.accentLight),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      lens != null
                          ? lens.label(AppStore.today)
                          : 'Custom range…',
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.accentLight)),
                ),
                if (lens != null) ...[
                  const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.accentLight),
                  const SizedBox(width: Insets.sm),
                ],
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.accentLight),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        const SizedBox(height: Insets.md),
        _yearStepper(),
        const SizedBox(height: Insets.md),
        // Cross-fade the strip on a year step, at constant height.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _MonthStrip(
            key: ValueKey(_year),
            year: _year,
            selectedYear: widget.store.period.year,
            selectedMonth: widget.store.period.month,
            lensActive: widget.store.isRangeLensActive,
            monthsWithData: _monthsFor(_year),
            today: AppStore.today,
            onPick: widget.onPickMonth,
          ),
        ),
      ],
    );
  }

  Widget _yearStepper() {
    final canBack = _year > _minYear;
    final canFwd = _year < _maxYear;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepButton(
          icon: Icons.chevron_left_rounded,
          enabled: canBack,
          semanticLabel: 'Previous year',
          onTap: () => _stepYear(-1),
        ),
        SizedBox(
          width: 92,
          child: Center(
            child: Text(
              '$_year',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        _StepButton(
          icon: Icons.chevron_right_rounded,
          enabled: canFwd,
          semanticLabel: 'Next year',
          onTap: () => _stepYear(1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
    // A disabled bound is absent from the semantics actions entirely.
    if (!enabled) return ExcludeSemantics(child: button);
    return Semantics(button: true, label: semanticLabel, child: button);
  }
}

// ── Month strip ──────────────────────────────────────────────────────────────

class _MonthStrip extends StatefulWidget {
  const _MonthStrip({
    super.key,
    required this.year,
    required this.selectedYear,
    required this.selectedMonth,
    required this.lensActive,
    required this.monthsWithData,
    required this.today,
    required this.onPick,
  });

  final int year;
  final int selectedYear;
  final int selectedMonth;
  final bool lensActive;
  final Set<int> monthsWithData;
  final DateTime today;
  final ValueChanged<DateTime> onPick;

  @override
  State<_MonthStrip> createState() => _MonthStripState();
}

class _MonthStripState extends State<_MonthStrip> {
  static const double _extent = 72; // 64pt chip + 8pt gutter slot
  late final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScroll());
  }

  /// Bring the sensible month into view: the selected month in its own year, or
  /// the nearest end otherwise (December looking back, January looking forward).
  void _autoScroll() {
    if (!_controller.hasClients) return;
    final int index;
    if (widget.year == widget.selectedYear && !widget.lensActive) {
      index = widget.selectedMonth - 1;
    } else if (widget.year < widget.selectedYear) {
      index = 11; // stepped back — land on December
    } else {
      index = 0; // stepped forward — land on January
    }
    final target = (index * _extent - _extent) // one chip of lead-in
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    // A little headroom over the chip's intrinsic height so a 130%-scaled label
    // grows without clipping.
    return SizedBox(
      height: 50,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.05, 0.95, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const _ChipSnapPhysics(_extent),
          itemExtent: _extent,
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          itemCount: 12,
          itemBuilder: (context, i) => _chip(i + 1),
        ),
      ),
    );
  }

  Widget _chip(int month) {
    final isSelected = !widget.lensActive &&
        widget.year == widget.selectedYear &&
        month == widget.selectedMonth;
    final isFuture = widget.year == widget.today.year && month > widget.today.month;
    final hasData = widget.monthsWithData.contains(month);
    final label = monthShort(month);
    final monthDate = DateTime(widget.year, month);

    final Color bg = isSelected
        ? AppColors.accent
        : (isFuture ? Colors.transparent : AppColors.surfaceHigh);
    final Color fg = isSelected
        ? Colors.white
        : isFuture
            ? AppColors.futureDay
            : (hasData ? AppColors.textPrimary : AppColors.textTertiary);

    final chip = Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isFuture ? null : () => widget.onPick(monthDate),
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
              const SizedBox(height: 3),
              // A 3pt accent dot marks a month that holds data (never on the
              // filled selected chip, where it would vanish into the fill).
              SizedBox(
                height: 3,
                child: (hasData && !isSelected && !isFuture)
                    ? Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );

    if (isFuture) return ExcludeSemantics(child: chip);
    return Semantics(
      button: true,
      selected: isSelected,
      label: monthYearLong(monthDate),
      child: chip,
    );
  }
}

/// Snaps the strip so a chip edge always rests at the leading margin.
class _ChipSnapPhysics extends ScrollPhysics {
  const _ChipSnapPhysics(this.itemExtent, {super.parent});

  final double itemExtent;

  @override
  _ChipSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _ChipSnapPhysics(itemExtent, parent: buildParent(ancestor));

  double _target(ScrollMetrics position, double velocity) {
    final v = toleranceFor(position).velocity;
    var page = position.pixels / itemExtent;
    if (velocity < -v) {
      page = page.floorToDouble();
    } else if (velocity > v) {
      page = page.ceilToDouble();
    } else {
      page = page.roundToDouble();
    }
    return (page * itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _target(position, velocity);
    if ((target - position.pixels).abs() < toleranceFor(position).distance) {
      return null;
    }
    return ScrollSpringSimulation(spring, position.pixels, target, velocity,
        tolerance: toleranceFor(position));
  }
}

// ── Calendar page ────────────────────────────────────────────────────────────

class _CalendarPage extends StatelessWidget {
  const _CalendarPage({
    super.key,
    required this.store,
    required this.initialFrom,
    required this.initialTo,
    required this.onBack,
    required this.onApply,
  });

  final AppStore store;
  final DateTime initialFrom;
  final DateTime initialTo;
  final VoidCallback onBack;
  final void Function(DateTime from, DateTime to) onApply;

  @override
  Widget build(BuildContext context) {
    // All txn days across every account — the ledger tab is all-accounts.
    final daysWithTxn = <DateTime>{
      for (final t in store.txns)
        DateTime(t.date.year, t.date.month, t.date.day),
    };

    return Column(
      key: const ValueKey('calendar'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.md, Insets.gutter, 0),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left_rounded,
                          size: 20, color: AppColors.accent),
                      Text('Period',
                          style:
                              TextStyle(fontSize: 15, color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'CUSTOM RANGE',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.66,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Balances the back control so the title stays centred.
              const SizedBox(width: 72),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        RangeCalendar(
          today: AppStore.today,
          initialFrom: initialFrom,
          initialTo: initialTo,
          disableFuture: true,
          // On the Ledger, verifying an empty stretch is a legitimate goal, so
          // Apply stays enabled at n = 0 (a deliberate divergence from the
          // Same-transactions calendar, which disables it there).
          applyEnabledAtZero: true,
          hasData: daysWithTxn.contains,
          countBetween: (from, to) => store
              .txnsInWindow(DateRange(
                DateTime(from.year, from.month, from.day),
                DateTime(to.year, to.month, to.day, 23, 59, 59, 999),
              ))
              .length,
          onApply: onApply,
        ),
      ],
    );
  }
}

// ── Shared bits ──────────────────────────────────────────────────────────────

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            Insets.gutter, Insets.lg, Insets.gutter, Insets.sm),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.66,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
}
