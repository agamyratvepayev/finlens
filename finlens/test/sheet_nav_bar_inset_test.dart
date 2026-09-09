import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/sheet_nav_bar_inset_test.dart
//
// Task 7: the sheet shell must reserve the system navigation bar
// (MediaQuery.padding.bottom) on both presentation paths, so the last row of a
// picker never sits under the bar. The keyboard (viewInsets.bottom) is handled
// separately and the two must never be added in full — on Android
// padding.bottom collapses to 0 while the keyboard is up.

const _w = 390.0;
const _h = 844.0;
const _navBar = 48.0;
const _keyboard = 300.0;

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 2580,
    );

AppStore _oneAccountStore() => AppStore(
      accounts: [_acc('a1', 'My Wallet')],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(
  AppStore store,
  void Function(BuildContext) onTap, {
  double navBarInset = 0,
  double keyboardInset = 0,
}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        // A `builder` override reaches modal routes (the sheet), which a
        // MediaQuery below the Navigator would not.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(bottom: navBarInset),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onTap(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

void _setSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(_w, _h);
  addTearDown(tester.view.reset);
}

/// The sheet's opaque rounded surface — the bottom-most painted extent of the
/// sheet itself, as opposed to the transparent modal barrier around it.
Finder _sheetSurface() => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius ==
              const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    );

Future<void> _openAccountPicker(
  WidgetTester tester, {
  double navBarInset = 0,
  double keyboardInset = 0,
}) async {
  await tester.pumpWidget(_host(
    _oneAccountStore(),
    (ctx) => pickAccount(ctx),
    navBarInset: navBarInset,
    keyboardInset: keyboardInset,
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'content-sized: last account row clears a 48pt navigation bar inset',
      (tester) async {
    _setSize(tester);
    await _openAccountPicker(tester, navBarInset: _navBar);

    // The row must end at least the bar's height above the window bottom —
    // its own list padding (Insets.xxl) then sits between it and the bar.
    final row = tester.getRect(find.text('My Wallet'));
    expect(
      row.bottom,
      lessThanOrEqualTo(_h - _navBar),
      reason: 'the last row must not extend under the navigation bar',
    );
  });

  testWidgets('content-sized: padding.bottom == 0 keeps today\'s geometry',
      (tester) async {
    _setSize(tester);
    await _openAccountPicker(tester);

    // With no nav bar the sheet surface still reaches the window bottom and
    // the last row keeps exactly its list padding (Insets.xxl) of clearance —
    // the pre-fix baseline, byte for byte.
    expect(tester.getRect(_sheetSurface()).bottom, _h);
    final row = tester.getRect(find.text('My Wallet'));
    expect(row.bottom, lessThanOrEqualTo(_h - Insets.xxl));
    expect(row.bottom, greaterThan(_h - Insets.xxl - 60));
  });

  testWidgets('content-sized: keyboard inset alone gains no extra foot gap',
      (tester) async {
    _setSize(tester);
    await _openAccountPicker(tester, keyboardInset: _keyboard);

    // viewInsets handling is untouched: the surface sits exactly on top of
    // the keyboard, not a pixel higher.
    expect(tester.getRect(_sheetSurface()).bottom, _h - _keyboard);
  });

  testWidgets('content-sized: keyboard and nav insets are never both added',
      (tester) async {
    _setSize(tester);
    await _openAccountPicker(
      tester,
      navBarInset: _navBar,
      keyboardInset: _keyboard,
    );

    // The keyboard covers the bar, so only the keyboard is reserved — adding
    // both would float the sheet 48pt above the keys.
    expect(tester.getRect(_sheetSurface()).bottom, _h - _keyboard);
  });

  testWidgets('draggable path reserves the navigation bar inset',
      (tester) async {
    _setSize(tester);
    await tester.pumpWidget(_host(
      _oneAccountStore(),
      (ctx) => showAppSheet<void>(
        ctx,
        title: 'Sheet',
        builder: (context, controller) => ListView(
          controller: controller,
          children: const [SizedBox(height: 200)],
        ),
      ),
      navBarInset: _navBar,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.getRect(_sheetSurface()).bottom, _h - _navBar);
  });

  testWidgets('draggable path: padding.bottom == 0 keeps today\'s geometry',
      (tester) async {
    _setSize(tester);
    await tester.pumpWidget(_host(
      _oneAccountStore(),
      (ctx) => showAppSheet<void>(
        ctx,
        title: 'Sheet',
        builder: (context, controller) => ListView(
          controller: controller,
          children: const [SizedBox(height: 200)],
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.getRect(_sheetSurface()).bottom, _h);
  });
}
