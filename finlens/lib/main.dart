import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/data/dev_seed_data.dart';
import 'core/data/seed_data.dart';
import 'core/store/app_store.dart';
import 'features/shell/app_shell.dart';
import 'l10n/app_localizations.dart';
import 'l10n/fallback_localizations.dart';
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
  await store.loadInsightAccountFilter();
  await store.loadBalanceOrder();
  await store.loadSameListRange();
  await store.loadCompletedRange();
  await store.loadPeriodUnits();
  await store.loadTransPrefs();
  await store.loadLedgerPrefs();
  await store.loadLocale();
  runApp(FinLensApp(store: store));
}

class FinLensApp extends StatelessWidget {
  const FinLensApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      // FinLensApp's own context sits above StoreScope, so the MaterialApp is
      // built one level down via Builder — that inner context can subscribe to
      // the store and rebuild MaterialApp (and thus the whole app's locale)
      // whenever the language preference changes.
      child: Builder(
        builder: (context) {
          final locale = StoreScope.of(context).locale;
          return MaterialApp(
            title: 'FinLens',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            locale: locale, // null ⇒ follow the device locale (see callback)
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              // Turkmen shims must precede the Global* delegates so they win the
              // MaterialLocalizations / CupertinoLocalizations slot for `tk`.
              TkMaterialLocalizationsDelegate(),
              TkCupertinoLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            // When following the device locale, fall back to Turkmen (the target
            // market) rather than the first supported locale, if the device
            // language isn't one we support.
            localeListResolutionCallback: (deviceLocales, supported) {
              for (final device in deviceLocales ?? const <Locale>[]) {
                for (final s in supported) {
                  if (s.languageCode == device.languageCode) return s;
                }
              }
              return const Locale('tk');
            },
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
