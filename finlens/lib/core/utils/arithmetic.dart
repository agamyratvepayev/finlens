/// Arithmetic for the numeric keypad — the `+ − × ÷ =` model.
///
/// A field's contents are an [Expression]: a run of operands with operators
/// between them, plus the operand currently being typed. It is kept as tokens,
/// not a string, so that backspace, operator replacement and evaluation all act
/// on one model rather than re-parsing a string on every keystroke (spec §3).
///
/// **The plain-number path is byte-identical to before.** With no operator
/// pressed, an [Expression] is a single [pending] operand and behaves exactly as
/// the old raw string did — the digit/decimal append rule is the shared
/// [appendDigit] that `AmountEntry.press` now delegates to.
///
/// Arithmetic is exact: operands parse to [_Frac] rationals over [BigInt], the
/// `× ÷` pass then the `+ −` pass run without rounding, and **only the final
/// value is rounded**, to the field's precision. So `0.1 + 0.2` is `0.3`, not
/// `0.30000000000000004`, and a repeating decimal is rounded once at the end
/// (spec §3.2). No `double` intermediate, and no `decimal` package — the app
/// stays dependency-free, per the owner's decision.
library;

/// The four operators, holding the glyph shown to the user and carried in the
/// expression. These are the real characters (`−` is U+2212 MINUS SIGN, not the
/// ASCII hyphen; `×` is U+00D7; `÷` is U+00F7) — the parser reads them directly
/// (spec §2.2). The spoken accessibility label is chosen at the widget layer
/// from [name], keeping this model free of l10n.
enum Op {
  add('+'), // +
  subtract('−'), // − (true minus)
  multiply('×'), // ×
  divide('÷'); // ÷

  const Op(this.glyph);

  /// The character shown to the user and held in the expression.
  final String glyph;
}

/// Appends one keypad character to a single operand's raw text, the way the
/// amount field always has (the algorithm lifted verbatim from the old
/// `AmountEntry.press`, now parameterised by precision).
///
/// [maxDecimals] caps the fraction digits (2 for money by default, more for a
/// rate); [maxWhole] caps the integer digits. A `.` past [maxDecimals], or when
/// one is already present, or when [maxDecimals] is 0, is ignored. A leading `0`
/// is replaced by the first significant digit. With `maxDecimals: 2` and
/// `maxWhole: 12` this returns exactly what `AmountEntry.press` returned before,
/// so every existing amount field is unchanged.
String appendDigit(
  String raw,
  String key, {
  required int maxDecimals,
  int maxWhole = 12,
}) {
  if (key == '.') {
    if (maxDecimals <= 0) return raw;
    if (raw.contains('.')) return raw;
    return raw.isEmpty ? '0.' : '$raw.';
  }
  final dot = raw.indexOf('.');
  if (dot >= 0) {
    if (raw.length - dot - 1 >= maxDecimals) return raw;
    return '$raw$key';
  }
  if (raw.length >= maxWhole) return raw;
  if (raw == '0') return key;
  return '$raw$key';
}

/// Removes one character from a single operand's raw text.
String backspaceDigit(String raw) =>
    raw.isEmpty ? raw : raw.substring(0, raw.length - 1);

/// An expression as tokens (spec §3).
///
/// [operands] are the *completed* operands and [operators] the operators after
/// each of them, so `operators.length == operands.length` always; [pending] is
/// the trailing operand still being typed. The whole expression is therefore
/// `operands[0] operators[0] operands[1] … operators[n-1] pending`, with
/// `operands.length + 1` numbers in it (the last being [pending]) — matching the
/// spec's "operands is always operators.length + 1" once [pending] is counted.
///
/// Operand strings are unsigned magnitudes while typed (the keypad has no minus
/// key). The one exception is a resolved **negative result**, which is carried
/// in [resolvedValue] and, if the user continues with an operator, committed as
/// a signed operand string (ASCII `-`, never shown; the display uses U+2212).
class Expression {
  const Expression({
    this.operands = const [],
    this.operators = const [],
    this.pending = '',
    this.afterEquals = false,
    this.resolvedValue,
  });

  /// A fresh, empty field.
  static const empty = Expression();

  final List<String> operands;
  final List<Op> operators;

  /// The operand currently being typed, as literal characters (`1`, `1.`,
  /// `1.0`), so an incomplete decimal survives until it is complete.
  final String pending;

  /// True immediately after `=`: a digit now starts a new number (replacing the
  /// result), while an operator continues from the result (spec §3.1).
  final bool afterEquals;

  /// The signed value the last `=` produced, or null. Only set while
  /// [afterEquals] is true; lets a negative result (`100 − 150 → −50`) be shown
  /// and carried forward even though operand strings are unsigned.
  final double? resolvedValue;

  /// A single plain number with nothing resolved and no operator — the common
  /// case, where the field behaves exactly as before.
  static Expression ofRaw(String raw) => Expression(pending: raw);

  bool get isEmpty =>
      operands.isEmpty && operators.isEmpty && pending.isEmpty && !afterEquals;

  bool get hasOperator => operators.isNotEmpty;

  /// Whether the field should render through the expression display rather than
  /// the single-number path: either an operator is pending, or the result of a
  /// `=` is negative (a magnitude string cannot carry its minus, so the signed
  /// display path draws it — spec §6).
  bool get showsAsExpression => hasOperator || (afterEquals && pendingIsNegative);

  /// Ends on an operator (`569 +`) — nothing to resolve yet.
  bool get _endsOnOperator => pending.isEmpty && operators.isNotEmpty;

  /// Every number in the expression, in order, including [pending] when it is
  /// non-empty. Used only for evaluation and semantics.
  List<String> get _numbers =>
      [...operands, if (pending.isNotEmpty) pending];

  // ── Key handling (spec §3.1) ───────────────────────────────────────────────

  /// A digit or `.`. After `=` a digit starts a new number, replacing the
  /// result; otherwise it appends to [pending].
  Expression pressDigit(String key, {required int maxDecimals, int maxWhole = 12}) {
    if (afterEquals) {
      return Expression(pending: appendDigit('', key, maxDecimals: maxDecimals, maxWhole: maxWhole));
    }
    return Expression(
      operands: operands,
      operators: operators,
      pending: appendDigit(pending, key, maxDecimals: maxDecimals, maxWhole: maxWhole),
    );
  }

  /// An operator. Closes [pending] into an operand and appends the operator;
  /// with [pending] empty it either replaces the last operator or, on an empty
  /// field, is ignored. After `=` it continues from the (possibly signed)
  /// result.
  Expression pressOperator(Op op) {
    if (afterEquals) {
      // Continue from the result: commit it as the first operand, signed.
      final signed = _plainSigned(resolvedValue ?? 0);
      return Expression(operands: [signed], operators: [op]);
    }
    if (pending.isEmpty) {
      if (operators.isEmpty) return this; // operator on an empty field → ignored
      // Replace the trailing operator — never a second one.
      final next = [...operators];
      next[next.length - 1] = op;
      return Expression(operands: operands, operators: next);
    }
    return Expression(
      operands: [...operands, pending],
      operators: [...operators, op],
    );
  }

  /// Backspace. Removes one character of [pending]; if [pending] is empty,
  /// removes the last operator and reopens the operand before it for editing.
  Expression backspace() {
    if (afterEquals) {
      // The result becomes an ordinary number under edit.
      return Expression(pending: backspaceDigit(pending));
    }
    if (pending.isNotEmpty) {
      return Expression(
        operands: operands,
        operators: operators,
        pending: backspaceDigit(pending),
      );
    }
    if (operators.isNotEmpty) {
      final ops = [...operators]..removeLast();
      final nums = [...operands];
      final reopened = nums.removeLast();
      return Expression(operands: nums, operators: ops, pending: reopened);
    }
    return this; // already empty
  }

  /// `=`. Evaluates to [precision] decimals and replaces the whole expression
  /// with the result. A no-op when the expression cannot resolve.
  Expression evaluated(int precision) {
    final v = evaluate(precision);
    if (v == null) return this;
    return Expression(
      pending: rawFromValue(v, precision),
      afterEquals: true,
      resolvedValue: v,
    );
  }

  // ── Evaluation (spec §3.2) ─────────────────────────────────────────────────

  /// The value to [precision] decimals, or null when the expression cannot
  /// resolve — it ends on an operator, or it divides by zero (spec §4).
  /// `× ÷` bind before `+ −`; nothing is rounded until the end.
  double? evaluate(int precision) {
    if (_endsOnOperator) return null;
    final nums = _numbers;
    if (nums.isEmpty) return null;
    if (operators.length != nums.length - 1) return null;

    // First pass: fold × and ÷, left to right, over the operand list.
    final values = <_Frac>[_Frac.parse(nums[0])];
    final adds = <Op>[]; // the + / − operators left for the second pass
    for (var i = 0; i < operators.length; i++) {
      final op = operators[i];
      final rhs = _Frac.parse(nums[i + 1]);
      if (op == Op.multiply) {
        values[values.length - 1] = values.last * rhs;
      } else if (op == Op.divide) {
        if (rhs.isZero) return null; // division by zero → unresolvable
        values[values.length - 1] = values.last / rhs;
      } else {
        adds.add(op);
        values.add(rhs);
      }
    }

    // Second pass: fold + and −, left to right.
    var acc = values[0];
    for (var i = 0; i < adds.length; i++) {
      acc = adds[i] == Op.add ? acc + values[i + 1] : acc - values[i + 1];
    }
    return acc.roundToDouble(precision);
  }

  /// True when `=` may be pressed: there is an operator and it resolves. This is
  /// the `=` key's enabled state and its only error report (spec §4).
  bool canResolve(int precision) => hasOperator && evaluate(precision) != null;

  /// The number this field commits, resolving a pending expression silently
  /// (spec §5). For a plain single operand this is exactly the old
  /// `AmountEntry.value` — `double.tryParse`, 0 on empty. For a resolved result
  /// it is that result; for an unresolved multi-operand expression it is the
  /// evaluation (null when incomplete, which keeps Save disabled).
  double? value(int precision) {
    if (afterEquals && resolvedValue != null && operators.isEmpty) {
      return resolvedValue;
    }
    if (hasOperator) return evaluate(precision);
    return pending.isEmpty ? 0 : (double.tryParse(pending) ?? 0);
  }

  /// The raw magnitude text of [pending] (unsigned), for the display path that
  /// renders one operand through the currency formatter.
  String get pendingMagnitude =>
      pending.startsWith('-') ? pending.substring(1) : pending;

  /// True when [pending] is a resolved negative result to be shown with a `−`.
  bool get pendingIsNegative =>
      pending.startsWith('-') || (afterEquals && (resolvedValue ?? 0) < 0);

  /// A signed decimal string using ASCII `-` (never shown; the display maps it
  /// to U+2212). Whole values drop the point; fractional values keep only the
  /// digits present.
  static String _plainSigned(double v) {
    final neg = v < 0;
    final mag = rawFromValue(v, 10);
    return neg ? '-$mag' : mag;
  }
}

/// Groups a run of integer digits with `,` every three places — the same
/// grouping the amount field always applied to a plain number (spec §7), lifted
/// so the expression display groups each operand identically.
String groupThousands(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// One operand as display text: whole part grouped, decimals kept as typed, a
/// resolved negative shown with a true minus (U+2212).
String _displayNumber(String raw) {
  var s = raw;
  var sign = '';
  if (s.startsWith('-')) {
    sign = '−';
    s = s.substring(1);
  }
  final dot = s.indexOf('.');
  if (dot < 0) return '$sign${groupThousands(s.isEmpty ? '0' : s)}';
  final whole = s.substring(0, dot);
  final frac = s.substring(dot + 1);
  return '$sign${groupThousands(whole.isEmpty ? '0' : whole)}.$frac';
}

/// The whole expression as plain display text, **no currency token**: each
/// operand grouped like a plain number, operators surrounded by one space each
/// (`1,234 + 30`), the pending operator shown when the expression ends on one
/// (`569 +`). The currency chip beside the field names the unit; a symbol per
/// operand would be noise (spec §7). Empty when the expression is empty.
String expressionDisplay(Expression e) {
  // A resolved negative is a single magnitude with its sign held apart; draw the
  // minus the magnitude string cannot carry.
  if (e.operands.isEmpty && e.operators.isEmpty && e.pendingIsNegative) {
    return '−${_displayNumber(e.pendingMagnitude)}';
  }
  final b = StringBuffer();
  for (var i = 0; i < e.operands.length; i++) {
    b.write(_displayNumber(e.operands[i]));
    b.write(' ${e.operators[i].glyph} ');
  }
  if (e.pending.isNotEmpty) {
    b.write(_displayNumber(e.pending));
  }
  return b.toString().trimRight();
}

/// A resolved value as an unsigned raw operand string at [precision] decimals:
/// whole values drop the point (`15`), fractional values keep their significant
/// digits with trailing zeros trimmed (`12.5`, not `12.50`).
String rawFromValue(double v, int precision) {
  final a = v.abs();
  if (a % 1 == 0) return a.toStringAsFixed(0);
  var s = a.toStringAsFixed(precision);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// An exact rational over [BigInt] — the arithmetic type for intermediate
/// results, so nothing is rounded until [roundToDouble]. Not reduced (it never
/// needs to be for the small expressions a keypad produces); the denominator is
/// kept positive and the sign rides on the numerator.
class _Frac {
  _Frac(this.num, this.den) {
    assert(den != BigInt.zero);
  }

  final BigInt num;
  final BigInt den;

  bool get isZero => num == BigInt.zero;

  /// Parses a decimal operand string (`12`, `12.`, `12.34`, `-50`) exactly.
  factory _Frac.parse(String raw) {
    var s = raw;
    var neg = false;
    if (s.startsWith('-')) {
      neg = true;
      s = s.substring(1);
    }
    final dot = s.indexOf('.');
    if (dot < 0) {
      final n = BigInt.parse(s.isEmpty ? '0' : s);
      return _Frac(neg ? -n : n, BigInt.one);
    }
    final whole = s.substring(0, dot);
    final frac = s.substring(dot + 1);
    final digits = '${whole.isEmpty ? '0' : whole}$frac';
    final n = BigInt.parse(digits.isEmpty ? '0' : digits);
    final d = BigInt.from(10).pow(frac.length);
    return _Frac(neg ? -n : n, d);
  }

  _Frac operator +(_Frac o) => _Frac(num * o.den + o.num * den, den * o.den);
  _Frac operator -(_Frac o) => _Frac(num * o.den - o.num * den, den * o.den);
  _Frac operator *(_Frac o) => _Frac(num * o.num, den * o.den);
  _Frac operator /(_Frac o) {
    // Keep the denominator positive so the sign stays on the numerator.
    final n = num * o.den;
    final d = den * o.num;
    return d.isNegative ? _Frac(-n, -d) : _Frac(n, d);
  }

  /// Rounds to [precision] decimal places, half away from zero — the same rule
  /// `roundToCurrency` uses (`(x·10ⁿ).round()/10ⁿ`), so the keypad and the money
  /// formatter round a value the same way.
  double roundToDouble(int precision) {
    final scale = BigInt.from(10).pow(precision < 0 ? 0 : precision);
    final scaledNum = num * scale; // value · 10^precision, still over `den`
    final neg = scaledNum.isNegative;
    final a = scaledNum.abs();
    // Round half away from zero: (a + den/2) ~/ den, with a tie going up.
    final twice = a * BigInt.two;
    var q = a ~/ den;
    final rem2 = twice - q * den * BigInt.two;
    if (rem2 >= den) q += BigInt.one; // remainder ≥ 0.5 → round up
    final signed = neg ? -q : q;
    return signed.toDouble() / scale.toDouble();
  }
}
