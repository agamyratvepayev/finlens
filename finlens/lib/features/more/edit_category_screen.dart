import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/icon_picker_sheet.dart';
import '../quick_add/pickers.dart';

/// More → Categories → a category (§3). The sibling of `edit_account_screen`:
/// read that first. A name, an icon and a colour are one form, not three
/// discrete actions, so this is a screen, not an action sheet.
///
/// The mode — live vs archived — is derived from `category.archived`, never from
/// a constructor flag: a screen that can be opened in the wrong mode eventually
/// will be.
class EditCategoryScreen extends StatefulWidget {
  const EditCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  late final AppStore _store = StoreScope.read(context);
  late final Category _category = _store.categoryById(widget.categoryId)!;

  late final TextEditingController _name =
      TextEditingController(text: _category.name);
  late IconData _icon = _category.icon;
  late Color _color = _category.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _archived => _category.archived;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final used = store.txnCountForCategory(_category.id) > 0;
    final typeLabel = _category.type == CategoryType.expense
        ? l.catSectionExpense
        : l.catSectionIncome;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header mirrors edit_account: Cancel · title · Save. An archived
            // category is read-only, so it has no Save.
            Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(l.actionCancel),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(l.catEditTitle, style: AppText.rowTitle),
                    ),
                  ),
                  if (_archived)
                    // Keeps the header balanced against the Cancel button.
                    const SizedBox(width: 64)
                  else
                    TextButton(
                      onPressed: _name.text.trim().isEmpty ? null : _save,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentSoft,
                        textStyle: AppText.button,
                      ),
                      child: Text(l.actionSave),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  FormSection(
                    children: [
                      if (_archived)
                        FormRow(
                          icon: Icons.label_rounded,
                          label: l.qaCategoryName,
                          value: _category.name,
                          enabled: false,
                        )
                      else
                        TextFieldRow(
                          icon: Icons.label_rounded,
                          label: l.qaCategoryName,
                          controller: _name,
                          trailing: const Icon(Icons.edit_rounded,
                              size: 16, color: AppColors.textTertiary),
                        ),
                      FormRow(
                        icon: Icons.category_rounded,
                        label: l.qaIcon,
                        enabled: !_archived,
                        trailing: IconTile(_icon, color: _color, size: 28),
                        onTap: _archived ? null : _pickIcon,
                      ),
                      FormRow(
                        icon: Icons.palette_rounded,
                        label: l.qaColour,
                        enabled: !_archived,
                        trailing: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        onTap: _archived ? null : _pickColour,
                      ),
                      // Type is locked, in either mode: flipping it would reverse
                      // every transaction already filed here (§3.1).
                      FormRow(
                        icon: Icons.swap_horiz_rounded,
                        label: l.ldgType,
                        value: typeLabel,
                        locked: true,
                        subtitle: l.catTypeLocked,
                      ),
                    ],
                  ),
                  if (_archived) ...[
                    _RestoreRow(
                      label: l.catRestoreThis,
                      onTap: () {
                        store.restoreCategory(_category);
                        Navigator.of(context).pop();
                      },
                    ),
                    if (!used)
                      DestructiveRow(
                        label: l.actionDeletePermanent,
                        onTap: () => _confirmDelete(store, l),
                      ),
                  ] else
                    DestructiveRow(
                      label: used ? l.catArchiveThis : l.catDeleteThis,
                      subtitle: used
                          ? l.catArchiveMsg(store.txnCountForCategory(_category.id))
                          : l.catDeleteMsg,
                      onTap: () =>
                          used ? _confirmArchive(store, l) : _confirmDelete(store, l),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIcon() async {
    final picked =
        await showCategoryIconPicker(context, color: _color, selected: _icon);
    if (picked != null) setState(() => _icon = picked);
  }

  /// The 6-swatch category palette, the same set `_NewCategoryForm` renders.
  Future<void> _pickColour() async {
    final picked = await showAppSheet<Color>(
      context,
      title: AppLocalizations.of(context).qaColour,
      initialSize: 0.35,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
            Insets.gutter, Insets.sm, Insets.gutter, Insets.xxl),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.md, vertical: Insets.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final c in AppColors.categoryPalette)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: c == _color
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: c == _color
                          ? const Icon(Icons.check_rounded,
                              size: 17, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _color = picked);
  }

  void _save() {
    _store.updateCategory(
      _category,
      name: _name.text.trim(),
      icon: _icon,
      color: _color,
    );
    Navigator.of(context).pop();
  }

  Future<void> _confirmArchive(AppStore store, AppLocalizations l) async {
    final count = store.txnCountForCategory(_category.id);
    final ok = await showDestructiveConfirm(
      context,
      title: _category.name,
      message: l.catArchiveMsg(count),
      impact: [ImpactLine.kept(l.arTxnStay)],
      confirmLabel: l.catArchiveThis,
    );
    if (!ok || !mounted) return;
    store.archiveCategory(_category);
    Navigator.of(context).pop();
  }

  /// Delete, guarded. A budgeted category is referenced by Planner, so it is
  /// refused outright (§3.2) — never a silent fall-back to Archive. The user is
  /// told why and pointed at the fix.
  Future<void> _confirmDelete(AppStore store, AppLocalizations l) async {
    if (store.monthlyBudgetForCategory(_category.id) != null) {
      await _showBudgetedRefusal(l);
      return;
    }
    final ok = await showDestructiveConfirm(
      context,
      title: _category.name,
      message: l.catDeleteMsg,
      impact: const [],
      confirmLabel: l.actionDeletePermanent,
    );
    if (!ok || !mounted) return;
    // deleteCategory re-checks txns and budget and returns false rather than
    // stranding history; the guards above make that path unreachable here.
    store.deleteCategory(_category);
    Navigator.of(context).pop();
  }

  Future<void> _showBudgetedRefusal(AppLocalizations l) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.xl, Insets.lg, Insets.xl, Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 26, color: AppColors.info),
              const SizedBox(height: Insets.md),
              Text(
                l.catDeleteBudgeted,
                style: AppText.body.copyWith(fontSize: 14, height: 1.35),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.lg),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  textStyle: AppText.button,
                ),
                child: Text(l.actionClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width restore action, shaped like [DestructiveRow] but in `accentSoft`
/// — restore reverses an archive and destroys nothing, so it must not read red.
class _RestoreRow extends StatelessWidget {
  const _RestoreRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.fromLTRB(
          Insets.gutter, 0, Insets.gutter, Insets.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.md, vertical: Insets.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(
                    fontSize: 14.5,
                    color: AppColors.accentSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
