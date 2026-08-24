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
}
