import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task047_equals_key_colors_test.dart
//
// Task 047 §1 — the passive `=` wears the operator pill (sheetCard) with a grey
// glyph (textSecondary), so the operator row reads as five equal keys on every
// host. The active `=` (the state `52 + 8` produces) is unchanged: an accent
// fill with a white glyph.

Widget _host({required bool canResolve}) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: NumericKeypad(
          onKey: (_) {},
          onBackspace: () {},
          onOperator: (_) {},
          onEquals: () {},
          canResolve: canResolve,
        ),
      ),
    );

/// The `=` pill: the Container wrapping the `=` glyph.
Color _equalsPillColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .ancestor(of: find.text('='), matching: find.byType(Container))
        .first,
  );
  return (container.decoration as BoxDecoration).color!;
}

Color _equalsGlyphColor(WidgetTester tester) =>
    tester.widget<Text>(find.text('=')).style!.color!;

void main() {
  testWidgets('passive = wears the operator pill (sheetCard) with a grey glyph',
      (tester) async {
    await tester.pumpWidget(_host(canResolve: false));
    await tester.pump();
    expect(_equalsPillColor(tester), AppColors.sheetCard);
    expect(_equalsGlyphColor(tester), AppColors.textSecondary);
  });

  testWidgets('active = is an accent fill with a white glyph (unchanged)',
      (tester) async {
    await tester.pumpWidget(_host(canResolve: true));
    await tester.pump();
    expect(_equalsPillColor(tester), AppColors.accent);
    expect(_equalsGlyphColor(tester), AppColors.textPrimary);
  });
}
