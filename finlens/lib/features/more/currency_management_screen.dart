import 'package:flutter/material.dart';

import '../../core/models/currency_def.dart';
import '../../core/models/models.dart' show BaseCurrencyChange;
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';
import 'reporting_currency_sheet.dart';

/// More → Data → Currencies (currency-sheet spec §1). Data you set up once and
/// later correct, which is exactly what the Categories and Tags screens beside
/// it are for — so this is modelled on them rather than invented.
///
/// The screen shows **no monetary figure**. The trailing slot used to carry the
/// add-form's formatting sample (`formatCurrencyExample(def, 9850)`); on a
/// screen of account-shaped rows a right-aligned `$9,850.00` reads as a balance,
/// and it never was one. The trailing slot now carries facts only — whether a
/// row is the base currency, and a chevron — and the one number on the row is
/// the account count, in the subtitle.
///
/// Two sections:
///   - **IN USE** — every code the base-currency setting, an account or a
///     transaction names. Ordered base-first, then by account count, then code.
///     A custom currency that is in use lives here, not below.
///   - **ADDED, NOT USED** — custom currencies nothing references. Absent when
///     empty; it is the only group anything can be deleted from (in the picker).
///
/// Editing does **not** live here beyond the row tap: the destructive edit form
/// is reached by tapping a row (or, in `pickCurrency`, by swiping it).
class CurrencyManagementScreen extends StatelessWidget {
  const CurrencyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    final base = store.baseCurrency;
    int accountsFor(String code) => store.accountsUsingCurrency(code).length;

    // IN USE: account ∪ transaction codes, **excluding the base** (it lives in
    // REPORTING now — 021a §3a), ordered by account count descending, then code.
    final inUseCodes = store.currencyCodesInUse()
        .where((c) => c != base)
        .toList()
      ..sort((a, b) {
        final byCount = accountsFor(b).compareTo(accountsFor(a));
        if (byCount != 0) return byCount;
        return a.compareTo(b);
      });
    final inUse = inUseCodes.map(currencyDef).toList();

    // ADDED, NOT USED: custom currencies referenced by nothing (not base, no
    // account, no transaction). The section is absent when empty (§1.3).
    final inUseSet = {...inUseCodes, base};
    final addedNotUsed = [
      for (final def in store.snapshotCustomCurrencies)
        if (!inUseSet.contains(def.code)) def,
    ];

    final lastChange = store.lastBaseCurrencyChange;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: l.curListTitle,
              showBack: true,
              showAdd: true,
              onAdd: () => showAddCurrencySheet(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  // REPORTING — the base currency, every total is shown in it
                  // (021a §3a). Tapping it opens the reporting-currency switch.
                  SectionLabel(l.curSectionReporting),
                  AppCard(
                    child: _CurrencyRow(
                      def: currencyDef(base),
                      isReporting: true,
                      inUse: true,
                      lastChange: lastChange,
                      onTap: () => showReportingCurrencySheet(context),
                    ),
                  ),
                  if (inUse.isNotEmpty) ...[
                    SectionLabel(l.curSectionInUse),
                    _CurrencyCard(defs: inUse, base: base, inUse: true),
                  ],
                  if (addedNotUsed.isNotEmpty) ...[
                    SectionLabel(l.curSectionAdded),
                    _CurrencyCard(defs: addedNotUsed, base: base, inUse: false),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section's card of currency rows, split by hairlines with none after the
/// last (the card's own clip rounds the strip).
class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    required this.defs,
    required this.base,
    required this.inUse,
  });

  final List<CurrencyDef> defs;
  final String base;

  /// Whether these rows are in-use currencies (a missing rate shows `Set rate`)
  /// or merely added-not-used ones (a missing rate shows nothing — 021a §3b).
  final bool inUse;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < defs.length; i++) ...[
            if (i > 0) const RowDivider(indent: 48),
            _CurrencyRow(
              def: defs[i],
              inUse: inUse,
              onTap: () => showEditCurrencySheet(context, defs[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// One currency row — **40 pt** tall at 100 % text scale (intrinsic, so it grows
/// rather than clips at 130 %). Anatomy shared with the picker's row (§1.2 /
/// §2.3): symbol tile, name over `{code} · {usage}`, a fact in the trailing slot.
///
/// The trailing figure this replaces was `formatCurrencyExample(def, 9850)`, the
/// add-form's sample. The slot now carries the base marker and a chevron only;
/// the usage count is the one number, and it moved into the subtitle.
/// One currency row (021a §3b). The trailing slot carries the rate against the
/// reporting currency, with the date it was set stacked beneath it; the base
/// currency's row shows `Every total` there instead, and an in-use currency
/// with no rate shows `Set rate` in [AppColors.warning].
class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.def,
    required this.inUse,
    required this.onTap,
    this.isReporting = false,
    this.lastChange,
  });

  final CurrencyDef def;

  /// In-use currencies show `Set rate` when unrated; not-in-use ones show
  /// nothing — the rule is only about what a total needs (021a §3b).
  final bool inUse;

  /// The base currency's row: shows `Every total` and the last reporting switch.
  final bool isReporting;
  final BaseCurrencyChange? lastChange;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = StoreScope.of(context);

    final subtitle = isReporting && lastChange != null
        ? '${def.code} · ${l.curReportingFromOn(lastChange!.from, dayMonth(lastChange!.at, l))}'
        : (isOverriddenBuiltIn(def.code)
            ? '${def.code} · ${l.curEdited}'
            : def.code);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${def.name}, $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: 6,
          ),
          child: Row(
            children: [
              _SymbolTile(def: def),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: def.name,
                          style: AppText.body.copyWith(
                            fontSize: 13,
                            height: 1.25,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (def.custom)
                          TextSpan(
                            text: '  ${l.curCustom.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppColors.accentLight,
                            ),
                          ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        fontSize: 10.5,
                        height: 1.25,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RateSlot(def: def, inUse: inUse, isReporting: isReporting, store: store),
              const Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: AppColors.textQuaternary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The trailing rate + date (021a §3b).
class _RateSlot extends StatelessWidget {
  const _RateSlot({
    required this.def,
    required this.inUse,
    required this.isReporting,
    required this.store,
  });

  final CurrencyDef def;
  final bool inUse;
  final bool isReporting;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (isReporting) {
      return Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(
          l.curEveryTotal,
          style: AppText.caption.copyWith(
              fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    final rate = store.rateFor(def.code);
    if (rate == null) {
      // A currency in use with no rate leads the reader to the fix; one not in
      // use shows nothing — a total does not need it (021a §3b).
      if (!inUse) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(
          l.curSetRate,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.warning),
        ),
      );
    }

    final setAt = store.rateSetAt(def.code);
    final dateLabel = setAt == null
        ? ''
        : (_sameDay(setAt, store.today) ? l.curToday : dayMonth(setAt, l));
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatRate(rate),
            style: AppText.amount.copyWith(
                fontSize: 14, color: AppColors.textPrimary),
          ),
          if (dateLabel.isNotEmpty)
            Text(
              dateLabel,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// The currency's own token — `$`, `m`, `TMT` — on a neutral tile. It is the
/// thing this screen configures, so it re-renders the moment the symbol changes;
/// a cleared symbol falls back to the code (a code takes the smaller size so a
/// three-letter token still fits).
class _SymbolTile extends StatelessWidget {
  const _SymbolTile({required this.def});

  final CurrencyDef def;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        def.token,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: AppText.body.copyWith(
          fontSize: def.token.length > 2 ? 9.5 : 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
