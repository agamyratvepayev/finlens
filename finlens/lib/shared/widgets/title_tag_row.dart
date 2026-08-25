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

  /// Natural single-line width of [s] in [style] at the ambient [scaler].
  /// Identical to the row's own render path, so the measurement is exact.
  static double measure(String s, TextStyle style, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: scaler,
    )..layout();
    return tp.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);

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
          final fullW = measure(runs.full, tagStyle, scaler);
          if (fullW <= budget) {
            run = runs.full;
          } else {
            final collapsedW = measure(runs.collapsed, tagStyle, scaler);
            if (collapsedW <= budget) run = runs.collapsed;
          }
          // Otherwise run stays null: no room for even the collapsed tag beside
          // a whole title, so the tag drops and the title takes the region.
        }

        final children = <Widget>[
          if (run == null)
            // No tag (or dropped): the title owns the whole region and
            // ellipsizes only if it must.
            Expanded(child: title)
          else ...[
            // Capped to its natural width so the tag hugs it with one gap
            // rather than being shoved to the right by an expanding title.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: titleWidth + 0.5),
              child: title,
            ),
            SizedBox(width: tagGap),
            buildTag(run),
            // Eat the remaining slack so the amount stays pinned right.
            const Spacer(),
          ],
          SizedBox(width: trailingGap),
          trailing,
        ];

        return Row(
          // Two type sizes side by side read on their baseline, not their
          // centres — matching the title/amount pairing this replaces.
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: children,
        );
      },
    );
  }
}
