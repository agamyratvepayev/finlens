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

  /// No description provided for @txnRevaluation.
  ///
  /// In en, this message translates to:
  /// **'Revaluation'**
  String get txnRevaluation;

  /// No description provided for @txnTransferOut.
  ///
  /// In en, this message translates to:
  /// **'Transfer out'**
  String get txnTransferOut;

  /// No description provided for @txnTransferIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer in'**
  String get txnTransferIn;

  /// No description provided for @plTabBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get plTabBudgets;

  /// No description provided for @plTabGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get plTabGoals;

  /// No description provided for @plTabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get plTabSchedule;

  /// No description provided for @plNoBudgetsYet.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get plNoBudgetsYet;

  /// No description provided for @plNoBudgetsMsg.
  ///
  /// In en, this message translates to:
  /// **'Give a category a monthly limit and it will show up here.'**
  String get plNoBudgetsMsg;

  /// No description provided for @plBudgeted.
  ///
  /// In en, this message translates to:
  /// **'Budgeted'**
  String get plBudgeted;

  /// No description provided for @plNoBudgetSet.
  ///
  /// In en, this message translates to:
  /// **'No budget set'**
  String get plNoBudgetSet;

  /// No description provided for @plSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get plSet;

  /// No description provided for @plNoGoalsYet.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get plNoGoalsYet;

  /// No description provided for @plNoGoalsMsg.
  ///
  /// In en, this message translates to:
  /// **'Set a target and FinLens works out the monthly pace.'**
  String get plNoGoalsMsg;

  /// No description provided for @plNewGoal.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get plNewGoal;

  /// No description provided for @plNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get plNewTask;

  /// No description provided for @plCompleteReady.
  ///
  /// In en, this message translates to:
  /// **'Complete · ready to archive'**
  String get plCompleteReady;

  /// No description provided for @plNoTargetDate.
  ///
  /// In en, this message translates to:
  /// **'No target date set'**
  String get plNoTargetDate;

  /// No description provided for @plMoNeeded.
  ///
  /// In en, this message translates to:
  /// **'/mo needed'**
  String get plMoNeeded;

  /// No description provided for @plComingIn.
  ///
  /// In en, this message translates to:
  /// **'Coming in'**
  String get plComingIn;

  /// No description provided for @plGoingOut.
  ///
  /// In en, this message translates to:
  /// **'Going out'**
  String get plGoingOut;

  /// No description provided for @schOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get schOverdue;

  /// No description provided for @schThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get schThisWeek;

  /// No description provided for @schLater.
  ///
  /// In en, this message translates to:
  /// **'Later this month'**
  String get schLater;

  /// No description provided for @plNothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get plNothingScheduled;

  /// No description provided for @plNothingSchedMsg.
  ///
  /// In en, this message translates to:
  /// **'Bills, salaries and subscriptions you plan will land here.'**
  String get plNothingSchedMsg;

  /// No description provided for @plLeftThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Left this month'**
  String get plLeftThisMonth;

  /// No description provided for @plUnbudgeted.
  ///
  /// In en, this message translates to:
  /// **'unbudgeted'**
  String get plUnbudgeted;

  /// No description provided for @plOf.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get plOf;

  /// No description provided for @plBudgetWord.
  ///
  /// In en, this message translates to:
  /// **'budget'**
  String get plBudgetWord;

  /// No description provided for @plSavedTowardGoals.
  ///
  /// In en, this message translates to:
  /// **'Saved toward goals'**
  String get plSavedTowardGoals;

  /// No description provided for @plPaymentsOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} payment overdue} other{{count} payments overdue}} · {amount}'**
  String plPaymentsOverdue(int count, Object amount);

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldSelectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get fieldSelectAccount;

  /// No description provided for @fieldDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get fieldDirection;

  /// No description provided for @actionUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get actionUse;

  /// No description provided for @actionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get actionRestore;

  /// No description provided for @countMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month} other{{count} months}}'**
  String countMonths(int count);

  /// No description provided for @ebTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get ebTitle;

  /// No description provided for @ebMonthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit'**
  String get ebMonthlyLimit;

  /// No description provided for @ebRollOver.
  ///
  /// In en, this message translates to:
  /// **'Roll over unspent'**
  String get ebRollOver;

  /// No description provided for @ebRollOverDesc.
  ///
  /// In en, this message translates to:
  /// **'Add leftovers to next month'**
  String get ebRollOverDesc;

  /// No description provided for @ebWarnAt.
  ///
  /// In en, this message translates to:
  /// **'Warn me at'**
  String get ebWarnAt;

  /// No description provided for @ebRemoveBudget.
  ///
  /// In en, this message translates to:
  /// **'Remove budget'**
  String get ebRemoveBudget;

  /// No description provided for @ebAverage.
  ///
  /// In en, this message translates to:
  /// **'You average {average}. Try {suggestion}?'**
  String ebAverage(Object average, Object suggestion);

  /// No description provided for @ebRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} budget?'**
  String ebRemoveTitle(Object name);

  /// No description provided for @ebRemoveMsg.
  ///
  /// In en, this message translates to:
  /// **'You\'ll stop tracking a limit for this category.'**
  String get ebRemoveMsg;

  /// No description provided for @ebCategoryStays.
  ///
  /// In en, this message translates to:
  /// **'The {name} category stays. {count, plural, one{Your {count} transaction is untouched.} other{Your {count} transactions are untouched.}}'**
  String ebCategoryStays(Object name, int count);

  /// No description provided for @ebWarningsDisappear.
  ///
  /// In en, this message translates to:
  /// **'Warnings and progress bars for this category disappear.'**
  String get ebWarningsDisappear;

  /// No description provided for @ebTotalDrops.
  ///
  /// In en, this message translates to:
  /// **'Total monthly budget drops from {from} to {to}.'**
  String ebTotalDrops(Object from, Object to);

  /// No description provided for @egTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get egTitle;

  /// No description provided for @egGoalName.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get egGoalName;

  /// No description provided for @egType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get egType;

  /// No description provided for @egTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get egTargetAmount;

  /// No description provided for @egTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get egTargetDate;

  /// No description provided for @egMoneyKeptIn.
  ///
  /// In en, this message translates to:
  /// **'Money kept in'**
  String get egMoneyKeptIn;

  /// No description provided for @egAutoContribute.
  ///
  /// In en, this message translates to:
  /// **'Auto contribute'**
  String get egAutoContribute;

  /// No description provided for @egAutoContributeDesc.
  ///
  /// In en, this message translates to:
  /// **'Creates a monthly transfer into this goal'**
  String get egAutoContributeDesc;

  /// No description provided for @egMonthlyContribution.
  ///
  /// In en, this message translates to:
  /// **'Monthly contribution'**
  String get egMonthlyContribution;

  /// No description provided for @egMarkReached.
  ///
  /// In en, this message translates to:
  /// **'Mark as reached'**
  String get egMarkReached;

  /// No description provided for @egMarkReachedDesc.
  ///
  /// In en, this message translates to:
  /// **'Money is spent, goal is done'**
  String get egMarkReachedDesc;

  /// No description provided for @egGiveUp.
  ///
  /// In en, this message translates to:
  /// **'Give up for now'**
  String get egGiveUp;

  /// No description provided for @egDeleteGoal.
  ///
  /// In en, this message translates to:
  /// **'Delete goal'**
  String get egDeleteGoal;

  /// No description provided for @egDeleteGoalDesc.
  ///
  /// In en, this message translates to:
  /// **'As if it never existed'**
  String get egDeleteGoalDesc;

  /// No description provided for @egMarkReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark {name} as reached?'**
  String egMarkReachedTitle(Object name);

  /// No description provided for @egMarkReachedMsg.
  ///
  /// In en, this message translates to:
  /// **'Congratulations — this moves the goal into your archive as a success.'**
  String get egMarkReachedMsg;

  /// No description provided for @egReachedAfter.
  ///
  /// In en, this message translates to:
  /// **'Recorded as reached after {count, plural, one{{count} month} other{{count} months}}, feeding your goal-performance stats.'**
  String egReachedAfter(int count);

  /// No description provided for @egPastTxnStay.
  ///
  /// In en, this message translates to:
  /// **'Past transactions stay in your Ledger.'**
  String get egPastTxnStay;

  /// No description provided for @egLeavesStops.
  ///
  /// In en, this message translates to:
  /// **'It leaves the Goals list and stops tracking.'**
  String get egLeavesStops;

  /// No description provided for @egAutoStops.
  ///
  /// In en, this message translates to:
  /// **'The monthly auto-contribution stops.'**
  String get egAutoStops;

  /// No description provided for @egNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get egNotYet;

  /// No description provided for @egGiveUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Give up on {name}?'**
  String egGiveUpTitle(Object name);

  /// No description provided for @egGiveUpMsg.
  ///
  /// In en, this message translates to:
  /// **'Tracking stops, but the money you already put aside stays exactly where it is.'**
  String get egGiveUpMsg;

  /// No description provided for @egSavedStaysIn.
  ///
  /// In en, this message translates to:
  /// **'The {amount} stays in {account}.'**
  String egSavedStaysIn(Object amount, Object account);

  /// No description provided for @egYourAccount.
  ///
  /// In en, this message translates to:
  /// **'your account'**
  String get egYourAccount;

  /// No description provided for @egRestoreLater.
  ///
  /// In en, this message translates to:
  /// **'You can restore it later from the Archive.'**
  String get egRestoreLater;

  /// No description provided for @egLeavesList.
  ///
  /// In en, this message translates to:
  /// **'It leaves the Goals list.'**
  String get egLeavesList;

  /// No description provided for @egDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String egDeleteTitle(Object name);

  /// No description provided for @egDeleteMsg.
  ///
  /// In en, this message translates to:
  /// **'Use this only when the goal was created by mistake — it leaves no trace in your history.'**
  String get egDeleteMsg;

  /// No description provided for @egBalancesUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Your account balances do not change.'**
  String get egBalancesUnchanged;

  /// No description provided for @egNotInArchive.
  ///
  /// In en, this message translates to:
  /// **'It will not appear in the Archive.'**
  String get egNotInArchive;

  /// No description provided for @egExcludedStats.
  ///
  /// In en, this message translates to:
  /// **'It is excluded from goal-performance stats.'**
  String get egExcludedStats;

  /// No description provided for @egRecurringCancelled.
  ///
  /// In en, this message translates to:
  /// **'The recurring transfer rule is cancelled.'**
  String get egRecurringCancelled;

  /// No description provided for @egPerMonthTrack.
  ///
  /// In en, this message translates to:
  /// **'{amount}/mo to stay on track'**
  String egPerMonthTrack(Object amount);

  /// No description provided for @egAutoContributeOn.
  ///
  /// In en, this message translates to:
  /// **'{amount} on the {day}'**
  String egAutoContributeOn(Object amount, Object day);

  /// No description provided for @egKeepsStops.
  ///
  /// In en, this message translates to:
  /// **'Keeps the {amount}, stops tracking'**
  String egKeepsStops(Object amount);

  /// No description provided for @egSaved.
  ///
  /// In en, this message translates to:
  /// **'saved'**
  String get egSaved;

  /// No description provided for @egToGo.
  ///
  /// In en, this message translates to:
  /// **'to go'**
  String get egToGo;

  /// No description provided for @ebWhatSpent.
  ///
  /// In en, this message translates to:
  /// **'What you actually spent'**
  String get ebWhatSpent;

  /// No description provided for @ebSpent.
  ///
  /// In en, this message translates to:
  /// **'spent'**
  String get ebSpent;

  /// No description provided for @etTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get etTitle;

  /// No description provided for @etTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get etTaskTitle;

  /// No description provided for @etPaidFrom.
  ///
  /// In en, this message translates to:
  /// **'Paid from'**
  String get etPaidFrom;

  /// No description provided for @etPaidInto.
  ///
  /// In en, this message translates to:
  /// **'Paid into'**
  String get etPaidInto;

  /// No description provided for @etLinkedAccount.
  ///
  /// In en, this message translates to:
  /// **'Linked account'**
  String get etLinkedAccount;

  /// No description provided for @etPayOut.
  ///
  /// In en, this message translates to:
  /// **'Pay out −'**
  String get etPayOut;

  /// No description provided for @etPayIn.
  ///
  /// In en, this message translates to:
  /// **'Pay in +'**
  String get etPayIn;

  /// No description provided for @etExpectedAmount.
  ///
  /// In en, this message translates to:
  /// **'Expected amount'**
  String get etExpectedAmount;

  /// No description provided for @etCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Where \"Mark as paid\" books it'**
  String get etCategoryHint;

  /// No description provided for @etNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get etNextDue;

  /// No description provided for @etRepeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get etRepeats;

  /// No description provided for @etOneOff.
  ///
  /// In en, this message translates to:
  /// **'One-off task'**
  String get etOneOff;

  /// No description provided for @etRemindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get etRemindMe;

  /// No description provided for @etRemindBefore.
  ///
  /// In en, this message translates to:
  /// **'{days} days before, {time}'**
  String etRemindBefore(Object days, Object time);

  /// No description provided for @etMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get etMarkPaid;

  /// No description provided for @etMarkPaidExpense.
  ///
  /// In en, this message translates to:
  /// **'Creates the expense in Ledger'**
  String get etMarkPaidExpense;

  /// No description provided for @etMarkPaidIncome.
  ///
  /// In en, this message translates to:
  /// **'Creates the income in Ledger'**
  String get etMarkPaidIncome;

  /// No description provided for @etSkipThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Skip this month'**
  String get etSkipThisMonth;

  /// No description provided for @etSeriesContinues.
  ///
  /// In en, this message translates to:
  /// **'Series continues in {month}'**
  String etSeriesContinues(Object month);

  /// No description provided for @etDeleteWholeSeries.
  ///
  /// In en, this message translates to:
  /// **'Delete the whole series'**
  String get etDeleteWholeSeries;

  /// No description provided for @etAllFutureReminders.
  ///
  /// In en, this message translates to:
  /// **'All future {title} reminders'**
  String etAllFutureReminders(Object title);

  /// No description provided for @etSkippedNext.
  ///
  /// In en, this message translates to:
  /// **'Skipped · next on {date}'**
  String etSkippedNext(Object date);

  /// No description provided for @etDeleteOnly.
  ///
  /// In en, this message translates to:
  /// **'Delete only {date}'**
  String etDeleteOnly(Object date);

  /// No description provided for @etDeleteOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete only {date}?'**
  String etDeleteOnlyTitle(Object date);

  /// No description provided for @etJustThisOne.
  ///
  /// In en, this message translates to:
  /// **'Just this one occurrence is removed.'**
  String get etJustThisOne;

  /// No description provided for @etOneOffRemoved.
  ///
  /// In en, this message translates to:
  /// **'This one-off task is removed.'**
  String get etOneOffRemoved;

  /// No description provided for @etSeriesContinuesOn.
  ///
  /// In en, this message translates to:
  /// **'The series continues on {date}.'**
  String etSeriesContinuesOn(Object date);

  /// No description provided for @etNoLedgerEntry.
  ///
  /// In en, this message translates to:
  /// **'No Ledger entry is created or removed.'**
  String get etNoLedgerEntry;

  /// No description provided for @etLedgerUntouched.
  ///
  /// In en, this message translates to:
  /// **'Your Ledger is untouched.'**
  String get etLedgerUntouched;

  /// No description provided for @etDisappears.
  ///
  /// In en, this message translates to:
  /// **'{date} disappears from your Schedule.'**
  String etDisappears(Object date);

  /// No description provided for @etDeleteDate.
  ///
  /// In en, this message translates to:
  /// **'Delete {date}'**
  String etDeleteDate(Object date);

  /// No description provided for @etDeleteSeriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the whole {title} series?'**
  String etDeleteSeriesTitle(Object title);

  /// No description provided for @etDeleteSeriesMsg.
  ///
  /// In en, this message translates to:
  /// **'Every future occurrence is removed, not just the next one.'**
  String get etDeleteSeriesMsg;

  /// No description provided for @etPaymentsStay.
  ///
  /// In en, this message translates to:
  /// **'Payments you already recorded stay in your Ledger.'**
  String get etPaymentsStay;

  /// No description provided for @etAllRemindersCancelled.
  ///
  /// In en, this message translates to:
  /// **'All future reminders are cancelled.'**
  String get etAllRemindersCancelled;

  /// No description provided for @etOutgoingsDrop.
  ///
  /// In en, this message translates to:
  /// **'Your monthly outgoings drop by {amount}.'**
  String etOutgoingsDrop(Object amount);

  /// No description provided for @etDeleteSeries.
  ///
  /// In en, this message translates to:
  /// **'Delete series'**
  String get etDeleteSeries;

  /// No description provided for @etRecordedInLedger.
  ///
  /// In en, this message translates to:
  /// **'{title} recorded in your Ledger'**
  String etRecordedInLedger(Object title);

  /// No description provided for @etRepeatsCadence.
  ///
  /// In en, this message translates to:
  /// **'Repeats {cadence}'**
  String etRepeatsCadence(Object cadence);

  /// No description provided for @bdAveraging.
  ///
  /// In en, this message translates to:
  /// **'Averaging {avg} · over the {limit} limit in {count} of 6'**
  String bdAveraging(Object avg, Object limit, Object count);

  /// No description provided for @bdNothingSpent.
  ///
  /// In en, this message translates to:
  /// **'Nothing spent here this month.'**
  String get bdNothingSpent;

  /// No description provided for @arEmpty.
  ///
  /// In en, this message translates to:
  /// **'Archive is empty'**
  String get arEmpty;

  /// No description provided for @arEmptyMsg.
  ///
  /// In en, this message translates to:
  /// **'Goals you reach or give up on, and budgets you remove, are kept here.'**
  String get arEmptyMsg;

  /// No description provided for @arFootnote.
  ///
  /// In en, this message translates to:
  /// **'Archived items don\'t appear in Planner and don\'t affect your totals. Their past transactions stay in Ledger.'**
  String get arFootnote;

  /// No description provided for @arReachedGoals.
  ///
  /// In en, this message translates to:
  /// **'Reached goals'**
  String get arReachedGoals;

  /// No description provided for @arReachedLine.
  ///
  /// In en, this message translates to:
  /// **'Reached {date} · took {count, plural, one{{count} month} other{{count} months}}'**
  String arReachedLine(Object date, int count);

  /// No description provided for @arGaveUp.
  ///
  /// In en, this message translates to:
  /// **'Gave up'**
  String get arGaveUp;

  /// No description provided for @arStoppedLine.
  ///
  /// In en, this message translates to:
  /// **'Stopped {date} · {saved} of {target}'**
  String arStoppedLine(Object date, Object saved, Object target);

  /// No description provided for @arRemovedBudgets.
  ///
  /// In en, this message translates to:
  /// **'Removed budgets'**
  String get arRemovedBudgets;

  /// No description provided for @arRemovedLine.
  ///
  /// In en, this message translates to:
  /// **'Removed {date}'**
  String arRemovedLine(Object date);

  /// No description provided for @arClearPermanently.
  ///
  /// In en, this message translates to:
  /// **'Clear archive permanently'**
  String get arClearPermanently;

  /// No description provided for @arClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the archive?'**
  String get arClearTitle;

  /// No description provided for @arClearMsg.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{All {count} archived item is erased for good.} other{All {count} archived items are erased for good.}}'**
  String arClearMsg(int count);

  /// No description provided for @arTxnStay.
  ///
  /// In en, this message translates to:
  /// **'Every related transaction stays in your Ledger.'**
  String get arTxnStay;

  /// No description provided for @arBalancesUnaffected.
  ///
  /// In en, this message translates to:
  /// **'Account balances are unaffected.'**
  String get arBalancesUnaffected;

  /// No description provided for @arRestoreImpossible.
  ///
  /// In en, this message translates to:
  /// **'Restore is no longer possible.'**
  String get arRestoreImpossible;

  /// No description provided for @arStatsDisappear.
  ///
  /// In en, this message translates to:
  /// **'Reached-goal history disappears from your stats.'**
  String get arStatsDisappear;

  /// No description provided for @arClearArchive.
  ///
  /// In en, this message translates to:
  /// **'Clear archive'**
  String get arClearArchive;
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
