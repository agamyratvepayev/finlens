import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../balance/balance_screen.dart' show FirstRunBlock;
import '../../ledger/ledger_screen.dart' show buildFirstRunHint;

/// The Planner's three tabs, for picking each one's icon and copy.
enum PlannerEmptyTab { budgets, goals, schedule }

/// The Planner's first-run empty block, shared by Budgets, Goals and Schedule.
/// No pill — the header `+` is the only action, named by the hint line below the
/// text (§4). The block itself is laid out by the shared [FirstRunBlock], which
/// centres it against the whole tab body so its icon lands on the same y as
/// Balance's and the Ledger's, and on the same y across the three tabs — the
/// title+message and fourth-row heights are derived once across all five
/// first-run screens (§1–§4). This widget only picks the per-tab icon and copy.
///
/// It is placed in a `Positioned.fill` behind the Planner's header and segmented
/// control (see `PlannerScreen.build`); the chrome paints over it rather than
/// pushing it down.
class PlannerEmptyState extends StatelessWidget {
  const PlannerEmptyState({super.key, required this.tab});

  final PlannerEmptyTab tab;

  /// Icon and nominal size per tab. All three are outlined so they read as one
  /// family, matching the Ledger's first-run glyph (§4.2). The sizes are nudged
  /// individually (within ±2pt of 24) to bring the three glyphs' ink heights
  /// level: the calendar renders a touch short of its box, so it runs at 25.
  /// The nudge changes the glyph, never its centre — the 54pt backdrop is
  /// centred, so the icon's centre y is the block's whatever the glyph's size.
  static const Map<PlannerEmptyTab, (IconData, double)> _icons = {
    PlannerEmptyTab.budgets: (Icons.pie_chart_outline_rounded, 24),
    PlannerEmptyTab.goals: (Icons.outlined_flag_rounded, 24),
    PlannerEmptyTab.schedule: (Icons.event_available_rounded, 25),
  };

  (String, String) _copy(AppLocalizations l, PlannerEmptyTab t) => switch (t) {
    PlannerEmptyTab.budgets => (l.plNoBudgetsYet, l.plNoBudgetsMsg),
    PlannerEmptyTab.goals => (l.plNoGoalsYet, l.plNoGoalsMsg),
    PlannerEmptyTab.schedule => (l.plNothingScheduled, l.plNothingSchedMsg),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, iconSize) = _icons[tab]!;
    final (title, message) = _copy(l, tab);

    // A NUL the localized string can never contain, swapped in for `{plus}` so a
    // translation is free to move the glyph; a string that lost the placeholder
    // degrades to plain text with the glyph omitted (§4.4).
    final sentinel = String.fromCharCode(0);

    return FirstRunBlock(
      icon: icon,
      iconSize: iconSize,
      title: title,
      message: message,
      // The hint sits in the reserved fourth-row box, below the text. It never
      // wraps — a second line would change the block height and undo the
      // shared-height guarantee — so it scales down instead.
      action: FittedBox(
        fit: BoxFit.scaleDown,
        child: buildFirstRunHint(l.ldgFirstRunHint(sentinel), sentinel),
      ),
    );
  }
}
