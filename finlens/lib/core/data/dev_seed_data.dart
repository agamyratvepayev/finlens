/// Development-only data seeder (spec: "Adding Varied Transactions").
///
/// FinLens has no database — [AppStore] is rebuilt from [buildSeedStore] on
/// every launch. So "seeding" here means building an *alternate fixture*:
/// [buildDevSeedStore] returns a store with the real accounts and categories
/// but a rich, varied transaction history, with each account's starting
/// balance **back-computed** so its live balance still equals the documented
/// target after the whole history is applied (spec §4).
///
/// This is wired behind a `kDebugMode`-guarded flag in `main.dart` (default
/// off) and never runs automatically. "Reset" is simply launching without the
/// flag, which rebuilds the untouched [buildSeedStore]. Seeded transactions are
/// marked by an id prefix ([kDevSeedIdPrefix]) so they can be told apart from
/// any real record without polluting a user-visible field.
///
/// The generator is deterministic: a fixed RNG seed and dates anchored to
/// [AppStore.today] mean every build produces the same data, and it shifts with
/// the app's clock rather than going stale.
library;

import 'dart:math';

import '../models/models.dart';
import '../store/app_store.dart';
import 'seed_data.dart';

/// Prefix stamped on every seeded transaction's id. This is the marker used to
/// identify seeded records; nothing user-visible carries it.
const String kDevSeedIdPrefix = 'dev-';

/// Fixed RNG seed — reproducibility over novelty (spec §3).
const int _kSeed = 20260809;

bool isDevSeededTxn(Txn t) => t.id.startsWith(kDevSeedIdPrefix);

// Real account ids from seed_data.dart.
const _checking = 'a-checking';
const _cashUsd = 'a-cash-usd';
const _cashEur = 'a-cash-eur';
const _family = 'a-family';
const _loanJohn = 'a-loan-john';
const _invoice = 'a-invoice';
const _refund = 'a-refund';
const _dinner = 'a-dinner';
const _stocks = 'a-stocks';
const _gold = 'a-gold';
const _crypto = 'a-crypto';
const _etf = 'a-etf';
const _pension = 'a-pension';
const _home = 'a-home';
const _car = 'a-car';
const _watches = 'a-watches';
const _tech = 'a-tech';
const _amex = 'a-amex';
const _bonus = 'a-bonus';
const _rentPayable = 'a-rent';
const _utilities = 'a-utilities';
const _internet = 'a-internet';
const _autoloan = 'a-autoloan';
const _mortgage = 'a-mortgage';

// Category ids.
const _cGroceries = 'c-groceries';
const _cHousing = 'c-housing';
const _cEntertainment = 'c-entertainment';
const _cTransport = 'c-transport';
const _cShopping = 'c-shopping';
const _cPersonal = 'c-personal';
const _cEatingOut = 'c-eatingout';
const _cSubs = 'c-subs';
const _cHealth = 'c-health';
const _cGarden = 'c-garden';
const _cDebt = 'c-debt';
const _cSalary = 'c-salary';
const _cFreelance = 'c-freelance';
const _cInterest = 'c-interest';

const _investmentAccounts = <String>[_stocks, _gold, _crypto, _etf, _pension];
const _receivables = <String>[_loanJohn, _invoice, _refund, _dinner];

/// Builds the full seeded transaction history relative to [today]. Pure and
/// deterministic — same input always yields the same list (spec §3, §7).
List<Txn> buildDevTxns(DateTime today) => _Gen(today)._run();

/// The alternate debug fixture: real accounts and categories (starting balances
/// back-computed so documented targets hold) plus the seeded history.
AppStore buildDevSeedStore() {
  final prod = buildSeedStore();
  final today = AppStore.today;
  final devTxns = buildDevTxns(today);

  // Sum each account's signed contribution using the canonical ledger rule
  // (AppStore._effectOn) — never re-implemented here — by probing a store whose
  // starting balances are all zero. balanceOf then returns Σ(effects) alone.
  final probe = AppStore(
    accounts: [for (final a in prod.accounts) _withOpening(a, 0)],
    categories: prod.categories,
    txns: devTxns,
    goals: const [],
    tasks: const [],
  );

  final devAccounts = <Account>[
    for (final a in prod.accounts)
      // opening = documented target − Σ(seeded contributions)  (spec §4)
      _withOpening(a, prod.balanceOf(a.id) - probe.balanceOf(a.id)),
  ];

  return AppStore(
    accounts: devAccounts,
    categories: prod.categories,
    txns: devTxns,
    // Preserve the full goal/task fixture, including archived goals, so the
    // other tabs still render as documented (spec §9 — no Planner/Insight data
    // beyond what these transactions produce).
    goals: [...prod.goals, ...prod.archivedGoals],
    tasks: prod.tasks,
  );
}

Account _withOpening(Account a, double opening) => Account(
      id: a.id,
      name: a.name,
      group: a.group,
      currency: a.currency,
      startingBalance: opening,
      creditLimit: a.creditLimit,
      statementDay: a.statementDay,
      paymentDue: a.paymentDue,
      hidden: a.hidden,
      archived: a.archived,
      countAsSpendable: a.countAsSpendable,
      icon: a.icon,
      openedOn: a.openedOn,
    );

/// Transaction factory. Only amounts are randomised (deterministically); every
/// date is computed, so the day-distribution and range-preset coverage in §5
/// hold by construction rather than by luck.
class _Gen {
  _Gen(this.today) : _rng = Random(_kSeed);

  final DateTime today;
  final Random _rng;
  final List<Txn> _txns = [];
  int _seq = 0;

  String _id() => '$kDevSeedIdPrefix${(++_seq).toString().padLeft(4, '0')}';
  double _amt(int lo, int hi) => (lo + _rng.nextInt(hi - lo + 1)).toDouble();
  T _pick<T>(List<T> xs) => xs[_rng.nextInt(xs.length)];

  /// [monthsAgo] months before [today], on [day]. Days are kept ≤ 28 so short
  /// months never roll the date into the next month.
  DateTime _at(int monthsAgo, int day, [int hour = 12, int minute = 0]) =>
      DateTime(today.year, today.month - monthsAgo, day, hour, minute);

  String _cur(String account) => account == _cashEur ? 'EUR' : 'USD';

  // Future-dated records are dropped so current-balance reconciliation stays
  // exact (see report). The guard makes that impossible to violate by accident.
  bool _future(DateTime d) => d.isAfter(today);

  void _expense(String account, String category, DateTime date, double amount,
      {String note = '', List<String> tags = const []}) {
    if (_future(date)) return;
    _txns.add(Txn(
      id: _id(),
      type: TxnType.expense,
      amount: amount,
      currency: _cur(account),
      fromRef: account,
      toRef: category,
      date: date,
      note: note,
      tags: tags,
    ));
  }

  void _income(String category, String account, DateTime date, double amount,
      {String note = '', List<String> tags = const []}) {
    if (_future(date)) return;
    _txns.add(Txn(
      id: _id(),
      type: TxnType.income,
      amount: amount,
      currency: _cur(account),
      fromRef: category,
      toRef: account,
      date: date,
      note: note,
      tags: tags,
    ));
  }

  void _transfer(String from, String to, DateTime date, double amount,
      {String note = '', double? toAmount, double? exchangeRate, double? fee}) {
    if (_future(date)) return;
    _txns.add(Txn(
      id: _id(),
      type: TxnType.transfer,
      amount: amount,
      currency: _cur(from),
      fromRef: from,
      toRef: to,
      date: date,
      toAmount: toAmount,
      exchangeRate: exchangeRate,
      fee: fee,
      note: note,
    ));
  }

  void _rebalance(String account, DateTime date, double delta,
      {String note = ''}) {
    if (_future(date)) return;
    _txns.add(Txn(
      id: _id(),
      type: TxnType.rebalance,
      amount: delta,
      currency: _cur(account),
      fromRef: account,
      toRef: account,
      date: date,
      note: note,
    ));
  }

  List<Txn> _run() {
    _recurring();
    _spending();
    _investments();
    _receivablesAndPayables();
    _valuables();
    _multiCurrency();
    _walletFunding();
    _shapedKeys();
    _shapedDays();
    _familyOverdraft();
    return _txns;
  }

  // ── Recurring, fixed-day series (feed the Same-transactions frequency line) ─
  void _recurring() {
    // Salary — 28th. 14 full months back (the current month's 28th is future).
    for (var m = 1; m <= 14; m++) {
      _income(_cSalary, _checking, _at(m, 28, 9), 5200, note: 'Monthly salary');
    }
    // Rent — 1st, including the current month.
    const rentNotes = ['August rent', 'Ağustos kirası', 'Monthly rent', 'Kira'];
    for (var m = 0; m <= 14; m++) {
      _expense(_checking, _cHousing, _at(m, 1, 10), _amt(1050, 1150),
          note: _pick(rentNotes));
    }
    // Transit pass — 5th.
    for (var m = 0; m <= 14; m++) {
      _expense(_checking, _cTransport, _at(m, 5, 8), 132,
          note: 'Monthly transit pass');
    }
    // Subscriptions — Netflix (2nd) and Spotify (3rd), near-constant.
    for (var m = 0; m <= 14; m++) {
      _expense(_amex, _cSubs, _at(m, 2, 7), 22, note: 'Netflix');
    }
    for (var m = 0; m <= 14; m++) {
      _expense(_amex, _cSubs, _at(m, 3, 7, 30), 10, note: 'Spotify');
    }
    // Gym — 2nd.
    for (var m = 0; m <= 14; m++) {
      _expense(_checking, _cPersonal, _at(m, 2, 8), 50,
          note: 'Gym membership');
    }
    // Bank-loan repayments — transfers only (spec §2 Bank Loans row).
    for (var m = 1; m <= 8; m++) {
      _transfer(_checking, _autoloan, _at(m, 15, 9), 300,
          note: 'Auto loan payment');
    }
    for (var m = 1; m <= 8; m++) {
      _transfer(_checking, _mortgage, _at(m, 1, 8), 500,
          note: 'Mortgage payment');
    }
    // Credit-card payments in, plus a few refunds out (bidirectional pair).
    for (var m = 1; m <= 8; m++) {
      _transfer(_checking, _amex, _at(m, 10, 9), _amt(300, 700),
          note: 'Partial payment before statement');
    }
    for (var m = 1; m <= 6; m++) {
      _transfer(_checking, _bonus, _at(m, 12, 9), _amt(150, 400),
          note: 'Card payment');
    }
    for (final m in [2, 5, 8]) {
      _transfer(_amex, _checking, _at(m, 22, 9), _amt(50, 150),
          note: 'Statement refund');
    }
  }

  // ── Everyday spending: weekend grocery/dining clusters, one-offs ───────────
  void _spending() {
    const grocery = [
      'Weekly shop',
      'Bakery & fruit',
      'Groceries',
      'Market run',
      'Fresh produce',
    ];
    // Groceries on two accounts → two separate Same-transactions lists (§5).
    for (var m = 1; m <= 8; m++) {
      for (final d in [6, 20]) {
        _expense(_checking, _cGroceries, _at(m, d, 17), _amt(80, 220),
            note: _pick(grocery));
      }
    }
    for (var m = 1; m <= 8; m++) {
      for (final d in [13, 27]) {
        _expense(_cashUsd, _cGroceries, _at(m, d, 18), _amt(80, 220),
            note: _pick(grocery));
      }
    }
    // Dining.
    const dining = ['Dinner out', 'Coffee', 'Lunch with team', 'Restaurant'];
    for (var m = 1; m <= 8; m++) {
      for (final d in [7, 21]) {
        _expense(_amex, _cEatingOut, _at(m, d, 20), _amt(15, 70),
            note: _pick(dining));
      }
    }
    for (var m = 1; m <= 6; m++) {
      _expense(_cashUsd, _cEatingOut, _at(m, 14, 13), _amt(10, 45),
          note: _pick(['Coffee', 'Snack', 'Lunch']));
    }
    // Shopping.
    for (var m = 1; m <= 6; m++) {
      _expense(_bonus, _cShopping, _at(m, 17, 16), _amt(60, 300),
          note: _pick(['Autumn jacket', 'Sneakers', 'Home decor', 'Gift']),
          tags: const ['home']);
    }
    for (var m = 1; m <= 4; m++) {
      _expense(_amex, _cShopping, _at(m, 23, 13), _amt(40, 200),
          note: _pick(['Books', 'Gadget', 'Headphones']));
    }
    // Entertainment (tagged 'fun').
    for (var m = 1; m <= 8; m++) {
      _expense(_amex, _cEntertainment, _at(m, 9, 20), _amt(30, 260),
          note: _pick(
              ['Concert tickets', 'Cinema night', 'Festival pass', 'Theatre']),
          tags: const ['fun']);
    }
    // Health.
    for (var m = 1; m <= 6; m++) {
      _expense(_checking, _cHealth, _at(m, 11, 10), _amt(20, 150),
          note: _pick(['Pharmacy', 'Doctor visit', 'Dentist', 'Eczane']));
    }
    // Debt payments.
    for (var m = 1; m <= 6; m++) {
      _expense(_checking, _cDebt, _at(m, 4, 9), _amt(50, 200),
          note: _pick(['Loan interest', 'Card interest', 'Debt payment']));
    }
    // Garden — a removed category (removedOn 2026-06-12): only history before it.
    for (var m = 2; m <= 8; m++) {
      _expense(_cashUsd, _cGarden, _at(m, 8, 11), _amt(15, 60),
          note: _pick(['Garden supplies', 'Seeds', 'Plant pots']));
    }
    // Freelance income (tagged 'side').
    for (var m = 1; m <= 8; m++) {
      _income(_cFreelance, _checking, _at(m, 18, 18), _amt(400, 1200),
          note: _pick(
              ['Landing page project', 'Design work', 'Consulting', 'Logo']),
          tags: const ['side']);
    }
  }

  // ── Investments: contributions in, dividends as income, fees as expenses ───
  void _investments() {
    for (var i = 0; i < _investmentAccounts.length; i++) {
      final acc = _investmentAccounts[i];
      // Dividends / gains (income, c-interest) — 6 each.
      for (var m = 1; m <= 6; m++) {
        _income(_cInterest, acc, _at(m, 16 + i, 10), _amt(20, 300),
            note: _pick(['Dividend', 'Interest', 'Coupon', 'Gain']));
      }
      // Contributions in (transfers) — 6 each.
      for (var m = 1; m <= 6; m++) {
        _transfer(_checking, acc, _at(m, 21 + i, 9), _amt(200, 600),
            note: 'Monthly contribution');
      }
      // Fees (expenses) — 2 each. Booked to Personal (no dedicated fee category).
      for (final m in [2, 5]) {
        _expense(acc, _cPersonal, _at(m, 24, 10), _amt(10, 40),
            note: 'Account fee');
      }
    }
    // Revaluations (rebalance — net worth only, excluded from income/expense).
    _rebalance(_gold, _at(2, 10, 10), 800, note: 'Gold price update');
    _rebalance(_gold, _at(8, 10, 10), -300, note: 'Gold price update');
    _rebalance(_stocks, _at(5, 10, 10), 500, note: 'Quarterly valuation');
    _rebalance(_crypto, _at(3, 10, 10), -400, note: 'Crypto valuation');
    _rebalance(_home, _at(6, 3, 10), 2000, note: 'Home revaluation');
  }

  // ── Receivables (money owed arriving) and payables (owed, paid down) ───────
  void _receivablesAndPayables() {
    for (var j = 0; j < _receivables.length; j++) {
      final acc = _receivables[j];
      for (var m = 1; m <= 6; m++) {
        _income(m.isEven ? _cInterest : _cFreelance, acc, _at(m, 5 + j, 12),
            _amt(50, 400),
            note: _pick(['Repayment', 'Instalment', 'Owed amount']));
      }
      _expense(acc, _cPersonal, _at(3, 6 + j, 12), _amt(10, 50),
          note: 'Adjustment');
    }
    // Payables: a monthly bill (expense grows what is owed) plus a settlement
    // transfer that pays it down.
    for (var m = 1; m <= 6; m++) {
      final winter = _at(m, 14, 9).month <= 2 || _at(m, 14, 9).month == 12;
      final bill = winter ? _amt(120, 180) : _amt(50, 90);
      _expense(_utilities, _cHousing, _at(m, 14, 9), bill,
          note: _pick(['Electricity bill', 'Şubat faturası', 'Utility bill']));
      _transfer(_checking, _utilities, _at(m, 20, 9), bill,
          note: 'Utilities settlement');
    }
    for (var m = 1; m <= 6; m++) {
      _expense(_rentPayable, _cHousing, _at(m, 7, 9), _amt(1050, 1150),
          note: 'Rent payable settlement');
      _transfer(_checking, _rentPayable, _at(m, 9, 9), _amt(1050, 1150),
          note: 'Landlord payment');
    }
    for (var m = 1; m <= 6; m++) {
      _expense(_internet, _cHousing, _at(m, 16, 9), _amt(35, 55),
          note: 'Internet & phone bill');
      _transfer(_checking, _internet, _at(m, 18, 9), _amt(35, 55),
          note: 'Internet settlement');
    }
  }

  // ── Valuables: property and a car barely transact (spec §2 — no symmetry) ──
  void _valuables() {
    _expense(_home, _cHousing, _at(6, 12, 10), 900, note: 'Property tax');
    _expense(_car, _cTransport, _at(4, 12, 10), 600,
        note: 'Yıllık sigorta ödemesi');
    _expense(_car, _cTransport, _at(8, 5, 10), _amt(200, 500),
        note: 'Car repair');
    _expense(_watches, _cPersonal, _at(5, 9, 12), 150, note: 'Watch service');
    _expense(_tech, _cShopping, _at(7, 9, 12), _amt(80, 200),
        note: 'Laptop repair');
  }

  // ── Multi-currency EUR wallet: native-EUR flows + cross-currency swaps ─────
  void _multiCurrency() {
    for (var m = 1; m <= 5; m++) {
      _expense(_cashEur, _cGroceries, _at(m, 10, 18), _amt(40, 120),
          note: _pick(['Market', 'Bakkal', 'Groceries']));
    }
    for (var m = 1; m <= 6; m++) {
      _expense(_cashEur, _cEatingOut, _at(m, 17, 20), _amt(15, 60),
          note: _pick(['Kafe', 'Dinner', 'Lunch']));
    }
    for (var m = 1; m <= 5; m++) {
      _expense(_cashEur, _cShopping, _at(m, 23, 15), _amt(30, 120),
          note: _pick(['Clothes', 'Shoes']), tags: const ['vacation']);
    }
    for (var m = 1; m <= 5; m++) {
      _income(_cFreelance, _cashEur, _at(m, 24, 18), _amt(100, 400),
          note: _pick(['Freelance EUR', 'Refund']));
    }
    // Cross-currency transfers (EUR ↔ USD). toAmount is in the destination
    // account's currency; the app's Fx rate is 1 EUR = 1.10 USD.
    _transfer(_cashEur, _cashUsd, _at(4, 16, 16, 20), 500,
        toAmount: 550, exchangeRate: 1.10, fee: 3, note: 'Holiday cash swap');
    _transfer(_cashUsd, _cashEur, _at(9, 12, 16), 300,
        toAmount: 300 / 1.10, exchangeRate: 1 / 1.10, fee: 2,
        note: 'EUR top-up');
    for (final m in [2, 6, 10]) {
      final eur = _amt(50, 200);
      _transfer(_cashEur, _checking, _at(m, 26, 12), eur,
          toAmount: eur * 1.10, exchangeRate: 1.10, note: 'Move to checking');
    }
  }

  // ── Wallet funding, so cash/family wallets meet the Spendable type spread ──
  //
  // Cash and family wallets are funded by *transfers* (ATM/allowance), not by
  // direct income — but §2's Spendable row still wants a little income on each.
  // With no "gift/allowance" income category to draw on, wallet income is
  // modelled loosely as cashback / a shared gig (flagged in the report).
  void _walletFunding() {
    // Cash (USD): ATM withdrawals in, occasional cashback.
    for (var m = 1; m <= 7; m++) {
      _transfer(_checking, _cashUsd, _at(m, 8, 10), _amt(100, 400),
          note: 'ATM withdrawal');
    }
    for (var m = 1; m <= 5; m++) {
      _income(_cInterest, _cashUsd, _at(m, 15, 12), _amt(5, 30),
          note: 'Card cashback');
    }
    // Cash (EUR): USD → EUR top-ups (cross-currency).
    for (final m in [3, 7]) {
      final usd = _amt(100, 300);
      _transfer(_checking, _cashEur, _at(m, 28, 12), usd,
          toAmount: usd / 1.10, exchangeRate: 1 / 1.10, note: 'EUR top-up');
    }
    // Family: shared side income (recent months, so it does not lift the early
    // overdraft crafted in _familyOverdraft).
    for (var m = 1; m <= 5; m++) {
      _income(_cFreelance, _family, _at(m, 24, 12), _amt(80, 220),
          note: 'Family gig');
    }
  }

  // ── Shaped Same-transactions keys (spec §5) ────────────────────────────────
  void _shapedKeys() {
    // A key with exactly one transaction (unique category+account+direction).
    _income(_cFreelance, _cashUsd, _at(7, 3, 12), 250, note: 'One-off gig');
    // A key with exactly two.
    _expense(_family, _cShopping, _at(6, 5, 12), 90, note: 'Kids clothes');
    _expense(_family, _cShopping, _at(3, 15, 12), 120, note: 'School supplies');
    // A key whose three transactions span < 14 days → frequency line hides.
    _expense(_cashUsd, _cPersonal, _at(5, 3, 12), 40, note: 'Haircut');
    _expense(_cashUsd, _cPersonal, _at(5, 7, 12), 25, note: '');
    _expense(_cashUsd, _cPersonal, _at(5, 11, 12), 60, note: 'Spa day');
  }

  // ── Shaped calendar days: distribution + text/layout stress (spec §5) ──────
  void _shapedDays() {
    // 12 isolated single-transaction days (months 9..14, days 25 & 27 are clear
    // of every recurring series).
    for (var m = 9; m <= 14; m++) {
      _expense(_cashUsd, _cEatingOut, _at(m, 25, 13), _amt(10, 40),
          note: _pick(['Coffee', 'Snack']));
      _expense(_checking, _cHealth, _at(m, 27, 10), _amt(20, 90),
          note: _pick(['Pharmacy', 'Vitamins']));
    }
    // Six explicit two-transaction days (day 23, months 9..14).
    for (var m = 9; m <= 14; m++) {
      _expense(_checking, _cGroceries, _at(m, 23, 11), _amt(60, 160),
          note: 'Weekly shop');
      _expense(_amex, _cEatingOut, _at(m, 23, 20), _amt(15, 50),
          note: 'Dinner out');
    }
    // Six explicit three-transaction days (day 21, months 9..14).
    for (var m = 9; m <= 14; m++) {
      _expense(_checking, _cGroceries, _at(m, 21, 9), _amt(50, 150),
          note: 'Market run');
      _expense(_amex, _cEntertainment, _at(m, 21, 19), _amt(20, 90),
          note: 'Cinema night', tags: const ['fun']);
      _expense(_cashUsd, _cEatingOut, _at(m, 21, 13), _amt(10, 40),
          note: 'Lunch');
    }
    // One dense 6-transaction day (§5 "5+"). Aug 2025 (m12), day 24 is clear.
    final dense = 12;
    _expense(_checking, _cGroceries, _at(dense, 24, 8), 75, note: 'Corner shop');
    _expense(_checking, _cEatingOut, _at(dense, 24, 10), 22, note: 'Brunch');
    _expense(_checking, _cTransport, _at(dense, 24, 12), 18, note: 'Taxi');
    _expense(_amex, _cShopping, _at(dense, 24, 14), 140, note: 'Home decor',
        tags: const ['home']);
    _expense(_checking, _cHealth, _at(dense, 24, 16), 35, note: 'Pharmacy');
    _income(_cFreelance, _checking, _at(dense, 24, 18), 300,
        note: 'Weekend gig', tags: const ['side']);

    // A day whose transactions net to zero (income +200, expense −200).
    _income(_cFreelance, _checking, _at(11, 20, 10), 200, note: 'Refund');
    _expense(_checking, _cGroceries, _at(11, 20, 15), 200, note: 'Big shop');

    // A two-row day with a large income and a large expense (total stays hidden
    // because the day has fewer than three transactions).
    _income(_cSalary, _checking, _at(9, 6, 9), 5000, note: 'Annual bonus');
    _expense(_checking, _cHousing, _at(9, 6, 15), 4800,
        note: 'Rent deposit for the new apartment, refundable on move-out day');

    // Text/layout stress: no-description rows and a long (60+ char) description.
    _expense(_cashUsd, _cGroceries, _at(10, 6, 12), 45, note: '');
    _expense(_checking, _cShopping, _at(7, 6, 12), 320,
        note:
            'Quarterly home maintenance: plumbing, gutter cleaning and hallway repainting');
  }

  // ── A crafted overdraft: Family Wallet dips below zero, then recovers ──────
  //
  // Target balance for Family Wallet is +1,700. A large early expense drives
  // the running balance negative; monthly top-ups from checking climb it back.
  // Because opening = target − Σ(effects), keeping the big inflows *after* the
  // early expense guarantees the running balance is negative for that stretch.
  void _familyOverdraft() {
    _expense(_family, _cHousing, _at(14, 10, 9), 1600, note: 'Acil aile masrafı');
    for (var m = 1; m <= 13; m++) {
      _transfer(_checking, _family, _at(m, 10, 9), 230, note: 'Family allowance');
    }
    for (var m = 1; m <= 6; m++) {
      _expense(_family, _cGroceries, _at(m, 19, 12), 100, note: 'Family shop');
    }
  }
}
