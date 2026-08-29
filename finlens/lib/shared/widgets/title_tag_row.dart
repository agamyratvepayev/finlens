import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

/// A transaction row's **title line**: `title · #tag · (slack) · amount`.
///
/// THE TITLE WINS. It is laid out at its natural width first; the tag then
/// takes whatever slack is left before the amount — collapsing from the full
/// run (`#fun #weekend`) to `#fun +1`, and dropping out entirely, *before* the
/// title is allowed to ellipsize. A category name is the row's identity; a tag
/// is a footnote to it, so a whole `#groceries` must never cost a truncated
/// "Transportation".
///
/// This is the deliberate **opposite** of the meta line's rule (there the
/// account — long and incidental — yields so the tag stays whole). Do not
/// "restore consistency" between the two: the protected element is different
/// because what it means is different.
///
/// The tag's cap is the residual slack (`region − titleWidth − gap`), not a
/// fixed percentage like the meta line's 60%. The title now occupies the space
/// the account used to, and it earns all of it before a tag gets any; the tag
/// simply rides whatever remains.
class TitleTagRow extends StatelessWidget {
  const TitleTagRow({
    super.key,
    required this.title,
    required this.titleWidth,
    required this.tags,
    required this.tagStyle,
    required this.buildTag,
    required this.trailing,
    required this.trailingWidth,
    this.trailingGap = 8,
    this.tagGap = 6,
  });

  /// The title widget. Must be able to ellipsize (a plain single-line [Text],
  /// or a small row whose text child ellipsizes). Rendered whole whenever the
  /// tag fits; ellipsized only when even a tag-less title overflows.
  final Widget title;

  /// The title's natural (unconstrained) width — measured by the caller with
  /// [measure], and including anything that must sit inside the title region
  /// (e.g. a no-cash pill), so the tag never eats into it.
  final double titleWidth;

  /// The row's tags. Empty renders the title exactly as before — nothing added.
  final List<String> tags;

  /// The tag run's style; only its size/metrics matter for measuring. The
  /// caller owns the colour (kept at each row's own meta size, in tagDot).
  final TextStyle tagStyle;

  /// Builds the tag run into a single-line widget from the chosen run string,
  /// so the caller keeps its own search-highlighting helper.
  final Widget Function(String run) buildTag;

  /// The fixed figure pinned to the right (the amount, optionally paired with a
  /// running balance). It never yields.
  final Widget trailing;

  /// The natural width of [trailing]. A small cushion is added internally, so a
  /// caller should pass a faithful measurement of what it renders.
  final double trailingWidth;

  /// Gap between the title/tag region and the trailing figure (defaults to the
  /// [Insets.sm] the rows already used).
  final double trailingGap;

  /// Gap between the title and its tag — a single space's worth.
  final double tagGap;

  /// Natural single-line width of [s] as it will actually render here.
  ///
  /// Resolves the ambient [DefaultTextStyle] first: a [Text] merges its style
  /// into that unless `inherit` is false (nothing in this app sets it), so
  /// measuring the bare [style] misses whatever the theme contributes —
  /// letter-spacing above all — and the caller then sizes the title region a
  /// few pixels short, ellipsizing the title with slack still beside it. The
  /// text scaler and direction come from the same [context] too, so the
  /// measurement matches the render exactly.
  static double measure(BuildContext context, String s, TextStyle style) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final tp = TextPainter(
      text: TextSpan(text: s, style: effective),
      textDirection: Directionality.of(context),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return tp.size.width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth;
        // A cushion on the trailing figure absorbs sub-pixel rounding so the
        // row can never overflow by a fraction (the amount must stay whole).
        final region = avail - (trailingWidth + 2) - trailingGap;

        String? run;
        if (tags.isNotEmpty) {
          final runs = tagRunText(tags);
          final budget = region - titleWidth - tagGap;
          final fullW = measure(context, runs.full, tagStyle);
          if (fullW <= budget) {
            run = runs.full;
          } else {
            final collapsedW = measure(context, runs.collapsed, tagStyle);
            if (collapsedW <= budget) run = runs.collapsed;
          }
          // Otherwise run stays null: no room for even the collapsed tag beside
          // a whole title, so the tag drops and the title takes the region.
        }

        if (run == null) {
          // No tag (or dropped): the title owns the whole region and
          // ellipsizes only if it must.
          return Row(
            // Two type sizes side by side read on their baseline, not their
            // centres — matching the title/amount pairing this replaces.
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: title),
              SizedBox(width: trailingGap),
              trailing,
            ],
          );
        }

        // A tag is shown. The title and tag form one group sized to its own
        // intrinsic width, and the amount is pinned right by `spaceBetween`,
        // which drops all the residual slack between the tag and the amount.
        //
        // The title is `Flexible.loose` (never `Expanded`): it renders whole
        // whenever it fits and never stretches to shove the tag toward the
        // amount. It sits INSIDE the group so its flex competes only with its
        // own tag — never with the amount-pinning — so it is not capped to a
        // share of the whole row and cannot be truncated while slack remains.
        // (That measured-width pin — the old `ConstrainedBox(titleWidth + 0.5)`
        // — was the truncation defect: the rendered text drifts a fraction past
        // its own measurement and overflowed a box sized to fit it exactly. The
        // measurement above now only chooses the run, never sizes the render.)
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(fit: FlexFit.loose, child: title),
                  SizedBox(width: tagGap),
                  buildTag(run),
                ],
              ),
            ),
            trailing,
          ],
        );
      },
    );
  }
}
