import 'package:flutter/material.dart';

import 'assets_screen.dart';

/// Spec 1.3 — Liabilities detail. Structurally symmetric with Assets; the
/// difference is the per-row subtitle (utilisation / due date / next payment).
class LiabilitiesScreen extends StatelessWidget {
  const LiabilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GroupDetailScreen(title: 'Liabilities', isAssets: false);
  }
}
