// TEMPORARY repro harness for task 008 §4 (overflow). Delete after use.
import 'package:flutter/material.dart';

import 'core/data/seed_data.dart';
import 'core/models/models.dart';
import 'core/store/app_store.dart';
import 'core/utils/date_range.dart';
import 'features/insight/category_detail_screen.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

void main() {
  final store = buildSeedStore();
  store.setInsightWindow(RangePreset.thisMonth.resolve(DateTime(2026, 8, 9)));
  store.addTxn(
    type: TxnType.expense,
    amount: 2000,
    currency: 'USD',
    fromRef: 'a-checking',
    toRef: 'c-housing',
    date: DateTime(2026, 8, 8, 10, 0),
  );
  runApp(_Repro(store: store));
}

class _Repro extends StatelessWidget {
  const _Repro({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => ColoredBox(
            color: const Color(0xFF000000),
            child: Center(
              child: SizedBox(
                width: 320,
                height: 568,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: const Size(320, 568),
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                  ),
                  child: const CategoryDetailScreen(categoryId: 'c-housing'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
