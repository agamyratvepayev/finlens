import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/archive_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';

/// §6.1 — a cancelled (skipped) one-off task is an *outcome*, not something you
/// bring back, so it belongs under UNFINISHED — never under a "completed"
/// heading (the old code mislabelled it as COMPLETED TASKS with a "Cancelled"
/// subtitle). Written against the new grouping.
void main() {
  Widget wrap(AppStore store, Widget child) => StoreScope(
        store: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  testWidgets('a cancelled one-off task renders under UNFINISHED',
      (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    final task = store.addTask(
      title: 'One-off registration',
      linkedAccountId: store.accounts.first.id,
      expectedAmount: 50,
      dueDate: DateTime(2026, 8, 1),
      icon: Icons.receipt_long_rounded,
    );
    store.skipTask(task);

    // The store places it in completedTasks with a skipped status…
    expect(
        store.completedTasks
            .where((t) => t.status == TaskStatus.skipped)
            .map((t) => t.id),
        contains(task.id));

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(wrap(store, const ArchiveScreen()));
    await tester.pumpAndSettle();

    // …and the screen files it under UNFINISHED, with a "cancelled" subtitle.
    expect(find.text(l.arGroupUnfinished.toUpperCase()), findsOneWidget);
    expect(find.text('One-off registration'), findsOneWidget);
    expect(find.textContaining('cancelled'), findsWidgets);

    // The retired "completed" heading is gone.
    expect(find.textContaining('COMPLETED'), findsNothing);
  });
}
