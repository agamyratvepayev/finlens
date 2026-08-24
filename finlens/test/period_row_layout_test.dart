import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finlens/l10n/app_localizations_en.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/ledger/widgets/period_row.dart';
import 'package:finlens/theme/app_theme.dart';

/// The chip is one widget shared by every ledger scope, so these mount it
/// directly rather than through a screen — a scope only changes the numbers
/// handed in, and the question here is about the chip's own layout.
Widget _chip(
  AppStore store, {
  required double totalIn,
  required double totalOut,
  TextScaler scaler = TextScaler.noScaling,
}) {
  return StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: PeriodRow(
              range: RangePreset.thisMonth.resolve(AppStore.today),
              totalIn: totalIn,
              totalOut: totalOut,
              filter: null,
              onStep: (_) {},
              onPickRange: () {},
              onFilter: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// `getRect(PeriodRow)` measures the widget including its own 16 horizontal
/// margin, so the trailing figure's glyphs stop 16 + 4 (chip padding) + 8 (the
/// figure's own padding, which draws its active pill) short of that edge.
/// On screen the visible gap inside the chip is therefore 12.
const _trailingInset = 16 + 4 + 8;

void main() {
  testWidgets('the figures sit at the chip trailing edge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _chip(buildSeedStore(), totalIn: 6100, totalOut: 2500),
    );
    await tester.pump();

    final chip = tester.getRect(find.byType(PeriodRow));
    final out = tester.getRect(find.text(moneyCompact(2500)));

    expect(chip.right - out.right, closeTo(_trailingInset, 1.5));
  });

  testWidgets('the navigation group stays at the leading edge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _chip(buildSeedStore(), totalIn: 6100, totalOut: 2500),
    );
    await tester.pump();

    final chip = tester.getRect(find.byType(PeriodRow));
    final label = tester.getRect(
      find.text(
        RangePreset.thisMonth.resolve(AppStore.today).label(AppStore.today, AppLocalizationsEn()),
      ),
    );

    // Margin 16 + the back arrow's 28 + 4 of label padding = 48. The label has
    // not drifted rightwards into the space the figures gave up.
    expect(label.left - chip.left, closeTo(52, 2));
  });

  /// The two ledger scopes differ only in the numbers they hand in, so the chip
  /// must place its trailing edge identically for both.
  testWidgets('every scope places the figures identically', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gaps = <double>[];
    // Group scope and account scope, as they read against the seed data.
    for (final pair in [(6100.0, 2500.0), (6100.0, 2200.0)]) {
      await tester.pumpWidget(
        _chip(buildSeedStore(), totalIn: pair.$1, totalOut: pair.$2),
      );
      await tester.pump();
      final chip = tester.getRect(find.byType(PeriodRow));
      final out = tester.getRect(find.text(moneyCompact(pair.$2)));
      gaps.add(chip.right - out.right);
    }
    expect(gaps.first, closeTo(gaps.last, 0.5));
  });

  testWidgets('no overflow at any supported width, default scale',
      (tester) async {
    for (final width in [390.0, 360.0, 320.0]) {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _chip(buildSeedStore(), totalIn: 6100, totalOut: 2500),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  /// Text-scale headroom, measured rather than assumed.
  ///
  /// The chip cannot survive iOS's largest accessibility size at any width —
  /// two figures at 13.5pt scaled 3.1x are wider than the chip on their own,
  /// and neither the font sizes nor the compact `$6.1K` form may be traded away
  /// to buy the room. That limit predates this widget's current layout; these
  /// values only pin the headroom that does exist so it cannot silently shrink.
  ///
  /// Recorded thresholds (scale at which overflow first appears):
  ///   width  before  after
  ///   390     1.45    1.55
  ///   360     1.20    1.35
  ///   320     1.05    1.05
  group('text-scale headroom', () {
    const safe = <(double width, double scale)>[
      (390, 1.50),
      (360, 1.30),
      (320, 1.00),
    ];

    for (final entry in safe) {
      testWidgets('holds to ${entry.$2}x at ${entry.$1.toInt()}pt',
          (tester) async {
        tester.view.physicalSize = Size(entry.$1, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _chip(
            buildSeedStore(),
            totalIn: 6100,
            totalOut: 2500,
            scaler: TextScaler.linear(entry.$2),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
