import 'package:flutter/services.dart';

/// Refuses any keystroke that would take an integer-percent field outside
/// 1–100, or introduce anything but digits — rather than accepting `120` and
/// silently rewriting it to `100` (task 22, spec §1b). The rejected digit
/// simply never appears; [onReject] fires so the caller can add a haptic.
///
/// The 1–100 bound is not a taste: the warn threshold only fires while a budget
/// is *not* yet over, so a value above 100% could never fire and 0% would fire
/// the instant a budget exists.
class PercentInputFormatter extends TextInputFormatter {
  const PercentInputFormatter([this.onReject]);

  /// Called whenever a keystroke is refused (e.g. to fire a light haptic).
  final void Function()? onReject;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue; // clearing the field is allowed
    // Digits only: no decimal point, sign, or spaces. `100` is the longest
    // in-range value, so anything past three digits is out of range too.
    if (text.length > 3 || !RegExp(r'^[0-9]+$').hasMatch(text)) {
      onReject?.call();
      return oldValue;
    }
    final value = int.parse(text);
    if (value < 1 || value > 100) {
      onReject?.call();
      return oldValue;
    }
    return newValue;
  }
}
