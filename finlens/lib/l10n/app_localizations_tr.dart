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

  @override
  String get insightTitle => 'Analiz';

  @override
  String get insightLeftOver => 'Kalan';

  @override
  String get insightNoIncome => 'Bu ay gelir kaydedilmedi';

  @override
  String insightKept(String percent, String amount) {
    return '$amount tutarın $percent kadarı korundu';
  }

  @override
  String get insightWhereItWent => 'Nereye gitti';

  @override
  String get insightGoalPerformance => 'Hedef performansı';

  @override
  String get insightReached => 'Ulaşıldı';

  @override
  String get insightSuccessRate => 'Başarı oranı';

  @override
  String get insightAvgTime => 'Ort. süre';

  @override
  String insightMonthsShort(int count) {
    return '$count ay';
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
  String get balNoAccountsYet => 'Henüz hesap yok';

  @override
  String get balNoAccountMatch => 'Aramanızla eşleşen hesap veya grup yok.';

  @override
  String get balAddFirstAccount => 'İlk hesabınızı ekleyin';

  @override
  String get balNoAccountsMessage =>
      'Hesaplarınızı ekleyin, FinLens kaydettiğiniz işlemlerden net değerinizi hesaplasın.';

  @override
  String get balAdjustFilter => 'Filtreyi ayarla';

  @override
  String get balSortTooltip => 'Sırala';

  @override
  String get balHoldToArrange => 'Düzenlemek için bir hesabı basılı tutun';

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
  String get plNoBudgetsYet => 'Henüz bütçe yok';

  @override
  String get plNoBudgetsMsg =>
      'Bir kategoriye aylık limit verin, burada görünsün.';

  @override
  String get plBudgeted => 'Bütçelenen';

  @override
  String get plNoBudgetSet => 'Bütçe ayarlanmadı';

  @override
  String get plSet => 'Ayarla';

  @override
  String get plNoGoalsYet => 'Henüz hedef yok';

  @override
  String get plNoGoalsMsg =>
      'Bir hedef belirleyin, FinLens aylık hızı hesaplasın.';

  @override
  String get plNewGoal => 'Yeni hedef';

  @override
  String get plNewTask => 'Yeni görev';

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
  String get schLater => 'Bu ayın ilerisi';

  @override
  String get plNothingScheduled => 'Planlanmış bir şey yok';

  @override
  String get plNothingSchedMsg =>
      'Planladığınız faturalar, maaşlar ve abonelikler burada görünür.';

  @override
  String get plLeftThisMonth => 'Bu ay kalan';

  @override
  String get plUnbudgeted => 'bütçesiz';

  @override
  String get plOf => '/';

  @override
  String get plBudgetWord => 'bütçe';

  @override
  String get plSavedTowardGoals => 'Hedeflere biriktirilen';

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
  String get arReachedGoals => 'Ulaşılan hedefler';

  @override
  String arReachedLine(Object date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ay',
      one: '$count ay',
    );
    return 'Ulaşıldı $date · $_temp0 sürdü';
  }

  @override
  String get arGaveUp => 'Vazgeçildi';

  @override
  String arStoppedLine(Object date, Object saved, Object target) {
    return 'Durduruldu $date · $target hedefin $saved kadarı';
  }

  @override
  String get arRemovedBudgets => 'Kaldırılan bütçeler';

  @override
  String arRemovedLine(Object date) {
    return 'Kaldırıldı $date';
  }

  @override
  String get arClearPermanently => 'Arşivi kalıcı olarak temizle';

  @override
  String get arClearTitle => 'Arşiv temizlensin mi?';

  @override
  String arClearMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arşivlenmiş öğe kalıcı olarak silinir.',
      one: '$count arşivlenmiş öğe kalıcı olarak silinir.',
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
}
