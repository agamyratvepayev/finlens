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
  String get accountGroupSpendable => 'Harcanabilir';

  @override
  String get accountGroupSetAside => 'Ayrılan';

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
  String get accountGroupSpendableDesc =>
      'Vadesiz hesap, nakit, banka kartınız';

  @override
  String get accountGroupSetAsideDesc =>
      'Şimdilik harcamayı düşünmediğiniz birikim';

  @override
  String get accountGroupReceivablesDesc =>
      'Birinin size borcu, geri ödeyeceği para';

  @override
  String get accountGroupInvestmentsDesc =>
      'Hisse, fon, kripto, emeklilik birikimi';

  @override
  String get accountGroupValuablesDesc => 'Araba, altın, satabileceğiniz mülk';

  @override
  String get accountGroupCreditCardsDesc => 'Harcayıp sonra ödediğiniz kartlar';

  @override
  String get accountGroupPayablesDesc => 'Henüz ödemediğiniz fatura ve borçlar';

  @override
  String get accountGroupBankLoansDesc => 'Konut, taşıt veya öğrenim kredisi';

  @override
  String get naType => 'Tür';

  @override
  String get naRequired => 'GEREKLİ';

  @override
  String get naAccountType => 'Hesap türü';

  @override
  String get curSearch => 'Para birimi ara';

  @override
  String get curRecent => 'SON KULLANILAN';

  @override
  String get curAll => 'TÜM PARA BİRİMLERİ';

  @override
  String get curAdd => 'Ekle';

  @override
  String get curAddTitle => 'Para birimi ekle';

  @override
  String get curCode => 'Kod';

  @override
  String get curName => 'Ad';

  @override
  String get curSymbolOptional => 'Simge · isteğe bağlı';

  @override
  String get curBeforeAmount => 'Tutardan önce';

  @override
  String get curDecimals => 'Ondalık basamak';

  @override
  String get curPreview => 'Önizleme';

  @override
  String get curAddButton => 'Para birimi ekle';

  @override
  String get curInert =>
      'Yalnızca bu uygulamada kullanılır. Döviz kuru uygulanmaz.';

  @override
  String get curCodeExists => 'Bu kod zaten kullanımda.';

  @override
  String curNoMatch(Object query) {
    return '\"$query\" ile eşleşen para birimi yok.';
  }

  @override
  String get qaBackgroundColour => 'Arka plan rengi';

  @override
  String get qaIconsTab => 'Simgeler';

  @override
  String get qaEmojiTab => 'Emoji';

  @override
  String get qaSearchEmoji => 'Emoji ara';

  @override
  String get qaNoEmojiMatch => 'Eşleşen emoji yok';

  @override
  String qaNoIconMatch(Object query) {
    return '$query ile eşleşen simge yok.';
  }

  @override
  String get qaTryEmoji => 'Emoji dene';

  @override
  String get quickAddExpense => 'Gider';

  @override
  String get quickAddIncome => 'Gelir';

  @override
  String get quickAddTransfer => 'Transfer';

  @override
  String get quickAddRebalance => 'Yeniden dengele';

  @override
  String get quickAddNewBudget => 'Yeni bütçe';

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
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Pzt',
      '2': 'Sal',
      '3': 'Çar',
      '4': 'Per',
      '5': 'Cum',
      '6': 'Cmt',
      '7': 'Paz',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayNarrow(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'P',
      '2': 'S',
      '3': 'Ç',
      '4': 'P',
      '5': 'C',
      '6': 'C',
      '7': 'P',
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
  String get moreData => 'Veriler';

  @override
  String get morePreferences => 'Tercihler';

  @override
  String get moreCategories => 'Kategoriler';

  @override
  String get moreArchive => 'Arşiv';

  @override
  String get moreMaskAmounts => 'Tüm tutarları gizle';

  @override
  String get moreBackup => 'Verileri yedekle';

  @override
  String get moreRestore => 'Verileri geri yükle';

  @override
  String get backupSavedMsg => 'Yedek kaydedildi';

  @override
  String get backupFailedMsg => 'Yedek kaydedilemedi';

  @override
  String get restoreConfirmTitle => 'Tüm veriler değiştirilsin mi?';

  @override
  String restoreConfirmMsg(int accounts, int txns) {
    return 'Bu yedekte $accounts hesap ve $txns işlem var. Mevcut verileriniz değiştirilecek.';
  }

  @override
  String get restoreImpactLost => 'Bu cihazdaki tüm veriler silinir';

  @override
  String get restoreImpactKept =>
      'Yedekteki hesaplar, işlemler ve ayarlar yüklenir';

  @override
  String get restoreConfirmAction => 'Geri yükle';

  @override
  String get restoreDoneMsg => 'Veriler geri yüklendi';

  @override
  String get restoreInvalidMsg => 'Bu dosya geçerli bir FinLens yedeği değil';

  @override
  String moreVersion(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get moreAddAccount => 'Hesap ekle';

  @override
  String get actionDeletePermanent => 'Kalıcı olarak sil';

  @override
  String plusNMore(int count) {
    return '+$count daha';
  }

  @override
  String get catManageTitle => 'Kategoriler';

  @override
  String get catEditTitle => 'Kategoriyi düzenle';

  @override
  String get catSectionExpense => 'Gider';

  @override
  String get catSectionIncome => 'Gelir';

  @override
  String get catSectionArchived => 'Arşivlenmiş';

  @override
  String get catArchiveFootnote =>
      'Arşivlenen kategoriler geçmiş işlemlerinde kalır. Sadece yeni bir şey kaydederken görünmezler.';

  @override
  String get catTypeLocked =>
      'Bunu değiştirmek buraya kaydedilmiş her işlemi ters çevirir';

  @override
  String get catArchiveThis => 'Kategoriyi arşivle';

  @override
  String catArchiveMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Buraya $count işlem kaydedilmiş, bu yüzden silinmek yerine arşivlenir',
      one:
          'Buraya $count işlem kaydedilmiş, bu yüzden silinmek yerine arşivlenir',
    );
    return '$_temp0';
  }

  @override
  String get catDeleteThis => 'Kategoriyi sil';

  @override
  String get catDeleteMsg =>
      'Buraya henüz bir şey kaydedilmedi, bu yüzden tamamen kaldırılabilir';

  @override
  String get catDeleteBudgeted =>
      'Bu kategorinin Planlayıcı\'da bir bütçesi var. Önce bütçeyi kaldırın ya da kategoriyi arşivleyin.';

  @override
  String get catRestoreThis => 'Kategoriyi geri yükle';

  @override
  String get insightTitle => 'Analiz';

  @override
  String get insNetWorth => 'Net değer';

  @override
  String get insNetWorthCaption => 'net değer';

  @override
  String get insIncome => 'Gelir';

  @override
  String get insSpending => 'Gider';

  @override
  String get insDebtCredit => 'Borç & alacak';

  @override
  String get insRevaluation => 'Değer değişimi';

  @override
  String get insIn => 'Girdi';

  @override
  String get insOut => 'Çıktı';

  @override
  String get insRevalued => 'Değerlendi';

  @override
  String get insBefore => 'Önce';

  @override
  String get insNow => 'Şimdi';

  @override
  String get insMoved => 'Taşındı';

  @override
  String get insYourDebt => 'Borcun';

  @override
  String get insYourCredit => 'Alacağın';

  @override
  String get insUnchanged => 'değişmedi';

  @override
  String get insChargedToCards => 'Kartla harcadın';

  @override
  String get insPaidToCards => 'Karta ödedin';

  @override
  String insMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count daha',
    );
    return '+$_temp0';
  }

  @override
  String get insShowLess => 'Daha az göster';

  @override
  String get insFilterAccounts => 'Hesapları filtrele';

  @override
  String get insFilterOff => 'Kapalı';

  @override
  String insFilterActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Etkin, $count öğe gizli',
    );
    return '$_temp0';
  }

  @override
  String get insClearCustomRange => 'Özel aralığı temizle';

  @override
  String insA11yHeroUp(String amount) {
    return 'Net değer $amount arttı.';
  }

  @override
  String insA11yHeroDown(String amount) {
    return 'Net değer $amount azaldı.';
  }

  @override
  String insA11yHeroFlat(String amount) {
    return 'Net değer değişmedi, $amount.';
  }

  @override
  String insA11yWaterfall(
    Object before,
    Object inflow,
    Object outflow,
    Object revalued,
    Object now,
  ) {
    return 'Net değer önce $before, $inflow girdi, $outflow çıktı, $revalued değerlendi, şimdi $now.';
  }

  @override
  String insA11yWaterfallMoved(
    Object before,
    Object inflow,
    Object outflow,
    Object revalued,
    Object moved,
    Object now,
  ) {
    return 'Net değer önce $before, $inflow girdi, $outflow çıktı, $revalued değerlendi, $moved görünümden çıktı, şimdi $now.';
  }

  @override
  String insA11yGroupUp(Object name, Object amount) {
    return '$name, $amount arttı.';
  }

  @override
  String insA11yGroupDown(Object name, Object amount) {
    return '$name, $amount azaldı.';
  }

  @override
  String insA11yDebtUp(Object label, Object balance, Object delta) {
    return '$label $balance, $delta arttı.';
  }

  @override
  String insA11yDebtDown(Object label, Object balance, Object delta) {
    return '$label $balance, $delta azaldı.';
  }

  @override
  String insA11yDebtFlat(Object label, Object balance) {
    return '$label $balance, değişmedi.';
  }

  @override
  String insA11yMovementUp(Object label, Object amount) {
    return '$label, $amount, borç arttı.';
  }

  @override
  String insA11yMovementDown(Object label, Object amount) {
    return '$label, $amount, borç azaldı.';
  }

  @override
  String insA11yRevalUp(
    Object name,
    Object amount,
    Object percent,
    Object date,
  ) {
    return '$name, $amount arttı$percent, $date.';
  }

  @override
  String insA11yRevalDown(
    Object name,
    Object amount,
    Object percent,
    Object date,
  ) {
    return '$name, $amount azaldı$percent, $date.';
  }

  @override
  String insA11yPercent(Object percent) {
    return ', $percent';
  }

  @override
  String insSeeAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kategori',
    );
    return 'Tümünü gör · $_temp0';
  }

  @override
  String insCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kategori',
    );
    return '$_temp0';
  }

  @override
  String get insEmptyNoAccountsTitle => 'Henüz gösterilecek bir şey yok';

  @override
  String get insEmptyNoAccountsBody =>
      'Insight paranızın ne yaptığını gösterir — nereden geldi, nereye gitti ve geriye ne kaldı.';

  @override
  String get insEmptyNoRecordsTitle => 'Henüz hiçbir şey hareket etmedi';

  @override
  String insEmptyHoldings(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hesap',
      one: '$count hesap',
    );
    return 'Hesaplarınızda $amount · $_temp0';
  }

  @override
  String insEmptyHoldingsNoAmount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hesap',
      one: '$count hesap',
    );
    return '$_temp0';
  }

  @override
  String get insEmptyRecordSomething => 'Bir şey kaydet';

  @override
  String get insEmptyAllHiddenTitle => 'Her hesap gizli';

  @override
  String insEmptyAllHiddenBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hesabı',
      one: '$count hesabı',
    );
    return 'Filtre $_temp0 gizliyor';
  }

  @override
  String get insEmptyShowAll => 'Tüm hesapları göster';

  @override
  String insEmptyWindow(String period) {
    return '$period için kayıt yok';
  }

  @override
  String insEmptyHiddenByFilter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kayıt filtreyle gizlendi',
      one: '$count kayıt filtreyle gizlendi',
    );
    return '$_temp0';
  }

  @override
  String insGoToPeriodBack(String period) {
    return '← $period dönemine git';
  }

  @override
  String insGoToPeriodForward(String period) {
    return '→ $period dönemine git';
  }

  @override
  String get insA11yEmptyNoAccounts =>
      'Henüz gösterilecek bir şey yok. Insight paranızın ne yaptığını gösterir. Bir hesap ekleyin.';

  @override
  String insA11yEmptyNoRecords(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hesap',
      one: '$count hesap',
    );
    return 'Net değer değişmedi. Henüz hiçbir şey hareket etmedi. Hesaplarınızda $amount, $_temp0.';
  }

  @override
  String get insA11yEmptyAllHidden =>
      'Net değer değişmedi. Her hesap filtreyle gizli.';

  @override
  String insA11yEmptyWindow(String period) {
    return 'Net değer değişmedi. $period için kayıt yok.';
  }

  @override
  String insAverageValue(String amount) {
    return 'Ortalama $amount';
  }

  @override
  String insHighest(String label, String amount) {
    return 'en yüksek $label $amount';
  }

  @override
  String get insEmptyMonthsExcluded => 'boş dönemler hariç';

  @override
  String insStillRunning(String month) {
    return '$month sürüyor';
  }

  @override
  String insDaysShort(int count) {
    return '${count}g';
  }

  @override
  String insVsRange(String amount, String range, String percent) {
    return '$amount · $range ($percent)';
  }

  @override
  String insTooFewPeriods(int count) {
    return 'Sadece $count dönemde kayıt var — ortalama ve eğilim yazılmadı';
  }

  @override
  String get insNoPreviousPeriod => 'geçen dönemde kayıt yok';

  @override
  String insMonthlyBudget(String amount, String percent) {
    return 'Aylık bütçe $amount · $percent';
  }

  @override
  String insLeft(String amount) {
    return '$amount kaldı';
  }

  @override
  String insOverBudget(String amount) {
    return '$amount aşıldı';
  }

  @override
  String get insNoBudget => 'bütçe yok';

  @override
  String insBudgetSub(String amount, String percent) {
    return 'bütçe $amount · $percent';
  }

  @override
  String insBudgetSubOver(String amount, String percent) {
    return 'bütçe $amount · $percent aşıldı';
  }

  @override
  String get insAddBudget => 'Bütçe ekle';

  @override
  String insUnbudgetedTotal(String amount) {
    return 'Bütçesiz kategorilerde $amount';
  }

  @override
  String get insSelectDateRange => 'Tarih aralığı seç…';

  @override
  String get insPeriod => 'Dönem';

  @override
  String insDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
    );
    return '$_temp0';
  }

  @override
  String get insFilterAccountsNote => 'Gizli hesaplar tüm rakamları değiştirir';

  @override
  String get insFilterCategoriesNote =>
      'Gizli kategoriler yalnızca listeden düşer';

  @override
  String get insSpendingList => 'Harcama listesi';

  @override
  String get insIncomeList => 'Gelir listesi';

  @override
  String insOfTotal(String amount) {
    return 'toplam $amount';
  }

  @override
  String insCategoriesShown(int shown, int total) {
    return '$shown / $total kategori';
  }

  @override
  String insAccountsShown(int shown, int total) {
    return '$shown / $total hesap';
  }

  @override
  String get insSpendingHistory => '6 aylık harcama geçmişi';

  @override
  String insSavedOutsideWindow(String date) {
    return '$date tarihine kaydedildi, bu dönemin dışında';
  }

  @override
  String get insGoToDate => 'Tarihe git';

  @override
  String insA11yPresetSelected(String name, String range) {
    return '$name, $range, seçili';
  }

  @override
  String insA11yCustomRow(String range, String days) {
    return 'Tarih aralığı seç, şu an $range, $days';
  }

  @override
  String insA11yChartCol(String label, String amount) {
    return '$label, $amount';
  }

  @override
  String insA11yChartColPartial(String label, String amount, String days) {
    return '$label, şu ana kadar $amount, $days';
  }

  @override
  String insA11yChartColEmpty(String label) {
    return '$label, kayıt yok';
  }

  @override
  String insA11yTxnRow(
    String title,
    String amount,
    String date,
    String account,
  ) {
    return '$title, $amount, $date, $account';
  }

  @override
  String get arcReachedLabel => 'ulaşılan';

  @override
  String get arcSuccessLabel => 'başarı';

  @override
  String get arcAverageLabel => 'ortalama';

  @override
  String arcMonthsShort(int count) {
    return '$count ay';
  }

  @override
  String arcOneLine(String reached, String rate, String avg) {
    return '$reached ulaşılan · $rate başarı · $avg ortalama';
  }

  @override
  String get actionCancel => 'İptal';

  @override
  String get actionSave => 'Kaydet';

  @override
  String get actionDelete => 'Sil';

  @override
  String get actionEdit => 'Düzenle';

  @override
  String get actionCopy => 'Kopyala';

  @override
  String get obTitle => 'Açılış bakiyesi';

  @override
  String get obNotSet => 'Ayarlanmadı';

  @override
  String get obShiftsNote => 'Bu, bu hesaptaki her yürüyen bakiyeyi kaydırır.';

  @override
  String get obDateTooLate => 'Açılış tarihi ilk işlemden sonra olamaz.';

  @override
  String get obDeleteTitle => 'Açılış bakiyesi kaldırılsın mı?';

  @override
  String obDeleteMsg(String amount) {
    return 'Bu hesaptaki her bakiye $amount kadar kayacak.';
  }

  @override
  String get obDeleteConfirm => 'Açılış bakiyesini kaldır';

  @override
  String get obCopyTitle => 'Hesaba kopyala';

  @override
  String obA11y(String account, String amount) {
    return 'Açılış bakiyesi, $account, $amount';
  }

  @override
  String get actionUndo => 'Geri al';

  @override
  String get actionApply => 'Uygula';

  @override
  String get actionSearch => 'Ara';

  @override
  String get actionMoveUp => 'Yukarı taşı';

  @override
  String get actionMoveDown => 'Aşağı taşı';

  @override
  String get actionCollapseAll => 'Tümünü daralt';

  @override
  String get actionExpandAll => 'Tümünü genişlet';

  @override
  String get actionReset => 'Sıfırla';

  @override
  String get balSearchAccounts => 'Hesap ara';

  @override
  String get balNoResults => 'Sonuç yok';

  @override
  String get balNoAccountsYet => 'Elinizdekiyle başlayın';

  @override
  String get balNoAccountMatch => 'Aramanızla eşleşen hesap veya grup yok.';

  @override
  String get balEmptyBenefit =>
      'Ne kadar paranız olduğunu bir daha hesaplamanıza gerek kalmaz.';

  @override
  String get balAddAccount => 'Hesap ekleyin';

  @override
  String get balAdjustFilter => 'Filtreyi ayarla';

  @override
  String get balSortTooltip => 'Sırala';

  @override
  String get balSortDefault => 'Varsayılan sıralama';

  @override
  String get balPressHoldMove => 'Taşımak için bir hesaba basılı tutun';

  @override
  String get balFilterCategories => 'Kategorileri filtrele';

  @override
  String get balNoVisibleCategories => 'Görünür kategori yok';

  @override
  String balSeeAll(int count) {
    return 'Tümünü gör $count  ›';
  }

  @override
  String transferFromTo(String from, String to) {
    return '$from hesabından $to hesabına transfer';
  }

  @override
  String get eaName => 'Ad';

  @override
  String get eaGroup => 'Grup';

  @override
  String get eaCurrency => 'Para birimi';

  @override
  String get eaStartingBalance => 'Başlangıç bakiyesi';

  @override
  String get eaStartingBalanceLock =>
      'Bakiyeyi düzeltmek için bunun yerine bir işlem ekleyin';

  @override
  String get eaCreditLimit => 'Kredi limiti';

  @override
  String get eaStatementDay => 'Ekstre günü';

  @override
  String get eaPaymentDue => 'Son ödeme günü';

  @override
  String get eaNotSet => 'Ayarlanmadı';

  @override
  String get eaHideFromBalance => 'Bakiye\'den gizle';

  @override
  String get eaHideDesc => 'Toplamlarda kalır, listelerden kaybolur';

  @override
  String get eaRemoveThisAccount => 'Bu hesabı kaldır';

  @override
  String get eaRemovePermanent => 'Bu hesabı kalıcı olarak siler';

  @override
  String get eaRemoveHasHistory => 'Geçmişi var — silinmez, arşivlenir';

  @override
  String eaRemoveTitle(String name) {
    return '$name kaldırılsın mı?';
  }

  @override
  String get eaArchivedMsg =>
      'Bu hesabın geçmişi olduğundan silinmek yerine arşivlenir.';

  @override
  String get eaDeleteMsg => 'Bu hesabın işlemi yok ve tamamen silinebilir.';

  @override
  String eaTxnStays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count işleminiz Defter\'de dokunulmadan kalır.',
      one: '$count işleminiz Defter\'de dokunulmadan kalır.',
    );
    return '$_temp0';
  }

  @override
  String eaGroupDropsBy(String group, String amount) {
    return '$group $amount azalır.';
  }

  @override
  String get eaDisappearsPicker => 'Her hesap seçiciden kaybolur.';

  @override
  String get eaCannotUndo => 'Bu geri alınamaz.';

  @override
  String get eaArchiveAccount => 'Hesabı arşivle';

  @override
  String get eaRemoveAccount => 'Hesabı kaldır';

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
  String get eaEditAccount => 'Hesabı düzenle';

  @override
  String balFilterActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Etkin, $count öğe gizli',
      one: 'Etkin, $count öğe gizli',
    );
    return '$_temp0';
  }

  @override
  String get balFilterOff => 'Kapalı';

  @override
  String get balMoved => 'Taşındı';

  @override
  String get balMovedCustom => 'Taşındı · Özele göre sıralı';

  @override
  String balTotalOf(String name) {
    return 'Toplam $name';
  }

  @override
  String balUtilization(String percent) {
    return 'Kullanım: $percent';
  }

  @override
  String get balOverdue => 'Gecikmiş';

  @override
  String balDue(String when) {
    return 'Ödeme $when';
  }

  @override
  String balNextPayment(String date) {
    return 'Sonraki ödeme: $date';
  }

  @override
  String get actionDone => 'Bitti';

  @override
  String get actionBack => 'Geri';

  @override
  String get filterTitle => 'Filtre';

  @override
  String get sheetApply => 'Uygula';

  @override
  String get sheetToday => 'Bugün';

  @override
  String get sheetNow => 'Şimdi';

  @override
  String balNoBetween(String subject, String range) {
    return '$range aralığında $subject yok';
  }

  @override
  String get freqLessThanMonthly => 'Ayda bir defadan az';

  @override
  String get freqAbout => 'Yaklaşık ';

  @override
  String freqTimesAMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' defa ayda',
      one: ' defa ayda',
    );
    return '$_temp0';
  }

  @override
  String txnDeleteEntryTitle(String type) {
    return 'Bu $type silinsin mi?';
  }

  @override
  String get txnDeleteEntryMessage =>
      'Bu kayıt kalıcı olarak silinir ve aşağıdaki bakiyeler eski haline döner.';

  @override
  String get txnDeleteNothingElse => 'Defterinizde başka hiçbir şey değişmez.';

  @override
  String get txnDeleteEntryConfirm => 'Kaydı sil';

  @override
  String get freqLastOne => ' · sonuncusu ';

  @override
  String txnBudgetImpact(Object name, Object before, Object after) {
    return '$name bütçesi $before → $after';
  }

  @override
  String get txnRevaluation => 'Yeniden değerleme';

  @override
  String get txnTransferOut => 'Giden transfer';

  @override
  String get txnTransferIn => 'Gelen transfer';

  @override
  String get plTabBudgets => 'Bütçeler';

  @override
  String get plTabGoals => 'Hedefler';

  @override
  String get plTabSchedule => 'Takvim';

  @override
  String get plNoBudgetsYet => 'Bütçe bir kategoriyi sınırlar';

  @override
  String get plNoBudgetsMsg =>
      'Bir kategoriye aylık limit verin; içindeki her işlem o limitten düşer.';

  @override
  String get plBudgeted => 'Bütçelenen';

  @override
  String get plNoBudgetSet => 'Bütçe ayarlanmadı';

  @override
  String get plSet => 'Ayarla';

  @override
  String get plNoGoalsYet => 'Hedefler “ne zaman” sorusunu yanıtlar';

  @override
  String get plNoGoalsMsg =>
      'Bir hedef belirleyin, FinLens aylık hızı hesaplasın.';

  @override
  String get plNewGoal => 'Yeni hedef';

  @override
  String get plNewTask => 'Yeni görev';

  @override
  String get plNewBudget => 'Yeni bütçe';

  @override
  String get plCompleteReady => 'Tamamlandı · arşive hazır';

  @override
  String get plNoTargetDate => 'Tarih ayarlanmadı';

  @override
  String get plMoNeeded => '/ay gerekli';

  @override
  String get plComingIn => 'Gelen';

  @override
  String get plGoingOut => 'Giden';

  @override
  String get schOverdue => 'Gecikmiş';

  @override
  String get schThisWeek => 'Bu hafta';

  @override
  String get plNothingScheduled => 'Yaklaşanları planlayın';

  @override
  String get plNothingSchedMsg =>
      'Planladığınız faturalar, maaşlar ve abonelikler, gerçekleşmeden önce burada belirir.';

  @override
  String get plLeftThisMonth => 'Bu ay kalan';

  @override
  String get plOf => '/';

  @override
  String get plBudgetWord => 'bütçe';

  @override
  String get plSavedTowardGoals => 'Hedeflere biriktirilen';

  @override
  String get plPace => 'Tempo';

  @override
  String plLeftOfAmount(Object amount) {
    return '$amount bütçeden kaldı';
  }

  @override
  String plOverAmount(Object amount) {
    return '$amount bütçeyi aştı';
  }

  @override
  String plPctSpent(Object pct) {
    return '$pct harcandı';
  }

  @override
  String plDayOfMonth(int day, int length) {
    return '$length günün $day. günü';
  }

  @override
  String plCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kategori',
      one: '$count kategori',
    );
    return '$_temp0';
  }

  @override
  String plSemRowOver(Object name, Object spent, Object limit) {
    return '$name, bütçe aşıldı, $spent / $limit';
  }

  @override
  String plSemRowNear(Object name, Object spent, Object limit) {
    return '$name, limite yakın, $spent / $limit';
  }

  @override
  String plSemRowNormal(Object name, Object spent, Object limit) {
    return '$name, $spent / $limit';
  }

  @override
  String plPaymentsOverdue(int count, Object amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ödeme gecikmiş',
      one: '$count ödeme gecikmiş',
    );
    return '$_temp0 · $amount';
  }

  @override
  String get fieldCategory => 'Kategori';

  @override
  String get fieldSelectAccount => 'Hesap seçin';

  @override
  String get fieldDirection => 'Yön';

  @override
  String get actionUse => 'Kullan';

  @override
  String get actionRestore => 'Geri yükle';

  @override
  String countMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ay',
      one: '$count ay',
    );
    return '$_temp0';
  }

  @override
  String get ebTitle => 'Bütçeyi düzenle';

  @override
  String get ebMonthlyLimit => 'Aylık limit';

  @override
  String get ebRollOver => 'Kalanı devret';

  @override
  String get ebRollOverDesc => 'Kalanı gelecek aya ekle';

  @override
  String get ebWarnAt => 'Şurada uyar';

  @override
  String get ebRemoveBudget => 'Bütçeyi kaldır';

  @override
  String ebAverage(Object average, Object suggestion) {
    return 'Ortalama $average. $suggestion deneyin mi?';
  }

  @override
  String ebRemoveTitle(Object name) {
    return '$name bütçesi kaldırılsın mı?';
  }

  @override
  String get ebRemoveMsg => 'Bu kategori için limit takibini bırakacaksınız.';

  @override
  String ebCategoryStays(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count işleminiz dokunulmadan kalır.',
      one: '$count işleminiz dokunulmadan kalır.',
    );
    return '$name kategorisi kalır. $_temp0';
  }

  @override
  String get ebWarningsDisappear =>
      'Bu kategori için uyarılar ve ilerleme çubukları kaybolur.';

  @override
  String ebTotalDrops(Object from, Object to) {
    return 'Toplam aylık bütçe $from değerinden $to değerine düşer.';
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
  String get egTitle => 'Hedefi düzenle';

  @override
  String get egGoalName => 'Hedef adı';

  @override
  String get egType => 'Tür';

  @override
  String get egTargetAmount => 'Hedef tutar';

  @override
  String get egTargetDate => 'Hedef tarih';

  @override
  String get egMoneyKeptIn => 'Paranın tutulduğu yer';

  @override
  String get egAutoContribute => 'Otomatik katkı';

  @override
  String get egAutoContributeDesc => 'Bu hedefe aylık transfer oluşturur';

  @override
  String get egMonthlyContribution => 'Aylık katkı';

  @override
  String get egMarkReached => 'Ulaşıldı olarak işaretle';

  @override
  String get egMarkReachedDesc => 'Para harcandı, hedef tamamlandı';

  @override
  String get egGiveUp => 'Şimdilik vazgeç';

  @override
  String get egDeleteGoal => 'Hedefi sil';

  @override
  String get egDeleteGoalDesc => 'Hiç var olmamış gibi';

  @override
  String egMarkReachedTitle(Object name) {
    return '$name ulaşıldı olarak işaretlensin mi?';
  }

  @override
  String get egMarkReachedMsg =>
      'Tebrikler — hedef başarılı olarak arşive taşınır.';

  @override
  String egReachedAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ay',
      one: '$count ay',
    );
    return '$_temp0 sonra ulaşıldı olarak kaydedildi, hedef istatistiklerinize eklenir.';
  }

  @override
  String get egPastTxnStay => 'Geçmiş işlemler Defter\'de kalır.';

  @override
  String get egLeavesStops => 'Hedeflerden çıkar ve takip durur.';

  @override
  String get egAutoStops => 'Aylık otomatik katkı durur.';

  @override
  String get egNotYet => 'Henüz değil';

  @override
  String egGiveUpTitle(Object name) {
    return '$name hedefinden vazgeçilsin mi?';
  }

  @override
  String get egGiveUpMsg =>
      'Takip durur, ancak ayırdığınız para olduğu yerde kalır.';

  @override
  String egSavedStaysIn(Object amount, Object account) {
    return '$amount $account hesabında kalır.';
  }

  @override
  String get egYourAccount => 'hesabınızda';

  @override
  String get egRestoreLater => 'Daha sonra Arşiv\'den geri yükleyebilirsiniz.';

  @override
  String get egLeavesList => 'Hedefler listesinden çıkar.';

  @override
  String egDeleteTitle(Object name) {
    return '$name silinsin mi?';
  }

  @override
  String get egDeleteMsg =>
      'Bunu yalnızca hedef yanlışlıkla oluşturulduysa kullanın — geçmişinizde iz bırakmaz.';

  @override
  String get egBalancesUnchanged => 'Hesap bakiyeleriniz değişmez.';

  @override
  String get egNotInArchive => 'Arşiv\'de görünmez.';

  @override
  String get egExcludedStats =>
      'Hedef performans istatistiklerinden hariç tutulur.';

  @override
  String get egRecurringCancelled => 'Yinelenen transfer kuralı iptal edilir.';

  @override
  String egPerMonthTrack(Object amount) {
    return 'hedefte kalmak için $amount/ay';
  }

  @override
  String egAutoContributeOn(Object amount, Object day) {
    return 'her ayın $day $amount';
  }

  @override
  String egKeepsStops(Object amount) {
    return '$amount tutulur, takip durur';
  }

  @override
  String get egSaved => 'biriktirildi';

  @override
  String get egToGo => 'kaldı';

  @override
  String get ebWhatSpent => 'Gerçekte ne harcadınız';

  @override
  String get ebSpent => 'harcandı';

  @override
  String get etTitle => 'Görevi düzenle';

  @override
  String get etTaskTitle => 'Görev başlığı';

  @override
  String get etPaidFrom => 'Ödeme kaynağı';

  @override
  String get etPaidInto => 'Ödeme hedefi';

  @override
  String get etLinkedAccount => 'Bağlı hesap';

  @override
  String get etPayOut => 'Ödeme −';

  @override
  String get etPayIn => 'Tahsilat +';

  @override
  String get etExpectedAmount => 'Beklenen tutar';

  @override
  String get etCategoryHint => '\"Ödendi olarak işaretle\" nereye kaydeder';

  @override
  String get etNextDue => 'Sonraki vade';

  @override
  String get etRepeats => 'Tekrar';

  @override
  String get etOneOff => 'Tek seferlik görev';

  @override
  String get etRemindMe => 'Hatırlat';

  @override
  String etRemindBefore(Object days, Object time) {
    return '$days gün önce, $time';
  }

  @override
  String get etMarkPaid => 'Ödendi olarak işaretle';

  @override
  String get etMarkPaidExpense => 'Defter\'de gider oluşturur';

  @override
  String get etMarkPaidIncome => 'Defter\'de gelir oluşturur';

  @override
  String get etSkipThisMonth => 'Bu ayı atla';

  @override
  String etSeriesContinues(Object month) {
    return 'Seri $month ayında devam eder';
  }

  @override
  String get etDeleteWholeSeries => 'Tüm seriyi sil';

  @override
  String etAllFutureReminders(Object title) {
    return 'Gelecekteki tüm $title hatırlatıcıları';
  }

  @override
  String etSkippedNext(Object date) {
    return 'Atlandı · sonraki $date';
  }

  @override
  String etDeleteOnly(Object date) {
    return 'Yalnızca $date sil';
  }

  @override
  String etDeleteOnlyTitle(Object date) {
    return 'Yalnızca $date silinsin mi?';
  }

  @override
  String get etJustThisOne => 'Yalnızca bu tekrar kaldırılır.';

  @override
  String get etOneOffRemoved => 'Bu tek seferlik görev kaldırılır.';

  @override
  String etSeriesContinuesOn(Object date) {
    return 'Seri $date tarihinde devam eder.';
  }

  @override
  String get etNoLedgerEntry => 'Defter kaydı oluşturulmaz veya kaldırılmaz.';

  @override
  String get etLedgerUntouched => 'Defteriniz değişmez.';

  @override
  String etDisappears(Object date) {
    return '$date Takviminizden kaybolur.';
  }

  @override
  String etDeleteDate(Object date) {
    return '$date sil';
  }

  @override
  String etDeleteSeriesTitle(Object title) {
    return 'Tüm $title serisi silinsin mi?';
  }

  @override
  String get etDeleteSeriesMsg =>
      'Yalnızca sonraki değil, gelecekteki tüm tekrarlar kaldırılır.';

  @override
  String get etPaymentsStay => 'Zaten kaydettiğiniz ödemeler Defter\'de kalır.';

  @override
  String get etAllRemindersCancelled =>
      'Gelecekteki tüm hatırlatıcılar iptal edilir.';

  @override
  String etOutgoingsDrop(Object amount) {
    return 'Aylık giderleriniz $amount azalır.';
  }

  @override
  String get etDeleteSeries => 'Seriyi sil';

  @override
  String etRecordedInLedger(Object title) {
    return '$title Defter\'e kaydedildi';
  }

  @override
  String etRepeatsCadence(Object cadence) {
    return 'Tekrar: $cadence';
  }

  @override
  String bdAveraging(Object avg, Object limit, Object count) {
    return 'Ortalama $avg · 6 ayın $count ayında $limit limitin üzerinde';
  }

  @override
  String get bdNothingSpent => 'Bu ay burada harcama yok.';

  @override
  String get arEmpty => 'Arşiv boş';

  @override
  String get arEmptyMsg =>
      'Ulaştığınız veya vazgeçtiğiniz hedefler ve kaldırdığınız bütçeler burada saklanır.';

  @override
  String get arFootnote =>
      'Arşivlenen öğeler Planlayıcı\'da görünmez ve toplamlarınızı etkilemez. Geçmiş işlemleri Defter\'de kalır.';

  @override
  String get arGroupFinished => 'Tamamlandı';

  @override
  String get arGroupUnfinished => 'Tamamlanmadı';

  @override
  String get arGroupCanComeBack => 'Geri gelebilir';

  @override
  String get arGroupRecentlyDeleted => 'Yakında silinenler';

  @override
  String get arTypeGoal => 'Hedef';

  @override
  String get arTypeTask => 'Görev';

  @override
  String get arTypeBudget => 'Bütçe';

  @override
  String get arTypeAccount => 'Hesap';

  @override
  String arReachedLine(Object date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ay',
      one: '$count ay',
    );
    return 'ulaşıldı $date · $_temp0 sürdü';
  }

  @override
  String arStoppedLine(Object date, Object saved, Object target) {
    return 'durduruldu $date · $target hedefin $saved kadarı';
  }

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
    return 'kaldırıldı $date';
  }

  @override
  String get arClearFinished => 'Temizle';

  @override
  String get arClearUnfinished => 'Temizle';

  @override
  String get arDeleteNow => 'Şimdi sil';

  @override
  String get arClearScopedTitle => 'Bunlar kalıcı olarak temizlensin mi?';

  @override
  String arClearScopedMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğe kalıcı olarak kaldırılır. Bu geri alınamaz.',
      one: '$count öğe kalıcı olarak kaldırılır. Bu geri alınamaz.',
    );
    return '$_temp0';
  }

  @override
  String get arTxnStay => 'İlgili tüm işlemler Defter\'de kalır.';

  @override
  String get arBalancesUnaffected => 'Hesap bakiyeleri etkilenmez.';

  @override
  String get arRestoreImpossible => 'Geri yükleme artık mümkün değil.';

  @override
  String get arStatsDisappear =>
      'Ulaşılan hedef geçmişi istatistiklerinizden kaybolur.';

  @override
  String get arClearArchive => 'Arşivi temizle';

  @override
  String get stateOn => 'Açık';

  @override
  String get stateOff => 'Kapalı';

  @override
  String get filterAll => 'Tümü';

  @override
  String get actionClose => 'Kapat';

  @override
  String get ldgShowDescriptions => 'Açıklamaları göster';

  @override
  String get ldgSortTransactions => 'İşlemleri sırala';

  @override
  String get ldgFilterTransactions => 'İşlemleri filtrele';

  @override
  String get ldgSearchTransactions => 'İşlemlerde ara';

  @override
  String ldgFilterActive(Object shown, Object total) {
    return 'Etkin, $total işlemin $shown tanesi gösteriliyor';
  }

  @override
  String ldgNoResultsFor(Object query) {
    return '\"$query\" için sonuç yok';
  }

  @override
  String get ldgNoMatchFilter => 'Filtrenizle eşleşen işlem yok';

  @override
  String get ldgClearFilter => 'Filtreyi temizle';

  @override
  String get ldgNothingHere => 'Her işlem burada yaşar';

  @override
  String get ldgNothingHereMsg =>
      'Harcadığınızı ve aldığınızı kaydedin. Bakiyeler, bütçeler ve hedefler bu listeden okur.';

  @override
  String ldgNothingRecordedInMonth(Object month) {
    return '$month ayında kayıt yok';
  }

  @override
  String get ldgAddEntry => 'Kayıt ekle';

  @override
  String get ldgCategories => 'Kategoriler';

  @override
  String get ldgAccounts => 'Hesaplar';

  @override
  String get ldgTags => 'Etiketler';

  @override
  String get ldgType => 'Tür';

  @override
  String get ldgDirection => 'Yön';

  @override
  String get ldgAmount => 'Tutar';

  @override
  String get ldgClearCustomRange => 'Özel aralığı temizle';

  @override
  String ldgSpentOf(Object expense, Object income) {
    return '$income tutarın $expense harcandı';
  }

  @override
  String get ldgOut => 'Çıkan';

  @override
  String get ldgLeft => 'Kalan';

  @override
  String get ldgChangePeriod => 'Dönemi değiştir';

  @override
  String get ldgBalance => 'Bakiye';

  @override
  String get ldgTransactionDeleted => 'İşlem silindi';

  @override
  String get ldgNoTransactions => 'İşlem yok';

  @override
  String get ldgPeriod => 'Dönem';

  @override
  String get ldgShow => 'Göster';

  @override
  String get ldgCustomRange => 'Özel aralık';

  @override
  String get ldgPreviousYear => 'Önceki yıl';

  @override
  String get ldgNextYear => 'Sonraki yıl';

  @override
  String ldgShowCountOf(Object count, Object total) {
    return '$total işlemin $count tanesini göster';
  }

  @override
  String ldgShowAll(Object count) {
    return 'Tümünü göster $count';
  }

  @override
  String ldgPlusMore(Object count) {
    return '+$count daha';
  }

  @override
  String get ldgNetIn => 'Net giriş';

  @override
  String get ldgNetOut => 'Net çıkış';

  @override
  String get ldgMoneyIn => 'Gelen';

  @override
  String get ldgMoneyOut => 'Giden';

  @override
  String get ldgNoCash => 'Nakit yok';

  @override
  String get ldgIn => 'Giren';

  @override
  String ldgRangeHint(Object min, Object max) {
    return 'Buradaki işlemler $min – $max arasında';
  }

  @override
  String ldgSearchWithin(Object labels) {
    return '$labels içinde ara';
  }

  @override
  String ldgSelectAllIn(Object section) {
    return '$section içinde tümünü seç';
  }

  @override
  String ldgClearSelection(Object section) {
    return '$section seçimini temizle';
  }

  @override
  String get ldgSelectAll => 'Tümünü seç';

  @override
  String get ldgClear => 'Temizle';

  @override
  String get ldgMin => 'Min';

  @override
  String get ldgMax => 'Maks';

  @override
  String get ldgResetFilter => 'Filtreyi sıfırla';

  @override
  String get ldgSelectOthers => 'Diğerlerini seç';

  @override
  String ldgNSelected(Object n) {
    return '$n seçili';
  }

  @override
  String get ldgAllSelected => 'hepsi';

  @override
  String ldgClearSection(Object section) {
    return '$section seçimini temizle';
  }

  @override
  String ldgMoreCategories(Object n) {
    return '$n kategori daha';
  }

  @override
  String ldgMoreAccounts(Object n) {
    return '$n hesap daha';
  }

  @override
  String ldgMoreTags(Object n) {
    return '$n etiket daha';
  }

  @override
  String ldgNHiddenSelected(Object n) {
    return '$n’i seçili';
  }

  @override
  String ldgNMatches(Object n) {
    return '$n eşleşme';
  }

  @override
  String ldgNResults(Object n) {
    return '$n sonuç';
  }

  @override
  String get ldgExpenses => 'Giderler';

  @override
  String get ldgIncomes => 'Gelirler';

  @override
  String get ldgExpenseCategoriesA11y => 'gider kategorileri';

  @override
  String get ldgIncomeSourcesA11y => 'gelir kaynakları';

  @override
  String get ldgTransfersHaveNoCategory => 'Transferlerin kategorisi yoktur.';

  @override
  String get ldgRevaluationsMoveNoCash => 'Yeniden değerleme nakit taşımaz.';

  @override
  String ldgAmountRange(Object min, Object max) {
    return '$min – $max';
  }

  @override
  String get tdFrom => 'Kaynak';

  @override
  String get tdTo => 'Hedef';

  @override
  String get tdDeletedAccount => 'Silinmiş hesap';

  @override
  String get tdRate => 'Kur';

  @override
  String get tdNote => 'NOT';

  @override
  String get tdNetWorth => 'Net değer';

  @override
  String get tdUnchanged => 'Değişmedi';

  @override
  String get stDetailNote => 'Not';

  @override
  String get stDetailWhen => 'Ne zaman';

  @override
  String get stDetailPaidWith => 'Ödeme hesabı';

  @override
  String get stDetailTags => 'Etiketler';

  @override
  String get qaAmount => 'Tutar';

  @override
  String get qaDue => 'Vade';

  @override
  String get qaNewBalance => 'Yeni bakiye';

  @override
  String get qaTarget => 'Hedef';

  @override
  String get qaDate => 'Tarih';

  @override
  String get qaTag => 'Etiketler';

  @override
  String get qaNone => 'Yok';

  @override
  String get qaNote => 'Not';

  @override
  String get qaAddNote => 'Not ekle';

  @override
  String get qaNotePlaceholder => 'Ne içindi?';

  @override
  String get qaSplit => 'Böl';

  @override
  String qaSplitCategories(Object count) {
    return '$count kategori';
  }

  @override
  String get qaGroupRequired => 'Gerekli';

  @override
  String get qaGroupOptional => 'İsteğe bağlı';

  @override
  String get qaFrom => 'Kaynak';

  @override
  String get qaTo => 'Hedef';

  @override
  String get qaChooseAccount => 'Hesap seç';

  @override
  String get qaChooseCategory => 'Kategori seç';

  @override
  String get qaChooseSource => 'Kaynak seç';

  @override
  String get qaPayFrom => 'Şuradan öde';

  @override
  String get qaDepositInto => 'Şuraya yatır';

  @override
  String get qaTransferFrom => 'Şuradan transfer';

  @override
  String get qaTransferTo => 'Şuraya transfer';

  @override
  String get qaRate => 'Kur';

  @override
  String get qaReceives => 'Alır';

  @override
  String get qaFee => 'Ücret';

  @override
  String get qaAccount => 'Hesap';

  @override
  String get qaRevalueAccount => 'Hesabı yeniden değerle';

  @override
  String get qaCurrent => 'Mevcut';

  @override
  String get qaDifference => 'Fark';

  @override
  String get qaReason => 'Sebep';

  @override
  String get qaAdjustment => 'Düzeltme';

  @override
  String get qaBalanceUnchanged => 'Bakiye değişmedi';

  @override
  String get qaName => 'Ad';

  @override
  String get qaNameYourGoal => 'Hedefinizi adlandırın';

  @override
  String get qaGoalNameHint => 'örn. MacBook Pro M4';

  @override
  String get qaSetDate => 'Tarih belirle';

  @override
  String get qaFundingAccount => 'Fonlama hesabı';

  @override
  String get qaStartingAmount => 'Başlangıç tutarı';

  @override
  String get qaIconColour => 'Simge ve renk';

  @override
  String get qaTapToChange => 'Değiştirmek için dokunun';

  @override
  String get qaAutoFund => 'Otomatik fonla';

  @override
  String get qaRemind => 'Hatırlat';

  @override
  String get qaTaskPlaceholder => 'Ne yapılması gerekiyor?';

  @override
  String get qaExchangeRate => 'Döviz kuru';

  @override
  String qaFxRate(Object from, Object to) {
    return '1 $from = ? $to';
  }

  @override
  String get qaWhatAdding => 'Ne ekliyorsunuz?';

  @override
  String get qaDeleteEntry => 'Bu kaydı sil';

  @override
  String get qaBalanceAdjustment => 'Bakiye düzeltmesi';

  @override
  String get qaRecurring => 'Yinelenen';

  @override
  String qaLinkedSplit(Object count) {
    return 'Bu, $count bağlı bölme işleminden biridir.';
  }

  @override
  String qaDeleteAll(Object count) {
    return 'Tümünü sil $count';
  }

  @override
  String get qaDeleteJustLine => 'Yalnızca bu satırı sil';

  @override
  String get qaSaveExpense => 'Gideri kaydet';

  @override
  String get qaSaveIncome => 'Geliri kaydet';

  @override
  String get qaSaveTransfer => 'Transferi kaydet';

  @override
  String get qaSaveAdjustment => 'Düzeltmeyi kaydet';

  @override
  String get qaCreateGoal => 'Hedef oluştur';

  @override
  String get qaCreateTask => 'Görev oluştur';

  @override
  String qaSaved(Object type) {
    return '$type kaydedildi';
  }

  @override
  String get qaBlockAmount => 'Bir tutar girin';

  @override
  String get qaBlockAccount => 'Bir hesap seçin';

  @override
  String get qaBlockCategory => 'Bir kategori seçin';

  @override
  String get qaBlockSource => 'Bir kaynak seçin';

  @override
  String get qaBlockSplit => 'Bölmeyi dengeleyin';

  @override
  String get qaBlockSourceAccount => 'Bir kaynak hesap seçin';

  @override
  String get qaBlockDestination => 'Bir hedef seçin';

  @override
  String get qaBlockBalanceUnchanged => 'Bakiye değişmedi';

  @override
  String get qaBlockNameGoal => 'Hedefinizi adlandırın';

  @override
  String get qaBlockSetTarget => 'Bir hedef belirleyin';

  @override
  String get qaBlockSetTargetDate => 'Bir hedef tarih belirleyin';

  @override
  String get qaBlockFunding => 'Bir fonlama hesabı seçin';

  @override
  String get qaBlockNameTask => 'Görevi adlandırın';

  @override
  String get qaBlockDueDate => 'Bir vade belirleyin';

  @override
  String get qaNewAccount => 'Yeni hesap';

  @override
  String get qaNoAccountsYet => 'Henüz hesabınız yok';

  @override
  String get qaNoAccountsYetBody =>
      'Bu işlemi kaydetmek için bir hesap gerekiyor.';

  @override
  String get qaNewCategory => 'Yeni kategori';

  @override
  String get qaNewExpenseCategory => 'Yeni gider kategorisi';

  @override
  String get qaNewIncomeCategory => 'Yeni gelir kategorisi';

  @override
  String get qaNoCategoriesYet => 'Henüz kategori yok';

  @override
  String qaCategoryEmptyBody(Object action) {
    return 'İlk kategoriyi eklemek için $action düğmesine dokun.';
  }

  @override
  String get qaCategoryExpenseHelper =>
      'Giderler için kullanılır. Adını ve görünümünü sonra değiştirebilirsin.';

  @override
  String get qaCategoryIncomeHelper =>
      'Gelirler için kullanılır. Adını ve görünümünü sonra değiştirebilirsin.';

  @override
  String get qaCategoryExists => 'Bu adda bir kategori zaten var';

  @override
  String get qaNewShort => 'Yeni';

  @override
  String get qaSelectAccount => 'Hesap seçin';

  @override
  String get qaSearchAccounts => 'Hesap ara';

  @override
  String get qaSearchCategories => 'Kategori ara';

  @override
  String qaAccountSearchNoMatch(Object query) {
    return '$query ile eşleşen hesap yok.';
  }

  @override
  String qaNoCategoryMatch(Object query) {
    return '$query ile eşleşen kategori yok.';
  }

  @override
  String get qaExpenseCategory => 'Gider kategorisi';

  @override
  String get qaIncomeCategory => 'Gelir kategorisi';

  @override
  String get qaBudgetWhichCategory => 'Hangi kategoriye bütçe?';

  @override
  String qaThisMonthSpend(Object amount) {
    return 'bu ay $amount';
  }

  @override
  String get qaNothingSpentYet => 'Henüz yok';

  @override
  String get qaAllCategoriesBudgeted => 'Her kategorinin zaten bir bütçesi var';

  @override
  String get qaSearchCleared => 'Arama temizlendi';

  @override
  String get qaClearSearch => 'Aramayı temizle';

  @override
  String get qaCategoryName => 'Kategori adı';

  @override
  String get qaIcon => 'Simge';

  @override
  String get qaColour => 'Renk';

  @override
  String get qaCreateSelect => 'Oluştur ve seç';

  @override
  String get qaAccountName => 'Hesap adı';

  @override
  String get qaAccountExists => 'Bu adda bir hesap zaten var';

  @override
  String get qaAssets => 'Varlıklar';

  @override
  String get qaLiabilities => 'Yükümlülükler';

  @override
  String get qaAmountOwed => 'Borç tutarı';

  @override
  String get qaPaymentDay => 'Ödeme günü';

  @override
  String get qaOwedHint =>
      'Borcunuzu pozitif bir sayı olarak girin — net değerinizden düşülür.';

  @override
  String get qaStartingBalanceHint =>
      'Bunu bir kez girin. Bundan sonra bakiye işlemlerinizden hesaplanır.';

  @override
  String get qaPaymentDayHint => 'Bundan kısa aylar son günlerini kullanır.';

  @override
  String get qaDiscardTitle => 'Yeni hesaptan vazgeçilsin mi?';

  @override
  String get qaDiscardBody => 'Girdiğiniz bilgiler kaydedilmeyecek.';

  @override
  String get qaDiscardConfirm => 'Vazgeç';

  @override
  String get qaMoreIcons => 'Daha fazla simge';

  @override
  String get qaChooseIcon => 'Simge seç';

  @override
  String get qaSearchIcons => 'Simge ara';

  @override
  String get ssRemoveSplit => 'Bölmeyi kaldır';

  @override
  String get ssSplitByCategory => 'Kategoriye göre böl';

  @override
  String ssTotalCovers(Object total, Object covered) {
    return 'Toplam $total · $covered';
  }

  @override
  String get ssRemoveLine => 'Satırı kaldır';

  @override
  String get ssAddCategory => 'Kategori ekle';

  @override
  String get ssRemaining => 'Kalan';

  @override
  String get ssOverBy => 'Fazla';

  @override
  String get ssSplitEvenly => 'Eşit böl';

  @override
  String get ssRestToLast => 'Kalanı sona';

  @override
  String get ssApplySplit => 'Bölmeyi uygula';

  @override
  String get ssApplySplitBlocked =>
      'Bölmeyi uygula, kalan sıfır olana kadar kullanılamaz';

  @override
  String get rsRepeat => 'Tekrar';

  @override
  String get rsHowOften => 'Ne sıklıkla';

  @override
  String get rsEveryWeek => 'Her hafta';

  @override
  String get rsEvery2Weeks => '2 haftada bir';

  @override
  String get rsEveryMonth => 'Her ay';

  @override
  String get rsEveryQuarter => 'Her üç ayda';

  @override
  String get rsEveryYear => 'Her yıl';

  @override
  String get rsShortWeekly => 'haftalık';

  @override
  String get rsShortBiweekly => '2 haftada bir';

  @override
  String get rsShortMonthly => 'aylık';

  @override
  String get rsShortQuarterly => 'üç aylık';

  @override
  String get rsShortYearly => 'yıllık';

  @override
  String rsSummary(Object cadence, Object date) {
    return '$cadence tekrarlar, $date tarihinden itibaren. Planlayıcı\'da yönetilir.';
  }

  @override
  String rsWeekly(Object weekday) {
    return 'her hafta $weekday';
  }

  @override
  String rsMonthly(Object day) {
    return 'her ayın $day';
  }

  @override
  String rsQuarterly(Object day) {
    return '$day, her 3 ayda bir';
  }

  @override
  String rsYearly(Object day, Object month) {
    return 'her yıl $day $month';
  }

  @override
  String get rsNext => 'Sonraki';

  @override
  String get rsShorterMonths => 'Kısa aylar son gününü kullanır';

  @override
  String get rsEveryDay => 'Her gün';

  @override
  String get rsWeekdays => 'Hafta içi';

  @override
  String rsNDaysWeek(int count) {
    return 'haftada $count gün';
  }

  @override
  String rsNDaysMonth(int count) {
    return 'ayda $count gün';
  }

  @override
  String rsMonthlyOnDay(Object day) {
    return 'her ayın $day';
  }

  @override
  String rsDaysJoin(Object head, Object last) {
    return '$head ve $last';
  }

  @override
  String get qaExchange => 'Döviz';

  @override
  String get qaEnterNewBalance => 'Yeni bakiyeyi girin';

  @override
  String get qaDeleteSplit => 'Bölmeyi sil';

  @override
  String get qaBooksPrefix => 'Bugün tarihli ';

  @override
  String get qaBooksSuffix =>
      ' düzeltme kaydeder. Geçmiş raporlar yeniden yazılmaz.';

  @override
  String get qaPutAsidePrefix => 'Ayırın: ';

  @override
  String qaPerMonth(Object amount) {
    return '$amount / ay';
  }

  @override
  String qaToReachMonths(Object months) {
    return ' zamanında ulaşmak için $months ay boyunca.';
  }

  @override
  String qaCreated(Object date) {
    return 'Oluşturuldu $date';
  }

  @override
  String qaEditedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · $count kez düzenlendi',
      one: ' · $count kez düzenlendi',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get a11yShown => 'gösteriliyor';

  @override
  String get a11yPartiallyShown => 'kısmen gösteriliyor';

  @override
  String get a11yHidden => 'gizli';

  @override
  String get a11yDoubleTapShow => 'Tüm hesapları göstermek için çift dokunun';

  @override
  String get a11yDoubleTapHide => 'Tüm hesapları gizlemek için çift dokunun';

  @override
  String get a11yInternalTransfer => 'iç transfer';

  @override
  String get a11yOfAssets => 'varlıkların';

  @override
  String get a11yOfLiabilities => 'yükümlülüklerin';

  @override
  String get a11yBalanceWord => 'bakiye';

  @override
  String a11yAccountBalance(Object account, Object amount) {
    return '$account bakiyesi $amount';
  }

  @override
  String get qaUnavailableNoAmount => 'tutar girilene kadar kullanılamaz';

  @override
  String get bfNetWorthFiltered => 'NET DEĞER · FİLTRELİ';

  @override
  String bfVisibleCategories(int visible, int total) {
    return '$total kategoriden $visible tanesi';
  }

  @override
  String bfVisibleAccounts(int visible, int total) {
    return '$total hesaptan $visible tanesi';
  }

  @override
  String get bdAMonth => 'aylık';

  @override
  String get bdSpent => 'harcandı';

  @override
  String bdSpentOver(String over) {
    return 'harcandı · $over aşım';
  }

  @override
  String bdDayOfMonth(int day, int total) {
    return '$total günün $day. günü';
  }

  @override
  String get bdAgainstLimit => 'LİMİTE KARŞI';

  @override
  String get mpMonth => 'AY';

  @override
  String get srDateRange => 'TARİH ARALIĞI';

  @override
  String get srCustomRange => 'ÖZEL ARALIK';

  @override
  String get calFrom => 'BAŞLANGIÇ';

  @override
  String get calTo => 'BİTİŞ';

  @override
  String plOfTarget(String target) {
    return '$target hedeften';
  }

  @override
  String get dsKeepIt => 'Kalsın';

  @override
  String get qaExampleCategory => 'örn. Market';

  @override
  String get qaExampleAccount => 'örn. Ana Hesap';

  @override
  String get qaExampleGoal => 'örn. MacBook Pro M4';

  @override
  String get goalSecSaving => 'Biriktirme';

  @override
  String get goalSecPayingOff => 'Ödeme';

  @override
  String get goalSecWaitingOn => 'Bekleniyor';

  @override
  String get goalSecEarning => 'Kazanç';

  @override
  String goalOfTotal(Object current, Object target) {
    return '$target / $current';
  }

  @override
  String goalLeftTotal(Object amount) {
    return '$amount kaldı';
  }

  @override
  String goalOwedTotal(Object amount) {
    return '$amount alacak';
  }

  @override
  String get goalSourceUnavailable => 'Kaynak kullanılamıyor';

  @override
  String get goalReached => 'Ulaşıldı';

  @override
  String goalReachedEarly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün erken ulaşıldı',
      one: '1 gün erken ulaşıldı',
    );
    return '$_temp0';
  }

  @override
  String get goalNothingYet => 'henüz yok';

  @override
  String goalAmountIn(Object amount) {
    return '$amount geldi';
  }

  @override
  String goalAmountOf(Object amount, Object whole) {
    return '$whole içinde $amount';
  }

  @override
  String goalDueLine(Object date, Object tail) {
    return 'Son $date · $tail';
  }

  @override
  String get goalFunded => 'Karşılandı';

  @override
  String goalRefill(Object amount) {
    return '$amount ekle';
  }

  @override
  String goalBehind(Object phrase) {
    return 'Geride · $phrase';
  }

  @override
  String plGoalRateSave(Object rate) {
    return 'aylık $rate biriktir';
  }

  @override
  String plGoalRatePay(Object rate) {
    return 'aylık $rate öde';
  }

  @override
  String plGoalRateCollect(Object rate) {
    return 'aylık $rate tahsil et';
  }

  @override
  String plGoalRateEarn(Object rate) {
    return 'aylık $rate kazan';
  }

  @override
  String goalAhead(Object rate) {
    return 'Önde · aylık $rate';
  }

  @override
  String goalOnTrack(Object rate) {
    return 'Yolunda · aylık $rate';
  }

  @override
  String get plGoalFilterButton => 'Hedef filtresi';

  @override
  String plGoalScopeAllSome(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hedef',
      one: '$n hedef',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m ilgi bekliyor',
      one: '$m ilgi bekliyor',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String plGoalScopeAllNone(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hedef',
      one: '$n hedef',
    );
    return '$_temp0 · tümü yolunda';
  }

  @override
  String get plGoalScopeOneAttention => '1 hedef · ilgi bekliyor';

  @override
  String get plGoalScopeOneOnTrack => '1 hedef · yolunda';

  @override
  String plGoalScopeNeeds(int m, int n) {
    return 'İlgi bekliyor · $n hedeften $m';
  }

  @override
  String plGoalScopeOnTrack(int k, int n) {
    return 'Yolunda · $n hedeften $k';
  }

  @override
  String get plGoalStatus => 'DURUM';

  @override
  String get plGoalFilterAll => 'Tümü';

  @override
  String get plGoalFilterNeeds => 'İlgi bekliyor';

  @override
  String get plGoalFilterOnTrack => 'Yolunda';

  @override
  String get plGoalArchiveNote =>
      'Ulaşılan ve vazgeçilen hedefler burada değil — Arşiv\'de.';

  @override
  String get plGoalNoneNeed => 'İlgi bekleyen hedef yok';

  @override
  String get plGoalNoneOnTrack => 'Yolunda giden hedef yok';

  @override
  String get plGoalShowAll => 'Tümünü göster';

  @override
  String plGoalRowA11y(Object option, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hedef',
      one: '$count hedef',
    );
    return '$option, $_temp0';
  }

  @override
  String goalPerMonth(Object amount) {
    return 'aylık $amount';
  }

  @override
  String get goalNewTitle => 'Yeni hedef';

  @override
  String get goalWatching => 'İzleniyor';

  @override
  String get goalSource => 'Kaynak';

  @override
  String get goalSourceLocked => 'Hesabı değiştirmek yeni bir hedef demektir.';

  @override
  String get goalSetDateHint => 'Bir tarih ya da aylık tutar girin';

  @override
  String get goalMonthly => 'Aylık';

  @override
  String get goalEnterRate => 'Aylık tutar girin';

  @override
  String get goalNoteLabel => 'Not';

  @override
  String get goalNoteHint => 'İsteğe bağlı';

  @override
  String get goalDoneOnceReached => 'Ulaşınca tamamlanır';

  @override
  String get goalDoneOnceReachedDesc =>
      'Yeniden dolduracağın fonlar için kapat';

  @override
  String get goalDeleteRowDesc => 'Hedefi siler, para kalır';

  @override
  String get goalOfWord => '/';

  @override
  String goalNewAccountNamed(Object name) {
    return 'Yeni · $name';
  }

  @override
  String get goalUntitled => 'Yeni hedef';

  @override
  String get goalChooseSource => 'Neyi izleyeceğini seç';

  @override
  String get goalTwoOnAccount =>
      'Bu hesabı izleyen başka bir hedef var. Sorun değil — ikisi de aynı bakiyeyi okur.';

  @override
  String get goalMonthlyPromptTitle => 'Aylık tutar';

  @override
  String get goalNewAccountOption => 'Yeni hesap';

  @override
  String get goalNewAccountOptionDesc =>
      'Hedeften adlandırılan bir ayrılmış hesap';

  @override
  String get goalIncomeCategories => 'Gelir kategorileri';

  @override
  String goalDeleteTitle(Object name) {
    return '\"$name\" silinsin mi?';
  }

  @override
  String get goalDeleteBody =>
      'Hedef ve geçmişi gider. Başka hiçbir şey değişmez.';

  @override
  String goalDeleteAccountStays(Object name, Object balance) {
    return '\"$name\" hesabı kalır · $balance';
  }

  @override
  String goalDeleteTxnStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count işlemi kalır',
      one: '1 işlemi kalır',
    );
    return '$_temp0';
  }

  @override
  String get goalDeleteCategoryStays => 'Gelir kategorisi ve işlemleri kalır';

  @override
  String goalOfToGo(Object target, Object remaining) {
    return '/ $target · $remaining kaldı';
  }

  @override
  String goalDaysCaption(Object pct, int elapsed, int total) {
    return '$pct · $total günün $elapsed günü';
  }

  @override
  String get goalColStarted => 'Başlangıç';

  @override
  String get goalColTarget => 'Hedef';

  @override
  String get goalColAtThisRate => 'Bu hızla';

  @override
  String get goalColReachedOn => 'Ulaşıldı';

  @override
  String get goalColStoppedOn => 'Durduruldu';

  @override
  String get goalColGotTo => 'Ulaşılan';

  @override
  String get goalColTook => 'Sürdü';

  @override
  String goalTookMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ay',
      one: '1 ay',
    );
    return '$_temp0';
  }

  @override
  String get goalTookUnderMonth => '< 1 ay';

  @override
  String goalOutcomeReachedOn(Object date) {
    return '$date tarihinde ulaşıldı';
  }

  @override
  String goalOutcomeStoppedOn(Object date) {
    return '$date tarihinde durduruldu';
  }

  @override
  String get goalDeletePermanently => 'Kalıcı olarak sil';

  @override
  String get goalReachedSummary => 'Ulaşıldı — yapılacak başka şey yok';

  @override
  String get goalNotMovingYet => 'Henüz hareket yok';

  @override
  String goalAveragingOnly(Object rate) {
    return 'Ayda ortalama $rate';
  }

  @override
  String goalAveraging(Object actual, Object needs) {
    return 'Şimdi aylık $actual · zamanında bitirmek için aylık $needs gerek';
  }

  @override
  String a11yMoneyIn(Object amount) {
    return 'Para girişi, $amount';
  }

  @override
  String a11yMoneyOut(Object amount) {
    return 'Para çıkışı, $amount';
  }

  @override
  String goalCategoryWindow(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get goalMovements => 'Hareketler';

  @override
  String goalSeeAll(int count) {
    return 'Tümünü gör ($count)';
  }

  @override
  String get goalNoteSection => 'Not';

  @override
  String get goalChanges => 'Değişiklikler';

  @override
  String get goalChangeCreated => 'Oluşturuldu';

  @override
  String get goalChangeTarget => 'Hedef';

  @override
  String get goalChangeDate => 'Hedef tarihi';

  @override
  String get bhCreated => 'Oluşturuldu';

  @override
  String get bhLimit => 'Limit';

  @override
  String get bhRollover => 'Devir';

  @override
  String get bhWarn => 'Uyarı';

  @override
  String get bhRemoved => 'Kaldırıldı';

  @override
  String get bhRestored => 'Geri yüklendi';

  @override
  String get bhCategoryArchived => 'Kategori arşivlendi';

  @override
  String get bhOn => 'Açık';

  @override
  String get bhOff => 'Kapalı';

  @override
  String bhCreatedRolloverOn(String amount) {
    return '$amount · devir açık';
  }

  @override
  String bhCreatedRolloverOff(String amount) {
    return '$amount · devir kapalı';
  }

  @override
  String get bhEmpty => 'Henüz değişiklik kaydı yok';

  @override
  String bhSince(String date) {
    return 'Değişiklikler $date tarihinden itibaren kaydediliyor';
  }

  @override
  String get bhA11yTo => '→';

  @override
  String get bhA11yIncreased => 'artırıldı';

  @override
  String get goalMenuEdit => 'Hedefi düzenle';

  @override
  String get goalStopTracking => 'İzlemeyi bırak';

  @override
  String get goalStopTrackingDesc => 'Kayıt Arşivde kalır';

  @override
  String get goalReachedAtZero => 'Ulaşıldı ve hesap boş.';

  @override
  String get goalKeepAccount => 'Hesabı tut';

  @override
  String get goalArchiveBoth => 'İkisini de arşivle';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get moreTags => 'Tags';

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
  String get tagSectionUnused => 'Kullanılmıyor';

  @override
  String get tagSectionArchived => 'Archived';

  @override
  String get tagCapReached => 'En fazla 5 etiket. Yenisi için birini kaldır.';

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

  @override
  String get tagEditTitle => 'Etiketi düzenle';

  @override
  String get tagArchiveThis => 'Etiketi arşivle';

  @override
  String tagArchiveMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count işleminde kalır ve aranabilir olmayı sürdürür',
      one: '$count işleminde kalır ve aranabilir olmayı sürdürür',
    );
    return '$_temp0';
  }

  @override
  String get tagDeleteThis => 'Etiketi sil';

  @override
  String get tagDeleteMsg =>
      'Henüz hiçbir şey onu taşımıyor, bu yüzden tamamen kaldırılabilir';

  @override
  String get tagRestoreThis => 'Etiketi geri yükle';

  @override
  String get plTitle => 'Planlayıcı';

  @override
  String get fieldSelectCategory => 'Kategori seç';

  @override
  String get actionResume => 'Sürdür';

  @override
  String get schToday => 'Bugün';

  @override
  String get schHorizonThisWeek => 'Bu hafta';

  @override
  String get schHorizonNext30 => 'Sonraki 30 gün';

  @override
  String get schHorizonThisMonth => 'Bu ay';

  @override
  String get schHorizonNext3Months => 'Sonraki 3 ay';

  @override
  String get schHorizonTitle => 'UFUK';

  @override
  String get schHorizonUntilDate => 'Bir tarihe kadar…';

  @override
  String get schHorizonFootnote =>
      'Gecikmiş ödemeler burada sayılmaz — hangi ufku seçerseniz seçin listede kalır.';

  @override
  String schUntilControl(Object date) {
    return '$date tarihine kadar';
  }

  @override
  String schCompletedIn(Object label) {
    return '$label tamamlanan';
  }

  @override
  String get schCompletedEmpty => 'Bu dönemde tamamlanan bir şey yok.';

  @override
  String get schCompletedLongerPeriod => 'Daha uzun bir dönem seçin';

  @override
  String get schUntilTitle => 'BİR TARİHE KADAR';

  @override
  String get schUntilNote => 'Bugün başlar — bitişi seçin.';

  @override
  String get schUntilPickPrompt => 'Bir bitiş tarihi seçin';

  @override
  String schUntilFromTo(Object date) {
    return 'Bugünden $date tarihine';
  }

  @override
  String schDaysChip(int count) {
    return '$count gün';
  }

  @override
  String schDaysCount(int count) {
    return '$count gün';
  }

  @override
  String schPaymentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ödeme',
      one: '$count ödeme',
    );
    return '$_temp0';
  }

  @override
  String schApplyDays(int count) {
    return 'Uygula · $count gün';
  }

  @override
  String get schLegendPayment => 'ödeme var';

  @override
  String get schLegendNegative => 'bakiye eksiye düşer';

  @override
  String get schShortLabel => 'eksik';

  @override
  String get schLeftLabel => 'kalıyor';

  @override
  String get schLeftAfter => 'taahhütlerden sonra kalan';

  @override
  String get schShortAfter => 'taahhütlerden sonra eksik';

  @override
  String schCaptionIn(Object amount) {
    return '$amount gelecek';
  }

  @override
  String schCaptionOut(Object amount) {
    return '$amount çıkacak';
  }

  @override
  String schShortToday(Object amount) {
    return 'Bugün $amount eksik';
  }

  @override
  String schShortOnDay(Object amount, Object date) {
    return '$date tarihinde $amount eksik';
  }

  @override
  String schBannerOut(int count, Object amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gecikmiş ödeme',
      one: '$count gecikmiş ödeme',
    );
    return '$_temp0 · $amount';
  }

  @override
  String schBannerIn(int count, Object amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count beklenen ödeme gelmedi',
      one: '$count beklenen ödeme gelmedi',
    );
    return '$_temp0 · $amount';
  }

  @override
  String schBannerBoth(int count, Object out, Object inAmt) {
    return '$count gecikmiş · $out çıkan, $inAmt gelen';
  }

  @override
  String get schNothingInHorizon => 'Bu aralıkta bir şey yok';

  @override
  String get schShowNext3Months => 'Sonraki 3 ayı göster ›';

  @override
  String schDaysLate(int count) {
    return '$count gün gecikmiş';
  }

  @override
  String schOverdueDays(int count) {
    return '$count gün';
  }

  @override
  String get schWontCover => 'yetmeyecek';

  @override
  String get schSemPayingOut => 'ödeniyor';

  @override
  String get schSemComingIn => 'geliyor';

  @override
  String get schSemDue => 'vade';

  @override
  String get schSemFrom => 'hesaptan';

  @override
  String get schSemInto => 'hesaba';

  @override
  String schSemRepeats(Object cadence) {
    return 'tekrarlanır $cadence';
  }

  @override
  String schItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kayıt',
      one: '$count kayıt',
    );
    return '$_temp0';
  }

  @override
  String schPausedArchiveLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duraklatılmış görev',
      one: '$count duraklatılmış görev',
    );
    return '$_temp0 · Arşiv ›';
  }

  @override
  String schCompletedFooter(Object out, Object inAmt, int count) {
    return '$out çıkan · $inAmt gelen · $count gerçekleşmedi';
  }

  @override
  String schSeeAll(int count) {
    return 'Tümünü gör ($count) ›';
  }

  @override
  String schPaidLine(Object when, Object account) {
    return '$when ödendi · $account';
  }

  @override
  String schReceivedLine(Object when, Object account) {
    return '$when alındı · $account';
  }

  @override
  String schSkippedLine(Object when) {
    return '$when atlandı';
  }

  @override
  String schCancelledLine(Object when) {
    return '$when iptal edildi';
  }

  @override
  String histLastDays(int count) {
    return 'Son $count gün';
  }

  @override
  String get histThisMonth => 'Bu ay';

  @override
  String get histLastMonth => 'Geçen ay';

  @override
  String histSinceDate(Object date) {
    return '$date tarihinden';
  }

  @override
  String get histSincePrompt => 'Bir tarihten…';

  @override
  String histFilterAll(int count) {
    return 'Tümü $count';
  }

  @override
  String histFilterPaid(int count) {
    return 'Ödendi $count';
  }

  @override
  String histFilterSkipped(int count) {
    return 'Atlandı $count';
  }

  @override
  String histFilterCancelled(int count) {
    return 'İptal $count';
  }

  @override
  String get histOut => 'ÇIKAN';

  @override
  String get histIn => 'GELEN';

  @override
  String get histDidntHappen => 'GERÇEKLEŞMEDİ';

  @override
  String get histNothingHere => 'Bu dönemde bir şey yok';

  @override
  String histPausedDeleted(int paused, int deleted) {
    return 'Bu dönemde $paused duraklatıldı, $deleted silindi · Arşiv ›';
  }

  @override
  String get mpTitlePaid => 'Ödendi olarak işaretle';

  @override
  String get mpTitleReceived => 'Alındı olarak işaretle';

  @override
  String mpSubtitle(Object title, Object date) {
    return '$title · vade $date';
  }

  @override
  String mpExpected(Object amount) {
    return 'beklenen $amount';
  }

  @override
  String get mpDate => 'Tarih';

  @override
  String get mpFrom => 'Hesaptan';

  @override
  String get mpInto => 'Hesaba';

  @override
  String get mpTo => 'Nereye';

  @override
  String get mpTransferNoCategory => 'Transfer — bütçe kategorisi yok';

  @override
  String mpRemember(Object amount) {
    return 'Bir dahaki sefer için $amount hatırla';
  }

  @override
  String mpConfirm(Object amount) {
    return 'Onayla · $amount';
  }

  @override
  String get mpChooseDestination => 'Hedef seç';

  @override
  String get mpPayOffGroup => 'BORÇ ÖDE';

  @override
  String mpRecorded(Object title) {
    return '$title Deftere kaydedildi';
  }

  @override
  String mpRecordedNext(Object title, Object date) {
    return '$title Deftere kaydedildi · sonraki $date';
  }

  @override
  String get tmEdit => 'Düzenle';

  @override
  String get tmEditSub =>
      'Tutar, tarih, tekrar, hesap, kategori, hatırlatıcı ve not.';

  @override
  String get tmSkip => 'Bunu atla';

  @override
  String tmSkipSub(Object date, Object next) {
    return '$date atlandı. Deftere bir şey yazılmaz; seri $next tarihinde devam eder.';
  }

  @override
  String get tmPause => 'Duraklat';

  @override
  String get tmPauseSub =>
      'Listeden ve tahminden çıkar. Ödeme geçmişi ve gelecek tarihler korunur — istediğiniz zaman Arşiv\'den sürdürün.';

  @override
  String get tmDelete => 'Sil';

  @override
  String tmDeleteSub(int count) {
    return 'Arşiv\'e taşınır — yanlışlıkla silmeyi geri alabilirsiniz. $count ödeme Defterde kalır. Kalıcı silme Arşiv\'den yapılır.';
  }

  @override
  String tdDeleteTitle(Object title) {
    return '$title silinsin mi?';
  }

  @override
  String get tdDeleteMsg =>
      'Arşiv\'e taşınır — yanlışlıkla silmeyi geri alabilirsiniz.';

  @override
  String tdKeptPayments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ödeme Defterde kalır',
      one: '$count ödeme Defterde kalır',
    );
    return '$_temp0';
  }

  @override
  String get tdKeptBalances => 'Bakiyeler etkilenmez';

  @override
  String get tdKeptHistory => 'Ödeme geçmişi görevle birlikte Arşiv\'de kalır';

  @override
  String get tdLostSchedule => 'Takvim ve tahminden çıkar';

  @override
  String get tdLostReminders => 'Gelecek hatırlatıcılar durur';

  @override
  String get tdDeleteConfirm => 'Sil';

  @override
  String tdPausedOn(Object date) {
    return '$date tarihinde duraklatıldı';
  }

  @override
  String get tdNext => 'SONRAKİ';

  @override
  String get tdAmount => 'TUTAR';

  @override
  String get tdPerYear => 'YILLIK';

  @override
  String get tdDue => 'VADE';

  @override
  String get tdUpcoming => 'YAKLAŞAN';

  @override
  String get tdPaymentHistory => 'ÖDEME GEÇMİŞİ';

  @override
  String get tdNoPayments => 'Henüz ödeme kaydı yok';

  @override
  String tdPaymentsSince(int count, Object month, Object total) {
    return '$month tarihinden beri $count ödeme · toplam $total';
  }

  @override
  String get tdResume => 'Sürdür';

  @override
  String get tdMarkPaid => 'Ödendi olarak işaretle';

  @override
  String get tdMarkReceived => 'Alındı olarak işaretle';

  @override
  String get tdSkipOne => 'Bunu atla';

  @override
  String get etNote => 'Not';

  @override
  String get etNoteHint => 'Not ekle';

  @override
  String get etPaidTo => 'Nereye ödenir';

  @override
  String arPausedLine(Object date, int payments, Object total) {
    return '$date duraklatıldı · $payments ödeme · $total';
  }

  @override
  String arCompletedLine(Object date, Object amount) {
    return '$date ödendi · $amount';
  }

  @override
  String arCancelledLine(Object date) {
    return '$date iptal edildi';
  }

  @override
  String arDeletedLineTask(Object date, int payments, Object total) {
    return '$date silindi · $payments ödeme · $total';
  }
}
