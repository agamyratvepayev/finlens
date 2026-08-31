import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../planner/archive_screen.dart';
import '../quick_add/pickers.dart';
import 'tag_management_screen.dart';
import 'widgets/split_count_row.dart';

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

/// The fifth tab is a settings page. The governing rule:
///
/// > A row belongs on More only when the thing it reaches has no home
/// > elsewhere.
///
/// That test removed Assets and Liabilities (Balance's assets/liabilities
/// sections already render this content, and through its filter — More's copies
/// disagreed on the numbers), the category picker's dead entry point, and the
/// permanent "Add an account" row the codebase forbids. What remains reaches
/// things with no other home: Categories and Tags management, the Archive, the
/// language choice, and the app-wide mask.
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
          // The eye stays off here: More is where the mask is explained, not a
          // second copy of the header control.
          ScreenHeader(title: l.moreTitle, showEye: false, showAdd: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Insets.xxl),
              children: [
                // DATA is broader than its contents (Archive lives here too) —
                // the opposite failure of the old "Planner" label, which was
                // narrower than the archived accounts and categories it headed.
                //
                // The ONLY SectionLabel in the app that takes a custom padding:
                // ScreenHeader's bottom gap is shared and can't shrink, so the
                // 28 pt title→label gap is closed to 16 pt from the label side.
                // Do not "normalise" this back to the default.
                SectionLabel(
                  l.moreData,
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.xs, Insets.gutter, Insets.sm),
                ),
                _card([
                  SplitCountRow(
                    leftLabel: l.moreCategories,
                    // The live count (archived excluded) — never a total that
                    // includes archived. A row that says 16 above a picker
                    // listing 14 is the defect this screen exists to kill.
                    leftCount: store.categoryCount,
                    // Knowingly wrong, and out of scope to fix: this opens Quick
                    // Add's *selection* sheet, pinned to expense, because
                    // CategoryManagementScreen does not exist yet. It gets its
                    // own spec.
                    onLeftTap: () => pickCategory(
                      context,
                      type: CategoryType.expense,
                      title: l.moreCategories,
                    ),
                    rightLabel: l.moreTags,
                    rightCount: store.tagsInUseCount,
                    onRightTap: () => Navigator.of(context, rootNavigator: true)
                        .push(MaterialPageRoute(
                      builder: (_) => const TagManagementScreen(),
                    )),
                  ),
                  // Full-width hairline: the row above has no icon column to
                  // align an indent to.
                  const RowDivider(),
                  _ArchiveRow(
                    count: store.archivedCount,
                    onTap: () => Navigator.of(context, rootNavigator: true)
                        .push(MaterialPageRoute(
                      builder: (_) => const ArchiveScreen(),
                    )),
                  ),
                ]),
                // PREFERENCES follows a card, not the screen title, so it keeps
                // the default top gap.
                SectionLabel(l.morePreferences),
                _card([
                  _LanguageRow(
                    value: _languageLabel(context, store.locale),
                    onTap: () => _pickLanguage(context, store),
                  ),
                  // Indent 48 (= 12 padding + 24 icon + 12 gap) so the hairline
                  // starts at the text, not the 52 the shared FormSection uses.
                  const RowDivider(indent: 48),
                  _MaskRow(
                    value: store.masked,
                    onChanged: (_) => store.toggleMasked(),
                  ),
                ]),
                const _VersionFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One rounded card, hairlines supplied by the caller (this screen needs a
/// full-width divider in one card and an indented one in the other, so it can't
/// use FormSection's automatic between-rows rule).
Widget _card(List<Widget> children) => AppCard(
      margin: const EdgeInsets.fromLTRB(
          Insets.gutter, 0, Insets.gutter, Insets.md),
      child: Column(children: children),
    );

/// FormRow-shaped but inline: FormRow's padding is 12 and its value sits in a
/// Flexible sized for text; this row's padding is 8. Do not widen FormRow to
/// take it — five other screens render FormRow and must stay byte-identical.
///
/// Renders at zero and prints `0` rather than disappearing: Archive has its own
/// empty state, so a tap at zero lands somewhere coherent, and a row that
/// vanishes and returns is a worse surprise than a bare `0`.
class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              child: Icon(Icons.inventory_2_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.moreArchive,
                style: AppText.body.copyWith(
                    fontSize: 14.5, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text('$count', style: AppText.amount),
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The language row — inline for the same padding reason as [_ArchiveRow].
/// Behaviour is unchanged: it still opens [_pickLanguage].
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              child: Icon(Icons.language_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.language,
                style: AppText.body.copyWith(
                    fontSize: 14.5, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppText.amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The old "Privacy mode" row, its subtitle folded into the label. ToggleRow-
/// shaped but inline (same padding reason). The scaled switch — not the text —
/// sets the row height; the whole row is the touch target, so the control looks
/// 26 pt tall while the target stays the full 37 pt row.
class _MaskRow extends StatelessWidget {
  const _MaskRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              child: Icon(Icons.visibility_off_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.moreMaskAmounts,
                style: AppText.body.copyWith(
                    fontSize: 14.5, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Transform.scale(
              scale: 0.85,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.surfaceHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The footer: the real version and build, read once from the pubspec via
/// [PackageInfo]. A line of text, not a row — no card, no chevron, no tap
/// target. "FinLens" is the product name (a proper noun), not a localised
/// string; only the version/build come from [l.moreVersion].
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg),
      child: Center(
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final info = snap.data;
            return Text(
              info == null
                  ? ''
                  : 'FinLens ${l.moreVersion(info.version, info.buildNumber)}',
              style: AppText.caption.copyWith(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            );
          },
        ),
      ),
    );
  }
}
