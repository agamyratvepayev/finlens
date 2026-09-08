import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/data/dev_seed_data.dart';
import 'core/persistence/local_database.dart';
import 'core/persistence/store_persister.dart';
import 'core/persistence/sync_store.dart';
import 'core/store/app_store.dart';
import 'core/sync/api_client.dart';
import 'core/sync/sync_config.dart';
import 'core/sync/sync_controller.dart';
import 'core/sync/sync_engine.dart';
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

  // Group sync rides on real persistence only — the dev-seed fixture has no
  // persister and must never push its data into a group.
  SyncController? syncController;
  if (kSyncEnabled && persister != null) {
    final syncStore = SyncStore(db);
    final api = SyncApiClient();
    syncController = SyncController(syncStore, api);
    await syncController.hydrate();
    syncController.engine =
        SyncEngine(store, syncStore, api, syncController)..attach();
    // Launch pull-and-push (fire and forget — offline is a status, not an
    // error) plus a membership refresh so invites surface without opening More.
    if (syncController.isSignedIn) {
      unawaited(syncController.refresh());
      if (syncController.isInGroup) {
        unawaited(syncController.engine!.syncNow());
      }
    }
  }

  runApp(FinLensApp(
    store: store,
    persister: persister,
    syncController: syncController,
  ));
}

class FinLensApp extends StatefulWidget {
  const FinLensApp({
    super.key,
    required this.store,
    this.persister,
    this.syncController,
  });

  final AppStore store;

  /// Null in the debug dev-seed mode (that fixture is not persisted); otherwise
  /// the live persister, flushed on app suspend so the last edit is never lost.
  final StorePersister? persister;

  /// Null when the sync feature is compiled out ([kSyncEnabled] false) or in
  /// dev-seed mode; otherwise the auth/group state distributed via [SyncScope].
  final SyncController? syncController;

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
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Flush any pending debounced snapshot before the OS can suspend or kill the
    // process, so a change made moments earlier survives. The framework does not
    // await this callback, but awaiting flush here drives the write to completion
    // during `paused`/`hidden` — the window before the process is suspended.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      await widget.persister?.flush();
    }
    // Coming back to the foreground: pick up other members' changes (and push
    // anything made while a sync was impossible).
    if (state == AppLifecycleState.resumed) {
      final sync = widget.syncController;
      if (sync != null && sync.isSignedIn && sync.isInGroup) {
        unawaited(sync.engine?.syncNow());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncController = widget.syncController;
    Widget app = StoreScope(
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
    if (syncController != null) {
      app = SyncScope(controller: syncController, child: app);
    }
    return app;
  }
}
