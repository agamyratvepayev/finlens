import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/store/app_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../balance_filter.dart';
import '../balance_order.dart';

/// Opens the Balance category & account filter.
///
/// A bottom sheet rather than a pushed page on purpose: the Balance screen
/// stays visible behind it, so the user watches Net Worth react as they toggle
/// — the only cue, since the filter button changes nothing but a glyph.
Future<void> showBalanceFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _BalanceFilterSheet(),
  );
}

class _BalanceFilterSheet extends StatefulWidget {
  const _BalanceFilterSheet();

  @override
  State<_BalanceFilterSheet> createState() => _BalanceFilterSheetState();
}

class _BalanceFilterSheetState extends State<_BalanceFilterSheet> {
  /// Local-only: which category cards are expanded. Not part of the filter.
  final Set<AccountGroup> _expanded = {};

  void _apply(BalanceFilter next) =>
      StoreScope.read(context).setBalanceFilter(next);

  @override
  Widget build(BuildContext context) {
    // Subscribes: every toggle re-runs this build so the preview and switches
    // track the live filter, alongside the screen behind.
    final store = StoreScope.of(context);
    final filter = store.balanceFilter;
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    // Same order the Balance list uses, so the two surfaces agree (spec §6):
    // the user's arrangement in Custom mode, declaration order otherwise.
    final custom = store.balanceSort == AccountSort.custom;
    final groups = <AccountGroup>[
      for (final assets in [true, false])
        ...(custom
            ? store.balanceOrder.orderedCategories(assets: assets)
            : (assets ? AccountGroup.assets : AccountGroup.liabilities)),
    ].where((g) => store.groupCount(g) > 0).toList(growable: false);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: ColoredBox(
          color: AppColors.surfaceAlt,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _grabber(),
              _headerRow(filter),
              _previewCard(store, filter, groups),
              Flexible(child: _body(store, filter, groups)),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grabber() => Container(
        width: 36,
        height: 5,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: AppColors.sheetGrabber,
          borderRadius: BorderRadius.circular(999),
        ),
      );

  Widget _headerRow(BalanceFilter filter) {
    final canReset = filter.isActive;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 9),
      child: Row(
        children: [
          const Text(
            'Filter',
            style: TextStyle(
              fontSize: 17,
              height: 1.2,
              fontWeight: FontWeight.w600, // 650 rounds to semi-bold
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // Disabled = 35% and inert when nothing is hidden.
          Opacity(
            opacity: canReset ? 1 : 0.35,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canReset ? () => _apply(const BalanceFilter()) : null,
              child: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The one place the user learns what the filter costs — required, not
  /// optional, because the button itself is silent.
  Widget _previewCard(
      AppStore store, BalanceFilter filter, List<AccountGroup> groups) {
    final totalCats = groups.length;
    final visibleCats =
        groups.where((g) => filter.isGroupVisible(store, g)).length;
    var totalAccts = 0;
    var visibleAccts = 0;
    for (final g in groups) {
      totalAccts += store.accountsIn(g).length;
      visibleAccts += filter.visibleAccounts(store, g).length;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sheetCard,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NET WORTH · FILTERED',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.44, // 0.04em @ 11pt
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                AmountText.balance(
                  filter.netWorth(store),
                  style: AppText.groupAmount.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$visibleCats of $totalCats categories',
                  style: _previewMeta),
              const SizedBox(height: 2),
              Text('$visibleAccts of $totalAccts accounts', style: _previewMeta),
            ],
          ),
        ],
      ),
    );
  }

  static const _previewMeta = TextStyle(
    fontSize: 11,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  Widget _body(
      AppStore store, BalanceFilter filter, List<AccountGroup> groups) {
    final assets = groups.where((g) => g.isAsset).toList(growable: false);
    final liabilities =
        groups.where((g) => g.isLiability).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      children: [
        if (assets.isNotEmpty) ...[
          _sectionLabel('ASSETS'),
          for (final g in assets) _categoryCard(store, filter, g),
        ],
        if (liabilities.isNotEmpty) ...[
          _sectionLabel('LIABILITIES'),
          for (final g in liabilities) _categoryCard(store, filter, g),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600, // 650
            letterSpacing: 0.77, // 0.07em @ 11pt
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _categoryCard(
      AppStore store, BalanceFilter filter, AccountGroup group) {
    final state = filter.toggleState(store, group);
    // Accounts in the same order the Balance list shows them (spec §6).
    final accounts = store.balanceSort == AccountSort.custom
        ? store.balanceOrder.orderedAccounts(store, group)
        : store.accountsIn(group);
    final visibleCount = filter.visibleAccounts(store, group).length;
    final expanded = _expanded.contains(group);
    final off = state == ToggleState.off;

    final subtitle = state == ToggleState.mixed
        ? '$visibleCount of ${accounts.length} · '
            '${money(filter.filteredTotal(store, group), masked: store.masked)}'
        : '${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'} · '
            '${money(store.groupTotal(group), masked: store.masked)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: AppColors.sheetCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() =>
                        expanded ? _expanded.remove(group) : _expanded.add(group)),
                    child: Row(
                      children: [
                        // Off dims the caret/icon/name/subtitle but never the
                        // switch — a hidden row must stay discoverable.
                        _Dimmed(
                          dim: off,
                          child: AnimatedRotation(
                            turns: expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _Dimmed(
                          dim: off,
                          child: IconTile(
                            group.icon,
                            color: group.color,
                            size: 28,
                            solid: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Dimmed(
                            dim: off,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  group.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.2,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _TriSwitch(
                  state: state,
                  width: 45,
                  height: 27,
                  knob: 23,
                  semanticLabel: '${group.label}, ${_stateWord(state)}',
                  semanticHint:
                      'Double tap to ${off ? 'show' : 'hide'} all accounts',
                  onTap: () => _apply(filter.toggleGroup(store, group)),
                ),
              ],
            ),
          ),
          if (expanded)
            for (final a in accounts) _accountRow(store, filter, group, a),
        ],
      ),
    );
  }

  Widget _accountRow(
      AppStore store, BalanceFilter filter, AccountGroup group, Account a) {
    final visible = filter.visibleAccounts(store, group).contains(a);
    return Column(
      children: [
        Container(height: 1, color: AppColors.sheetRowDivider),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 11, 6),
          child: Row(
            children: [
              Expanded(
                child: _Dimmed(
                  dim: !visible,
                  child: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      color: AppColors.sheetAccountName,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _Dimmed(
                dim: !visible,
                child: Text(
                  money(store.balanceOf(a.id),
                      currency: a.currency, masked: store.masked),
                  style: AppText.groupAmount.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _TriSwitch(
                state: visible ? ToggleState.on : ToggleState.off,
                width: 38,
                height: 22,
                knob: 18,
                semanticLabel: '${a.name}, ${visible ? 'shown' : 'hidden'}',
                onTap: () => _apply(filter.toggleAccount(store, a)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(top: BorderSide(color: AppColors.sheetRowDivider)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        11,
        16,
        13 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 47,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  static String _stateWord(ToggleState s) => switch (s) {
        ToggleState.on => 'shown',
        ToggleState.mixed => 'partially shown',
        ToggleState.off => 'hidden',
      };
}

/// Fades a subtree to 35% when its row is off, over 200ms. The switch is
/// deliberately kept outside this so a hidden row stays operable.
class _Dimmed extends StatelessWidget {
  const _Dimmed({required this.dim, required this.child});

  final bool dim;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: dim ? 0.35 : 1,
        duration: const Duration(milliseconds: 200),
        child: child,
      );
}

/// A three-state switch. Flutter's [Switch] can't centre its knob, which the
/// `mixed` state needs, so it is hand-built. Track colour and knob position
/// animate together over 220ms.
class _TriSwitch extends StatelessWidget {
  const _TriSwitch({
    required this.state,
    required this.onTap,
    required this.width,
    required this.height,
    required this.knob,
    this.semanticLabel,
    this.semanticHint,
  });

  final ToggleState state;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double knob;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final track = switch (state) {
      ToggleState.on => AppColors.positive,
      ToggleState.mixed => AppColors.accent,
      ToggleState.off => AppColors.sheetGrabber,
    };
    final align = switch (state) {
      ToggleState.on => Alignment.centerRight,
      ToggleState.mixed => Alignment.center,
      ToggleState.off => Alignment.centerLeft,
    };

    return Semantics(
      button: true,
      label: semanticLabel,
      hint: semanticHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: width,
          height: height,
          padding: EdgeInsets.all((height - knob) / 2),
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: align,
            child: Container(
              width: knob,
              height: knob,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
