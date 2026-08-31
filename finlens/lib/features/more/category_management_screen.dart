import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/category_cell.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';
import 'edit_category_screen.dart';

/// More → Categories (§2). A grid, not a list: a category's identity is its icon
/// and colour, and a full-width row would spend 350 pt to carry a 46 pt tile and
/// one word.
///
/// Three sections — EXPENSE, INCOME, ARCHIVED — each its own `Wrap` of the shared
/// [CategoryCell]. EXPENSE and INCOME end with a [NewCategoryCell] whose type is
/// unambiguous from the section it sits in, which is why the header carries no
/// `+`. There is no transaction count anywhere here: that number moves to the
/// editor (§3), where it decides whether a category is archived or deleted.
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  /// Per-section one-way expansion, exactly as `trans_filter_sheet` truncation:
  /// a section is only ever added here, never removed. Balance's own comment
  /// gives the reason — one stray tap must not hide content for good.
  final Set<String> _expanded = <String>{};
  static const int _truncateAt = 8;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final expense = _sorted(store, store.categoriesOfType(CategoryType.expense));
    final income = _sorted(store, store.categoriesOfType(CategoryType.income));
    final archived = _sorted(store, store.archivedCategories);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: l.catManageTitle,
              showBack: true,
              showEye: false,
              showAdd: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _section(context, store, l,
                      key: 'expense',
                      title: l.catSectionExpense,
                      cats: expense,
                      createType: CategoryType.expense),
                  _section(context, store, l,
                      key: 'income',
                      title: l.catSectionIncome,
                      cats: income,
                      createType: CategoryType.income),
                  if (archived.isNotEmpty)
                    Opacity(
                      opacity: 0.45,
                      child: _section(context, store, l,
                          key: 'archived',
                          title: l.catSectionArchived,
                          cats: archived,
                          createType: null),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Insets.gutter, Insets.md, Insets.gutter, 0),
                    child: Text(
                      l.catArchiveFootnote,
                      style: AppText.caption.copyWith(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Order within a section: transaction count descending, then name. Seed
  /// authoring order means nothing to the user (§2.2).
  List<Category> _sorted(AppStore store, List<Category> cats) {
    final list = [...cats];
    list.sort((a, b) {
      final byCount = store
          .txnCountForCategory(b.id)
          .compareTo(store.txnCountForCategory(a.id));
      if (byCount != 0) return byCount;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Widget _section(
    BuildContext context,
    AppStore store,
    AppLocalizations l, {
    required String key,
    required String title,
    required List<Category> cats,
    required CategoryType? createType,
  }) {
    final expanded = _expanded.contains(key);
    final overflow = cats.length > _truncateAt && !expanded;
    final shown = overflow ? cats.take(_truncateAt).toList() : cats;
    final hidden = cats.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const columns = 3;
              const gap = 8.0;
              final cellWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: gap,
                    runSpacing: 10,
                    children: [
                      for (final c in shown)
                        SizedBox(
                          width: cellWidth,
                          child: CategoryCell(
                            category: c,
                            selected: false,
                            onTap: () => _openEdit(context, c),
                          ),
                        ),
                      if (createType != null)
                        SizedBox(
                          width: cellWidth,
                          child: NewCategoryCell(
                            onTap: () => _create(context, createType),
                          ),
                        ),
                    ],
                  ),
                  if (overflow)
                    // Same shape as the filter sheet's "+N more": one-way, so a
                    // stray tap never re-hides what it just revealed.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => setState(() => _expanded.add(key)),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5, left: 2),
                          child: Text(
                            l.plusNMore(hidden),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _openEdit(BuildContext context, Category category) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => EditCategoryScreen(categoryId: category.id),
      ),
    );
  }

  Future<void> _create(BuildContext context, CategoryType type) async {
    // Quick Add's own create sheet, its type fixed by the section (§2.1). The
    // return value is discarded here — a store notify rebuilds the grid.
    await showNewCategorySheet(context, type: type);
  }
}
