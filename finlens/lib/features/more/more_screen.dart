import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/data/dev_seed_data.dart';
import '../../core/data/seed_data.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../balance/assets_screen.dart';
import '../balance/liabilities_screen.dart';
import '../planner/archive_screen.dart';
import '../quick_add/pickers.dart';

/// Selectable UI languages. `null` = follow the device locale. Endonyms are
/// intentionally shown in each language's own script and are NOT translated.
const _languageOptions = <(Locale?, String)>[
  (null, ''),
  (Locale('en'), 'English'),
  (Locale('ru'), 'Русский'),
  (Locale('tr'), 'Türkçe'),
  (Locale('tk'), 'Türkmençe'),
];

String _languageLabel(BuildContext context, Locale? locale) {
  if (locale == null) return AppLocalizations.of(context).languageSystemDefault;
  for (final (loc, endonym) in _languageOptions) {
    if (loc?.languageCode == locale.languageCode) return endonym;
  }
  return locale.languageCode;
}

void _pickLanguage(BuildContext context, AppStore store) {
  final l = AppLocalizations.of(context);
  showAppSheet(
    context,
    title: l.language,
    initialSize: 0.5,
    builder: (sheetContext, controller) {
      final current = store.locale?.languageCode;
      return ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
            Insets.gutter, 0, Insets.gutter, Insets.xxl),
        children: [
          FormSection(
            margin: EdgeInsets.zero,
            children: [
              for (final (loc, endonym) in _languageOptions)
                FormRow(
                  label: loc == null ? l.languageSystemDefault : endonym,
                  trailing: (loc?.languageCode == current)
                      ? const Icon(Icons.check_rounded,
                          size: 20, color: AppColors.accent)
                      : null,
                  onTap: () {
                    store.setLocale(loc);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ],
      );
    },
  );
}

/// "More" is listed in the bottom navigation but not specified in v1.1. It
/// collects the entry points the spec defines elsewhere — Archive (5.8),
/// account and category management (4.1/4.2), privacy mode (1.1).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(title: l.moreTitle, showEye: false, showAdd: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Insets.xxl),
              children: [
                SectionLabel(l.moreYourMoney),
                FormSection(
                  children: [
                    FormRow(
                      icon: Icons.trending_up_rounded,
                      label: l.balanceSectionAssets,
                      subtitle: l.countAccounts(AccountGroup.assets
                          .fold(0, (s, g) => s + store.groupCount(g))),
                      showChevron: true,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute(
                        builder: (_) => const AssetsScreen(),
                      )),
                    ),
                    FormRow(
                      icon: Icons.credit_card_rounded,
                      label: l.balanceSectionLiabilities,
                      subtitle: l.countAccounts(AccountGroup.liabilities
                          .fold(0, (s, g) => s + store.groupCount(g))),
                      showChevron: true,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute(
                        builder: (_) => const LiabilitiesScreen(),
                      )),
                    ),
                    FormRow(
                      icon: Icons.category_rounded,
                      label: l.moreCategories,
                      subtitle: l.moreCategoriesInUse(store.categories.length),
                      showChevron: true,
                      onTap: () => pickCategory(
                        context,
                        type: CategoryType.expense,
                        title: l.moreCategories,
                      ),
                    ),
                  ],
                ),
                SectionLabel(l.morePlannerSection),
                FormSection(
                  children: [
                    FormRow(
                      icon: Icons.inventory_2_rounded,
                      label: 'Archive',
                      subtitle: l.countArchivedItems(store.archivedCount),
                      showChevron: true,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute(
                        builder: (_) => const ArchiveScreen(),
                      )),
                    ),
                  ],
                ),
                SectionLabel(l.morePreferences),
                FormSection(
                  children: [
                    FormRow(
                      icon: Icons.language_rounded,
                      label: l.language,
                      value: _languageLabel(context, store.locale),
                      showChevron: true,
                      onTap: () => _pickLanguage(context, store),
                    ),
                    ToggleRow(
                      icon: Icons.visibility_off_rounded,
                      label: l.morePrivacyMode,
                      subtitle: l.morePrivacyModeDesc,
                      value: store.masked,
                      onChanged: (_) => store.toggleMasked(),
                    ),
                    FormRow(
                      icon: Icons.add_circle_outline_rounded,
                      label: l.moreAddAccount,
                      showChevron: true,
                      onTap: () => showNewAccountSheet(context),
                    ),
                  ],
                ),
                if (kDebugMode) ...[
                  const SectionLabel('Developer'),
                  FormSection(
                    children: [
                      FormRow(
                        icon: Icons.science_rounded,
                        label: 'Seed dev data',
                        subtitle: 'Load the varied test history',
                        onTap: () {
                          StoreScope.read(context)
                              .loadFrom(buildDevSeedStore());
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(const SnackBar(
                              content: Text('Loaded development data'),
                            ));
                        },
                      ),
                      FormRow(
                        icon: Icons.restart_alt_rounded,
                        label: 'Reset to default',
                        subtitle: 'Restore the standard fixture',
                        onTap: () {
                          StoreScope.read(context).loadFrom(buildSeedStore());
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(const SnackBar(
                              content: Text('Reset to default data'),
                            ));
                        },
                      ),
                    ],
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.only(top: Insets.lg),
                  child: Center(
                    child: Text(
                      'FinLens · Tech Spec v1.1',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
