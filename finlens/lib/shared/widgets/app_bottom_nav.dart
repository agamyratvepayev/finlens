import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'nav_icons.dart';

/// The five modules (spec 1.1). Order is fixed.
enum NavTab {
  balance('Balance', NavGlyph.balance),
  ledger('Ledger', NavGlyph.ledger),
  planner('Planner', NavGlyph.planner),
  insight('Insight', NavGlyph.insight),
  more('More', NavGlyph.more);

  const NavTab(this.label, this.glyph);

  final String label;
  final NavGlyph glyph;
}

/// A badge on a tab. `count == null` renders the dot form.
class NavBadge {
  const NavBadge.dot() : count = null;
  const NavBadge.count(this.count);

  final int? count;
}

/// Bottom navigation: 56px plus the bottom safe-area inset as padding.
///
/// State is carried by icon fill and colour rather than a box behind the active
/// tab — the rest of the app is flat typography with minimal fills, and a
/// filled pill made the bar shout over the content it navigates.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onChanged,
    this.onReselected,
    this.badges = const {},
  });

  final NavTab current;
  final ValueChanged<NavTab> onChanged;

  /// Tapping the already-active tab scrolls that page's list to the top.
  final ValueChanged<NavTab>? onReselected;

  final Map<NavTab, NavBadge> badges;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final tab in NavTab.values)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab == current,
                    badge: badges[tab],
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (tab == current) {
                        onReselected?.call(tab);
                      } else {
                        onChanged(tab);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;
  final NavBadge? badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.selected ? AppColors.accentSoft : AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.tab.label,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          // The whole bar height is the touch target.
          child: SizedBox(
            height: AppBottomNav.height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TweenAnimationBuilder<Color?>(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      tween: ColorTween(end: color),
                      builder: (context, value, _) => NavIcon(
                        glyph: widget.tab.glyph,
                        filled: widget.selected,
                        color: value ?? color,
                      ),
                    ),
                    if (widget.badge != null)
                      Positioned(
                        top: -3,
                        right: -6,
                        child: _Badge(badge: widget.badge!),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.navLabel.copyWith(
                    color: color,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final NavBadge badge;

  @override
  Widget build(BuildContext context) {
    if (badge.count == null) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.negative,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 1.5),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.negative,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      child: Text(
        badge.count! > 99 ? '99+' : '${badge.count}',
        style: const TextStyle(
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
