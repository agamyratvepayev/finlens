import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tk.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('tk'),
    Locale('tr'),
  ];

  /// Row label for the language selector in More > Preferences.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language picker option: follow the device locale.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @accountGroupSpendable.
  ///
  /// In en, this message translates to:
  /// **'Spendable'**
  String get accountGroupSpendable;

  /// No description provided for @accountGroupReceivables.
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get accountGroupReceivables;

  /// No description provided for @accountGroupInvestments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get accountGroupInvestments;

  /// No description provided for @accountGroupValuables.
  ///
  /// In en, this message translates to:
  /// **'Valuables'**
  String get accountGroupValuables;

  /// No description provided for @accountGroupCreditCards.
  ///
  /// In en, this message translates to:
  /// **'Credit Cards'**
  String get accountGroupCreditCards;

  /// No description provided for @accountGroupPayables.
  ///
  /// In en, this message translates to:
  /// **'Payables'**
  String get accountGroupPayables;

  /// No description provided for @accountGroupBankLoans.
  ///
  /// In en, this message translates to:
  /// **'Bank Loans'**
  String get accountGroupBankLoans;

  /// No description provided for @quickAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get quickAddExpense;

  /// No description provided for @quickAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get quickAddIncome;

  /// No description provided for @quickAddTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get quickAddTransfer;

  /// No description provided for @quickAddRebalance.
  ///
  /// In en, this message translates to:
  /// **'Rebalance'**
  String get quickAddRebalance;

  /// No description provided for @quickAddNewGoal.
  ///
  /// In en, this message translates to:
  /// **'New Goal'**
  String get quickAddNewGoal;

  /// No description provided for @quickAddNewTask.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get quickAddNewTask;

  /// No description provided for @txnTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get txnTypeExpense;

  /// No description provided for @txnTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get txnTypeIncome;

  /// No description provided for @txnTypeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get txnTypeTransfer;

  /// No description provided for @txnTypeRebalance.
  ///
  /// In en, this message translates to:
  /// **'Rebalance'**
  String get txnTypeRebalance;

  /// No description provided for @goalTypeSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get goalTypeSaving;

  /// No description provided for @goalTypeMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get goalTypeMilestone;

  /// No description provided for @goalTypePurchasing.
  ///
  /// In en, this message translates to:
  /// **'Purchasing'**
  String get goalTypePurchasing;

  /// No description provided for @goalSectionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get goalSectionSaving;

  /// No description provided for @goalSectionMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get goalSectionMilestone;

  /// No description provided for @goalSectionPurchasing.
  ///
  /// In en, this message translates to:
  /// **'Purchasing'**
  String get goalSectionPurchasing;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @repeatNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatNever;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get repeatQuarterly;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get repeatYearly;

  /// No description provided for @comparePeriodTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get comparePeriodTodayLabel;

  /// No description provided for @comparePeriodTodayCaption.
  ///
  /// In en, this message translates to:
  /// **'vs yesterday'**
  String get comparePeriodTodayCaption;

  /// No description provided for @comparePeriodWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get comparePeriodWeekLabel;

  /// No description provided for @comparePeriodWeekCaption.
  ///
  /// In en, this message translates to:
  /// **'vs last week'**
  String get comparePeriodWeekCaption;

  /// No description provided for @comparePeriodMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get comparePeriodMonthLabel;

  /// No description provided for @comparePeriodMonthCaption.
  ///
  /// In en, this message translates to:
  /// **'vs last month'**
  String get comparePeriodMonthCaption;

  /// No description provided for @rangeThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get rangeThisWeek;

  /// No description provided for @rangeLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get rangeLastWeek;

  /// No description provided for @rangeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get rangeThisMonth;

  /// No description provided for @rangeLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get rangeLastMonth;

  /// No description provided for @rangeLast3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 months'**
  String get rangeLast3Months;

  /// No description provided for @rangeLast6Months.
  ///
  /// In en, this message translates to:
  /// **'Last 6 months'**
  String get rangeLast6Months;

  /// No description provided for @rangeLast12Months.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get rangeLast12Months;

  /// No description provided for @rangeThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get rangeThisYear;

  /// No description provided for @rangeAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get rangeAllTime;

  /// No description provided for @navBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get navBalance;

  /// No description provided for @navLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get navLedger;

  /// No description provided for @navPlanner.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get navPlanner;

  /// No description provided for @navInsight.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get navInsight;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @accountSortValueDesc.
  ///
  /// In en, this message translates to:
  /// **'Value — high to low'**
  String get accountSortValueDesc;

  /// No description provided for @accountSortValueAsc.
  ///
  /// In en, this message translates to:
  /// **'Value — low to high'**
  String get accountSortValueAsc;

  /// No description provided for @accountSortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name — A to Z'**
  String get accountSortNameAsc;

  /// No description provided for @accountSortActivity.
  ///
  /// In en, this message translates to:
  /// **'Change — most active'**
  String get accountSortActivity;

  /// No description provided for @accountSortCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get accountSortCustom;

  /// No description provided for @balanceSectionAll.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get balanceSectionAll;

  /// No description provided for @balanceSectionAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get balanceSectionAssets;

  /// No description provided for @balanceSectionLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get balanceSectionLiabilities;

  /// No description provided for @transSortDateNewest.
  ///
  /// In en, this message translates to:
  /// **'Date — newest first'**
  String get transSortDateNewest;

  /// No description provided for @transSortDateOldest.
  ///
  /// In en, this message translates to:
  /// **'Date — oldest first'**
  String get transSortDateOldest;

  /// No description provided for @transSortAmountHigh.
  ///
  /// In en, this message translates to:
  /// **'Amount — high to low'**
  String get transSortAmountHigh;

  /// No description provided for @transSortAmountLow.
  ///
  /// In en, this message translates to:
  /// **'Amount — low to high'**
  String get transSortAmountLow;

  /// No description provided for @transSortByCategory.
  ///
  /// In en, this message translates to:
  /// **'Category — A to Z'**
  String get transSortByCategory;

  /// No description provided for @transSortByAccount.
  ///
  /// In en, this message translates to:
  /// **'Account — A to Z'**
  String get transSortByAccount;

  /// No description provided for @ledgerAllAccounts.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get ledgerAllAccounts;

  /// No description provided for @ledgerAccountFallback.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get ledgerAccountFallback;

  /// Abbreviated month name by month number 1-12.
  ///
  /// In en, this message translates to:
  /// **'{month, select, 1{Jan} 2{Feb} 3{Mar} 4{Apr} 5{May} 6{Jun} 7{Jul} 8{Aug} 9{Sep} 10{Oct} 11{Nov} 12{Dec} other{}}'**
  String monthShort(String month);

  /// Full month name by month number 1-12.
  ///
  /// In en, this message translates to:
  /// **'{month, select, 1{January} 2{February} 3{March} 4{April} 5{May} 6{June} 7{July} 8{August} 9{September} 10{October} 11{November} 12{December} other{}}'**
  String monthLong(String month);

  /// Full weekday name by ISO weekday number 1 (Mon) - 7 (Sun).
  ///
  /// In en, this message translates to:
  /// **'{weekday, select, 1{Monday} 2{Tuesday} 3{Wednesday} 4{Thursday} 5{Friday} 6{Saturday} 7{Sunday} other{}}'**
  String weekdayLong(String weekday);

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// No description provided for @dateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dateTomorrow;

  /// A date label followed by a time, e.g. 'Today, 14:32'.
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dateWithTime(String date, String time);

  /// Ledger day-group header for yesterday, e.g. 'Yesterday · 8 Aug'.
  ///
  /// In en, this message translates to:
  /// **'Yesterday · {date}'**
  String dateGroupYesterday(String date);

  /// All-time range label, e.g. 'Since Mar 2023'.
  ///
  /// In en, this message translates to:
  /// **'Since {monthYear}'**
  String rangeSince(String monthYear);

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get dueToday;

  /// No description provided for @dueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get dueTomorrow;

  /// No description provided for @dueInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{in {days} day} other{in {days} days}}'**
  String dueInDays(int days);

  /// No description provided for @dueDaysLate.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{{days} day late} other{{days} days late}}'**
  String dueDaysLate(int days);

  /// No description provided for @countAccounts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} account} other{{count} accounts}}'**
  String countAccounts(int count);

  /// No description provided for @countTransactions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} transaction} other{{count} transactions}}'**
  String countTransactions(int count);

  /// No description provided for @countResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} result} other{{count} results}}'**
  String countResults(int count);

  /// No description provided for @countDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String countDays(int count);

  /// No description provided for @countArchivedItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} archived item} other{{count} archived items}}'**
  String countArchivedItems(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @moreYourMoney.
  ///
  /// In en, this message translates to:
  /// **'Your money'**
  String get moreYourMoney;

  /// No description provided for @morePlannerSection.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get morePlannerSection;

  /// No description provided for @morePreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get morePreferences;

  /// No description provided for @moreCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get moreCategories;

  /// No description provided for @moreCategoriesInUse.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} in use} other{{count} in use}}'**
  String moreCategoriesInUse(int count);

  /// No description provided for @moreArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get moreArchive;

  /// No description provided for @morePrivacyMode.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode'**
  String get morePrivacyMode;

  /// No description provided for @morePrivacyModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Mask every amount across the app'**
  String get morePrivacyModeDesc;

  /// No description provided for @moreAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add an account'**
  String get moreAddAccount;

  /// No description provided for @insightTitle.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get insightTitle;

  /// No description provided for @insightLeftOver.
  ///
  /// In en, this message translates to:
  /// **'Left over'**
  String get insightLeftOver;

  /// No description provided for @insightNoIncome.
  ///
  /// In en, this message translates to:
  /// **'No income recorded this month'**
  String get insightNoIncome;

  /// No description provided for @insightKept.
  ///
  /// In en, this message translates to:
  /// **'{percent} of {amount} kept'**
  String insightKept(String percent, String amount);

  /// No description provided for @insightWhereItWent.
  ///
  /// In en, this message translates to:
  /// **'Where it went'**
  String get insightWhereItWent;

  /// No description provided for @insightGoalPerformance.
  ///
  /// In en, this message translates to:
  /// **'Goal performance'**
  String get insightGoalPerformance;

  /// No description provided for @insightReached.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get insightReached;

  /// No description provided for @insightSuccessRate.
  ///
  /// In en, this message translates to:
  /// **'Success rate'**
  String get insightSuccessRate;

  /// No description provided for @insightAvgTime.
  ///
  /// In en, this message translates to:
  /// **'Avg. time'**
  String get insightAvgTime;

  /// No description provided for @insightMonthsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} mo'**
  String insightMonthsShort(int count);

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get actionMoveUp;

  /// No description provided for @actionMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get actionMoveDown;

  /// No description provided for @actionCollapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get actionCollapseAll;

  /// No description provided for @actionExpandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get actionExpandAll;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @balSearchAccounts.
  ///
  /// In en, this message translates to:
  /// **'Search accounts'**
  String get balSearchAccounts;

  /// No description provided for @balNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get balNoResults;

  /// No description provided for @balNoAccountsYet.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get balNoAccountsYet;

  /// No description provided for @balNoAccountMatch.
  ///
  /// In en, this message translates to:
  /// **'No account or group matches your search.'**
  String get balNoAccountMatch;

  /// No description provided for @balAddFirstAccount.
  ///
  /// In en, this message translates to:
  /// **'Add your first account'**
  String get balAddFirstAccount;

  /// No description provided for @balNoAccountsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your accounts and FinLens works out your net worth from the transactions you record.'**
  String get balNoAccountsMessage;

  /// No description provided for @balAdjustFilter.
  ///
  /// In en, this message translates to:
  /// **'Adjust filter'**
  String get balAdjustFilter;

  /// No description provided for @balSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get balSortTooltip;

  /// No description provided for @balHoldToArrange.
  ///
  /// In en, this message translates to:
  /// **'Hold an account to arrange'**
  String get balHoldToArrange;

  /// No description provided for @balPressHoldMove.
  ///
  /// In en, this message translates to:
  /// **'Press and hold an account to move it'**
  String get balPressHoldMove;

  /// No description provided for @balFilterCategories.
  ///
  /// In en, this message translates to:
  /// **'Filter categories'**
  String get balFilterCategories;

  /// No description provided for @balNoVisibleCategories.
  ///
  /// In en, this message translates to:
  /// **'No visible categories'**
  String get balNoVisibleCategories;

  /// No description provided for @balSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all {count}  ›'**
  String balSeeAll(int count);

  /// No description provided for @transferFromTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer from {from} to {to}'**
  String transferFromTo(String from, String to);

  /// No description provided for @eaName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get eaName;

  /// No description provided for @eaGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get eaGroup;

  /// No description provided for @eaCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get eaCurrency;

  /// No description provided for @eaStartingBalance.
  ///
  /// In en, this message translates to:
  /// **'Starting balance'**
  String get eaStartingBalance;

  /// No description provided for @eaStartingBalanceLock.
  ///
  /// In en, this message translates to:
  /// **'To fix the balance, add a transaction instead'**
  String get eaStartingBalanceLock;

  /// No description provided for @eaCreditLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get eaCreditLimit;

  /// No description provided for @eaStatementDay.
  ///
  /// In en, this message translates to:
  /// **'Statement day'**
  String get eaStatementDay;

  /// No description provided for @eaPaymentDue.
  ///
  /// In en, this message translates to:
  /// **'Payment due'**
  String get eaPaymentDue;

  /// No description provided for @eaNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get eaNotSet;

  /// No description provided for @eaHideFromBalance.
  ///
  /// In en, this message translates to:
  /// **'Hide from Balance'**
  String get eaHideFromBalance;

  /// No description provided for @eaHideDesc.
  ///
  /// In en, this message translates to:
  /// **'Stays in your totals, disappears from the lists'**
  String get eaHideDesc;

  /// No description provided for @eaRemoveThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove this account'**
  String get eaRemoveThisAccount;

  /// No description provided for @eaRemovePermanent.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes this account'**
  String get eaRemovePermanent;

  /// No description provided for @eaRemoveHasHistory.
  ///
  /// In en, this message translates to:
  /// **'Has history — it will be archived, not erased'**
  String get eaRemoveHasHistory;

  /// No description provided for @eaRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String eaRemoveTitle(String name);

  /// No description provided for @eaArchivedMsg.
  ///
  /// In en, this message translates to:
  /// **'This account has history, so it is archived rather than erased.'**
  String get eaArchivedMsg;

  /// No description provided for @eaDeleteMsg.
  ///
  /// In en, this message translates to:
  /// **'This account has no transactions and can be deleted outright.'**
  String get eaDeleteMsg;

  /// No description provided for @eaTxnStays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Your {count} transaction stays in the Ledger, untouched.} other{Your {count} transactions stay in the Ledger, untouched.}}'**
  String eaTxnStays(int count);

  /// No description provided for @eaGroupDropsBy.
  ///
  /// In en, this message translates to:
  /// **'{group} drops by {amount}.'**
  String eaGroupDropsBy(String group, String amount);

  /// No description provided for @eaDisappearsPicker.
  ///
  /// In en, this message translates to:
  /// **'It disappears from every account picker.'**
  String get eaDisappearsPicker;

  /// No description provided for @eaCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get eaCannotUndo;

  /// No description provided for @eaArchiveAccount.
  ///
  /// In en, this message translates to:
  /// **'Archive account'**
  String get eaArchiveAccount;

  /// No description provided for @eaRemoveAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get eaRemoveAccount;

  /// No description provided for @eaEditAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get eaEditAccount;

  /// No description provided for @balFilterActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Active, {count} item hidden} other{Active, {count} items hidden}}'**
  String balFilterActive(int count);

  /// No description provided for @balFilterOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get balFilterOff;

  /// No description provided for @balMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved'**
  String get balMoved;

  /// No description provided for @balMovedCustom.
  ///
  /// In en, this message translates to:
  /// **'Moved · sorted by Custom'**
  String get balMovedCustom;

  /// No description provided for @balTotalOf.
  ///
  /// In en, this message translates to:
  /// **'Total {name}'**
  String balTotalOf(String name);

  /// No description provided for @balUtilization.
  ///
  /// In en, this message translates to:
  /// **'Utilization: {percent}'**
  String balUtilization(String percent);

  /// No description provided for @balOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get balOverdue;

  /// No description provided for @balDue.
  ///
  /// In en, this message translates to:
  /// **'Due {when}'**
  String balDue(String when);

  /// No description provided for @balNextPayment.
  ///
  /// In en, this message translates to:
  /// **'Next payment: {date}'**
  String balNextPayment(String date);

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterTitle;

  /// No description provided for @sheetApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get sheetApply;

  /// No description provided for @sheetToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sheetToday;

  /// No description provided for @balNoBetween.
  ///
  /// In en, this message translates to:
  /// **'No {subject} between {range}'**
  String balNoBetween(String subject, String range);

  /// No description provided for @freqLessThanMonthly.
  ///
  /// In en, this message translates to:
  /// **'Less than once a month'**
  String get freqLessThanMonthly;

  /// No description provided for @freqAbout.
  ///
  /// In en, this message translates to:
  /// **'About '**
  String get freqAbout;

  /// No description provided for @freqTimesAMonth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{ time a month} other{ times a month}}'**
  String freqTimesAMonth(int count);

  /// No description provided for @txnDeleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this {type}?'**
  String txnDeleteEntryTitle(String type);

  /// No description provided for @txnDeleteEntryMessage.
  ///
  /// In en, this message translates to:
  /// **'This entry is removed for good and the balances below go back to what they were.'**
  String get txnDeleteEntryMessage;

  /// No description provided for @txnDeleteNothingElse.
  ///
  /// In en, this message translates to:
  /// **'Nothing else in your ledger changes.'**
  String get txnDeleteNothingElse;

  /// No description provided for @txnDeleteEntryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get txnDeleteEntryConfirm;

  /// No description provided for @freqLastOne.
  ///
  /// In en, this message translates to:
  /// **' · last one '**
  String get freqLastOne;

  /// No description provided for @txnBudgetImpact.
  ///
  /// In en, this message translates to:
  /// **'{name} budget {before} → {after}'**
  String txnBudgetImpact(Object name, Object before, Object after);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'tk', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'tk':
      return AppLocalizationsTk();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
