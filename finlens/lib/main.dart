import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/data/seed_data.dart';
import 'core/store/app_store.dart';
import 'features/shell/app_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Needed before touching SharedPreferences (the filter store) and before
  // runApp, so the persisted Balance filter is restored *before the first
  // frame* — the screen must never paint unfiltered values and then re-render.
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final store = buildSeedStore();
  await store.loadBalanceFilter();
  await store.loadBalanceOrder();
  await store.loadSameListRange();
  await store.loadPeriodUnits();
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
