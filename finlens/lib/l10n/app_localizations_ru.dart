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
}
