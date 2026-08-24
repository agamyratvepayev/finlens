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
  String get languageSystemDefault => 'Как на устройстве';

  @override
  String get accountGroupSpendable => 'Расходные';

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
  String get quickAddExpense => 'Расход';

  @override
  String get quickAddIncome => 'Доход';

  @override
  String get quickAddTransfer => 'Перевод';

  @override
  String get quickAddRebalance => 'Корректировка';

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
  String get moreYourMoney => 'Ваши деньги';

  @override
  String get morePlannerSection => 'Планы';

  @override
  String get morePreferences => 'Настройки';

  @override
  String get moreCategories => 'Категории';

  @override
  String moreCategoriesInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count используется',
      many: '$count используется',
      few: '$count используется',
      one: '$count используется',
    );
    return '$_temp0';
  }

  @override
  String get moreArchive => 'Архив';

  @override
  String get morePrivacyMode => 'Приватность';

  @override
  String get morePrivacyModeDesc => 'Скрывать все суммы в приложении';

  @override
  String get moreAddAccount => 'Добавить счёт';

  @override
  String get insightTitle => 'Аналитика';

  @override
  String get insightLeftOver => 'Остаток';

  @override
  String get insightNoIncome => 'В этом месяце дохода не было';

  @override
  String insightKept(String percent, String amount) {
    return '$percent из $amount сохранено';
  }

  @override
  String get insightWhereItWent => 'Куда ушло';

  @override
  String get insightGoalPerformance => 'Достижение целей';

  @override
  String get insightReached => 'Достигнуто';

  @override
  String get insightSuccessRate => 'Успешность';

  @override
  String get insightAvgTime => 'Ср. время';

  @override
  String insightMonthsShort(int count) {
    return '$count мес';
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
  String get balNoAccountsYet => 'Пока нет счетов';

  @override
  String get balNoAccountMatch =>
      'Ни один счёт или группа не подходят под запрос.';

  @override
  String get balAddFirstAccount => 'Добавьте первый счёт';

  @override
  String get balNoAccountsMessage =>
      'Добавьте счета, и FinLens сам рассчитает капитал по вашим операциям.';

  @override
  String get balAdjustFilter => 'Настроить фильтр';

  @override
  String get balSortTooltip => 'Сортировка';

  @override
  String get balHoldToArrange => 'Удерживайте счёт, чтобы упорядочить';

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
  String get plNoBudgetsYet => 'Пока нет бюджетов';

  @override
  String get plNoBudgetsMsg =>
      'Задайте категории месячный лимит, и она появится здесь.';

  @override
  String get plBudgeted => 'В бюджете';

  @override
  String get plNoBudgetSet => 'Бюджет не задан';

  @override
  String get plSet => 'Задать';

  @override
  String get plNoGoalsYet => 'Пока нет целей';

  @override
  String get plNoGoalsMsg =>
      'Задайте цель, и FinLens рассчитает месячный темп.';

  @override
  String get plNewGoal => 'Новая цель';

  @override
  String get plNewTask => 'Новая задача';

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
  String get schLater => 'Позже в этом месяце';

  @override
  String get plNothingScheduled => 'Ничего не запланировано';

  @override
  String get plNothingSchedMsg =>
      'Счета, зарплаты и подписки, которые вы запланируете, появятся здесь.';

  @override
  String get plLeftThisMonth => 'Осталось за месяц';

  @override
  String get plUnbudgeted => 'вне бюджета';

  @override
  String get plOf => 'из';

  @override
  String get plBudgetWord => 'бюджета';

  @override
  String get plSavedTowardGoals => 'Накоплено на цели';

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
  String get arReachedGoals => 'Достигнутые цели';

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
    return 'Достигнуто $date · за $_temp0';
  }

  @override
  String get arGaveUp => 'Заброшено';

  @override
  String arStoppedLine(Object date, Object saved, Object target) {
    return 'Остановлено $date · $saved из $target';
  }

  @override
  String get arRemovedBudgets => 'Удалённые бюджеты';

  @override
  String arRemovedLine(Object date) {
    return 'Удалено $date';
  }

  @override
  String get arClearPermanently => 'Очистить архив навсегда';

  @override
  String get arClearTitle => 'Очистить архив?';

  @override
  String arClearMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count архивных элемента удаляются навсегда.',
      many: '$count архивных элементов удаляются навсегда.',
      few: '$count архивных элемента удаляются навсегда.',
      one: '$count архивный элемент удаляется навсегда.',
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
}
