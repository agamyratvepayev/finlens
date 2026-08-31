import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// Mounts a single NoticeBanner at a pinned width so we can measure its own
/// box. `EdgeInsets.zero` margin mirrors the Schedule call site; the width is
/// constrained to model the header gutter.
Widget _banner(
  NoticeBanner banner, {
  double width = 350,
  double scale = 1.0,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: banner),
            ),
          ),
        ),
      ),
    );

void main() {
  const oneLine = '1 payment overdue · \$50';

  // ── The dense banner is a line, not a paragraph: 31 ± 1 pt (§1, §4) ─────────
  testWidgets('dense one-line banner measures 31 ± 1 pt', (tester) async {
    await tester.pumpWidget(_banner(const NoticeBanner(
      margin: EdgeInsets.zero,
      color: AppColors.negative,
      icon: Icons.error_outline_rounded,
      text: oneLine,
      dense: true,
    )));
    await tester.pump();

    final h = tester.getSize(find.byType(NoticeBanner)).height;
    expect(h, closeTo(31.0, 1.0), reason: 'dense: 8+8 padding + 15 pt icon');
  });

  // ── The other two callers are untouched: default stays ~41 pt (§2, §4) ──────
  testWidgets('default one-line banner keeps its original ~41 pt height',
      (tester) async {
    await tester.pumpWidget(_banner(const NoticeBanner(
      margin: EdgeInsets.zero,
      text: oneLine,
    )));
    await tester.pump();

    final h = tester.getSize(find.byType(NoticeBanner)).height;
    expect(h, closeTo(41.0, 1.0),
        reason: 'the default path (task_detail / edit_goal) must not shrink');
  });

  // ── schBannerBoth wraps to two lines at 320 pt — grows, never clips (§3) ─────
  testWidgets('dense schBannerBoth wraps to two lines with no overflow at 320',
      (tester) async {
    final l = AppLocalizationsEn();
    final both = l.schBannerBoth(4, '\$340', '\$120');

    await tester.pumpWidget(_banner(
      NoticeBanner(
        margin: EdgeInsets.zero,
        color: AppColors.negative,
        icon: Icons.error_outline_rounded,
        text: both,
        dense: true,
      ),
      // 320 pt screen minus the header's 20 pt gutters on each side.
      width: 280,
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);

    final para = tester.renderObject<RenderParagraph>(find.text(both));
    expect(para.didExceedMaxLines, isFalse, reason: 'no maxLines → never clips');
    expect(para.size.height, greaterThan(20),
        reason: 'two lines of 12.5/1.15 text ≈ 28.8 pt');

    // The icon sits with the first line, not the middle of the grown box.
    final iconTop =
        tester.getTopLeft(find.byIcon(Icons.error_outline_rounded)).dy;
    final textTop = tester.getTopLeft(find.text(both)).dy;
    expect((iconTop - textTop).abs(), lessThan(6),
        reason: 'crossAxisAlignment.start keeps the icon on the first line');
  });

  // ── Toggling the eye (masking) must not change the banner height (§3) ───────
  testWidgets('masked vs unmasked one-line banner is the same height',
      (tester) async {
    await tester.pumpWidget(_banner(const NoticeBanner(
      margin: EdgeInsets.zero,
      color: AppColors.negative,
      icon: Icons.error_outline_rounded,
      text: '1 payment overdue · ••',
      dense: true,
    )));
    await tester.pump();

    final h = tester.getSize(find.byType(NoticeBanner)).height;
    expect(h, closeTo(31.0, 1.0));
  });
}
