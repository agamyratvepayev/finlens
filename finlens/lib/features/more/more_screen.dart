import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/persistence/backup_codec.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/restore_flow.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../planner/archive_screen.dart';
import 'category_management_screen.dart';
import 'tag_management_screen.dart';
import 'widgets/split_action_row.dart';
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
          // More has no header (§1): the bottom nav already prints the screen's
          // name, so a title row here would draw the word twice. The mask lives
          // in PREFERENCES below, where it is explained rather than mirrored as a
          // header eye.
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // DATA is broader than its contents (Archive lives here too) —
                // the opposite failure of the old "Planner" label, which was
                // narrower than the archived accounts and categories it headed.
                //
                // Still the ONLY SectionLabel with a custom padding, but for a
                // new reason: with the header gone this is the first thing on the
                // page, so the top value is a page margin (Insets.xl) measured
                // from the safe area, not the default Insets.lg that suits a label
                // trailing a card. Do not "normalise" it back to the default.
                SectionLabel(
                  l.moreData,
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.xl, Insets.gutter, Insets.sm),
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
                  // Back up / Restore share one row (§2): carry the whole store
                  // to a JSON file and back, so a user can move to a new phone.
                  // The indent-48 hairline aligns to the text past the 24-icon +
                  // 12-gap column. Restore replaces everything, but sitting it
                  // beside Back up is safe only because runRestoreFlow always
                  // opens a destructive confirm first — see the note in §2.2.
                  const RowDivider(indent: 48),
                  SplitActionRow(
                    leftIcon: Icons.save_alt_rounded,
                    leftLabel: l.moreBackupShort,
                    onLeftTap: () => _runBackup(context, store),
                    rightIcon: Icons.restore_rounded,
                    rightLabel: l.moreRestoreShort,
                    onRightTap: () => runRestoreFlow(context, store),
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
              ],
            ),
          ),
          // Pinned (§4): the footer leaves the scrollable list and sits above the
          // bottom nav, so on a screen whose cards end halfway down it no longer
          // hangs under the last card with a screen of black beneath it.
          const _VersionFooter(),
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
/// Flexible sized for text; this row owns More's shared 38 pt metrics. Do not
/// widen FormRow to take it — five other screens render FormRow and must stay
/// byte-identical.
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
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
              // Shared trailing (§3.2): label→value gap, the value (never shrinks),
              // an 8 pt gap, then an 18 pt chevron box flush to the content edge.
              const SizedBox(width: Insets.sm),
              Text('$count', style: AppText.amount),
              const _RowTrailingChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The value→chevron gap and the 18 pt chevron box, shared by every value+chevron
/// row so the chevron's right edge (flush to the content edge) and the value's
/// right edge (8 pt left of the box) land on the same x down the card (§3.2).
class _RowTrailingChevron extends StatelessWidget {
  const _RowTrailingChevron();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 8),
        SizedBox(
          width: 18,
          child: Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// The language row — inline for the same reason as [_ArchiveRow].
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
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
              // Same trailing column as [_ArchiveRow]: the endonym is the value
              // and never shrinks (the label ellipsises instead); its right edge
              // and the chevron's line up with the other rows (§3.2).
              const SizedBox(width: Insets.sm),
              Text(value, style: AppText.amount, maxLines: 1),
              const _RowTrailingChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The old "Privacy mode" row, its subtitle folded into the label. ToggleRow-
/// shaped but inline. The switch is boxed to 40 × 24 (§3.1) so it fits the shared
/// 38 pt row and its right edge lines up with the chevron column; the whole row
/// stays the touch target, not just the control.
class _MaskRow extends StatelessWidget {
  const _MaskRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
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
              // The control's right edge is the same content edge the chevrons sit
              // on; FittedBox constrains the switch's layout box to 40 × 24 (a bare
              // Transform.scale would shrink the paint but keep the full layout
              // size, breaking the 38 pt row).
              SizedBox(
                width: 40,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.surfaceHigh,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The footer: the real version and build, read once from the pubspec via
/// [PackageInfo]. A line of text, not a row — no card, no chevron, no tap
/// target. "FinLens" is the product name (a proper noun), not a localised
/// string; only the version/build come from [l.moreVersion].
///
/// Stateful, and the future is resolved once in [initState] (§4): a
/// FutureBuilder over a future rebuilt every `build` would re-fetch on each mask
/// toggle. While it is unresolved the line renders a single space so it already
/// occupies exactly one line's height — when the real text arrives it swaps in
/// place with no layout shift, and the space grows with the text scale just as
/// the text would.
class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md, bottom: Insets.lg),
      child: Center(
        child: FutureBuilder<PackageInfo>(
          future: _info,
          builder: (context, snap) {
            final info = snap.data;
            final text = info == null
                ? ''
                : 'FinLens ${l.moreVersion(info.version, info.buildNumber)}';
            // A space (not '') reserves one line's height so nothing shifts when
            // the real string resolves.
            return Text(
              text.isEmpty ? ' ' : text,
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
