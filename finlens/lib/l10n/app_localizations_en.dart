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
  String get accountGroupSetAside => 'Set aside';

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
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Mon',
      '2': 'Tue',
      '3': 'Wed',
      '4': 'Thu',
      '5': 'Fri',
      '6': 'Sat',
      '7': 'Sun',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayNarrow(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'M',
      '2': 'T',
      '3': 'W',
      '4': 'T',
      '5': 'F',
      '6': 'S',
      '7': 'S',
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
  String get obTitle => 'Opening balance';

  @override
  String get obNotSet => 'Not set';

  @override
  String get obShiftsNote =>
      'This shifts every running balance on this account.';

  @override
  String get obDateTooLate =>
      'The opening date can’t be after the first transaction.';

  @override
  String get obDeleteTitle => 'Remove the opening balance?';

  @override
  String obDeleteMsg(String amount) {
    return 'Every balance on this account will shift by $amount.';
  }

  @override
  String get obDeleteConfirm => 'Remove opening balance';

  @override
  String get obCopyTitle => 'Copy to account';

  @override
  String obA11y(String account, String amount) {
    return 'Opening balance, $account, $amount';
  }

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
  String get balSortDefault => 'Default order';

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
  String get eaArchiveThisAccount => 'Archive this account';

  @override
  String eaMoveOutTitle(String amount) {
    return 'Move the $amount out first';
  }

  @override
  String eaMoveOutMsg(String amount) {
    return 'Archiving now would drop $amount from your net worth with nothing in the Ledger to explain where it went. A closed account holds nothing.';
  }

  @override
  String eaSettleTitle(String amount) {
    return 'Settle the $amount first';
  }

  @override
  String eaSettleMsg(String amount) {
    return 'Archiving now would drop $amount from your net worth with nothing in the Ledger to explain where it went. A closed account holds nothing.';
  }

  @override
  String get eaMoveMoney => 'Move money';

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
  String get plOf => 'of';

  @override
  String get plBudgetWord => 'budget';

  @override
  String get plSavedTowardGoals => 'Saved toward goals';

  @override
  String get plPace => 'Pace';

  @override
  String plLeftOfAmount(Object amount) {
    return 'left of $amount';
  }

  @override
  String plOverAmount(Object amount) {
    return 'over $amount';
  }

  @override
  String plPctSpent(Object pct) {
    return '$pct spent';
  }

  @override
  String plDayOfMonth(int day, int length) {
    return 'day $day of $length';
  }

  @override
  String plCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '$count category',
    );
    return '$_temp0';
  }

  @override
  String plSemRowOver(Object name, Object spent, Object limit) {
    return '$name, over budget, $spent of $limit';
  }

  @override
  String plSemRowNear(Object name, Object spent, Object limit) {
    return '$name, near the limit, $spent of $limit';
  }

  @override
  String plSemRowNormal(Object name, Object spent, Object limit) {
    return '$name, $spent of $limit';
  }

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

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldSelectAccount => 'Select account';

  @override
  String get fieldDirection => 'Direction';

  @override
  String get actionUse => 'Use';

  @override
  String get actionRestore => 'Restore';

  @override
  String countMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String get ebTitle => 'Edit budget';

  @override
  String get ebMonthlyLimit => 'Monthly limit';

  @override
  String get ebRollOver => 'Roll over unspent';

  @override
  String get ebRollOverDesc => 'Add leftovers to next month';

  @override
  String get ebWarnAt => 'Warn me at';

  @override
  String get ebRemoveBudget => 'Remove budget';

  @override
  String ebAverage(Object average, Object suggestion) {
    return 'You average $average. Try $suggestion?';
  }

  @override
  String ebRemoveTitle(Object name) {
    return 'Remove $name budget?';
  }

  @override
  String get ebRemoveMsg => 'You\'ll stop tracking a limit for this category.';

  @override
  String ebCategoryStays(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count transactions are untouched.',
      one: 'Your $count transaction is untouched.',
    );
    return 'The $name category stays. $_temp0';
  }

  @override
  String get ebWarningsDisappear =>
      'Warnings and progress bars for this category disappear.';

  @override
  String ebTotalDrops(Object from, Object to) {
    return 'Total monthly budget drops from $from to $to.';
  }

  @override
  String get ctArchiveCategory => 'Archive category';

  @override
  String ctArchiveTitle(String name) {
    return 'Archive \"$name\"?';
  }

  @override
  String get ctArchiveMsg =>
      'It stops appearing when you add a transaction. Nothing already recorded changes.';

  @override
  String ctTxnStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your $count transactions stay in the Ledger, with this name and icon.',
      one:
          'Your $count transaction stays in the Ledger, with this name and icon.',
    );
    return '$_temp0';
  }

  @override
  String ctPastMonths(String name) {
    return 'Past months keep their $name figures.';
  }

  @override
  String ctBudgetRemoved(String amount) {
    return 'Its $amount monthly budget is removed — a budget with nothing to track would sit empty forever. You can restore it from Archive.';
  }

  @override
  String get ctDisappearsPicker => 'It disappears from every category picker.';

  @override
  String ctBlockedTitle(String name) {
    return 'Can\'t archive \"$name\" yet';
  }

  @override
  String ctBlockedMsg(String task) {
    return 'The scheduled item \"$task\" still books into it. Change or remove that item first.';
  }

  @override
  String get egTitle => 'Edit goal';

  @override
  String get egGoalName => 'Goal name';

  @override
  String get egType => 'Type';

  @override
  String get egTargetAmount => 'Target amount';

  @override
  String get egTargetDate => 'Target date';

  @override
  String get egMoneyKeptIn => 'Money kept in';

  @override
  String get egAutoContribute => 'Auto contribute';

  @override
  String get egAutoContributeDesc =>
      'Creates a monthly transfer into this goal';

  @override
  String get egMonthlyContribution => 'Monthly contribution';

  @override
  String get egMarkReached => 'Mark as reached';

  @override
  String get egMarkReachedDesc => 'Money is spent, goal is done';

  @override
  String get egGiveUp => 'Give up for now';

  @override
  String get egDeleteGoal => 'Delete goal';

  @override
  String get egDeleteGoalDesc => 'As if it never existed';

  @override
  String egMarkReachedTitle(Object name) {
    return 'Mark $name as reached?';
  }

  @override
  String get egMarkReachedMsg =>
      'Congratulations — this moves the goal into your archive as a success.';

  @override
  String egReachedAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return 'Recorded as reached after $_temp0, feeding your goal-performance stats.';
  }

  @override
  String get egPastTxnStay => 'Past transactions stay in your Ledger.';

  @override
  String get egLeavesStops => 'It leaves the Goals list and stops tracking.';

  @override
  String get egAutoStops => 'The monthly auto-contribution stops.';

  @override
  String get egNotYet => 'Not yet';

  @override
  String egGiveUpTitle(Object name) {
    return 'Give up on $name?';
  }

  @override
  String get egGiveUpMsg =>
      'Tracking stops, but the money you already put aside stays exactly where it is.';

  @override
  String egSavedStaysIn(Object amount, Object account) {
    return 'The $amount stays in $account.';
  }

  @override
  String get egYourAccount => 'your account';

  @override
  String get egRestoreLater => 'You can restore it later from the Archive.';

  @override
  String get egLeavesList => 'It leaves the Goals list.';

  @override
  String egDeleteTitle(Object name) {
    return 'Delete $name?';
  }

  @override
  String get egDeleteMsg =>
      'Use this only when the goal was created by mistake — it leaves no trace in your history.';

  @override
  String get egBalancesUnchanged => 'Your account balances do not change.';

  @override
  String get egNotInArchive => 'It will not appear in the Archive.';

  @override
  String get egExcludedStats => 'It is excluded from goal-performance stats.';

  @override
  String get egRecurringCancelled =>
      'The recurring transfer rule is cancelled.';

  @override
  String egPerMonthTrack(Object amount) {
    return '$amount/mo to stay on track';
  }

  @override
  String egAutoContributeOn(Object amount, Object day) {
    return '$amount on the $day';
  }

  @override
  String egKeepsStops(Object amount) {
    return 'Keeps the $amount, stops tracking';
  }

  @override
  String get egSaved => 'saved';

  @override
  String get egToGo => 'to go';

  @override
  String get ebWhatSpent => 'What you actually spent';

  @override
  String get ebSpent => 'spent';

  @override
  String get etTitle => 'Edit task';

  @override
  String get etTaskTitle => 'Task title';

  @override
  String get etPaidFrom => 'Paid from';

  @override
  String get etPaidInto => 'Paid into';

  @override
  String get etLinkedAccount => 'Linked account';

  @override
  String get etPayOut => 'Pay out −';

  @override
  String get etPayIn => 'Pay in +';

  @override
  String get etExpectedAmount => 'Expected amount';

  @override
  String get etCategoryHint => 'Where \"Mark as paid\" books it';

  @override
  String get etNextDue => 'Next due';

  @override
  String get etRepeats => 'Repeats';

  @override
  String get etOneOff => 'One-off task';

  @override
  String get etRemindMe => 'Remind me';

  @override
  String etRemindBefore(Object days, Object time) {
    return '$days days before, $time';
  }

  @override
  String get etMarkPaid => 'Mark as paid';

  @override
  String get etMarkPaidExpense => 'Creates the expense in Ledger';

  @override
  String get etMarkPaidIncome => 'Creates the income in Ledger';

  @override
  String get etSkipThisMonth => 'Skip this month';

  @override
  String etSeriesContinues(Object month) {
    return 'Series continues in $month';
  }

  @override
  String get etDeleteWholeSeries => 'Delete the whole series';

  @override
  String etAllFutureReminders(Object title) {
    return 'All future $title reminders';
  }

  @override
  String etSkippedNext(Object date) {
    return 'Skipped · next on $date';
  }

  @override
  String etDeleteOnly(Object date) {
    return 'Delete only $date';
  }

  @override
  String etDeleteOnlyTitle(Object date) {
    return 'Delete only $date?';
  }

  @override
  String get etJustThisOne => 'Just this one occurrence is removed.';

  @override
  String get etOneOffRemoved => 'This one-off task is removed.';

  @override
  String etSeriesContinuesOn(Object date) {
    return 'The series continues on $date.';
  }

  @override
  String get etNoLedgerEntry => 'No Ledger entry is created or removed.';

  @override
  String get etLedgerUntouched => 'Your Ledger is untouched.';

  @override
  String etDisappears(Object date) {
    return '$date disappears from your Schedule.';
  }

  @override
  String etDeleteDate(Object date) {
    return 'Delete $date';
  }

  @override
  String etDeleteSeriesTitle(Object title) {
    return 'Delete the whole $title series?';
  }

  @override
  String get etDeleteSeriesMsg =>
      'Every future occurrence is removed, not just the next one.';

  @override
  String get etPaymentsStay =>
      'Payments you already recorded stay in your Ledger.';

  @override
  String get etAllRemindersCancelled => 'All future reminders are cancelled.';

  @override
  String etOutgoingsDrop(Object amount) {
    return 'Your monthly outgoings drop by $amount.';
  }

  @override
  String get etDeleteSeries => 'Delete series';

  @override
  String etRecordedInLedger(Object title) {
    return '$title recorded in your Ledger';
  }

  @override
  String etRepeatsCadence(Object cadence) {
    return 'Repeats $cadence';
  }

  @override
  String bdAveraging(Object avg, Object limit, Object count) {
    return 'Averaging $avg · over the $limit limit in $count of 6';
  }

  @override
  String get bdNothingSpent => 'Nothing spent here this month.';

  @override
  String get arEmpty => 'Archive is empty';

  @override
  String get arEmptyMsg =>
      'Goals you reach or give up on, and budgets you remove, are kept here.';

  @override
  String get arFootnote =>
      'Archived items don\'t appear in Planner and don\'t affect your totals. Their past transactions stay in Ledger.';

  @override
  String get arReachedGoals => 'Reached goals';

  @override
  String arReachedLine(Object date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return 'Reached $date · took $_temp0';
  }

  @override
  String get arGaveUp => 'Gave up';

  @override
  String arStoppedLine(Object date, Object saved, Object target) {
    return 'Stopped $date · $saved of $target';
  }

  @override
  String get arRemovedBudgets => 'Removed budgets';

  @override
  String get arAccounts => 'Accounts';

  @override
  String get arCategories => 'Categories';

  @override
  String arAccountLine(String group, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '$count transaction',
    );
    return '$group · $_temp0';
  }

  @override
  String arRemovedLine(Object date) {
    return 'Removed $date';
  }

  @override
  String get arClearPermanently => 'Clear archive permanently';

  @override
  String get arClearTitle => 'Clear the archive?';

  @override
  String arClearMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count archived items are erased for good.',
      one: 'All $count archived item is erased for good.',
    );
    return '$_temp0';
  }

  @override
  String get arTxnStay => 'Every related transaction stays in your Ledger.';

  @override
  String get arBalancesUnaffected => 'Account balances are unaffected.';

  @override
  String get arRestoreImpossible => 'Restore is no longer possible.';

  @override
  String get arStatsDisappear =>
      'Reached-goal history disappears from your stats.';

  @override
  String get arClearArchive => 'Clear archive';

  @override
  String get stateOn => 'On';

  @override
  String get stateOff => 'Off';

  @override
  String get filterAll => 'All';

  @override
  String get actionClose => 'Close';

  @override
  String get ldgShowDescriptions => 'Show descriptions';

  @override
  String get ldgSortTransactions => 'Sort transactions';

  @override
  String get ldgFilterTransactions => 'Filter transactions';

  @override
  String get ldgSearchTransactions => 'Search transactions';

  @override
  String ldgFilterActive(Object shown, Object total) {
    return 'Active, $shown of $total shown';
  }

  @override
  String ldgNoResultsFor(Object query) {
    return 'No results for \"$query\"';
  }

  @override
  String get ldgNoMatchFilter => 'No transactions match your filter';

  @override
  String get ldgClearFilter => 'Clear filter';

  @override
  String get ldgNothingHere => 'Nothing here yet';

  @override
  String get ldgNothingHereMsg => 'Entries you add will appear in this list.';

  @override
  String get ldgAddEntry => 'Add an entry';

  @override
  String get ldgCategories => 'Categories';

  @override
  String get ldgAccounts => 'Accounts';

  @override
  String get ldgTags => 'Tags';

  @override
  String get ldgType => 'Type';

  @override
  String get ldgDirection => 'Direction';

  @override
  String get ldgAmount => 'Amount';

  @override
  String get ldgAny => 'Any';

  @override
  String get ldgClearCustomRange => 'Clear custom range';

  @override
  String ldgSpentOf(Object expense, Object income) {
    return 'Spent $expense of $income';
  }

  @override
  String get ldgOut => 'Out';

  @override
  String get ldgLeft => 'Left';

  @override
  String get ldgChangePeriod => 'Change period';

  @override
  String get ldgBalance => 'Balance';

  @override
  String get ldgTransactionDeleted => 'Transaction deleted';

  @override
  String get ldgNoTransactions => 'No transactions';

  @override
  String get ldgPeriod => 'Period';

  @override
  String get ldgShow => 'Show';

  @override
  String get ldgCustomRange => 'Custom range';

  @override
  String get ldgPreviousYear => 'Previous year';

  @override
  String get ldgNextYear => 'Next year';

  @override
  String ldgShowCountOf(Object count, Object total) {
    return 'Show $count of $total';
  }

  @override
  String ldgShowAll(Object count) {
    return 'Show all $count';
  }

  @override
  String ldgPlusMore(Object count) {
    return '+$count more';
  }

  @override
  String get ldgNetIn => 'Net in';

  @override
  String get ldgNetOut => 'Net out';

  @override
  String get ldgMoneyIn => 'Money in';

  @override
  String get ldgMoneyOut => 'Money out';

  @override
  String get ldgNoCash => 'No cash';

  @override
  String get ldgIn => 'In';

  @override
  String ldgRangeHint(Object min, Object max) {
    return 'Transactions here range $min – $max';
  }

  @override
  String ldgSearchWithin(Object labels) {
    return 'Search $labels';
  }

  @override
  String ldgSelectAllIn(Object section) {
    return 'Select all in $section';
  }

  @override
  String ldgClearSelection(Object section) {
    return 'Clear $section selection';
  }

  @override
  String get ldgSelectAll => 'Select all';

  @override
  String get ldgClear => 'Clear';

  @override
  String get ldgMin => 'Min';

  @override
  String get ldgMax => 'Max';

  @override
  String get ldgResetFilter => 'Reset filter';

  @override
  String get tdFrom => 'From';

  @override
  String get tdTo => 'To';

  @override
  String get tdDeletedAccount => 'Deleted account';

  @override
  String get tdRate => 'Rate';

  @override
  String get tdNote => 'Note';

  @override
  String get tdNetWorth => 'Net worth';

  @override
  String get tdUnchanged => 'Unchanged';

  @override
  String get stDetailNote => 'Note';

  @override
  String get stDetailWhen => 'When';

  @override
  String get stDetailPaidWith => 'Paid with';

  @override
  String get stDetailTags => 'Tags';

  @override
  String get qaAmount => 'Amount';

  @override
  String get qaDue => 'Due';

  @override
  String get qaNewBalance => 'New balance';

  @override
  String get qaTarget => 'Target';

  @override
  String get qaDate => 'Date';

  @override
  String get qaTag => 'Tag';

  @override
  String get qaNone => 'None';

  @override
  String get qaNote => 'Note';

  @override
  String get qaAddNote => 'Add a note';

  @override
  String get qaOptional => 'Optional';

  @override
  String get qaSplit => 'Split';

  @override
  String qaSplitCategories(Object count) {
    return '$count categories';
  }

  @override
  String get qaGroupRequired => 'Required';

  @override
  String get qaGroupOptional => 'Optional';

  @override
  String get qaFrom => 'From';

  @override
  String get qaTo => 'To';

  @override
  String get qaChooseAccount => 'Choose account';

  @override
  String get qaChooseCategory => 'Choose category';

  @override
  String get qaChooseSource => 'Choose source';

  @override
  String get qaPayFrom => 'Pay from';

  @override
  String get qaDepositInto => 'Deposit into';

  @override
  String get qaTransferFrom => 'Transfer from';

  @override
  String get qaTransferTo => 'Transfer to';

  @override
  String get qaRate => 'Rate';

  @override
  String get qaReceives => 'Receives';

  @override
  String get qaFee => 'Fee';

  @override
  String get qaAccount => 'Account';

  @override
  String get qaRevalueAccount => 'Revalue account';

  @override
  String get qaCurrent => 'Current';

  @override
  String get qaDifference => 'Difference';

  @override
  String get qaReason => 'Reason';

  @override
  String get qaAdjustment => 'Adjustment';

  @override
  String get qaBalanceUnchanged => 'Balance unchanged';

  @override
  String get qaName => 'Name';

  @override
  String get qaNameYourGoal => 'Name your goal';

  @override
  String get qaGoalNameHint => 'e.g. MacBook Pro M4';

  @override
  String get qaSetDate => 'Set a date';

  @override
  String get qaFundingAccount => 'Funding account';

  @override
  String get qaStartingAmount => 'Starting amount';

  @override
  String get qaIconColour => 'Icon & colour';

  @override
  String get qaTapToChange => 'Tap to change';

  @override
  String get qaAutoFund => 'Auto-fund';

  @override
  String get qaRemind => 'Remind';

  @override
  String get qaTaskPlaceholder => 'What needs doing?';

  @override
  String get qaExchangeRate => 'Exchange rate';

  @override
  String qaFxRate(Object from, Object to) {
    return '1 $from = ? $to';
  }

  @override
  String get qaWhatAdding => 'What are you adding?';

  @override
  String get qaDeleteEntry => 'Delete this entry';

  @override
  String get qaBalanceAdjustment => 'Balance adjustment';

  @override
  String get qaRecurring => 'Recurring';

  @override
  String qaLinkedSplit(Object count) {
    return 'This is one of $count linked split transactions.';
  }

  @override
  String qaDeleteAll(Object count) {
    return 'Delete all $count';
  }

  @override
  String get qaDeleteJustLine => 'Delete just this line';

  @override
  String get qaSaveExpense => 'Save expense';

  @override
  String get qaSaveIncome => 'Save income';

  @override
  String get qaSaveTransfer => 'Save transfer';

  @override
  String get qaSaveAdjustment => 'Save adjustment';

  @override
  String get qaCreateGoal => 'Create goal';

  @override
  String get qaCreateTask => 'Create task';

  @override
  String qaSaved(Object type) {
    return '$type saved';
  }

  @override
  String get qaBlockAmount => 'Enter an amount';

  @override
  String get qaBlockAccount => 'Choose an account';

  @override
  String get qaBlockCategory => 'Choose a category';

  @override
  String get qaBlockSource => 'Choose a source';

  @override
  String get qaBlockSplit => 'Balance the split';

  @override
  String get qaBlockSourceAccount => 'Choose a source account';

  @override
  String get qaBlockDestination => 'Choose a destination';

  @override
  String get qaBlockBalanceUnchanged => 'Balance unchanged';

  @override
  String get qaBlockNameGoal => 'Name your goal';

  @override
  String get qaBlockSetTarget => 'Set a target';

  @override
  String get qaBlockSetTargetDate => 'Set a target date';

  @override
  String get qaBlockFunding => 'Choose a funding account';

  @override
  String get qaBlockNameTask => 'Name the task';

  @override
  String get qaBlockDueDate => 'Set a due date';

  @override
  String get qaNewAccount => 'New account';

  @override
  String get qaNewCategory => 'New category';

  @override
  String get qaNewShort => 'New';

  @override
  String get qaSelectAccount => 'Select account';

  @override
  String get qaSearchAccounts => 'Search accounts';

  @override
  String get qaSearchCategories => 'Search categories';

  @override
  String qaNoAccountMatch(Object query) {
    return 'No account matches \"$query\".';
  }

  @override
  String qaNoCategoryMatch(Object query) {
    return 'No category matches \"$query\".';
  }

  @override
  String get qaExpenseCategory => 'Expense category';

  @override
  String get qaIncomeCategory => 'Income category';

  @override
  String get qaSearchCleared => 'Search cleared';

  @override
  String get qaClearSearch => 'Clear search';

  @override
  String get qaCategoryName => 'Category name';

  @override
  String get qaIcon => 'Icon';

  @override
  String get qaColour => 'Colour';

  @override
  String get qaMonthlyBudget => 'Monthly budget (optional)';

  @override
  String get qaCategoryPlannerNote =>
      'This category will also appear in Planner → Expense Budget, where you can track spending against it.';

  @override
  String get qaCreateSelect => 'Create & select';

  @override
  String get qaAccountName => 'Account name';

  @override
  String get qaAccountExists => 'An account with this name already exists';

  @override
  String get qaAssets => 'Assets';

  @override
  String get qaLiabilities => 'Liabilities';

  @override
  String get qaAmountOwed => 'Amount owed';

  @override
  String get qaPaymentDay => 'Payment day';

  @override
  String get qaOwedHint =>
      'Enter what you owe as a positive number — it counts against your net worth.';

  @override
  String get qaStartingBalanceHint =>
      'Enter this once. From now on the balance is calculated from your transactions.';

  @override
  String get qaPaymentDayHint => 'Months shorter than this use their last day.';

  @override
  String get qaDiscardTitle => 'Discard new account?';

  @override
  String get qaDiscardBody => 'The details you entered won\'t be saved.';

  @override
  String get qaDiscardConfirm => 'Discard';

  @override
  String get qaMoreIcons => 'More icons';

  @override
  String get qaChooseIcon => 'Choose icon';

  @override
  String get qaSearchIcons => 'Search icons';

  @override
  String get qaResults => 'Results';

  @override
  String get qaNoIconsMatch => 'No icons match';

  @override
  String get ssRemoveSplit => 'Remove split';

  @override
  String get ssSplitByCategory => 'Split by category';

  @override
  String ssTotalCovers(Object total, Object covered) {
    return 'Total $total · $covered';
  }

  @override
  String get ssRemoveLine => 'Remove line';

  @override
  String get ssAddCategory => 'Add category';

  @override
  String get ssRemaining => 'Remaining';

  @override
  String get ssOverBy => 'Over by';

  @override
  String get ssSplitEvenly => 'Split evenly';

  @override
  String get ssRestToLast => 'Rest to last';

  @override
  String get ssApplySplit => 'Apply split';

  @override
  String get ssApplySplitBlocked =>
      'Apply split, unavailable until the remaining is zero';

  @override
  String get rsRepeat => 'Repeat';

  @override
  String get rsHowOften => 'How often';

  @override
  String get rsEveryWeek => 'Every week';

  @override
  String get rsEvery2Weeks => 'Every 2 weeks';

  @override
  String get rsEveryMonth => 'Every month';

  @override
  String get rsEveryQuarter => 'Every quarter';

  @override
  String get rsEveryYear => 'Every year';

  @override
  String rsSummary(Object cadence, Object date) {
    return 'Repeats $cadence, starting $date. Managed in Planner.';
  }

  @override
  String rsWeekly(Object weekday) {
    return 'every week on $weekday';
  }

  @override
  String rsMonthly(Object day) {
    return 'on the $day of every month';
  }

  @override
  String rsQuarterly(Object day) {
    return 'on the $day, every 3 months';
  }

  @override
  String rsYearly(Object day, Object month) {
    return 'every year on $day $month';
  }

  @override
  String get rsNext => 'Next';

  @override
  String get rsShorterMonths => 'Shorter months use their last day';

  @override
  String get rsEveryDay => 'Every day';

  @override
  String get rsWeekdays => 'Weekdays';

  @override
  String rsNDaysWeek(int count) {
    return '$count days a week';
  }

  @override
  String rsNDaysMonth(int count) {
    return '$count days a month';
  }

  @override
  String rsMonthlyOnDay(Object day) {
    return 'Every month on the $day';
  }

  @override
  String rsDaysJoin(Object head, Object last) {
    return '$head & $last';
  }

  @override
  String get qaExchange => 'Exchange';

  @override
  String get qaEnterNewBalance => 'Enter the new balance';

  @override
  String get qaDeleteSplit => 'Delete split';

  @override
  String get qaBooksPrefix => 'Books a ';

  @override
  String get qaBooksSuffix =>
      ' adjustment dated today. Past reports are not rewritten.';

  @override
  String get qaPutAsidePrefix => 'Put aside ';

  @override
  String qaPerMonth(Object amount) {
    return '$amount / month';
  }

  @override
  String qaToReachMonths(Object months) {
    return ' for $months months to reach it on time.';
  }

  @override
  String qaCreated(Object date) {
    return 'Created $date';
  }

  @override
  String qaEditedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · edited $count times',
      one: ' · edited once',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get a11yShown => 'shown';

  @override
  String get a11yPartiallyShown => 'partially shown';

  @override
  String get a11yHidden => 'hidden';

  @override
  String get a11yDoubleTapShow => 'Double tap to show all accounts';

  @override
  String get a11yDoubleTapHide => 'Double tap to hide all accounts';

  @override
  String get a11yInternalTransfer => 'internal transfer';

  @override
  String get a11yOfAssets => 'of assets';

  @override
  String get a11yOfLiabilities => 'of liabilities';

  @override
  String get a11yBalanceWord => 'balance';

  @override
  String a11yAccountBalance(Object account, Object amount) {
    return '$account balance $amount';
  }

  @override
  String get qaUnavailableNoAmount => 'unavailable until an amount is entered';

  @override
  String get bfNetWorthFiltered => 'NET WORTH · FILTERED';

  @override
  String bfVisibleCategories(int visible, int total) {
    return '$visible of $total categories';
  }

  @override
  String bfVisibleAccounts(int visible, int total) {
    return '$visible of $total accounts';
  }

  @override
  String get bdAMonth => 'a month';

  @override
  String get bdSpent => 'spent';

  @override
  String bdSpentOver(String over) {
    return 'spent · $over over';
  }

  @override
  String bdDayOfMonth(int day, int total) {
    return 'day $day of $total';
  }

  @override
  String get bdAgainstLimit => 'AGAINST THE LIMIT';

  @override
  String get mpMonth => 'MONTH';

  @override
  String get srDateRange => 'DATE RANGE';

  @override
  String get srCustomRange => 'CUSTOM RANGE';

  @override
  String get calFrom => 'FROM';

  @override
  String get calTo => 'TO';

  @override
  String plOfTarget(String target) {
    return 'of $target target';
  }

  @override
  String get dsKeepIt => 'Keep it';

  @override
  String get qaExampleCategory => 'e.g. Groceries';

  @override
  String get qaExampleAccount => 'e.g. Main Checking';

  @override
  String get qaExampleGoal => 'e.g. MacBook Pro M4';

  @override
  String get goalSecSaving => 'Saving';

  @override
  String get goalSecPayingOff => 'Paying off';

  @override
  String get goalSecWaitingOn => 'Waiting on';

  @override
  String get goalSecEarning => 'Earning';

  @override
  String goalOfTotal(Object current, Object target) {
    return '$current of $target';
  }

  @override
  String goalLeftTotal(Object amount) {
    return '$amount left';
  }

  @override
  String goalOwedTotal(Object amount) {
    return '$amount owed';
  }

  @override
  String get goalSourceUnavailable => 'Source unavailable';

  @override
  String get goalReached => 'Reached';

  @override
  String goalReachedEarly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Reached $days days early',
      one: 'Reached 1 day early',
    );
    return '$_temp0';
  }

  @override
  String get goalNothingYet => 'nothing yet';

  @override
  String goalAmountIn(Object amount) {
    return '$amount in';
  }

  @override
  String goalDueLine(Object date, Object tail) {
    return 'Due $date · $tail';
  }

  @override
  String get goalFunded => 'Funded';

  @override
  String goalRefill(Object amount) {
    return 'Refill $amount';
  }

  @override
  String goalBehind(Object phrase) {
    return 'Behind · $phrase';
  }

  @override
  String plGoalRateSave(Object rate) {
    return 'save $rate/mo';
  }

  @override
  String plGoalRatePay(Object rate) {
    return 'pay $rate/mo';
  }

  @override
  String plGoalRateCollect(Object rate) {
    return 'collect $rate/mo';
  }

  @override
  String plGoalRateEarn(Object rate) {
    return 'earn $rate/mo';
  }

  @override
  String goalAhead(Object rate) {
    return 'Ahead · $rate/mo left';
  }

  @override
  String goalOnTrack(Object rate) {
    return 'On track · $rate/mo';
  }

  @override
  String goalPerMonth(Object amount) {
    return '$amount a month';
  }

  @override
  String get goalNewTitle => 'New goal';

  @override
  String get goalWatching => 'Watching';

  @override
  String get goalSource => 'Source';

  @override
  String get goalSourceLocked => 'Changing the account means a new goal.';

  @override
  String get goalSetDateHint => 'Set a date, or a monthly amount';

  @override
  String get goalMonthly => 'Monthly';

  @override
  String get goalEnterRate => 'Set a monthly amount';

  @override
  String get goalNoteLabel => 'Note';

  @override
  String get goalNoteHint => 'Optional';

  @override
  String get goalDoneOnceReached => 'Done once reached';

  @override
  String get goalDoneOnceReachedDesc => 'Off for funds you refill';

  @override
  String get goalDeleteRowDesc => 'Removes the goal, keeps the money';

  @override
  String get goalOfWord => 'of';

  @override
  String goalNewAccountNamed(Object name) {
    return 'New · $name';
  }

  @override
  String get goalUntitled => 'New goal';

  @override
  String get goalChooseSource => 'Choose what to watch';

  @override
  String get goalTwoOnAccount =>
      'Another goal already watches this account. That\'s allowed — both read the same balance.';

  @override
  String get goalMonthlyPromptTitle => 'Monthly amount';

  @override
  String get goalNewAccountOption => 'New account';

  @override
  String get goalNewAccountOptionDesc =>
      'A set-aside account, named from the goal';

  @override
  String get goalIncomeCategories => 'Income categories';

  @override
  String goalDeleteTitle(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get goalDeleteBody =>
      'The goal and its history go. Nothing else moves.';

  @override
  String goalDeleteAccountStays(Object name, Object balance) {
    return 'Account \"$name\" stays · $balance';
  }

  @override
  String goalDeleteTxnStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count transactions stay',
      one: 'Its 1 transaction stays',
    );
    return '$_temp0';
  }

  @override
  String get goalDeleteCategoryStays =>
      'The income category and its transactions stay';

  @override
  String goalOfToGo(Object target, Object remaining) {
    return 'of $target · $remaining to go';
  }

  @override
  String goalDaysCaption(Object pct, int elapsed, int total) {
    return '$pct · $elapsed of $total days';
  }

  @override
  String get goalColStarted => 'Started';

  @override
  String get goalColTarget => 'Target';

  @override
  String get goalColAtThisRate => 'At this rate';

  @override
  String get goalReachedSummary => 'Reached — nothing more to do';

  @override
  String get goalNotMovingYet => 'Not moving yet';

  @override
  String goalAveragingOnly(Object rate) {
    return 'Averaging $rate a month';
  }

  @override
  String goalAveraging(Object actual, Object needs) {
    return 'Now $actual/mo · needs $needs/mo to land on time';
  }

  @override
  String a11yMoneyIn(Object amount) {
    return 'Money in, $amount';
  }

  @override
  String a11yMoneyOut(Object amount) {
    return 'Money out, $amount';
  }

  @override
  String goalCategoryWindow(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get goalMovements => 'Movements';

  @override
  String goalSeeAll(int count) {
    return 'See all $count';
  }

  @override
  String get goalNoteSection => 'Note';

  @override
  String get goalChanges => 'Changes';

  @override
  String get goalChangeCreated => 'Created';

  @override
  String get goalChangeTarget => 'Target';

  @override
  String get goalChangeDate => 'Target date';

  @override
  String get goalMenuEdit => 'Edit goal';

  @override
  String get goalStopTracking => 'Stop tracking';

  @override
  String get goalStopTrackingDesc => 'Keeps the record in Archive';

  @override
  String get goalReachedAtZero => 'Reached, and the account is empty.';

  @override
  String get goalKeepAccount => 'Keep account';

  @override
  String get goalArchiveBoth => 'Archive both';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get moreTags => 'Tags';

  @override
  String tagsSubtitle(int inUse, int archived) {
    return '$inUse in use · $archived archived';
  }

  @override
  String tagSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get tagSearchOrCreate => 'Search or create';

  @override
  String tagCreate(Object name) {
    return 'Create #$name';
  }

  @override
  String get tagSectionInUse => 'In use';

  @override
  String get tagSectionArchived => 'Archived';

  @override
  String get tagNeverUsed => 'Not used yet';

  @override
  String tagUsageLine(int count, Object date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions · last $date',
      one: '$count transaction · last $date',
    );
    return '$_temp0';
  }

  @override
  String get tagArchiveFootnote =>
      'Archived tags stay on their transactions and stay searchable. They just don\'t appear when you tag something new.';

  @override
  String get tagActionArchive => 'Archive';

  @override
  String get tagActionRename => 'Rename';

  @override
  String get tagNewTitle => 'New tag';

  @override
  String get tagNameHint => 'Tag name';

  @override
  String tagRenameTitle(Object name) {
    return 'Rename #$name';
  }

  @override
  String tagRenameSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions carry this tag',
      one: '$count transaction carries this tag',
    );
    return '$_temp0';
  }

  @override
  String tagMergeWarning(Object target, int count) {
    return 'A tag named #$target already exists. The two will merge into one tag on $count transactions. This cannot be undone.';
  }

  @override
  String tagMergeButton(Object target) {
    return 'Merge into #$target';
  }

  @override
  String get tagArchivedBadge => 'archived';
}
