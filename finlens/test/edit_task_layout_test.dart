import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';

/// Regression for the blank Edit-task body: the Direction row's [SegmentedPicker]
/// (a Row of Expanded children) was handed unbounded width by FormRow's unwrapped
/// `trailing` slot, so the whole scroll view failed to lay out and painted nothing.
///
/// `flutter test` hangs on the dev machine — written, not run there; verify with
/// `flutter analyze`. Confirmed to FAIL on the pre-fix code (RenderFlex unbounded
/// width) and PASS once the picker is wrapped in `Flexible`.
void main() {
  Widget wrap(AppStore store, Widget child, {Locale? locale}) => StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  testWidgets(
      'Edit task lays out its full form at 320pt in Turkish — the note field '
      'label proves the body rendered', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(
      buildSeedStore(),
      // k-gym is a recurring (monthly) pay-out task — it exercises the Direction
      // segmented control and the repeat preview.
      const EditTaskScreen(taskId: 'k-gym'),
      locale: const Locale('tr'),
    ));
    await tester.pump();

    // The note field sits in the last FormSection, below the Direction row. If
    // the layout threw, nothing below the top bar renders and this label is absent.
    expect(find.text('Not'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
