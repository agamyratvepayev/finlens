import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../features/balance/balance_filter.dart';
import '../../features/balance/balance_order.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'amount_text.dart';
import 'app_card.dart';

/// The filter sheet, shared by Balance and Insight (spec §2.3).
///
/// A bottom sheet rather than a pushed page on purpose: the screen behind stays
/// visible, so the user watches the headline figure react as they toggle — the
/// only cue, since the filter button changes nothing but a glyph.
///
/// The sheet renders whatever [sections] and [preview] the caller passes and is
/// otherwise dumb about *what* is being filtered. Balance passes a single
/// account section and its net-worth preview and behaves byte-for-byte as
/// before the extraction; Insight passes three sections (accounts + spending +
/// income) and a preview that mirrors what each moves (spec §2.1/§2.2).
Future<void> showFilterSheet(
  BuildContext context, {
  required List<FilterSectionSpec> sections,
  required Widget preview,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _FilterSheet(sections: sections, preview: preview),
  );
}

/// A thin back-compat shim: the old accounts-only entry point, now a single
/// account section with the Balance-style preview. Kept so callers that only
/// need one account section stay terse.
Future<void> showAccountFilterSheet(
  BuildContext context, {
  required BalanceFilter Function(AppStore) selector,
  required void Function(AppStore, BalanceFilter) onApply,
}) {
  return showFilterSheet(
    context,
    sections: [
      FilterSectionSpec.accounts(
        filter: selector,
        onChanged: onApply,
        groups: defaultBalanceGroups,
      ),
    ],
    preview: AccountFilterPreview(selector: selector),
  );
}

/// The group list Balance shows: the user's arrangement in Custom mode,
/// declaration order otherwise (spec §2.3). Insight overrides this with plain
/// declaration order so its list matches the group grid.
List<AccountGroup> defaultBalanceGroups(AppStore store) {
  final custom = store.balanceSort == AccountSort.custom;
  return <AccountGroup>[
    for (final assets in [true, false])
      ...(custom
          ? store.balanceOrder.orderedCategories(assets: assets)
          : (assets ? AccountGroup.assets : AccountGroup.liabilities)),
  ].where((g) => store.groupCount(g) > 0).toList(growable: false);
}

enum _FilterKind { accounts, categories }

/// One section of the filter sheet. Two shapes, chosen by named constructor:
/// [FilterSectionSpec.accounts] (expandable groups + tri-state, drives a
/// [BalanceFilter]) and [FilterSectionSpec.categories] (flat on/off rows, drives
/// a `Set<String>` of hidden ids). Every accessor is live — the sheet subscribes
/// to the store and re-reads on each build.
class FilterSectionSpec {
  const FilterSectionSpec._(
    this._kind, {
    this.title,
    this.note,
    this.filterOf,
    this.onFilter,
    this.groupsOf,
    this.rowsOf,
    this.hiddenOf,
    this.onHidden,
  });

  final _FilterKind _kind;

  /// Section header text; null renders no header (Balance's single section).
  final String? title;

  /// One-line note beneath the header (spec §2.1); may wrap in `ru`.
  final String? note;

  // Account section.
  final BalanceFilter Function(AppStore)? filterOf;
  final void Function(AppStore, BalanceFilter)? onFilter;
  final List<AccountGroup> Function(AppStore)? groupsOf;

  // Category section.
  final List<(Category, double)> Function(AppStore)? rowsOf;
  final Set<String> Function(AppStore)? hiddenOf;
  final void Function(AppStore, Set<String>)? onHidden;

  factory FilterSectionSpec.accounts({
    String? title,
    String? note,
    required BalanceFilter Function(AppStore) filter,
    required void Function(AppStore, BalanceFilter) onChanged,
    required List<AccountGroup> Function(AppStore) groups,
  }) =>
      FilterSectionSpec._(
        _FilterKind.accounts,
        title: title,
        note: note,
        filterOf: filter,
        onFilter: onChanged,
        groupsOf: groups,
      );

  factory FilterSectionSpec.categories({
    required String title,
    String? note,
    required List<(Category, double)> Function(AppStore) rows,
    required Set<String> Function(AppStore) hidden,
    required void Function(AppStore, Set<String>) onChanged,
  }) =>
      FilterSectionSpec._(
        _FilterKind.categories,
        title: title,
        note: note,
        rowsOf: rows,
        hiddenOf: hidden,
        onHidden: onChanged,
      );

  bool isActive(AppStore s) => _kind == _FilterKind.accounts
      ? filterOf!(s).isActive
      : hiddenOf!(s).isNotEmpty;

  void reset(AppStore s) => _kind == _FilterKind.accounts
      ? onFilter!(s, const BalanceFilter())
      : onHidden!(s, <String>{});
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.sections, required this.preview});

  final List<FilterSectionSpec> sections;
  final Widget preview;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  /// Local-only: which account cards are expanded. Not part of any filter.
  final Set<AccountGroup> _expanded = {};

  @override
  Widget build(BuildContext context) {
    // Subscribes: every toggle re-runs this build so the preview and switches
    // track the live filters, alongside the screen behind.
    final store = StoreScope.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

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
              _headerRow(store),
              widget.preview,
              Flexible(child: _body(store)),
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

  Widget _headerRow(AppStore store) {
    // Reset clears every active section (spec §2.3 — one Reset).
    final canReset = widget.sections.any((s) => s.isActive(store));
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 9),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).filterTitle,
            style: const TextStyle(
              fontSize: 17,
              height: 1.2,
              fontWeight: FontWeight.w600, // 650 rounds to semi-bold
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Opacity(
            opacity: canReset ? 1 : 0.35,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canReset
                  ? () {
                      for (final s in widget.sections) {
                        if (s.isActive(store)) s.reset(store);
                      }
                    }
                  : null,
              child: Text(
                AppLocalizations.of(context).actionReset,
                style: const TextStyle(
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

  Widget _body(AppStore store) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      children: [
        for (final sec in widget.sections) ..._section(store, sec),
      ],
    );
  }

  List<Widget> _section(AppStore store, FilterSectionSpec sec) {
    return [
      if (sec.title != null) _sectionHeader(sec.title!, sec.note),
      if (sec._kind == _FilterKind.accounts)
        ..._accountSection(store, sec)
      else
        ..._categorySection(store, sec),
    ];
  }

  /// A section header with its one explanatory line — the only sentence in the
  /// module that earns its place, teaching a behavioural difference (spec §2.1).
  Widget _sectionHeader(String title, String? note) => Padding(
        padding: EdgeInsets.fromLTRB(8, 12, 8, note == null ? 6 : 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.77,
                color: AppColors.textSecondary,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 3),
              // No maxLines: `ru` may wrap to two lines and must be allowed to
              // (spec §11).
              Text(
                note,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      );

  // ── Account section ──────────────────────────────────────────────────────

  List<Widget> _accountSection(AppStore store, FilterSectionSpec sec) {
    final l = AppLocalizations.of(context);
    final groups = sec.groupsOf!(store);
    final assets = groups.where((g) => g.isAsset).toList(growable: false);
    final liabilities = groups.where((g) => g.isLiability).toList(growable: false);
    return [
      if (assets.isNotEmpty) ...[
        _sublabel(l.balanceSectionAssets.toUpperCase()),
        for (final g in assets) _categoryCard(store, sec, g),
      ],
      if (liabilities.isNotEmpty) ...[
        _sublabel(l.balanceSectionLiabilities.toUpperCase()),
        for (final g in liabilities) _categoryCard(store, sec, g),
      ],
    ];
  }

  Widget _sublabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.77,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _categoryCard(
      AppStore store, FilterSectionSpec sec, AccountGroup group) {
    final l = AppLocalizations.of(context);
    final filter = sec.filterOf!(store);
    final state = filter.toggleState(store, group);
    final accounts = store.balanceSort == AccountSort.custom
        ? store.balanceOrder.orderedAccounts(store, group)
        : store.accountsIn(group);
    final visibleCount = filter.visibleAccounts(store, group).length;
    final expanded = _expanded.contains(group);
    final off = state == ToggleState.off;

    final subtitle = state == ToggleState.mixed
        ? '$visibleCount of ${accounts.length} · '
            '${money(filter.filteredTotal(store, group), masked: store.masked)}'
        : '${l.countAccounts(accounts.length)} · '
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
                                  group.label(l),
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
                  semanticLabel: '${group.label(l)}, ${_stateWord(state, l)}',
                  semanticHint: off ? l.a11yDoubleTapShow : l.a11yDoubleTapHide,
                  onTap: () =>
                      sec.onFilter!(store, filter.toggleGroup(store, group)),
                ),
              ],
            ),
          ),
          if (expanded)
            for (final a in accounts) _accountRow(store, sec, group, a),
        ],
      ),
    );
  }

  Widget _accountRow(
      AppStore store, FilterSectionSpec sec, AccountGroup group, Account a) {
    final filter = sec.filterOf!(store);
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
                semanticLabel:
                    '${a.name}, ${visible ? AppLocalizations.of(context).a11yShown : AppLocalizations.of(context).a11yHidden}',
                onTap: () => sec.onFilter!(store, filter.toggleAccount(store, a)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Category section (flat, on/off) ──────────────────────────────────────

  List<Widget> _categorySection(AppStore store, FilterSectionSpec sec) {
    final rows = sec.rowsOf!(store);
    return [for (final (c, amount) in rows) _categoryRow(store, sec, c, amount)];
  }

  Widget _categoryRow(
      AppStore store, FilterSectionSpec sec, Category c, double amount) {
    final l = AppLocalizations.of(context);
    final hidden = sec.hiddenOf!(store).contains(c.id);
    final amountStr = money(amount, masked: store.masked);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: AppColors.sheetCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          children: [
            _Dimmed(
              dim: hidden,
              child: IconTile(c.icon, color: c.color, size: 28, solid: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Dimmed(
                dim: hidden,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
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
                      amountStr,
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
            const SizedBox(width: 10),
            _TriSwitch(
              state: hidden ? ToggleState.off : ToggleState.on,
              width: 45,
              height: 27,
              knob: 23,
              // Names the amount, per §9.
              semanticLabel:
                  '${c.name}, ${hidden ? l.a11yHidden : l.a11yShown}, $amountStr',
              semanticHint: hidden ? l.a11yDoubleTapShow : l.a11yDoubleTapHide,
              onTap: () {
                final next = {...sec.hiddenOf!(store)};
                hidden ? next.remove(c.id) : next.add(c.id);
                sec.onHidden!(store, next);
              },
            ),
          ],
        ),
      ),
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
          child: Text(
            AppLocalizations.of(context).actionDone,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  static String _stateWord(ToggleState s, AppLocalizations l) => switch (s) {
        ToggleState.on => l.a11yShown,
        ToggleState.mixed => l.a11yPartiallyShown,
        ToggleState.off => l.a11yHidden,
      };
}

/// Balance's preview card, extracted verbatim so its behaviour is unchanged
/// (spec §2.2). Reads the store live, so it tracks toggles like the old inline
/// card did.
class AccountFilterPreview extends StatelessWidget {
  const AccountFilterPreview({super.key, required this.selector});

  final BalanceFilter Function(AppStore) selector;

  static const _previewMeta = TextStyle(
    fontSize: 11,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final filter = selector(store);
    final l = AppLocalizations.of(context);
    final groups = defaultBalanceGroups(store);

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
                Text(
                  l.bfNetWorthFiltered,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.44,
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
              Text(l.bfVisibleCategories(visibleCats, totalCats),
                  style: _previewMeta),
              const SizedBox(height: 2),
              Text(l.bfVisibleAccounts(visibleAccts, totalAccts),
                  style: _previewMeta),
            ],
          ),
        ],
      ),
    );
  }
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
