import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'account_icons.dart';

/// A single glyph tile in the group's colour (spec §5.5/§5.6). Unselected tiles
/// show a dark tint of the colour with the glyph in the colour; the selected
/// tile is filled with the colour and carries a 2 pt white ring.
class AccountGlyphTile extends StatelessWidget {
  const AccountGlyphTile({
    super.key,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 36,
    this.name,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: selected
                ? color
                : Color.alphaBlend(
                    color.withValues(alpha: 0.18), AppColors.surfaceAlt),
            borderRadius: BorderRadius.circular(size >= 42 ? 11 : 10),
            border:
                selected ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Icon(
            icon,
            size: size * 0.5,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

/// The full icon picker (spec §5.6): grouped grid, every tile in [color], with
/// a locale-aware search. Opens over the New account sheet and returns the
/// chosen glyph (or [selected] unchanged on Done).
Future<IconData?> showIconPicker(
  BuildContext context, {
  required Color color,
  IconData? selected,
}) {
  return showModalBottomSheet<IconData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface, // #161618
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _IconPickerSheet(color: color, selected: selected),
  );
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({required this.color, this.selected});

  final Color color;
  final IconData? selected;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final results = _query.trim().isEmpty ? null : searchAccountIcons(_query);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.sheetGrabber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(AppLocalizations.of(context).qaChooseIcon,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(widget.selected),
                    child: Text(AppLocalizations.of(context).actionDone,
                        style: TextStyle(fontSize: 14, color: AppColors.accent)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.sheetCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        cursorColor: AppColors.accent,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: AppLocalizations.of(context).qaSearchIcons,
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: results != null
                  ? _grid(AppLocalizations.of(context).qaResults, results)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final entry in accountIconGroups.entries)
                          _section(entry.key, entry.value),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(String label, List<AccountIconEntry> entries) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text(AppLocalizations.of(context).qaNoIconsMatch,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [_section(label, entries)],
    );
  }

  Widget _section(String label, List<AccountIconEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.07 * 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final e in entries)
                AccountGlyphTile(
                  icon: e.icon,
                  name: e.name,
                  color: widget.color,
                  size: 42,
                  selected: e.icon == widget.selected,
                  onTap: () => Navigator.of(context).pop(e.icon),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
