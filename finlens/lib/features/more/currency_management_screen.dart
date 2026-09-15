import 'package:flutter/material.dart';

import '../../core/models/currency_def.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';

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

    // IN USE: base ∪ account codes ∪ transaction codes, ordered base-first, then
    // by account count descending, then by code. Custom currencies in use are
    // listed here (they no longer split off into a second group), so no
    // de-duplication is needed — each code appears once.
    final inUseCodes = store.currencyCodesInUse()
      ..sort((a, b) {
        if (a == b) return 0;
        if (a == base) return -1;
        if (b == base) return 1;
        final byCount = accountsFor(b).compareTo(accountsFor(a));
        if (byCount != 0) return byCount;
        return a.compareTo(b);
      });
    final inUse = inUseCodes.map(currencyDef).toList();

    // ADDED, NOT USED: custom currencies referenced by nothing (not base, no
    // account, no transaction). The section is absent when empty (§1.3).
    final inUseSet = inUseCodes.toSet();
    final addedNotUsed = [
      for (final def in store.snapshotCustomCurrencies)
        if (!inUseSet.contains(def.code)) def,
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: l.curListTitle,
              showBack: true,
              showEye: false,
              showAdd: true,
              // The existing corner `+` (HeaderCircleButton, accent) opens the
              // existing add sheet — no second add flow. The store notifies on
              // create, so this screen rebuilds with the new row in place.
              onAdd: () => showAddCurrencySheet(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  if (inUse.isNotEmpty) ...[
                    SectionLabel(l.curSectionInUse),
                    _CurrencyCard(
                      defs: inUse,
                      base: base,
                      accountsFor: accountsFor,
                    ),
                  ],
                  if (addedNotUsed.isNotEmpty) ...[
                    SectionLabel(l.curSectionAdded),
                    _CurrencyCard(
                      defs: addedNotUsed,
                      base: base,
                      accountsFor: accountsFor,
                    ),
                  ],
                  // The screen's most important sentence: somebody arrives here
                  // looking for exchange rates; this tells them there are none
                  // before they hunt. Rendered whatever the sections compute to,
                  // so a store with only the base currency still carries it.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.gutter,
                      Insets.lg,
                      Insets.gutter,
                      0,
                    ),
                    child: Text(
                      l.curDisplayNote,
                      style: AppText.caption.copyWith(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
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
    required this.accountsFor,
  });

  final List<CurrencyDef> defs;
  final String base;
  final int Function(String) accountsFor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < defs.length; i++) ...[
            if (i > 0) const RowDivider(indent: 48),
            _CurrencyRow(
              def: defs[i],
              isBase: defs[i].code == base,
              accountCount: accountsFor(defs[i].code),
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
class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.def,
    required this.isBase,
    required this.accountCount,
  });

  final CurrencyDef def;
  final bool isBase;
  final int accountCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final usage = l.curUsageAccounts(accountCount);
    // Name, code, usage and base state announced as one label (§5); the row's
    // own descendants are excluded so the reader hears it once, coherently.
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: isBase
          ? '${def.name}, ${def.code}, $usage, ${l.curBase}'
          : '${def.name}, ${def.code}, $usage',
      child: InkWell(
        // Tapping a row opens the edit form — the same sheet the picker's swipe
        // reaches.
        onTap: () => showEditCurrencySheet(context, def),
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
                    // The name truncates; the CUSTOM label sits outside its flex
                    // box so it never gives way (§5).
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
                      '${def.code} · $usage',
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
              if (isBase) ...[
                const _BaseBadge(),
                const SizedBox(width: 5),
              ],
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

/// The `BASE` marker — a pill in accent @ 20 %, the label in [AppColors
/// .accentLight]. It only **reports**: the base currency is chosen in
/// More ▸ Preferences and stays chosen there, so tapping it does nothing distinct
/// from tapping the row.
class _BaseBadge extends StatelessWidget {
  const _BaseBadge();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l.curBase.toUpperCase(),
        maxLines: 1,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.accentLight,
        ),
      ),
    );
  }
}
