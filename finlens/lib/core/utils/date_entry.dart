/// Pure, stateless logic for a typed `dd.mm.yyyy` date field (Task 25 §1).
///
/// Digits go in; the separators are derived, never stored. The order is the
/// same in every locale — three of the four languages are day-first anyway, and
/// one app cannot ask for `dd.mm.yyyy` in Turkmen and `mm/dd/yyyy` in English
/// (§1a). This type holds no `BuildContext` and touches no Flutter API so it can
/// be unit-tested over a bare keystroke sequence.
library;

/// The outcome of validating a would-be date (§1e). Only meaningful once eight
/// digits are in; before that the answer is always [incomplete] and nothing is
/// shown to the user.
enum DateEntryError {
  /// Fewer than eight digits — say nothing yet (§3: no error while typing).
  incomplete,

  /// Eight digits, but not a real calendar day (`31.02`, `00`, month 13…).
  notReal,

  /// A real date, but outside the caller's `firstDate`/`lastDate`.
  outOfRange,

  /// A real, in-range date.
  ok,
}

/// An immutable `dd.mm.yyyy` entry, addressed only through its normalised digit
/// [digits] buffer (0..8 chars: `[dd][mm][yyyy]`). Every mutator returns a new
/// value; [text] renders the buffer with separators.
class DateEntry {
  const DateEntry(this.digits);

  /// Normalised digit buffer, 0..8 chars. The field always shows this two-digit
  /// form, so the user sees what was understood immediately (§1b).
  final String digits;

  static const DateEntry empty = DateEntry('');

  /// Eight digits are in — the only point at which validation runs.
  bool get isComplete => digits.length == 8;

  bool get isEmpty => digits.isEmpty;

  /// A pre-filled entry from an existing date (§4: opening on an existing date).
  static DateEntry fromDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return DateEntry(
      '${two(d.day)}${two(d.month)}${d.year.toString().padLeft(4, '0')}',
    );
  }

  /// The formatted display, `dd.mm.yyyy`, with the separators inserted for the
  /// user. Follows the §1b table exactly at every intermediate length.
  String get text {
    final n = digits.length;
    final b = StringBuffer();
    b.write(digits.substring(0, n < 2 ? n : 2));
    if (n >= 2) b.write('.');
    if (n > 2) b.write(digits.substring(2, n < 4 ? n : 4));
    if (n >= 4) b.write('.');
    if (n > 4) b.write(digits.substring(4, n));
    return b.toString();
  }

  static bool _isDigit(String ch) =>
      ch.length == 1 && ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

  /// Append one typed digit, with the two unambiguous shortcuts (§1b):
  ///  * a first day digit of 4–9 cannot be a tens digit → it is the whole day
  ///    (`4` → `04.`);
  ///  * a first month digit of 2–9 cannot be a tens digit → the whole month
  ///    (`01.` `5` → `01.05.`).
  ///
  /// `0` and `1` (and `2`,`3` for the day) stay ambiguous and wait. A non-digit
  /// — a typed `.` or `/` — is swallowed, never doubled.
  DateEntry typeDigit(String ch) {
    if (!_isDigit(ch) || digits.length >= 8) return this;
    switch (digits.length) {
      case 0:
        // Day tens can be 0..3, so only 4..9 are unambiguous.
        return ch.compareTo('4') >= 0 ? DateEntry('0$ch') : DateEntry(ch);
      case 2:
        // Month tens can be 0 or 1, so only 2..9 are unambiguous.
        return ch.compareTo('2') >= 0
            ? DateEntry('${digits}0$ch')
            : DateEntry('$digits$ch');
      default:
        return DateEntry('$digits$ch');
    }
  }

  /// Remove the last digit; a derived separator disappears with it, so a dot the
  /// user never typed is never a second backspace to cross (§1c).
  DateEntry backspace() =>
      digits.isEmpty ? this : DateEntry(digits.substring(0, digits.length - 1));

  /// Replace the buffer with pasted content: everything that is not a digit is
  /// stripped, up to eight are kept, and the result is reformatted (§1f). No
  /// shortcut expansion — a pasted `1/4/2027` becomes `14.20.27…`, which the
  /// validator will refuse, and that is the intended, un-clever behaviour.
  static DateEntry paste(String raw) {
    final d = raw.replaceAll(RegExp('[^0-9]'), '');
    return DateEntry(d.length > 8 ? d.substring(0, 8) : d);
  }

  int get _day => int.parse(digits.substring(0, 2));
  int get _month => int.parse(digits.substring(2, 4));
  int get _year => int.parse(digits.substring(4, 8));

  /// Validate a complete entry, in order (§1e): a real calendar date first —
  /// `31.02.2027` is refused, leap years respected — then the caller's bounds.
  /// Each failure has its own answer so the two messages can differ.
  DateEntryError validate({
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    if (!isComplete) return DateEntryError.incomplete;
    final day = _day, month = _month, year = _year;
    if (month < 1 || month > 12 || day < 1) return DateEntryError.notReal;
    final dt = DateTime(year, month, day);
    // A rolled-over construction (Feb 31 → Mar 3, day 00 → prev month) proves
    // the typed day is not real.
    if (dt.year != year || dt.month != month || dt.day != day) {
      return DateEntryError.notReal;
    }
    final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
    if (dt.isBefore(first) || dt.isAfter(last)) {
      return DateEntryError.outOfRange;
    }
    return DateEntryError.ok;
  }

  /// The valid, in-range date, or null if the entry is incomplete, unreal, or
  /// out of range.
  DateTime? dateWithin(DateTime firstDate, DateTime lastDate) =>
      validate(firstDate: firstDate, lastDate: lastDate) == DateEntryError.ok
      ? DateTime(_year, _month, _day)
      : null;

  @override
  bool operator ==(Object other) =>
      other is DateEntry && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;

  @override
  String toString() => 'DateEntry($digits)';
}
