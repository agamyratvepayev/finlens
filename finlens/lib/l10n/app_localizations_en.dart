// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get accountGroupSpendable => 'Spendable';

  @override
  String get accountGroupReceivables => 'Receivables';

  @override
  String get accountGroupInvestments => 'Investments';

  @override
  String get accountGroupValuables => 'Valuables';

  @override
  String get accountGroupCreditCards => 'Credit Cards';

  @override
  String get accountGroupPayables => 'Payables';

  @override
  String get accountGroupBankLoans => 'Bank Loans';

  @override
  String get quickAddExpense => 'Expense';

  @override
  String get quickAddIncome => 'Income';

  @override
  String get quickAddTransfer => 'Transfer';

  @override
  String get quickAddRebalance => 'Rebalance';

  @override
  String get quickAddNewGoal => 'New Goal';

  @override
  String get quickAddNewTask => 'New Task';

  @override
  String get txnTypeExpense => 'Expense';

  @override
  String get txnTypeIncome => 'Income';

  @override
  String get txnTypeTransfer => 'Transfer';

  @override
  String get txnTypeRebalance => 'Rebalance';

  @override
  String get goalTypeSaving => 'Saving';

  @override
  String get goalTypeMilestone => 'Milestone';

  @override
  String get goalTypePurchasing => 'Purchasing';

  @override
  String get goalSectionSaving => 'Saving';

  @override
  String get goalSectionMilestone => 'Milestone';

  @override
  String get goalSectionPurchasing => 'Purchasing';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'High';

  @override
  String get repeatNever => 'Never';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatQuarterly => 'Quarterly';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get comparePeriodTodayLabel => 'Today';

  @override
  String get comparePeriodTodayCaption => 'vs yesterday';

  @override
  String get comparePeriodWeekLabel => 'Week';

  @override
  String get comparePeriodWeekCaption => 'vs last week';

  @override
  String get comparePeriodMonthLabel => 'Month';

  @override
  String get comparePeriodMonthCaption => 'vs last month';

  @override
  String get rangeThisWeek => 'This week';

  @override
  String get rangeLastWeek => 'Last week';

  @override
  String get rangeThisMonth => 'This month';

  @override
  String get rangeLastMonth => 'Last month';

  @override
  String get rangeLast3Months => 'Last 3 months';

  @override
  String get rangeLast6Months => 'Last 6 months';

  @override
  String get rangeLast12Months => 'Last 12 months';

  @override
  String get rangeThisYear => 'This year';

  @override
  String get rangeAllTime => 'All time';

  @override
  String get navBalance => 'Balance';

  @override
  String get navLedger => 'Ledger';

  @override
  String get navPlanner => 'Planner';

  @override
  String get navInsight => 'Insight';

  @override
  String get navMore => 'More';

  @override
  String get accountSortValueDesc => 'Value — high to low';

  @override
  String get accountSortValueAsc => 'Value — low to high';

  @override
  String get accountSortNameAsc => 'Name — A to Z';

  @override
  String get accountSortActivity => 'Change — most active';

  @override
  String get accountSortCustom => 'Custom';

  @override
  String get balanceSectionAll => 'Net worth';

  @override
  String get balanceSectionAssets => 'Assets';

  @override
  String get balanceSectionLiabilities => 'Liabilities';

  @override
  String get transSortDateNewest => 'Date — newest first';

  @override
  String get transSortDateOldest => 'Date — oldest first';

  @override
  String get transSortAmountHigh => 'Amount — high to low';

  @override
  String get transSortAmountLow => 'Amount — low to high';

  @override
  String get transSortByCategory => 'Category — A to Z';

  @override
  String get transSortByAccount => 'Account — A to Z';

  @override
  String get ledgerAllAccounts => 'All accounts';

  @override
  String get ledgerAccountFallback => 'Account';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Jan',
      '2': 'Feb',
      '3': 'Mar',
      '4': 'Apr',
      '5': 'May',
      '6': 'Jun',
      '7': 'Jul',
      '8': 'Aug',
      '9': 'Sep',
      '10': 'Oct',
      '11': 'Nov',
      '12': 'Dec',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String monthLong(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'January',
      '2': 'February',
      '3': 'March',
      '4': 'April',
      '5': 'May',
      '6': 'June',
      '7': 'July',
      '8': 'August',
      '9': 'September',
      '10': 'October',
      '11': 'November',
      '12': 'December',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayLong(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Monday',
      '2': 'Tuesday',
      '3': 'Wednesday',
      '4': 'Thursday',
      '5': 'Friday',
      '6': 'Saturday',
      '7': 'Sunday',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get dateTomorrow => 'Tomorrow';

  @override
  String dateWithTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String dateGroupYesterday(String date) {
    return 'Yesterday · $date';
  }

  @override
  String rangeSince(String monthYear) {
    return 'Since $monthYear';
  }

  @override
  String get dueToday => 'today';

  @override
  String get dueTomorrow => 'tomorrow';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days',
      one: 'in $days day',
    );
    return '$_temp0';
  }

  @override
  String dueDaysLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late',
      one: '$days day late',
    );
    return '$_temp0';
  }

  @override
  String countAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '$count account',
    );
    return '$_temp0';
  }

  @override
  String countTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '$count transaction',
    );
    return '$_temp0';
  }

  @override
  String countResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0';
  }

  @override
  String countDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String countArchivedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archived items',
      one: '$count archived item',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get moreTitle => 'More';

  @override
  String get moreYourMoney => 'Your money';

  @override
  String get morePlannerSection => 'Planner';

  @override
  String get morePreferences => 'Preferences';

  @override
  String get moreCategories => 'Categories';

  @override
  String moreCategoriesInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in use',
      one: '$count in use',
    );
    return '$_temp0';
  }

  @override
  String get moreArchive => 'Archive';

  @override
  String get morePrivacyMode => 'Privacy mode';

  @override
  String get morePrivacyModeDesc => 'Mask every amount across the app';

  @override
  String get moreAddAccount => 'Add an account';

  @override
  String get insightTitle => 'Insight';

  @override
  String get insightLeftOver => 'Left over';

  @override
  String get insightNoIncome => 'No income recorded this month';

  @override
  String insightKept(String percent, String amount) {
    return '$percent of $amount kept';
  }

  @override
  String get insightWhereItWent => 'Where it went';

  @override
  String get insightGoalPerformance => 'Goal performance';

  @override
  String get insightReached => 'Reached';

  @override
  String get insightSuccessRate => 'Success rate';

  @override
  String get insightAvgTime => 'Avg. time';

  @override
  String insightMonthsShort(int count) {
    return '$count mo';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionMoveUp => 'Move up';

  @override
  String get actionMoveDown => 'Move down';

  @override
  String get actionCollapseAll => 'Collapse all';

  @override
  String get actionExpandAll => 'Expand all';

  @override
  String get actionReset => 'Reset';

  @override
  String get balSearchAccounts => 'Search accounts';

  @override
  String get balNoResults => 'No results';

  @override
  String get balNoAccountsYet => 'No accounts yet';

  @override
  String get balNoAccountMatch => 'No account or group matches your search.';

  @override
  String get balAddFirstAccount => 'Add your first account';

  @override
  String get balNoAccountsMessage =>
      'Add your accounts and FinLens works out your net worth from the transactions you record.';

  @override
  String get balAdjustFilter => 'Adjust filter';

  @override
  String get balSortTooltip => 'Sort';

  @override
  String get balHoldToArrange => 'Hold an account to arrange';

  @override
  String get balPressHoldMove => 'Press and hold an account to move it';

  @override
  String get balFilterCategories => 'Filter categories';

  @override
  String get balNoVisibleCategories => 'No visible categories';

  @override
  String balSeeAll(int count) {
    return 'See all $count  ›';
  }

  @override
  String transferFromTo(String from, String to) {
    return 'Transfer from $from to $to';
  }

  @override
  String get eaName => 'Name';

  @override
  String get eaGroup => 'Group';

  @override
  String get eaCurrency => 'Currency';

  @override
  String get eaStartingBalance => 'Starting balance';

  @override
  String get eaStartingBalanceLock =>
      'To fix the balance, add a transaction instead';

  @override
  String get eaCreditLimit => 'Credit limit';

  @override
  String get eaStatementDay => 'Statement day';

  @override
  String get eaPaymentDue => 'Payment due';

  @override
  String get eaNotSet => 'Not set';

  @override
  String get eaHideFromBalance => 'Hide from Balance';

  @override
  String get eaHideDesc => 'Stays in your totals, disappears from the lists';

  @override
  String get eaRemoveThisAccount => 'Remove this account';

  @override
  String get eaRemovePermanent => 'Permanently deletes this account';

  @override
  String get eaRemoveHasHistory =>
      'Has history — it will be archived, not erased';

  @override
  String eaRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get eaArchivedMsg =>
      'This account has history, so it is archived rather than erased.';

  @override
  String get eaDeleteMsg =>
      'This account has no transactions and can be deleted outright.';

  @override
  String eaTxnStays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count transactions stay in the Ledger, untouched.',
      one: 'Your $count transaction stays in the Ledger, untouched.',
    );
    return '$_temp0';
  }

  @override
  String eaGroupDropsBy(String group, String amount) {
    return '$group drops by $amount.';
  }

  @override
  String get eaDisappearsPicker => 'It disappears from every account picker.';

  @override
  String get eaCannotUndo => 'This cannot be undone.';

  @override
  String get eaArchiveAccount => 'Archive account';

  @override
  String get eaRemoveAccount => 'Remove account';

  @override
  String get eaEditAccount => 'Edit account';

  @override
  String balFilterActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Active, $count items hidden',
      one: 'Active, $count item hidden',
    );
    return '$_temp0';
  }

  @override
  String get balFilterOff => 'Off';

  @override
  String get balMoved => 'Moved';

  @override
  String get balMovedCustom => 'Moved · sorted by Custom';

  @override
  String balTotalOf(String name) {
    return 'Total $name';
  }

  @override
  String balUtilization(String percent) {
    return 'Utilization: $percent';
  }

  @override
  String get balOverdue => 'Overdue';

  @override
  String balDue(String when) {
    return 'Due $when';
  }

  @override
  String balNextPayment(String date) {
    return 'Next payment: $date';
  }

  @override
  String get actionDone => 'Done';

  @override
  String get actionBack => 'Back';

  @override
  String get filterTitle => 'Filter';

  @override
  String get sheetApply => 'Apply';

  @override
  String get sheetToday => 'Today';

  @override
  String balNoBetween(String subject, String range) {
    return 'No $subject between $range';
  }

  @override
  String get freqLessThanMonthly => 'Less than once a month';

  @override
  String get freqAbout => 'About ';

  @override
  String freqTimesAMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' times a month',
      one: ' time a month',
    );
    return '$_temp0';
  }

  @override
  String txnDeleteEntryTitle(String type) {
    return 'Delete this $type?';
  }

  @override
  String get txnDeleteEntryMessage =>
      'This entry is removed for good and the balances below go back to what they were.';

  @override
  String get txnDeleteNothingElse => 'Nothing else in your ledger changes.';

  @override
  String get txnDeleteEntryConfirm => 'Delete entry';

  @override
  String get freqLastOne => ' · last one ';

  @override
  String txnBudgetImpact(Object name, Object before, Object after) {
    return '$name budget $before → $after';
  }

  @override
  String get txnRevaluation => 'Revaluation';

  @override
  String get txnTransferOut => 'Transfer out';

  @override
  String get txnTransferIn => 'Transfer in';

  @override
  String get plTabBudgets => 'Budgets';

  @override
  String get plTabGoals => 'Goals';

  @override
  String get plTabSchedule => 'Schedule';

  @override
  String get plNoBudgetsYet => 'No budgets yet';

  @override
  String get plNoBudgetsMsg =>
      'Give a category a monthly limit and it will show up here.';

  @override
  String get plBudgeted => 'Budgeted';

  @override
  String get plNoBudgetSet => 'No budget set';

  @override
  String get plSet => 'Set';

  @override
  String get plNoGoalsYet => 'No goals yet';

  @override
  String get plNoGoalsMsg =>
      'Set a target and FinLens works out the monthly pace.';

  @override
  String get plNewGoal => 'New goal';

  @override
  String get plNewTask => 'New task';

  @override
  String get plCompleteReady => 'Complete · ready to archive';

  @override
  String get plNoTargetDate => 'No target date set';

  @override
  String get plMoNeeded => '/mo needed';

  @override
  String get plComingIn => 'Coming in';

  @override
  String get plGoingOut => 'Going out';

  @override
  String get schOverdue => 'Overdue';

  @override
  String get schThisWeek => 'This week';

  @override
  String get schLater => 'Later this month';

  @override
  String get plNothingScheduled => 'Nothing scheduled';

  @override
  String get plNothingSchedMsg =>
      'Bills, salaries and subscriptions you plan will land here.';

  @override
  String get plLeftThisMonth => 'Left this month';

  @override
  String get plUnbudgeted => 'unbudgeted';

  @override
  String get plOf => 'of';

  @override
  String get plBudgetWord => 'budget';

  @override
  String get plSavedTowardGoals => 'Saved toward goals';

  @override
  String plPaymentsOverdue(int count, Object amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments overdue',
      one: '$count payment overdue',
    );
    return '$_temp0 · $amount';
  }
}
