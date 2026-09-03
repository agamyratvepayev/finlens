import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/screen_header.dart' show SegmentedPicker;
import '../../theme/app_colors.dart';
import 'account_icons.dart';
import 'emoji_catalog.dart';

/// What the icon picker returns (spec §7b): a glyph — either a Material [icon]
/// **or** an [emoji] string — together with the chosen [colorValue] (an ARGB
/// int, or null to follow the account type's colour). Exactly one of [icon] /
/// [emoji] is non-null.
class IconSelection {
  const IconSelection({this.icon, this.emoji, this.colorValue});

  final IconData? icon;
  final String? emoji;
  final int? colorValue;
}

/// A single glyph tile in [color] (spec §7b). Renders either a Material [icon]
/// (tinted with the colour, filled when selected) or an [emoji] (which keeps its
/// own colours, on a tile tinted with the colour). The selected tile carries a
/// 2 pt accent ring — a ring reads better than a check in a dense grid.
class AccountGlyphTile extends StatelessWidget {
  const AccountGlyphTile({
    super.key,
    this.icon,
    this.emoji,
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 36,
    this.name,
  }) : assert(icon != null || emoji != null);

  final IconData? icon;
  final String? emoji;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final isEmoji = emoji != null;
    // Icons: filled with the colour when selected, else a dark tint with the
    // glyph in the colour. Emoji: always a tinted tile (the glyph carries its
    // own colours), a touch stronger when selected.
    final Color bg = isEmoji
        ? Color.alphaBlend(
            color.withValues(alpha: selected ? 0.28 : 0.18),
            AppColors.surfaceAlt)
        : (selected
            ? color
            : Color.alphaBlend(
                color.withValues(alpha: 0.18), AppColors.surfaceAlt));

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
            color: bg,
            borderRadius: BorderRadius.circular(size >= 42 ? 11 : 10),
            border: selected
                ? Border.all(color: AppColors.accentLight, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: isEmoji
              ? Text(emoji!, style: TextStyle(fontSize: size * 0.5))
              : Icon(
                  icon,
                  size: size * 0.5,
                  color: selected && !isEmoji ? Colors.white : color,
                ),
        ),
      ),
    );
  }
}

/// The icon picker (spec §7b): a colour row, an `Icons`/`Emoji` switch, search,
/// and a grouped grid whose glyphs render in the currently-selected colour. One
/// tap on a glyph selects it *and* the current colour, and closes. Opens over
/// the New account sheet.
///
/// [typeColor] is the account type's colour — the fallback when the user has not
/// picked one. [colorValue] is the account's current custom colour (null = follow
/// the type). [icon]/[emoji] carry the current glyph so it starts selected.
Future<IconSelection?> showIconPicker(
  BuildContext context, {
  required Color typeColor,
  int? colorValue,
  IconData? icon,
  String? emoji,
  bool allowEmoji = true,
  bool allowColor = true,
}) {
  return showModalBottomSheet<IconSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _IconPickerSheet(
      typeColor: typeColor,
      colorValue: colorValue,
      icon: icon,
      emoji: emoji,
      allowEmoji: allowEmoji,
      allowColor: allowColor,
    ),
  );
}

/// An icon-only variant for the category editor (which chooses its colour on a
/// separate row and stores an [IconData], never an emoji). Reuses the same grid
/// and search but hides the colour row and the Emoji tab, preserving the
/// category editor's existing behaviour after the account picker's rework.
Future<IconData?> showCategoryIconPicker(
  BuildContext context, {
  required Color color,
  IconData? selected,
}) async {
  final result = await showIconPicker(
    context,
    typeColor: color,
    colorValue: color.toARGB32(),
    icon: selected,
    allowEmoji: false,
    allowColor: false,
  );
  return result?.icon;
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({
    required this.typeColor,
    this.colorValue,
    this.icon,
    this.emoji,
    this.allowEmoji = true,
    this.allowColor = true,
  });

  final Color typeColor;
  final int? colorValue;
  final IconData? icon;
  final String? emoji;
  final bool allowEmoji;
  final bool allowColor;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

enum _GlyphTab { icons, emoji }

class _IconPickerSheetState extends State<_IconPickerSheet> {
  String _query = '';
  late _GlyphTab _tab;

  /// The chosen colour as an ARGB int, or null to follow the type. The rendered
  /// colour is [_effectiveColor].
  int? _colorValue;

  @override
  void initState() {
    super.initState();
    _colorValue = widget.colorValue;
    // Land on the tab holding the current glyph so it starts selected.
    _tab = widget.emoji != null ? _GlyphTab.emoji : _GlyphTab.icons;
  }

  Color get _effectiveColor =>
      _colorValue == null ? widget.typeColor : Color(_colorValue!);

  void _pickColor(Color c) => setState(() => _colorValue = c.toARGB32());

  void _selectIcon(IconData icon) =>
      Navigator.of(context).pop(IconSelection(icon: icon, colorValue: _colorValue));

  void _selectEmoji(String emoji) => Navigator.of(context)
      .pop(IconSelection(emoji: emoji, colorValue: _colorValue));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
                    child: Text(l.qaIcon,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(l.actionCancel,
                        style: TextStyle(fontSize: 14, color: AppColors.accent)),
                  ),
                ],
              ),
            ),
            // Colour row — heading depends on the tab (spec §7b). Hidden in the
            // category editor, which chooses its colour elsewhere.
            if (widget.allowColor) ...[
              _colorRow(l),
              const SizedBox(height: 12),
            ],
            // Icons / Emoji switch — hidden when emoji are not allowed.
            if (widget.allowEmoji)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: SegmentedPicker<_GlyphTab>(
                  values: const [_GlyphTab.icons, _GlyphTab.emoji],
                  selected: _tab,
                  labelOf: (t) =>
                      t == _GlyphTab.icons ? l.qaIconsTab : l.qaEmojiTab,
                  onChanged: (t) => setState(() {
                    _tab = t;
                    _query = '';
                  }),
                ),
              ),
            _searchBar(l),
            Expanded(
              child:
                  _tab == _GlyphTab.icons ? _iconsBody(l) : _emojiBody(l),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorRow(AppLocalizations l) {
    final heading =
        _tab == _GlyphTab.emoji ? l.qaBackgroundColour : l.qaColour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            heading.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.07 * 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final c in AppColors.accountSwatches) ...[
                _Swatch(
                  color: c,
                  selected: c.toARGB32() == _effectiveColor.toARGB32(),
                  onTap: () => _pickColor(c),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchBar(AppLocalizations l) {
    return Padding(
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
                  hintText: _tab == _GlyphTab.icons
                      ? l.qaSearchIcons
                      : l.qaSearchEmoji,
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconsBody(AppLocalizations l) {
    if (_query.trim().isNotEmpty) {
      final results = searchAccountIcons(_query);
      if (results.isEmpty) return _noIconMatch(l);
      // During search, group headings are removed and results render as one set
      // (spec §6) — a null label draws the grid with no heading.
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [_iconSection(null, results)],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Every glyph in every group is rendered — no truncation, no "see all"
        // (spec §6); the sheet scrolls.
        for (final entry in accountIconGroups.entries)
          _iconSection(entry.key, entry.value),
      ],
    );
  }

  Widget _iconSection(String? label, List<AccountIconEntry> entries) {
    return _gridSection(
      label,
      entries.length,
      [
        for (final e in entries)
          AccountGlyphTile(
            icon: e.icon,
            name: e.name,
            color: _effectiveColor,
            size: 42,
            selected: e.icon == widget.icon && widget.emoji == null,
            onTap: () => _selectIcon(e.icon),
          ),
      ],
    );
  }

  Widget _emojiBody(AppLocalizations l) {
    if (_query.trim().isNotEmpty) {
      final results = searchEmoji(_query);
      if (results.isEmpty) {
        return _noMatchMessage(l.qaNoEmojiMatch);
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [_emojiSection(null, results)],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in emojiGroups.entries)
          _emojiSection(entry.key, entry.value),
      ],
    );
  }

  Widget _emojiSection(String? label, List<EmojiEntry> entries) {
    return _gridSection(
      label,
      entries.length,
      [
        for (final e in entries)
          AccountGlyphTile(
            emoji: e.emoji,
            name: e.emoji,
            color: _effectiveColor,
            size: 42,
            selected: e.emoji == widget.emoji,
            onTap: () => _selectEmoji(e.emoji),
          ),
      ],
    );
  }

  /// A grid section. When [label] is non-null the heading carries the group's
  /// glyph [count] — `HEALTH · 7` — so the user is not left wondering whether the
  /// group continues below (spec §6). A null label (search results) draws no
  /// heading at all.
  Widget _gridSection(String? label, int count, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Text(
              '${label.toUpperCase()} · $count',
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
          child: Wrap(spacing: 7, runSpacing: 7, children: tiles),
        ),
      ],
    );
  }

  /// The icons-tab no-match (spec §6): the message in the same shape as the
  /// category picker's — the trimmed query set off by colour, no quotes — and a
  /// single action, `Try emoji instead`, that switches to the Emoji tab carrying
  /// the query across. The icon set is finite; emoji is not, so the fallback
  /// beats a dead end. The action is hidden when emoji are not allowed (the
  /// category editor's icon-only variant).
  Widget _noIconMatch(AppLocalizations l) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        _colouredNoMatch(l.qaNoIconMatch(_kSentinel), _query.trim()),
        if (widget.allowEmoji) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              // Keep _query so the emoji search runs the same terms (spec §6).
              onPressed: () => setState(() => _tab = _GlyphTab.emoji),
              child: Text(l.qaTryEmoji,
                  style: TextStyle(fontSize: 14, color: AppColors.accent)),
            ),
          ),
        ],
      ],
    );
  }

  /// A plain, uncoloured centred message (emoji tab has no fallback action).
  Widget _noMatchMessage(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textTertiary)),
    );
  }

  /// Renders a "no match" template with its query placeholder recoloured to the
  /// primary text colour, on one ellipsised line. A plain-ASCII sentinel is
  /// interpolated through the localised template then split back out, so it works
  /// wherever the placeholder sits in a locale.
  Widget _colouredNoMatch(String template, String query) {
    final i = template.indexOf(_kSentinel);
    final before = i < 0 ? template : template.substring(0, i);
    final after = i < 0 ? '' : template.substring(i + _kSentinel.length);
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
        children: [
          TextSpan(text: before),
          TextSpan(
              text: query,
              style: const TextStyle(color: AppColors.textPrimary)),
          TextSpan(text: after),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// An unambiguous placeholder marker for splitting a localised no-match template;
/// no query or template contains it.
const String _kSentinel = 'ZZQUERYZZ';

class _Swatch extends StatelessWidget {
  const _Swatch(
      {required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: Colors.white, width: 2.5)
                : null,
          ),
        ),
      ),
    );
  }
}
