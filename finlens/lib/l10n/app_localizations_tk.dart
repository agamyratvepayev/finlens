// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkmen (`tk`).
class AppLocalizationsTk extends AppLocalizations {
  AppLocalizationsTk([String locale = 'tk']) : super(locale);

  @override
  String get language => 'Dil';

  @override
  String get languageSystemDefault => 'Enjam sazlamasy';

  @override
  String get accountGroupSpendable => 'Sarp ediljek';

  @override
  String get accountGroupReceivables => 'Aljaklar';

  @override
  String get accountGroupInvestments => 'Maýa goýumlar';

  @override
  String get accountGroupValuables => 'Gymmatlyklar';

  @override
  String get accountGroupCreditCards => 'Karz kartlary';

  @override
  String get accountGroupPayables => 'Tölegler';

  @override
  String get accountGroupBankLoans => 'Bank karzlary';

  @override
  String get quickAddExpense => 'Çykdajy';

  @override
  String get quickAddIncome => 'Girdeji';

  @override
  String get quickAddTransfer => 'Geçirim';

  @override
  String get quickAddRebalance => 'Deňagramlaşdyrma';

  @override
  String get quickAddNewGoal => 'Täze maksat';

  @override
  String get quickAddNewTask => 'Täze tabşyryk';

  @override
  String get txnTypeExpense => 'Çykdajy';

  @override
  String get txnTypeIncome => 'Girdeji';

  @override
  String get txnTypeTransfer => 'Geçirim';

  @override
  String get txnTypeRebalance => 'Deňagramlaşdyrma';

  @override
  String get goalTypeSaving => 'Toplama';

  @override
  String get goalTypeMilestone => 'Sepgit';

  @override
  String get goalTypePurchasing => 'Satyn alyş';

  @override
  String get goalSectionSaving => 'Toplama';

  @override
  String get goalSectionMilestone => 'Sepgitler';

  @override
  String get goalSectionPurchasing => 'Satyn alyş';

  @override
  String get priorityLow => 'Pes';

  @override
  String get priorityNormal => 'Adaty';

  @override
  String get priorityHigh => 'Ýokary';

  @override
  String get repeatNever => 'Hiç haçan';

  @override
  String get repeatWeekly => 'Hepdelik';

  @override
  String get repeatMonthly => 'Aýlyk';

  @override
  String get repeatQuarterly => 'Çärýeklik';

  @override
  String get repeatYearly => 'Ýyllyk';

  @override
  String get comparePeriodTodayLabel => 'Şu gün';

  @override
  String get comparePeriodTodayCaption => 'düýne görä';

  @override
  String get comparePeriodWeekLabel => 'Hepde';

  @override
  String get comparePeriodWeekCaption => 'geçen hepdä görä';

  @override
  String get comparePeriodMonthLabel => 'Aý';

  @override
  String get comparePeriodMonthCaption => 'geçen aýa görä';

  @override
  String get rangeThisWeek => 'Şu hepde';

  @override
  String get rangeLastWeek => 'Geçen hepde';

  @override
  String get rangeThisMonth => 'Şu aý';

  @override
  String get rangeLastMonth => 'Geçen aý';

  @override
  String get rangeLast3Months => 'Soňky 3 aý';

  @override
  String get rangeLast6Months => 'Soňky 6 aý';

  @override
  String get rangeLast12Months => 'Soňky 12 aý';

  @override
  String get rangeThisYear => 'Şu ýyl';

  @override
  String get rangeAllTime => 'Ähli wagt';

  @override
  String get navBalance => 'Balans';

  @override
  String get navLedger => 'Hasap';

  @override
  String get navPlanner => 'Meýilnama';

  @override
  String get navInsight => 'Derňew';

  @override
  String get navMore => 'Ýene';

  @override
  String get accountSortValueDesc => 'Bahasy — ýokardan aşak';

  @override
  String get accountSortValueAsc => 'Bahasy — aşakdan ýokary';

  @override
  String get accountSortNameAsc => 'Ady — A-Z';

  @override
  String get accountSortActivity => 'Üýtgeme — işjeň';

  @override
  String get accountSortCustom => 'Elde';

  @override
  String get balanceSectionAll => 'Arassa baýlyk';

  @override
  String get balanceSectionAssets => 'Aktiwler';

  @override
  String get balanceSectionLiabilities => 'Borçlar';

  @override
  String get transSortDateNewest => 'Sene — täzeden';

  @override
  String get transSortDateOldest => 'Sene — köneden';

  @override
  String get transSortAmountHigh => 'Möçber — ýokardan aşak';

  @override
  String get transSortAmountLow => 'Möçber — aşakdan ýokary';

  @override
  String get transSortByCategory => 'Kategoriýa — A-Z';

  @override
  String get transSortByAccount => 'Hasap — A-Z';

  @override
  String get ledgerAllAccounts => 'Ähli hasaplar';

  @override
  String get ledgerAccountFallback => 'Hasap';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Ýan',
      '2': 'Few',
      '3': 'Mart',
      '4': 'Apr',
      '5': 'Maý',
      '6': 'Iýun',
      '7': 'Iýul',
      '8': 'Awg',
      '9': 'Sen',
      '10': 'Okt',
      '11': 'Noý',
      '12': 'Dek',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String monthLong(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Ýanwar',
      '2': 'Fewral',
      '3': 'Mart',
      '4': 'Aprel',
      '5': 'Maý',
      '6': 'Iýun',
      '7': 'Iýul',
      '8': 'Awgust',
      '9': 'Sentýabr',
      '10': 'Oktýabr',
      '11': 'Noýabr',
      '12': 'Dekabr',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayLong(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Duşenbe',
      '2': 'Sişenbe',
      '3': 'Çarşenbe',
      '4': 'Penşenbe',
      '5': 'Anna',
      '6': 'Şenbe',
      '7': 'Ýekşenbe',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get dateToday => 'Şu gün';

  @override
  String get dateYesterday => 'Düýn';

  @override
  String get dateTomorrow => 'Ertir';

  @override
  String dateWithTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String dateGroupYesterday(String date) {
    return 'Düýn · $date';
  }

  @override
  String rangeSince(String monthYear) {
    return '$monthYear-den bäri';
  }

  @override
  String get dueToday => 'şu gün';

  @override
  String get dueTomorrow => 'ertir';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days günden soň',
      one: '$days günden soň',
    );
    return '$_temp0';
  }

  @override
  String dueDaysLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün gijä galdy',
      one: '$days gün gijä galdy',
    );
    return '$_temp0';
  }

  @override
  String countAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hasap',
      one: '$count hasap',
    );
    return '$_temp0';
  }

  @override
  String countTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amal',
      one: '$count amal',
    );
    return '$_temp0';
  }

  @override
  String countResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count netije',
      one: '$count netije',
    );
    return '$_temp0';
  }

  @override
  String countDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
      one: '$count gün',
    );
    return '$_temp0';
  }

  @override
  String countArchivedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arhiw elementi',
      one: '$count arhiw elementi',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün öň',
      one: '$count gün öň',
    );
    return '$_temp0';
  }

  @override
  String get moreTitle => 'Ýene';

  @override
  String get moreYourMoney => 'Pullaryňyz';

  @override
  String get morePlannerSection => 'Meýilnama';

  @override
  String get morePreferences => 'Sazlamalar';

  @override
  String get moreCategories => 'Kategoriýalar';

  @override
  String moreCategoriesInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ulanylýar',
      one: '$count ulanylýar',
    );
    return '$_temp0';
  }

  @override
  String get moreArchive => 'Arhiw';

  @override
  String get morePrivacyMode => 'Gizlinlik tertibi';

  @override
  String get morePrivacyModeDesc => 'Programmadaky ähli mukdarlary gizle';

  @override
  String get moreAddAccount => 'Hasap goş';
}
