// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get language => 'Язык';

  @override
  String get accountGroupSpendable => 'Расходные';

  @override
  String get accountGroupSetAside => 'Отложенные';

  @override
  String get accountGroupReceivables => 'К получению';

  @override
  String get accountGroupInvestments => 'Инвестиции';

  @override
  String get accountGroupValuables => 'Ценности';

  @override
  String get accountGroupCreditCards => 'Кредитные карты';

  @override
  String get accountGroupPayables => 'К оплате';

  @override
  String get accountGroupBankLoans => 'Банковские кредиты';

  @override
  String get accountGroupSpendableDesc =>
      'Текущий счёт, наличные, дебетовая карта';

  @override
  String get accountGroupSetAsideDesc => 'Сбережения, которые пока не тратите';

  @override
  String get accountGroupReceivablesDesc =>
      'Деньги, которые вам должны и вернут';

  @override
  String get accountGroupInvestmentsDesc => 'Акции, фонды, крипта, пенсия';

  @override
  String get accountGroupValuablesDesc =>
      'Машина, золото, недвижимость на продажу';

  @override
  String get accountGroupCreditCardsDesc =>
      'Карты, которыми платите и потом гасите';

  @override
  String get accountGroupPayablesDesc =>
      'Счета и долги, которые ещё не оплатили';

  @override
  String get accountGroupBankLoansDesc => 'Ипотека, автокредит или на учёбу';

  @override
  String get naType => 'Тип';

  @override
  String get naRequired => 'ОБЯЗАТЕЛЬНО';

  @override
  String get naAccountType => 'Тип счёта';

  @override
  String get curSearch => 'Поиск валют';

  @override
  String get curRecent => 'НЕДАВНИЕ';

  @override
  String get curAll => 'ВСЕ ВАЛЮТЫ';

  @override
  String get curAdd => 'Добавить';

  @override
  String get curAddTitle => 'Добавить валюту';

  @override
  String get curCode => 'Код';

  @override
  String get curName => 'Название';

  @override
  String get curSymbolOptional => 'Символ · необязательно';

  @override
  String get curBeforeAmount => 'Перед суммой';

  @override
  String get curDecimals => 'Знаков после запятой';

  @override
  String get curPreview => 'Предпросмотр';

  @override
  String get curAddButton => 'Добавить валюту';

  @override
  String get curInert =>
      'Используется только в этом приложении. Курс не применяется.';

  @override
  String get curCodeExists => 'Этот код уже используется.';

  @override
  String curNoMatch(Object query) {
    return 'Нет валют по запросу «$query».';
  }

  @override
  String get qaBackgroundColour => 'Цвет фона';

  @override
  String get qaIconsTab => 'Значки';

  @override
  String get qaEmojiTab => 'Эмодзи';

  @override
  String get qaSearchEmoji => 'Поиск эмодзи';

  @override
  String get qaNoEmojiMatch => 'Ничего не найдено';

  @override
  String get quickAddExpense => 'Расход';

  @override
  String get quickAddIncome => 'Доход';

  @override
  String get quickAddTransfer => 'Перевод';

  @override
  String get quickAddRebalance => 'Корректировка';

  @override
  String get quickAddNewBudget => 'Новый бюджет';

  @override
  String get quickAddNewGoal => 'Новая цель';

  @override
  String get quickAddNewTask => 'Новая задача';

  @override
  String get txnTypeExpense => 'Расход';

  @override
  String get txnTypeIncome => 'Доход';

  @override
  String get txnTypeTransfer => 'Перевод';

  @override
  String get txnTypeRebalance => 'Корректировка';

  @override
  String get goalTypeSaving => 'Накопление';

  @override
  String get goalTypeMilestone => 'Веха';

  @override
  String get goalTypePurchasing => 'Покупка';

  @override
  String get goalSectionSaving => 'Накопления';

  @override
  String get goalSectionMilestone => 'Вехи';

  @override
  String get goalSectionPurchasing => 'Покупки';

  @override
  String get priorityLow => 'Низкий';

  @override
  String get priorityNormal => 'Обычный';

  @override
  String get priorityHigh => 'Высокий';

  @override
  String get repeatNever => 'Никогда';

  @override
  String get repeatWeekly => 'Еженедельно';

  @override
  String get repeatMonthly => 'Ежемесячно';

  @override
  String get repeatQuarterly => 'Ежеквартально';

  @override
  String get repeatYearly => 'Ежегодно';

  @override
  String get comparePeriodTodayLabel => 'Сегодня';

  @override
  String get comparePeriodTodayCaption => 'к вчера';

  @override
  String get comparePeriodWeekLabel => 'Неделя';

  @override
  String get comparePeriodWeekCaption => 'к прош. неделе';

  @override
  String get comparePeriodMonthLabel => 'Месяц';

  @override
  String get comparePeriodMonthCaption => 'к прош. месяцу';

  @override
  String get rangeThisWeek => 'Эта неделя';

  @override
  String get rangeLastWeek => 'Прошлая неделя';

  @override
  String get rangeThisMonth => 'Этот месяц';

  @override
  String get rangeLastMonth => 'Прошлый месяц';

  @override
  String get rangeLast3Months => '3 месяца';

  @override
  String get rangeLast6Months => '6 месяцев';

  @override
  String get rangeLast12Months => '12 месяцев';

  @override
  String get rangeThisYear => 'Этот год';

  @override
  String get rangeAllTime => 'Всё время';

  @override
  String get navBalance => 'Баланс';

  @override
  String get navLedger => 'Операции';

  @override
  String get navPlanner => 'Планы';

  @override
  String get navInsight => 'Аналитика';

  @override
  String get navMore => 'Ещё';

  @override
  String get accountSortValueDesc => 'Сумма — по убыванию';

  @override
  String get accountSortValueAsc => 'Сумма — по возрастанию';

  @override
  String get accountSortNameAsc => 'Название — А-Я';

  @override
  String get accountSortActivity => 'Изменения — активные';

  @override
  String get accountSortCustom => 'Вручную';

  @override
  String get balanceSectionAll => 'Капитал';

  @override
  String get balanceSectionAssets => 'Активы';

  @override
  String get balanceSectionLiabilities => 'Обязательства';

  @override
  String get transSortDateNewest => 'Дата — сначала новые';

  @override
  String get transSortDateOldest => 'Дата — сначала старые';

  @override
  String get transSortAmountHigh => 'Сумма — по убыванию';

  @override
  String get transSortAmountLow => 'Сумма — по возрастанию';

  @override
  String get transSortByCategory => 'Категория — А-Я';

  @override
  String get transSortByAccount => 'Счёт — А-Я';

  @override
  String get ledgerAllAccounts => 'Все счета';

  @override
  String get ledgerAccountFallback => 'Счёт';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'янв.',
      '2': 'февр.',
      '3': 'март',
      '4': 'апр.',
      '5': 'май',
      '6': 'июнь',
      '7': 'июль',
      '8': 'авг.',
      '9': 'сент.',
      '10': 'окт.',
      '11': 'нояб.',
      '12': 'дек.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String monthLong(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Январь',
      '2': 'Февраль',
      '3': 'Март',
      '4': 'Апрель',
      '5': 'Май',
      '6': 'Июнь',
      '7': 'Июль',
      '8': 'Август',
      '9': 'Сентябрь',
      '10': 'Октябрь',
      '11': 'Ноябрь',
      '12': 'Декабрь',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayLong(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Понедельник',
      '2': 'Вторник',
      '3': 'Среда',
      '4': 'Четверг',
      '5': 'Пятница',
      '6': 'Суббота',
      '7': 'Воскресенье',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Пн',
      '2': 'Вт',
      '3': 'Ср',
      '4': 'Чт',
      '5': 'Пт',
      '6': 'Сб',
      '7': 'Вс',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayNarrow(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'П',
      '2': 'В',
      '3': 'С',
      '4': 'Ч',
      '5': 'П',
      '6': 'С',
      '7': 'В',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get dateToday => 'Сегодня';

  @override
  String get dateYesterday => 'Вчера';

  @override
  String get dateTomorrow => 'Завтра';

  @override
  String dateWithTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String dateGroupYesterday(String date) {
    return 'Вчера · $date';
  }

  @override
  String rangeSince(String monthYear) {
    return 'С $monthYear';
  }

  @override
  String get dueToday => 'сегодня';

  @override
  String get dueTomorrow => 'завтра';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'через $days дня',
      many: 'через $days дней',
      few: 'через $days дня',
      one: 'через $days день',
    );
    return '$_temp0';
  }

  @override
  String dueDaysLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'просрочено на $days дня',
      many: 'просрочено на $days дней',
      few: 'просрочено на $days дня',
      one: 'просрочено на $days день',
    );
    return '$_temp0';
  }

  @override
  String countAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count счёта',
      many: '$count счетов',
      few: '$count счёта',
      one: '$count счёт',
    );
    return '$_temp0';
  }

  @override
  String countTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count операции',
      many: '$count операций',
      few: '$count операции',
      one: '$count операция',
    );
    return '$_temp0';
  }

  @override
  String countResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count результата',
      many: '$count результатов',
      few: '$count результата',
      one: '$count результат',
    );
    return '$_temp0';
  }

  @override
  String countDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String countArchivedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count архивных элемента',
      many: '$count архивных элементов',
      few: '$count архивных элемента',
      one: '$count архивный элемент',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня назад',
      many: '$count дней назад',
      few: '$count дня назад',
      one: '$count день назад',
    );
    return '$_temp0';
  }

  @override
  String get moreTitle => 'Ещё';

  @override
  String get moreData => 'Данные';

  @override
  String get morePreferences => 'Настройки';

  @override
  String get moreCategories => 'Категории';

  @override
  String get moreArchive => 'Архив';

  @override
  String get moreMaskAmounts => 'Скрывать все суммы';

  @override
  String get moreBackup => 'Резервная копия';

  @override
  String get moreRestore => 'Восстановить';

  @override
  String get backupSavedMsg => 'Копия сохранена';

  @override
  String get backupFailedMsg => 'Не удалось сохранить копию';

  @override
  String get restoreConfirmTitle => 'Заменить все данные?';

  @override
  String restoreConfirmMsg(int accounts, int txns) {
    return 'В этой копии $accounts счетов и $txns операций. Текущие данные будут заменены.';
  }

  @override
  String get restoreImpactLost => 'Все данные на этом устройстве будут стёрты';

  @override
  String get restoreImpactKept =>
      'Счета, операции и настройки из копии будут загружены';

  @override
  String get restoreConfirmAction => 'Восстановить';

  @override
  String get restoreDoneMsg => 'Данные восстановлены';

  @override
  String get restoreInvalidMsg => 'Файл не является резервной копией FinLens';

  @override
  String moreVersion(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get moreAddAccount => 'Добавить счёт';

  @override
  String get actionDeletePermanent => 'Удалить навсегда';

  @override
  String plusNMore(int count) {
    return '+$count ещё';
  }

  @override
  String get catManageTitle => 'Категории';

  @override
  String get catEditTitle => 'Изменить категорию';

  @override
  String get catSectionExpense => 'Расходы';

  @override
  String get catSectionIncome => 'Доходы';

  @override
  String get catSectionArchived => 'Архив';

  @override
  String get catArchiveFootnote =>
      'Архивные категории остаются в прошлых операциях. Они просто не появляются, когда вы записываете что-то новое.';

  @override
  String get catTypeLocked =>
      'Изменение перевернёт все операции, уже записанные сюда';

  @override
  String get catArchiveThis => 'Архивировать категорию';

  @override
  String catArchiveMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Сюда записано $count операции, поэтому она архивируется, а не удаляется',
      many:
          'Сюда записано $count операций, поэтому она архивируется, а не удаляется',
      few:
          'Сюда записаны $count операции, поэтому она архивируется, а не удаляется',
      one:
          'Сюда записана $count операция, поэтому она архивируется, а не удаляется',
    );
    return '$_temp0';
  }

  @override
  String get catDeleteThis => 'Удалить категорию';

  @override
  String get catDeleteMsg =>
      'Сюда ещё ничего не записано, поэтому её можно удалить полностью';

  @override
  String get catDeleteBudgeted =>
      'У этой категории есть бюджет в Планировщике. Сначала удалите бюджет или архивируйте категорию.';

  @override
  String get catRestoreThis => 'Восстановить категорию';

  @override
  String get insightTitle => 'Аналитика';

  @override
  String get insNetWorth => 'Чистый капитал';

  @override
  String get insNetWorthCaption => 'чистый капитал';

  @override
  String get insIncome => 'Доход';

  @override
  String get insSpending => 'Расходы';

  @override
  String get insDebtCredit => 'Долги и требования';

  @override
  String get insRevaluation => 'Переоценка';

  @override
  String get insIn => 'Приход';

  @override
  String get insOut => 'Расход';

  @override
  String get insRevalued => 'Переоц.';

  @override
  String get insBefore => 'Было';

  @override
  String get insNow => 'Сейчас';

  @override
  String get insMoved => 'Ушло';

  @override
  String get insYourDebt => 'Твой долг';

  @override
  String get insYourCredit => 'Тебе должны';

  @override
  String get insUnchanged => 'без изменений';

  @override
  String get insChargedToCards => 'Потрачено картой';

  @override
  String get insPaidToCards => 'Оплата карты';

  @override
  String insMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ещё $count',
      few: 'ещё $count',
      one: 'ещё $count',
    );
    return '+$_temp0';
  }

  @override
  String get insShowLess => 'Свернуть';

  @override
  String get insFilterAccounts => 'Фильтр счетов';

  @override
  String get insFilterOff => 'Выкл';

  @override
  String insFilterActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Активен, скрыто $count элементов',
      few: 'Активен, скрыто $count элемента',
      one: 'Активен, скрыт $count элемент',
    );
    return '$_temp0';
  }

  @override
  String get insClearCustomRange => 'Сбросить свой период';

  @override
  String insA11yHeroUp(String amount) {
    return 'Чистый капитал вырос на $amount.';
  }

  @override
  String insA11yHeroDown(String amount) {
    return 'Чистый капитал упал на $amount.';
  }

  @override
  String insA11yHeroFlat(String amount) {
    return 'Чистый капитал без изменений, $amount.';
  }

  @override
  String insA11yWaterfall(
    Object before,
    Object inflow,
    Object outflow,
    Object revalued,
    Object now,
  ) {
    return 'Чистый капитал: было $before, приход $inflow, расход $outflow, переоценка $revalued, сейчас $now.';
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
    return 'Чистый капитал: было $before, приход $inflow, расход $outflow, переоценка $revalued, $moved ушло из виду, сейчас $now.';
  }

  @override
  String insA11yGroupUp(Object name, Object amount) {
    return '$name, рост на $amount.';
  }

  @override
  String insA11yGroupDown(Object name, Object amount) {
    return '$name, снижение на $amount.';
  }

  @override
  String insA11yDebtUp(Object label, Object balance, Object delta) {
    return '$label $balance, рост на $delta.';
  }

  @override
  String insA11yDebtDown(Object label, Object balance, Object delta) {
    return '$label $balance, снижение на $delta.';
  }

  @override
  String insA11yDebtFlat(Object label, Object balance) {
    return '$label $balance, без изменений.';
  }

  @override
  String insA11yMovementUp(Object label, Object amount) {
    return '$label, $amount, долг вырос.';
  }

  @override
  String insA11yMovementDown(Object label, Object amount) {
    return '$label, $amount, долг снизился.';
  }

  @override
  String insA11yRevalUp(
    Object name,
    Object amount,
    Object percent,
    Object date,
  ) {
    return '$name, рост на $amount$percent, $date.';
  }

  @override
  String insA11yRevalDown(
    Object name,
    Object amount,
    Object percent,
    Object date,
  ) {
    return '$name, снижение на $amount$percent, $date.';
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
      other: '$count категорий',
      few: '$count категории',
      one: '$count категория',
    );
    return 'Показать все · $_temp0';
  }

  @override
  String insCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count категорий',
      few: '$count категории',
      one: '$count категория',
    );
    return '$_temp0';
  }

  @override
  String get insEmptyNoAccountsTitle => 'Пока нечего показать';

  @override
  String get insEmptyNoAccountsBody =>
      'Insight показывает, куда ушли деньги, откуда пришли и что осталось.';

  @override
  String get insEmptyNoRecordsTitle => 'Пока ничего не менялось';

  @override
  String insEmptyHoldings(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count счёта',
      many: '$count счетов',
      few: '$count счёта',
      one: '$count счёт',
    );
    return 'На счетах $amount · $_temp0';
  }

  @override
  String insEmptyHoldingsNoAmount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count счёта',
      many: '$count счетов',
      few: '$count счёта',
      one: '$count счёт',
    );
    return '$_temp0';
  }

  @override
  String get insEmptyRecordSomething => 'Записать операцию';

  @override
  String get insEmptyAllHiddenTitle => 'Все счета скрыты';

  @override
  String insEmptyAllHiddenBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count счетов',
      many: '$count счетов',
      few: '$count счёта',
      one: '$count счёт',
    );
    return 'Фильтр скрывает $_temp0';
  }

  @override
  String get insEmptyShowAll => 'Показать все счета';

  @override
  String insEmptyWindow(String period) {
    return 'Нет записей за $period';
  }

  @override
  String insEmptyHiddenByFilter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи скрыты фильтром',
      many: '$count записей скрыто фильтром',
      few: '$count записи скрыты фильтром',
      one: '$count запись скрыта фильтром',
    );
    return '$_temp0';
  }

  @override
  String insGoToPeriodBack(String period) {
    return '← Перейти к $period';
  }

  @override
  String insGoToPeriodForward(String period) {
    return '→ Перейти к $period';
  }

  @override
  String get insA11yEmptyNoAccounts =>
      'Пока нечего показать. Insight показывает, что стало с деньгами. Добавьте счёт.';

  @override
  String insA11yEmptyNoRecords(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count счёта',
      many: '$count счетов',
      few: '$count счёта',
      one: '$count счёт',
    );
    return 'Стоимость не изменилась. Пока ничего не менялось. На счетах $amount, $_temp0.';
  }

  @override
  String get insA11yEmptyAllHidden =>
      'Стоимость не изменилась. Все счета скрыты фильтром.';

  @override
  String insA11yEmptyWindow(String period) {
    return 'Стоимость не изменилась. Нет записей за $period.';
  }

  @override
  String insAverageValue(String amount) {
    return 'Среднее $amount';
  }

  @override
  String insHighest(String label, String amount) {
    return 'макс. $label $amount';
  }

  @override
  String get insEmptyMonthsExcluded => 'пустые периоды исключены';

  @override
  String insStillRunning(String month) {
    return '$month ещё идёт';
  }

  @override
  String insDaysShort(int count) {
    return '$countд';
  }

  @override
  String insVsRange(String amount, String range, String percent) {
    return '$amount к $range ($percent)';
  }

  @override
  String insTooFewPeriods(int count) {
    return 'Записи лишь за $count периода — среднее и тренд не показаны';
  }

  @override
  String get insNoPreviousPeriod => 'нет записей за прошлый период';

  @override
  String insMonthlyBudget(String amount, String percent) {
    return 'Месячный бюджет $amount · $percent';
  }

  @override
  String insLeft(String amount) {
    return 'осталось $amount';
  }

  @override
  String insOverBudget(String amount) {
    return 'превышено на $amount';
  }

  @override
  String get insNoBudget => 'нет бюджета';

  @override
  String insBudgetSub(String amount, String percent) {
    return 'бюджет $amount · $percent';
  }

  @override
  String insBudgetSubOver(String amount, String percent) {
    return 'бюджет $amount · $percent превышен';
  }

  @override
  String get insAddBudget => 'Добавить бюджет';

  @override
  String insUnbudgetedTotal(String amount) {
    return '$amount в категориях без бюджета';
  }

  @override
  String get insSelectDateRange => 'Выбрать период…';

  @override
  String get insPeriod => 'Период';

  @override
  String insDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get insFilterAccountsNote => 'Скрытые счета убирают все цифры';

  @override
  String get insFilterCategoriesNote =>
      'Скрытые категории убирают только из списка';

  @override
  String get insSpendingList => 'Список расходов';

  @override
  String get insIncomeList => 'Список доходов';

  @override
  String insOfTotal(String amount) {
    return 'из $amount';
  }

  @override
  String insCategoriesShown(int shown, int total) {
    return '$shown из $total категорий';
  }

  @override
  String insAccountsShown(int shown, int total) {
    return '$shown из $total счетов';
  }

  @override
  String get insSpendingHistory => 'История трат за 6 месяцев';

  @override
  String insSavedOutsideWindow(String date) {
    return 'Сохранено на $date, вне этого периода';
  }

  @override
  String get insGoToDate => 'Перейти к дате';

  @override
  String insA11yPresetSelected(String name, String range) {
    return '$name, $range, выбрано';
  }

  @override
  String insA11yCustomRow(String range, String days) {
    return 'Выбрать период, сейчас $range, $days';
  }

  @override
  String insA11yChartCol(String label, String amount) {
    return '$label, $amount';
  }

  @override
  String insA11yChartColPartial(String label, String amount, String days) {
    return '$label, пока $amount, $days';
  }

  @override
  String insA11yChartColEmpty(String label) {
    return '$label, нет записей';
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
  String get arcReachedLabel => 'достигнуто';

  @override
  String get arcSuccessLabel => 'успех';

  @override
  String get arcAverageLabel => 'в среднем';

  @override
  String arcMonthsShort(int count) {
    return '$count мес';
  }

  @override
  String arcOneLine(String reached, String rate, String avg) {
    return '$reached достигнуто · $rate успех · $avg в среднем';
  }

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionEdit => 'Изменить';

  @override
  String get actionCopy => 'Копировать';

  @override
  String get obTitle => 'Начальный баланс';

  @override
  String get obNotSet => 'Не задано';

  @override
  String get obShiftsNote => 'Это сместит каждый остаток по этому счёту.';

  @override
  String get obDateTooLate =>
      'Дата начала не может быть позже первой операции.';

  @override
  String get obDeleteTitle => 'Удалить начальный баланс?';

  @override
  String obDeleteMsg(String amount) {
    return 'Каждый остаток по этому счёту изменится на $amount.';
  }

  @override
  String get obDeleteConfirm => 'Удалить начальный баланс';

  @override
  String get obCopyTitle => 'Копировать на счёт';

  @override
  String obA11y(String account, String amount) {
    return 'Начальный баланс, $account, $amount';
  }

  @override
  String get actionUndo => 'Отменить';

  @override
  String get actionApply => 'Применить';

  @override
  String get actionSearch => 'Поиск';

  @override
  String get actionMoveUp => 'Вверх';

  @override
  String get actionMoveDown => 'Вниз';

  @override
  String get actionCollapseAll => 'Свернуть все';

  @override
  String get actionExpandAll => 'Развернуть все';

  @override
  String get actionReset => 'Сбросить';

  @override
  String get balSearchAccounts => 'Поиск по счетам';

  @override
  String get balNoResults => 'Ничего не найдено';

  @override
  String get balNoAccountsYet => 'Начните с того, что есть';

  @override
  String get balNoAccountMatch =>
      'Ни один счёт или группа не подходят под запрос.';

  @override
  String get balEmptyBenefit =>
      'Вам больше не нужно самим считать, сколько у вас на самом деле денег.';

  @override
  String get balAddAccount => 'Добавить счёт';

  @override
  String get balAdjustFilter => 'Настроить фильтр';

  @override
  String get balSortTooltip => 'Сортировка';

  @override
  String get balSortDefault => 'Порядок по умолчанию';

  @override
  String get balPressHoldMove =>
      'Нажмите и удерживайте счёт, чтобы переместить';

  @override
  String get balFilterCategories => 'Фильтр категорий';

  @override
  String get balNoVisibleCategories => 'Нет видимых категорий';

  @override
  String balSeeAll(int count) {
    return 'Показать все $count  ›';
  }

  @override
  String transferFromTo(String from, String to) {
    return 'Перевод с $from на $to';
  }

  @override
  String get eaName => 'Название';

  @override
  String get eaGroup => 'Группа';

  @override
  String get eaCurrency => 'Валюта';

  @override
  String get eaStartingBalance => 'Начальный баланс';

  @override
  String get eaStartingBalanceLock =>
      'Чтобы исправить баланс, добавьте операцию';

  @override
  String get eaCreditLimit => 'Кредитный лимит';

  @override
  String get eaStatementDay => 'День выписки';

  @override
  String get eaPaymentDue => 'Срок платежа';

  @override
  String get eaNotSet => 'Не задано';

  @override
  String get eaHideFromBalance => 'Скрыть с Баланса';

  @override
  String get eaHideDesc => 'Остаётся в итогах, но исчезает из списков';

  @override
  String get eaRemoveThisAccount => 'Удалить этот счёт';

  @override
  String get eaRemovePermanent => 'Счёт удаляется безвозвратно';

  @override
  String get eaRemoveHasHistory =>
      'Есть история — будет архивирован, а не удалён';

  @override
  String eaRemoveTitle(String name) {
    return 'Удалить $name?';
  }

  @override
  String get eaArchivedMsg =>
      'У счёта есть история, поэтому он архивируется, а не удаляется.';

  @override
  String get eaDeleteMsg =>
      'У счёта нет операций, его можно удалить полностью.';

  @override
  String eaTxnStays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ваши $count операции останутся в журнале без изменений.',
      many: 'Ваши $count операций останутся в журнале без изменений.',
      few: 'Ваши $count операции останутся в журнале без изменений.',
      one: 'Ваша $count операция останется в журнале без изменений.',
    );
    return '$_temp0';
  }

  @override
  String eaGroupDropsBy(String group, String amount) {
    return '$group уменьшится на $amount.';
  }

  @override
  String get eaDisappearsPicker => 'Он исчезнет из всех списков выбора счёта.';

  @override
  String get eaCannotUndo => 'Это действие нельзя отменить.';

  @override
  String get eaArchiveAccount => 'Архивировать счёт';

  @override
  String get eaRemoveAccount => 'Удалить счёт';

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
  String get eaEditAccount => 'Изменить счёт';

  @override
  String balFilterActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Активен, $count скрыто',
      many: 'Активен, $count скрыто',
      few: 'Активен, $count скрыто',
      one: 'Активен, $count скрыт',
    );
    return '$_temp0';
  }

  @override
  String get balFilterOff => 'Выкл';

  @override
  String get balMoved => 'Перемещено';

  @override
  String get balMovedCustom => 'Перемещено · сортировка Вручную';

  @override
  String balTotalOf(String name) {
    return 'Всего: $name';
  }

  @override
  String balUtilization(String percent) {
    return 'Использование: $percent';
  }

  @override
  String get balOverdue => 'Просрочено';

  @override
  String balDue(String when) {
    return 'Оплата $when';
  }

  @override
  String balNextPayment(String date) {
    return 'Следующий платёж: $date';
  }

  @override
  String get actionDone => 'Готово';

  @override
  String get actionBack => 'Назад';

  @override
  String get filterTitle => 'Фильтр';

  @override
  String get sheetApply => 'Применить';

  @override
  String get sheetToday => 'Сегодня';

  @override
  String balNoBetween(String subject, String range) {
    return 'Нет «$subject» за период $range';
  }

  @override
  String get freqLessThanMonthly => 'Реже раза в месяц';

  @override
  String get freqAbout => 'Около ';

  @override
  String freqTimesAMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' раза в месяц',
      many: ' раз в месяц',
      few: ' раза в месяц',
      one: ' раз в месяц',
    );
    return '$_temp0';
  }

  @override
  String txnDeleteEntryTitle(String type) {
    return 'Удалить $type?';
  }

  @override
  String get txnDeleteEntryMessage =>
      'Запись удаляется навсегда, и балансы ниже возвращаются к прежним значениям.';

  @override
  String get txnDeleteNothingElse => 'Больше ничего в журнале не меняется.';

  @override
  String get txnDeleteEntryConfirm => 'Удалить запись';

  @override
  String get freqLastOne => ' · последний раз ';

  @override
  String txnBudgetImpact(Object name, Object before, Object after) {
    return '$name: бюджет $before → $after';
  }

  @override
  String get txnRevaluation => 'Переоценка';

  @override
  String get txnTransferOut => 'Перевод со счёта';

  @override
  String get txnTransferIn => 'Перевод на счёт';

  @override
  String get plTabBudgets => 'Бюджеты';

  @override
  String get plTabGoals => 'Цели';

  @override
  String get plTabSchedule => 'График';

  @override
  String get plNoBudgetsYet => 'Бюджет — это лимит категории';

  @override
  String get plNoBudgetsMsg =>
      'Задайте категории месячный лимит — и каждая трата по ней пойдёт в счёт этого лимита.';

  @override
  String get plBudgeted => 'В бюджете';

  @override
  String get plNoBudgetSet => 'Бюджет не задан';

  @override
  String get plSet => 'Задать';

  @override
  String get plNoGoalsYet => 'Цели отвечают на «когда»';

  @override
  String get plNoGoalsMsg =>
      'Задайте цель, и FinLens рассчитает месячный темп.';

  @override
  String get plNewGoal => 'Новая цель';

  @override
  String get plNewTask => 'Новая задача';

  @override
  String get plNewBudget => 'Новый бюджет';

  @override
  String get plCompleteReady => 'Готово · можно в архив';

  @override
  String get plNoTargetDate => 'Дата не задана';

  @override
  String get plMoNeeded => '/мес нужно';

  @override
  String get plComingIn => 'Поступления';

  @override
  String get plGoingOut => 'Списания';

  @override
  String get schOverdue => 'Просрочено';

  @override
  String get schThisWeek => 'На этой неделе';

  @override
  String get plNothingScheduled => 'Планируйте, что впереди';

  @override
  String get plNothingSchedMsg =>
      'Счета, зарплаты и подписки, которые вы планируете, появятся здесь до того, как случатся.';

  @override
  String get plLeftThisMonth => 'Осталось за месяц';

  @override
  String get plOf => 'из';

  @override
  String get plBudgetWord => 'бюджета';

  @override
  String get plSavedTowardGoals => 'Накоплено на цели';

  @override
  String get plPace => 'Темп';

  @override
  String plLeftOfAmount(Object amount) {
    return 'осталось из $amount';
  }

  @override
  String plOverAmount(Object amount) {
    return 'сверх $amount';
  }

  @override
  String plPctSpent(Object pct) {
    return '$pct потрачено';
  }

  @override
  String plDayOfMonth(int day, int length) {
    return 'день $day из $length';
  }

  @override
  String plCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count категории',
      many: '$count категорий',
      few: '$count категории',
      one: '$count категория',
    );
    return '$_temp0';
  }

  @override
  String plSemRowOver(Object name, Object spent, Object limit) {
    return '$name, превышен бюджет, $spent из $limit';
  }

  @override
  String plSemRowNear(Object name, Object spent, Object limit) {
    return '$name, близко к лимиту, $spent из $limit';
  }

  @override
  String plSemRowNormal(Object name, Object spent, Object limit) {
    return '$name, $spent из $limit';
  }

  @override
  String plPaymentsOverdue(int count, Object amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count платежа просрочено',
      many: '$count платежей просрочено',
      few: '$count платежа просрочено',
      one: '$count платёж просрочен',
    );
    return '$_temp0 · $amount';
  }

  @override
  String get fieldCategory => 'Категория';

  @override
  String get fieldSelectAccount => 'Выберите счёт';

  @override
  String get fieldDirection => 'Направление';

  @override
  String get actionUse => 'Взять';

  @override
  String get actionRestore => 'Восстановить';

  @override
  String countMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }

  @override
  String get ebTitle => 'Изменить бюджет';

  @override
  String get ebMonthlyLimit => 'Месячный лимит';

  @override
  String get ebRollOver => 'Переносить остаток';

  @override
  String get ebRollOverDesc => 'Добавлять остаток к следующему месяцу';

  @override
  String get ebWarnAt => 'Предупредить при';

  @override
  String get ebRemoveBudget => 'Удалить бюджет';

  @override
  String ebAverage(Object average, Object suggestion) {
    return 'В среднем $average. Попробуйте $suggestion?';
  }

  @override
  String ebRemoveTitle(Object name) {
    return 'Удалить бюджет «$name»?';
  }

  @override
  String get ebRemoveMsg =>
      'Вы перестанете отслеживать лимит для этой категории.';

  @override
  String ebCategoryStays(Object name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ваши $count операции не тронуты.',
      many: 'Ваши $count операций не тронуты.',
      few: 'Ваши $count операции не тронуты.',
      one: 'Ваша $count операция не тронута.',
    );
    return 'Категория «$name» остаётся. $_temp0';
  }

  @override
  String get ebWarningsDisappear =>
      'Предупреждения и полосы прогресса для этой категории исчезнут.';

  @override
  String ebTotalDrops(Object from, Object to) {
    return 'Общий месячный бюджет уменьшится с $from до $to.';
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
  String get egTitle => 'Изменить цель';

  @override
  String get egGoalName => 'Название цели';

  @override
  String get egType => 'Тип';

  @override
  String get egTargetAmount => 'Целевая сумма';

  @override
  String get egTargetDate => 'Целевая дата';

  @override
  String get egMoneyKeptIn => 'Деньги хранятся на';

  @override
  String get egAutoContribute => 'Автопополнение';

  @override
  String get egAutoContributeDesc => 'Создаёт ежемесячный перевод в эту цель';

  @override
  String get egMonthlyContribution => 'Ежемесячный взнос';

  @override
  String get egMarkReached => 'Отметить достигнутой';

  @override
  String get egMarkReachedDesc => 'Деньги потрачены, цель выполнена';

  @override
  String get egGiveUp => 'Пока отказаться';

  @override
  String get egDeleteGoal => 'Удалить цель';

  @override
  String get egDeleteGoalDesc => 'Как будто её не было';

  @override
  String egMarkReachedTitle(Object name) {
    return 'Отметить «$name» достигнутой?';
  }

  @override
  String get egMarkReachedMsg =>
      'Поздравляем — цель перемещается в архив как успешная.';

  @override
  String egReachedAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return 'Записано как достигнутое за $_temp0, учитывается в статистике целей.';
  }

  @override
  String get egPastTxnStay => 'Прошлые операции остаются в журнале.';

  @override
  String get egLeavesStops => 'Цель покидает список и перестаёт отслеживаться.';

  @override
  String get egAutoStops => 'Ежемесячное автопополнение прекращается.';

  @override
  String get egNotYet => 'Ещё нет';

  @override
  String egGiveUpTitle(Object name) {
    return 'Отказаться от «$name»?';
  }

  @override
  String get egGiveUpMsg =>
      'Отслеживание прекращается, но отложенные деньги остаются на месте.';

  @override
  String egSavedStaysIn(Object amount, Object account) {
    return '$amount остаются на $account.';
  }

  @override
  String get egYourAccount => 'вашем счёте';

  @override
  String get egRestoreLater => 'Позже можно восстановить из архива.';

  @override
  String get egLeavesList => 'Цель покидает список.';

  @override
  String egDeleteTitle(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String get egDeleteMsg =>
      'Используйте только если цель создана по ошибке — она не оставит следа в истории.';

  @override
  String get egBalancesUnchanged => 'Балансы ваших счетов не меняются.';

  @override
  String get egNotInArchive => 'Она не появится в архиве.';

  @override
  String get egExcludedStats => 'Она исключена из статистики достижения целей.';

  @override
  String get egRecurringCancelled => 'Правило регулярного перевода отменяется.';

  @override
  String egPerMonthTrack(Object amount) {
    return '$amount/мес, чтобы успеть в срок';
  }

  @override
  String egAutoContributeOn(Object amount, Object day) {
    return '$amount $day';
  }

  @override
  String egKeepsStops(Object amount) {
    return 'Сохраняет $amount, прекращает отслеживание';
  }

  @override
  String get egSaved => 'накоплено';

  @override
  String get egToGo => 'осталось';

  @override
  String get ebWhatSpent => 'Сколько вы реально потратили';

  @override
  String get ebSpent => 'потрачено';

  @override
  String get etTitle => 'Изменить задачу';

  @override
  String get etTaskTitle => 'Название задачи';

  @override
  String get etPaidFrom => 'Оплата с';

  @override
  String get etPaidInto => 'Оплата на';

  @override
  String get etLinkedAccount => 'Связанный счёт';

  @override
  String get etPayOut => 'Списание −';

  @override
  String get etPayIn => 'Поступление +';

  @override
  String get etExpectedAmount => 'Ожидаемая сумма';

  @override
  String get etCategoryHint => 'Куда «Отметить оплаченным» запишет операцию';

  @override
  String get etNextDue => 'Следующий срок';

  @override
  String get etRepeats => 'Повтор';

  @override
  String get etOneOff => 'Разовая задача';

  @override
  String get etRemindMe => 'Напомнить';

  @override
  String etRemindBefore(Object days, Object time) {
    return 'за $days дн., $time';
  }

  @override
  String get etMarkPaid => 'Отметить оплаченным';

  @override
  String get etMarkPaidExpense => 'Создаёт расход в журнале';

  @override
  String get etMarkPaidIncome => 'Создаёт доход в журнале';

  @override
  String get etSkipThisMonth => 'Пропустить этот месяц';

  @override
  String etSeriesContinues(Object month) {
    return 'Серия продолжится в $month';
  }

  @override
  String get etDeleteWholeSeries => 'Удалить всю серию';

  @override
  String etAllFutureReminders(Object title) {
    return 'Все будущие напоминания «$title»';
  }

  @override
  String etSkippedNext(Object date) {
    return 'Пропущено · следующее $date';
  }

  @override
  String etDeleteOnly(Object date) {
    return 'Удалить только $date';
  }

  @override
  String etDeleteOnlyTitle(Object date) {
    return 'Удалить только $date?';
  }

  @override
  String get etJustThisOne => 'Удаляется только это повторение.';

  @override
  String get etOneOffRemoved => 'Эта разовая задача удаляется.';

  @override
  String etSeriesContinuesOn(Object date) {
    return 'Серия продолжится $date.';
  }

  @override
  String get etNoLedgerEntry => 'Запись в журнале не создаётся и не удаляется.';

  @override
  String get etLedgerUntouched => 'Ваш журнал не затрагивается.';

  @override
  String etDisappears(Object date) {
    return '$date исчезает из вашего графика.';
  }

  @override
  String etDeleteDate(Object date) {
    return 'Удалить $date';
  }

  @override
  String etDeleteSeriesTitle(Object title) {
    return 'Удалить всю серию «$title»?';
  }

  @override
  String get etDeleteSeriesMsg =>
      'Удаляются все будущие повторения, а не только следующее.';

  @override
  String get etPaymentsStay => 'Уже записанные платежи остаются в журнале.';

  @override
  String get etAllRemindersCancelled => 'Все будущие напоминания отменяются.';

  @override
  String etOutgoingsDrop(Object amount) {
    return 'Ваши месячные списания уменьшатся на $amount.';
  }

  @override
  String get etDeleteSeries => 'Удалить серию';

  @override
  String etRecordedInLedger(Object title) {
    return '$title записано в журнал';
  }

  @override
  String etRepeatsCadence(Object cadence) {
    return 'Повтор: $cadence';
  }

  @override
  String bdAveraging(Object avg, Object limit, Object count) {
    return 'В среднем $avg · превышение лимита $limit в $count из 6';
  }

  @override
  String get bdNothingSpent => 'В этом месяце здесь ничего не потрачено.';

  @override
  String get arEmpty => 'Архив пуст';

  @override
  String get arEmptyMsg =>
      'Достигнутые и заброшенные цели, а также удалённые бюджеты хранятся здесь.';

  @override
  String get arFootnote =>
      'Архивные элементы не показываются в Планировщике и не влияют на итоги. Их прошлые операции остаются в журнале.';

  @override
  String get arGroupFinished => 'Завершено';

  @override
  String get arGroupUnfinished => 'Не завершено';

  @override
  String get arGroupCanComeBack => 'Можно вернуть';

  @override
  String get arGroupRecentlyDeleted => 'Недавно удалённые';

  @override
  String get arTypeGoal => 'Цель';

  @override
  String get arTypeTask => 'Задача';

  @override
  String get arTypeBudget => 'Бюджет';

  @override
  String get arTypeAccount => 'Счёт';

  @override
  String arReachedLine(Object date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return 'достигнуто $date · за $_temp0';
  }

  @override
  String arStoppedLine(Object date, Object saved, Object target) {
    return 'остановлено $date · $saved из $target';
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
    return 'удалено $date';
  }

  @override
  String get arClearFinished => 'Очистить';

  @override
  String get arClearUnfinished => 'Очистить';

  @override
  String get arDeleteNow => 'Удалить сейчас';

  @override
  String get arClearScopedTitle => 'Очистить это навсегда?';

  @override
  String arClearScopedMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента удаляются навсегда. Это нельзя отменить.',
      many: '$count элементов удаляются навсегда. Это нельзя отменить.',
      few: '$count элемента удаляются навсегда. Это нельзя отменить.',
      one: '$count элемент удаляется навсегда. Это нельзя отменить.',
    );
    return '$_temp0';
  }

  @override
  String get arTxnStay => 'Все связанные операции остаются в журнале.';

  @override
  String get arBalancesUnaffected => 'Балансы счетов не затрагиваются.';

  @override
  String get arRestoreImpossible => 'Восстановление больше невозможно.';

  @override
  String get arStatsDisappear =>
      'История достигнутых целей исчезает из статистики.';

  @override
  String get arClearArchive => 'Очистить архив';

  @override
  String get stateOn => 'Вкл';

  @override
  String get stateOff => 'Выкл';

  @override
  String get filterAll => 'Все';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get ldgShowDescriptions => 'Показывать описания';

  @override
  String get ldgSortTransactions => 'Сортировать операции';

  @override
  String get ldgFilterTransactions => 'Фильтровать операции';

  @override
  String get ldgSearchTransactions => 'Искать операции';

  @override
  String ldgFilterActive(Object shown, Object total) {
    return 'Активен, $shown из $total показано';
  }

  @override
  String ldgNoResultsFor(Object query) {
    return 'Ничего не найдено по «$query»';
  }

  @override
  String get ldgNoMatchFilter => 'Нет операций по вашему фильтру';

  @override
  String get ldgClearFilter => 'Сбросить фильтр';

  @override
  String get ldgNothingHere => 'Здесь живёт каждая операция';

  @override
  String get ldgNothingHereMsg =>
      'Записывайте расходы и поступления. Балансы, бюджеты и цели берут данные из этого списка.';

  @override
  String ldgNothingRecordedInMonth(Object month) {
    return 'Нет записей за $month';
  }

  @override
  String get ldgAddEntry => 'Добавить запись';

  @override
  String get ldgCategories => 'Категории';

  @override
  String get ldgAccounts => 'Счета';

  @override
  String get ldgTags => 'Метки';

  @override
  String get ldgType => 'Тип';

  @override
  String get ldgDirection => 'Направление';

  @override
  String get ldgAmount => 'Сумма';

  @override
  String get ldgClearCustomRange => 'Сбросить период';

  @override
  String ldgSpentOf(Object expense, Object income) {
    return 'Потрачено $expense из $income';
  }

  @override
  String get ldgOut => 'Расход';

  @override
  String get ldgLeft => 'Остаток';

  @override
  String get ldgChangePeriod => 'Сменить период';

  @override
  String get ldgBalance => 'Баланс';

  @override
  String get ldgTransactionDeleted => 'Операция удалена';

  @override
  String get ldgNoTransactions => 'Нет операций';

  @override
  String get ldgPeriod => 'Период';

  @override
  String get ldgShow => 'Показ';

  @override
  String get ldgCustomRange => 'Свой период';

  @override
  String get ldgPreviousYear => 'Предыдущий год';

  @override
  String get ldgNextYear => 'Следующий год';

  @override
  String ldgShowCountOf(Object count, Object total) {
    return 'Показать $count из $total';
  }

  @override
  String ldgShowAll(Object count) {
    return 'Показать все $count';
  }

  @override
  String ldgPlusMore(Object count) {
    return '+$count ещё';
  }

  @override
  String get ldgNetIn => 'Чистый приход';

  @override
  String get ldgNetOut => 'Чистый расход';

  @override
  String get ldgMoneyIn => 'Приход';

  @override
  String get ldgMoneyOut => 'Расход';

  @override
  String get ldgNoCash => 'Без денег';

  @override
  String get ldgIn => 'Приход';

  @override
  String ldgRangeHint(Object min, Object max) {
    return 'Операции здесь от $min до $max';
  }

  @override
  String ldgSearchWithin(Object labels) {
    return 'Искать в $labels';
  }

  @override
  String ldgSelectAllIn(Object section) {
    return 'Выбрать все в «$section»';
  }

  @override
  String ldgClearSelection(Object section) {
    return 'Снять выбор «$section»';
  }

  @override
  String get ldgSelectAll => 'Выбрать все';

  @override
  String get ldgClear => 'Снять';

  @override
  String get ldgMin => 'Мин';

  @override
  String get ldgMax => 'Макс';

  @override
  String get ldgResetFilter => 'Сбросить фильтр';

  @override
  String get ldgSelectOthers => 'Выбрать остальные';

  @override
  String ldgNSelected(Object n) {
    return '$n выбрано';
  }

  @override
  String get ldgAllSelected => 'все';

  @override
  String ldgClearSection(Object section) {
    return 'Очистить выбор: $section';
  }

  @override
  String ldgMoreCategories(Object n) {
    return 'ещё $n категорий';
  }

  @override
  String ldgMoreAccounts(Object n) {
    return 'ещё $n счетов';
  }

  @override
  String ldgMoreTags(Object n) {
    return 'ещё $n тегов';
  }

  @override
  String ldgNHiddenSelected(Object n) {
    return '$n выбрано';
  }

  @override
  String ldgNMatches(Object n) {
    return '$n совпадений';
  }

  @override
  String ldgNResults(Object n) {
    return '$n результатов';
  }

  @override
  String get ldgExpenses => 'Расходы';

  @override
  String get ldgIncomes => 'Доходы';

  @override
  String get ldgExpenseCategoriesA11y => 'категории расходов';

  @override
  String get ldgIncomeSourcesA11y => 'источники дохода';

  @override
  String get ldgTransfersHaveNoCategory => 'У переводов нет категории.';

  @override
  String get ldgRevaluationsMoveNoCash => 'Переоценка не двигает деньги.';

  @override
  String ldgAmountRange(Object min, Object max) {
    return '$min – $max';
  }

  @override
  String get tdFrom => 'Откуда';

  @override
  String get tdTo => 'Куда';

  @override
  String get tdDeletedAccount => 'Удалённый счёт';

  @override
  String get tdRate => 'Курс';

  @override
  String get tdNote => 'ЗАМЕТКА';

  @override
  String get tdNetWorth => 'Капитал';

  @override
  String get tdUnchanged => 'Без изменений';

  @override
  String get stDetailNote => 'Заметка';

  @override
  String get stDetailWhen => 'Когда';

  @override
  String get stDetailPaidWith => 'Оплачено с';

  @override
  String get stDetailTags => 'Метки';

  @override
  String get qaAmount => 'Сумма';

  @override
  String get qaDue => 'Срок';

  @override
  String get qaNewBalance => 'Новый баланс';

  @override
  String get qaTarget => 'Цель';

  @override
  String get qaDate => 'Дата';

  @override
  String get qaTag => 'Метка';

  @override
  String get qaNone => 'Нет';

  @override
  String get qaNote => 'Заметка';

  @override
  String get qaAddNote => 'Добавить заметку';

  @override
  String get qaOptional => 'Необязательно';

  @override
  String get qaSplit => 'Разбить';

  @override
  String qaSplitCategories(Object count) {
    return '$count категорий';
  }

  @override
  String get qaGroupRequired => 'Обязательно';

  @override
  String get qaGroupOptional => 'Необязательно';

  @override
  String get qaFrom => 'Откуда';

  @override
  String get qaTo => 'Куда';

  @override
  String get qaChooseAccount => 'Выберите счёт';

  @override
  String get qaChooseCategory => 'Выберите категорию';

  @override
  String get qaChooseSource => 'Выберите источник';

  @override
  String get qaPayFrom => 'Оплатить с';

  @override
  String get qaDepositInto => 'Зачислить на';

  @override
  String get qaTransferFrom => 'Перевод с';

  @override
  String get qaTransferTo => 'Перевод на';

  @override
  String get qaRate => 'Курс';

  @override
  String get qaReceives => 'Получит';

  @override
  String get qaFee => 'Комиссия';

  @override
  String get qaAccount => 'Счёт';

  @override
  String get qaRevalueAccount => 'Переоценить счёт';

  @override
  String get qaCurrent => 'Текущий';

  @override
  String get qaDifference => 'Разница';

  @override
  String get qaReason => 'Причина';

  @override
  String get qaAdjustment => 'Корректировка';

  @override
  String get qaBalanceUnchanged => 'Баланс без изменений';

  @override
  String get qaName => 'Название';

  @override
  String get qaNameYourGoal => 'Назовите цель';

  @override
  String get qaGoalNameHint => 'напр. MacBook Pro M4';

  @override
  String get qaSetDate => 'Задать дату';

  @override
  String get qaFundingAccount => 'Счёт пополнения';

  @override
  String get qaStartingAmount => 'Начальная сумма';

  @override
  String get qaIconColour => 'Значок и цвет';

  @override
  String get qaTapToChange => 'Нажмите, чтобы изменить';

  @override
  String get qaAutoFund => 'Автопополнение';

  @override
  String get qaRemind => 'Напоминание';

  @override
  String get qaTaskPlaceholder => 'Что нужно сделать?';

  @override
  String get qaExchangeRate => 'Обменный курс';

  @override
  String qaFxRate(Object from, Object to) {
    return '1 $from = ? $to';
  }

  @override
  String get qaWhatAdding => 'Что вы добавляете?';

  @override
  String get qaDeleteEntry => 'Удалить эту запись';

  @override
  String get qaBalanceAdjustment => 'Корректировка баланса';

  @override
  String get qaRecurring => 'Повторяющаяся';

  @override
  String qaLinkedSplit(Object count) {
    return 'Это одна из $count связанных операций разбивки.';
  }

  @override
  String qaDeleteAll(Object count) {
    return 'Удалить все $count';
  }

  @override
  String get qaDeleteJustLine => 'Удалить только эту строку';

  @override
  String get qaSaveExpense => 'Сохранить расход';

  @override
  String get qaSaveIncome => 'Сохранить доход';

  @override
  String get qaSaveTransfer => 'Сохранить перевод';

  @override
  String get qaSaveAdjustment => 'Сохранить корректировку';

  @override
  String get qaCreateGoal => 'Создать цель';

  @override
  String get qaCreateTask => 'Создать задачу';

  @override
  String qaSaved(Object type) {
    return '$type: сохранено';
  }

  @override
  String get qaBlockAmount => 'Введите сумму';

  @override
  String get qaBlockAccount => 'Выберите счёт';

  @override
  String get qaBlockCategory => 'Выберите категорию';

  @override
  String get qaBlockSource => 'Выберите источник';

  @override
  String get qaBlockSplit => 'Сведите разбивку';

  @override
  String get qaBlockSourceAccount => 'Выберите счёт списания';

  @override
  String get qaBlockDestination => 'Выберите счёт зачисления';

  @override
  String get qaBlockBalanceUnchanged => 'Баланс без изменений';

  @override
  String get qaBlockNameGoal => 'Назовите цель';

  @override
  String get qaBlockSetTarget => 'Задайте цель';

  @override
  String get qaBlockSetTargetDate => 'Задайте целевую дату';

  @override
  String get qaBlockFunding => 'Выберите счёт пополнения';

  @override
  String get qaBlockNameTask => 'Назовите задачу';

  @override
  String get qaBlockDueDate => 'Задайте срок';

  @override
  String get qaNewAccount => 'Новый счёт';

  @override
  String get qaNoAccountsYet => 'Счетов пока нет';

  @override
  String get qaNoAccountsYetBody =>
      'Для записи этой операции понадобится счёт.';

  @override
  String get qaNewCategory => 'Новая категория';

  @override
  String get qaNewShort => 'Новый';

  @override
  String get qaSelectAccount => 'Выберите счёт';

  @override
  String get qaSearchAccounts => 'Поиск по счетам';

  @override
  String get qaSearchCategories => 'Поиск по категориям';

  @override
  String qaAccountSearchNoMatch(Object query) {
    return 'Нет счёта по запросу $query.';
  }

  @override
  String qaNoCategoryMatch(Object query) {
    return 'Нет категории по запросу «$query».';
  }

  @override
  String get qaExpenseCategory => 'Категория расходов';

  @override
  String get qaIncomeCategory => 'Категория доходов';

  @override
  String get qaBudgetWhichCategory => 'Для какой категории бюджет?';

  @override
  String qaThisMonthSpend(Object amount) {
    return '$amount в этом месяце';
  }

  @override
  String get qaNothingSpentYet => 'Пока ничего';

  @override
  String get qaAllCategoriesBudgeted => 'У каждой категории уже есть бюджет';

  @override
  String get qaSearchCleared => 'Поиск очищен';

  @override
  String get qaClearSearch => 'Очистить поиск';

  @override
  String get qaCategoryName => 'Название категории';

  @override
  String get qaIcon => 'Значок';

  @override
  String get qaColour => 'Цвет';

  @override
  String get qaMonthlyBudget => 'Месячный бюджет (необязательно)';

  @override
  String get qaCategoryPlannerNote =>
      'Эта категория также появится в Планировщик → Бюджет расходов, где можно отслеживать траты по ней.';

  @override
  String get qaCreateSelect => 'Создать и выбрать';

  @override
  String get qaAccountName => 'Название счёта';

  @override
  String get qaAccountExists => 'Счёт с таким названием уже существует';

  @override
  String get qaAssets => 'Активы';

  @override
  String get qaLiabilities => 'Обязательства';

  @override
  String get qaAmountOwed => 'Сумма долга';

  @override
  String get qaPaymentDay => 'День платежа';

  @override
  String get qaOwedHint =>
      'Введите сумму долга положительным числом — она уменьшает капитал.';

  @override
  String get qaStartingBalanceHint =>
      'Введите один раз. Дальше баланс рассчитывается по вашим операциям.';

  @override
  String get qaPaymentDayHint =>
      'Для более коротких месяцев используется их последний день.';

  @override
  String get qaDiscardTitle => 'Отменить создание счёта?';

  @override
  String get qaDiscardBody => 'Введённые данные не будут сохранены.';

  @override
  String get qaDiscardConfirm => 'Не сохранять';

  @override
  String get qaMoreIcons => 'Больше значков';

  @override
  String get qaChooseIcon => 'Выберите значок';

  @override
  String get qaSearchIcons => 'Поиск значков';

  @override
  String get qaResults => 'Результаты';

  @override
  String get qaNoIconsMatch => 'Нет подходящих значков';

  @override
  String get ssRemoveSplit => 'Убрать разбивку';

  @override
  String get ssSplitByCategory => 'Разбить по категориям';

  @override
  String ssTotalCovers(Object total, Object covered) {
    return 'Всего $total · $covered';
  }

  @override
  String get ssRemoveLine => 'Убрать строку';

  @override
  String get ssAddCategory => 'Добавить категорию';

  @override
  String get ssRemaining => 'Осталось';

  @override
  String get ssOverBy => 'Превышение на';

  @override
  String get ssSplitEvenly => 'Поровну';

  @override
  String get ssRestToLast => 'Остаток в последнюю';

  @override
  String get ssApplySplit => 'Применить разбивку';

  @override
  String get ssApplySplitBlocked =>
      'Применить разбивку можно, когда остаток равен нулю';

  @override
  String get rsRepeat => 'Повтор';

  @override
  String get rsHowOften => 'Как часто';

  @override
  String get rsEveryWeek => 'Каждую неделю';

  @override
  String get rsEvery2Weeks => 'Каждые 2 недели';

  @override
  String get rsEveryMonth => 'Каждый месяц';

  @override
  String get rsEveryQuarter => 'Каждый квартал';

  @override
  String get rsEveryYear => 'Каждый год';

  @override
  String get rsShortWeekly => 'еженедельно';

  @override
  String get rsShortBiweekly => 'раз в 2 недели';

  @override
  String get rsShortMonthly => 'ежемесячно';

  @override
  String get rsShortQuarterly => 'ежеквартально';

  @override
  String get rsShortYearly => 'ежегодно';

  @override
  String rsSummary(Object cadence, Object date) {
    return 'Повтор: $cadence, с $date. Управляется в Планировщике.';
  }

  @override
  String rsWeekly(Object weekday) {
    return 'каждую неделю в $weekday';
  }

  @override
  String rsMonthly(Object day) {
    return '$day числа каждого месяца';
  }

  @override
  String rsQuarterly(Object day) {
    return '$day числа, каждые 3 месяца';
  }

  @override
  String rsYearly(Object day, Object month) {
    return 'каждый год $day $month';
  }

  @override
  String get rsNext => 'Далее';

  @override
  String get rsShorterMonths => 'В коротких месяцах — последний день';

  @override
  String get rsEveryDay => 'Каждый день';

  @override
  String get rsWeekdays => 'Будни';

  @override
  String rsNDaysWeek(int count) {
    return '$count дн. в неделю';
  }

  @override
  String rsNDaysMonth(int count) {
    return '$count дн. в месяц';
  }

  @override
  String rsMonthlyOnDay(Object day) {
    return 'Каждый месяц $day числа';
  }

  @override
  String rsDaysJoin(Object head, Object last) {
    return '$head и $last';
  }

  @override
  String get qaExchange => 'Обмен';

  @override
  String get qaEnterNewBalance => 'Введите новый баланс';

  @override
  String get qaDeleteSplit => 'Удалить разбивку';

  @override
  String get qaBooksPrefix => 'Записывает ';

  @override
  String get qaBooksSuffix =>
      ' корректировку сегодняшней датой. Прошлые отчёты не переписываются.';

  @override
  String get qaPutAsidePrefix => 'Откладывайте ';

  @override
  String qaPerMonth(Object amount) {
    return '$amount / месяц';
  }

  @override
  String qaToReachMonths(Object months) {
    return ' в течение $months мес., чтобы успеть в срок.';
  }

  @override
  String qaCreated(Object date) {
    return 'Создано $date';
  }

  @override
  String qaEditedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · изменено $count раза',
      many: ' · изменено $count раз',
      few: ' · изменено $count раза',
      one: ' · изменено $count раз',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get a11yShown => 'показано';

  @override
  String get a11yPartiallyShown => 'частично показано';

  @override
  String get a11yHidden => 'скрыто';

  @override
  String get a11yDoubleTapShow => 'Двойное нажатие — показать все счета';

  @override
  String get a11yDoubleTapHide => 'Двойное нажатие — скрыть все счета';

  @override
  String get a11yInternalTransfer => 'внутренний перевод';

  @override
  String get a11yOfAssets => 'от активов';

  @override
  String get a11yOfLiabilities => 'от обязательств';

  @override
  String get a11yBalanceWord => 'баланс';

  @override
  String a11yAccountBalance(Object account, Object amount) {
    return 'баланс $account $amount';
  }

  @override
  String get qaUnavailableNoAmount => 'недоступно, пока не введена сумма';

  @override
  String get bfNetWorthFiltered => 'КАПИТАЛ · ФИЛЬТР';

  @override
  String bfVisibleCategories(int visible, int total) {
    return '$visible из $total категорий';
  }

  @override
  String bfVisibleAccounts(int visible, int total) {
    return '$visible из $total счетов';
  }

  @override
  String get bdAMonth => 'в месяц';

  @override
  String get bdSpent => 'потрачено';

  @override
  String bdSpentOver(String over) {
    return 'потрачено · $over сверх';
  }

  @override
  String bdDayOfMonth(int day, int total) {
    return 'день $day из $total';
  }

  @override
  String get bdAgainstLimit => 'ОТНОСИТЕЛЬНО ЛИМИТА';

  @override
  String get mpMonth => 'МЕСЯЦ';

  @override
  String get srDateRange => 'ДИАПАЗОН ДАТ';

  @override
  String get srCustomRange => 'СВОЙ ПЕРИОД';

  @override
  String get calFrom => 'С';

  @override
  String get calTo => 'ПО';

  @override
  String plOfTarget(String target) {
    return 'из $target цели';
  }

  @override
  String get dsKeepIt => 'Оставить';

  @override
  String get qaExampleCategory => 'напр. Продукты';

  @override
  String get qaExampleAccount => 'напр. Основной счёт';

  @override
  String get qaExampleGoal => 'напр. MacBook Pro M4';

  @override
  String get goalSecSaving => 'Накопление';

  @override
  String get goalSecPayingOff => 'Погашение';

  @override
  String get goalSecWaitingOn => 'Ожидание';

  @override
  String get goalSecEarning => 'Заработок';

  @override
  String goalOfTotal(Object current, Object target) {
    return '$current из $target';
  }

  @override
  String goalLeftTotal(Object amount) {
    return 'осталось $amount';
  }

  @override
  String goalOwedTotal(Object amount) {
    return '$amount к получению';
  }

  @override
  String get goalSourceUnavailable => 'Источник недоступен';

  @override
  String get goalReached => 'Достигнуто';

  @override
  String goalReachedEarly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Достигнуто на $days дней раньше',
      many: 'Достигнуто на $days дней раньше',
      few: 'Достигнуто на $days дня раньше',
      one: 'Достигнуто на $days день раньше',
    );
    return '$_temp0';
  }

  @override
  String get goalNothingYet => 'пока ничего';

  @override
  String goalAmountIn(Object amount) {
    return 'получено $amount';
  }

  @override
  String goalAmountOf(Object amount, Object whole) {
    return '$amount из $whole';
  }

  @override
  String goalDueLine(Object date, Object tail) {
    return 'Срок $date · $tail';
  }

  @override
  String get goalFunded => 'Обеспечено';

  @override
  String goalRefill(Object amount) {
    return 'Пополнить $amount';
  }

  @override
  String goalBehind(Object phrase) {
    return 'Отставание · $phrase';
  }

  @override
  String plGoalRateSave(Object rate) {
    return 'откладывать $rate/мес';
  }

  @override
  String plGoalRatePay(Object rate) {
    return 'платить $rate/мес';
  }

  @override
  String plGoalRateCollect(Object rate) {
    return 'получать $rate/мес';
  }

  @override
  String plGoalRateEarn(Object rate) {
    return 'зарабатывать $rate/мес';
  }

  @override
  String goalAhead(Object rate) {
    return 'Опережение · $rate/мес';
  }

  @override
  String goalOnTrack(Object rate) {
    return 'В графике · $rate/мес';
  }

  @override
  String get plGoalFilterButton => 'Фильтр целей';

  @override
  String plGoalScopeAllSome(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n цели',
      many: '$n целей',
      few: '$n цели',
      one: '$n цель',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m требуют внимания',
      many: '$m требуют внимания',
      few: '$m требуют внимания',
      one: '$m требует внимания',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String plGoalScopeAllNone(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n цели',
      many: '$n целей',
      few: '$n цели',
      one: '$n цель',
    );
    return '$_temp0 · все в графике';
  }

  @override
  String get plGoalScopeOneAttention => '1 цель · требует внимания';

  @override
  String get plGoalScopeOneOnTrack => '1 цель · в графике';

  @override
  String plGoalScopeNeeds(int m, int n) {
    return 'Требуют внимания · $m из $n';
  }

  @override
  String plGoalScopeOnTrack(int k, int n) {
    return 'В графике · $k из $n';
  }

  @override
  String get plGoalStatus => 'СТАТУС';

  @override
  String get plGoalFilterAll => 'Все';

  @override
  String get plGoalFilterNeeds => 'Требуют внимания';

  @override
  String get plGoalFilterOnTrack => 'В графике';

  @override
  String get plGoalArchiveNote =>
      'Достигнутых и отменённых целей здесь нет — они в Архиве.';

  @override
  String get plGoalNoneNeed => 'Нет целей, требующих внимания';

  @override
  String get plGoalNoneOnTrack => 'Нет целей в графике';

  @override
  String get plGoalShowAll => 'Показать все';

  @override
  String plGoalRowA11y(Object option, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count цели',
      many: '$count целей',
      few: '$count цели',
      one: '$count цель',
    );
    return '$option, $_temp0';
  }

  @override
  String goalPerMonth(Object amount) {
    return '$amount в месяц';
  }

  @override
  String get goalNewTitle => 'Новая цель';

  @override
  String get goalWatching => 'Отслеживает';

  @override
  String get goalSource => 'Источник';

  @override
  String get goalSourceLocked => 'Смена счёта — это новая цель.';

  @override
  String get goalSetDateHint => 'Укажите дату или сумму в месяц';

  @override
  String get goalMonthly => 'В месяц';

  @override
  String get goalEnterRate => 'Укажите сумму в месяц';

  @override
  String get goalNoteLabel => 'Заметка';

  @override
  String get goalNoteHint => 'Необязательно';

  @override
  String get goalDoneOnceReached => 'Завершить по достижении';

  @override
  String get goalDoneOnceReachedDesc => 'Выключите для пополняемых фондов';

  @override
  String get goalDeleteRowDesc => 'Удаляет цель, деньги остаются';

  @override
  String get goalOfWord => 'из';

  @override
  String goalNewAccountNamed(Object name) {
    return 'Новый · $name';
  }

  @override
  String get goalUntitled => 'Новая цель';

  @override
  String get goalChooseSource => 'Выберите, что отслеживать';

  @override
  String get goalTwoOnAccount =>
      'Этот счёт уже отслеживает другая цель. Это допустимо — обе читают один баланс.';

  @override
  String get goalMonthlyPromptTitle => 'Сумма в месяц';

  @override
  String get goalNewAccountOption => 'Новый счёт';

  @override
  String get goalNewAccountOptionDesc => 'Отложенный счёт, названный по цели';

  @override
  String get goalIncomeCategories => 'Категории доходов';

  @override
  String goalDeleteTitle(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String get goalDeleteBody =>
      'Цель и её история исчезнут. Больше ничего не изменится.';

  @override
  String goalDeleteAccountStays(Object name, Object balance) {
    return 'Счёт «$name» остаётся · $balance';
  }

  @override
  String goalDeleteTxnStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Остаются $count транзакций',
      many: 'Остаются $count транзакций',
      few: 'Остаются $count транзакции',
      one: 'Остаётся 1 транзакция',
    );
    return '$_temp0';
  }

  @override
  String get goalDeleteCategoryStays =>
      'Категория дохода и её транзакции остаются';

  @override
  String goalOfToGo(Object target, Object remaining) {
    return 'из $target · осталось $remaining';
  }

  @override
  String goalDaysCaption(Object pct, int elapsed, int total) {
    return '$pct · $elapsed из $total дней';
  }

  @override
  String get goalColStarted => 'Начато';

  @override
  String get goalColTarget => 'Цель';

  @override
  String get goalColAtThisRate => 'При этом темпе';

  @override
  String get goalColReachedOn => 'Достигнута';

  @override
  String get goalColStoppedOn => 'Остановлена';

  @override
  String get goalColGotTo => 'Собрано';

  @override
  String get goalColTook => 'Заняло';

  @override
  String goalTookMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '1 месяц',
    );
    return '$_temp0';
  }

  @override
  String get goalTookUnderMonth => '< 1 месяца';

  @override
  String goalOutcomeReachedOn(Object date) {
    return 'Достигнута $date';
  }

  @override
  String goalOutcomeStoppedOn(Object date) {
    return 'Остановлена $date';
  }

  @override
  String get goalDeletePermanently => 'Удалить навсегда';

  @override
  String get goalReachedSummary => 'Достигнуто — делать больше нечего';

  @override
  String get goalNotMovingYet => 'Пока без движения';

  @override
  String goalAveragingOnly(Object rate) {
    return 'В среднем $rate в месяц';
  }

  @override
  String goalAveraging(Object actual, Object needs) {
    return 'Сейчас $actual/мес · нужно $needs/мес, чтобы успеть в срок';
  }

  @override
  String a11yMoneyIn(Object amount) {
    return 'Поступление, $amount';
  }

  @override
  String a11yMoneyOut(Object amount) {
    return 'Списание, $amount';
  }

  @override
  String goalCategoryWindow(Object from, Object to) {
    return '$from – $to';
  }

  @override
  String get goalMovements => 'Движения';

  @override
  String goalSeeAll(int count) {
    return 'Показать все $count';
  }

  @override
  String get goalNoteSection => 'Заметка';

  @override
  String get goalChanges => 'Изменения';

  @override
  String get goalChangeCreated => 'Создано';

  @override
  String get goalChangeTarget => 'Цель';

  @override
  String get goalChangeDate => 'Дата цели';

  @override
  String get bhCreated => 'Создано';

  @override
  String get bhLimit => 'Лимит';

  @override
  String get bhRollover => 'Перенос';

  @override
  String get bhWarn => 'Оповещение при';

  @override
  String get bhRemoved => 'Удалено';

  @override
  String get bhRestored => 'Восстановлено';

  @override
  String get bhCategoryArchived => 'Категория архивирована';

  @override
  String get bhOn => 'Вкл';

  @override
  String get bhOff => 'Выкл';

  @override
  String bhCreatedRolloverOn(String amount) {
    return '$amount · перенос вкл';
  }

  @override
  String bhCreatedRolloverOff(String amount) {
    return '$amount · перенос выкл';
  }

  @override
  String get bhEmpty => 'Изменений пока нет';

  @override
  String bhSince(String date) {
    return 'Изменения записываются с $date';
  }

  @override
  String get bhA11yTo => 'до';

  @override
  String get bhA11yIncreased => 'увеличено';

  @override
  String get goalMenuEdit => 'Изменить цель';

  @override
  String get goalStopTracking => 'Прекратить отслеживание';

  @override
  String get goalStopTrackingDesc => 'Запись остаётся в архиве';

  @override
  String get goalReachedAtZero => 'Достигнуто, и счёт пуст.';

  @override
  String get goalKeepAccount => 'Оставить счёт';

  @override
  String get goalArchiveBoth => 'Архивировать оба';

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
  String get tagEditTitle => 'Изменить метку';

  @override
  String get tagArchiveThis => 'Архивировать метку';

  @override
  String tagArchiveMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Она остаётся на своих $count операциях и доступна для поиска',
      many: 'Она остаётся на своих $count операциях и доступна для поиска',
      few: 'Она остаётся на своих $count операциях и доступна для поиска',
      one: 'Она остаётся на своей $count операции и доступна для поиска',
    );
    return '$_temp0';
  }

  @override
  String get tagDeleteThis => 'Удалить метку';

  @override
  String get tagDeleteMsg =>
      'Её пока ничто не несёт, поэтому её можно удалить полностью';

  @override
  String get tagRestoreThis => 'Восстановить метку';

  @override
  String get plTitle => 'Планер';

  @override
  String get fieldSelectCategory => 'Выберите категорию';

  @override
  String get actionResume => 'Возобновить';

  @override
  String get schToday => 'Сегодня';

  @override
  String get schHorizonThisWeek => 'На этой неделе';

  @override
  String get schHorizonNext30 => 'Следующие 30 дней';

  @override
  String get schHorizonThisMonth => 'В этом месяце';

  @override
  String get schHorizonNext3Months => 'Следующие 3 месяца';

  @override
  String get schHorizonTitle => 'ГОРИЗОНТ';

  @override
  String get schHorizonUntilDate => 'До даты…';

  @override
  String get schHorizonFootnote =>
      'Просроченные платежи здесь не учитываются — они остаются в списке при любом горизонте.';

  @override
  String schUntilControl(Object date) {
    return 'До $date';
  }

  @override
  String schCompletedIn(Object label) {
    return 'Выполнено · $label';
  }

  @override
  String get schCompletedEmpty => 'За этот период ничего не выполнено.';

  @override
  String get schCompletedLongerPeriod => 'Выбрать более длинный период';

  @override
  String get schUntilTitle => 'ДО ДАТЫ';

  @override
  String get schUntilNote => 'Начинается сегодня — выберите конец.';

  @override
  String get schUntilPickPrompt => 'Выберите дату окончания';

  @override
  String schUntilFromTo(Object date) {
    return 'От сегодня до $date';
  }

  @override
  String schDaysChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дн.',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String schDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дн.',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String schPaymentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count платежей',
      one: '$count платёж',
    );
    return '$_temp0';
  }

  @override
  String schApplyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дн.',
      one: '$count день',
    );
    return 'Применить · $_temp0';
  }

  @override
  String get schLegendPayment => 'есть платёж';

  @override
  String get schLegendNegative => 'баланс уходит в минус';

  @override
  String get schShortLabel => 'не хватает';

  @override
  String get schLeftLabel => 'остаётся';

  @override
  String get schLeftAfter => 'останется после обязательств';

  @override
  String get schShortAfter => 'не хватит после обязательств';

  @override
  String schCaptionIn(Object amount) {
    return '$amount придёт';
  }

  @override
  String schCaptionOut(Object amount) {
    return '$amount уйдёт';
  }

  @override
  String schShortToday(Object amount) {
    return 'Не хватает $amount сегодня';
  }

  @override
  String schShortOnDay(Object amount, Object date) {
    return 'Не хватает $amount — $date';
  }

  @override
  String schBannerOut(int count, Object amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count просроченных платежей',
      one: '$count просроченный платёж',
    );
    return '$_temp0 · $amount';
  }

  @override
  String schBannerIn(int count, Object amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ожидаемых платежей не поступили',
      one: '$count ожидаемый платёж не поступил',
    );
    return '$_temp0 · $amount';
  }

  @override
  String schBannerBoth(int count, Object out, Object inAmt) {
    return '$count просрочено · $out исходящих, $inAmt входящих';
  }

  @override
  String get schNothingInHorizon => 'В этом окне ничего не запланировано';

  @override
  String get schShowNext3Months => 'Показать следующие 3 месяца ›';

  @override
  String schDaysLate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'на $count дн. позже',
      one: 'на $count день позже',
    );
    return '$_temp0';
  }

  @override
  String schOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get schWontCover => 'не хватит';

  @override
  String get schSemPayingOut => 'выплата';

  @override
  String get schSemComingIn => 'поступление';

  @override
  String get schSemDue => 'срок';

  @override
  String get schSemFrom => 'со счёта';

  @override
  String get schSemInto => 'на счёт';

  @override
  String schSemRepeats(Object cadence) {
    return 'повторяется $cadence';
  }

  @override
  String schItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записей',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String schPausedArchiveLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count приостановленных задач',
      one: '$count приостановленная задача',
    );
    return '$_temp0 · Архив ›';
  }

  @override
  String schCompletedFooter(Object out, Object inAmt, int count) {
    return '$out исходящих · $inAmt входящих · $count не состоялось';
  }

  @override
  String schSeeAll(int count) {
    return 'Показать все ($count) ›';
  }

  @override
  String schPaidLine(Object when, Object account) {
    return '$when оплачено · $account';
  }

  @override
  String schReceivedLine(Object when, Object account) {
    return '$when получено · $account';
  }

  @override
  String schSkippedLine(Object when) {
    return '$when пропущено';
  }

  @override
  String schCancelledLine(Object when) {
    return '$when отменено';
  }

  @override
  String histLastDays(int count) {
    return 'Последние $count дн.';
  }

  @override
  String get histThisMonth => 'Этот месяц';

  @override
  String get histLastMonth => 'Прошлый месяц';

  @override
  String histSinceDate(Object date) {
    return 'С $date';
  }

  @override
  String get histSincePrompt => 'С даты…';

  @override
  String histFilterAll(int count) {
    return 'Все $count';
  }

  @override
  String histFilterPaid(int count) {
    return 'Оплачено $count';
  }

  @override
  String histFilterSkipped(int count) {
    return 'Пропущено $count';
  }

  @override
  String histFilterCancelled(int count) {
    return 'Отменено $count';
  }

  @override
  String get histOut => 'РАСХОД';

  @override
  String get histIn => 'ПРИХОД';

  @override
  String get histDidntHappen => 'НЕ СОСТОЯЛОСЬ';

  @override
  String get histNothingHere => 'Здесь ничего нет за этот период';

  @override
  String histPausedDeleted(int paused, int deleted) {
    return '$paused приостановлено, $deleted удалено за период · Архив ›';
  }

  @override
  String get mpTitlePaid => 'Отметить оплаченным';

  @override
  String get mpTitleReceived => 'Отметить полученным';

  @override
  String mpSubtitle(Object title, Object date) {
    return '$title · срок $date';
  }

  @override
  String mpExpected(Object amount) {
    return 'ожидалось $amount';
  }

  @override
  String get mpDate => 'Дата';

  @override
  String get mpFrom => 'Со счёта';

  @override
  String get mpInto => 'На счёт';

  @override
  String get mpTo => 'Куда';

  @override
  String get mpTransferNoCategory => 'Перевод — без категории бюджета';

  @override
  String mpRemember(Object amount) {
    return 'Запомнить $amount на будущее';
  }

  @override
  String mpConfirm(Object amount) {
    return 'Подтвердить · $amount';
  }

  @override
  String get mpChooseDestination => 'Выберите назначение';

  @override
  String get mpPayOffGroup => 'ПОГАСИТЬ';

  @override
  String mpRecorded(Object title) {
    return '$title записано в Реестр';
  }

  @override
  String mpRecordedNext(Object title, Object date) {
    return '$title записано в Реестр · далее $date';
  }

  @override
  String get tmEdit => 'Изменить';

  @override
  String get tmEditSub =>
      'Сумма, дата, повтор, счёт, категория, напоминание и заметка.';

  @override
  String get tmSkip => 'Пропустить эту';

  @override
  String tmSkipSub(Object date, Object next) {
    return '$date пропущено. В Реестр ничего не пишется; серия продолжится $next.';
  }

  @override
  String get tmPause => 'Приостановить';

  @override
  String get tmPauseSub =>
      'Уходит из списка и прогноза. История платежей и будущие даты сохраняются — возобновите из Архива в любой момент.';

  @override
  String get tmDelete => 'Удалить';

  @override
  String tmDeleteSub(int count) {
    return 'Перемещается в Архив — случайное удаление можно отменить. $count платежей остаются в Реестре. Окончательное удаление — из Архива.';
  }

  @override
  String tdDeleteTitle(Object title) {
    return 'Удалить $title?';
  }

  @override
  String get tdDeleteMsg =>
      'Перемещается в Архив — случайное удаление можно отменить.';

  @override
  String tdKeptPayments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count платежей остаются в Реестре',
      one: '$count платёж остаётся в Реестре',
    );
    return '$_temp0';
  }

  @override
  String get tdKeptBalances => 'Балансы не затрагиваются';

  @override
  String get tdKeptHistory => 'История платежей остаётся с задачей в Архиве';

  @override
  String get tdLostSchedule => 'Уходит из Расписания и прогноза';

  @override
  String get tdLostReminders => 'Будущие напоминания прекращаются';

  @override
  String get tdDeleteConfirm => 'Удалить';

  @override
  String tdPausedOn(Object date) {
    return 'Приостановлено $date';
  }

  @override
  String get tdNext => 'ДАЛЕЕ';

  @override
  String get tdAmount => 'СУММА';

  @override
  String get tdPerYear => 'В ГОД';

  @override
  String get tdDue => 'СРОК';

  @override
  String get tdUpcoming => 'ПРЕДСТОЯЩИЕ';

  @override
  String get tdPaymentHistory => 'ИСТОРИЯ ПЛАТЕЖЕЙ';

  @override
  String get tdNoPayments => 'Платежей пока нет';

  @override
  String tdPaymentsSince(int count, Object month, Object total) {
    return '$count платежей с $month · всего $total';
  }

  @override
  String get tdResume => 'Возобновить';

  @override
  String get tdMarkPaid => 'Отметить оплаченным';

  @override
  String get tdMarkReceived => 'Отметить полученным';

  @override
  String get tdSkipOne => 'Пропустить эту';

  @override
  String get etNote => 'Заметка';

  @override
  String get etNoteHint => 'Добавить заметку';

  @override
  String get etPaidTo => 'Куда платить';

  @override
  String arPausedLine(Object date, int payments, Object total) {
    return 'приостановлено $date · $payments платежей · $total';
  }

  @override
  String arCompletedLine(Object date, Object amount) {
    return 'оплачено $date · $amount';
  }

  @override
  String arCancelledLine(Object date) {
    return 'отменено $date';
  }

  @override
  String arDeletedLineTask(Object date, int payments, Object total) {
    return 'удалено $date · $payments платежей · $total';
  }
}
