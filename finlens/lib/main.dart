import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/data/dev_seed_data.dart';
import 'core/data/seed_data.dart';
import 'core/store/app_store.dart';
import 'features/shell/app_shell.dart';
import 'theme/app_theme.dart';

/// Debug-only switch for the development data seeder. It is never on by
/// default: run `flutter run --dart-define=DEV_SEED=true` to load the varied
/// fixture. `kDebugMode` is a compile-time `false` in release builds, so the
/// whole branch — and [buildDevSeedStore] — is tree-shaken out of a release
/// binary and can never be invoked there. Launching without the flag rebuilds
/// the untouched [buildSeedStore], which is the seeder's "reset".
const bool _useDevSeed =
    kDebugMode && bool.fromEnvironment('DEV_SEED', defaultValue: false);

Future<void> main() async {
  // Needed before touching SharedPreferences (the filter store) and before
  // runApp, so the persisted Balance filter is restored *before the first
  // frame* — the screen must never paint unfiltered values and then re-render.
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final store = _useDevSeed ? buildDevSeedStore() : buildSeedStore();
  await store.loadBalanceFilter();
  await store.loadBalanceOrder();
  await store.loadSameListRange();
  await store.loadPeriodUnits();
  await store.loadTransPrefs();
  runApp(FinLensApp(store: store));
}

class FinLensApp extends StatelessWidget {
  const FinLensApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'FinLens',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AppShell(),
      ),
    );
  }
}
