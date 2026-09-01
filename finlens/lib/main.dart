import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/data/dev_seed_data.dart';
import 'core/persistence/local_database.dart';
import 'core/persistence/store_persister.dart';
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

  // Local persistence: hydrate the store from the on-device database, or start
  // blank on a fresh install. The debug dev-seed fixture is ephemeral and is
  // never persisted (it mirrors the app's old reset-every-launch behaviour), so
  // it does not attach a persister and cannot overwrite real data.
  final db = await LocalDatabase.open();
  final AppStore store;
  StorePersister? persister;
  if (_useDevSeed) {
    store = buildDevSeedStore();
  } else {
    store = await StorePersister.hydrate(db) ?? AppStore.empty();
    persister = StorePersister(store, db)..attach();
  }

  await store.loadBalanceFilter();
  await store.loadInsightAccountFilter();
  await store.loadInsightCategoryFilter();
  await store.loadBalanceOrder();
  await store.loadSameListRange();
  await store.loadCompletedRange();
  await store.loadPeriodUnits();
  await store.loadTransPrefs();
  await store.loadLedgerPrefs();
  await store.loadLocale();
  runApp(FinLensApp(store: store, persister: persister));
}

class FinLensApp extends StatefulWidget {
  const FinLensApp({super.key, required this.store, this.persister});

  final AppStore store;

  /// Null in the debug dev-seed mode (that fixture is not persisted); otherwise
  /// the live persister, flushed on app suspend so the last edit is never lost.
  final StorePersister? persister;

  @override
  State<FinLensApp> createState() => _FinLensAppState();
}

class _FinLensAppState extends State<FinLensApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flush any pending debounced snapshot before the OS can suspend or kill the
    // process, so a change made moments earlier survives.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.persister?.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
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
            locale: locale, // §7.1 — always a real language, never null
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
            // `locale` is always set now (§7.1), so this resolves `[locale]`
            // against the supported set. The fallback is English: the language
            // is seeded from the device once at first launch (see
            // AppStore.resolveInitialLocale) and is a stored value thereafter,
            // so there is no longer a live device-follow path to default to
            // Turkmen for. A Turkmen phone still opens in Turkmen — its locale
            // seeds the stored value; an unrecognised locale opens in English.
            localeListResolutionCallback: (deviceLocales, supported) {
              for (final device in deviceLocales ?? const <Locale>[]) {
                for (final s in supported) {
                  if (s.languageCode == device.languageCode) return s;
                }
              }
              return const Locale('en');
            },
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
