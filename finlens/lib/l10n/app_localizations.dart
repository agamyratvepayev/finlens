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

  /// No description provided for @accountGroupSetAside.
  ///
  /// In en, this message translates to:
  /// **'Set aside'**
  String get accountGroupSetAside;

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

  /// Abbreviated weekday name by ISO weekday number 1 (Mon) - 7 (Sun).
  ///
  /// In en, this message translates to:
  /// **'{weekday, select, 1{Mon} 2{Tue} 3{Wed} 4{Thu} 5{Fri} 6{Sat} 7{Sun} other{}}'**
  String weekdayShort(String weekday);

  /// Single-letter weekday initial by ISO weekday number 1 (Mon) - 7 (Sun).
  ///
  /// In en, this message translates to:
  /// **'{weekday, select, 1{M} 2{T} 3{W} 4{T} 5{F} 6{S} 7{S} other{}}'**
  String weekdayNarrow(String weekday);

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

  /// No description provided for @insNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get insNetWorth;

  /// No description provided for @insNetWorthCaption.
  ///
  /// In en, this message translates to:
  /// **'your net worth'**
  String get insNetWorthCaption;

  /// No description provided for @insIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get insIncome;

  /// No description provided for @insSpending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get insSpending;

  /// No description provided for @insDebtCredit.
  ///
  /// In en, this message translates to:
  /// **'Debt & credit'**
  String get insDebtCredit;

  /// No description provided for @insRevaluation.
  ///
  /// In en, this message translates to:
  /// **'Revaluation'**
  String get insRevaluation;

  /// No description provided for @insIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get insIn;

  /// No description provided for @insOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get insOut;

  /// No description provided for @insRevalued.
  ///
  /// In en, this message translates to:
  /// **'Revalued'**
  String get insRevalued;

  /// No description provided for @insYourDebt.
  ///
  /// In en, this message translates to:
  /// **'Your debt'**
  String get insYourDebt;

  /// No description provided for @insYourCredit.
  ///
  /// In en, this message translates to:
  /// **'Owed to you'**
  String get insYourCredit;

  /// No description provided for @insUnchanged.
  ///
  /// In en, this message translates to:
  /// **'unchanged'**
  String get insUnchanged;

  /// No description provided for @insChargedToCards.
  ///
  /// In en, this message translates to:
  /// **'Charged to cards'**
  String get insChargedToCards;

  /// No description provided for @insCardPayment.
  ///
  /// In en, this message translates to:
  /// **'Card payment'**
  String get insCardPayment;

  /// No description provided for @insSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all · {count, plural, =1{1 category} other{{count} categories}}'**
  String insSeeAll(int count);

  /// No description provided for @insCategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String insCategoriesCount(int count);

  /// No description provided for @insUntouchedGained.
  ///
  /// In en, this message translates to:
  /// **'Money you didn\'t touch earned {amount}'**
  String insUntouchedGained(String amount);

  /// No description provided for @insUntouchedLost.
  ///
  /// In en, this message translates to:
  /// **'Money you didn\'t touch lost {amount}'**
  String insUntouchedLost(String amount);

  /// No description provided for @insTransferFootnote.
  ///
  /// In en, this message translates to:
  /// **'Moved {amount} between your accounts'**
  String insTransferFootnote(String amount);

  /// No description provided for @insTransferCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transfers'**
  String insTransferCount(int count);

  /// No description provided for @insFee.
  ///
  /// In en, this message translates to:
  /// **'{amount} fee'**
  String insFee(String amount);

  /// No description provided for @insContradictionUp.
  ///
  /// In en, this message translates to:
  /// **'Your net worth rose, but you spent {amount} more than you earned.'**
  String insContradictionUp(String amount);

  /// No description provided for @insContradictionDown.
  ///
  /// In en, this message translates to:
  /// **'Your net worth fell, though you earned {amount} more than you spent.'**
  String insContradictionDown(String amount);

  /// No description provided for @insContradictionRevalued.
  ///
  /// In en, this message translates to:
  /// **'The whole change this period is investment revaluation.'**
  String get insContradictionRevalued;

  /// No description provided for @insNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records in this period'**
  String get insNoRecords;

  /// No description provided for @insBackToPeriod.
  ///
  /// In en, this message translates to:
  /// **'Back to {period}'**
  String insBackToPeriod(String period);

  /// No description provided for @insMovements.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get insMovements;

  /// No description provided for @insAverage.
  ///
  /// In en, this message translates to:
  /// **'Avg.'**
  String get insAverage;

  /// No description provided for @insAverageValue.
  ///
  /// In en, this message translates to:
  /// **'Average {amount}'**
  String insAverageValue(String amount);

  /// No description provided for @insHighest.
  ///
  /// In en, this message translates to:
  /// **'highest {label} {amount}'**
  String insHighest(String label, String amount);

  /// No description provided for @insEmptyMonthsExcluded.
  ///
  /// In en, this message translates to:
  /// **'empty periods excluded'**
  String get insEmptyMonthsExcluded;

  /// No description provided for @insVsLastPeriod.
  ///
  /// In en, this message translates to:
  /// **'{amount} vs last period ({percent})'**
  String insVsLastPeriod(String amount, String percent);

  /// No description provided for @insTooFewPeriods.
  ///
  /// In en, this message translates to:
  /// **'Only {count} periods with records — no average or trend shown'**
  String insTooFewPeriods(int count);

  /// No description provided for @insNoPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'no records last period'**
  String get insNoPreviousPeriod;

  /// No description provided for @insMonthlyBudget.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget {amount} · {percent}'**
  String insMonthlyBudget(String amount, String percent);

  /// No description provided for @insLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String insLeft(String amount);

  /// No description provided for @insOverBudget.
  ///
  /// In en, this message translates to:
  /// **'{amount} over'**
  String insOverBudget(String amount);

  /// No description provided for @insNoBudget.
  ///
  /// In en, this message translates to:
  /// **'no budget'**
  String get insNoBudget;

  /// No description provided for @insBudgetSub.
  ///
  /// In en, this message translates to:
  /// **'budget {amount} · {percent}'**
  String insBudgetSub(String amount, String percent);

  /// No description provided for @insBudgetSubOver.
  ///
  /// In en, this message translates to:
  /// **'budget {amount} · {percent} over'**
  String insBudgetSubOver(String amount, String percent);

  /// No description provided for @insAddBudget.
  ///
  /// In en, this message translates to:
  /// **'Add budget'**
  String get insAddBudget;

  /// No description provided for @insUnbudgetedTotal.
  ///
  /// In en, this message translates to:
  /// **'{amount} in unbudgeted categories'**
  String insUnbudgetedTotal(String amount);

  /// No description provided for @insCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range · {days, plural, =1{1 day} other{{days} days}}'**
  String insCustomRange(int days);

  /// No description provided for @insClearRange.
  ///
  /// In en, this message translates to:
  /// **'clear'**
  String get insClearRange;

  /// No description provided for @insSelectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select date range…'**
  String get insSelectDateRange;

  /// No description provided for @insOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get insOther;

  /// No description provided for @arcReached.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get arcReached;

  /// No description provided for @arcSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get arcSuccess;

  /// No description provided for @arcAvgTime.
  ///
  /// In en, this message translates to:
  /// **'Avg. time'**
  String get arcAvgTime;

  /// No description provided for @arcMonthsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} mo'**
  String arcMonthsShort(int count);

  /// No description provided for @arcGoalsTakeAbout.
  ///
  /// In en, this message translates to:
  /// **'Your goals take about {count, plural, =1{1 month} other{{count} months}} on average'**
  String arcGoalsTakeAbout(int count);

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

  /// No description provided for @obTitle.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get obTitle;

  /// No description provided for @obNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get obNotSet;

  /// No description provided for @obShiftsNote.
  ///
  /// In en, this message translates to:
  /// **'This shifts every running balance on this account.'**
  String get obShiftsNote;

  /// No description provided for @obDateTooLate.
  ///
  /// In en, this message translates to:
  /// **'The opening date can’t be after the first transaction.'**
  String get obDateTooLate;

  /// No description provided for @obDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the opening balance?'**
  String get obDeleteTitle;

  /// No description provided for @obDeleteMsg.
  ///
  /// In en, this message translates to:
  /// **'Every balance on this account will shift by {amount}.'**
  String obDeleteMsg(String amount);

  /// No description provided for @obDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove opening balance'**
  String get obDeleteConfirm;

  /// No description provided for @obCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy to account'**
  String get obCopyTitle;

  /// No description provided for @obA11y.
  ///
  /// In en, this message translates to:
  /// **'Opening balance, {account}, {amount}'**
  String obA11y(String account, String amount);

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

  /// No description provided for @balSortDefault.
  ///
  /// In en, this message translates to:
  /// **'Default order'**
  String get balSortDefault;

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

  /// No description provided for @eaArchiveThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Archive this account'**
  String get eaArchiveThisAccount;

  /// No description provided for @eaMoveOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Move the {amount} out first'**
  String eaMoveOutTitle(String amount);

  /// No description provided for @eaMoveOutMsg.
  ///
  /// In en, this message translates to:
  /// **'Archiving now would drop {amount} from your net worth with nothing in the Ledger to explain where it went. A closed account holds nothing.'**
  String eaMoveOutMsg(String amount);

  /// No description provided for @eaSettleTitle.
  ///
  /// In en, this message translates to:
  /// **'Settle the {amount} first'**
  String eaSettleTitle(String amount);

  /// No description provided for @eaSettleMsg.
  ///
  /// In en, this message translates to:
  /// **'Archiving now would drop {amount} from your net worth with nothing in the Ledger to explain where it went. A closed account holds nothing.'**
  String eaSettleMsg(String amount);

  /// No description provided for @eaMoveMoney.
  ///
  /// In en, this message translates to:
  /// **'Move money'**
  String get eaMoveMoney;

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

  /// No description provided for @plPace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get plPace;

  /// No description provided for @plLeftOfAmount.
  ///
  /// In en, this message translates to:
  /// **'left of {amount}'**
  String plLeftOfAmount(Object amount);

  /// No description provided for @plOverAmount.
  ///
  /// In en, this message translates to:
  /// **'over {amount}'**
  String plOverAmount(Object amount);

  /// No description provided for @plPctSpent.
  ///
  /// In en, this message translates to:
  /// **'{pct} spent'**
  String plPctSpent(Object pct);

  /// No description provided for @plDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'day {day} of {length}'**
  String plDayOfMonth(int day, int length);

  /// No description provided for @plCategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} category} other{{count} categories}}'**
  String plCategoriesCount(int count);

  /// No description provided for @plSemRowOver.
  ///
  /// In en, this message translates to:
  /// **'{name}, over budget, {spent} of {limit}'**
  String plSemRowOver(Object name, Object spent, Object limit);

  /// No description provided for @plSemRowNear.
  ///
  /// In en, this message translates to:
  /// **'{name}, near the limit, {spent} of {limit}'**
  String plSemRowNear(Object name, Object spent, Object limit);

  /// No description provided for @plSemRowNormal.
  ///
  /// In en, this message translates to:
  /// **'{name}, {spent} of {limit}'**
  String plSemRowNormal(Object name, Object spent, Object limit);

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

  /// No description provided for @ctArchiveCategory.
  ///
  /// In en, this message translates to:
  /// **'Archive category'**
  String get ctArchiveCategory;

  /// No description provided for @ctArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive \"{name}\"?'**
  String ctArchiveTitle(String name);

  /// No description provided for @ctArchiveMsg.
  ///
  /// In en, this message translates to:
  /// **'It stops appearing when you add a transaction. Nothing already recorded changes.'**
  String get ctArchiveMsg;

  /// No description provided for @ctTxnStay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Your {count} transaction stays in the Ledger, with this name and icon.} other{Your {count} transactions stay in the Ledger, with this name and icon.}}'**
  String ctTxnStay(int count);

  /// No description provided for @ctPastMonths.
  ///
  /// In en, this message translates to:
  /// **'Past months keep their {name} figures.'**
  String ctPastMonths(String name);

  /// No description provided for @ctBudgetRemoved.
  ///
  /// In en, this message translates to:
  /// **'Its {amount} monthly budget is removed — a budget with nothing to track would sit empty forever. You can restore it from Archive.'**
  String ctBudgetRemoved(String amount);

  /// No description provided for @ctDisappearsPicker.
  ///
  /// In en, this message translates to:
  /// **'It disappears from every category picker.'**
  String get ctDisappearsPicker;

  /// No description provided for @ctBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t archive \"{name}\" yet'**
  String ctBlockedTitle(String name);

  /// No description provided for @ctBlockedMsg.
  ///
  /// In en, this message translates to:
  /// **'The scheduled item \"{task}\" still books into it. Change or remove that item first.'**
  String ctBlockedMsg(String task);

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

  /// No description provided for @arAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get arAccounts;

  /// No description provided for @arCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get arCategories;

  /// No description provided for @arAccountLine.
  ///
  /// In en, this message translates to:
  /// **'{group} · {count, plural, one{{count} transaction} other{{count} transactions}}'**
  String arAccountLine(String group, int count);

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

  /// No description provided for @stateOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get stateOn;

  /// No description provided for @stateOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get stateOff;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @ldgShowDescriptions.
  ///
  /// In en, this message translates to:
  /// **'Show descriptions'**
  String get ldgShowDescriptions;

  /// No description provided for @ldgSortTransactions.
  ///
  /// In en, this message translates to:
  /// **'Sort transactions'**
  String get ldgSortTransactions;

  /// No description provided for @ldgFilterTransactions.
  ///
  /// In en, this message translates to:
  /// **'Filter transactions'**
  String get ldgFilterTransactions;

  /// No description provided for @ldgSearchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get ldgSearchTransactions;

  /// No description provided for @ldgFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active, {shown} of {total} shown'**
  String ldgFilterActive(Object shown, Object total);

  /// No description provided for @ldgNoResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String ldgNoResultsFor(Object query);

  /// No description provided for @ldgNoMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No transactions match your filter'**
  String get ldgNoMatchFilter;

  /// No description provided for @ldgClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get ldgClearFilter;

  /// No description provided for @ldgNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get ldgNothingHere;

  /// No description provided for @ldgNothingHereMsg.
  ///
  /// In en, this message translates to:
  /// **'Entries you add will appear in this list.'**
  String get ldgNothingHereMsg;

  /// No description provided for @ldgAddEntry.
  ///
  /// In en, this message translates to:
  /// **'Add an entry'**
  String get ldgAddEntry;

  /// No description provided for @ldgCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get ldgCategories;

  /// No description provided for @ldgAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get ldgAccounts;

  /// No description provided for @ldgTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get ldgTags;

  /// No description provided for @ldgType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get ldgType;

  /// No description provided for @ldgDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get ldgDirection;

  /// No description provided for @ldgAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get ldgAmount;

  /// No description provided for @ldgClearCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Clear custom range'**
  String get ldgClearCustomRange;

  /// No description provided for @ldgSpentOf.
  ///
  /// In en, this message translates to:
  /// **'Spent {expense} of {income}'**
  String ldgSpentOf(Object expense, Object income);

  /// No description provided for @ldgOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get ldgOut;

  /// No description provided for @ldgLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get ldgLeft;

  /// No description provided for @ldgChangePeriod.
  ///
  /// In en, this message translates to:
  /// **'Change period'**
  String get ldgChangePeriod;

  /// No description provided for @ldgBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get ldgBalance;

  /// No description provided for @ldgTransactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get ldgTransactionDeleted;

  /// No description provided for @ldgNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get ldgNoTransactions;

  /// No description provided for @ldgPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get ldgPeriod;

  /// No description provided for @ldgShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get ldgShow;

  /// No description provided for @ldgCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get ldgCustomRange;

  /// No description provided for @ldgPreviousYear.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get ldgPreviousYear;

  /// No description provided for @ldgNextYear.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get ldgNextYear;

  /// No description provided for @ldgShowCountOf.
  ///
  /// In en, this message translates to:
  /// **'Show {count} of {total}'**
  String ldgShowCountOf(Object count, Object total);

  /// No description provided for @ldgShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all {count}'**
  String ldgShowAll(Object count);

  /// No description provided for @ldgPlusMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String ldgPlusMore(Object count);

  /// No description provided for @ldgNetIn.
  ///
  /// In en, this message translates to:
  /// **'Net in'**
  String get ldgNetIn;

  /// No description provided for @ldgNetOut.
  ///
  /// In en, this message translates to:
  /// **'Net out'**
  String get ldgNetOut;

  /// No description provided for @ldgMoneyIn.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get ldgMoneyIn;

  /// No description provided for @ldgMoneyOut.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get ldgMoneyOut;

  /// No description provided for @ldgNoCash.
  ///
  /// In en, this message translates to:
  /// **'No cash'**
  String get ldgNoCash;

  /// No description provided for @ldgIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get ldgIn;

  /// No description provided for @ldgRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Transactions here range {min} – {max}'**
  String ldgRangeHint(Object min, Object max);

  /// No description provided for @ldgSearchWithin.
  ///
  /// In en, this message translates to:
  /// **'Search {labels}'**
  String ldgSearchWithin(Object labels);

  /// No description provided for @ldgSelectAllIn.
  ///
  /// In en, this message translates to:
  /// **'Select all in {section}'**
  String ldgSelectAllIn(Object section);

  /// No description provided for @ldgClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear {section} selection'**
  String ldgClearSelection(Object section);

  /// No description provided for @ldgSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get ldgSelectAll;

  /// No description provided for @ldgClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get ldgClear;

  /// No description provided for @ldgMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get ldgMin;

  /// No description provided for @ldgMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get ldgMax;

  /// No description provided for @ldgResetFilter.
  ///
  /// In en, this message translates to:
  /// **'Reset filter'**
  String get ldgResetFilter;

  /// No description provided for @ldgSelectOthers.
  ///
  /// In en, this message translates to:
  /// **'Select others'**
  String get ldgSelectOthers;

  /// No description provided for @ldgNSelected.
  ///
  /// In en, this message translates to:
  /// **'{n} selected'**
  String ldgNSelected(Object n);

  /// No description provided for @ldgAllSelected.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get ldgAllSelected;

  /// No description provided for @ldgClearSection.
  ///
  /// In en, this message translates to:
  /// **'Clear {section} selection'**
  String ldgClearSection(Object section);

  /// No description provided for @ldgMoreCategories.
  ///
  /// In en, this message translates to:
  /// **'{n} more categories'**
  String ldgMoreCategories(Object n);

  /// No description provided for @ldgMoreAccounts.
  ///
  /// In en, this message translates to:
  /// **'{n} more accounts'**
  String ldgMoreAccounts(Object n);

  /// No description provided for @ldgMoreTags.
  ///
  /// In en, this message translates to:
  /// **'{n} more tags'**
  String ldgMoreTags(Object n);

  /// No description provided for @ldgNHiddenSelected.
  ///
  /// In en, this message translates to:
  /// **'{n} selected'**
  String ldgNHiddenSelected(Object n);

  /// No description provided for @ldgNMatches.
  ///
  /// In en, this message translates to:
  /// **'{n} matches'**
  String ldgNMatches(Object n);

  /// No description provided for @ldgNResults.
  ///
  /// In en, this message translates to:
  /// **'{n} results'**
  String ldgNResults(Object n);

  /// No description provided for @ldgExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get ldgExpenses;

  /// No description provided for @ldgIncomes.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get ldgIncomes;

  /// No description provided for @ldgExpenseCategoriesA11y.
  ///
  /// In en, this message translates to:
  /// **'expense categories'**
  String get ldgExpenseCategoriesA11y;

  /// No description provided for @ldgIncomeSourcesA11y.
  ///
  /// In en, this message translates to:
  /// **'income sources'**
  String get ldgIncomeSourcesA11y;

  /// No description provided for @ldgTransfersHaveNoCategory.
  ///
  /// In en, this message translates to:
  /// **'Transfers have no category.'**
  String get ldgTransfersHaveNoCategory;

  /// No description provided for @ldgRevaluationsMoveNoCash.
  ///
  /// In en, this message translates to:
  /// **'Revaluations move no cash.'**
  String get ldgRevaluationsMoveNoCash;

  /// No description provided for @ldgAmountRange.
  ///
  /// In en, this message translates to:
  /// **'{min} – {max}'**
  String ldgAmountRange(Object min, Object max);

  /// No description provided for @tdFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get tdFrom;

  /// No description provided for @tdTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get tdTo;

  /// No description provided for @tdDeletedAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleted account'**
  String get tdDeletedAccount;

  /// No description provided for @tdRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get tdRate;

  /// No description provided for @tdNote.
  ///
  /// In en, this message translates to:
  /// **'NOTE'**
  String get tdNote;

  /// No description provided for @tdNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get tdNetWorth;

  /// No description provided for @tdUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get tdUnchanged;

  /// No description provided for @stDetailNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get stDetailNote;

  /// No description provided for @stDetailWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get stDetailWhen;

  /// No description provided for @stDetailPaidWith.
  ///
  /// In en, this message translates to:
  /// **'Paid with'**
  String get stDetailPaidWith;

  /// No description provided for @stDetailTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get stDetailTags;

  /// No description provided for @qaAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get qaAmount;

  /// No description provided for @qaDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get qaDue;

  /// No description provided for @qaNewBalance.
  ///
  /// In en, this message translates to:
  /// **'New balance'**
  String get qaNewBalance;

  /// No description provided for @qaTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get qaTarget;

  /// No description provided for @qaDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get qaDate;

  /// No description provided for @qaTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get qaTag;

  /// No description provided for @qaNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get qaNone;

  /// No description provided for @qaNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get qaNote;

  /// No description provided for @qaAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get qaAddNote;

  /// No description provided for @qaOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get qaOptional;

  /// No description provided for @qaSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get qaSplit;

  /// No description provided for @qaSplitCategories.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String qaSplitCategories(Object count);

  /// No description provided for @qaGroupRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get qaGroupRequired;

  /// No description provided for @qaGroupOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get qaGroupOptional;

  /// No description provided for @qaFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get qaFrom;

  /// No description provided for @qaTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get qaTo;

  /// No description provided for @qaChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get qaChooseAccount;

  /// No description provided for @qaChooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get qaChooseCategory;

  /// No description provided for @qaChooseSource.
  ///
  /// In en, this message translates to:
  /// **'Choose source'**
  String get qaChooseSource;

  /// No description provided for @qaPayFrom.
  ///
  /// In en, this message translates to:
  /// **'Pay from'**
  String get qaPayFrom;

  /// No description provided for @qaDepositInto.
  ///
  /// In en, this message translates to:
  /// **'Deposit into'**
  String get qaDepositInto;

  /// No description provided for @qaTransferFrom.
  ///
  /// In en, this message translates to:
  /// **'Transfer from'**
  String get qaTransferFrom;

  /// No description provided for @qaTransferTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer to'**
  String get qaTransferTo;

  /// No description provided for @qaRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get qaRate;

  /// No description provided for @qaReceives.
  ///
  /// In en, this message translates to:
  /// **'Receives'**
  String get qaReceives;

  /// No description provided for @qaFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get qaFee;

  /// No description provided for @qaAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get qaAccount;

  /// No description provided for @qaRevalueAccount.
  ///
  /// In en, this message translates to:
  /// **'Revalue account'**
  String get qaRevalueAccount;

  /// No description provided for @qaCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get qaCurrent;

  /// No description provided for @qaDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get qaDifference;

  /// No description provided for @qaReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get qaReason;

  /// No description provided for @qaAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get qaAdjustment;

  /// No description provided for @qaBalanceUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Balance unchanged'**
  String get qaBalanceUnchanged;

  /// No description provided for @qaName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get qaName;

  /// No description provided for @qaNameYourGoal.
  ///
  /// In en, this message translates to:
  /// **'Name your goal'**
  String get qaNameYourGoal;

  /// No description provided for @qaGoalNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. MacBook Pro M4'**
  String get qaGoalNameHint;

  /// No description provided for @qaSetDate.
  ///
  /// In en, this message translates to:
  /// **'Set a date'**
  String get qaSetDate;

  /// No description provided for @qaFundingAccount.
  ///
  /// In en, this message translates to:
  /// **'Funding account'**
  String get qaFundingAccount;

  /// No description provided for @qaStartingAmount.
  ///
  /// In en, this message translates to:
  /// **'Starting amount'**
  String get qaStartingAmount;

  /// No description provided for @qaIconColour.
  ///
  /// In en, this message translates to:
  /// **'Icon & colour'**
  String get qaIconColour;

  /// No description provided for @qaTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get qaTapToChange;

  /// No description provided for @qaAutoFund.
  ///
  /// In en, this message translates to:
  /// **'Auto-fund'**
  String get qaAutoFund;

  /// No description provided for @qaRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get qaRemind;

  /// No description provided for @qaTaskPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'What needs doing?'**
  String get qaTaskPlaceholder;

  /// No description provided for @qaExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get qaExchangeRate;

  /// No description provided for @qaFxRate.
  ///
  /// In en, this message translates to:
  /// **'1 {from} = ? {to}'**
  String qaFxRate(Object from, Object to);

  /// No description provided for @qaWhatAdding.
  ///
  /// In en, this message translates to:
  /// **'What are you adding?'**
  String get qaWhatAdding;

  /// No description provided for @qaDeleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry'**
  String get qaDeleteEntry;

  /// No description provided for @qaBalanceAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Balance adjustment'**
  String get qaBalanceAdjustment;

  /// No description provided for @qaRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get qaRecurring;

  /// No description provided for @qaLinkedSplit.
  ///
  /// In en, this message translates to:
  /// **'This is one of {count} linked split transactions.'**
  String qaLinkedSplit(Object count);

  /// No description provided for @qaDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all {count}'**
  String qaDeleteAll(Object count);

  /// No description provided for @qaDeleteJustLine.
  ///
  /// In en, this message translates to:
  /// **'Delete just this line'**
  String get qaDeleteJustLine;

  /// No description provided for @qaSaveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save expense'**
  String get qaSaveExpense;

  /// No description provided for @qaSaveIncome.
  ///
  /// In en, this message translates to:
  /// **'Save income'**
  String get qaSaveIncome;

  /// No description provided for @qaSaveTransfer.
  ///
  /// In en, this message translates to:
  /// **'Save transfer'**
  String get qaSaveTransfer;

  /// No description provided for @qaSaveAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Save adjustment'**
  String get qaSaveAdjustment;

  /// No description provided for @qaCreateGoal.
  ///
  /// In en, this message translates to:
  /// **'Create goal'**
  String get qaCreateGoal;

  /// No description provided for @qaCreateTask.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get qaCreateTask;

  /// No description provided for @qaSaved.
  ///
  /// In en, this message translates to:
  /// **'{type} saved'**
  String qaSaved(Object type);

  /// No description provided for @qaBlockAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get qaBlockAmount;

  /// No description provided for @qaBlockAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get qaBlockAccount;

  /// No description provided for @qaBlockCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get qaBlockCategory;

  /// No description provided for @qaBlockSource.
  ///
  /// In en, this message translates to:
  /// **'Choose a source'**
  String get qaBlockSource;

  /// No description provided for @qaBlockSplit.
  ///
  /// In en, this message translates to:
  /// **'Balance the split'**
  String get qaBlockSplit;

  /// No description provided for @qaBlockSourceAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose a source account'**
  String get qaBlockSourceAccount;

  /// No description provided for @qaBlockDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination'**
  String get qaBlockDestination;

  /// No description provided for @qaBlockBalanceUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Balance unchanged'**
  String get qaBlockBalanceUnchanged;

  /// No description provided for @qaBlockNameGoal.
  ///
  /// In en, this message translates to:
  /// **'Name your goal'**
  String get qaBlockNameGoal;

  /// No description provided for @qaBlockSetTarget.
  ///
  /// In en, this message translates to:
  /// **'Set a target'**
  String get qaBlockSetTarget;

  /// No description provided for @qaBlockSetTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Set a target date'**
  String get qaBlockSetTargetDate;

  /// No description provided for @qaBlockFunding.
  ///
  /// In en, this message translates to:
  /// **'Choose a funding account'**
  String get qaBlockFunding;

  /// No description provided for @qaBlockNameTask.
  ///
  /// In en, this message translates to:
  /// **'Name the task'**
  String get qaBlockNameTask;

  /// No description provided for @qaBlockDueDate.
  ///
  /// In en, this message translates to:
  /// **'Set a due date'**
  String get qaBlockDueDate;

  /// No description provided for @qaNewAccount.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get qaNewAccount;

  /// No description provided for @qaNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get qaNewCategory;

  /// No description provided for @qaNewShort.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get qaNewShort;

  /// No description provided for @qaSelectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get qaSelectAccount;

  /// No description provided for @qaSearchAccounts.
  ///
  /// In en, this message translates to:
  /// **'Search accounts'**
  String get qaSearchAccounts;

  /// No description provided for @qaSearchCategories.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get qaSearchCategories;

  /// No description provided for @qaNoAccountMatch.
  ///
  /// In en, this message translates to:
  /// **'No account matches \"{query}\".'**
  String qaNoAccountMatch(Object query);

  /// No description provided for @qaNoCategoryMatch.
  ///
  /// In en, this message translates to:
  /// **'No category matches \"{query}\".'**
  String qaNoCategoryMatch(Object query);

  /// No description provided for @qaExpenseCategory.
  ///
  /// In en, this message translates to:
  /// **'Expense category'**
  String get qaExpenseCategory;

  /// No description provided for @qaIncomeCategory.
  ///
  /// In en, this message translates to:
  /// **'Income category'**
  String get qaIncomeCategory;

  /// No description provided for @qaSearchCleared.
  ///
  /// In en, this message translates to:
  /// **'Search cleared'**
  String get qaSearchCleared;

  /// No description provided for @qaClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get qaClearSearch;

  /// No description provided for @qaCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get qaCategoryName;

  /// No description provided for @qaIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get qaIcon;

  /// No description provided for @qaColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get qaColour;

  /// No description provided for @qaMonthlyBudget.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget (optional)'**
  String get qaMonthlyBudget;

  /// No description provided for @qaCategoryPlannerNote.
  ///
  /// In en, this message translates to:
  /// **'This category will also appear in Planner → Expense Budget, where you can track spending against it.'**
  String get qaCategoryPlannerNote;

  /// No description provided for @qaCreateSelect.
  ///
  /// In en, this message translates to:
  /// **'Create & select'**
  String get qaCreateSelect;

  /// No description provided for @qaAccountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get qaAccountName;

  /// No description provided for @qaAccountExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this name already exists'**
  String get qaAccountExists;

  /// No description provided for @qaAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get qaAssets;

  /// No description provided for @qaLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get qaLiabilities;

  /// No description provided for @qaAmountOwed.
  ///
  /// In en, this message translates to:
  /// **'Amount owed'**
  String get qaAmountOwed;

  /// No description provided for @qaPaymentDay.
  ///
  /// In en, this message translates to:
  /// **'Payment day'**
  String get qaPaymentDay;

  /// No description provided for @qaOwedHint.
  ///
  /// In en, this message translates to:
  /// **'Enter what you owe as a positive number — it counts against your net worth.'**
  String get qaOwedHint;

  /// No description provided for @qaStartingBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter this once. From now on the balance is calculated from your transactions.'**
  String get qaStartingBalanceHint;

  /// No description provided for @qaPaymentDayHint.
  ///
  /// In en, this message translates to:
  /// **'Months shorter than this use their last day.'**
  String get qaPaymentDayHint;

  /// No description provided for @qaDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard new account?'**
  String get qaDiscardTitle;

  /// No description provided for @qaDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The details you entered won\'t be saved.'**
  String get qaDiscardBody;

  /// No description provided for @qaDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get qaDiscardConfirm;

  /// No description provided for @qaMoreIcons.
  ///
  /// In en, this message translates to:
  /// **'More icons'**
  String get qaMoreIcons;

  /// No description provided for @qaChooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose icon'**
  String get qaChooseIcon;

  /// No description provided for @qaSearchIcons.
  ///
  /// In en, this message translates to:
  /// **'Search icons'**
  String get qaSearchIcons;

  /// No description provided for @qaResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get qaResults;

  /// No description provided for @qaNoIconsMatch.
  ///
  /// In en, this message translates to:
  /// **'No icons match'**
  String get qaNoIconsMatch;

  /// No description provided for @ssRemoveSplit.
  ///
  /// In en, this message translates to:
  /// **'Remove split'**
  String get ssRemoveSplit;

  /// No description provided for @ssSplitByCategory.
  ///
  /// In en, this message translates to:
  /// **'Split by category'**
  String get ssSplitByCategory;

  /// No description provided for @ssTotalCovers.
  ///
  /// In en, this message translates to:
  /// **'Total {total} · {covered}'**
  String ssTotalCovers(Object total, Object covered);

  /// No description provided for @ssRemoveLine.
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get ssRemoveLine;

  /// No description provided for @ssAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get ssAddCategory;

  /// No description provided for @ssRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get ssRemaining;

  /// No description provided for @ssOverBy.
  ///
  /// In en, this message translates to:
  /// **'Over by'**
  String get ssOverBy;

  /// No description provided for @ssSplitEvenly.
  ///
  /// In en, this message translates to:
  /// **'Split evenly'**
  String get ssSplitEvenly;

  /// No description provided for @ssRestToLast.
  ///
  /// In en, this message translates to:
  /// **'Rest to last'**
  String get ssRestToLast;

  /// No description provided for @ssApplySplit.
  ///
  /// In en, this message translates to:
  /// **'Apply split'**
  String get ssApplySplit;

  /// No description provided for @ssApplySplitBlocked.
  ///
  /// In en, this message translates to:
  /// **'Apply split, unavailable until the remaining is zero'**
  String get ssApplySplitBlocked;

  /// No description provided for @rsRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get rsRepeat;

  /// No description provided for @rsHowOften.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get rsHowOften;

  /// No description provided for @rsEveryWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get rsEveryWeek;

  /// No description provided for @rsEvery2Weeks.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get rsEvery2Weeks;

  /// No description provided for @rsEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get rsEveryMonth;

  /// No description provided for @rsEveryQuarter.
  ///
  /// In en, this message translates to:
  /// **'Every quarter'**
  String get rsEveryQuarter;

  /// No description provided for @rsEveryYear.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get rsEveryYear;

  /// No description provided for @rsShortWeekly.
  ///
  /// In en, this message translates to:
  /// **'weekly'**
  String get rsShortWeekly;

  /// No description provided for @rsShortBiweekly.
  ///
  /// In en, this message translates to:
  /// **'every 2 weeks'**
  String get rsShortBiweekly;

  /// No description provided for @rsShortMonthly.
  ///
  /// In en, this message translates to:
  /// **'monthly'**
  String get rsShortMonthly;

  /// No description provided for @rsShortQuarterly.
  ///
  /// In en, this message translates to:
  /// **'quarterly'**
  String get rsShortQuarterly;

  /// No description provided for @rsShortYearly.
  ///
  /// In en, this message translates to:
  /// **'yearly'**
  String get rsShortYearly;

  /// No description provided for @rsSummary.
  ///
  /// In en, this message translates to:
  /// **'Repeats {cadence}, starting {date}. Managed in Planner.'**
  String rsSummary(Object cadence, Object date);

  /// No description provided for @rsWeekly.
  ///
  /// In en, this message translates to:
  /// **'every week on {weekday}'**
  String rsWeekly(Object weekday);

  /// No description provided for @rsMonthly.
  ///
  /// In en, this message translates to:
  /// **'on the {day} of every month'**
  String rsMonthly(Object day);

  /// No description provided for @rsQuarterly.
  ///
  /// In en, this message translates to:
  /// **'on the {day}, every 3 months'**
  String rsQuarterly(Object day);

  /// No description provided for @rsYearly.
  ///
  /// In en, this message translates to:
  /// **'every year on {day} {month}'**
  String rsYearly(Object day, Object month);

  /// No description provided for @rsNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get rsNext;

  /// No description provided for @rsShorterMonths.
  ///
  /// In en, this message translates to:
  /// **'Shorter months use their last day'**
  String get rsShorterMonths;

  /// No description provided for @rsEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get rsEveryDay;

  /// No description provided for @rsWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get rsWeekdays;

  /// No description provided for @rsNDaysWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} days a week'**
  String rsNDaysWeek(int count);

  /// No description provided for @rsNDaysMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} days a month'**
  String rsNDaysMonth(int count);

  /// No description provided for @rsMonthlyOnDay.
  ///
  /// In en, this message translates to:
  /// **'Every month on the {day}'**
  String rsMonthlyOnDay(Object day);

  /// No description provided for @rsDaysJoin.
  ///
  /// In en, this message translates to:
  /// **'{head} & {last}'**
  String rsDaysJoin(Object head, Object last);

  /// No description provided for @qaExchange.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get qaExchange;

  /// No description provided for @qaEnterNewBalance.
  ///
  /// In en, this message translates to:
  /// **'Enter the new balance'**
  String get qaEnterNewBalance;

  /// No description provided for @qaDeleteSplit.
  ///
  /// In en, this message translates to:
  /// **'Delete split'**
  String get qaDeleteSplit;

  /// No description provided for @qaBooksPrefix.
  ///
  /// In en, this message translates to:
  /// **'Books a '**
  String get qaBooksPrefix;

  /// No description provided for @qaBooksSuffix.
  ///
  /// In en, this message translates to:
  /// **' adjustment dated today. Past reports are not rewritten.'**
  String get qaBooksSuffix;

  /// No description provided for @qaPutAsidePrefix.
  ///
  /// In en, this message translates to:
  /// **'Put aside '**
  String get qaPutAsidePrefix;

  /// No description provided for @qaPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} / month'**
  String qaPerMonth(Object amount);

  /// No description provided for @qaToReachMonths.
  ///
  /// In en, this message translates to:
  /// **' for {months} months to reach it on time.'**
  String qaToReachMonths(Object months);

  /// No description provided for @qaCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String qaCreated(Object date);

  /// No description provided for @qaEditedTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} one{ · edited once} other{ · edited {count} times}}'**
  String qaEditedTimes(int count);

  /// No description provided for @a11yShown.
  ///
  /// In en, this message translates to:
  /// **'shown'**
  String get a11yShown;

  /// No description provided for @a11yPartiallyShown.
  ///
  /// In en, this message translates to:
  /// **'partially shown'**
  String get a11yPartiallyShown;

  /// No description provided for @a11yHidden.
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get a11yHidden;

  /// No description provided for @a11yDoubleTapShow.
  ///
  /// In en, this message translates to:
  /// **'Double tap to show all accounts'**
  String get a11yDoubleTapShow;

  /// No description provided for @a11yDoubleTapHide.
  ///
  /// In en, this message translates to:
  /// **'Double tap to hide all accounts'**
  String get a11yDoubleTapHide;

  /// No description provided for @a11yInternalTransfer.
  ///
  /// In en, this message translates to:
  /// **'internal transfer'**
  String get a11yInternalTransfer;

  /// No description provided for @a11yOfAssets.
  ///
  /// In en, this message translates to:
  /// **'of assets'**
  String get a11yOfAssets;

  /// No description provided for @a11yOfLiabilities.
  ///
  /// In en, this message translates to:
  /// **'of liabilities'**
  String get a11yOfLiabilities;

  /// No description provided for @a11yBalanceWord.
  ///
  /// In en, this message translates to:
  /// **'balance'**
  String get a11yBalanceWord;

  /// No description provided for @a11yAccountBalance.
  ///
  /// In en, this message translates to:
  /// **'{account} balance {amount}'**
  String a11yAccountBalance(Object account, Object amount);

  /// No description provided for @qaUnavailableNoAmount.
  ///
  /// In en, this message translates to:
  /// **'unavailable until an amount is entered'**
  String get qaUnavailableNoAmount;

  /// No description provided for @bfNetWorthFiltered.
  ///
  /// In en, this message translates to:
  /// **'NET WORTH · FILTERED'**
  String get bfNetWorthFiltered;

  /// No description provided for @bfVisibleCategories.
  ///
  /// In en, this message translates to:
  /// **'{visible} of {total} categories'**
  String bfVisibleCategories(int visible, int total);

  /// No description provided for @bfVisibleAccounts.
  ///
  /// In en, this message translates to:
  /// **'{visible} of {total} accounts'**
  String bfVisibleAccounts(int visible, int total);

  /// No description provided for @bdAMonth.
  ///
  /// In en, this message translates to:
  /// **'a month'**
  String get bdAMonth;

  /// No description provided for @bdSpent.
  ///
  /// In en, this message translates to:
  /// **'spent'**
  String get bdSpent;

  /// No description provided for @bdSpentOver.
  ///
  /// In en, this message translates to:
  /// **'spent · {over} over'**
  String bdSpentOver(String over);

  /// No description provided for @bdDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'day {day} of {total}'**
  String bdDayOfMonth(int day, int total);

  /// No description provided for @bdAgainstLimit.
  ///
  /// In en, this message translates to:
  /// **'AGAINST THE LIMIT'**
  String get bdAgainstLimit;

  /// No description provided for @mpMonth.
  ///
  /// In en, this message translates to:
  /// **'MONTH'**
  String get mpMonth;

  /// No description provided for @srDateRange.
  ///
  /// In en, this message translates to:
  /// **'DATE RANGE'**
  String get srDateRange;

  /// No description provided for @srCustomRange.
  ///
  /// In en, this message translates to:
  /// **'CUSTOM RANGE'**
  String get srCustomRange;

  /// No description provided for @calFrom.
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get calFrom;

  /// No description provided for @calTo.
  ///
  /// In en, this message translates to:
  /// **'TO'**
  String get calTo;

  /// No description provided for @plOfTarget.
  ///
  /// In en, this message translates to:
  /// **'of {target} target'**
  String plOfTarget(String target);

  /// No description provided for @dsKeepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get dsKeepIt;

  /// No description provided for @qaExampleCategory.
  ///
  /// In en, this message translates to:
  /// **'e.g. Groceries'**
  String get qaExampleCategory;

  /// No description provided for @qaExampleAccount.
  ///
  /// In en, this message translates to:
  /// **'e.g. Main Checking'**
  String get qaExampleAccount;

  /// No description provided for @qaExampleGoal.
  ///
  /// In en, this message translates to:
  /// **'e.g. MacBook Pro M4'**
  String get qaExampleGoal;

  /// No description provided for @goalSecSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get goalSecSaving;

  /// No description provided for @goalSecPayingOff.
  ///
  /// In en, this message translates to:
  /// **'Paying off'**
  String get goalSecPayingOff;

  /// No description provided for @goalSecWaitingOn.
  ///
  /// In en, this message translates to:
  /// **'Waiting on'**
  String get goalSecWaitingOn;

  /// No description provided for @goalSecEarning.
  ///
  /// In en, this message translates to:
  /// **'Earning'**
  String get goalSecEarning;

  /// No description provided for @goalOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{current} of {target}'**
  String goalOfTotal(Object current, Object target);

  /// No description provided for @goalLeftTotal.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String goalLeftTotal(Object amount);

  /// No description provided for @goalOwedTotal.
  ///
  /// In en, this message translates to:
  /// **'{amount} owed'**
  String goalOwedTotal(Object amount);

  /// No description provided for @goalSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Source unavailable'**
  String get goalSourceUnavailable;

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get goalReached;

  /// No description provided for @goalReachedEarly.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Reached 1 day early} other{Reached {days} days early}}'**
  String goalReachedEarly(int days);

  /// No description provided for @goalNothingYet.
  ///
  /// In en, this message translates to:
  /// **'nothing yet'**
  String get goalNothingYet;

  /// No description provided for @goalAmountIn.
  ///
  /// In en, this message translates to:
  /// **'{amount} in'**
  String goalAmountIn(Object amount);

  /// No description provided for @goalAmountOf.
  ///
  /// In en, this message translates to:
  /// **'{amount} of {whole}'**
  String goalAmountOf(Object amount, Object whole);

  /// No description provided for @goalDueLine.
  ///
  /// In en, this message translates to:
  /// **'Due {date} · {tail}'**
  String goalDueLine(Object date, Object tail);

  /// No description provided for @goalFunded.
  ///
  /// In en, this message translates to:
  /// **'Funded'**
  String get goalFunded;

  /// No description provided for @goalRefill.
  ///
  /// In en, this message translates to:
  /// **'Refill {amount}'**
  String goalRefill(Object amount);

  /// No description provided for @goalBehind.
  ///
  /// In en, this message translates to:
  /// **'Behind · {phrase}'**
  String goalBehind(Object phrase);

  /// No description provided for @plGoalRateSave.
  ///
  /// In en, this message translates to:
  /// **'save {rate}/mo'**
  String plGoalRateSave(Object rate);

  /// No description provided for @plGoalRatePay.
  ///
  /// In en, this message translates to:
  /// **'pay {rate}/mo'**
  String plGoalRatePay(Object rate);

  /// No description provided for @plGoalRateCollect.
  ///
  /// In en, this message translates to:
  /// **'collect {rate}/mo'**
  String plGoalRateCollect(Object rate);

  /// No description provided for @plGoalRateEarn.
  ///
  /// In en, this message translates to:
  /// **'earn {rate}/mo'**
  String plGoalRateEarn(Object rate);

  /// No description provided for @goalAhead.
  ///
  /// In en, this message translates to:
  /// **'Ahead · {rate}/mo left'**
  String goalAhead(Object rate);

  /// No description provided for @goalOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track · {rate}/mo'**
  String goalOnTrack(Object rate);

  /// No description provided for @plGoalFilterButton.
  ///
  /// In en, this message translates to:
  /// **'Goal filter'**
  String get plGoalFilterButton;

  /// No description provided for @plGoalScopeAllSome.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} goal} other{{n} goals}} · {m, plural, one{{m} needs attention} other{{m} need attention}}'**
  String plGoalScopeAllSome(int n, int m);

  /// No description provided for @plGoalScopeAllNone.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} goal} other{{n} goals}} · all on track'**
  String plGoalScopeAllNone(int n);

  /// No description provided for @plGoalScopeOneAttention.
  ///
  /// In en, this message translates to:
  /// **'1 goal · needs attention'**
  String get plGoalScopeOneAttention;

  /// No description provided for @plGoalScopeOneOnTrack.
  ///
  /// In en, this message translates to:
  /// **'1 goal · on track'**
  String get plGoalScopeOneOnTrack;

  /// No description provided for @plGoalScopeNeeds.
  ///
  /// In en, this message translates to:
  /// **'Needs attention · {m} of {n}'**
  String plGoalScopeNeeds(int m, int n);

  /// No description provided for @plGoalScopeOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track · {k} of {n}'**
  String plGoalScopeOnTrack(int k, int n);

  /// No description provided for @plGoalStatus.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get plGoalStatus;

  /// No description provided for @plGoalFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get plGoalFilterAll;

  /// No description provided for @plGoalFilterNeeds.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get plGoalFilterNeeds;

  /// No description provided for @plGoalFilterOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get plGoalFilterOnTrack;

  /// No description provided for @plGoalArchiveNote.
  ///
  /// In en, this message translates to:
  /// **'Reached and abandoned goals aren\'t here — they\'re in the Archive.'**
  String get plGoalArchiveNote;

  /// No description provided for @plGoalNoneNeed.
  ///
  /// In en, this message translates to:
  /// **'No goals need attention'**
  String get plGoalNoneNeed;

  /// No description provided for @plGoalNoneOnTrack.
  ///
  /// In en, this message translates to:
  /// **'No goals are on track'**
  String get plGoalNoneOnTrack;

  /// No description provided for @plGoalShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get plGoalShowAll;

  /// No description provided for @plGoalRowA11y.
  ///
  /// In en, this message translates to:
  /// **'{option}, {count, plural, one{{count} goal} other{{count} goals}}'**
  String plGoalRowA11y(Object option, int count);

  /// No description provided for @goalPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} a month'**
  String goalPerMonth(Object amount);

  /// No description provided for @goalNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get goalNewTitle;

  /// No description provided for @goalWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get goalWatching;

  /// No description provided for @goalSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get goalSource;

  /// No description provided for @goalSourceLocked.
  ///
  /// In en, this message translates to:
  /// **'Changing the account means a new goal.'**
  String get goalSourceLocked;

  /// No description provided for @goalSetDateHint.
  ///
  /// In en, this message translates to:
  /// **'Set a date, or a monthly amount'**
  String get goalSetDateHint;

  /// No description provided for @goalMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get goalMonthly;

  /// No description provided for @goalEnterRate.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly amount'**
  String get goalEnterRate;

  /// No description provided for @goalNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get goalNoteLabel;

  /// No description provided for @goalNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get goalNoteHint;

  /// No description provided for @goalDoneOnceReached.
  ///
  /// In en, this message translates to:
  /// **'Done once reached'**
  String get goalDoneOnceReached;

  /// No description provided for @goalDoneOnceReachedDesc.
  ///
  /// In en, this message translates to:
  /// **'Off for funds you refill'**
  String get goalDoneOnceReachedDesc;

  /// No description provided for @goalDeleteRowDesc.
  ///
  /// In en, this message translates to:
  /// **'Removes the goal, keeps the money'**
  String get goalDeleteRowDesc;

  /// No description provided for @goalOfWord.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get goalOfWord;

  /// No description provided for @goalNewAccountNamed.
  ///
  /// In en, this message translates to:
  /// **'New · {name}'**
  String goalNewAccountNamed(Object name);

  /// No description provided for @goalUntitled.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get goalUntitled;

  /// No description provided for @goalChooseSource.
  ///
  /// In en, this message translates to:
  /// **'Choose what to watch'**
  String get goalChooseSource;

  /// No description provided for @goalTwoOnAccount.
  ///
  /// In en, this message translates to:
  /// **'Another goal already watches this account. That\'s allowed — both read the same balance.'**
  String get goalTwoOnAccount;

  /// No description provided for @goalMonthlyPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly amount'**
  String get goalMonthlyPromptTitle;

  /// No description provided for @goalNewAccountOption.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get goalNewAccountOption;

  /// No description provided for @goalNewAccountOptionDesc.
  ///
  /// In en, this message translates to:
  /// **'A set-aside account, named from the goal'**
  String get goalNewAccountOptionDesc;

  /// No description provided for @goalIncomeCategories.
  ///
  /// In en, this message translates to:
  /// **'Income categories'**
  String get goalIncomeCategories;

  /// No description provided for @goalDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String goalDeleteTitle(Object name);

  /// No description provided for @goalDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The goal and its history go. Nothing else moves.'**
  String get goalDeleteBody;

  /// No description provided for @goalDeleteAccountStays.
  ///
  /// In en, this message translates to:
  /// **'Account \"{name}\" stays · {balance}'**
  String goalDeleteAccountStays(Object name, Object balance);

  /// No description provided for @goalDeleteTxnStay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Its 1 transaction stays} other{Its {count} transactions stay}}'**
  String goalDeleteTxnStay(int count);

  /// No description provided for @goalDeleteCategoryStays.
  ///
  /// In en, this message translates to:
  /// **'The income category and its transactions stay'**
  String get goalDeleteCategoryStays;

  /// No description provided for @goalOfToGo.
  ///
  /// In en, this message translates to:
  /// **'of {target} · {remaining} to go'**
  String goalOfToGo(Object target, Object remaining);

  /// No description provided for @goalDaysCaption.
  ///
  /// In en, this message translates to:
  /// **'{pct} · {elapsed} of {total} days'**
  String goalDaysCaption(Object pct, int elapsed, int total);

  /// No description provided for @goalColStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get goalColStarted;

  /// No description provided for @goalColTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalColTarget;

  /// No description provided for @goalColAtThisRate.
  ///
  /// In en, this message translates to:
  /// **'At this rate'**
  String get goalColAtThisRate;

  /// No description provided for @goalColReachedOn.
  ///
  /// In en, this message translates to:
  /// **'Reached on'**
  String get goalColReachedOn;

  /// No description provided for @goalColStoppedOn.
  ///
  /// In en, this message translates to:
  /// **'Stopped on'**
  String get goalColStoppedOn;

  /// No description provided for @goalColGotTo.
  ///
  /// In en, this message translates to:
  /// **'Got to'**
  String get goalColGotTo;

  /// No description provided for @goalColTook.
  ///
  /// In en, this message translates to:
  /// **'Took'**
  String get goalColTook;

  /// No description provided for @goalTookMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 month} other{{count} months}}'**
  String goalTookMonths(int count);

  /// No description provided for @goalTookUnderMonth.
  ///
  /// In en, this message translates to:
  /// **'< 1 month'**
  String get goalTookUnderMonth;

  /// No description provided for @goalOutcomeReachedOn.
  ///
  /// In en, this message translates to:
  /// **'Reached on {date}'**
  String goalOutcomeReachedOn(Object date);

  /// No description provided for @goalOutcomeStoppedOn.
  ///
  /// In en, this message translates to:
  /// **'Stopped on {date}'**
  String goalOutcomeStoppedOn(Object date);

  /// No description provided for @goalDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get goalDeletePermanently;

  /// No description provided for @goalReachedSummary.
  ///
  /// In en, this message translates to:
  /// **'Reached — nothing more to do'**
  String get goalReachedSummary;

  /// No description provided for @goalNotMovingYet.
  ///
  /// In en, this message translates to:
  /// **'Not moving yet'**
  String get goalNotMovingYet;

  /// No description provided for @goalAveragingOnly.
  ///
  /// In en, this message translates to:
  /// **'Averaging {rate} a month'**
  String goalAveragingOnly(Object rate);

  /// No description provided for @goalAveraging.
  ///
  /// In en, this message translates to:
  /// **'Now {actual}/mo · needs {needs}/mo to land on time'**
  String goalAveraging(Object actual, Object needs);

  /// Screen-reader label for an inbound movement amount; direction stated in words because colour is its only visual cue (§6).
  ///
  /// In en, this message translates to:
  /// **'Money in, {amount}'**
  String a11yMoneyIn(Object amount);

  /// Screen-reader label for an outbound movement amount; direction stated in words because colour is its only visual cue (§6).
  ///
  /// In en, this message translates to:
  /// **'Money out, {amount}'**
  String a11yMoneyOut(Object amount);

  /// No description provided for @goalCategoryWindow.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String goalCategoryWindow(Object from, Object to);

  /// No description provided for @goalMovements.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get goalMovements;

  /// No description provided for @goalSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all {count}'**
  String goalSeeAll(int count);

  /// No description provided for @goalNoteSection.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get goalNoteSection;

  /// No description provided for @goalChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get goalChanges;

  /// No description provided for @goalChangeCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get goalChangeCreated;

  /// No description provided for @goalChangeTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalChangeTarget;

  /// No description provided for @goalChangeDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get goalChangeDate;

  /// No description provided for @bhCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get bhCreated;

  /// No description provided for @bhLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get bhLimit;

  /// No description provided for @bhRollover.
  ///
  /// In en, this message translates to:
  /// **'Rollover'**
  String get bhRollover;

  /// No description provided for @bhWarn.
  ///
  /// In en, this message translates to:
  /// **'Alert at'**
  String get bhWarn;

  /// No description provided for @bhRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get bhRemoved;

  /// No description provided for @bhRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get bhRestored;

  /// No description provided for @bhCategoryArchived.
  ///
  /// In en, this message translates to:
  /// **'Category archived'**
  String get bhCategoryArchived;

  /// No description provided for @bhOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get bhOn;

  /// No description provided for @bhOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get bhOff;

  /// No description provided for @bhCreatedRolloverOn.
  ///
  /// In en, this message translates to:
  /// **'{amount} · rollover on'**
  String bhCreatedRolloverOn(String amount);

  /// No description provided for @bhCreatedRolloverOff.
  ///
  /// In en, this message translates to:
  /// **'{amount} · rollover off'**
  String bhCreatedRolloverOff(String amount);

  /// No description provided for @bhEmpty.
  ///
  /// In en, this message translates to:
  /// **'No changes recorded yet'**
  String get bhEmpty;

  /// No description provided for @bhSince.
  ///
  /// In en, this message translates to:
  /// **'Changes are recorded from {date}'**
  String bhSince(String date);

  /// No description provided for @bhA11yTo.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get bhA11yTo;

  /// No description provided for @bhA11yIncreased.
  ///
  /// In en, this message translates to:
  /// **'increased'**
  String get bhA11yIncreased;

  /// No description provided for @goalMenuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get goalMenuEdit;

  /// No description provided for @goalStopTracking.
  ///
  /// In en, this message translates to:
  /// **'Stop tracking'**
  String get goalStopTracking;

  /// No description provided for @goalStopTrackingDesc.
  ///
  /// In en, this message translates to:
  /// **'Keeps the record in Archive'**
  String get goalStopTrackingDesc;

  /// No description provided for @goalReachedAtZero.
  ///
  /// In en, this message translates to:
  /// **'Reached, and the account is empty.'**
  String get goalReachedAtZero;

  /// No description provided for @goalKeepAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep account'**
  String get goalKeepAccount;

  /// No description provided for @goalArchiveBoth.
  ///
  /// In en, this message translates to:
  /// **'Archive both'**
  String get goalArchiveBoth;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @moreTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get moreTags;

  /// No description provided for @tagsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{inUse} in use · {archived} archived'**
  String tagsSubtitle(int inUse, int archived);

  /// No description provided for @tagSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String tagSelectedCount(int count);

  /// No description provided for @tagSearchOrCreate.
  ///
  /// In en, this message translates to:
  /// **'Search or create'**
  String get tagSearchOrCreate;

  /// No description provided for @tagCreate.
  ///
  /// In en, this message translates to:
  /// **'Create #{name}'**
  String tagCreate(Object name);

  /// No description provided for @tagSectionInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get tagSectionInUse;

  /// No description provided for @tagSectionArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get tagSectionArchived;

  /// No description provided for @tagNeverUsed.
  ///
  /// In en, this message translates to:
  /// **'Not used yet'**
  String get tagNeverUsed;

  /// No description provided for @tagUsageLine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} transaction · last {date}} other{{count} transactions · last {date}}}'**
  String tagUsageLine(int count, Object date);

  /// No description provided for @tagArchiveFootnote.
  ///
  /// In en, this message translates to:
  /// **'Archived tags stay on their transactions and stay searchable. They just don\'t appear when you tag something new.'**
  String get tagArchiveFootnote;

  /// No description provided for @tagActionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get tagActionArchive;

  /// No description provided for @tagActionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get tagActionRename;

  /// No description provided for @tagNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get tagNewTitle;

  /// No description provided for @tagNameHint.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagNameHint;

  /// No description provided for @tagRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename #{name}'**
  String tagRenameTitle(Object name);

  /// No description provided for @tagRenameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} transaction carries this tag} other{{count} transactions carry this tag}}'**
  String tagRenameSubtitle(int count);

  /// No description provided for @tagMergeWarning.
  ///
  /// In en, this message translates to:
  /// **'A tag named #{target} already exists. The two will merge into one tag on {count} transactions. This cannot be undone.'**
  String tagMergeWarning(Object target, int count);

  /// No description provided for @tagMergeButton.
  ///
  /// In en, this message translates to:
  /// **'Merge into #{target}'**
  String tagMergeButton(Object target);

  /// No description provided for @tagArchivedBadge.
  ///
  /// In en, this message translates to:
  /// **'archived'**
  String get tagArchivedBadge;

  /// No description provided for @plTitle.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get plTitle;

  /// No description provided for @fieldSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get fieldSelectCategory;

  /// No description provided for @actionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get actionResume;

  /// No description provided for @schToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get schToday;

  /// No description provided for @schHorizonThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get schHorizonThisWeek;

  /// No description provided for @schHorizonNext30.
  ///
  /// In en, this message translates to:
  /// **'Next 30 days'**
  String get schHorizonNext30;

  /// No description provided for @schHorizonThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get schHorizonThisMonth;

  /// No description provided for @schHorizonNext3Months.
  ///
  /// In en, this message translates to:
  /// **'Next 3 months'**
  String get schHorizonNext3Months;

  /// No description provided for @schHorizonTitle.
  ///
  /// In en, this message translates to:
  /// **'HORIZON'**
  String get schHorizonTitle;

  /// No description provided for @schHorizonUntilDate.
  ///
  /// In en, this message translates to:
  /// **'Until a date…'**
  String get schHorizonUntilDate;

  /// No description provided for @schHorizonFootnote.
  ///
  /// In en, this message translates to:
  /// **'Overdue payments are not counted here — they stay in the list whichever horizon you pick.'**
  String get schHorizonFootnote;

  /// No description provided for @schUntilControl.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String schUntilControl(Object date);

  /// No description provided for @schCompletedIn.
  ///
  /// In en, this message translates to:
  /// **'{label} completed'**
  String schCompletedIn(Object label);

  /// No description provided for @schCompletedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing completed in this period.'**
  String get schCompletedEmpty;

  /// No description provided for @schCompletedLongerPeriod.
  ///
  /// In en, this message translates to:
  /// **'Choose a longer period'**
  String get schCompletedLongerPeriod;

  /// No description provided for @schUntilTitle.
  ///
  /// In en, this message translates to:
  /// **'UNTIL A DATE'**
  String get schUntilTitle;

  /// No description provided for @schUntilNote.
  ///
  /// In en, this message translates to:
  /// **'Starts today — pick the end.'**
  String get schUntilNote;

  /// No description provided for @schUntilPickPrompt.
  ///
  /// In en, this message translates to:
  /// **'Pick an end date'**
  String get schUntilPickPrompt;

  /// No description provided for @schUntilFromTo.
  ///
  /// In en, this message translates to:
  /// **'From today to {date}'**
  String schUntilFromTo(Object date);

  /// No description provided for @schDaysChip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String schDaysChip(int count);

  /// No description provided for @schDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String schDaysCount(int count);

  /// No description provided for @schPaymentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} payment} other{{count} payments}}'**
  String schPaymentsCount(int count);

  /// No description provided for @schApplyDays.
  ///
  /// In en, this message translates to:
  /// **'Apply · {count, plural, one{{count} day} other{{count} days}}'**
  String schApplyDays(int count);

  /// No description provided for @schLegendPayment.
  ///
  /// In en, this message translates to:
  /// **'has a payment'**
  String get schLegendPayment;

  /// No description provided for @schLegendNegative.
  ///
  /// In en, this message translates to:
  /// **'balance goes negative'**
  String get schLegendNegative;

  /// No description provided for @schShortLabel.
  ///
  /// In en, this message translates to:
  /// **'short'**
  String get schShortLabel;

  /// No description provided for @schLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get schLeftLabel;

  /// No description provided for @schLeftAfter.
  ///
  /// In en, this message translates to:
  /// **'left after commitments'**
  String get schLeftAfter;

  /// No description provided for @schShortAfter.
  ///
  /// In en, this message translates to:
  /// **'short after commitments'**
  String get schShortAfter;

  /// No description provided for @schCaptionIn.
  ///
  /// In en, this message translates to:
  /// **'{amount} coming in'**
  String schCaptionIn(Object amount);

  /// No description provided for @schCaptionOut.
  ///
  /// In en, this message translates to:
  /// **'{amount} going out'**
  String schCaptionOut(Object amount);

  /// No description provided for @schShortToday.
  ///
  /// In en, this message translates to:
  /// **'Short {amount} today'**
  String schShortToday(Object amount);

  /// No description provided for @schShortOnDay.
  ///
  /// In en, this message translates to:
  /// **'Short {amount} on {date}'**
  String schShortOnDay(Object amount, Object date);

  /// No description provided for @schBannerOut.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} payment overdue} other{{count} payments overdue}} · {amount}'**
  String schBannerOut(int count, Object amount);

  /// No description provided for @schBannerIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} expected payment hasn\'t arrived} other{{count} expected payments haven\'t arrived}} · {amount}'**
  String schBannerIn(int count, Object amount);

  /// No description provided for @schBannerBoth.
  ///
  /// In en, this message translates to:
  /// **'{count} items overdue · {out} out, {inAmt} in'**
  String schBannerBoth(int count, Object out, Object inAmt);

  /// No description provided for @schNothingInHorizon.
  ///
  /// In en, this message translates to:
  /// **'Nothing due in this window'**
  String get schNothingInHorizon;

  /// No description provided for @schShowNext3Months.
  ///
  /// In en, this message translates to:
  /// **'Show next 3 months ›'**
  String get schShowNext3Months;

  /// No description provided for @schDaysLate.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day late} other{{count} days late}}'**
  String schDaysLate(int count);

  /// No description provided for @schOverdueDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String schOverdueDays(int count);

  /// No description provided for @schWontCover.
  ///
  /// In en, this message translates to:
  /// **'won\'t cover'**
  String get schWontCover;

  /// No description provided for @schSemPayingOut.
  ///
  /// In en, this message translates to:
  /// **'paying out'**
  String get schSemPayingOut;

  /// No description provided for @schSemComingIn.
  ///
  /// In en, this message translates to:
  /// **'coming in'**
  String get schSemComingIn;

  /// No description provided for @schSemDue.
  ///
  /// In en, this message translates to:
  /// **'due'**
  String get schSemDue;

  /// No description provided for @schSemFrom.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get schSemFrom;

  /// No description provided for @schSemInto.
  ///
  /// In en, this message translates to:
  /// **'into'**
  String get schSemInto;

  /// No description provided for @schSemRepeats.
  ///
  /// In en, this message translates to:
  /// **'repeats {cadence}'**
  String schSemRepeats(Object cadence);

  /// No description provided for @schItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String schItemsCount(int count);

  /// No description provided for @schPausedArchiveLine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} paused task} other{{count} paused tasks}} · Archive ›'**
  String schPausedArchiveLine(int count);

  /// No description provided for @schCompletedFooter.
  ///
  /// In en, this message translates to:
  /// **'{out} out · {inAmt} in · {count} didn\'t happen'**
  String schCompletedFooter(Object out, Object inAmt, int count);

  /// No description provided for @schSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all ({count}) ›'**
  String schSeeAll(int count);

  /// No description provided for @schPaidLine.
  ///
  /// In en, this message translates to:
  /// **'{when} paid · {account}'**
  String schPaidLine(Object when, Object account);

  /// No description provided for @schReceivedLine.
  ///
  /// In en, this message translates to:
  /// **'{when} received · {account}'**
  String schReceivedLine(Object when, Object account);

  /// No description provided for @schSkippedLine.
  ///
  /// In en, this message translates to:
  /// **'{when} skipped'**
  String schSkippedLine(Object when);

  /// No description provided for @schCancelledLine.
  ///
  /// In en, this message translates to:
  /// **'{when} cancelled'**
  String schCancelledLine(Object when);

  /// No description provided for @histLastDays.
  ///
  /// In en, this message translates to:
  /// **'Last {count} days'**
  String histLastDays(int count);

  /// No description provided for @histThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get histThisMonth;

  /// No description provided for @histLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get histLastMonth;

  /// No description provided for @histSinceDate.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String histSinceDate(Object date);

  /// No description provided for @histSincePrompt.
  ///
  /// In en, this message translates to:
  /// **'Since a date…'**
  String get histSincePrompt;

  /// No description provided for @histFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String histFilterAll(int count);

  /// No description provided for @histFilterPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid {count}'**
  String histFilterPaid(int count);

  /// No description provided for @histFilterSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count}'**
  String histFilterSkipped(int count);

  /// No description provided for @histFilterCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled {count}'**
  String histFilterCancelled(int count);

  /// No description provided for @histOut.
  ///
  /// In en, this message translates to:
  /// **'OUT'**
  String get histOut;

  /// No description provided for @histIn.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get histIn;

  /// No description provided for @histDidntHappen.
  ///
  /// In en, this message translates to:
  /// **'DIDN\'T HAPPEN'**
  String get histDidntHappen;

  /// No description provided for @histNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here for this period'**
  String get histNothingHere;

  /// No description provided for @histPausedDeleted.
  ///
  /// In en, this message translates to:
  /// **'{paused} paused, {deleted} deleted in this period · Archive ›'**
  String histPausedDeleted(int paused, int deleted);

  /// No description provided for @mpTitlePaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get mpTitlePaid;

  /// No description provided for @mpTitleReceived.
  ///
  /// In en, this message translates to:
  /// **'Mark as received'**
  String get mpTitleReceived;

  /// No description provided for @mpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{title} · due {date}'**
  String mpSubtitle(Object title, Object date);

  /// No description provided for @mpExpected.
  ///
  /// In en, this message translates to:
  /// **'expected {amount}'**
  String mpExpected(Object amount);

  /// No description provided for @mpDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get mpDate;

  /// No description provided for @mpFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get mpFrom;

  /// No description provided for @mpInto.
  ///
  /// In en, this message translates to:
  /// **'Into'**
  String get mpInto;

  /// No description provided for @mpTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get mpTo;

  /// No description provided for @mpTransferNoCategory.
  ///
  /// In en, this message translates to:
  /// **'Transfer — no budget category'**
  String get mpTransferNoCategory;

  /// No description provided for @mpRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember {amount} for next time'**
  String mpRemember(Object amount);

  /// No description provided for @mpConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm · {amount}'**
  String mpConfirm(Object amount);

  /// No description provided for @mpChooseDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get mpChooseDestination;

  /// No description provided for @mpPayOffGroup.
  ///
  /// In en, this message translates to:
  /// **'PAY OFF'**
  String get mpPayOffGroup;

  /// No description provided for @mpRecorded.
  ///
  /// In en, this message translates to:
  /// **'{title} recorded in your Ledger'**
  String mpRecorded(Object title);

  /// No description provided for @mpRecordedNext.
  ///
  /// In en, this message translates to:
  /// **'{title} recorded in your Ledger · next {date}'**
  String mpRecordedNext(Object title, Object date);

  /// No description provided for @tmEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tmEdit;

  /// No description provided for @tmEditSub.
  ///
  /// In en, this message translates to:
  /// **'Amount, date, repeat, account, category, reminder and note.'**
  String get tmEditSub;

  /// No description provided for @tmSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this one'**
  String get tmSkip;

  /// No description provided for @tmSkipSub.
  ///
  /// In en, this message translates to:
  /// **'{date} is skipped. Nothing is written to the Ledger; the series continues on {next}.'**
  String tmSkipSub(Object date, Object next);

  /// No description provided for @tmPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get tmPause;

  /// No description provided for @tmPauseSub.
  ///
  /// In en, this message translates to:
  /// **'Leaves the list and the projection. Payment history and future dates are kept — resume it from the Archive whenever you like.'**
  String get tmPauseSub;

  /// No description provided for @tmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tmDelete;

  /// No description provided for @tmDeleteSub.
  ///
  /// In en, this message translates to:
  /// **'Moves to the Archive — you can undo an accidental delete. The {count} payments stay in your Ledger. Permanent deletion is from the Archive.'**
  String tmDeleteSub(int count);

  /// No description provided for @tdDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}?'**
  String tdDeleteTitle(Object title);

  /// No description provided for @tdDeleteMsg.
  ///
  /// In en, this message translates to:
  /// **'It moves to the Archive — you can undo an accidental delete.'**
  String get tdDeleteMsg;

  /// No description provided for @tdKeptPayments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} payment stays in your Ledger} other{{count} payments stay in your Ledger}}'**
  String tdKeptPayments(int count);

  /// No description provided for @tdKeptBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances are unaffected'**
  String get tdKeptBalances;

  /// No description provided for @tdKeptHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment history stays with the task in the Archive'**
  String get tdKeptHistory;

  /// No description provided for @tdLostSchedule.
  ///
  /// In en, this message translates to:
  /// **'It leaves the Schedule and the projection'**
  String get tdLostSchedule;

  /// No description provided for @tdLostReminders.
  ///
  /// In en, this message translates to:
  /// **'Future reminders stop'**
  String get tdLostReminders;

  /// No description provided for @tdDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tdDeleteConfirm;

  /// No description provided for @tdPausedOn.
  ///
  /// In en, this message translates to:
  /// **'Paused on {date}'**
  String tdPausedOn(Object date);

  /// No description provided for @tdNext.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get tdNext;

  /// No description provided for @tdAmount.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT'**
  String get tdAmount;

  /// No description provided for @tdPerYear.
  ///
  /// In en, this message translates to:
  /// **'PER YEAR'**
  String get tdPerYear;

  /// No description provided for @tdDue.
  ///
  /// In en, this message translates to:
  /// **'DUE'**
  String get tdDue;

  /// No description provided for @tdUpcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get tdUpcoming;

  /// No description provided for @tdPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT HISTORY'**
  String get tdPaymentHistory;

  /// No description provided for @tdNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded yet'**
  String get tdNoPayments;

  /// No description provided for @tdPaymentsSince.
  ///
  /// In en, this message translates to:
  /// **'{count} payments since {month} · {total} total'**
  String tdPaymentsSince(int count, Object month, Object total);

  /// No description provided for @tdResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get tdResume;

  /// No description provided for @tdMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get tdMarkPaid;

  /// No description provided for @tdMarkReceived.
  ///
  /// In en, this message translates to:
  /// **'Mark as received'**
  String get tdMarkReceived;

  /// No description provided for @tdSkipOne.
  ///
  /// In en, this message translates to:
  /// **'Skip this one'**
  String get tdSkipOne;

  /// No description provided for @etNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get etNote;

  /// No description provided for @etNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get etNoteHint;

  /// No description provided for @etPaidTo.
  ///
  /// In en, this message translates to:
  /// **'Paid to'**
  String get etPaidTo;

  /// No description provided for @arPausedTasks.
  ///
  /// In en, this message translates to:
  /// **'PAUSED TASKS'**
  String get arPausedTasks;

  /// No description provided for @arCompletedTasks.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED TASKS'**
  String get arCompletedTasks;

  /// No description provided for @arDeletedTasks.
  ///
  /// In en, this message translates to:
  /// **'DELETED TASKS'**
  String get arDeletedTasks;

  /// No description provided for @arPausedLine.
  ///
  /// In en, this message translates to:
  /// **'Paused {date} · {payments} payments · {total}'**
  String arPausedLine(Object date, int payments, Object total);

  /// No description provided for @arCompletedLine.
  ///
  /// In en, this message translates to:
  /// **'Paid {date} · {amount}'**
  String arCompletedLine(Object date, Object amount);

  /// No description provided for @arCancelledLine.
  ///
  /// In en, this message translates to:
  /// **'Cancelled {date}'**
  String arCancelledLine(Object date);

  /// No description provided for @arDeletedLineTask.
  ///
  /// In en, this message translates to:
  /// **'Deleted {date} · {payments} payments · {total}'**
  String arDeletedLineTask(Object date, int payments, Object total);
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
