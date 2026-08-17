import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A transfer row's title: `{Source} → {Destination}` on one line.
///
/// Two [Flexible] texts share the width equally so a long name on one side
/// never eats the other's space; both ellipsize rather than one tail vanishing.
/// The arrow is a muted connector (never a word or an icon), and it resolves
/// from the ambient [Directionality] — `→` in LTR, `←` in RTL — while the [Row]
/// mirrors naturally so it always points source → destination in reading order.
class TransferTitleText extends StatelessWidget {
  const TransferTitleText({
    super.key,
    required this.from,
    required this.to,
    required this.style,
  });

  final String from;
  final String to;

  /// The row title's existing size/weight/colour — the names inherit it; only
  /// the arrow is recoloured.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final arrow = rtl ? '←' : '→';
    Widget side(String name) => Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        );

    // Fill the available width so the two Flexible names can split it equally
    // and ellipsize; a min-size row would starve them and overflow.
    return Row(
      children: [
        side(from),
        Text(' $arrow ', style: style.copyWith(color: AppColors.textSecondary)),
        side(to),
      ],
    );
  }
}
