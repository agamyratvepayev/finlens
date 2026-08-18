import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/data/dev_seed_data.dart';
import '../../core/data/seed_data.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../balance/assets_screen.dart';
import '../balance/liabilities_screen.dart';
import '../planner/archive_screen.dart';
import '../quick_add/pickers.dart';

/// "More" is listed in the bottom navigation but not specified in v1.1. It
/// collects the entry points the spec defines elsewhere — Archive (5.8),
/// account and category management (4.1/4.2), privacy mode (1.1).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const ScreenHeader(title: 'More', showEye: false, showAdd: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Insets.xxl),
              children: [
                const SectionLabel('Your money'),
                FormSection(
                  children: [
                    FormRow(
                      icon: Icons.trending_up_rounded,
                      label: 'Assets',
                      subtitle:
                          '${AccountGroup.assets.fold(0, (s, g) => s + store.groupCount(g))} accounts',
                      showChevron: true,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute(
                        builder: (_) => const AssetsScreen(),
                      )),
                    ),
                    FormRow(
                      icon: Icons.credit_card_rounded,
                      label: 'Liabilities',
                      subtitle:
                          '${AccountGroup.liabilities.fold(0, (s, g) => s + store.groupCount(g))} accounts',
                      showChevron: true,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute(
                        builder: (_) => const LiabilitiesScreen(),
                      )),
                    ),
                    FormRow(
                      icon: Icons.category_rounded,
                      label: 'Categories',
                      subtitle: '${store.categories.length} in use',
                      showChevron: true,
                      onTap: () => pickCategory(
                        context,
                        type: CategoryType.expense,
                        title: 'Categories',
                      ),
                    ),
                  ],
                ),
                const SectionLabel('Planner'),
                FormSection(
                  children: [
                    FormRow(
                      icon: Icons.inventory_2_rounded,
                      label: 'Archive',
                      subtitle:
                          '${store.archivedCount} archived item${store.archivedCount == 1 ? '' : 's'}',
                      showChevron: true,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(MaterialPageRoute(
                        builder: (_) => const ArchiveScreen(),
                      )),
                    ),
                  ],
                ),
                const SectionLabel('Preferences'),
                FormSection(
                  children: [
                    ToggleRow(
                      icon: Icons.visibility_off_rounded,
                      label: 'Privacy mode',
                      subtitle: 'Mask every amount across the app',
                      value: store.masked,
                      onChanged: (_) => store.toggleMasked(),
                    ),
                    FormRow(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Add an account',
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
