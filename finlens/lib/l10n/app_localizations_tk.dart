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

  @override
  String get insightTitle => 'Derňew';

  @override
  String get insightLeftOver => 'Galan';

  @override
  String get insightNoIncome => 'Bu aý girdeji hasaba alynmady';

  @override
  String insightKept(String percent, String amount) {
    return '$amount mukdaryň $percent bölegi saklandy';
  }

  @override
  String get insightWhereItWent => 'Nirä gitdi';

  @override
  String get insightGoalPerformance => 'Maksat netijeliligi';

  @override
  String get insightReached => 'Ýetildi';

  @override
  String get insightSuccessRate => 'Üstünlik derejesi';

  @override
  String get insightAvgTime => 'Ort. wagt';

  @override
  String insightMonthsShort(int count) {
    return '$count aý';
  }

  @override
  String get actionCancel => 'Ýatyr';

  @override
  String get actionSave => 'Ýatda sakla';

  @override
  String get actionDelete => 'Poz';

  @override
  String get actionEdit => 'Üýtget';

  @override
  String get actionCopy => 'Nusgala';

  @override
  String get actionUndo => 'Yza gaýtar';

  @override
  String get actionApply => 'Ulan';

  @override
  String get actionSearch => 'Gözle';

  @override
  String get actionMoveUp => 'Ýokary';

  @override
  String get actionMoveDown => 'Aşak';

  @override
  String get actionCollapseAll => 'Ählisini ýygna';

  @override
  String get actionExpandAll => 'Ählisini aç';

  @override
  String get actionReset => 'Täzeden';

  @override
  String get balSearchAccounts => 'Hasap gözle';

  @override
  String get balNoResults => 'Netije ýok';

  @override
  String get balNoAccountsYet => 'Entek hasap ýok';

  @override
  String get balNoAccountMatch =>
      'Gözlegiňize gabat gelýän hasap ýa-da topar ýok.';

  @override
  String get balAddFirstAccount => 'Ilkinji hasabyňyzy goşuň';

  @override
  String get balNoAccountsMessage =>
      'Hasaplaryňyzy goşuň, FinLens ýazgy eden amallaryňyzdan arassa baýlygyňyzy hasaplar.';

  @override
  String get balAdjustFilter => 'Süzgüji sazla';

  @override
  String get balSortTooltip => 'Tertiple';

  @override
  String get balHoldToArrange => 'Tertiplemek üçin hasaby basyp saklaň';

  @override
  String get balPressHoldMove => 'Süýşürmek üçin hasaby basyp saklaň';

  @override
  String get balFilterCategories => 'Kategoriýalary süz';

  @override
  String get balNoVisibleCategories => 'Görünýän kategoriýa ýok';

  @override
  String balSeeAll(int count) {
    return 'Ählisini gör $count  ›';
  }

  @override
  String transferFromTo(String from, String to) {
    return '$from hasabyndan $to hasabyna geçirim';
  }

  @override
  String get eaName => 'Ady';

  @override
  String get eaGroup => 'Topar';

  @override
  String get eaCurrency => 'Walýuta';

  @override
  String get eaStartingBalance => 'Başlangyç balans';

  @override
  String get eaStartingBalanceLock =>
      'Balansy düzetmek üçin oňa derek amal goşuň';

  @override
  String get eaCreditLimit => 'Karz çägi';

  @override
  String get eaStatementDay => 'Hasabat güni';

  @override
  String get eaPaymentDue => 'Töleg möhleti';

  @override
  String get eaNotSet => 'Bellenmedik';

  @override
  String get eaHideFromBalance => 'Balansdan gizle';

  @override
  String get eaHideDesc => 'Jemlerde galýar, sanawlardan ýitýär';

  @override
  String get eaRemoveThisAccount => 'Bu hasaby aýyr';

  @override
  String get eaRemovePermanent => 'Bu hasaby hemişelik pozýar';

  @override
  String get eaRemoveHasHistory => 'Taryhy bar — pozulman, arhiwlenýär';

  @override
  String eaRemoveTitle(String name) {
    return '$name aýyrylsynmy?';
  }

  @override
  String get eaArchivedMsg =>
      'Bu hasabyň taryhy bar, şonuň üçin pozulman arhiwlenýär.';

  @override
  String get eaDeleteMsg => 'Bu hasabyň amaly ýok we doly pozulyp bilner.';

  @override
  String eaTxnStays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amalyňyz Hasapda üýtgewsiz galýar.',
      one: '$count amalyňyz Hasapda üýtgewsiz galýar.',
    );
    return '$_temp0';
  }

  @override
  String eaGroupDropsBy(String group, String amount) {
    return '$group $amount azalýar.';
  }

  @override
  String get eaDisappearsPicker => 'Ol her hasap saýlaýjydan ýitýär.';

  @override
  String get eaCannotUndo => 'Muny yzyna gaýtaryp bolmaýar.';

  @override
  String get eaArchiveAccount => 'Hasaby arhiwle';

  @override
  String get eaRemoveAccount => 'Hasaby aýyr';

  @override
  String get eaEditAccount => 'Hasaby üýtget';

  @override
  String balFilterActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Işjeň, $count element gizli',
      one: 'Işjeň, $count element gizli',
    );
    return '$_temp0';
  }

  @override
  String get balFilterOff => 'Öçük';

  @override
  String get balMoved => 'Süýşürildi';

  @override
  String get balMovedCustom => 'Süýşürildi · Elde tertipde';

  @override
  String balTotalOf(String name) {
    return 'Jemi: $name';
  }

  @override
  String balUtilization(String percent) {
    return 'Ulanylyşy: $percent';
  }

  @override
  String get balOverdue => 'Möhleti geçdi';

  @override
  String balDue(String when) {
    return 'Töleg $when';
  }

  @override
  String balNextPayment(String date) {
    return 'Indiki töleg: $date';
  }

  @override
  String get actionDone => 'Taýýar';

  @override
  String get actionBack => 'Yza';

  @override
  String get filterTitle => 'Süzgüç';

  @override
  String get sheetApply => 'Ulan';

  @override
  String get sheetToday => 'Şu gün';

  @override
  String balNoBetween(String subject, String range) {
    return '$range aralygynda $subject ýok';
  }

  @override
  String get freqLessThanMonthly => 'Aýda bir gezekden az';

  @override
  String get freqAbout => 'Takmynan ';

  @override
  String freqTimesAMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' gezek aýda',
      one: ' gezek aýda',
    );
    return '$_temp0';
  }

  @override
  String txnDeleteEntryTitle(String type) {
    return 'Bu $type pozulsynmy?';
  }

  @override
  String get txnDeleteEntryMessage =>
      'Bu ýazgy hemişelik pozulýar we aşakdaky balanslar öňki ýagdaýyna dolanýar.';

  @override
  String get txnDeleteNothingElse => 'Hasabyňyzda başga hiç zat üýtgemeýär.';

  @override
  String get txnDeleteEntryConfirm => 'Ýazgyny poz';

  @override
  String get freqLastOne => ' · soňkusy ';

  @override
  String txnBudgetImpact(Object name, Object before, Object after) {
    return '$name býujeti $before → $after';
  }
}
