/// Currency conversion.
///
/// Spec 3.4 calls for a live rate with a manual override; until a rate feed is
/// wired in, these fixed rates stand in for it. Every aggregate figure in the
/// app (net worth, group totals, spendable) converts to the store's base
/// currency through here, so a EUR wallet is never summed into a TMT total
/// unconverted.
///
/// The base is a stored per-store setting now (`AppStore.baseCurrency`), not a
/// compile-time constant: callers pass it in, so [Fx] stays a pure function of
/// its inputs with no dependency on the store.
abstract final class Fx {
  /// Value of one unit of each currency, expressed in USD (USD == 1.0). This is
  /// the fixed rate table only; the *display* base is chosen per store and
  /// supplied to [convert]/[toBase] by the caller.
  static const _perUnit = <String, double>{
    'USD': 1.0,
    'EUR': 1.10,
    'GBP': 1.28,
    'TRY': 0.031,
    'TMT': 0.286, // Turkmen manat (official peg ≈ 3.5 TMT/USD)
    'JPY': 0.0067,
  };

  static double rate(String from, String to) {
    final f = _perUnit[from] ?? 1.0;
    final t = _perUnit[to] ?? 1.0;
    return f / t;
  }

  static double toBase(double amount, String currency) =>
      amount * (_perUnit[currency] ?? 1.0);

  static double convert(double amount, String from, String to) =>
      amount * rate(from, to);

  /// Pure conversion given the two rates, so the rate table can live in the
  /// store and [Fx] stays testable without one (spec 021a §1b). Each rate is
  /// *units of that currency per one unit of the reporting currency* — the base
  /// itself is `1`. Converts [amount] (in the `from` currency) into the `to`
  /// currency: `amount` → base is `amount / fromRate`, base → `to` is `× toRate`.
  ///
  /// **Null in, null out.** A currency with no rate is a state, not a zero
  /// (021a §2): if either rate is null (or non-positive, which a real rate never
  /// is) the conversion cannot be computed and the caller must decide what to
  /// show. `?? 1.0` is exactly the bug 021a removes.
  static double? convertWith(double amount, double? fromRate, double? toRate) {
    if (fromRate == null || toRate == null) return null;
    if (fromRate <= 0 || toRate <= 0) return null;
    return amount * toRate / fromRate;
  }

  /// The initial rate table for a fresh store whose reporting currency is
  /// [base], seeded from the six numbers in [_perUnit] (spec 021a §5). Each
  /// value is *units of the code per one unit of [base]* — the direction the
  /// store quotes rates in — so for base USD, `TRY → 1 / 0.031 ≈ 32.26`. The
  /// base is deliberately absent (its rate is `1` by definition), and so is any
  /// code [_perUnit] does not list.
  static Map<String, double> seedRates(String base) {
    final basePerUnit = _perUnit[base];
    if (basePerUnit == null) return const {};
    final out = <String, double>{};
    for (final entry in _perUnit.entries) {
      if (entry.key == base) continue;
      if (entry.value <= 0) continue;
      // units of `code` per 1 base = (base in USD) / (code in USD).
      out[entry.key] = basePerUnit / entry.value;
    }
    return out;
  }
}

/// Where a proposed exchange rate came from (spec 021b §3a), which decides the
/// rate row's marker: none for the base or the current stored rate, a history
/// glyph for a back-dated entry's frozen rate, an edit glyph once the user types.
enum RateProposalSource { base, stored, earlierEntry, manual }

/// A proposed rate plus its provenance — what `AppStore.rateProposal` returns so
/// the Quick Add rate row can show the right marker (spec 021b §3a). [rate] is
/// null when the currency has no stored rate and no earlier entry to borrow from
/// (the blocked case — §3b).
class RateProposal {
  const RateProposal({required this.rate, required this.source, this.entryDate});

  final double? rate;
  final RateProposalSource source;
  final DateTime? entryDate;
}
