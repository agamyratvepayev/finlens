import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/undo_bar.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run this yourself:
//   flutter test test/undo_bar_test.dart
//
// The helper carries the two things every undo bar in this app must get right:
// persist: false (so a Flutter 3.37+ actionable bar still auto-dismisses) and
// one shared window. These tests pin both, plus the appear/dismiss/undo cycle.

Future<void> _pumpHost(
  WidgetTester tester, {
  required VoidCallback onUndo,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () =>
                showUndoBar(context, message: 'Moved', onUndo: onUndo),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('the bar is built with persist: false and undoBarWindow',
      (tester) async {
    await _pumpHost(tester, onUndo: () {});
    await tester.tap(find.text('show'));
    await tester.pump(); // build the SnackBar

    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.persist, isFalse,
        reason: 'an actionable bar must opt back into auto-dismiss');
    expect(bar.duration, undoBarWindow);
    expect(find.text('Moved'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('the message is wrapped in a liveRegion for screen readers',
      (tester) async {
    await _pumpHost(tester, onUndo: () {});
    await tester.tap(find.text('show'));
    await tester.pump();

    // The helper wraps the message Text directly in Semantics(liveRegion: true);
    // the closest Semantics ancestor of the text is that wrapper.
    final wrapper = tester.widget<Semantics>(
      find
          .ancestor(of: find.text('Moved'), matching: find.byType(Semantics))
          .first,
    );
    expect(wrapper.properties.liveRegion, isTrue);
  });

  testWidgets('left alone, the bar auto-dismisses after the window',
      (tester) async {
    await _pumpHost(tester, onUndo: () {});
    await tester.tap(find.text('show'));
    await tester.pump(); // enter animation begins
    expect(find.byType(SnackBar), findsOneWidget);

    // Past the window; then let the exit animation run.
    await tester.pump(undoBarWindow);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('tapping Undo fires the callback and closes the bar',
      (tester) async {
    var undone = 0;
    await _pumpHost(tester, onUndo: () => undone++);
    await tester.tap(find.text('show'));
    await tester.pump();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.byType(SnackBar), findsNothing);
  });
}
