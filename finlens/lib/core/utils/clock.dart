/// The single source of "now" for the entire app.
///
/// Production reads the real clock; tests pin it. There is no third mode, and
/// there is no wall-clock read anywhere outside [_SystemClock] — a second
/// reading is exactly how Schedule drifted out of sync with Balance while both
/// believed they agreed.
abstract class Clock {
  DateTime now();

  static const Clock system = _SystemClock();
  static Clock fixed(DateTime at) => _FixedClock(at);
}

class _SystemClock implements Clock {
  const _SystemClock();

  /// The only wall-clock read in `lib/`.
  @override
  DateTime now() => DateTime.now();
}

class _FixedClock implements Clock {
  const _FixedClock(this._at);
  final DateTime _at;

  @override
  DateTime now() => _at;
}
