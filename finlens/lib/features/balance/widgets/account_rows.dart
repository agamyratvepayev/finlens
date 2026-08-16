import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/store/app_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Left indent that lines child labels up under the group name:
/// gutter (20) + icon (34) + gap (12).
const kChildIndent = 66.0;

/// Group header — icon, name, "N accounts", amount and share.
///
/// The row carries two tap targets, because one tap cannot both expand the
/// group and open its ledger:
///
///  * everything up to 8px before the amount block toggles open/closed;
///  * the amount block, that 8px gap and the trailing gutter open the ledger.
///
/// The boundary sits inside the gap rather than flush against the number: a
/// thumb aimed at the amount lands slightly left of centre more often than
/// right, so an imprecise tap still navigates. The left zone (~250pt) has the
/// width to give away.
class GroupRow extends StatelessWidget {
  const GroupRow({
    super.key,
    required this.group,
    required this.total,
    required this.count,
    required this.share,
    this.isOpen = false,
    this.onToggle,
    this.onOpenLedger,
    this.onLongPress,
  });

  final AccountGroup group;
  final double total;
  final int count;
  final double share;

  /// Announced to VoiceOver — the toggle has to report what it will do.
  final bool isOpen;

  final VoidCallback? onToggle;
  final VoidCallback? onOpenLedger;

  /// Long-press offers "Add account to `<group>`" — account creation lives in
  /// contextual places, never as a permanent row in this list. It stays on the
  /// name side so it cannot fight the ledger tap.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final shareColor =
        group.isLiability ? AppColors.negative : AppColors.positive;
    final masked = StoreScope.of(context).masked;
    final countLabel = '$count ${count == 1 ? 'account' : 'accounts'}';

    return ColoredBox(
      // The wash spans the full row so it is unambiguous which group the
      // accounts underneath belong to.
      color: isOpen ? const Color(0x0FFFFFFF) : const Color(0x00000000),
      child: Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            expanded: isOpen,
            label: '${group.label}, $countLabel, '
                '${money(total, signless: true, masked: masked)}, '
                '${percent(share)}',
            child: PressZone(
              onTap: onToggle,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, 10, 0, 10),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      IconTile(group.icon,
                          color: group.color,
                          size: 34,
                          circle: true,
                          solid: true),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.label,
                              style: AppText.groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(countLabel, style: AppText.accountCount),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: '${group.label} transactions',
          child: PressZone(
            onTap: onOpenLedger,
            child: Padding(
              // The 8px lead-in belongs to this zone — that is the whole point
              // of putting the boundary in the gap rather than on the number.
              padding: const EdgeInsets.fromLTRB(
                Insets.sm,
                10,
                Insets.gutter,
                10,
              ),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText.balance(
                      total,
                      style: AppText.groupAmount,
                      color:
                          group.isLiability ? AppColors.amountGroupNeg : null,
                    ),
                    const SizedBox(height: 2),
                    // The chevron rides the percentage line, never the amount
                    // line: group and child amounts share one right edge at
                    // 20px, and that alignment is why this list dropped
                    // chevrons in the first place. The percentage has no
                    // counterpart in the child rows, so it is the only line
                    // that can carry one without moving the number column.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          percent(share),
                          style:
                              AppText.sharePercent.copyWith(color: shareColor),
                        ),
                        // Shown only where the tap exists: GroupRow is reused
                        // on the Assets/Liabilities screens, which have no
                        // ledger to open, and an affordance that does nothing
                        // is worse than none.
                        if (onOpenLedger != null) ...[
                          const SizedBox(width: 4),
                          const _GroupChevron(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

/// The 9px affordance on the percentage line. Drawn rather than taken from the
/// icon font so the 1.9 stroke is exact — at this size a font glyph's hinting
/// makes the weight unpredictable, which is the same reason the nav icons are
/// hand-drawn.
class _GroupChevron extends StatelessWidget {
  const _GroupChevron();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 9,
        height: 9,
        child: CustomPaint(painter: _ChevronPainter()),
      );
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3F3F43)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(3.0, 1.6)
        ..lineTo(6.2, 4.5)
        ..lineTo(3.0, 7.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}

/// Press feedback bounded to a single tap zone.
///
/// This is the split's main teaching mechanism: the first press shows the user
/// the row has two halves, which a 9px chevron alone will not. The wash
/// therefore has to stop at the zone's edge rather than cover the row.
///
/// On is instant, off takes 120ms — a fade-in would lag the finger at exactly
/// the moment the user is learning where the boundary is.
class PressZone extends StatefulWidget {
  const PressZone({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressZone> createState() => _PressZoneState();
}

class _PressZoneState extends State<PressZone> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: _pressed ? Duration.zero : const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0xFFFFFFFF).withValues(alpha: 0.055)
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Child account row — ~26px against the group row's 54px. That ratio alone
/// communicates subordination, so no tint or connecting line is needed.
///
/// Split the same way the group row is, on the same rule: left is the thing,
/// right is its money. The name asks *what is this* and opens the account's
/// page; the amount asks *where did this come from* and opens its ledger.
class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.account,
    required this.balance,
    this.subtitle,
    this.subtitleColor,
    this.onOpenAccount,
    this.onOpenLedger,
    this.onTap,
  });

  final Account account;
  final double balance;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenLedger;

  /// The Assets/Liabilities detail screens still use one whole-row target.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final masked = StoreScope.of(context).masked;

    final name = Padding(
      padding: const EdgeInsets.fromLTRB(kChildIndent, 4, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            account.name,
            style: AppText.childName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppText.accountCount.copyWith(
                fontSize: 11.5,
                color: subtitleColor ?? AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );

    final amount = Padding(
      // The 8px lead-in belongs to the money side, same as the group row.
      padding: const EdgeInsets.fromLTRB(Insets.sm, 4, Insets.gutter, 4),
      child: AmountText.balance(
        balance,
        currency: account.currency,
        style: AppText.childAmount,
        color: account.isLiability ? AppColors.amountChildNeg : null,
      ),
    );

    // Whole-row form, for the screens that have only one destination.
    if (onOpenAccount == null && onOpenLedger == null) {
      final content = Row(children: [Expanded(child: name), amount]);
      return onTap == null ? content : InkWell(onTap: onTap, child: content);
    }

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: account.name,
            child: PressZone(
              onTap: onOpenAccount,
              child: ExcludeSemantics(child: name),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: '${account.name} transactions, '
              '${money(balance, signless: true, masked: masked)}',
          child: PressZone(
            onTap: onOpenLedger,
            child: ExcludeSemantics(child: amount),
          ),
        ),
      ],
    );
  }
}

/// Subtitle under a liability child row: utilisation for cards, due date for
/// payables, next payment for loans (spec 1.3).
({String? text, Color? color}) liabilitySubtitle(AppStore store, Account a) {
  switch (a.group) {
    case AccountGroup.creditCards:
      final u = store.utilisationOf(a.id);
      return (
        text: u == null ? null : 'Utilization: ${percent(u, decimals: 0)}',
        color: null,
      );
    case AccountGroup.payables:
      if (a.paymentDue == null) return (text: null, color: null);
      final due = DateTime(
        AppStore.today.year,
        AppStore.today.month,
        a.paymentDue!,
      );
      final days = due
          .difference(DateTime(
            AppStore.today.year,
            AppStore.today.month,
            AppStore.today.day,
          ))
          .inDays;
      // Spec 1.3 — the label warms up as the due date approaches.
      final color = days < 3 ? AppColors.negative : AppColors.warning;
      return (text: days < 0 ? 'Overdue' : 'Due ${dueLabel(days)}', color: color);
    case AccountGroup.bankLoans:
      if (a.paymentDue == null) return (text: null, color: null);
      final next = DateTime(
        AppStore.today.year,
        AppStore.today.month + (a.paymentDue! < AppStore.today.day ? 1 : 0),
        a.paymentDue!,
      );
      return (text: 'Next payment: ${dayMonthYear(next)}', color: null);
    default:
      return (text: null, color: null);
  }
}
