import 'package:flutter/material.dart';

import '../../core/store/app_store.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../balance/balance_screen.dart';
import '../insight/insight_screen.dart';
import '../ledger/ledger_screen.dart';
import '../more/more_screen.dart';
import '../planner/planner_screen.dart';

/// Root scaffold: the five modules behind a persistent bottom nav.
///
/// Detail screens (Assets, Account Detail, Archive…) are pushed on the root
/// navigator so they cover the bar — matching the "push navigation" wording in
/// specs 1.2/1.4/5.8.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavTab _tab = NavTab.balance;

  /// Bumped to ask the visible page to scroll itself back to the top when its
  /// already-active tab is tapped again.
  int _scrollToTopSignal = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final overdue = store.overdueTasks.length;

    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          BalanceScreen(scrollToTopSignal: _scrollToTopSignal),
          const LedgerScreen(),
          const PlannerScreen(),
          const InsightScreen(),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: _tab,
        onChanged: (t) => setState(() => _tab = t),
        onReselected: (_) => setState(() => _scrollToTopSignal++),
        badges: {
          // Spec 5.3 — overdue obligations are the first real use of badges.
          if (overdue > 0) NavTab.planner: NavBadge.count(overdue),
        },
      ),
    );
  }
}
