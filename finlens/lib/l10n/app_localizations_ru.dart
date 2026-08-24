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
  String get plPace => 'Темп';

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
  String get ldgNothingHere => 'Здесь пока пусто';

  @override
  String get ldgNothingHereMsg => 'Добавленные записи появятся в этом списке.';

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
  String get ldgAny => 'Любая';

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
  String get tdFrom => 'Откуда';

  @override
  String get tdTo => 'Куда';

  @override
  String get tdDeletedAccount => 'Удалённый счёт';

  @override
  String get tdRate => 'Курс';

  @override
  String get tdNote => 'Заметка';

  @override
  String get tdNetWorth => 'Капитал';

  @override
  String get tdUnchanged => 'Без изменений';

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
  String qaNoAccountMatch(Object query) {
    return 'Нет счёта по запросу «$query».';
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
  String get rsEveryMonth => 'Каждый месяц';

  @override
  String get rsEveryQuarter => 'Каждый квартал';

  @override
  String get rsEveryYear => 'Каждый год';

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
  String goalBehind(Object rate) {
    return 'Отставание · нужно $rate/мес';
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
  String get goalReachedSummary => 'Достигнуто — делать больше нечего';

  @override
  String get goalNotMovingYet => 'Пока без движения';

  @override
  String goalAveragingOnly(Object rate) {
    return 'В среднем $rate в месяц';
  }

  @override
  String goalAveraging(Object actual, Object needs) {
    return 'В среднем $actual в месяц · нужно $needs, чтобы успеть в срок';
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
}
