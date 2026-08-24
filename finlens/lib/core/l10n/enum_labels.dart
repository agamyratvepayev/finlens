import '../../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../utils/date_range.dart';

/// Localized display labels for the core domain enums.
///
/// The enums themselves carry only stable identity + presentation data (colour,
/// icon); their display strings live in the ARB catalog and are resolved here,
/// so a label reads correctly in every language. Call as `type.label(l10n)`
/// where `l10n = AppLocalizations.of(context)`.
extension AccountGroupL10n on AccountGroup {
  String label(AppLocalizations l) => switch (this) {
        AccountGroup.spendable => l.accountGroupSpendable,
        AccountGroup.setAside => l.accountGroupSetAside,
        AccountGroup.receivables => l.accountGroupReceivables,
        AccountGroup.investments => l.accountGroupInvestments,
        AccountGroup.valuables => l.accountGroupValuables,
        AccountGroup.creditCards => l.accountGroupCreditCards,
        AccountGroup.payables => l.accountGroupPayables,
        AccountGroup.bankLoans => l.accountGroupBankLoans,
      };
}

extension QuickAddTypeL10n on QuickAddType {
  String label(AppLocalizations l) => switch (this) {
        QuickAddType.expense => l.quickAddExpense,
        QuickAddType.income => l.quickAddIncome,
        QuickAddType.transfer => l.quickAddTransfer,
        QuickAddType.rebalance => l.quickAddRebalance,
        QuickAddType.newGoal => l.quickAddNewGoal,
        QuickAddType.newTask => l.quickAddNewTask,
      };
}

extension TxnTypeL10n on TxnType {
  String label(AppLocalizations l) => switch (this) {
        TxnType.expense => l.txnTypeExpense,
        TxnType.income => l.txnTypeIncome,
        TxnType.transfer => l.txnTypeTransfer,
        TxnType.rebalance => l.txnTypeRebalance,
      };
}

extension GoalTypeL10n on GoalType {
  String label(AppLocalizations l) => switch (this) {
        GoalType.saving => l.goalTypeSaving,
        GoalType.milestone => l.goalTypeMilestone,
        GoalType.purchase => l.goalTypePurchasing,
      };

  String sectionTitle(AppLocalizations l) => switch (this) {
        GoalType.saving => l.goalSectionSaving,
        GoalType.milestone => l.goalSectionMilestone,
        GoalType.purchase => l.goalSectionPurchasing,
      };
}

extension PriorityL10n on Priority {
  String label(AppLocalizations l) => switch (this) {
        Priority.low => l.priorityLow,
        Priority.normal => l.priorityNormal,
        Priority.high => l.priorityHigh,
      };
}

extension RepeatFrequencyL10n on RepeatFrequency {
  String label(AppLocalizations l) => switch (this) {
        RepeatFrequency.none => l.repeatNever,
        RepeatFrequency.weekly => l.repeatWeekly,
        RepeatFrequency.monthly => l.repeatMonthly,
        RepeatFrequency.quarterly => l.repeatQuarterly,
        RepeatFrequency.yearly => l.repeatYearly,
      };
}

extension ComparePeriodL10n on ComparePeriod {
  String label(AppLocalizations l) => switch (this) {
        ComparePeriod.today => l.comparePeriodTodayLabel,
        ComparePeriod.week => l.comparePeriodWeekLabel,
        ComparePeriod.month => l.comparePeriodMonthLabel,
      };

  String caption(AppLocalizations l) => switch (this) {
        ComparePeriod.today => l.comparePeriodTodayCaption,
        ComparePeriod.week => l.comparePeriodWeekCaption,
        ComparePeriod.month => l.comparePeriodMonthCaption,
      };
}

extension RangePresetL10n on RangePreset {
  String label(AppLocalizations l) => switch (this) {
        RangePreset.thisWeek => l.rangeThisWeek,
        RangePreset.lastWeek => l.rangeLastWeek,
        RangePreset.thisMonth => l.rangeThisMonth,
        RangePreset.lastMonth => l.rangeLastMonth,
        RangePreset.last3Months => l.rangeLast3Months,
        RangePreset.thisYear => l.rangeThisYear,
        RangePreset.allTime => l.rangeAllTime,
      };
}
