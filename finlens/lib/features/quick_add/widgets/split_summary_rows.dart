import 'package:flutter/material.dart';

import '../../../core/store/app_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../split_sheet.dart' show SplitLine;
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/amount_text.dart';
import 'form_kit.dart';

/// The split's lines, listed under the form's category row.
///
/// A summary that hides the only thing worth knowing is not a summary: `From`
/// names the account, `Date` shows the date, and `To` alone showed `3
/// categories` and made you reopen a modal to learn what you had already
/// decided. The count still answers *how many* — it stays on the row above —
/// and these answer *which*, the way Balance's group header shows `N accounts`
/// and expands to name them.
///
/// Read-only by design: no chevron, no `×`, no editing in place. The split
/// editor remains the one place a line changes, and a tap anywhere in the block
/// opens it.
List<Widget> buildSplitChildRows({
  required BuildContext context,
  required AppStore store,
  required List<SplitLine> lines,
  required String currency,
  required VoidCallback onTap,
}) {
  return [
    for (final line in lines)
      _SplitChildRow(
        store: store,
        line: line,
        currency: currency,
        onTap: onTap,
      ),
  ];
}

class _SplitChildRow extends StatelessWidget {
  const _SplitChildRow({
    required this.store,
    required this.line,
    required this.currency,
    required this.onTap,
  });

  final AppStore store;
  final SplitLine line;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    final l = AppLocalizations.of(context);
    final category = store.categoryById(line.categoryId);
    // A category archived mid-form renders the way the editor's own line does:
    // the warning colour and the fallback glyph, never a blank or a crash.
    final missing = category == null;
    final color = category?.color ?? AppColors.warning;
    final name = missing ? l.ssChooseCategory : category.name;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        button: true,
        // Announced as one node, `name, amount`, with the visual sub-nodes
        // excluded — the pattern the editor's line row already uses.
        label: '$name, ${money(line.amount ?? 0, currency: currency, forceDecimals: true, masked: store.masked)}',
        excludeSemantics: true,
        child: Padding(
          // Aligns to the hairline TxnCard indents its dividers by, so the
          // lines share the parent row's content edge. No new constant.
          padding: EdgeInsets.fromLTRB(
            kSeparatorInset * s,
            0,
            kRowPadding * s,
            10 * s,
          ),
          child: Row(
            children: [
              // The editor's 30pt tile at 22, composited against the form
              // card rather than the sheet card it sits on there.
              Container(
                width: 22 * s,
                height: 22 * s,
                decoration: BoxDecoration(
                  color: missing
                      ? AppColors.surfaceHigh
                      : Color.alphaBlend(
                          color.withValues(alpha: 0.18), AppColors.fieldCard),
                  borderRadius: BorderRadius.circular(7 * s),
                ),
                child: Icon(category?.icon ?? Icons.category_rounded,
                    size: 12 * s, color: color),
              ),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13 * s * t,
                    height: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: kIconGap * s),
              // Right-aligned on the parent row's value edge, and never
              // ellipsised — the name yields, the figure does not. Tabular so
              // the column reads as a column.
              AmountText(
                line.amount ?? 0,
                currency: currency,
                forceDecimals: true,
                style: TextStyle(
                  fontSize: 13 * s * t,
                  height: 1.2,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
