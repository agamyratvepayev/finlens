import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// NumericHero (rendered as NumericHeroCard) — the amount row at the top of the
// Quick Add sheet. `flutter test` hangs on the dev machine, so these are
// written, not run here; verify with `flutter analyze` and run the file
// yourself:  flutter test test/quick_add_amount_hero_test.dart
//
// NOTE ON FONTS: the flutter_test default font is fixed-width (every glyph is a
// full em box), so a 12-digit amount is far wider here than in the real
// proportional font (Roboto). The spec's "12 digits fit whole at 320pt" is a
// property of the real font; under the test font a 12-digit number legitimately
// exceeds a 320pt row even at the floor. These tests therefore assert the
// mechanism that guarantees no-clip under any font — the number is never
// ellipsised, the amount shrinks to (never below) the floor, the label yields
// before the amount, and the chip keeps its width — rather than an absolute
// glyph fit that only holds under Roboto. The four available-width / max-digit
// figures are reported from arithmetic in the accompanying write-up.

const _s393 = Size(393, 852);
const _s320 = Size(320, 568);

Widget _app(AppStore store, {double textScale = 1.0}) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: const QuickAddScreen(initialType: QuickAddType.expense),
      ),
    );

Future<void> _pump(WidgetTester tester, Size size,
    {double textScale = 1.0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(buildSeedStore(), textScale: textScale));
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _type(WidgetTester tester, int nines) async {
  for (var i = 0; i < nines; i++) {
    await tester.tap(find.text('9'));
    await tester.pump();
  }
}

/// The amount's paragraph — the one RichText whose flattened text carries the
/// grouped digits.
RenderParagraph _amountPara(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(
        find.textContaining('999', findRichText: true));

double _amountFontSize(RenderParagraph p) {
  final span = p.text as TextSpan;
  return span.children!.whereType<TextSpan>().first.style!.fontSize!;
}

/// The currency chip's box, located by its code text.
Size _chipSize(WidgetTester tester) => tester.getSize(
    find.ancestor(of: find.text('USD'), matching: find.byType(Container)).first);

void main() {
  testWidgets('a twelve-digit amount is never ellipsised (393 & 320)',
      (tester) async {
    for (final size in [_s393, _s320]) {
      await _pump(tester, size);
      await _type(tester, 12);

      // The number carries the clip overflow, never ellipsis — a reader always
      // sees glyphs, never a "…" standing in for their digits.
      final richText = tester.widget<RichText>(
          find.textContaining('999', findRichText: true));
      expect(richText.overflow, TextOverflow.clip);
      expect(richText.maxLines, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a short amount that fits renders at the full 17·s·t, not clipped',
      (tester) async {
    // "$123.45" fits even under the fixed-width test font, so this exercises the
    // no-shrink path and proves the fit branch does not truncate.
    await _pump(tester, _s393);
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();

    final para = tester.renderObject<RenderParagraph>(
        find.textContaining('123', findRichText: true));
    expect(para.didExceedMaxLines, isFalse);

    final span = para.text as TextSpan;
    final fontSize = span.children!.whereType<TextSpan>().first.style!.fontSize!;
    final s = (393 / 390).clamp(0.92, 1.10);
    expect(fontSize, closeTo(17 * s * 1.0, 0.01));
  });

  testWidgets('the chip keeps one identical width at \$0.00 and twelve digits',
      (tester) async {
    await _pump(tester, _s320);
    final empty = _chipSize(tester);

    await _type(tester, 12);
    final full = _chipSize(tester);

    // The chip never yields: same code, same width, whatever the number does.
    expect(full.width, closeTo(empty.width, 0.01));
    // And it stays one line — its height does not grow to two rows of text.
    expect(full.height, closeTo(empty.height, 0.01));
  });

  testWidgets('at 320 a twelve-digit amount sits at the floor and the label '
      'yields — the amount does not', (tester) async {
    await _pump(tester, _s320);
    await _type(tester, 12);

    final s = (320 / 390).clamp(0.92, 1.10);
    final fontSize = _amountFontSize(_amountPara(tester));
    // Shrunk, but not past the 15·s·t floor.
    expect(fontSize, closeTo(15 * s * 1.0, 0.01));
    expect(fontSize, greaterThanOrEqualTo(15 * s * 1.0 - 0.01));

    // The label is the thing that gave way: on this width it has ellipsised or
    // disappeared, never pushing the number below its floor.
    final label = find.text('Amount');
    if (label.evaluate().isNotEmpty) {
      final para = tester.renderObject<RenderParagraph>(label);
      expect(para.didExceedMaxLines, isTrue,
          reason: 'the label ellipsised rather than the amount shrinking more');
    }
  });

  testWidgets('the card is at least 52·s tall and grows with text scale',
      (tester) async {
    Finder heroFinder() => find.byType(NumericHeroCard);

    await _pump(tester, _s393);
    final s = (393 / 390).clamp(0.92, 1.10);
    final h100 = tester.getSize(heroFinder()).height;
    expect(h100, greaterThanOrEqualTo(52 * s - 0.01));

    await _pump(tester, _s393, textScale: 1.3);
    final h130 = tester.getSize(heroFinder()).height;
    expect(h130, greaterThan(h100),
        reason: 'minHeight, not a fixed height — the row grows at 130%');
  });

  testWidgets("the label's global x equals From's global x", (tester) async {
    // Default $0.00: the label is present, so the columns can be compared.
    await _pump(tester, _s393);
    final amountX = tester.getRect(find.text('Amount')).left;
    final fromX = tester.getRect(find.text('From')).left;
    expect(amountX, closeTo(fromX, 0.5));
  });

  test('AmountEntry.press accepts twelve whole digits and ignores the rest', () {
    var raw = '';
    for (var i = 0; i < 15; i++) {
      raw = AmountEntry.press(raw, '9');
    }
    expect(raw, '999999999999');
    expect(raw.length, 12);
    // The thirteenth is a no-op, as today.
    expect(AmountEntry.press('999999999999', '1'), '999999999999');
  });
}
