/// A currency definition — the metadata the app needs to *display* an amount in
/// a currency. FinLens applies **no exchange rate** to custom currencies (spec
/// §7a / §10): a [CurrencyDef] governs formatting only, never conversion, which
/// stays the province of [Fx] and its built-in rate table.
///
/// Two populations share this type:
///   - **built-ins** — the ISO 4217 catalog in [kBuiltInCurrencies], each with a
///     name and (for the common ones) a symbol; [custom] is false.
///   - **user-defined** — created through the Add-currency sheet, persisted with
///     the user's data, and registered at load through [setCustomCurrencies] so
///     the dependency-free [money] formatter can reach them without a store.
///
/// Formatting rules (spec §7a):
///   - the displayed token is [symbol] when present, else the [code];
///   - **spacing depends on the token, not its position**: a symbol sits flush
///     against the number (`m9,850`, `9,850m`); a code takes a space
///     (`TMT 9,850`, `9,850 TMT`);
///   - [symbolBefore] governs the token's side;
///   - [decimals] is fixed per currency (0 for JPY-like, 3 for dinar-like).
class CurrencyDef {
  const CurrencyDef({
    required this.code,
    required this.name,
    this.symbol,
    this.decimals = 2,
    this.symbolBefore = true,
    this.custom = false,
  });

  final String code;
  final String name;

  /// The glyph shown in place of the code (`$`, `€`, `m`). Null → the code is
  /// used as the token, spaced from the number.
  final String? symbol;

  /// Fixed number of fraction digits, 0..3.
  final int decimals;

  /// Token side: true renders it before the amount, false after.
  final bool symbolBefore;

  /// True for user-defined currencies. Built-ins keep the app's legacy money
  /// formatting untouched; only custom currencies take the metadata-driven path.
  final bool custom;

  /// The token actually rendered — the symbol if the user gave one, else the
  /// code (spec §7a: an absent symbol falls back to the code).
  String get token => (symbol != null && symbol!.isNotEmpty) ? symbol! : code;

  /// Whether the rendered token is a bare symbol (flush against the number) or a
  /// code (spaced from it) — spec §7a's spacing rule.
  bool get tokenIsSymbol => symbol != null && symbol!.isNotEmpty;

  CurrencyDef copyWith({
    String? code,
    String? name,
    String? symbol,
    bool clearSymbol = false,
    int? decimals,
    bool? symbolBefore,
    bool? custom,
  }) =>
      CurrencyDef(
        code: code ?? this.code,
        name: name ?? this.name,
        symbol: clearSymbol ? null : (symbol ?? this.symbol),
        decimals: decimals ?? this.decimals,
        symbolBefore: symbolBefore ?? this.symbolBefore,
        custom: custom ?? this.custom,
      );
}

/// The built-in ISO 4217 catalog, alphabetical by code. Names are English (the
/// same pragmatic choice the icon catalog makes); the picker searches code and
/// name, and a symbol is provided only for the currencies that have a widely
/// recognised one — the rest fall back to their code (spec §6/§7a). Decimals
/// follow ISO 4217 minor-unit counts (0 for JPY/KRW/…; 3 for the Gulf dinars).
const List<CurrencyDef> kBuiltInCurrencies = [
  CurrencyDef(code: 'AED', name: 'UAE Dirham'),
  CurrencyDef(code: 'AFN', name: 'Afghan Afghani', symbol: '؋'),
  CurrencyDef(code: 'ALL', name: 'Albanian Lek'),
  CurrencyDef(code: 'AMD', name: 'Armenian Dram', symbol: '֏'),
  CurrencyDef(code: 'ARS', name: 'Argentine Peso', symbol: r'$'),
  CurrencyDef(code: 'AUD', name: 'Australian Dollar', symbol: r'$'),
  CurrencyDef(code: 'AZN', name: 'Azerbaijani Manat', symbol: '₼'),
  CurrencyDef(code: 'BAM', name: 'Bosnia-Herzegovina Mark'),
  CurrencyDef(code: 'BDT', name: 'Bangladeshi Taka', symbol: '৳'),
  CurrencyDef(code: 'BGN', name: 'Bulgarian Lev'),
  CurrencyDef(code: 'BHD', name: 'Bahraini Dinar', decimals: 3),
  CurrencyDef(code: 'BND', name: 'Brunei Dollar', symbol: r'$'),
  CurrencyDef(code: 'BOB', name: 'Bolivian Boliviano'),
  CurrencyDef(code: 'BRL', name: 'Brazilian Real', symbol: r'R$'),
  CurrencyDef(code: 'BYN', name: 'Belarusian Ruble'),
  CurrencyDef(code: 'CAD', name: 'Canadian Dollar', symbol: r'$'),
  CurrencyDef(code: 'CHF', name: 'Swiss Franc'),
  CurrencyDef(code: 'CLP', name: 'Chilean Peso', symbol: r'$', decimals: 0),
  CurrencyDef(code: 'CNY', name: 'Chinese Yuan', symbol: '¥'),
  CurrencyDef(code: 'COP', name: 'Colombian Peso', symbol: r'$'),
  CurrencyDef(code: 'CRC', name: 'Costa Rican Colón', symbol: '₡'),
  CurrencyDef(code: 'CZK', name: 'Czech Koruna', symbol: 'Kč', symbolBefore: false),
  CurrencyDef(code: 'DKK', name: 'Danish Krone'),
  CurrencyDef(code: 'DOP', name: 'Dominican Peso', symbol: r'$'),
  CurrencyDef(code: 'DZD', name: 'Algerian Dinar'),
  CurrencyDef(code: 'EGP', name: 'Egyptian Pound'),
  CurrencyDef(code: 'EUR', name: 'Euro', symbol: '€'),
  CurrencyDef(code: 'GBP', name: 'British Pound', symbol: '£'),
  CurrencyDef(code: 'GEL', name: 'Georgian Lari', symbol: '₾'),
  CurrencyDef(code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵'),
  CurrencyDef(code: 'HKD', name: 'Hong Kong Dollar', symbol: r'$'),
  CurrencyDef(code: 'HRK', name: 'Croatian Kuna'),
  CurrencyDef(code: 'HUF', name: 'Hungarian Forint', symbol: 'Ft', symbolBefore: false),
  CurrencyDef(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp'),
  CurrencyDef(code: 'ILS', name: 'Israeli New Shekel', symbol: '₪'),
  CurrencyDef(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
  CurrencyDef(code: 'IQD', name: 'Iraqi Dinar', decimals: 3),
  CurrencyDef(code: 'IRR', name: 'Iranian Rial'),
  CurrencyDef(code: 'ISK', name: 'Icelandic Króna', decimals: 0),
  CurrencyDef(code: 'JOD', name: 'Jordanian Dinar', decimals: 3),
  CurrencyDef(code: 'JPY', name: 'Japanese Yen', symbol: '¥', decimals: 0),
  CurrencyDef(code: 'KES', name: 'Kenyan Shilling'),
  CurrencyDef(code: 'KGS', name: 'Kyrgyzstani Som'),
  CurrencyDef(code: 'KHR', name: 'Cambodian Riel', symbol: '៛'),
  CurrencyDef(code: 'KRW', name: 'South Korean Won', symbol: '₩', decimals: 0),
  CurrencyDef(code: 'KWD', name: 'Kuwaiti Dinar', decimals: 3),
  CurrencyDef(code: 'KZT', name: 'Kazakhstani Tenge', symbol: '₸'),
  CurrencyDef(code: 'LBP', name: 'Lebanese Pound'),
  CurrencyDef(code: 'LKR', name: 'Sri Lankan Rupee', symbol: 'Rs'),
  CurrencyDef(code: 'MAD', name: 'Moroccan Dirham'),
  CurrencyDef(code: 'MDL', name: 'Moldovan Leu'),
  CurrencyDef(code: 'MXN', name: 'Mexican Peso', symbol: r'$'),
  CurrencyDef(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM'),
  CurrencyDef(code: 'NGN', name: 'Nigerian Naira', symbol: '₦'),
  CurrencyDef(code: 'NOK', name: 'Norwegian Krone'),
  CurrencyDef(code: 'NPR', name: 'Nepalese Rupee', symbol: 'Rs'),
  CurrencyDef(code: 'NZD', name: 'New Zealand Dollar', symbol: r'$'),
  CurrencyDef(code: 'OMR', name: 'Omani Rial', decimals: 3),
  CurrencyDef(code: 'PEN', name: 'Peruvian Sol', symbol: 'S/'),
  CurrencyDef(code: 'PHP', name: 'Philippine Peso', symbol: '₱'),
  CurrencyDef(code: 'PKR', name: 'Pakistani Rupee', symbol: 'Rs'),
  CurrencyDef(code: 'PLN', name: 'Polish Złoty', symbol: 'zł', symbolBefore: false),
  CurrencyDef(code: 'QAR', name: 'Qatari Riyal'),
  CurrencyDef(code: 'RON', name: 'Romanian Leu', symbol: 'lei', symbolBefore: false),
  CurrencyDef(code: 'RSD', name: 'Serbian Dinar'),
  CurrencyDef(code: 'RUB', name: 'Russian Ruble', symbol: '₽', symbolBefore: false),
  CurrencyDef(code: 'SAR', name: 'Saudi Riyal'),
  CurrencyDef(code: 'SEK', name: 'Swedish Krona'),
  CurrencyDef(code: 'SGD', name: 'Singapore Dollar', symbol: r'$'),
  CurrencyDef(code: 'THB', name: 'Thai Baht', symbol: '฿'),
  CurrencyDef(code: 'TJS', name: 'Tajikistani Somoni'),
  CurrencyDef(code: 'TMT', name: 'Turkmen Manat', symbol: 'm'),
  CurrencyDef(code: 'TND', name: 'Tunisian Dinar', decimals: 3),
  CurrencyDef(code: 'TRY', name: 'Turkish Lira', symbol: '₺'),
  CurrencyDef(code: 'TWD', name: 'New Taiwan Dollar', symbol: r'NT$'),
  CurrencyDef(code: 'TZS', name: 'Tanzanian Shilling'),
  CurrencyDef(code: 'UAH', name: 'Ukrainian Hryvnia', symbol: '₴'),
  CurrencyDef(code: 'UGX', name: 'Ugandan Shilling', decimals: 0),
  CurrencyDef(code: 'USD', name: 'US Dollar', symbol: r'$'),
  CurrencyDef(code: 'UYU', name: 'Uruguayan Peso', symbol: r'$'),
  CurrencyDef(code: 'UZS', name: 'Uzbekistani Som'),
  CurrencyDef(code: 'VND', name: 'Vietnamese Dong', symbol: '₫', symbolBefore: false, decimals: 0),
  CurrencyDef(code: 'XAF', name: 'Central African CFA Franc', decimals: 0),
  CurrencyDef(code: 'XOF', name: 'West African CFA Franc', decimals: 0),
  CurrencyDef(code: 'ZAR', name: 'South African Rand', symbol: 'R'),
];

/// Fast lookup for the built-in catalog, keyed by code.
final Map<String, CurrencyDef> _builtInByCode = {
  for (final c in kBuiltInCurrencies) c.code: c,
};

/// User-defined currencies, registered at load and on every mutation. Kept as a
/// module global so the dependency-free [money]/[currencyDef] path can reach
/// them without a [BuildContext] or the store — the same shape [Fx] already
/// uses for its rate table.
Map<String, CurrencyDef> _customByCode = const {};

/// Replaces the registered custom-currency set. Called by the store whenever the
/// list loads or changes, so formatting everywhere reflects the latest metadata.
void setCustomCurrencies(Iterable<CurrencyDef> currencies) {
  _customByCode = {for (final c in currencies) c.code: c.copyWith(custom: true)};
}

/// The currency metadata for [code] — a registered custom currency wins over a
/// built-in of the same code, then the built-in catalog, then a synthesised
/// code-only default so an unknown code still renders (as `CODE 1,234`).
CurrencyDef currencyDef(String code) =>
    _customByCode[code] ??
    _builtInByCode[code] ??
    CurrencyDef(code: code, name: code, symbol: null);

/// The registered custom currency for [code], or null if none — the switch that
/// sends [money] down the metadata-driven formatting branch.
CurrencyDef? customCurrencyDef(String code) => _customByCode[code];

/// Whether [code] already names a currency (built-in or custom) — the
/// duplicate-code guard behind the Add-currency sheet (spec §7a).
bool currencyCodeExists(String code) {
  final c = code.trim().toUpperCase();
  return _builtInByCode.containsKey(c) || _customByCode.containsKey(c);
}
