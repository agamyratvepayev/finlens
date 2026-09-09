import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/utils/uuid.dart';

/// Group-sync ids: record ids must be collision-free across devices, so
/// [uuidV4] replaces the old monotonic counter inside `AppStore._nextId`.
///
/// flutter test hangs on the author's machine — run these yourself:
///   flutter test test/sync_uuid_test.dart
void main() {
  final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  test('uuidV4 emits well-formed version-4 UUIDs', () {
    for (var i = 0; i < 100; i++) {
      expect(uuidV4(), matches(v4));
    }
  });

  test('uuidV4 does not repeat across 10k draws', () {
    final seen = <String>{};
    for (var i = 0; i < 10000; i++) {
      expect(seen.add(uuidV4()), isTrue);
    }
  });
}
