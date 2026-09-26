import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_override_sheet.dart';

/// Task 064 §7b — change one occurrence's amount, or that one and every one
/// after it, typed on the app keypad with the expression operators. Writes
/// through [AppStore.setOccurrenceAmount]; booking is untouched.
///
/// Task 067.2 §4 moved the sheet body into the shared [showAmountOverrideSheet];
/// this is the scheduled-item caller, with the same behaviour as before.
Future<void> showOccurrenceAmountSheet(
  BuildContext context, {
  required Task task,
  required DateTime day,
}) {
  final store = StoreScope.read(context);
  final l = AppLocalizations.of(context);
  final d = DateTime(day.year, day.month, day.day);
  final currency =
      store.accountById(task.linkedAccountId)?.currency ?? store.baseCurrency;
  return showAmountOverrideSheet(
    context,
    title: dayMonthYear(d, l),
    initialMagnitude: task.amountOn(d).abs(),
    usualMagnitude: task.expectedAmount.abs(),
    currencyCode: currency,
    hasOverride: task.hasOverrideOn(d),
    onlyLabel: l.tdOnlyThis(dayMonthYear(d, l)),
    andAfterLabel: l.tdThisAndAfter(dayMonthYear(d, l)),
    onSave: (magnitude, andAfter) =>
        store.setOccurrenceAmount(task, d, magnitude, andAfter: andAfter),
    onReset: () => store.setOccurrenceAmount(task, d, task.expectedAmount.abs(),
        andAfter: false),
  );
}
