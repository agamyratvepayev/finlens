import 'package:flutter/material.dart';

import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';

/// Changing the reporting currency (spec 021e §4a). Choosing a target opens a
/// confirmation that states, before anything changes, the single factor the
/// whole history is re-expressed through — proposed from the target's stored
/// rate, editable, refusing `0`. `Convert and switch` is the only way through;
/// `Cancel` changes nothing at all.
Future<void> showReportingCurrencySheet(BuildContext context) async {
  final store = StoreScope.read(context);
  final from = store.baseCurrency;
  final to = await pickCurrency(context, from);
  if (to == null || to == from || !context.mounted) return;
  await showAppSheet<bool>(
    context,
    title: AppLocalizations.of(context).curChangeReportingTitle,
    contentSized: true,
    cancelLabel: AppLocalizations.of(context).actionCancel,
    builder: (context, controller) => _ReportingConfirmForm(
      controller: controller,
      from: from,
      to: to,
      store: store,
    ),
  );
}

class _ReportingConfirmForm extends StatefulWidget {
  const _ReportingConfirmForm({
    required this.controller,
    required this.from,
    required this.to,
    required this.store,
  });

  final ScrollController controller;
  final String from;
  final String to;
  final AppStore store;

  @override
  State<_ReportingConfirmForm> createState() => _ReportingConfirmFormState();
}

class _ReportingConfirmFormState extends State<_ReportingConfirmForm> {
  double? _factor;

  @override
  void initState() {
    super.initState();
    // Proposed from the target's stored rate — how many `to` one `from` buys.
    _factor = widget.store.rateFor(widget.to);
  }

  Future<void> _editFactor() async {
    final v = await promptDecimal(
      context,
      title: AppLocalizations.of(context).qaExchangeRate,
      initial: _factor,
      hint: '1 ${widget.from} = ? ${widget.to}',
    );
    if (v != null) setState(() => _factor = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final factor = _factor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            controller: widget.controller,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.md, Insets.gutter, Insets.lg),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.from,
                      style: AppText.body.copyWith(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ),
                  Text(widget.to,
                      style: AppText.body.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentLight)),
                ],
              ),
              const SizedBox(height: Insets.lg),
              InkWell(
                onTap: _editFactor,
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.sheetCard,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      Text('1 ${widget.from} =',
                          style: AppText.body.copyWith(fontSize: 15)),
                      const Spacer(),
                      if (factor == null)
                        Text(l.curSetRate,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning))
                      else
                        Text('${formatRate(factor)} ${widget.to}',
                            style: AppText.body.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      const SizedBox(width: 6),
                      const Icon(Icons.expand_more_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(l.curReportingNote,
                  style: AppText.caption.copyWith(fontSize: 12, height: 1.45)),
            ],
          ),
        ),
        _ConfirmFooter(
          label: l.curConvertAndSwitch,
          enabled: factor != null,
          onPressed: factor == null
              ? null
              : () {
                  widget.store.setBaseCurrency(widget.to, factor: factor);
                  Navigator.of(context).pop(true);
                },
        ),
      ],
    );
  }
}

class _ConfirmFooter extends StatelessWidget {
  const _ConfirmFooter(
      {required this.label, required this.enabled, required this.onPressed});
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, Insets.md, Insets.gutter, Insets.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.surfaceHigh,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: AppText.button,
        ),
        child: Text(label),
      ),
    );
  }
}
