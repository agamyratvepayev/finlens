import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/data/seed_data.dart';
import 'core/store/app_store.dart';
import 'features/shell/app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(FinLensApp(store: buildSeedStore()));
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
