import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'account_icons.dart';
import 'icon_picker_sheet.dart';

/// Shell shared by every picker and create sheet: a drag handle, a title bar
/// and a scrollable body.
///
/// The modal itself is transparent and the background is painted by a
/// content-hugging [Container] (§1): a full-height opaque sheet would swallow
/// taps in the empty region above its visible content, so tap-to-dismiss failed
/// at full expansion. With the sheet sized to its content, that region is the
/// bare modal barrier at every height. The max extent is capped so at least
/// 44pt of barrier stays tappable below the status bar, and
/// [DraggableScrollableSheet.shouldCloseOnMinExtent] lets one downward drag
/// close the sheet from any height.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext, ScrollController) builder,
  double initialSize = 0.7,
  List<Widget> actions = const [],
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final media = MediaQuery.of(context);
      // Leave ≥44pt of barrier tappable below the status bar at full extent.
      final maxSize =
          ((media.size.height - media.padding.top - 44) / media.size.height)
              .clamp(0.5, 0.94);
      final initial = initialSize > maxSize ? maxSize : initialSize;
      return DraggableScrollableSheet(
        initialChildSize: initial,
        minChildSize: 0.4,
        maxChildSize: maxSize,
        expand: false,
        shouldCloseOnMinExtent: true,
        builder: (context, controller) => Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
          ),
          child: Column(
            children: [
              const SizedBox(height: Insets.md),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.lg,
                  Insets.gutter,
                  Insets.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: AppText.title.copyWith(fontSize: 19)),
                    ),
                    ...actions,
                  ],
                ),
              ),
              Expanded(child: builder(context, controller)),
            ],
          ),
        ),
      );
    },
  );
}

/// Spec 4.2 — account picker. The "＋ New account" affordance lives in the
/// header (right of the title), reachable the instant the sheet opens and while
/// a search is active — no longer buried at the end of the list.
Future<Account?> pickAccount(
  BuildContext context, {
  String? title,
  bool Function(Account)? filter,
  String? excludeId,
}) {
  return showAppSheet<Account>(
    context,
    title: title ?? AppLocalizations.of(context).qaSelectAccount,
    actions: [
      _HeaderCreateAction<Account>(
        label: AppLocalizations.of(context).qaNewAccount,
        // Do not prefill the name from the picker's search query (spec §3).
        onCreate: (ctx) => showNewAccountSheet(ctx),
      ),
    ],
    builder: (context, controller) => _AccountPickerBody(
      controller: controller,
      filter: filter,
      excludeId: excludeId,
    ),
  );
}

class _AccountPickerBody extends StatefulWidget {
  const _AccountPickerBody({
    required this.controller,
    this.filter,
    this.excludeId,
  });

  final ScrollController controller;
  final bool Function(Account)? filter;
  final String? excludeId;

  @override
  State<_AccountPickerBody> createState() => _AccountPickerBodyState();
}

class _AccountPickerBodyState extends State<_AccountPickerBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _query.trim().toLowerCase();
    final all = store.visibleAccounts
        .where((a) => a.id != widget.excludeId)
        .where((a) => widget.filter?.call(a) ?? true)
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q))
        .toList();

    final grouped = <AccountGroup, List<Account>>{};
    for (final a in all) {
      grouped.putIfAbsent(a.group, () => []).add(a);
    }

    return Column(
      children: [
        _SearchBar(
          hint: AppLocalizations.of(context).qaSearchAccounts,
          onChanged: (v) {
            setState(() => _query = v);
            // The now-unfiltered list is longer; the old offset belonged to a
            // shorter one, so return to the top when the query empties.
            if (v.isEmpty && widget.controller.hasClients) {
              widget.controller.jumpTo(0);
            }
          },
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.sm,
              Insets.gutter,
              Insets.xxl,
            ),
            children: [
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                  child: Text(
                    AppLocalizations.of(context).qaNoAccountMatch(_query),
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ),
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, Insets.md, 4, Insets.sm),
                  child: Text(
                      entry.key.label(AppLocalizations.of(context)).toUpperCase(),
                      style: AppText.label),
                ),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0) const RowDivider(indent: Insets.md),
                        _pickRow(
                          context,
                          icon: entry.value[i].displayIcon,
                          color: entry.value[i].color,
                          title: entry.value[i].name,
                          // Spec 3.2 — the current balance is previewed on the
                          // right so the user picks with context.
                          trailing: AmountText(
                            store.balanceOf(entry.value[i].id),
                            currency: entry.value[i].currency,
                            style: AppText.amount.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(entry.value[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Spec 4.1 — category picker. A 3-column grid; its create action is the last
/// cell of the grid (§3).
Future<Category?> pickCategory(
  BuildContext context, {
  required CategoryType type,
  String? title,
  String? selectedId,
}) {
  return showAppSheet<Category>(
    context,
    title: title ??
        (type == CategoryType.expense
            ? AppLocalizations.of(context).qaExpenseCategory
            : AppLocalizations.of(context).qaIncomeCategory),
    builder: (context, controller) => _CategoryPickerBody(
        controller: controller, type: type, selectedId: selectedId),
  );
}

class _CategoryPickerBody extends StatefulWidget {
  const _CategoryPickerBody({
    required this.controller,
    required this.type,
    this.selectedId,
  });

  final ScrollController controller;
  final CategoryType type;

  /// The transaction's current category, highlighted in the grid when supplied.
  final String? selectedId;

  @override
  State<_CategoryPickerBody> createState() => _CategoryPickerBodyState();
}

class _CategoryPickerBodyState extends State<_CategoryPickerBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _query.trim().toLowerCase();
    final items = store
        .categoriesOfType(widget.type)
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();

    return Column(
      children: [
        _SearchBar(
          hint: AppLocalizations.of(context).qaSearchCategories,
          onChanged: (v) {
            setState(() => _query = v);
            // The now-unfiltered grid is taller; drop back to the top when the
            // query empties so the user isn't left scrolled into the middle.
            if (v.isEmpty && widget.controller.hasClients) {
              widget.controller.jumpTo(0);
            }
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.controller,
            // No spent/budget figures here — this is a picker; budget progress
            // lives on the Planner tab (§2).
            padding:
                const EdgeInsets.fromLTRB(14, Insets.md, 14, Insets.xxl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const columns = 3;
                const gap = 8.0;
                final cellWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.md),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            AppLocalizations.of(context).qaNoCategoryMatch(_query),
                            textAlign: TextAlign.center,
                            style: AppText.caption,
                          ),
                        ),
                      ),
                    // Wrap, not a stretched grid: a partial last row stays
                    // left-aligned and cells never stretch to fill it (§5).
                    Wrap(
                      spacing: gap,
                      runSpacing: 10,
                      children: [
                        for (final c in items)
                          SizedBox(
                            width: cellWidth,
                            child: _CategoryCell(
                              category: c,
                              selected: c.id == widget.selectedId,
                              onTap: () => Navigator.of(context).pop(c),
                            ),
                          ),
                        SizedBox(
                          width: cellWidth,
                          child: _NewCategoryCell(
                            onTap: () async {
                              final created = await showNewCategorySheet(
                                  context,
                                  type: widget.type);
                              if (created != null && context.mounted) {
                                Navigator.of(context).pop(created);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// One category in the picker grid (§3): a 46pt colour-tinted tile above a
/// two-line, centred label. The selected cell is filled with the colour, its
/// glyph white with a 2pt white ring, and its label white at weight 600.
class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected
                    ? category.color
                    : Color.alphaBlend(
                        category.color.withValues(alpha: 0.18),
                        AppColors.surfaceAlt),
                borderRadius: BorderRadius.circular(13),
                border:
                    selected ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: Icon(
                category.icon,
                size: 22,
                color: selected ? Colors.white : category.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: selected ? Colors.white : AppColors.sheetAccountName,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The create cell, last in the grid (§3): a dashed accent tile + "New".
class _NewCategoryCell extends StatelessWidget {
  const _NewCategoryCell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).qaNewCategory,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: _DashedRRectPainter(
                color: AppColors.accent,
                radius: 13,
                strokeWidth: 1.5,
              ),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.sheetCard,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 22, color: AppColors.accentLight),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).qaNewShort,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: AppColors.accentLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Strokes a dashed rounded rectangle — Flutter has no dashed border built in.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth,
          size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

Widget _pickRow(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  Widget? trailing,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          IconTile(icon, color: color, size: 32),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              title,
              style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

/// The create affordance, moved into the picker's header row (spec §1/§4).
/// A text button — `+ New …` in accent — with a ≥44 pt hit area that extends
/// above and below the visible text. It opens the create sheet *over* the
/// picker and, on success, pops the picker with the created item selected.
class _HeaderCreateAction<T> extends StatelessWidget {
  const _HeaderCreateAction({required this.label, required this.onCreate});

  final String label;
  final Future<T?> Function(BuildContext) onCreate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () async {
          final created = await onCreate(context);
          if (created != null && context.mounted) {
            Navigator.of(context).pop(created);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('+',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    )),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  // Owned here so the clear button can empty the field programmatically; the
  // parent still learns of every change through [widget.onChanged].
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    // Clearing is a correction, not an exit: empty the query and let the
    // results spring back, but do not close the sheet and do not touch focus —
    // leaving it untouched keeps an open keyboard open and a closed one closed.
    _controller.clear();
    widget.onChanged('');
    SemanticsService.sendAnnouncement(
      View.of(context),
      AppLocalizations.of(context).qaSearchCleared,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                style: AppText.body,
                cursorColor: AppColors.accentSoft,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),
            // Clear button — mounted only while the query is non-empty, so a
            // screen reader never meets a present-but-hidden glyph. Whitespace
            // counts as non-empty on purpose. As a Row sibling it reserves its
            // own width, so a long query ellipsizes rather than sliding under.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return Semantics(
                  button: true,
                  label: AppLocalizations.of(context).qaClearSearch,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _clear,
                    child: const SizedBox(
                      width: 44,
                      height: double.infinity,
                      child: Center(
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contextual create: New Category (spec 4.1) ──────────────────────────────

const _categoryIcons = <IconData>[
  Icons.shopping_basket_rounded,
  Icons.home_rounded,
  Icons.play_circle_rounded,
  Icons.local_shipping_rounded,
  Icons.shopping_bag_rounded,
  Icons.self_improvement_rounded,
  Icons.local_cafe_rounded,
  Icons.favorite_rounded,
  Icons.school_rounded,
  Icons.pets_rounded,
  Icons.flight_rounded,
  Icons.subscriptions_rounded,
];

Future<Category?> showNewCategorySheet(
  BuildContext context, {
  required CategoryType type,
  String initialName = '',
}) {
  return showAppSheet<Category>(
    context,
    title: AppLocalizations.of(context).qaNewCategory,
    initialSize: 0.85,
    builder: (context, controller) => _NewCategoryForm(
      controller: controller,
      type: type,
      initialName: initialName,
    ),
  );
}

class _NewCategoryForm extends StatefulWidget {
  const _NewCategoryForm({
    required this.controller,
    required this.type,
    required this.initialName,
  });

  final ScrollController controller;
  final CategoryType type;
  final String initialName;

  @override
  State<_NewCategoryForm> createState() => _NewCategoryFormState();
}

class _NewCategoryFormState extends State<_NewCategoryForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final _budget = TextEditingController();
  IconData _icon = _categoryIcons.first;
  Color _color = AppColors.categoryPalette.first;

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.only(bottom: Insets.lg),
            children: [
              FormSection(
                children: [
                  TextFieldRow(
                    icon: Icons.label_rounded,
                    label: AppLocalizations.of(context).qaCategoryName,
                    controller: _name,
                    hint: AppLocalizations.of(context).qaExampleCategory,
                    autofocus: widget.initialName.isEmpty,
                  ),
                ],
              ),
              SectionLabelSmall(AppLocalizations.of(context).qaIcon),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: AppCard(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Wrap(
                    spacing: Insets.md,
                    runSpacing: Insets.md,
                    children: [
                      for (final icon in _categoryIcons)
                        GestureDetector(
                          onTap: () => setState(() => _icon = icon),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: icon == _icon
                                  ? AppColors.tint(_color, 0.22)
                                  : AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: icon == _icon
                                  ? Border.all(color: _color, width: 1.5)
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: icon == _icon
                                  ? _color
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SectionLabelSmall(AppLocalizations.of(context).qaColour),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: AppCard(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final c in AppColors.categoryPalette)
                        GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: c == _color
                                  ? Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: c == _color
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              if (widget.type == CategoryType.expense)
                FormSection(
                  children: [
                    TextFieldRow(
                      icon: Icons.attach_money_rounded,
                      label: AppLocalizations.of(context).qaMonthlyBudget,
                      controller: _budget,
                      hint: '0',
                    ),
                  ],
                ),
              InfoNote(
                AppLocalizations.of(context).qaCategoryPlannerNote,
              ),
            ],
          ),
        ),
        _SheetFooter(
          label: AppLocalizations.of(context).qaCreateSelect,
          enabled: _valid,
          onPressed: () {
            final created = store.addCategory(
              name: _name.text.trim(),
              type: widget.type,
              icon: _icon,
              color: _color,
              monthlyBudget: double.tryParse(_budget.text.trim()),
            );
            Navigator.of(context).pop(created);
          },
        ),
      ],
    );
  }
}

// ── Contextual create: New Account (spec 4.2) ───────────────────────────────

Future<Account?> showNewAccountSheet(
  BuildContext context, {
  AccountGroup? initialGroup,
}) {
  return showAppSheet<Account>(
    context,
    title: AppLocalizations.of(context).qaNewAccount,
    initialSize: 0.85,
    builder: (context, controller) =>
        _NewAccountForm(controller: controller, initialGroup: initialGroup),
  );
}

class _NewAccountForm extends StatefulWidget {
  const _NewAccountForm({required this.controller, this.initialGroup});

  final ScrollController controller;

  /// Pre-selected when opened from a group's long-press (assets screen); null
  /// from the picker header, where nothing is selected initially (spec §5.3).
  final AccountGroup? initialGroup;

  @override
  State<_NewAccountForm> createState() => _NewAccountFormState();
}

class _NewAccountFormState extends State<_NewAccountForm> {
  final _name = TextEditingController();
  // A positive magnitude: the opening balance for an asset, or what is owed for
  // a liability. addAccount stores the liability version negative.
  final _balance = TextEditingController();
  final _limit = TextEditingController(); // Credit Cards
  final _paymentDay = TextEditingController(); // Bank Loans

  AccountGroup? _group; // nothing selected initially (spec §5.3)
  String _currency = Fx.baseCurrency;
  IconData? _icon;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _balance, _limit, _paymentDay]) {
      c.addListener(_onChanged);
    }
    if (widget.initialGroup != null) {
      _group = widget.initialGroup;
      _icon = defaultIconFor(widget.initialGroup!);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _balance, _limit, _paymentDay]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  bool get _isLiability => _group?.isLiability ?? false;

  bool get _limitValid {
    final t = _limit.text.trim();
    if (t.isEmpty) return true;
    final v = double.tryParse(t);
    return v != null && v > 0;
  }

  bool get _dayValid {
    final t = _paymentDay.text.trim();
    if (t.isEmpty) return true;
    final v = int.tryParse(t);
    return v != null && v >= 1 && v <= 31;
  }

  bool _duplicateName(AppStore store) {
    final n = _name.text.trim().toLowerCase();
    if (n.isEmpty) return false;
    return store.accounts.any((a) => a.name.trim().toLowerCase() == n);
  }

  bool _valid(AppStore store) {
    if (_name.text.trim().isEmpty || _group == null) return false;
    if (_duplicateName(store)) return false;
    if (_group == AccountGroup.creditCards && !_limitValid) return false;
    if (_group == AccountGroup.bankLoans && !_dayValid) return false;
    return true;
  }

  void _selectGroup(AccountGroup g) {
    setState(() {
      _group = g;
      // A default glyph is chosen the instant a group is picked; a later group
      // change keeps the chosen glyph if it still belongs, else swaps it (§5.5).
      final set = iconSuggestionsFor(g);
      if (_icon == null || !set.contains(_icon)) _icon = defaultIconFor(g);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final group = _group;
    final duplicate = _duplicateName(store);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.only(bottom: Insets.lg),
            children: [
              FormSection(
                children: [
                  TextFieldRow(
                    icon: Icons.drive_file_rename_outline_rounded,
                    label: AppLocalizations.of(context).qaAccountName,
                    controller: _name,
                    hint: AppLocalizations.of(context).qaExampleAccount,
                    autofocus: true,
                  ),
                ],
              ),
              if (duplicate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter + Insets.xs, 0, Insets.gutter, Insets.md),
                  child: Text(
                    AppLocalizations.of(context).qaAccountExists,
                    style: const TextStyle(fontSize: 12, color: AppColors.negative),
                  ),
                ),
              _groupList(AppLocalizations.of(context).qaAssets.toUpperCase(),
                  AccountGroup.assets),
              const SizedBox(height: Insets.md),
              _groupList(
                  AppLocalizations.of(context).qaLiabilities.toUpperCase(),
                  AccountGroup.liabilities),
              // The group drives everything below it; animate rows in and out
              // so the sheet never jumps (spec §5.4).
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: group == null
                    ? const SizedBox(width: double.infinity)
                    : _detailsAndIcon(group),
              ),
            ],
          ),
        ),
        _SheetFooter(
          label: AppLocalizations.of(context).qaCreateSelect,
          enabled: _valid(store),
          onPressed: () {
            final magnitude = double.tryParse(_balance.text.trim()) ?? 0;
            final created = store.addAccount(
              name: _name.text.trim(),
              group: group!,
              currency: _currency,
              // addAccount signs liabilities negative; the user types positive.
              startingBalance: magnitude,
              // Only the final group's fields are persisted (spec §5.4).
              creditLimit: group == AccountGroup.creditCards
                  ? double.tryParse(_limit.text.trim())
                  : null,
              paymentDue: group == AccountGroup.bankLoans
                  ? int.tryParse(_paymentDay.text.trim())
                  : null,
              icon: _icon,
            );
            Navigator.of(context).pop(created);
          },
        ),
      ],
    );
  }

  Widget _groupList(String label, List<AccountGroup> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 5),
          child: Semantics(
            header: true,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.07 * 10.5,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          decoration: BoxDecoration(
            color: AppColors.sheetCard,
            borderRadius: BorderRadius.circular(9),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0)
                  Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06)),
                _groupRow(groups[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupRow(AccountGroup g) {
    final selected = _group == g;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${g.label(AppLocalizations.of(context))}, ${g.isAsset ? AppLocalizations.of(context).qaAssets : AppLocalizations.of(context).qaLiabilities}',
      child: InkWell(
        onTap: () => _selectGroup(g),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          color: selected ? AppColors.accent.withValues(alpha: 0.16) : null,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: g.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  g.label(AppLocalizations.of(context)),
                  style: TextStyle(
                    fontSize: 13.5,
                    color:
                        selected ? Colors.white : AppColors.sheetAccountName,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.accentLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsAndIcon(AccountGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Insets.md),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          decoration: BoxDecoration(
            color: AppColors.sheetCard,
            borderRadius: BorderRadius.circular(11),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              FormRow(
                label: AppLocalizations.of(context).eaCurrency,
                value: _currency,
                showChevron: true,
                onTap: () async {
                  final picked = await pickCurrency(context, _currency);
                  if (picked != null) setState(() => _currency = picked);
                },
              ),
              _hair(),
              _amountRow(
                label: _isLiability ? AppLocalizations.of(context).qaAmountOwed : AppLocalizations.of(context).eaStartingBalance,
                controller: _balance,
                valueColor:
                    _isLiability ? AppColors.negative : AppColors.textPrimary,
              ),
              if (group == AccountGroup.creditCards) ...[
                _hair(),
                _amountRow(
                  label: AppLocalizations.of(context).eaCreditLimit,
                  controller: _limit,
                  valueColor: AppColors.textPrimary,
                  error: !_limitValid,
                ),
              ],
              if (group == AccountGroup.bankLoans) ...[
                _hair(),
                _amountRow(
                  label: AppLocalizations.of(context).qaPaymentDay,
                  controller: _paymentDay,
                  valueColor: AppColors.textPrimary,
                  showSymbol: false,
                  integer: true,
                  maxLength: 2,
                  error: !_dayValid,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 7, 18, 0),
          child: Text(
            _isLiability
                ? AppLocalizations.of(context).qaOwedHint
                : AppLocalizations.of(context).qaStartingBalanceHint,
            style: const TextStyle(
                fontSize: 11, height: 1.45, color: AppColors.textTertiary),
          ),
        ),
        if (group == AccountGroup.bankLoans)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: Text(
              AppLocalizations.of(context).qaPaymentDayHint,
              style: const TextStyle(
                  fontSize: 11, height: 1.45, color: AppColors.textTertiary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            AppLocalizations.of(context).qaIcon.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.07 * 10.5,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.gutter, 0, Insets.gutter, Insets.md),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                for (var i = 0; i < iconSuggestionsFor(group).length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  AccountGlyphTile(
                    icon: iconSuggestionsFor(group)[i],
                    color: group.color,
                    selected: _icon == iconSuggestionsFor(group)[i],
                    onTap: () =>
                        setState(() => _icon = iconSuggestionsFor(group)[i]),
                  ),
                ],
                const Spacer(),
                _gridButton(group),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridButton(AccountGroup group) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).qaMoreIcons,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final picked = await showIconPicker(context,
              color: group.color, selected: _icon);
          if (picked != null) setState(() => _icon = picked);
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.taskDim,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.grid_view_rounded,
              size: 18, color: AppColors.accentLight),
        ),
      ),
    );
  }

  Widget _hair() =>
      Container(height: 1, color: Colors.white.withValues(alpha: 0.07));

  Widget _amountRow({
    required String label,
    required TextEditingController controller,
    required Color valueColor,
    bool showSymbol = true,
    bool integer = false,
    int? maxLength,
    bool error = false,
  }) {
    final color = error ? AppColors.negative : valueColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14.5, color: AppColors.textPrimary)),
          ),
          if (showSymbol)
            Padding(
              padding: const EdgeInsets.only(right: 1),
              child: Text(currencySymbol(_currency),
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          SizedBox(
            width: 92,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: integer
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.]')),
                if (maxLength != null)
                  LengthLimitingTextInputFormatter(maxLength),
              ],
              cursorColor: AppColors.accent,
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, color: color),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> pickCurrency(BuildContext context, String current) {
  const codes = ['USD', 'EUR', 'TRY', 'TMT', 'GBP', 'JPY'];
  return showAppSheet<String>(
    context,
    title: AppLocalizations.of(context).eaCurrency,
    initialSize: 0.5,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < codes.length; i++) ...[
                if (i > 0) const RowDivider(indent: Insets.md),
                FormRow(
                  label: '${codes[i]}  ${currencySymbol(codes[i])}',
                  onTap: () => Navigator.of(context).pop(codes[i]),
                  trailing: codes[i] == current
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.accentSoft,
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Small uppercase label used inside sheets.
class SectionLabelSmall extends StatelessWidget {
  const SectionLabelSmall(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter + Insets.xs,
        Insets.sm,
        Insets.gutter,
        Insets.sm,
      ),
      child: Text(text.toUpperCase(), style: AppText.label),
    );
  }
}

/// Sticky primary action at the bottom of a sheet.
class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        Insets.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.surfaceHigh,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: AppText.button,
        ),
        child: Text(label),
      ),
    );
  }
}
