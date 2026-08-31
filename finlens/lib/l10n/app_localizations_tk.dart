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
  String get accountGroupSetAside => 'Aýrylan';

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
  String get quickAddNewBudget => 'Täze býujet';

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
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Duş',
      '2': 'Siş',
      '3': 'Çar',
      '4': 'Pen',
      '5': 'Ann',
      '6': 'Şen',
      '7': 'Ýek',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayNarrow(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'D',
      '2': 'S',
      '3': 'Ç',
      '4': 'P',
      '5': 'A',
      '6': 'Ş',
      '7': 'Ý',
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
  String get insNetWorth => 'Arassa gymmat';

  @override
  String get insNetWorthCaption => 'arassa gymmat';

  @override
  String get insIncome => 'Girdeji';

  @override
  String get insSpending => 'Çykdajy';

  @override
  String get insDebtCredit => 'Bergi & alacak';

  @override
  String get insRevaluation => 'Gymmat üýtgemesi';

  @override
  String get insIn => 'Girdi';

  @override
  String get insOut => 'Çykdy';

  @override
  String get insRevalued => 'Gaýtadan bahalandy';

  @override
  String get insBefore => 'Öň';

  @override
  String get insNow => 'Häzir';

  @override
  String get insMoved => 'Geçirildi';

  @override
  String get insYourDebt => 'Bergiň';

  @override
  String get insYourCredit => 'Alacagyň';

  @override
  String get insUnchanged => 'üýtgemedi';

  @override
  String get insChargedToCards => 'Kart bilen harçladyň';

  @override
  String get insPaidToCards => 'Karta töledin';

  @override
  String insMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ýene $count',
    );
    return '+$_temp0';
  }

  @override
  String get insShowLess => 'Azyny görkez';

  @override
  String get insFilterAccounts => 'Hasaplary süz';

  @override
  String get insFilterOff => 'Öçük';

  @override
  String insFilterActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Işjeň, $count element gizlenen',
    );
    return '$_temp0';
  }

  @override
  String get insClearCustomRange => 'Ýörite aralygy arassala';

  @override
  String insA11yHeroUp(String amount) {
    return 'Arassa gymmat $amount artdy.';
  }

  @override
  String insA11yHeroDown(String amount) {
    return 'Arassa gymmat $amount azaldy.';
  }

  @override
  String insA11yHeroFlat(String amount) {
    return 'Arassa gymmat üýtgemedi, $amount.';
  }

  @override
  String insA11yWaterfall(
    Object before,
    Object inflow,
    Object outflow,
    Object revalued,
    Object now,
  ) {
    return 'Arassa gymmat öň $before, $inflow girdi, $outflow çykdy, $revalued bahalandy, häzir $now.';
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
    return 'Arassa gymmat öň $before, $inflow girdi, $outflow çykdy, $revalued bahalandy, $moved görnüşden çykdy, häzir $now.';
  }

  @override
  String insA11yGroupUp(Object name, Object amount) {
    return '$name, $amount artdy.';
  }

  @override
  String insA11yGroupDown(Object name, Object amount) {
    return '$name, $amount azaldy.';
  }

  @override
  String insA11yDebtUp(Object label, Object balance, Object delta) {
    return '$label $balance, $delta artdy.';
  }

  @override
  String insA11yDebtDown(Object label, Object balance, Object delta) {
    return '$label $balance, $delta azaldy.';
  }

  @override
  String insA11yDebtFlat(Object label, Object balance) {
    return '$label $balance, üýtgemedi.';
  }

  @override
  String insA11yMovementUp(Object label, Object amount) {
    return '$label, $amount, bergi artdy.';
  }

  @override
  String insA11yMovementDown(Object label, Object amount) {
    return '$label, $amount, bergi azaldy.';
  }

  @override
  String insA11yRevalUp(
    Object name,
    Object amount,
    Object percent,
    Object date,
  ) {
    return '$name, $amount artdy$percent, $date.';
  }

  @override
  String insA11yRevalDown(
    Object name,
    Object amount,
    Object percent,
    Object date,
  ) {
    return '$name, $amount azaldy$percent, $date.';
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
      other: '$count kategoriýa',
    );
    return 'Ählisini gör · $_temp0';
  }

  @override
  String insCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kategoriýa',
    );
    return '$_temp0';
  }

  @override
  String get insEmptyNoAccountsTitle => 'Görkezere zat ýok';

  @override
  String get insEmptyNoAccountsBody =>
      'Insight puluňyzyň nä bolandygyny görkezýär — nireden geldi, nirä gitdi we näme galdy.';

  @override
  String get insEmptyNoRecordsTitle => 'Entek hiç zat üýtgänok';

  @override
  String insEmptyHoldings(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hasap',
      one: '$count hasap',
    );
    return 'Hasaplaryňyzda $amount · $_temp0';
  }

  @override
  String insEmptyHoldingsNoAmount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hasap',
      one: '$count hasap',
    );
    return '$_temp0';
  }

  @override
  String get insEmptyRecordSomething => 'Bir zat ýaz';

  @override
  String get insEmptyAllHiddenTitle => 'Ähli hasap gizlendi';

  @override
  String insEmptyAllHiddenBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hasaby',
      one: '$count hasaby',
    );
    return 'Filtr $_temp0 gizleýär';
  }

  @override
  String get insEmptyShowAll => 'Ähli hasaplary görkez';

  @override
  String insEmptyWindow(String period) {
    return '$period üçin ýazgy ýok';
  }

  @override
  String insEmptyHiddenByFilter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ýazgy filtr bilen gizlendi',
      one: '$count ýazgy filtr bilen gizlendi',
    );
    return '$_temp0';
  }

  @override
  String insGoToPeriodBack(String period) {
    return '← $period geç';
  }

  @override
  String insGoToPeriodForward(String period) {
    return '→ $period geç';
  }

  @override
  String get insA11yEmptyNoAccounts =>
      'Görkezere zat ýok. Insight puluňyzyň nä bolandygyny görkezýär. Hasap goşuň.';

  @override
  String insA11yEmptyNoRecords(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hasap',
      one: '$count hasap',
    );
    return 'Arassa baýlyk üýtgemedi. Entek hiç zat üýtgänok. Hasaplaryňyzda $amount, $_temp0.';
  }

  @override
  String get insA11yEmptyAllHidden =>
      'Arassa baýlyk üýtgemedi. Ähli hasap filtr bilen gizlendi.';

  @override
  String insA11yEmptyWindow(String period) {
    return 'Arassa baýlyk üýtgemedi. $period üçin ýazgy ýok.';
  }

  @override
  String insAverageValue(String amount) {
    return 'Ortaça $amount';
  }

  @override
  String insHighest(String label, String amount) {
    return 'iň ýokary $label $amount';
  }

  @override
  String get insEmptyMonthsExcluded => 'boş döwürler hasaba alynmady';

  @override
  String insStillRunning(String month) {
    return '$month dowam edýär';
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
    return 'Diňe $count döwürde ýazgy bar — ortaça we ugur ýazylmady';
  }

  @override
  String get insNoPreviousPeriod => 'geçen döwürde ýazgy ýok';

  @override
  String insMonthlyBudget(String amount, String percent) {
    return 'Aýlyk býujet $amount · $percent';
  }

  @override
  String insLeft(String amount) {
    return '$amount galdy';
  }

  @override
  String insOverBudget(String amount) {
    return '$amount aşdy';
  }

  @override
  String get insNoBudget => 'býujet ýok';

  @override
  String insBudgetSub(String amount, String percent) {
    return 'býujet $amount · $percent';
  }

  @override
  String insBudgetSubOver(String amount, String percent) {
    return 'býujet $amount · $percent aşdy';
  }

  @override
  String get insAddBudget => 'Býujet goş';

  @override
  String insUnbudgetedTotal(String amount) {
    return 'Býujetsiz kategoriýalarda $amount';
  }

  @override
  String get insSelectDateRange => 'Sene aralygyny saýla…';

  @override
  String get insPeriod => 'Döwür';

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
  String get insFilterAccountsNote =>
      'Gizlenen hasaplar ähli sanlary üýtgedýär';

  @override
  String get insFilterCategoriesNote =>
      'Gizlenen kategoriýalar diňe sanawdan aýrylýar';

  @override
  String get insSpendingList => 'Çykdajy sanawy';

  @override
  String get insIncomeList => 'Girdeji sanawy';

  @override
  String insOfTotal(String amount) {
    return 'jemi $amount';
  }

  @override
  String insCategoriesShown(int shown, int total) {
    return '$shown / $total kategoriýa';
  }

  @override
  String insAccountsShown(int shown, int total) {
    return '$shown / $total hasap';
  }

  @override
  String get insSpendingHistory => '6 aýlyk çykdajy taryhy';

  @override
  String insSavedOutsideWindow(String date) {
    return '$date senesine ýazyldy, bu döwürden daşary';
  }

  @override
  String get insGoToDate => 'Senä geç';

  @override
  String insA11yPresetSelected(String name, String range) {
    return '$name, $range, saýlanan';
  }

  @override
  String insA11yCustomRow(String range, String days) {
    return 'Sene aralygyny saýla, häzir $range, $days';
  }

  @override
  String insA11yChartCol(String label, String amount) {
    return '$label, $amount';
  }

  @override
  String insA11yChartColPartial(String label, String amount, String days) {
    return '$label, şu wagta çenli $amount, $days';
  }

  @override
  String insA11yChartColEmpty(String label) {
    return '$label, ýazgy ýok';
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
  String get arcReached => 'Ýetilen';

  @override
  String get arcSuccess => 'Üstünlik';

  @override
  String get arcAvgTime => 'Ort. wagt';

  @override
  String arcMonthsShort(int count) {
    return '$count aý';
  }

  @override
  String arcGoalsTakeAbout(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aý',
    );
    return 'Maksatlaryň ortaça $_temp0 dowam edýär';
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
  String get obTitle => 'Açylyş balansy';

  @override
  String get obNotSet => 'Bellenmedik';

  @override
  String get obShiftsNote =>
      'Bu şu hasapdaky ähli hereket edýän balansy süýşürer.';

  @override
  String get obDateTooLate => 'Açylyş senesi ilkinji amaldan soň bolup bilmez.';

  @override
  String get obDeleteTitle => 'Açylyş balansy aýrylsynmy?';

  @override
  String obDeleteMsg(String amount) {
    return 'Şu hasapdaky ähli balans $amount möçberde üýtgär.';
  }

  @override
  String get obDeleteConfirm => 'Açylyş balansyny aýyr';

  @override
  String get obCopyTitle => 'Hasaba göçür';

  @override
  String obA11y(String account, String amount) {
    return 'Açylyş balansy, $account, $amount';
  }

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
  String get balNoAccountsYet => 'Eliňizdäki bilen başlaň';

  @override
  String get balNoAccountMatch =>
      'Gözlegiňize gabat gelýän hasap ýa-da topar ýok.';

  @override
  String get balAddFirstAccount => 'Ilkinji hasabyňyzy goşuň';

  @override
  String get balNoAccountsMessage =>
      'Hasap we onuň balansyny goşuň. Galan zatlaryň baryny — arassa baýlygy, býujetleri, maksatlary — FinLens şundan hasaplaýar.';

  @override
  String get balNothingRecordedYet => 'Entek hiç zat ýazylmady';

  @override
  String get balAdjustFilter => 'Süzgüji sazla';

  @override
  String get balSortTooltip => 'Tertiple';

  @override
  String get balSortDefault => 'Adaty tertip';

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
  String get plNothingScheduled => 'Meýilnama ýok';

  @override
  String get plNothingSchedMsg =>
      'Meýilleşdiren hasaplaryňyz, aýlyklaryňyz we abunalaryňyz şu ýerde görüner.';

  @override
  String get plLeftThisMonth => 'Şu aý galan';

  @override
  String get plOf => '/';

  @override
  String get plBudgetWord => 'býujet';

  @override
  String get plSavedTowardGoals => 'Maksatlara toplanan';

  @override
  String get plPace => 'Depgin';

  @override
  String plLeftOfAmount(Object amount) {
    return '$amount býujetden galan';
  }

  @override
  String plOverAmount(Object amount) {
    return '$amount býujetden aşdy';
  }

  @override
  String plPctSpent(Object pct) {
    return '$pct sarp edildi';
  }

  @override
  String plDayOfMonth(int day, int length) {
    return '$length günüň $day-nji güni';
  }

  @override
  String plCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kategoriýa',
      one: '$count kategoriýa',
    );
    return '$_temp0';
  }

  @override
  String plSemRowOver(Object name, Object spent, Object limit) {
    return '$name, býujet aşyldy, $spent / $limit';
  }

  @override
  String plSemRowNear(Object name, Object spent, Object limit) {
    return '$name, çäge ýakyn, $spent / $limit';
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
  String get arAccounts => 'Accounts';

  @override
  String get arCategories => 'Categories';

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
  String get ldgSelectOthers => 'Beýlekileri saýla';

  @override
  String ldgNSelected(Object n) {
    return '$n saýlandy';
  }

  @override
  String get ldgAllSelected => 'ählisi';

  @override
  String ldgClearSection(Object section) {
    return '$section saýlawyny arassala';
  }

  @override
  String ldgMoreCategories(Object n) {
    return 'ýene $n kategoriýa';
  }

  @override
  String ldgMoreAccounts(Object n) {
    return 'ýene $n hasap';
  }

  @override
  String ldgMoreTags(Object n) {
    return 'ýene $n bellik';
  }

  @override
  String ldgNHiddenSelected(Object n) {
    return '$n saýlandy';
  }

  @override
  String ldgNMatches(Object n) {
    return '$n gabat';
  }

  @override
  String ldgNResults(Object n) {
    return '$n netije';
  }

  @override
  String get ldgExpenses => 'Çykdajylar';

  @override
  String get ldgIncomes => 'Girdejiler';

  @override
  String get ldgExpenseCategoriesA11y => 'çykdajy kategoriýalary';

  @override
  String get ldgIncomeSourcesA11y => 'girdeji çeşmeleri';

  @override
  String get ldgTransfersHaveNoCategory => 'Geçirimleriň kategoriýasy ýok.';

  @override
  String get ldgRevaluationsMoveNoCash => 'Deňagramlaşdyrma nagt geçirmeýär.';

  @override
  String ldgAmountRange(Object min, Object max) {
    return '$min – $max';
  }

  @override
  String get tdFrom => 'Nireden';

  @override
  String get tdTo => 'Nirä';

  @override
  String get tdDeletedAccount => 'Pozulan hasap';

  @override
  String get tdRate => 'Kurs';

  @override
  String get tdNote => 'BELLIK';

  @override
  String get tdNetWorth => 'Arassa baýlyk';

  @override
  String get tdUnchanged => 'Üýtgemedik';

  @override
  String get stDetailNote => 'Bellik';

  @override
  String get stDetailWhen => 'Haçan';

  @override
  String get stDetailPaidWith => 'Töleg hasaby';

  @override
  String get stDetailTags => 'Bellikler';

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
  String get qaBudgetWhichCategory => 'Haýsy kategoriýa býujet?';

  @override
  String qaThisMonthSpend(Object amount) {
    return 'şu aý $amount';
  }

  @override
  String get qaNothingSpentYet => 'Entek ýok';

  @override
  String get qaAllCategoriesBudgeted => 'Her kategoriýanyň eýýäm býujeti bar';

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
  String get qaDiscardTitle => 'Täze hasap ýatyrylsynmy?';

  @override
  String get qaDiscardBody => 'Giren maglumatlaryňyz saklanmaz.';

  @override
  String get qaDiscardConfirm => 'Ýatyr';

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
  String get ssOverBy => 'Artyk';

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
  String get rsEvery2Weeks => '2 hepdede bir';

  @override
  String get rsEveryMonth => 'Her aý';

  @override
  String get rsEveryQuarter => 'Her çärýek';

  @override
  String get rsEveryYear => 'Her ýyl';

  @override
  String get rsShortWeekly => 'hepdelik';

  @override
  String get rsShortBiweekly => '2 hepdede bir';

  @override
  String get rsShortMonthly => 'aýlyk';

  @override
  String get rsShortQuarterly => 'çärýeklik';

  @override
  String get rsShortYearly => 'ýyllyk';

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
  String get rsNext => 'Indiki';

  @override
  String get rsShorterMonths => 'Gysga aýlar iň soňky güni ulanýar';

  @override
  String get rsEveryDay => 'Her gün';

  @override
  String get rsWeekdays => 'Iş günleri';

  @override
  String rsNDaysWeek(int count) {
    return 'hepdede $count gün';
  }

  @override
  String rsNDaysMonth(int count) {
    return 'aýda $count gün';
  }

  @override
  String rsMonthlyOnDay(Object day) {
    return 'her aýyň $day';
  }

  @override
  String rsDaysJoin(Object head, Object last) {
    return '$head we $last';
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

  @override
  String get bfNetWorthFiltered => 'ARASSA BAÝLYK · SÜZGÜÇLI';

  @override
  String bfVisibleCategories(int visible, int total) {
    return '$total kategoriýadan $visible';
  }

  @override
  String bfVisibleAccounts(int visible, int total) {
    return '$total hasapdan $visible';
  }

  @override
  String get bdAMonth => 'aýda';

  @override
  String get bdSpent => 'harçlandy';

  @override
  String bdSpentOver(String over) {
    return 'harçlandy · $over artyk';
  }

  @override
  String bdDayOfMonth(int day, int total) {
    return '$total günüň $day-nji güni';
  }

  @override
  String get bdAgainstLimit => 'ÇÄKE GARŞY';

  @override
  String get mpMonth => 'AÝ';

  @override
  String get srDateRange => 'SENE ARALYGY';

  @override
  String get srCustomRange => 'ÖZ ARALYGY';

  @override
  String get calFrom => 'BAŞLANGYÇ';

  @override
  String get calTo => 'AHYRY';

  @override
  String plOfTarget(String target) {
    return '$target maksatdan';
  }

  @override
  String get dsKeepIt => 'Galsyn';

  @override
  String get qaExampleCategory => 'mysal: Azyk';

  @override
  String get qaExampleAccount => 'mysal: Esasy hasap';

  @override
  String get qaExampleGoal => 'mysal: MacBook Pro M4';

  @override
  String get goalSecSaving => 'Ýygnamak';

  @override
  String get goalSecPayingOff => 'Töleg';

  @override
  String get goalSecWaitingOn => 'Garaşylýan';

  @override
  String get goalSecEarning => 'Girdeji';

  @override
  String goalOfTotal(Object current, Object target) {
    return '$target / $current';
  }

  @override
  String goalLeftTotal(Object amount) {
    return '$amount galdy';
  }

  @override
  String goalOwedTotal(Object amount) {
    return '$amount almaly';
  }

  @override
  String get goalSourceUnavailable => 'Çeşme elýeterli däl';

  @override
  String get goalReached => 'Ýetildi';

  @override
  String goalReachedEarly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün ir ýetildi',
      one: '1 gün ir ýetildi',
    );
    return '$_temp0';
  }

  @override
  String get goalNothingYet => 'häzirlikçe ýok';

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
    return 'Möhlet $date · $tail';
  }

  @override
  String get goalFunded => 'Üpjün edildi';

  @override
  String goalRefill(Object amount) {
    return '$amount goş';
  }

  @override
  String goalBehind(Object phrase) {
    return 'Yza galýar · $phrase';
  }

  @override
  String plGoalRateSave(Object rate) {
    return 'aýda $rate ýygna';
  }

  @override
  String plGoalRatePay(Object rate) {
    return 'aýda $rate töle';
  }

  @override
  String plGoalRateCollect(Object rate) {
    return 'aýda $rate al';
  }

  @override
  String plGoalRateEarn(Object rate) {
    return 'aýda $rate gazan';
  }

  @override
  String goalAhead(Object rate) {
    return 'Öňde · aýda $rate';
  }

  @override
  String goalOnTrack(Object rate) {
    return 'Meýilnamada · aýda $rate';
  }

  @override
  String get plGoalFilterButton => 'Maksat süzgüçi';

  @override
  String plGoalScopeAllSome(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n maksat',
      one: '$n maksat',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m üns talap edýär',
      one: '$m üns talap edýär',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String plGoalScopeAllNone(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n maksat',
      one: '$n maksat',
    );
    return '$_temp0 · ählisi meýilnamada';
  }

  @override
  String get plGoalScopeOneAttention => '1 maksat · üns talap edýär';

  @override
  String get plGoalScopeOneOnTrack => '1 maksat · meýilnamada';

  @override
  String plGoalScopeNeeds(int m, int n) {
    return 'Üns talap edýär · $n maksatdan $m';
  }

  @override
  String plGoalScopeOnTrack(int k, int n) {
    return 'Meýilnamada · $n maksatdan $k';
  }

  @override
  String get plGoalStatus => 'ÝAGDAÝ';

  @override
  String get plGoalFilterAll => 'Ählisi';

  @override
  String get plGoalFilterNeeds => 'Üns talap edýär';

  @override
  String get plGoalFilterOnTrack => 'Meýilnamada';

  @override
  String get plGoalArchiveNote =>
      'Ýetilen we ýüz öwrülen maksatlar bu ýerde däl — Arhiwde.';

  @override
  String get plGoalNoneNeed => 'Üns talap edýän maksat ýok';

  @override
  String get plGoalNoneOnTrack => 'Meýilnamada barýan maksat ýok';

  @override
  String get plGoalShowAll => 'Ählisini görkez';

  @override
  String plGoalRowA11y(Object option, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count maksat',
      one: '$count maksat',
    );
    return '$option, $_temp0';
  }

  @override
  String goalPerMonth(Object amount) {
    return 'aýda $amount';
  }

  @override
  String get goalNewTitle => 'Täze maksat';

  @override
  String get goalWatching => 'Yzarlanýar';

  @override
  String get goalSource => 'Çeşme';

  @override
  String get goalSourceLocked => 'Hasaby üýtgetmek täze maksat diýmekdir.';

  @override
  String get goalSetDateHint => 'Sene ýa-da aýlyk mukdar giriziň';

  @override
  String get goalMonthly => 'Aýlyk';

  @override
  String get goalEnterRate => 'Aýlyk mukdar giriziň';

  @override
  String get goalNoteLabel => 'Bellik';

  @override
  String get goalNoteHint => 'Islege görä';

  @override
  String get goalDoneOnceReached => 'Ýetilende tamamlansyn';

  @override
  String get goalDoneOnceReachedDesc => 'Doldurylýan gaznalar üçin öçüriň';

  @override
  String get goalDeleteRowDesc => 'Maksady öçürýär, pul galýar';

  @override
  String get goalOfWord => '/';

  @override
  String goalNewAccountNamed(Object name) {
    return 'Täze · $name';
  }

  @override
  String get goalUntitled => 'Täze maksat';

  @override
  String get goalChooseSource => 'Nämäni yzarlajagyňyzy saýlaň';

  @override
  String get goalTwoOnAccount =>
      'Bu hasaby yzarlaýan başga maksat bar. Rugsat berilýär — ikisi hem bir balansy okaýar.';

  @override
  String get goalMonthlyPromptTitle => 'Aýlyk mukdar';

  @override
  String get goalNewAccountOption => 'Täze hasap';

  @override
  String get goalNewAccountOptionDesc => 'Maksatdan atlandyrylan aýrylan hasap';

  @override
  String get goalIncomeCategories => 'Girdeji kategoriýalary';

  @override
  String goalDeleteTitle(Object name) {
    return '\"$name\" pozulsynmy?';
  }

  @override
  String get goalDeleteBody =>
      'Maksat we onuň taryhy ýitýär. Başga hiç zat üýtgemeýär.';

  @override
  String goalDeleteAccountStays(Object name, Object balance) {
    return '\"$name\" hasaby galýar · $balance';
  }

  @override
  String goalDeleteTxnStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amaly galýar',
      one: '1 amaly galýar',
    );
    return '$_temp0';
  }

  @override
  String get goalDeleteCategoryStays =>
      'Girdeji kategoriýasy we amallary galýar';

  @override
  String goalOfToGo(Object target, Object remaining) {
    return '/ $target · $remaining galdy';
  }

  @override
  String goalDaysCaption(Object pct, int elapsed, int total) {
    return '$pct · $total günüň $elapsed güni';
  }

  @override
  String get goalColStarted => 'Başlandy';

  @override
  String get goalColTarget => 'Maksat';

  @override
  String get goalColAtThisRate => 'Şu depginde';

  @override
  String get goalColReachedOn => 'Ýetildi';

  @override
  String get goalColStoppedOn => 'Duruzyldy';

  @override
  String get goalColGotTo => 'Ýygnaldy';

  @override
  String get goalColTook => 'Wagt';

  @override
  String goalTookMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aý',
      one: '1 aý',
    );
    return '$_temp0';
  }

  @override
  String get goalTookUnderMonth => '< 1 aý';

  @override
  String goalOutcomeReachedOn(Object date) {
    return '$date ýetildi';
  }

  @override
  String goalOutcomeStoppedOn(Object date) {
    return '$date duruzyldy';
  }

  @override
  String get goalDeletePermanently => 'Hemişelik pozmak';

  @override
  String get goalReachedSummary => 'Ýetildi — başga edere zat ýok';

  @override
  String get goalNotMovingYet => 'Heniz hereket ýok';

  @override
  String goalAveragingOnly(Object rate) {
    return 'Aýda ortaça $rate';
  }

  @override
  String goalAveraging(Object actual, Object needs) {
    return 'Häzir aýda $actual · wagtynda ýetmek üçin aýda $needs gerek';
  }

  @override
  String a11yMoneyIn(Object amount) {
    return 'Pul girişi, $amount';
  }

  @override
  String a11yMoneyOut(Object amount) {
    return 'Pul çykyşy, $amount';
  }

  @override
  String goalCategoryWindow(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get goalMovements => 'Hereketler';

  @override
  String goalSeeAll(int count) {
    return 'Ählisini gör ($count)';
  }

  @override
  String get goalNoteSection => 'Bellik';

  @override
  String get goalChanges => 'Üýtgeşmeler';

  @override
  String get goalChangeCreated => 'Döredildi';

  @override
  String get goalChangeTarget => 'Maksat';

  @override
  String get goalChangeDate => 'Maksat senesi';

  @override
  String get bhCreated => 'Döredildi';

  @override
  String get bhLimit => 'Çäk';

  @override
  String get bhRollover => 'Geçiriş';

  @override
  String get bhWarn => 'Duýduryş';

  @override
  String get bhRemoved => 'Aýryldy';

  @override
  String get bhRestored => 'Dikeldildi';

  @override
  String get bhCategoryArchived => 'Kategoriýa arhiwlendi';

  @override
  String get bhOn => 'Açyk';

  @override
  String get bhOff => 'Ýapyk';

  @override
  String bhCreatedRolloverOn(String amount) {
    return '$amount · geçiriş açyk';
  }

  @override
  String bhCreatedRolloverOff(String amount) {
    return '$amount · geçiriş ýapyk';
  }

  @override
  String get bhEmpty => 'Heniz üýtgeşme ýazgysy ýok';

  @override
  String bhSince(String date) {
    return 'Üýtgeşmeler $date senesinden bäri ýazylýar';
  }

  @override
  String get bhA11yTo => '→';

  @override
  String get bhA11yIncreased => 'ýokarlandy';

  @override
  String get goalMenuEdit => 'Maksady üýtget';

  @override
  String get goalStopTracking => 'Yzarlamany bes et';

  @override
  String get goalStopTrackingDesc => 'Ýazgy Arhiwde galýar';

  @override
  String get goalReachedAtZero => 'Ýetildi we hasap boş.';

  @override
  String get goalKeepAccount => 'Hasaby sakla';

  @override
  String get goalArchiveBoth => 'Ikisini hem arhiwle';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get moreTags => 'Tags';

  @override
  String tagsSubtitle(int inUse, int archived) {
    return '$inUse in use · $archived archived';
  }

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
  String get tagSectionArchived => 'Archived';

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
  String get plTitle => 'Meýilleşdiriji';

  @override
  String get fieldSelectCategory => 'Kategoriýa saýlaň';

  @override
  String get actionResume => 'Dowam et';

  @override
  String get schToday => 'Şu gün';

  @override
  String get schHorizonThisWeek => 'Şu hepde';

  @override
  String get schHorizonNext30 => 'Indiki 30 gün';

  @override
  String get schHorizonThisMonth => 'Şu aý';

  @override
  String get schHorizonNext3Months => 'Indiki 3 aý';

  @override
  String get schHorizonTitle => 'GORIZONT';

  @override
  String get schHorizonUntilDate => 'Sene çenli…';

  @override
  String get schHorizonFootnote =>
      'Möhleti geçen tölegler bu ýerde hasaba alynmaýar — haýsy gorizonty saýlasaňyz-da sanawda galýar.';

  @override
  String schUntilControl(Object date) {
    return '$date çenli';
  }

  @override
  String schCompletedIn(Object label) {
    return '$label tamamlanan';
  }

  @override
  String get schCompletedEmpty => 'Bu döwürde tamamlanan zat ýok.';

  @override
  String get schCompletedLongerPeriod => 'Uzynrak döwür saýlaň';

  @override
  String get schUntilTitle => 'SENE ÇENLI';

  @override
  String get schUntilNote => 'Şu gün başlaýar — soňuny saýlaň.';

  @override
  String get schUntilPickPrompt => 'Tamamlanýan senäni saýlaň';

  @override
  String schUntilFromTo(Object date) {
    return 'Şu günden $date çenli';
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
    return '$count töleg';
  }

  @override
  String schApplyDays(int count) {
    return 'Ulan · $count gün';
  }

  @override
  String get schLegendPayment => 'töleg bar';

  @override
  String get schLegendNegative => 'balans minusa geçýär';

  @override
  String get schShortLabel => 'ýetmeýär';

  @override
  String get schLeftLabel => 'galýar';

  @override
  String get schLeftAfter => 'borçlardan soň galýar';

  @override
  String get schShortAfter => 'borçlardan soň ýetmeýär';

  @override
  String schCaptionIn(Object amount) {
    return '$amount geler';
  }

  @override
  String schCaptionOut(Object amount) {
    return '$amount çykar';
  }

  @override
  String schShortToday(Object amount) {
    return 'Şu gün $amount ýetmeýär';
  }

  @override
  String schShortOnDay(Object amount, Object date) {
    return '$date senesinde $amount ýetmeýär';
  }

  @override
  String schBannerOut(int count, Object amount) {
    return '$count möhleti geçen töleg · $amount';
  }

  @override
  String schBannerIn(int count, Object amount) {
    return '$count garaşylýan töleg gelmedi · $amount';
  }

  @override
  String schBannerBoth(int count, Object out, Object inAmt) {
    return '$count möhleti geçdi · $out çykýan, $inAmt gelýän';
  }

  @override
  String get schNothingInHorizon => 'Bu aralykda hiç zat ýok';

  @override
  String get schShowNext3Months => 'Indiki 3 aýy görkez ›';

  @override
  String schDaysLate(int count) {
    return '$count gün gijä galdy';
  }

  @override
  String schOverdueDays(int count) {
    return '$count gün';
  }

  @override
  String get schWontCover => 'ýetmez';

  @override
  String get schSemPayingOut => 'tölenýär';

  @override
  String get schSemComingIn => 'gelýär';

  @override
  String get schSemDue => 'möhlet';

  @override
  String get schSemFrom => 'hasapdan';

  @override
  String get schSemInto => 'hasaba';

  @override
  String schSemRepeats(Object cadence) {
    return 'gaýtalanýar $cadence';
  }

  @override
  String schItemsCount(int count) {
    return '$count ýazgy';
  }

  @override
  String schPausedArchiveLine(int count) {
    return '$count duruzylan iş · Arhiw ›';
  }

  @override
  String schCompletedFooter(Object out, Object inAmt, int count) {
    return '$out çykýan · $inAmt gelýän · $count bolmady';
  }

  @override
  String schSeeAll(int count) {
    return 'Ählisini gör ($count) ›';
  }

  @override
  String schPaidLine(Object when, Object account) {
    return '$when tölendi · $account';
  }

  @override
  String schReceivedLine(Object when, Object account) {
    return '$when alyndy · $account';
  }

  @override
  String schSkippedLine(Object when) {
    return '$when geçildi';
  }

  @override
  String schCancelledLine(Object when) {
    return '$when ýatyryldy';
  }

  @override
  String histLastDays(int count) {
    return 'Soňky $count gün';
  }

  @override
  String get histThisMonth => 'Şu aý';

  @override
  String get histLastMonth => 'Geçen aý';

  @override
  String histSinceDate(Object date) {
    return '$date senesinden';
  }

  @override
  String get histSincePrompt => 'Senesinden…';

  @override
  String histFilterAll(int count) {
    return 'Ählisi $count';
  }

  @override
  String histFilterPaid(int count) {
    return 'Tölenen $count';
  }

  @override
  String histFilterSkipped(int count) {
    return 'Geçilen $count';
  }

  @override
  String histFilterCancelled(int count) {
    return 'Ýatyrylan $count';
  }

  @override
  String get histOut => 'ÇYKAN';

  @override
  String get histIn => 'GELEN';

  @override
  String get histDidntHappen => 'BOLMADY';

  @override
  String get histNothingHere => 'Bu döwürde hiç zat ýok';

  @override
  String histPausedDeleted(int paused, int deleted) {
    return 'Bu döwürde $paused duruzyldy, $deleted pozuldy · Arhiw ›';
  }

  @override
  String get mpTitlePaid => 'Tölenen diýip belle';

  @override
  String get mpTitleReceived => 'Alnan diýip belle';

  @override
  String mpSubtitle(Object title, Object date) {
    return '$title · möhlet $date';
  }

  @override
  String mpExpected(Object amount) {
    return 'garaşylýan $amount';
  }

  @override
  String get mpDate => 'Sene';

  @override
  String get mpFrom => 'Hasapdan';

  @override
  String get mpInto => 'Hasaba';

  @override
  String get mpTo => 'Nirä';

  @override
  String get mpTransferNoCategory => 'Geçirim — býujet kategoriýasy ýok';

  @override
  String mpRemember(Object amount) {
    return 'Indiki gezek üçin $amount ýatda sakla';
  }

  @override
  String mpConfirm(Object amount) {
    return 'Tassykla · $amount';
  }

  @override
  String get mpChooseDestination => 'Barjak ýerini saýlaň';

  @override
  String get mpPayOffGroup => 'BERGINI ÜZMEK';

  @override
  String mpRecorded(Object title) {
    return '$title Depdere ýazyldy';
  }

  @override
  String mpRecordedNext(Object title, Object date) {
    return '$title Depdere ýazyldy · indiki $date';
  }

  @override
  String get tmEdit => 'Üýtget';

  @override
  String get tmEditSub =>
      'Möçber, sene, gaýtalanma, hasap, kategoriýa, ýatladyş we bellik.';

  @override
  String get tmSkip => 'Muny geç';

  @override
  String tmSkipSub(Object date, Object next) {
    return '$date geçildi. Depdere hiç zat ýazylmaýar; tapgyr $next senesinde dowam eder.';
  }

  @override
  String get tmPause => 'Duruz';

  @override
  String get tmPauseSub =>
      'Sanawdan we çaklamadan çykýar. Töleg taryhy we geljekki seneler saklanýar — islän wagtyňyz Arhiwden dowam ediň.';

  @override
  String get tmDelete => 'Poz';

  @override
  String tmDeleteSub(int count) {
    return 'Arhiwe geçýär — tötänleýin pozmagy yzyna gaýtaryp bolýar. $count töleg Depderde galýar. Hemişelik pozmak Arhiwden edilýär.';
  }

  @override
  String tdDeleteTitle(Object title) {
    return '$title pozulsynmy?';
  }

  @override
  String get tdDeleteMsg =>
      'Arhiwe geçýär — tötänleýin pozmagy yzyna gaýtaryp bolýar.';

  @override
  String tdKeptPayments(int count) {
    return '$count töleg Depderde galýar';
  }

  @override
  String get tdKeptBalances => 'Balanslara täsir etmeýär';

  @override
  String get tdKeptHistory => 'Töleg taryhy iş bilen Arhiwde galýar';

  @override
  String get tdLostSchedule => 'Meýilnamadan we çaklamadan çykýar';

  @override
  String get tdLostReminders => 'Geljekki ýatladyşlar togtaýar';

  @override
  String get tdDeleteConfirm => 'Poz';

  @override
  String tdPausedOn(Object date) {
    return '$date senesinde duruzyldy';
  }

  @override
  String get tdNext => 'INDIKI';

  @override
  String get tdAmount => 'MÖÇBER';

  @override
  String get tdPerYear => 'ÝYLDA';

  @override
  String get tdDue => 'MÖHLET';

  @override
  String get tdUpcoming => 'GELJEKKI';

  @override
  String get tdPaymentHistory => 'TÖLEG TARYHY';

  @override
  String get tdNoPayments => 'Heniz töleg ýok';

  @override
  String tdPaymentsSince(int count, Object month, Object total) {
    return '$month senesinden $count töleg · jemi $total';
  }

  @override
  String get tdResume => 'Dowam et';

  @override
  String get tdMarkPaid => 'Tölenen diýip belle';

  @override
  String get tdMarkReceived => 'Alnan diýip belle';

  @override
  String get tdSkipOne => 'Muny geç';

  @override
  String get etNote => 'Bellik';

  @override
  String get etNoteHint => 'Bellik goş';

  @override
  String get etPaidTo => 'Nirä tölenýär';

  @override
  String get arPausedTasks => 'DURUZYLAN IŞLER';

  @override
  String get arCompletedTasks => 'TAMAMLANAN IŞLER';

  @override
  String get arDeletedTasks => 'POZULAN IŞLER';

  @override
  String arPausedLine(Object date, int payments, Object total) {
    return '$date duruzyldy · $payments töleg · $total';
  }

  @override
  String arCompletedLine(Object date, Object amount) {
    return '$date tölendi · $amount';
  }

  @override
  String arCancelledLine(Object date) {
    return '$date ýatyryldy';
  }

  @override
  String arDeletedLineTask(Object date, int payments, Object total) {
    return '$date pozuldy · $payments töleg · $total';
  }
}
