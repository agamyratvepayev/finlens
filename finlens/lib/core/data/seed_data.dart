import 'package:flutter/material.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import 'seed_history.dart';

/// Mock data layer. Every figure here is lifted from the mockups in Tech Spec
/// v1.1 so the running app reproduces the documented screens.
///
/// This is the only file that knows the data is fake — swapping it for a
/// repository backed by an API means replacing [buildSeedStore] alone.
AppStore buildSeedStore() {
  final now = AppStore.today;
  DateTime at(int day, [int hour = 12, int minute = 0]) =>
      DateTime(2026, 8, day, hour, minute);

  // ── Accounts (spec 1.2 / 1.3 mockups) ─────────────────────────────────────
  final accounts = <Account>[
    // Spendable
    Account(
      id: 'a-cash-usd',
      name: 'Cash (USD Wallet)',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 5199.35, // 5210 → 5199.35: −10.65 history offset
      icon: Icons.payments_rounded,
    ),
    Account(
      id: 'a-cash-eur',
      name: 'Cash (EUR Wallet)',
      group: AccountGroup.spendable,
      currency: 'EUR',
      startingBalance: 3134.30, // 3300 → 3134.30: −165.70 history offset (EUR)
      icon: Icons.euro_rounded,
    ),
    Account(
      id: 'a-checking',
      name: 'Main Checking',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 26506, // 4000 → 26506: +22506 history offset (net hub outflows)
      icon: Icons.account_balance_rounded,
    ),
    Account(
      id: 'a-family',
      name: 'Family Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1288.70, // 1700 → 1288.70: −411.30 history offset
      icon: Icons.people_rounded,
    ),
    // Receivables
    Account(
      id: 'a-loan-john',
      name: 'Personal Loan (John Doe)',
      group: AccountGroup.receivables,
      currency: 'USD',
      startingBalance: 1635, // 1500 → 1635: +135 history offset
      icon: Icons.handshake_rounded,
    ),
    Account(
      id: 'a-invoice',
      name: 'Client Invoice (#104)',
      group: AccountGroup.receivables,
      currency: 'USD',
      startingBalance: 2340, // 1200 → 2340: +1140 history offset
      icon: Icons.receipt_rounded,
    ),
    Account(
      id: 'a-refund',
      name: 'Pending Refund (Amazon)',
      group: AccountGroup.receivables,
      currency: 'USD',
      startingBalance: 312, // 300 → 312: +12 history offset
      icon: Icons.assignment_return_rounded,
    ),
    Account(
      id: 'a-dinner',
      name: 'Dinner Split (Friends)',
      group: AccountGroup.receivables,
      currency: 'USD',
      startingBalance: 200, // unchanged: history nets to 0
      icon: Icons.restaurant_rounded,
    ),
    // Investments
    Account(
      id: 'a-stocks',
      name: 'US Stocks (S&P 500)',
      group: AccountGroup.investments,
      currency: 'USD',
      startingBalance: 17425, // 19500 → 17425: −2075 history offset
      icon: Icons.show_chart_rounded,
    ),
    Account(
      id: 'a-gold',
      name: 'Gold Portfolio',
      group: AccountGroup.investments,
      currency: 'USD',
      startingBalance: 12150, // 14200 → 12150: −2050 history offset
      icon: Icons.workspace_premium_rounded,
    ),
    Account(
      id: 'a-crypto',
      name: 'Crypto Wallet (BTC/ETH)',
      group: AccountGroup.investments,
      currency: 'USD',
      startingBalance: 6400, // 7700 → 6400: −1300 history offset
      icon: Icons.currency_bitcoin_rounded,
    ),
    Account(
      id: 'a-etf',
      name: 'Tech ETFs (QQQ)',
      group: AccountGroup.investments,
      currency: 'USD',
      startingBalance: 1816, // 3000 → 1816: −1184 history offset
      icon: Icons.candlestick_chart_rounded,
    ),
    Account(
      id: 'a-pension',
      name: 'Private Pension (BES)',
      group: AccountGroup.investments,
      currency: 'USD',
      startingBalance: 819, // 2000 → 819: −1181 history offset
      icon: Icons.savings_rounded,
    ),
    // Valuables
    Account(
      id: 'a-home',
      name: 'Primary Residence (Apartment)',
      group: AccountGroup.valuables,
      currency: 'USD',
      startingBalance: 114300, // 120000 → 114300: −5700 history offset (revaluations)
      icon: Icons.home_rounded,
    ),
    Account(
      id: 'a-car',
      name: 'Personal Car',
      group: AccountGroup.valuables,
      currency: 'USD',
      startingBalance: 27480, // 25000 → 27480: +2480 history offset (depreciation)
      icon: Icons.directions_car_rounded,
    ),
    Account(
      id: 'a-watches',
      name: 'Luxury Watches',
      group: AccountGroup.valuables,
      currency: 'USD',
      startingBalance: 1870, // 3000 → 1870: −1130 history offset
      icon: Icons.watch_rounded,
    ),
    Account(
      id: 'a-tech',
      name: 'Tech Hardware',
      group: AccountGroup.valuables,
      currency: 'USD',
      startingBalance: 1280, // 2000 → 1280: −720 history offset
      icon: Icons.laptop_mac_rounded,
    ),
    // Credit Cards — liabilities are held negative throughout.
    Account(
      id: 'a-amex',
      name: 'Main Credit Card (Amex)',
      group: AccountGroup.creditCards,
      currency: 'USD',
      startingBalance: -3340.50, // -2732 → -3340.50: −608.50 history offset (Zone D excluded)
      creditLimit: 10000,
      statementDay: 1,
      paymentDue: 12,
      icon: Icons.credit_card_rounded,
    ),
    Account(
      id: 'a-bonus',
      name: 'Shopping Card (Bonus)',
      group: AccountGroup.creditCards,
      currency: 'USD',
      startingBalance: -2724, // -2500 → -2724: −224 history offset (Zone D excluded)
      creditLimit: 6500,
      statementDay: 5,
      paymentDue: 20,
      icon: Icons.local_mall_rounded,
    ),
    // Payables
    Account(
      id: 'a-rent',
      name: 'Rent Payable (Landlord)',
      group: AccountGroup.payables,
      currency: 'USD',
      startingBalance: -2000, // unchanged: history nets to 0 (bill = settlement)
      paymentDue: 21,
      icon: Icons.home_work_rounded,
    ),
    Account(
      id: 'a-utilities',
      name: 'Electricity / Utilities',
      group: AccountGroup.payables,
      currency: 'USD',
      startingBalance: -800, // unchanged: history nets to 0 (bill = settlement)
      paymentDue: 14,
      icon: Icons.bolt_rounded,
    ),
    Account(
      id: 'a-internet',
      name: 'Internet / Phone',
      group: AccountGroup.payables,
      currency: 'USD',
      startingBalance: -400, // unchanged: history nets to 0 (bill = settlement)
      paymentDue: 17,
      icon: Icons.wifi_rounded,
    ),
    // Bank Loans
    Account(
      id: 'a-autoloan',
      name: 'Auto Loan (Car)',
      group: AccountGroup.bankLoans,
      currency: 'USD',
      startingBalance: -6941, // -5000 → -6941: −1941 history offset (repayments net down)
      creditLimit: 12000,
      paymentDue: 15,
      icon: Icons.directions_car_filled_rounded,
    ),
    Account(
      id: 'a-mortgage',
      name: 'Mortgage (Apartment)',
      group: AccountGroup.bankLoans,
      currency: 'USD',
      startingBalance: -18047, // -15000 → -18047: −3047 history offset (repayments net down)
      creditLimit: 60000,
      paymentDue: 1,
      icon: Icons.apartment_rounded,
    ),
  ];

  // ── Categories (spec 4.1) ─────────────────────────────────────────────────
  // Budgets are their own objects now (budgets-as-object spec §A); see the
  // `budgets` list below. Categories carry no budget fields.
  final categories = <Category>[
    Category(
      id: 'c-groceries',
      name: 'Groceries',
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
    ),
    Category(
      id: 'c-housing',
      name: 'Housing',
      type: CategoryType.expense,
      icon: Icons.home_rounded,
      color: const Color(0xFF3B82F6),
    ),
    Category(
      id: 'c-entertainment',
      name: 'Entertainment',
      type: CategoryType.expense,
      icon: Icons.play_circle_rounded,
      color: const Color(0xFF8B5CF6),
    ),
    Category(
      id: 'c-transport',
      name: 'Transportation',
      type: CategoryType.expense,
      icon: Icons.local_shipping_rounded,
      color: const Color(0xFFF5A524),
    ),
    Category(
      id: 'c-shopping',
      name: 'Shopping',
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFFF04438),
    ),
    Category(
      id: 'c-personal',
      name: 'Personal',
      type: CategoryType.expense,
      icon: Icons.self_improvement_rounded,
      color: const Color(0xFF14B8A6),
    ),
    // Unbudgeted expense categories — they exist in the picker but not in
    // Planner > Budgets, which is exactly what monthly_budget == null means.
    Category(
      id: 'c-eatingout',
      name: 'Eating out',
      type: CategoryType.expense,
      icon: Icons.local_cafe_rounded,
      color: const Color(0xFFEC4899),
    ),
    Category(
      id: 'c-subs',
      name: 'Subscriptions',
      type: CategoryType.expense,
      icon: Icons.subscriptions_rounded,
      color: const Color(0xFFF04438),
    ),
    Category(
      id: 'c-health',
      name: 'Health',
      type: CategoryType.expense,
      icon: Icons.favorite_rounded,
      color: const Color(0xFF34C759),
    ),
    // Its budget is a removed one, waiting in Archive (spec 5.8) — see `budgets`.
    Category(
      id: 'c-garden',
      name: 'Garden',
      type: CategoryType.expense,
      icon: Icons.local_florist_rounded,
      color: const Color(0xFF34C759),
    ),
    Category(
      id: 'c-debt',
      name: 'Debt payments',
      type: CategoryType.expense,
      icon: Icons.credit_score_rounded,
      color: const Color(0xFFF04438),
    ),
    // Income categories
    Category(
      id: 'c-salary',
      name: 'Salary',
      type: CategoryType.income,
      icon: Icons.payments_rounded,
      color: const Color(0xFF34C759),
    ),
    Category(
      id: 'c-freelance',
      name: 'Freelance',
      type: CategoryType.income,
      icon: Icons.laptop_rounded,
      color: const Color(0xFF3B82F6),
    ),
    Category(
      id: 'c-interest',
      name: 'Interest & Dividends',
      type: CategoryType.income,
      icon: Icons.trending_up_rounded,
      color: const Color(0xFF8B5CF6),
    ),
  ];

  // ── Transactions ──────────────────────────────────────────────────────────
  // Sized so the current month reproduces the Planner burn-rate figures:
  // Groceries 650/1000 · Housing 1140/1200 · Entertainment 440/400 ·
  // Transportation 200/500 · Shopping 300/500 · Personal 120/200.
  final txns = <Txn>[
    // Income
    Txn(
      id: 't-salary-aug',
      type: TxnType.income,
      amount: 5200,
      currency: 'USD',
      fromRef: 'c-salary',
      toRef: 'a-checking',
      date: at(1, 9, 0),
      note: 'Monthly salary',
    ),
    Txn(
      id: 't-freelance',
      type: TxnType.income,
      amount: 900,
      currency: 'USD',
      fromRef: 'c-freelance',
      toRef: 'a-checking',
      date: at(6, 18, 10),
      note: 'Landing page project',
      tagIds: ['side'],
    ),
    // Housing
    Txn(
      id: 't-rent',
      type: TxnType.expense,
      amount: 1100,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'c-housing',
      date: at(2, 10, 0),
      note: 'August rent',
    ),
    Txn(
      id: 't-water',
      type: TxnType.expense,
      amount: 40,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'c-housing',
      date: at(4, 11, 30),
      note: 'Water bill',
    ),
    // Groceries
    Txn(
      id: 't-market1',
      type: TxnType.expense,
      amount: 320,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'c-groceries',
      date: at(3, 17, 15),
      note: 'Weekly market run',
    ),
    Txn(
      id: 't-market2',
      type: TxnType.expense,
      amount: 210,
      currency: 'USD',
      fromRef: 'a-cash-usd',
      toRef: 'c-groceries',
      date: at(8, 19, 5),
      note: 'Groceries',
    ),
    Txn(
      id: 't-market3',
      type: TxnType.expense,
      amount: 120,
      currency: 'USD',
      fromRef: 'a-cash-usd',
      toRef: 'c-groceries',
      date: at(9, 11, 40),
      note: 'Bakery & fruit',
    ),
    // Entertainment — deliberately over its $400 limit (spec 5.1 red state).
    Txn(
      id: 't-concert',
      type: TxnType.expense,
      amount: 260,
      currency: 'USD',
      fromRef: 'a-amex',
      toRef: 'c-entertainment',
      date: at(5, 21, 0),
      note: 'Concert tickets',
      tagIds: ['fun'],
    ),
    Txn(
      id: 't-cinema',
      type: TxnType.expense,
      amount: 180,
      currency: 'USD',
      fromRef: 'a-amex',
      toRef: 'c-entertainment',
      date: at(7, 20, 30),
      note: 'Cinema night',
    ),
    // Transportation
    Txn(
      id: 't-shell',
      type: TxnType.expense,
      amount: 68,
      currency: 'USD',
      fromRef: 'a-amex',
      toRef: 'c-transport',
      date: at(3, 9, 20),
      note: 'Full tank before the trip',
      tagIds: ['vacation'],
    ),
    Txn(
      id: 't-transit',
      type: TxnType.expense,
      amount: 132,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'c-transport',
      date: at(6, 8, 15),
      note: 'Monthly transit pass',
    ),
    // Shopping
    Txn(
      id: 't-amazon',
      type: TxnType.expense,
      amount: 142,
      currency: 'USD',
      fromRef: 'a-amex',
      toRef: 'c-shopping',
      date: at(7, 13, 5),
      note: 'Kitchen shelves, 3 pcs',
      tagIds: ['home'],
    ),
    Txn(
      id: 't-clothes',
      type: TxnType.expense,
      amount: 158,
      currency: 'USD',
      fromRef: 'a-bonus',
      toRef: 'c-shopping',
      date: at(8, 16, 45),
      note: 'Autumn jacket',
    ),
    // Personal
    Txn(
      id: 't-gym',
      type: TxnType.expense,
      amount: 120,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'c-personal',
      date: at(2, 8, 0),
      note: 'Gym membership',
    ),
    // Eating out — unbudgeted, still shows in the Ledger.
    Txn(
      id: 't-cafe',
      type: TxnType.expense,
      amount: 18,
      currency: 'USD',
      fromRef: 'a-amex',
      toRef: 'c-eatingout',
      date: at(9, 14, 32),
      note: 'Morning coffee with Ayşe',
    ),
    // Subscriptions
    Txn(
      id: 't-netflix',
      type: TxnType.expense,
      amount: 22,
      currency: 'USD',
      fromRef: 'a-amex',
      toRef: 'c-subs',
      date: at(1, 7, 0),
      note: 'Monthly subscription',
    ),
    // Transfers — one same-currency card payment, one FX with a fee (spec 3.4).
    Txn(
      id: 't-cardpay',
      type: TxnType.transfer,
      amount: 500,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'a-amex',
      date: at(5, 15, 0),
      note: 'Partial payment before statement',
    ),
    Txn(
      id: 't-fx',
      type: TxnType.transfer,
      amount: 500,
      currency: 'EUR',
      fromRef: 'a-cash-eur',
      toRef: 'a-cash-usd',
      date: at(4, 16, 20),
      exchangeRate: 1.10,
      toAmount: 550,
      fee: 3,
      note: 'Holiday cash swap',
    ),
    // Rebalance — moves net worth only, never income (spec 3.5 / 6.2).
    Txn(
      id: 't-gold-reval',
      type: TxnType.rebalance,
      amount: 800,
      currency: 'USD',
      fromRef: 'a-gold',
      toRef: 'a-gold',
      date: at(6, 10, 0),
      note: 'Gold price update',
    ),
    Txn(
      id: 't-stocks-reval',
      type: TxnType.rebalance,
      amount: 500,
      currency: 'USD',
      fromRef: 'a-stocks',
      toRef: 'a-stocks',
      date: at(8, 10, 0),
      note: 'Quarterly valuation',
    ),
    // Previous months — feeds Edit Budget's "what you actually spent" block.
    Txn(
      id: 't-jul-ent',
      type: TxnType.expense,
      amount: 380,
      currency: 'USD',
      fromRef: 'a-amex',
      toRef: 'c-entertainment',
      date: DateTime(2026, 7, 18, 20, 0),
      note: 'Festival pass',
    ),
    Txn(
      id: 't-jun-ent',
      type: TxnType.expense,
      amount: 510,
      currency: 'USD',
      fromRef: 'a-amex',
      toRef: 'c-entertainment',
      date: DateTime(2026, 6, 12, 21, 0),
      note: 'Weekend trip',
    ),
    Txn(
      id: 't-jul-groc',
      type: TxnType.expense,
      amount: 890,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'c-groceries',
      date: DateTime(2026, 7, 20, 12, 0),
      note: 'July groceries',
    ),
    Txn(
      id: 't-jul-salary',
      type: TxnType.income,
      amount: 5200,
      currency: 'USD',
      fromRef: 'c-salary',
      toRef: 'a-checking',
      date: DateTime(2026, 7, 1, 9, 0),
      note: 'Monthly salary',
    ),
    // Authored history that lifts every account to ≥10 transactions. Kept in a
    // separate file so this fixture stays readable; each account's Zone A/B
    // additions are offset by the adjusted startingBalance values above, so
    // every 1 Aug 2026 balance is unchanged (see seed_history.dart).
    ...buildHistoryTxns(),
  ];

  // ── Goals, rebuilt on real balances (§1) ──────────────────────────────────
  // Progress is derived from each source, never stored — no `saved` field. The
  // seed exercises all four sections plus a refillable fund and both archives.
  final goals = <Goal>[
    // SAVING — an asset account climbing toward a target.
    Goal(
      id: 'g-house',
      name: 'House Deposit',
      source: const GoalSource.account('a-checking'),
      targetAmount: 30000,
      targetDate: DateTime(2027, 3, 1),
      createdAt: DateTime(2026, 2, 1),
    ),
    // SAVING (refillable) — an emergency fund that never latches, no date.
    Goal(
      id: 'g-emergency',
      name: 'Emergency Fund',
      source: const GoalSource.account('a-cash-usd'),
      targetAmount: 6000,
      endsWhenReached: false,
      createdAt: DateTime(2025, 12, 1),
    ),
    // PAYING OFF — a credit card falling to zero (target defaults to $0).
    Goal(
      id: 'g-amex',
      name: 'Main Credit Card',
      source: const GoalSource.account('a-amex'),
      targetAmount: 0,
      targetDate: DateTime(2026, 12, 1),
      createdAt: DateTime(2026, 3, 1),
    ),
    // WAITING ON — a receivable collected by someone else (never a rate).
    Goal(
      id: 'g-invoice',
      name: 'Client Invoice #104',
      source: const GoalSource.account('a-invoice'),
      targetAmount: 0,
      targetDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 6, 1),
    ),
    // EARNING — an income category summed over the goal's window.
    Goal(
      id: 'g-freelance',
      name: 'Freelance Side Income',
      source: const GoalSource.category('c-freelance'),
      targetAmount: 12000,
      targetDate: DateTime(2026, 12, 31),
      createdAt: DateTime(2026, 1, 1),
    ),
    // Archived — reached (spec 5.8).
    Goal(
      id: 'g-iphone',
      name: 'iPhone 17',
      source: const GoalSource.account('a-family'),
      targetAmount: 1200,
      status: GoalStatus.reached,
      completedAt: DateTime(2026, 5, 14),
      createdAt: DateTime(2025, 12, 14),
    ),
    // Archived — abandoned (spec 5.8).
    Goal(
      id: 'g-bali',
      name: 'Bali 2026',
      source: const GoalSource.account('a-checking'),
      targetAmount: 2000,
      status: GoalStatus.abandoned,
      stoppedAt: DateTime(2026, 4, 3),
      createdAt: DateTime(2025, 11, 3),
    ),
  ];

  // ── Tasks (spec 5.3 mockup) ───────────────────────────────────────────────
  final tasks = <Task>[
    Task(
      id: 'k-gym',
      title: 'Gym Subscription',
      categoryId: 'c-personal',
      linkedAccountId: 'a-checking',
      expectedAmount: -50,
      dueDate: DateTime(2026, 8, 7, 9, 0),
      icon: Icons.fitness_center_rounded,
      repeats: RepeatFrequency.monthly,
      priority: Priority.normal,
    ),
    Task(
      // Paying a credit-card statement moves money from Checking to Amex — a
      // transfer that shrinks the debt, not a spend that grows it (§10.4). The
      // money leaves `linkedAccountId` (Checking) and lands in `payToAccountId`
      // (Amex); a transfer carries no budget category.
      id: 'k-amex',
      title: 'Pay Amex statement',
      linkedAccountId: 'a-checking',
      payToAccountId: 'a-amex',
      expectedAmount: -3000,
      dueDate: DateTime(2026, 8, 12, 9, 0),
      icon: Icons.credit_card_rounded,
      priority: Priority.high,
      reminderDaysBefore: 2,
      reminderTime: const TimeOfDay(hour: 9, minute: 0),
    ),
    Task(
      id: 'k-salary',
      title: 'Monthly Salary',
      categoryId: 'c-salary',
      linkedAccountId: 'a-checking',
      expectedAmount: 5200,
      dueDate: DateTime(2026, 8, 15, 9, 0),
      icon: Icons.attach_money_rounded,
      repeats: RepeatFrequency.monthly,
    ),
    Task(
      id: 'k-internet',
      title: 'Internet Bill',
      categoryId: 'c-housing',
      linkedAccountId: 'a-checking',
      expectedAmount: -40,
      dueDate: DateTime(2026, 8, 22, 9, 0),
      icon: Icons.wifi_rounded,
      repeats: RepeatFrequency.monthly,
    ),
    Task(
      id: 'k-netflix',
      title: 'Netflix',
      categoryId: 'c-subs',
      linkedAccountId: 'a-amex',
      expectedAmount: -15.99,
      dueDate: DateTime(2026, 9, 1, 9, 0),
      icon: Icons.play_circle_rounded,
      repeats: RepeatFrequency.monthly,
      reminderDaysBefore: 2,
      reminderTime: const TimeOfDay(hour: 9, minute: 0),
    ),
    Task(
      id: 'k-spotify',
      title: 'Spotify',
      categoryId: 'c-subs',
      linkedAccountId: 'a-amex',
      expectedAmount: -9.99,
      dueDate: DateTime(2026, 9, 5, 9, 0),
      icon: Icons.music_note_rounded,
      repeats: RepeatFrequency.monthly,
    ),
  ];

  assert(now.year == 2026);

  // Opening-balance receipts (spec §1). Every seed account's history begins on
  // 1 August 2026 — one day at or before the earliest seeded transaction — so
  // its opening row lands at the foot of the default (this-month) tape, under
  // everything stacked on it, and never sits above a transaction (§9).
  final openingDate = DateTime(2026, 8, 1);
  for (final a in accounts) {
    a.openingDate = openingDate;
  }

  // ── Budgets (budgets-as-object spec §A) ───────────────────────────────────
  // Each seed budget is a monthly category budget anchored to the 1st, matching
  // the pre-change per-category fields exactly. Garden is a removed (archived)
  // budget, waiting in the Archive's REMOVED BUDGETS section.
  Budget monthlyBudget(String id, String catId, String name, double limit,
          {double warn = 0.8, DateTime? archivedAt}) =>
      Budget(
        id: id,
        name: name,
        scope: BudgetScope.categories,
        targets: {catId},
        limit: limit,
        period: BudgetPeriod.month,
        anchor: DateTime(2026, 1, 1),
        repeats: true,
        warnThreshold: warn,
        archivedAt: archivedAt,
      );

  final budgets = <Budget>[
    monthlyBudget('b-groceries', 'c-groceries', 'Groceries', 1000),
    monthlyBudget('b-housing', 'c-housing', 'Housing', 1200),
    monthlyBudget('b-entertainment', 'c-entertainment', 'Entertainment', 400),
    monthlyBudget('b-transport', 'c-transport', 'Transportation', 500),
    monthlyBudget('b-shopping', 'c-shopping', 'Shopping', 500),
    monthlyBudget('b-personal', 'c-personal', 'Personal', 200),
    // Removed budget, waiting in Archive (spec 5.8): limit cleared on removal,
    // rederived from spend on restore.
    monthlyBudget('b-garden', 'c-garden', 'Garden', 0,
        archivedAt: DateTime(2026, 6, 12)),
  ];

  return AppStore(
    accounts: accounts,
    categories: categories,
    txns: txns,
    goals: goals,
    tasks: tasks,
    budgets: budgets,
  );
}
