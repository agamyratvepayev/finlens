import '../../core/models/models.dart';

/// One calendar day's rendered ledger rows, and whether its net is worth
/// printing (spec §4).
///
/// [txns] is exactly what the list draws for the day — the Ledger groups *after*
/// filtering and search — so [total] is always the sum of the rendered rows and
/// can never disagree with them. That is why the "show the net" rule is purely
/// count-based: with grouping done post-filter there is no separate cached total
/// for a narrowed view to contradict.
class LedgerDay {
  LedgerDay(this.date);

  final DateTime date;
  final List<Txn> txns = [];

  /// The day's net. Transfers and revaluations move nothing net (spec §4 / §6.2)
  /// so they contribute 0 — while still counting as one row toward the
  /// threshold below.
  double get total => txns.fold<double>(0, (sum, t) {
        return switch (t.type) {
          TxnType.expense => sum - t.amount,
          TxnType.income => sum + t.amount,
          _ => sum,
        };
      });

  /// Print the net only when the reader cannot get it at a glance (spec §4):
  ///
  /// | rows | reader's work                            | show? |
  /// |------|------------------------------------------|-------|
  /// | 0    | group would not render                   | no    |
  /// | 1    | nothing — the header would copy the row  | no    |
  /// | 2    | one subtraction, both operands adjacent  | no    |
  /// | 3+   | real summation across mixed signs        | yes   |
  ///
  /// The rule is count-based, never value-based: three or more rows always show
  /// the net, even when it happens to equal one row's amount or nets to zero, so
  /// a busy day can always be trusted to state its net.
  bool get showsDayTotal => txns.length > 2;
}
