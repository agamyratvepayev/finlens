import 'package:flutter/material.dart';

import '../../core/models/currency_def.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';

/// More → Data → Currencies (spec §1). Data you set up once and later correct,
/// which is exactly what the Categories and Tags screens beside it are for — so
/// this is modelled on them rather than invented.
///
/// Editing does **not** live in `pickCurrency`: a picker opened mid-flow is the
/// wrong home for a destructive action, and it stays a picker.
///
/// Two sections, no pills:
///   - **IN USE** — every built-in an account or a transaction names, plus the
///     base currency. Not all 180 ISO codes: this lists what the store touches.
///   - **ADDED BY YOU** — every custom currency.
///
/// A currency that is both custom and in use appears under ADDED BY YOU **only**,
/// never twice.
class CurrencyManagementScreen extends StatelessWidget {
  const CurrencyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    final custom = store.snapshotCustomCurrencies;
    final customCodes = {for (final c in custom) c.code};
    // The de-duplication rule: a code with an override belongs to ADDED BY YOU,
    // so IN USE drops it rather than listing it a second time.
    final inUse = [
      for (final code in store.currencyCodesInUse())
        if (!customCodes.contains(code)) currencyDef(code),
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
              showAdd: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  if (inUse.isNotEmpty) ...[
                    SectionLabel(l.curSectionInUse),
                    AppCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < inUse.length; i++) ...[
                            if (i > 0) const RowDivider(indent: 58),
                            _CurrencyRow(def: inUse[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (custom.isNotEmpty) ...[
                    SectionLabel(l.curSectionAdded),
                    AppCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < custom.length; i++) ...[
                            if (i > 0) const RowDivider(indent: 58),
                            _CurrencyRow(def: custom[i]),
                          ],
                        ],
                      ),
                    ),
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

/// One currency — 49 dp tall, 30 dp badge. The shape of an account row: leading
/// badge, name over subtitle, value right, chevron.
class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({required this.def});

  final CurrencyDef def;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // `· Edited` only where a custom override shadows a built-in of the same
    // code. A pill was tried and rejected: it competed with the code for
    // attention, and the code is what identifies the row.
    final subtitle = isOverriddenBuiltIn(def.code)
        ? '${def.code} · ${l.curEdited}'
        : def.code;

    return InkWell(
      onTap: () => showEditCurrencySheet(context, def),
      child: SizedBox(
        height: 49,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Row(
            children: [
              // The badge carries the currency's own token — `$`, `m`, `TMT`.
              // It is the thing this screen configures, so it re-renders the
              // moment the symbol changes; with the symbol cleared it falls back
              // to the code (§6).
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  def.token,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppText.body.copyWith(
                    fontSize: def.token.length > 2 ? 10.5 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      def.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              // The live preview. Reading it is why this screen exists, so it is
              // textPrimary — not the dimmest thing on the row.
              Text(
                formatCurrencyExample(def, 9850),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.amount.copyWith(color: AppColors.textPrimary),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
