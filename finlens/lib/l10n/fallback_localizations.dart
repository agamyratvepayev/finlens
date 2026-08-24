import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// flutter_localizations does not ship Turkmen (`tk`) Material/Cupertino strings
/// (it has `tr` and `ru`, not `tk`). Without a delegate that supports `tk`, any
/// Material widget under a Turkmen locale would throw
/// "No MaterialLocalizations found".
///
/// [Localizations] loads only the first delegate per type whose `isSupported`
/// matches the locale, so these `tk`-only shims — placed *before* the
/// Global* delegates — provide framework strings for Turkmen by borrowing
/// Turkish (the closest supported language). Every other locale falls through
/// to the real Global* delegate. Our own [AppLocalizations] still supplies real
/// Turkmen for the app's own text; only the framework's built-in widget strings
/// (date picker, text-selection toolbar, etc.) are borrowed.
class TkMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const TkMaterialLocalizationsDelegate();

  static const _turkish = Locale('tr');

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tk';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_turkish);

  @override
  bool shouldReload(TkMaterialLocalizationsDelegate old) => false;
}

class TkCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const TkCupertinoLocalizationsDelegate();

  static const _turkish = Locale('tr');

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tk';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(_turkish);

  @override
  bool shouldReload(TkCupertinoLocalizationsDelegate old) => false;
}
