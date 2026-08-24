// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get language => 'Dil';

  @override
  String get languageSystemDefault => 'Cihaz varsayılanı';

  @override
  String get accountGroupSpendable => 'Harcanabilir';

  @override
  String get accountGroupReceivables => 'Alacaklar';

  @override
  String get accountGroupInvestments => 'Yatırımlar';

  @override
  String get accountGroupValuables => 'Değerli varlıklar';

  @override
  String get accountGroupCreditCards => 'Kredi kartları';

  @override
  String get accountGroupPayables => 'Borçlar';

  @override
  String get accountGroupBankLoans => 'Banka kredileri';

  @override
  String get quickAddExpense => 'Gider';

  @override
  String get quickAddIncome => 'Gelir';

  @override
  String get quickAddTransfer => 'Transfer';

  @override
  String get quickAddRebalance => 'Yeniden dengele';

  @override
  String get quickAddNewGoal => 'Yeni hedef';

  @override
  String get quickAddNewTask => 'Yeni görev';

  @override
  String get txnTypeExpense => 'Gider';

  @override
  String get txnTypeIncome => 'Gelir';

  @override
  String get txnTypeTransfer => 'Transfer';

  @override
  String get txnTypeRebalance => 'Yeniden dengeleme';

  @override
  String get goalTypeSaving => 'Birikim';

  @override
  String get goalTypeMilestone => 'Kilometre taşı';

  @override
  String get goalTypePurchasing => 'Satın alma';

  @override
  String get goalSectionSaving => 'Birikim';

  @override
  String get goalSectionMilestone => 'Kilometre taşları';

  @override
  String get goalSectionPurchasing => 'Satın alma';

  @override
  String get priorityLow => 'Düşük';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'Yüksek';

  @override
  String get repeatNever => 'Asla';

  @override
  String get repeatWeekly => 'Haftalık';

  @override
  String get repeatMonthly => 'Aylık';

  @override
  String get repeatQuarterly => 'Üç aylık';

  @override
  String get repeatYearly => 'Yıllık';

  @override
  String get comparePeriodTodayLabel => 'Bugün';

  @override
  String get comparePeriodTodayCaption => 'düne göre';

  @override
  String get comparePeriodWeekLabel => 'Hafta';

  @override
  String get comparePeriodWeekCaption => 'geçen haftaya göre';

  @override
  String get comparePeriodMonthLabel => 'Ay';

  @override
  String get comparePeriodMonthCaption => 'geçen aya göre';

  @override
  String get rangeThisWeek => 'Bu hafta';

  @override
  String get rangeLastWeek => 'Geçen hafta';

  @override
  String get rangeThisMonth => 'Bu ay';

  @override
  String get rangeLastMonth => 'Geçen ay';

  @override
  String get rangeLast3Months => 'Son 3 ay';

  @override
  String get rangeLast6Months => 'Son 6 ay';

  @override
  String get rangeLast12Months => 'Son 12 ay';

  @override
  String get rangeThisYear => 'Bu yıl';

  @override
  String get rangeAllTime => 'Tüm zamanlar';

  @override
  String get navBalance => 'Bakiye';

  @override
  String get navLedger => 'Defter';

  @override
  String get navPlanner => 'Planlayıcı';

  @override
  String get navInsight => 'Analiz';

  @override
  String get navMore => 'Daha';

  @override
  String get accountSortValueDesc => 'Değer — yüksekten düşüğe';

  @override
  String get accountSortValueAsc => 'Değer — düşükten yükseğe';

  @override
  String get accountSortNameAsc => 'Ad — A\'dan Z\'ye';

  @override
  String get accountSortActivity => 'Değişim — en aktif';

  @override
  String get accountSortCustom => 'Özel';

  @override
  String get balanceSectionAll => 'Net değer';

  @override
  String get balanceSectionAssets => 'Varlıklar';

  @override
  String get balanceSectionLiabilities => 'Yükümlülükler';

  @override
  String get transSortDateNewest => 'Tarih — en yeni';

  @override
  String get transSortDateOldest => 'Tarih — en eski';

  @override
  String get transSortAmountHigh => 'Tutar — yüksekten düşüğe';

  @override
  String get transSortAmountLow => 'Tutar — düşükten yükseğe';

  @override
  String get transSortByCategory => 'Kategori — A\'dan Z\'ye';

  @override
  String get transSortByAccount => 'Hesap — A\'dan Z\'ye';

  @override
  String get ledgerAllAccounts => 'Tüm hesaplar';

  @override
  String get ledgerAccountFallback => 'Hesap';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Oca',
      '2': 'Şub',
      '3': 'Mar',
      '4': 'Nis',
      '5': 'May',
      '6': 'Haz',
      '7': 'Tem',
      '8': 'Ağu',
      '9': 'Eyl',
      '10': 'Eki',
      '11': 'Kas',
      '12': 'Ara',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String monthLong(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Ocak',
      '2': 'Şubat',
      '3': 'Mart',
      '4': 'Nisan',
      '5': 'Mayıs',
      '6': 'Haziran',
      '7': 'Temmuz',
      '8': 'Ağustos',
      '9': 'Eylül',
      '10': 'Ekim',
      '11': 'Kasım',
      '12': 'Aralık',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayLong(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Pazartesi',
      '2': 'Salı',
      '3': 'Çarşamba',
      '4': 'Perşembe',
      '5': 'Cuma',
      '6': 'Cumartesi',
      '7': 'Pazar',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get dateToday => 'Bugün';

  @override
  String get dateYesterday => 'Dün';

  @override
  String get dateTomorrow => 'Yarın';

  @override
  String dateWithTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String dateGroupYesterday(String date) {
    return 'Dün · $date';
  }

  @override
  String rangeSince(String monthYear) {
    return '$monthYear\'den beri';
  }

  @override
  String get dueToday => 'bugün';

  @override
  String get dueTomorrow => 'yarın';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün içinde',
      one: '$days gün içinde',
    );
    return '$_temp0';
  }

  @override
  String dueDaysLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün gecikti',
      one: '$days gün gecikti',
    );
    return '$_temp0';
  }

  @override
  String countAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hesap',
      one: '$count hesap',
    );
    return '$_temp0';
  }

  @override
  String countTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count işlem',
      one: '$count işlem',
    );
    return '$_temp0';
  }

  @override
  String countResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sonuç',
      one: '$count sonuç',
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
      other: '$count arşivlenmiş öğe',
      one: '$count arşivlenmiş öğe',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün önce',
      one: '$count gün önce',
    );
    return '$_temp0';
  }

  @override
  String get moreTitle => 'Daha';

  @override
  String get moreYourMoney => 'Paranız';

  @override
  String get morePlannerSection => 'Planlayıcı';

  @override
  String get morePreferences => 'Tercihler';

  @override
  String get moreCategories => 'Kategoriler';

  @override
  String moreCategoriesInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kullanımda',
      one: '$count kullanımda',
    );
    return '$_temp0';
  }

  @override
  String get moreArchive => 'Arşiv';

  @override
  String get morePrivacyMode => 'Gizlilik modu';

  @override
  String get morePrivacyModeDesc => 'Uygulamadaki tüm tutarları gizle';

  @override
  String get moreAddAccount => 'Hesap ekle';
}
