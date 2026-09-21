/// The Planner forecast (task 057). Plain data read by the forecast row and,
/// later, the Forecast screen (task 058). The engine lives in `AppStore`
/// (`forecastTo`) because it needs the store's spendable/net-worth aggregates
/// and its FX conversion; these types carry only the result.
library;

/// Which kind of planned thing a [ForecastLine] came from. Recurrences of one
/// task are a single line with a [ForecastLine.count] > 1.
enum ForecastKind { scheduled, budget, goal, overdue }

/// What the Planner's forecast row and (task 058) the Forecast screen read.
/// Every figure is in the reporting currency; a **null** lens means a rate was
/// missing somewhere inside it and the figure must not be shown (021a §2) — the
/// row renders `Rate missing` in its place.
class ForecastResult {
  const ForecastResult({
    required this.start,
    required this.end,
    required this.spendableToday,
    required this.netWorthToday,
    required this.spendable,
    required this.netWorth,
    required this.spendableBelowZero,
    required this.spendableByDay,
    required this.netWorthByDay,
    required this.lines,
    required this.missingRateCodes,
  });

  /// Always today (at day granularity).
  final DateTime start;

  /// The chosen date, inclusive.
  final DateTime end;

  /// Today's figures — null-propagating, exactly like `balanceInBase`.
  final double? spendableToday;
  final double? netWorthToday;

  /// The two lenses at [end]. Null when a rate was missing inside the lens.
  final double? spendable;
  final double? netWorth;

  /// The first day the running spendable balance goes below zero, or null when
  /// it never does within the window.
  final DateTime? spendableBelowZero;

  /// One entry per day, `start..end` inclusive — 058 draws the curve. A null
  /// entry mirrors a silenced lens.
  final List<double?> spendableByDay;
  final List<double?> netWorthByDay;

  /// What moved, aggregated — 058 lists it.
  final List<ForecastLine> lines;

  /// The in-use currency codes with no rate that silenced a lens.
  final List<String> missingRateCodes;

  /// Whole days from [start] to [end]; a same-day forecast is 0.
  int get days => end.difference(start).inDays;
}

/// One aggregated cause of movement. Recurrences of a single task collapse into
/// one line carrying their [count].
class ForecastLine {
  const ForecastLine({
    required this.kind,
    required this.refId,
    required this.name,
    required this.amount,
    required this.count,
    required this.inSpendable,
    required this.inNetWorth,
  });

  final ForecastKind kind;

  /// The task / budget / goal id this line came from.
  final String refId;
  final String name;

  /// Signed, reporting currency — the total across [count] occurrences.
  final double amount;

  /// How many occurrences are aggregated into this line.
  final int count;

  /// Whether this line moves the Spendable lens.
  final bool inSpendable;

  /// Whether this line moves the Net worth lens.
  final bool inNetWorth;
}
