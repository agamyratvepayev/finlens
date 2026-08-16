/// Currency conversion.
///
/// Spec 3.4 calls for a live rate with a manual override; until a rate feed is
/// wired in, these fixed rates stand in for it. Every aggregate figure in the
/// app (net worth, group totals, spendable) converts to [baseCurrency] through
/// here, so a EUR wallet is never summed into a USD total unconverted.
abstract final class Fx {
  static const baseCurrency = 'USD';

  /// Value of one unit of each currency, expressed in [baseCurrency].
  static const _perUnit = <String, double>{
    'USD': 1.0,
    'EUR': 1.10,
    'GBP': 1.28,
    'TRY': 0.031,
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
