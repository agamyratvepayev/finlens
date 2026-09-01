import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/persistence/backup_codec.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../planner/archive_screen.dart';
import 'category_management_screen.dart';
import 'tag_management_screen.dart';
import 'widgets/split_count_row.dart';

/// Selectable UI languages (§7.1). Every entry is a real language: the "System
/// default" row is gone, because the stored locale is never null — the device
/// only seeds it once, at first launch. Endonyms are shown in each language's
/// own script and are NOT translated.
const _languageOptions = <(Locale, String)>[
  (Locale('en'), 'English'),
  (Locale('ru'), 'Русский'),
  (Locale('tr'), 'Türkçe'),
  (Locale('tk'), 'Türkmençe'),
];

String _languageLabel(Locale locale) {
  for (final (loc, endonym) in _languageOptions) {
    if (loc.languageCode == locale.languageCode) return endonym;
  }
  return locale.languageCode;
}

/// §7.2/§7.3 — a content-sized sheet built from a local card, not a fractional
/// [showAppSheet] with a [FormSection]. These rows have no leading icon, so the
/// shared FormSection's `indent: 52` divider would start 40 pt past the text;
/// the local card draws its own `indent: 12` hairline and its rows sit at 37 pt
/// (padding 10), matching More's own Language row rather than the 41 pt default.
void _pickLanguage(BuildContext context, AppStore store) {
  final l = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final current = store.locale.languageCode;
      final rows = <Widget>[
        for (final (loc, endonym) in _languageOptions)
          InkWell(
            onTap: () {
              store.setLocale(loc);
              Navigator.of(sheetContext).pop();
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      endonym,
                      style: AppText.body.copyWith(
                          fontSize: 14.5, color: AppColors.textPrimary),
                    ),
                  ),
                  if (loc.languageCode == current)
                    const Icon(Icons.check_rounded,
                        size: 20, color: AppColors.accent),
                ],
              ),
            ),
          ),
      ];
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Insets.md),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, Insets.lg, Insets.gutter, Insets.md),
                child: Text(l.language, style: AppText.title.copyWith(fontSize: 19)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, Insets.md),
                child: AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const RowDivider(indent: 12),
                        rows[i],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Dump: serialise the whole store and hand the bytes to the system "Save"
/// dialog so the user stores the `.json` anywhere (Downloads, SD card, Drive).
/// On Android/iOS the picker writes the bytes itself; on desktop it returns the
/// chosen path only, so we write there ourselves. A cancelled dialog is a no-op.
Future<void> _runBackup(BuildContext context, AppStore store) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final now = DateTime.now();
    final bytes = Uint8List.fromList(
      utf8.encode(encodeBackup(store, exportedAt: now)),
    );
    final stamp = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    // saveFile writes [bytes] itself on every platform we ship (mobile writes
    // the file; desktop writes them to the chosen path) — we only react to the
    // returned path being null (the user cancelled the dialog).
    final path = await FilePicker.saveFile(
      dialogTitle: l.moreBackup,
      fileName: 'finlens-backup-$stamp.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    if (path == null) return; // user cancelled
    messenger.showSnackBar(SnackBar(content: Text(l.backupSavedMsg)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.backupFailedMsg)));
  }
}

/// Restore: pick a backup `.json`, validate it, confirm the destructive replace,
/// then load it. [AppStore.loadFrom] fires `notifyListeners`, so the attached
/// persister writes the restored data to SQLite on its own — nothing here
/// touches the database. An invalid/corrupt file shows a notice and changes
/// nothing; cancelling the picker or the confirm is a silent no-op.
Future<void> _runRestore(BuildContext context, AppStore store) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final FilePickerResult? picked;
  try {
    picked = await FilePicker.pickFiles(
      dialogTitle: l.moreRestore,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.restoreInvalidMsg)));
    return;
  }
  if (picked == null || picked.files.isEmpty) return; // cancelled

  final bytes = picked.files.single.bytes;
  if (bytes == null) {
    messenger.showSnackBar(SnackBar(content: Text(l.restoreInvalidMsg)));
    return;
  }

  final BackupDocument doc;
  try {
    doc = decodeBackup(utf8.decode(bytes));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.restoreInvalidMsg)));
    return;
  }

  if (!context.mounted) return;
  final ok = await showDestructiveConfirm(
    context,
    title: l.restoreConfirmTitle,
    message: l.restoreConfirmMsg(doc.accountCount, doc.txnCount),
    impact: [
      ImpactLine.lost(l.restoreImpactLost),
      ImpactLine.kept(l.restoreImpactKept),
    ],
    confirmLabel: l.restoreConfirmAction,
  );
  if (!ok) return;

  store.loadFrom(doc.source);
  messenger.showSnackBar(SnackBar(content: Text(l.restoreDoneMsg)));
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
                    // includes archived. A row that says 16 above a screen
                    // listing 14 is the defect this screen exists to kill.
                    leftCount: store.categoryCount,
                    onLeftTap: () => Navigator.of(context, rootNavigator: true)
                        .push(MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
                    )),
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
                  // Backup / Restore: carry the whole store to a JSON file and
                  // back, so a user can move to a new phone (indent-48 hairlines
                  // align to the text past the 24-icon + 12-gap column).
                  const RowDivider(indent: 48),
                  _ActionRow(
                    icon: Icons.save_alt_rounded,
                    label: l.moreBackup,
                    onTap: () => _runBackup(context, store),
                  ),
                  const RowDivider(indent: 48),
                  _ActionRow(
                    icon: Icons.restore_rounded,
                    label: l.moreRestore,
                    onTap: () => _runRestore(context, store),
                  ),
                ]),
                // PREFERENCES follows a card, not the screen title, so it keeps
                // the default top gap.
                SectionLabel(l.morePreferences),
                _card([
                  _LanguageRow(
                    value: _languageLabel(store.locale),
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

/// A plain tappable row: leading icon, label, trailing chevron — no value.
/// Used for Backup / Restore, which navigate to a picker rather than showing a
/// count or a switch. Same 24-icon + 12-gap + 10-padding metrics as the rows
/// above so its hairlines and text align with them.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppText.body
                    .copyWith(fontSize: 14.5, color: AppColors.textPrimary),
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
