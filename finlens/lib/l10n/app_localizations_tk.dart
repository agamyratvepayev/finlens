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

  @override
  String get txnRevaluation => 'Gaýtadan bahalandyrma';

  @override
  String get txnTransferOut => 'Çykýan geçirim';

  @override
  String get txnTransferIn => 'Gelýän geçirim';

  @override
  String get plTabBudgets => 'Býujetler';

  @override
  String get plTabGoals => 'Maksatlar';

  @override
  String get plTabSchedule => 'Meýilnama';

  @override
  String get plNoBudgetsYet => 'Entek býujet ýok';

  @override
  String get plNoBudgetsMsg =>
      'Kategoriýa aýlyk çäk beriň, ol şu ýerde görüner.';

  @override
  String get plBudgeted => 'Býujetlenen';

  @override
  String get plNoBudgetSet => 'Býujet bellenmedik';

  @override
  String get plSet => 'Belle';

  @override
  String get plNoGoalsYet => 'Entek maksat ýok';

  @override
  String get plNoGoalsMsg => 'Maksat belläň, FinLens aýlyk depgini hasaplar.';

  @override
  String get plNewGoal => 'Täze maksat';

  @override
  String get plNewTask => 'Täze tabşyryk';

  @override
  String get plCompleteReady => 'Taýýar · arhiwe geçirmäge taýýar';

  @override
  String get plNoTargetDate => 'Sene bellenmedik';

  @override
  String get plMoNeeded => '/aýda gerek';

  @override
  String get plComingIn => 'Gelýän';

  @override
  String get plGoingOut => 'Çykýan';

  @override
  String get schOverdue => 'Möhleti geçdi';

  @override
  String get schThisWeek => 'Şu hepde';

  @override
  String get schLater => 'Şu aýyň soňunda';

  @override
  String get plNothingScheduled => 'Meýilnama ýok';

  @override
  String get plNothingSchedMsg =>
      'Meýilleşdiren hasaplaryňyz, aýlyklaryňyz we abunalaryňyz şu ýerde görüner.';

  @override
  String get plLeftThisMonth => 'Şu aý galan';

  @override
  String get plUnbudgeted => 'býujetsiz';

  @override
  String get plOf => '/';

  @override
  String get plBudgetWord => 'býujet';

  @override
  String get plSavedTowardGoals => 'Maksatlara toplanan';

  @override
  String get plPace => 'Depgin';

  @override
  String plPaymentsOverdue(int count, Object amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count töleg gijä galdy',
      one: '$count töleg gijä galdy',
    );
    return '$_temp0 · $amount';
  }

  @override
  String get fieldCategory => 'Kategoriýa';

  @override
  String get fieldSelectAccount => 'Hasap saýlaň';

  @override
  String get fieldDirection => 'Ugry';

  @override
  String get actionUse => 'Ulan';

  @override
  String get actionRestore => 'Dikelt';

  @override
  String countMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aý',
      one: '$count aý',
    );
    return '$_temp0';
  }

  @override
  String get ebTitle => 'Býujeti üýtget';

  @override
  String get ebMonthlyLimit => 'Aýlyk çäk';

  @override
  String get ebRollOver => 'Galanyny geçir';

  @override
  String get ebRollOverDesc => 'Galanyny indiki aýa goş';

  @override
  String get ebWarnAt => 'Şu ýerde duýdur';

  @override
  String get ebRemoveBudget => 'Býujeti aýyr';

  @override
  String ebAverage(Object average, Object suggestion) {
    return 'Ortaça $average. $suggestion synanyşyňmy?';
  }

  @override
  String ebRemoveTitle(Object name) {
    return '$name býujeti aýyrylsynmy?';
  }

  @override
  String get ebRemoveMsg => 'Bu kategoriýa üçin çäk yzarlamany bes edersiňiz.';

  @override
  String ebCategoryStays(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amalyňyz üýtgewsiz galýar.',
      one: '$count amalyňyz üýtgewsiz galýar.',
    );
    return '$name kategoriýasy galýar. $_temp0';
  }

  @override
  String get ebWarningsDisappear =>
      'Bu kategoriýa üçin duýduryşlar we öňegidiş zolaklary ýitýär.';

  @override
  String ebTotalDrops(Object from, Object to) {
    return 'Umumy aýlyk býujet $from bahadan $to baha çenli azalýar.';
  }

  @override
  String get egTitle => 'Maksady üýtget';

  @override
  String get egGoalName => 'Maksadyň ady';

  @override
  String get egType => 'Görnüşi';

  @override
  String get egTargetAmount => 'Maksat mukdary';

  @override
  String get egTargetDate => 'Maksat senesi';

  @override
  String get egMoneyKeptIn => 'Pul saklanýan ýer';

  @override
  String get egAutoContribute => 'Awtomatiki goşant';

  @override
  String get egAutoContributeDesc => 'Bu maksada aýlyk geçirim döredýär';

  @override
  String get egMonthlyContribution => 'Aýlyk goşant';

  @override
  String get egMarkReached => 'Ýetildi diýip belle';

  @override
  String get egMarkReachedDesc => 'Pul harçlandy, maksat tamamlandy';

  @override
  String get egGiveUp => 'Häzirlikçe ýüz öwür';

  @override
  String get egDeleteGoal => 'Maksady poz';

  @override
  String get egDeleteGoalDesc => 'Asla bolmadyk ýaly';

  @override
  String egMarkReachedTitle(Object name) {
    return '$name ýetildi diýip bellensinmi?';
  }

  @override
  String get egMarkReachedMsg =>
      'Gutlaýarys — maksat üstünlikli hökmünde arhiwe geçýär.';

  @override
  String egReachedAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aý',
      one: '$count aý',
    );
    return '$_temp0 soň ýetildi diýip bellendi, maksat statistikaňyza goşulýar.';
  }

  @override
  String get egPastTxnStay => 'Geçmiş amallar Hasapda galýar.';

  @override
  String get egLeavesStops =>
      'Maksatlar sanawyndan çykýar we yzarlama bes edilýär.';

  @override
  String get egAutoStops => 'Aýlyk awtomatiki goşant bes edilýär.';

  @override
  String get egNotYet => 'Entek däl';

  @override
  String egGiveUpTitle(Object name) {
    return '$name maksadyndan ýüz öwrülsinmi?';
  }

  @override
  String get egGiveUpMsg =>
      'Yzarlama bes edilýär, ýöne aýyran puluňyz ýerinde galýar.';

  @override
  String egSavedStaysIn(Object amount, Object account) {
    return '$amount $account hasabynda galýar.';
  }

  @override
  String get egYourAccount => 'hasabyňyzda';

  @override
  String get egRestoreLater => 'Soň Arhiwden dikeldip bilersiňiz.';

  @override
  String get egLeavesList => 'Maksatlar sanawyndan çykýar.';

  @override
  String egDeleteTitle(Object name) {
    return '$name pozulsynmy?';
  }

  @override
  String get egDeleteMsg =>
      'Muny diňe maksat ýalňyşlyk bilen döredilen bolsa ulanyň — taryhyňyzda yz galdyrmaýar.';

  @override
  String get egBalancesUnchanged => 'Hasap balanslaryňyz üýtgemeýär.';

  @override
  String get egNotInArchive => 'Ol Arhiwde görünmeýär.';

  @override
  String get egExcludedStats =>
      'Ol maksat netijelilik statistikasyndan aýrylýar.';

  @override
  String get egRecurringCancelled => 'Gaýtalanýan geçirim düzgüni ýatyrylýar.';

  @override
  String egPerMonthTrack(Object amount) {
    return 'wagtynda ýetişmek üçin $amount/aýda';
  }

  @override
  String egAutoContributeOn(Object amount, Object day) {
    return 'her aýyň $day $amount';
  }

  @override
  String egKeepsStops(Object amount) {
    return '$amount saklanýar, yzarlama bes edilýär';
  }

  @override
  String get egSaved => 'toplandy';

  @override
  String get egToGo => 'galdy';

  @override
  String get ebWhatSpent => 'Hakykatda näçe harçladyňyz';

  @override
  String get ebSpent => 'harçlandy';

  @override
  String get etTitle => 'Tabşyrygy üýtget';

  @override
  String get etTaskTitle => 'Tabşyrygyň ady';

  @override
  String get etPaidFrom => 'Töleg çeşmesi';

  @override
  String get etPaidInto => 'Töleg nyşany';

  @override
  String get etLinkedAccount => 'Baglanan hasap';

  @override
  String get etPayOut => 'Çykdajy −';

  @override
  String get etPayIn => 'Girdeji +';

  @override
  String get etExpectedAmount => 'Garaşylýan mukdar';

  @override
  String get etCategoryHint => '\"Tölenen diýip belle\" nirä ýazýar';

  @override
  String get etNextDue => 'Indiki möhlet';

  @override
  String get etRepeats => 'Gaýtalama';

  @override
  String get etOneOff => 'Bir gezeklik tabşyryk';

  @override
  String get etRemindMe => 'Ýatladyň';

  @override
  String etRemindBefore(Object days, Object time) {
    return '$days gün öň, $time';
  }

  @override
  String get etMarkPaid => 'Tölenen diýip belle';

  @override
  String get etMarkPaidExpense => 'Hasapda çykdajy döredýär';

  @override
  String get etMarkPaidIncome => 'Hasapda girdeji döredýär';

  @override
  String get etSkipThisMonth => 'Bu aýy geç';

  @override
  String etSeriesContinues(Object month) {
    return 'Seriýa $month aýynda dowam eder';
  }

  @override
  String get etDeleteWholeSeries => 'Ähli seriýany poz';

  @override
  String etAllFutureReminders(Object title) {
    return 'Geljekki ähli $title ýatladyşlary';
  }

  @override
  String etSkippedNext(Object date) {
    return 'Geçildi · indiki $date';
  }

  @override
  String etDeleteOnly(Object date) {
    return 'Diňe $date poz';
  }

  @override
  String etDeleteOnlyTitle(Object date) {
    return 'Diňe $date pozulsynmy?';
  }

  @override
  String get etJustThisOne => 'Diňe bu gaýtalanma aýrylýar.';

  @override
  String get etOneOffRemoved => 'Bu bir gezeklik tabşyryk aýrylýar.';

  @override
  String etSeriesContinuesOn(Object date) {
    return 'Seriýa $date dowam eder.';
  }

  @override
  String get etNoLedgerEntry => 'Hasap ýazgysy döredilmeýär we aýrylmaýar.';

  @override
  String get etLedgerUntouched => 'Hasabyňyz üýtgemeýär.';

  @override
  String etDisappears(Object date) {
    return '$date meýilnamaňyzdan ýitýär.';
  }

  @override
  String etDeleteDate(Object date) {
    return '$date poz';
  }

  @override
  String etDeleteSeriesTitle(Object title) {
    return 'Ähli $title seriýasy pozulsynmy?';
  }

  @override
  String get etDeleteSeriesMsg =>
      'Diňe indiki däl, geljekki ähli gaýtalanmalar aýrylýar.';

  @override
  String get etPaymentsStay => 'Eýýäm ýazan tölegleriňiz Hasapda galýar.';

  @override
  String get etAllRemindersCancelled => 'Geljekki ähli ýatladyşlar ýatyrylýar.';

  @override
  String etOutgoingsDrop(Object amount) {
    return 'Aýlyk çykdajylaryňyz $amount azalýar.';
  }

  @override
  String get etDeleteSeries => 'Seriýany poz';

  @override
  String etRecordedInLedger(Object title) {
    return '$title Hasaba ýazyldy';
  }

  @override
  String etRepeatsCadence(Object cadence) {
    return 'Gaýtalama: $cadence';
  }

  @override
  String bdAveraging(Object avg, Object limit, Object count) {
    return 'Ortaça $avg · 6 aýyň $count aýynda $limit çäginden ýokary';
  }

  @override
  String get bdNothingSpent => 'Bu aý bu ýerde hiç zat harçlanmady.';

  @override
  String get arEmpty => 'Arhiw boş';

  @override
  String get arEmptyMsg =>
      'Ýeten ýa-da ýüz öwren maksatlaryňyz we aýran býujetleriňiz şu ýerde saklanýar.';

  @override
  String get arFootnote =>
      'Arhiwlenen elementler Meýilnamada görünmeýär we jemleriňize täsir etmeýär. Geçmiş amallary Hasapda galýar.';

  @override
  String get arReachedGoals => 'Ýetilen maksatlar';

  @override
  String arReachedLine(Object date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aý',
      one: '$count aý',
    );
    return 'Ýetildi $date · $_temp0 gerek boldy';
  }

  @override
  String get arGaveUp => 'Ýüz öwrüldi';

  @override
  String arStoppedLine(Object date, Object saved, Object target) {
    return 'Duruzyldy $date · $target maksadyň $saved';
  }

  @override
  String get arRemovedBudgets => 'Aýrylan býujetler';

  @override
  String arRemovedLine(Object date) {
    return 'Aýryldy $date';
  }

  @override
  String get arClearPermanently => 'Arhiwi hemişelik arassala';

  @override
  String get arClearTitle => 'Arhiw arassalansynmy?';

  @override
  String arClearMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arhiw elementi hemişelik pozulýar.',
      one: '$count arhiw elementi hemişelik pozulýar.',
    );
    return '$_temp0';
  }

  @override
  String get arTxnStay => 'Ähli degişli amallar Hasapda galýar.';

  @override
  String get arBalancesUnaffected => 'Hasap balanslaryna täsir etmeýär.';

  @override
  String get arRestoreImpossible => 'Dikeltmek indi mümkin däl.';

  @override
  String get arStatsDisappear =>
      'Ýetilen maksat taryhy statistikaňyzdan ýitýär.';

  @override
  String get arClearArchive => 'Arhiwi arassala';

  @override
  String get stateOn => 'Açyk';

  @override
  String get stateOff => 'Öçük';

  @override
  String get filterAll => 'Ählisi';

  @override
  String get actionClose => 'Ýap';

  @override
  String get ldgShowDescriptions => 'Düşündirişleri görkez';

  @override
  String get ldgSortTransactions => 'Amallary tertiple';

  @override
  String get ldgFilterTransactions => 'Amallary süz';

  @override
  String get ldgSearchTransactions => 'Amallary gözle';

  @override
  String ldgFilterActive(Object shown, Object total) {
    return 'Işjeň, $total amalyň $shown görkezilýär';
  }

  @override
  String ldgNoResultsFor(Object query) {
    return '\"$query\" boýunça netije ýok';
  }

  @override
  String get ldgNoMatchFilter => 'Süzgüçiňize gabat gelýän amal ýok';

  @override
  String get ldgClearFilter => 'Süzgüji arassala';

  @override
  String get ldgNothingHere => 'Bu ýerde entek hiç zat ýok';

  @override
  String get ldgNothingHereMsg => 'Goşan ýazgylaryňyz şu sanawda görüner.';

  @override
  String get ldgAddEntry => 'Ýazgy goş';

  @override
  String get ldgCategories => 'Kategoriýalar';

  @override
  String get ldgAccounts => 'Hasaplar';

  @override
  String get ldgTags => 'Bellikler';

  @override
  String get ldgType => 'Görnüş';

  @override
  String get ldgDirection => 'Ugry';

  @override
  String get ldgAmount => 'Möçber';

  @override
  String get ldgAny => 'Islendik';

  @override
  String get ldgClearCustomRange => 'Öz aralygyny arassala';

  @override
  String ldgSpentOf(Object expense, Object income) {
    return '$income mukdaryň $expense harçlandy';
  }

  @override
  String get ldgOut => 'Çykýan';

  @override
  String get ldgLeft => 'Galan';

  @override
  String get ldgChangePeriod => 'Döwri üýtget';

  @override
  String get ldgBalance => 'Balans';

  @override
  String get ldgTransactionDeleted => 'Amal pozuldy';

  @override
  String get ldgNoTransactions => 'Amal ýok';

  @override
  String get ldgPeriod => 'Döwür';

  @override
  String get ldgShow => 'Görkez';

  @override
  String get ldgCustomRange => 'Öz aralygy';

  @override
  String get ldgPreviousYear => 'Öňki ýyl';

  @override
  String get ldgNextYear => 'Indiki ýyl';

  @override
  String ldgShowCountOf(Object count, Object total) {
    return '$total amalyň $count görkez';
  }

  @override
  String ldgShowAll(Object count) {
    return 'Ählisini görkez $count';
  }

  @override
  String ldgPlusMore(Object count) {
    return '+$count ýene';
  }

  @override
  String get ldgNetIn => 'Arassa giriş';

  @override
  String get ldgNetOut => 'Arassa çykyş';

  @override
  String get ldgMoneyIn => 'Gelýän';

  @override
  String get ldgMoneyOut => 'Çykýan';

  @override
  String get ldgNoCash => 'Nagt ýok';

  @override
  String get ldgIn => 'Gelen';

  @override
  String ldgRangeHint(Object min, Object max) {
    return 'Bu ýerdäki amallar $min – $max aralygynda';
  }

  @override
  String ldgSearchWithin(Object labels) {
    return '$labels içinde gözle';
  }

  @override
  String ldgSelectAllIn(Object section) {
    return '$section içinde ählisini saýla';
  }

  @override
  String ldgClearSelection(Object section) {
    return '$section saýlawyny arassala';
  }

  @override
  String get ldgSelectAll => 'Ählisini saýla';

  @override
  String get ldgClear => 'Arassala';

  @override
  String get ldgMin => 'Min';

  @override
  String get ldgMax => 'Maks';

  @override
  String get ldgResetFilter => 'Süzgüji täzele';

  @override
  String get tdFrom => 'Nireden';

  @override
  String get tdTo => 'Nirä';

  @override
  String get tdDeletedAccount => 'Pozulan hasap';

  @override
  String get tdRate => 'Kurs';

  @override
  String get tdNote => 'Bellik';

  @override
  String get tdNetWorth => 'Arassa baýlyk';

  @override
  String get tdUnchanged => 'Üýtgemedik';

  @override
  String get qaAmount => 'Möçber';

  @override
  String get qaDue => 'Möhlet';

  @override
  String get qaNewBalance => 'Täze balans';

  @override
  String get qaTarget => 'Maksat';

  @override
  String get qaDate => 'Sene';

  @override
  String get qaTag => 'Bellik';

  @override
  String get qaNone => 'Ýok';

  @override
  String get qaNote => 'Bellik';

  @override
  String get qaAddNote => 'Bellik goş';

  @override
  String get qaOptional => 'Islege bagly';

  @override
  String get qaSplit => 'Böl';

  @override
  String qaSplitCategories(Object count) {
    return '$count kategoriýa';
  }

  @override
  String get qaGroupRequired => 'Hökman';

  @override
  String get qaGroupOptional => 'Islege bagly';

  @override
  String get qaFrom => 'Nireden';

  @override
  String get qaTo => 'Nirä';

  @override
  String get qaChooseAccount => 'Hasap saýla';

  @override
  String get qaChooseCategory => 'Kategoriýa saýla';

  @override
  String get qaChooseSource => 'Çeşme saýla';

  @override
  String get qaPayFrom => 'Şundan töle';

  @override
  String get qaDepositInto => 'Şuňa geçir';

  @override
  String get qaTransferFrom => 'Şundan geçirim';

  @override
  String get qaTransferTo => 'Şuňa geçirim';

  @override
  String get qaRate => 'Kurs';

  @override
  String get qaReceives => 'Alýar';

  @override
  String get qaFee => 'Töleg';

  @override
  String get qaAccount => 'Hasap';

  @override
  String get qaRevalueAccount => 'Hasaby gaýtadan bahala';

  @override
  String get qaCurrent => 'Häzirki';

  @override
  String get qaDifference => 'Tapawut';

  @override
  String get qaReason => 'Sebäp';

  @override
  String get qaAdjustment => 'Düzediş';

  @override
  String get qaBalanceUnchanged => 'Balans üýtgemedik';

  @override
  String get qaName => 'Ady';

  @override
  String get qaNameYourGoal => 'Maksadyňyzy atlandyryň';

  @override
  String get qaGoalNameHint => 'mysal üçin MacBook Pro M4';

  @override
  String get qaSetDate => 'Sene belle';

  @override
  String get qaFundingAccount => 'Doldurym hasaby';

  @override
  String get qaStartingAmount => 'Başlangyç mukdar';

  @override
  String get qaIconColour => 'Nyşan we reňk';

  @override
  String get qaTapToChange => 'Üýtgetmek üçin basyň';

  @override
  String get qaAutoFund => 'Awtomatiki doldur';

  @override
  String get qaRemind => 'Ýatladyş';

  @override
  String get qaTaskPlaceholder => 'Näme etmeli?';

  @override
  String get qaExchangeRate => 'Alyş-çalyş kursy';

  @override
  String qaFxRate(Object from, Object to) {
    return '1 $from = ? $to';
  }

  @override
  String get qaWhatAdding => 'Näme goşýarsyňyz?';

  @override
  String get qaDeleteEntry => 'Bu ýazgyny poz';

  @override
  String get qaBalanceAdjustment => 'Balans düzedişi';

  @override
  String get qaRecurring => 'Gaýtalanýan';

  @override
  String qaLinkedSplit(Object count) {
    return 'Bu $count baglanan bölünme amalynyň biri.';
  }

  @override
  String qaDeleteAll(Object count) {
    return 'Ählisini poz $count';
  }

  @override
  String get qaDeleteJustLine => 'Diňe bu setiri poz';

  @override
  String get qaSaveExpense => 'Çykdajyny sakla';

  @override
  String get qaSaveIncome => 'Girdejini sakla';

  @override
  String get qaSaveTransfer => 'Geçirimi sakla';

  @override
  String get qaSaveAdjustment => 'Düzedişi sakla';

  @override
  String get qaCreateGoal => 'Maksat döret';

  @override
  String get qaCreateTask => 'Tabşyryk döret';

  @override
  String qaSaved(Object type) {
    return '$type saklandy';
  }

  @override
  String get qaBlockAmount => 'Möçber giriziň';

  @override
  String get qaBlockAccount => 'Hasap saýlaň';

  @override
  String get qaBlockCategory => 'Kategoriýa saýlaň';

  @override
  String get qaBlockSource => 'Çeşme saýlaň';

  @override
  String get qaBlockSplit => 'Bölünmäni deňleşdiriň';

  @override
  String get qaBlockSourceAccount => 'Çeşme hasaby saýlaň';

  @override
  String get qaBlockDestination => 'Nyşan saýlaň';

  @override
  String get qaBlockBalanceUnchanged => 'Balans üýtgemedik';

  @override
  String get qaBlockNameGoal => 'Maksadyňyzy atlandyryň';

  @override
  String get qaBlockSetTarget => 'Maksat belläň';

  @override
  String get qaBlockSetTargetDate => 'Maksat senesini belläň';

  @override
  String get qaBlockFunding => 'Doldurym hasabyny saýlaň';

  @override
  String get qaBlockNameTask => 'Tabşyrygy atlandyryň';

  @override
  String get qaBlockDueDate => 'Möhlet belläň';

  @override
  String get qaNewAccount => 'Täze hasap';

  @override
  String get qaNewCategory => 'Täze kategoriýa';

  @override
  String get qaNewShort => 'Täze';

  @override
  String get qaSelectAccount => 'Hasap saýlaň';

  @override
  String get qaSearchAccounts => 'Hasap gözle';

  @override
  String get qaSearchCategories => 'Kategoriýa gözle';

  @override
  String qaNoAccountMatch(Object query) {
    return '\"$query\" boýunça hasap ýok.';
  }

  @override
  String qaNoCategoryMatch(Object query) {
    return '\"$query\" boýunça kategoriýa ýok.';
  }

  @override
  String get qaExpenseCategory => 'Çykdajy kategoriýasy';

  @override
  String get qaIncomeCategory => 'Girdeji kategoriýasy';

  @override
  String get qaSearchCleared => 'Gözleg arassalandy';

  @override
  String get qaClearSearch => 'Gözlegi arassala';

  @override
  String get qaCategoryName => 'Kategoriýanyň ady';

  @override
  String get qaIcon => 'Nyşan';

  @override
  String get qaColour => 'Reňk';

  @override
  String get qaMonthlyBudget => 'Aýlyk býujet (islege bagly)';

  @override
  String get qaCategoryPlannerNote =>
      'Bu kategoriýa Meýilnama → Çykdajy býujetinde-de görüner, ol ýerde çykdajyny yzarlap bilersiňiz.';

  @override
  String get qaCreateSelect => 'Döret we saýla';

  @override
  String get qaAccountName => 'Hasabyň ady';

  @override
  String get qaAccountExists => 'Bu atly hasap eýýäm bar';

  @override
  String get qaAssets => 'Aktiwler';

  @override
  String get qaLiabilities => 'Borçlar';

  @override
  String get qaAmountOwed => 'Bergi mukdary';

  @override
  String get qaPaymentDay => 'Töleg güni';

  @override
  String get qaOwedHint =>
      'Bergiňizi položitel san hökmünde giriziň — ol arassa baýlygyňyzy azaldýar.';

  @override
  String get qaStartingBalanceHint =>
      'Muny bir gezek giriziň. Mundan soň balans amallaryňyzdan hasaplanýar.';

  @override
  String get qaPaymentDayHint => 'Bundan gysga aýlar öz soňky gününi ulanýar.';

  @override
  String get qaMoreIcons => 'Köp nyşan';

  @override
  String get qaChooseIcon => 'Nyşan saýla';

  @override
  String get qaSearchIcons => 'Nyşan gözle';

  @override
  String get qaResults => 'Netijeler';

  @override
  String get qaNoIconsMatch => 'Gabat gelýän nyşan ýok';

  @override
  String get ssRemoveSplit => 'Bölünmäni aýyr';

  @override
  String get ssSplitByCategory => 'Kategoriýa boýunça böl';

  @override
  String ssTotalCovers(Object total, Object covered) {
    return 'Jemi $total · $covered';
  }

  @override
  String get ssRemoveLine => 'Setiri aýyr';

  @override
  String get ssAddCategory => 'Kategoriýa goş';

  @override
  String get ssRemaining => 'Galan';

  @override
  String get ssSplitEvenly => 'Deň böl';

  @override
  String get ssRestToLast => 'Galany soňkusyna';

  @override
  String get ssApplySplit => 'Bölünmäni ulan';

  @override
  String get ssApplySplitBlocked =>
      'Bölünmäni ulanmak, galan nol bolýança elýeterli däl';

  @override
  String get rsRepeat => 'Gaýtala';

  @override
  String get rsHowOften => 'Näçe ýygy';

  @override
  String get rsEveryWeek => 'Her hepde';

  @override
  String get rsEveryMonth => 'Her aý';

  @override
  String get rsEveryQuarter => 'Her çärýek';

  @override
  String get rsEveryYear => 'Her ýyl';

  @override
  String rsSummary(Object cadence, Object date) {
    return '$cadence gaýtalanýar, $date-den başlap. Meýilnamada dolandyrylýar.';
  }

  @override
  String rsWeekly(Object weekday) {
    return 'her hepde $weekday';
  }

  @override
  String rsMonthly(Object day) {
    return 'her aýyň $day';
  }

  @override
  String rsQuarterly(Object day) {
    return '$day, her 3 aýda';
  }

  @override
  String rsYearly(Object day, Object month) {
    return 'her ýyl $day $month';
  }

  @override
  String get qaExchange => 'Alyş-çalyş';

  @override
  String get qaEnterNewBalance => 'Täze balansy giriziň';

  @override
  String get qaDeleteSplit => 'Bölünmäni poz';

  @override
  String get qaBooksPrefix => 'Şu gün senesi bilen ';

  @override
  String get qaBooksSuffix =>
      ' düzediş ýazýar. Geçmiş hasabatlar täzeden ýazylmaýar.';

  @override
  String get qaPutAsidePrefix => 'Aýryň: ';

  @override
  String qaPerMonth(Object amount) {
    return '$amount / aý';
  }

  @override
  String qaToReachMonths(Object months) {
    return ' wagtynda ýetmek üçin $months aý dowamynda.';
  }

  @override
  String qaCreated(Object date) {
    return 'Döredildi $date';
  }

  @override
  String qaEditedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · $count gezek üýtgedildi',
      one: ' · $count gezek üýtgedildi',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get a11yShown => 'görkezilýär';

  @override
  String get a11yPartiallyShown => 'bölekleýin görkezilýär';

  @override
  String get a11yHidden => 'gizlenen';

  @override
  String get a11yDoubleTapShow =>
      'Ähli hasaplary görkezmek üçin iki gezek basyň';

  @override
  String get a11yDoubleTapHide =>
      'Ähli hasaplary gizlemek üçin iki gezek basyň';

  @override
  String get a11yInternalTransfer => 'içki geçirim';

  @override
  String get a11yOfAssets => 'aktiwlerden';

  @override
  String get a11yOfLiabilities => 'borçlardan';

  @override
  String get a11yBalanceWord => 'balans';

  @override
  String a11yAccountBalance(Object account, Object amount) {
    return '$account balansy $amount';
  }

  @override
  String get qaUnavailableNoAmount => 'möçber girizilýänçä elýeterli däl';
}
