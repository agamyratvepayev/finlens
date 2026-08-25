import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/fx.dart';
import '../../l10n/app_localizations.dart';
import 'trans_filter.dart';

/// What the ledger is currently showing.
///
/// Group and account ledgers are one screen with a different scope, not two
/// screens: the period strip, the toolbar, the row and its expansion would
/// otherwise each need fixing twice.
sealed class LedgerScope {
  const LedgerScope();

  /// Accounts whose transactions belong to this scope.
  List<Account> accountsIn(AppStore store);

  /// Nav title, before the chevron.
  String title(AppStore store, AppLocalizations l);
}

class AllAccountsScope extends LedgerScope {
  const AllAccountsScope();

  @override
  List<Account> accountsIn(AppStore store) => store.accounts;

  @override
  String title(AppStore store, AppLocalizations l) => l.ledgerAllAccounts;
}

class GroupScope extends LedgerScope {
  const GroupScope(this.group);

  final AccountGroup group;

  @override
  List<Account> accountsIn(AppStore store) => store.accountsIn(group);

  @override
  String title(AppStore store, AppLocalizations l) => group.label(l);
}

class AccountScope extends LedgerScope {
  const AccountScope(this.accountId);

  final String accountId;

  @override
  List<Account> accountsIn(AppStore store) {
    final account = store.accountById(accountId);
    return account == null ? const [] : [account];
  }

  @override
  String title(AppStore store, AppLocalizations l) =>
      store.accountById(accountId)?.name ?? l.ledgerAccountFallback;
}

/// Whether the list currently on screen is a legible running-balance tape.
///
/// A balance column is only a column: each row must differ from the one below
/// it by that row's own amount. One foreign account, one hidden row, or one
/// non-chronological sort and that stops being true, at which point the figure
/// is decoration. The three conditions therefore live here as one predicate
/// rather than being restated at each call site.
class LedgerListShape {
  const LedgerListShape({
    required this.accountCount,
    required this.sort,
    required this.narrowed,
  });

  /// Accounts represented in the list — derived from the count, never the scope
  /// class, so a one-account group qualifies as a tape just as an account screen
  /// does.
  final int accountCount;

  /// The active sort; only the two date sorts leave the column reconciling
  /// (amount/name orders make it arbitrary). Reuses [TransSort.groupsByDay] —
  /// the day headers are honest under exactly the sorts the balance column is.
  final TransSort sort;

  /// An active filter, search query, or direction chip — the same `shown !=
  /// total` quantity the toolbar's "N of M" label reports. A hidden row breaks
  /// the arithmetic between the two rows around it.
  final bool narrowed;

  bool get isSingleAccount => accountCount == 1;

  bool get showsRunningBalance =>
      isSingleAccount && sort.groupsByDay && !narrowed;
}

/// How a transaction reads once the current scope is taken into account.
enum FlowKind {
  /// Money arrived from outside the scope.
  inflow,

  /// Money left the scope.
  outflow,

  /// A transfer with both ends inside the scope — the money never left, so it
  /// is neither, and it must not be counted in either total.
  internal,
}

/// One row's scope-resolved facts. Computing these once per transaction keeps
/// the row widget free of scope conditionals.
class ScopedTxn {
  const ScopedTxn({
    required this.txn,
    required this.kind,
    required this.signedAmount,
    required this.counterpartyLine,
  });

  final Txn txn;
  final FlowKind kind;

  /// Base-currency magnitude, always positive — the list renders unsigned and
  /// lets colour carry direction.
  final double signedAmount;

  /// Line 2's account/transfer text. Null when the row should fall back to the
  /// note-or-time rule (account scope, non-transfer).
  final String? counterpartyLine;

  bool get isInternal => kind == FlowKind.internal;

  /// What this row adds to its day's net. An internal transfer contributes
  /// nothing — the money never left the scope — which is why it is excluded
  /// from In and Out as well.
  double get netContribution => switch (kind) {
        FlowKind.inflow => signedAmount,
        FlowKind.outflow => -signedAmount,
        FlowKind.internal => 0,
      };

  /// Ledger rows and day totals are signed; the Balance screen's are not.
  /// There, colour carries direction and every amount ends on one right edge;
  /// here the sign is the point, so an internal transfer reads as neither.
  double get displayAmount => switch (kind) {
        FlowKind.inflow => signedAmount,
        FlowKind.outflow => -signedAmount,
        FlowKind.internal => signedAmount,
      };
}

/// Resolves transactions against a scope: which ones belong, how each one
/// reads, and what the In/Out totals are.
class LedgerQuery {
  LedgerQuery({
    required this.store,
    required this.scope,
    required this.start,
    required this.end,
  }) : _ids = scope.accountsIn(store).map((a) => a.id).toSet();

  final AppStore store;
  final LedgerScope scope;
  final DateTime start;
  final DateTime end;

  final Set<String> _ids;

  bool _inScope(String ref) => _ids.contains(ref);

  bool _inPeriod(DateTime d) =>
      !d.isBefore(start) && !d.isAfter(end);

  /// Every transaction touching the scope inside the period, newest first.
  ///
  /// Index-backed: candidates come from the store's per-account index
  /// ([AppStore.txnsForAccounts]) rather than a scan of every transaction.
  List<ScopedTxn> rows() {
    final candidates = store.txnsForAccounts(_ids)
      ..sort((a, b) => b.date.compareTo(a.date));
    final out = <ScopedTxn>[];
    for (final t in candidates) {
      if (!_inPeriod(t.date)) continue;
      final touchesFrom = _inScope(t.fromRef);
      final touchesTo = _inScope(t.toRef);
      if (!touchesFrom && !touchesTo) continue;
      out.add(_resolve(t, touchesFrom: touchesFrom, touchesTo: touchesTo));
    }
    return out;
  }

  ScopedTxn _resolve(
    Txn t, {
    required bool touchesFrom,
    required bool touchesTo,
  }) {
    final currency = store.accountById(
          touchesFrom ? t.fromRef : t.toRef,
        )?.currency ??
        Fx.baseCurrency;

    switch (t.type) {
      case TxnType.transfer:
        // The rule the whole screen turns on: a transfer is internal only when
        // both ends sit inside the current scope. The same transfer is
        // therefore grey in a group ledger and red in one of its accounts —
        // that is correct, not an inconsistency.
        final internal = touchesFrom && touchesTo;
        final leaving = touchesFrom;
        return ScopedTxn(
          txn: t,
          kind: internal
              ? FlowKind.internal
              : (leaving ? FlowKind.outflow : FlowKind.inflow),
          signedAmount: Fx.toBase(t.amount, currency).abs(),
          counterpartyLine: _transferLine(t, leaving: leaving),
        );

      case TxnType.expense:
        return ScopedTxn(
          txn: t,
          kind: FlowKind.outflow,
          signedAmount: Fx.toBase(t.amount, currency).abs(),
          counterpartyLine: null,
        );

      case TxnType.income:
        return ScopedTxn(
          txn: t,
          kind: FlowKind.inflow,
          signedAmount: Fx.toBase(t.amount, currency).abs(),
          counterpartyLine: null,
        );

      case TxnType.rebalance:
        // Non-cash, but the balance genuinely moved, so it still counts.
        return ScopedTxn(
          txn: t,
          kind: t.amount >= 0 ? FlowKind.inflow : FlowKind.outflow,
          signedAmount: Fx.toBase(t.amount, currency).abs(),
          counterpartyLine: null,
        );
    }
  }

  /// Line 2 for a transfer. In account scope the current side is already known
  /// from the header, so only the other end is printed.
  String _transferLine(Txn t, {required bool leaving}) {
    final from = store.refName(t.fromRef);
    final to = store.refName(t.toRef);
    if (scope is AccountScope) {
      return leaving ? '→ $to' : '← $from';
    }
    return '$from → $to';
  }

  /// Money in, excluding anything that never left the scope.
  double get totalIn => rows()
      .where((r) => r.kind == FlowKind.inflow)
      .fold(0.0, (sum, r) => sum + r.signedAmount);

  double get totalOut => rows()
      .where((r) => r.kind == FlowKind.outflow)
      .fold(0.0, (sum, r) => sum + r.signedAmount);

  double get net => totalIn - totalOut;

  /// The figure under the nav title.
  double get balance => switch (scope) {
        AllAccountsScope() => store.netWorth,
        GroupScope(:final group) => store.groupTotal(group),
        AccountScope(:final accountId) => store.balanceOf(accountId),
      };

  /// The currency [balance] is denominated in — resolved from the same scope,
  /// side by side, so the figure and its symbol can never drift apart. An
  /// account ledger's balance is native to that account; a group or all-
  /// accounts total sums across currencies and so is base-currency.
  String get currency => switch (scope) {
        AllAccountsScope() => Fx.baseCurrency,
        GroupScope() => Fx.baseCurrency,
        AccountScope(:final accountId) =>
          store.accountById(accountId)?.currency ?? Fx.baseCurrency,
      };
}

/// The synthesized opening-balance receipt for an account (spec §1). It follows
/// the grammar of the ledger — a row with a date, filed in a day group — but
/// takes no part in its arithmetic: it is never a [ScopedTxn], never enters
/// [DayGroup.total], the day count, or the §2B guard, and never reaches a query
/// or aggregate. It is display-only, derived from the account's own fields.
class OpeningEntry {
  const OpeningEntry(this.account);

  final Account account;

  /// Unsigned magnitude of the floor, in the account's own currency — the row
  /// renders it unsigned (spec §2.3).
  double get amount => account.startingBalance.abs();

  /// The signed floor, matching the running-balance column's convention — the
  /// figure beneath the amount (negative for liabilities, spec §2.4).
  double get runningBalance => account.startingBalance;
}

/// One calendar day's rendered rows, and whether its net is worth printing.
///
/// [rows] is exactly what the list draws for transactions, so [total] and the
/// rows can never disagree. [opening], when present, is the account's
/// opening-balance receipt rendered *after* the rows — it is deliberately not in
/// [rows], so it contributes nothing to [total], the day count or [showsDayTotal]
/// (spec §8.1: a floor is grammar, not arithmetic).
class DayGroup {
  const DayGroup({required this.date, required this.rows, this.opening});

  final DateTime date;
  final List<ScopedTxn> rows;
  final OpeningEntry? opening;

  /// Same day, with the opening receipt attached (or replaced).
  DayGroup withOpening(OpeningEntry entry) =>
      DayGroup(date: date, rows: rows, opening: entry);

  double get total =>
      rows.fold(0.0, (sum, r) => sum + r.netContribution);

  /// A single row already prints the day's net 40pt below the header, so
  /// repeating it there carries no information and competes with the rows.
  ///
  /// The rule is count-based, never value-based: two rows always show the
  /// total, even when it happens to equal one of them, so the user can trust
  /// that a multi-row day always states its net.
  bool get showsDayTotal {
    if (rows.length > 1) return true;
    if (rows.isEmpty) return false;
    // Only suppressed when provably redundant with what is on screen. Today
    // the list filters before grouping, so this always holds for one row —
    // the guard is here so a filtered view can never silently drop a figure
    // the rows do not account for.
    return total != rows.single.netContribution;
  }
}
