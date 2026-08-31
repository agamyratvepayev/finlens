import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/app_card.dart';
import 'package:finlens/theme/app_colors.dart';

/// Goal card — the target moves under the amount. Line one is name + current
/// amount; line two is verdict + the figure it is measured against, right-
/// aligned beneath the amount with no connector. `flutter test` hangs on the
/// dev machine, so these are written, not run here; verify with `flutter
/// analyze` and run the file yourself.
void main() {
  Widget wrap(
    AppStore store, {
    Locale? locale,
    double textScale = 1.0,
  }) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, w) => MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: w!,
          ),
          home: const PlannerScreen(),
        ),
      );

  Future<void> openGoals(WidgetTester tester) async {
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
  }

  /// The card wrapping a goal, located by its name.
  Finder cardFor(String name) => find
      .ancestor(of: find.text(name), matching: find.byType(AppCard))
      .first;

  /// The dim reference figure (§2): rowSubtitle at 11.5 painted in tertiary —
  /// the verdict shares the metrics but never the colour, so this is unique to
  /// the denominator. Scoped to one card.
  Finder denominatorIn(String name) => find.descendant(
        of: cardFor(name),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.style?.fontSize == 11.5 &&
              w.style?.color == AppColors.textTertiary,
        ),
      );

  /// The container Semantics label composed for the screen reader.
  String? semanticsLabelFor(WidgetTester tester, String name) {
    final s = tester.widgetList<Semantics>(find.byType(Semantics)).where(
        (w) => (w.properties.label ?? '').startsWith('$name,'));
    return s.isEmpty ? null : s.first.properties.label;
  }

  void iphoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556); // 393pt @ dpr 3
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('a saving goal renders its target underneath the amount',
      (tester) async {
    iphoneView(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store));
    await openGoals(tester);

    final goal = store.goals.firstWhere((g) => g.name == 'House Deposit');
    final m = store.goalMetrics(goal);
    // Saving → the whole is the target.
    expect(m.section, GoalSection.saving);
    final wholeStr = money(m.target, signless: true);

    expect(denominatorIn('House Deposit'), findsOneWidget);
    expect(tester.widget<Text>(denominatorIn('House Deposit')).data, wholeStr);
  });

  testWidgets(
      'a paying-off goal renders its original amount underneath, never \$0',
      (tester) async {
    iphoneView(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store));
    await openGoals(tester);

    final goal = store.goals.firstWhere((g) => g.name == 'Main Credit Card');
    final m = store.goalMetrics(goal);
    expect(m.section, GoalSection.payingOff);
    // The target is 0; the whole is the original debt (§3). Signless: the
    // liability's start is negative.
    final wholeStr = money(m.start, signless: true);
    expect(wholeStr, isNot(money(0)));

    final denom = denominatorIn('Main Credit Card');
    expect(denom, findsOneWidget);
    expect(tester.widget<Text>(denom).data, wholeStr);
    expect(tester.widget<Text>(denom).data, isNot('\$0'));
  });

  testWidgets(
      'a waiting-on goal with nothing collected shows one figure, not two',
      (tester) async {
    iphoneView(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store));
    await openGoals(tester);

    final goal = store.goals.firstWhere((g) => g.name == 'Client Invoice #104');
    final m = store.goalMetrics(goal);
    expect(m.section, GoalSection.waitingOn);
    // Nothing collected yet → current == start → the second line is omitted.
    expect(money(m.current, signless: true), money(m.start, signless: true));

    expect(denominatorIn('Client Invoice #104'), findsNothing);
  });

  testWidgets('a one-figure card is the same height as a two-figure card',
      (tester) async {
    iphoneView(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store));
    await openGoals(tester);

    final twoFigure = tester.getSize(cardFor('House Deposit')).height;
    final oneFigure = tester.getSize(cardFor('Client Invoice #104')).height;
    // Two text lines and a bar either way — dropping the reference figure must
    // not shrink the card. State the number so a future change trips this.
    expect(oneFigure, closeTo(twoFigure, 0.5));
  });

  testWidgets(
      'the long name Freelance Side Income renders in full at 393pt '
      '(no ellipsis truncation)', (tester) async {
    iphoneView(tester);
    await tester.pumpWidget(wrap(buildSeedStore()));
    await openGoals(tester);

    final name = find.text('Freelance Side Income');
    expect(name, findsOneWidget);
    // The name no longer shares its line with the target, so it fits whole.
    final para = tester.renderObject<RenderParagraph>(name);
    expect(para.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the semantics label carries "of" for a two-figure card and drops it '
      'for a one-figure card', (tester) async {
    iphoneView(tester);
    await tester.pumpWidget(wrap(buildSeedStore()));
    await openGoals(tester);

    final twoFig = semanticsLabelFor(tester, 'House Deposit');
    expect(twoFig, isNotNull);
    expect(twoFig, contains(' of '));

    final oneFig = semanticsLabelFor(tester, 'Client Invoice #104');
    expect(oneFig, isNotNull);
    expect(oneFig, isNot(contains(' of ')));
  });

  testWidgets(
      'no overflow at 320pt in Turkish with a seven-figure denominator',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    // Push the whole to seven figures on a long-named saving goal — the tightest
    // case the spec pins (§4, §7).
    store.goals.firstWhere((g) => g.name == 'House Deposit').targetAmount =
        12000000;

    await tester.pumpWidget(wrap(store, locale: const Locale('tr')));
    await openGoals(tester);

    expect(tester.takeException(), isNull);
  });
}
