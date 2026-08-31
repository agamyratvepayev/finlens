import 'package:flutter/material.dart';

import '../../../shared/widgets/account_filter_sheet.dart';

/// Opens the Balance category & account filter.
///
/// The sheet itself now lives in [showAccountFilterSheet] (shared with Insight,
/// spec §9). Balance wires its own `balanceFilter`/`setBalanceFilter` pair, so
/// its behaviour, copy, ordering and counts are unchanged by the extraction.
Future<void> showBalanceFilterSheet(BuildContext context) {
  return showAccountFilterSheet(
    context,
    selector: (store) => store.balanceFilter,
    onApply: (store, filter) => store.setBalanceFilter(filter),
  );
}
