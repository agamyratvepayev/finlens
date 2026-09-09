import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/persistence/local_database.dart';
import 'package:finlens/core/persistence/sync_store.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/sync/api_client.dart';
import 'package:finlens/core/sync/sync_controller.dart';
import 'package:finlens/features/sync/conflict_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// The conflict-review screen survives the 320 pt floor with its two-across
/// button rows, renders a card per queued conflict (txn summary + editor
/// line), and shows the empty state once the queue drains.
///
/// flutter test hangs on the author's machine — run these yourself:
///   flutter test test/sync_conflict_screen_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late SyncStore syncStore;
  late SyncController controller;

  setUp(() async {
    db = await LocalDatabase.openInMemory();
    syncStore = SyncStore(db);
    controller = SyncController(syncStore, SyncApiClient());
  });

  tearDown(() => db.close());

  Widget harness() => SyncScope(
        controller: controller,
        child: StoreScope(
          store: AppStore.empty(),
          child: MaterialApp(
            theme: AppTheme.dark,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ConflictScreen(),
          ),
        ),
      );

  Future<void> seedConflicts() async {
    await syncStore.putConflict(ConflictRow(
      entityType: 'txn',
      recordId: 't_1',
      localPayload: const {
        'id': 't_1',
        'amount': 25.5,
        'currency': 'TMT',
        'date': 1780000000000,
        'note': 'bazar',
      },
      localDeleted: false,
      remotePayload: const {
        'id': 't_1',
        'amount': 30.0,
        'currency': 'TMT',
        'date': 1780000000000,
        'note': 'bazar',
      },
      remoteDeleted: false,
      remoteVersion: 3,
      remoteUpdatedBy: 'wife@test.tm',
      remoteUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1780000100000),
    ));
    await syncStore.putConflict(const ConflictRow(
      entityType: 'tag',
      recordId: 'tg_a',
      localPayload: {'id': 'tg_a', 'name': 'food'},
      localDeleted: false,
      remotePayload: null,
      remoteDeleted: true,
      remoteVersion: 2,
      remoteUpdatedBy: 'wife@test.tm',
    ));
  }

  testWidgets('renders one card per conflict at 320×568 without overflow',
      (tester) async {
    await seedConflicts();
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Two cards → two per-card button pairs, plus the bulk pair on top.
    final l = AppLocalizations.of(tester.element(find.byType(ConflictScreen)));
    expect(find.text(l.syncConflictKeepMine), findsNWidgets(2));
    expect(find.text(l.syncConflictKeepTheirs), findsNWidgets(2));
    expect(find.text(l.syncConflictKeepAllMine), findsOneWidget);
    expect(find.text(l.syncConflictKeepAllTheirs), findsOneWidget);

    // The txn card summarises amount+date+note; the deleted tag names its
    // deleter. (No overflow: an overflowing row would have failed the pump.)
    expect(find.textContaining('bazar'), findsOneWidget);
    expect(find.textContaining('wife@test.tm'), findsNWidgets(2));
  });

  testWidgets('empty queue shows the empty line and no buttons',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final l = AppLocalizations.of(tester.element(find.byType(ConflictScreen)));
    expect(find.text(l.syncConflictEmpty), findsOneWidget);
    expect(find.text(l.syncConflictKeepMine), findsNothing);
  });
}
