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
}
