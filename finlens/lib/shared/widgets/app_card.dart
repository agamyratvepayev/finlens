import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// The rounded surface every list and panel sits on.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color,
    this.margin,
    this.radius = Radii.card,
    this.border,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final BoxBorder? border;

  /// Set to [Clip.antiAlias] when children paint to the edges — swipe-action
  /// rows, for instance, must not bleed past the rounded corners.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: child,
    );
  }
}

/// Rounded square holding a category/account glyph, tinted with its own colour.
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    required this.color,
    this.size = 36,
    this.iconSize,
    this.circle = false,
    this.solid = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final bool circle;

  /// Solid tiles are used for group headers; tinted ones for child rows.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : AppColors.tint(color, 0.18),
        borderRadius: BorderRadius.circular(circle ? size / 2 : size * 0.3),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.52,
        color: solid ? Colors.white : color,
      ),
    );
  }
}

/// Hairline used between rows inside a card.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: indent,
      color: AppColors.divider,
    );
  }
}
