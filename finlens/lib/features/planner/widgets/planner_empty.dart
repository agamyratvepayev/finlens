import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../balance/balance_screen.dart' show EmptyState;
import '../../ledger/ledger_screen.dart' show buildFirstRunHint;

/// The Planner's three tabs, for picking each one's icon and copy.
enum PlannerEmptyTab { budgets, goals, schedule }

/// The Planner's first-run empty block, shared by Budgets, Goals and Schedule
/// (spec "Planner first-run tabs"). No pill — the header `+` is the only action,
/// named by the hint line below the text (§4.1/§4.4). The title+message region is
/// pinned to one height derived across all three tabs, so the icon lands on the
/// same y whichever tab is showing and never jumps on a tab switch (§4.3). The
/// whole block centres in the space below the segmented control and scrolls
/// rather than overflowing under large text on a short screen (§4.5).
class PlannerEmptyState extends StatelessWidget {
  const PlannerEmptyState({super.key, required this.tab});

  final PlannerEmptyTab tab;

  /// Icon and nominal size per tab. All three are outlined so they read as one
  /// family, matching the Ledger's first-run glyph (§4.2). The sizes are nudged
  /// individually (within ±2pt of 24) to bring the three glyphs' ink heights
  /// level: the calendar renders a touch short of its box, so it runs at 25.
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
    final scaler = MediaQuery.textScalerOf(context);
    final (icon, iconSize) = _icons[tab]!;
    final (title, message) = _copy(l, tab);

    // A NUL the localized string can never contain, swapped in for `{plus}` so a
    // translation is free to move the glyph; a string that lost the placeholder
    // degrades to plain text with the glyph omitted (§4.4).
    final sentinel = String.fromCharCode(0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The width EmptyState gives its title and message: the block width less
        // its own Insets.xxl gutter on each side. Clamped so a pathological zero
        // width never feeds a negative into layout.
        final textWidth =
            (constraints.maxWidth - Insets.xxl * 2).clamp(0.0, double.infinity);
        final textBlockHeight = _tallestTextBlock(l, textWidth, scaler);

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: EmptyState(
                icon: icon,
                iconSize: iconSize,
                iconBackdrop: true,
                title: title,
                message: message,
                titleAsHeader: true,
                textBlockHeight: textBlockHeight,
                // The hint sits in the action slot, below the fixed text box. It
                // never wraps — a second line would change the block height and
                // undo the shared-height guarantee — so it scales down instead.
                action: FittedBox(
                  fit: BoxFit.scaleDown,
                  child:
                      buildFirstRunHint(l.ldgFirstRunHint(sentinel), sentinel),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The tallest title + message stack across all three tabs at this width and
  /// text scale (§4.3). Measured with the exact styles EmptyState renders, so the
  /// derived height matches what each tab lays out. A locale that runs one message
  /// to an extra line grows the box for all three tabs together, never one alone.
  double _tallestTextBlock(
      AppLocalizations l, double textWidth, TextScaler scaler) {
    final titleStyle = AppText.rowTitle.copyWith(fontSize: 16);
    const messageStyle = AppText.caption;
    var maxTitle = 0.0;
    var maxMessage = 0.0;
    for (final t in PlannerEmptyTab.values) {
      final (title, message) = _copy(l, t);
      final titleH = _measure(title, titleStyle, textWidth, scaler);
      final messageH = _measure(message, messageStyle, textWidth, scaler);
      if (titleH > maxTitle) maxTitle = titleH;
      if (messageH > maxMessage) maxMessage = messageH;
    }
    return maxTitle + Insets.xs + maxMessage;
  }

  double _measure(
      String text, TextStyle style, double maxWidth, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }
}
