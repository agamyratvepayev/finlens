import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart'
    show NumericKeypad;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task052_new_account_footer_keyboard_test.dart
//
// Task 052: New account's Create & select footer sits directly on top of the
// system keyboard from the first frame. The sheet itself does not move, the
// no-keyboard and keypad geometries are unchanged, and nothing overflows.

const _w = 390.0;
const _h = 844.0;
const _keyboard = 300.0;

AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: [
        Account(
          id: 'a1',
          name: 'Main Checking',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 1000,
        ),
      ],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, {double textScale = 1.0}) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // A `builder` override reaches the modal route; the view's viewInsets
        // and padding still flow through MediaQuery.of(context).
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showNewAccountSheet(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

void _setSize(WidgetTester tester, {double w = _w, double h = _h}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
}

void _keyboardUp(WidgetTester tester, double inset) {
  tester.view.viewInsets = FakeViewPadding(bottom: inset);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _open(WidgetTester tester, {double textScale = 1.0}) async {
  await tester.pumpWidget(_host(_store(), textScale: textScale));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _create() => find.widgetWithText(FilledButton, 'Create & select');
Finder _title() => find.text('New account');

void main() {
  testWidgets('no keyboard: the footer keeps today\'s geometry',
      (tester) async {
    _setSize(tester);
    await _open(tester);
    expect(tester.getRect(_create()).bottom, closeTo(_h - Insets.md, 0.5));
  });

  testWidgets('keyboard up on first open: Create & select sits on top of it',
      (tester) async {
    _setSize(tester);
    _keyboardUp(tester, _keyboard);
    await _open(tester);

    final button = tester.getRect(_create());
    expect(button.bottom, closeTo(_h - _keyboard - Insets.md, 0.5));
    expect(button.top, greaterThan(tester.getRect(_title()).bottom));
    // Empty form: visible, but in its disabled look.
    expect(tester.widget<FilledButton>(_create()).onPressed, isNull);
  });

  testWidgets('the sheet does not move when the keyboard opens',
      (tester) async {
    _setSize(tester);
    await _open(tester);
    final titleTop = tester.getRect(_title()).top;

    _keyboardUp(tester, _keyboard);
    await tester.pumpAndSettle();

    expect(tester.getRect(_title()).top, closeTo(titleTop, 0.5));
    expect(tester.getRect(_create()).bottom,
        closeTo(_h - _keyboard - Insets.md, 0.5));
  });

  testWidgets('nav bar + keyboard: lift is the full keyboard; nav bar alone '
      'is unchanged', (tester) async {
    _setSize(tester);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPadding);
    await _open(tester);
    expect(tester.getRect(_create()).bottom, closeTo(_h - 48 - Insets.md, 0.5));

    _keyboardUp(tester, _keyboard);
    await tester.pumpAndSettle();
    expect(tester.getRect(_create()).bottom,
        closeTo(_h - _keyboard - Insets.md, 0.5));
  });

  testWidgets('keypad open: the footer sits on the keypad, keyboard lift is 0',
      (tester) async {
    _setSize(tester);
    _keyboardUp(tester, _keyboard);
    await _open(tester);

    await tester.tap(find.text('Starting balance'));
    await tester.pumpAndSettle();

    // Hand-over frame: keypad up while the keyboard inset has not dropped yet.
    expect(tester.takeException(), isNull);
    final keypadTop = tester.getRect(find.byType(NumericKeypad)).top;
    expect(tester.getRect(_create()).bottom,
        closeTo(keypadTop - Insets.md, 0.5));

    // Keyboard gone: same geometry as before this task.
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getRect(_create()).bottom,
        closeTo(tester.getRect(find.byType(NumericKeypad)).top - Insets.md,
            0.5));
  });

  for (final size in const [Size(320, 568), Size(360, 640)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
          'no overflow at ${size.width.toInt()}×${size.height.toInt()} / '
          '${(scale * 100).toInt()}% with the keyboard up', (tester) async {
        _setSize(tester, w: size.width, h: size.height);
        _keyboardUp(tester, 260);
        await _open(tester, textScale: scale);

        expect(tester.takeException(), isNull);
        expect(tester.getRect(_create()).bottom,
            lessThanOrEqualTo(size.height - 260 + 0.5));
      });
    }
  }
}
