import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../core/utils/search_fold.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/category_cell.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'account_icons.dart';
import 'icon_picker_sheet.dart';
import 'widgets/amount_hero.dart';

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
  // Optional dismissal guard (spec §5.2). When supplied it runs on Cancel,
  // scrim tap, system back, and swipe-down alike; returning false keeps the
  // sheet open. Callers that omit it (every existing sheet) are untouched.
  Future<bool> Function()? onDismiss,
  // When supplied, a muted Cancel affordance is rendered at the right end of
  // the title row (spec §5). It routes through [onDismiss] when present.
  String? cancelLabel,
  // When true the sheet hugs its content instead of opening at [initialSize]:
  // a `Column(mainAxisSize: .min)` whose body grows with what is in it and
  // scrolls once it hits the same max extent (account-picker spec §4).
  // DraggableScrollableSheet cannot size to content, so this takes a separate
  // layout path; every other caller keeps the draggable fraction-sized sheet
  // untouched.
  bool contentSized = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // A guarded sheet takes over its own drag-close (see [_AppSheetBody]);
    // disabling the outer BottomSheet drag removes its unguarded Navigator.pop
    // path, leaving the inner DraggableScrollableSheet as the single,
    // intercepted swipe route. Unguarded sheets keep the default drag.
    enableDrag: onDismiss == null,
    builder: (context) {
      final media = MediaQuery.of(context);
      // Leave ≥44pt of barrier tappable below the status bar at full extent.
      final maxSize =
          ((media.size.height - media.padding.top - 44) / media.size.height)
              .clamp(0.5, 0.94);
      final initial = initialSize > maxSize ? maxSize : initialSize;
      return _AppSheetBody(
        title: title,
        actions: actions,
        builder: builder,
        initialSize: initial,
        maxSize: maxSize,
        onDismiss: onDismiss,
        cancelLabel: cancelLabel,
        contentSized: contentSized,
      );
    },
  );
}

/// The scrollable sheet scaffold: drag handle, title bar (with optional Cancel),
/// and body. Stateful only so a guarded sheet can own a
/// [DraggableScrollableController] and intercept the swipe-down close, which
/// showModalBottomSheet otherwise routes through a raw `Navigator.pop` that a
/// [PopScope] cannot catch.
class _AppSheetBody extends StatefulWidget {
  const _AppSheetBody({
    required this.title,
    required this.actions,
    required this.builder,
    required this.initialSize,
    required this.maxSize,
    this.onDismiss,
    this.cancelLabel,
    this.contentSized = false,
  });

  final String title;
  final List<Widget> actions;
  final Widget Function(BuildContext, ScrollController) builder;
  final double initialSize;
  final double maxSize;
  final Future<bool> Function()? onDismiss;
  final String? cancelLabel;
  final bool contentSized;

  @override
  State<_AppSheetBody> createState() => _AppSheetBodyState();
}

class _AppSheetBodyState extends State<_AppSheetBody> {
  DraggableScrollableController? _dragController;

  /// Owned only on the content-sized path (spec §4), where there is no
  /// DraggableScrollableSheet to hand the body a controller of its own.
  ScrollController? _contentController;

  /// Re-entrancy latch: the swipe listener can fire repeatedly at the minimum
  /// extent, and Cancel/scrim can race the confirmation sheet.
  bool _dismissing = false;

  bool get _guarded => widget.onDismiss != null;

  @override
  void initState() {
    super.initState();
    if (_guarded) _dragController = DraggableScrollableController();
    if (widget.contentSized) _contentController = ScrollController();
  }

  @override
  void dispose() {
    _dragController?.dispose();
    _contentController?.dispose();
    super.dispose();
  }

  Future<void> _attemptDismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    final navigator = Navigator.of(context);
    final allow = widget.onDismiss == null ? true : await widget.onDismiss!();
    if (!mounted) {
      _dismissing = false;
      return;
    }
    if (allow) {
      navigator.pop();
    } else {
      // Kept: if a downward drag shrank the sheet, restore a comfortable height
      // so the form the user chose to keep is fully visible again.
      final c = _dragController;
      if (c != null && c.isAttached && c.size < widget.initialSize) {
        c.animateTo(
          widget.initialSize,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      _dismissing = false;
    }
  }

  /// Drag handle and title row — shared verbatim by both the draggable and the
  /// content-sized paths so the chrome never drifts between them.
  List<Widget> _chrome() {
    final hasCancel = widget.cancelLabel != null;
    return [
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
              child: Text(
                widget.title,
                style: AppText.title.copyWith(fontSize: 19),
                // Only constrain wrapping when a Cancel could collide
                // with the title; unguarded sheets keep prior behavior.
                maxLines: hasCancel ? 1 : null,
                overflow: hasCancel ? TextOverflow.ellipsis : null,
              ),
            ),
            ...widget.actions,
            if (hasCancel)
              _SheetCancelButton(
                label: widget.cancelLabel!,
                onTap: _attemptDismiss,
              ),
          ],
        ),
      ),
    ];
  }

  /// Content-sized presentation (spec §4): the sheet hugs its content and only
  /// scrolls once it reaches the same max extent the draggable path caps at.
  /// The body is [Flexible] so short states stay short and long lists scroll.
  Widget _buildContentSized(BuildContext context) {
    final media = MediaQuery.of(context);
    // Sit above the keyboard, and never taller than the space that leaves ≥44pt
    // of barrier tappable below the status bar. Subtracting the keyboard inset
    // here (and padding for it below) keeps the search field and a row visible
    // when the keyboard is open on a small device (§7).
    final maxHeight = (media.size.height -
            media.viewInsets.bottom -
            media.padding.top -
            44)
        .clamp(0.0, media.size.height);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._chrome(),
              Flexible(child: widget.builder(context, _contentController!)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contentSized) return _buildContentSized(context);
    return DraggableScrollableSheet(
      controller: _dragController,
      initialChildSize: widget.initialSize,
      minChildSize: 0.4,
      maxChildSize: widget.maxSize,
      expand: false,
      // Guarded sheets intercept the min-extent close in the notification
      // listener below so it can route through the discard confirmation.
      shouldCloseOnMinExtent: !_guarded,
      builder: (context, controller) {
        Widget sheet = Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
          ),
          child: Column(
            children: [
              ..._chrome(),
              Expanded(child: widget.builder(context, controller)),
            ],
          ),
        );

        if (_guarded) {
          sheet = NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              // A downward drag settling at the minimum extent is the swipe
              // dismissal; route it through the same guard as Cancel (§5.2).
              if (n.extent <= n.minExtent + 0.0001) _attemptDismiss();
              return false;
            },
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                // Scrim tap and system back both arrive here via maybePop.
                _attemptDismiss();
              },
              child: sheet,
            ),
          );
        }
        return sheet;
      },
    );
  }
}

/// The muted header Cancel affordance (spec §5): a text button — never the
/// accent colour, so it does not compete with the primary action — with a
/// ≥44pt tap target reaching into the title row's right gutter.
class _SheetCancelButton extends StatelessWidget {
  const _SheetCancelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
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
  // The account set cannot change while this modal is up (the only path that
  // creates one pops the sheet), so the state 1 / 2-4 split is fixed at open.
  // With no accounts to offer, the "+ New account" header action disappears and
  // the create affordance moves into the empty state's body instead (spec §2).
  final store = StoreScope.read(context);
  final hasAccounts = store.visibleAccounts
      .where((a) => a.id != excludeId)
      .where((a) => filter?.call(a) ?? true)
      .isNotEmpty;
  final l = AppLocalizations.of(context);
  return showAppSheet<Account>(
    context,
    title: title ?? l.qaSelectAccount,
    // An accessible, labelled dismissal (spec §6) — the picker previously had
    // only the drag handle. Matches the New account sheet's Cancel exactly;
    // with nothing to discard it simply pops.
    cancelLabel: l.actionCancel,
    contentSized: true,
    actions: hasAccounts
        ? [
            _HeaderCreateAction<Account>(
              label: l.qaNewAccount,
              // Do not prefill the name from the picker's search query (§3).
              onCreate: (ctx) => showNewAccountSheet(ctx),
            ),
          ]
        : const [],
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
    final l = AppLocalizations.of(context);

    // The list this sheet draws from, before any query. Empty here means the
    // store has nothing to offer — state 1 — which is a different thing from a
    // query that matched nothing, and the two must never be confused (§1).
    final source = store.visibleAccounts
        .where((a) => a.id != widget.excludeId)
        .where((a) => widget.filter?.call(a) ?? true)
        .toList();

    // State 1: no accounts at all. No search field, no header action, no
    // keyboard — just the title and an empty state whose button is the sole
    // create affordance (§2). Not scrollable: there is nothing to scroll (§4).
    if (source.isEmpty) return _emptyState(context, l);

    final rawQuery = _query.trim();
    final hasQuery = rawQuery.isNotEmpty;
    final q = rawQuery.toLowerCase();
    final matches = source
        .where((a) => !hasQuery || a.name.toLowerCase().contains(q))
        .toList();

    final grouped = <AccountGroup, List<Account>>{};
    for (final a in matches) {
      grouped.putIfAbsent(a.group, () => []).add(a);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SearchBar(
          hint: l.qaSearchAccounts,
          onChanged: (v) {
            setState(() => _query = v);
            // The now-unfiltered list is longer; the old offset belonged to a
            // shorter one, so return to the top when the query empties.
            if (v.isEmpty && widget.controller.hasClients) {
              widget.controller.jumpTo(0);
            }
          },
        ),
        Flexible(
          child: ListView(
            controller: widget.controller,
            // shrinkWrap so a short list keeps the sheet short (§4); the outer
            // Flexible caps it and it scrolls once the list outgrows the sheet.
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.sm,
              Insets.gutter,
              Insets.xxl,
            ),
            children: [
              // State 4 — and ONLY state 4: accounts exist, a real query was
              // typed, and it matched nothing. An empty/whitespace query can
              // never reach here (§1, §7).
              if (hasQuery && matches.isEmpty) _noMatchLine(context, l, rawQuery),
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, Insets.md, 4, Insets.sm),
                  child: Text(entry.key.label(l).toUpperCase(),
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

  /// State 1 body (§2, §5): a heading, a direction-neutral line, and a
  /// full-weight filled primary button — the only control in the sheet.
  Widget _emptyState(BuildContext context, AppLocalizations l) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.xxl,
        Insets.lg,
        Insets.xxl,
        Insets.xl + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.qaNoAccountsYet,
              style: AppText.rowTitle.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            l.qaNoAccountsYetBody,
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.xl),
          _EmptyStateCreateButton(
            label: l.qaNewAccount,
            onCreate: () => showNewAccountSheet(context),
          ),
        ],
      ),
    );
  }

  /// State 4's one line: no quotation marks, the query set off by the primary
  /// text colour against the message's secondary colour, trimmed, and held to a
  /// single ellipsised line so it never wraps or grows the sheet (§3).
  ///
  /// The query is a real l10n placeholder: a sentinel is interpolated through
  /// the localised template, then split back out so the query alone can be
  /// recoloured — this keeps working wherever the placeholder sits in a locale
  /// (Turkish leads with it, English and Russian trail).
  Widget _noMatchLine(BuildContext context, AppLocalizations l, String query) {
    const sentinel = '\u0000';
    final template = l.qaAccountSearchNoMatch(sentinel);
    final i = template.indexOf(sentinel);
    final before = i < 0 ? template : template.substring(0, i);
    final after = i < 0 ? '' : template.substring(i + sentinel.length);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xl),
        child: Text.rich(
          TextSpan(
            style: AppText.caption,
            children: [
              TextSpan(text: before),
              TextSpan(
                text: query,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              TextSpan(text: after),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// State 1's create action: a full-weight filled primary (spec §5), distinct
/// from the Balance zero-data screen's unfilled action on purpose — here it is
/// the sheet's only control, so nothing competes with it. On success it pops
/// the picker with the created account selected, exactly as the header action
/// does.
class _EmptyStateCreateButton extends StatelessWidget {
  const _EmptyStateCreateButton({required this.label, required this.onCreate});

  final String label;
  final Future<Account?> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final created = await onCreate();
        if (created != null && context.mounted) {
          Navigator.of(context).pop(created);
        }
      },
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        // ≥44pt tap target (§8); horizontal padding keeps it content-width, not
        // stretched edge to edge.
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: Insets.xxl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        textStyle: AppText.button,
      ),
      child: Text(label),
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
                            child: CategoryCell(
                              category: c,
                              selected: c.id == widget.selectedId,
                              onTap: () => Navigator.of(context).pop(c),
                            ),
                          ),
                        SizedBox(
                          width: cellWidth,
                          child: NewCategoryCell(
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

/// New Budget's category picker (§3). Deliberately *not* [pickCategory]: it
/// lists only expense categories that carry no budget — including ones with no
/// spending this month, which is the whole point of the flow — shows this
/// month's spend beneath each as context (not a filter), and offers no
/// "New category" cell, since creating a category here is a non-goal. The
/// caller filters and sorts (spend descending, then name) and never opens this
/// on an empty list, so there is no empty state to render.
Future<Category?> pickBudgetCategory(
  BuildContext context, {
  required List<Category> candidates,
  required DateTime month,
}) {
  return showAppSheet<Category>(
    context,
    title: AppLocalizations.of(context).qaBudgetWhichCategory,
    builder: (context, controller) => _BudgetCategoryPickerBody(
      controller: controller,
      candidates: candidates,
      month: month,
    ),
  );
}

class _BudgetCategoryPickerBody extends StatelessWidget {
  const _BudgetCategoryPickerBody({
    required this.controller,
    required this.candidates,
    required this.month,
  });

  final ScrollController controller;
  final List<Category> candidates;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < candidates.length; i++) ...[
                if (i > 0) const RowDivider(indent: Insets.md),
                _budgetCategoryRow(context, store, l, candidates[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _budgetCategoryRow(
    BuildContext context,
    AppStore store,
    AppLocalizations l,
    Category c,
  ) {
    final spent = store.spentInCategory(c.id, month);
    final subtitle =
        spent > 0 ? l.qaThisMonthSpend(money(spent)) : l.qaNothingSpentYet;
    return InkWell(
      onTap: () => Navigator.of(context).pop(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        child: Row(
          children: [
            IconTile(c.icon, color: c.color, size: 36),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.formChevron,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _pickRow(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  Widget? trailing,
  required VoidCallback onTap,
}) {
  // Announce as a button (§6) without touching the row's dot, name, balance,
  // alignment or tap behaviour (hard boundary): the label is composed from the
  // row's own descendants.
  return Semantics(
    button: true,
    child: InkWell(
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
  final l = AppLocalizations.of(context);
  // The dirty-check lives on the form's state; the header Cancel and every
  // dismissal gesture reach it through this key (§5.1/§5.2).
  final formKey = GlobalKey<_NewAccountFormState>();
  return showAppSheet<Account>(
    context,
    title: l.qaNewAccount,
    initialSize: 0.85,
    cancelLabel: l.actionCancel,
    onDismiss: () async => await formKey.currentState?.confirmDiscard() ?? true,
    builder: (context, controller) => _NewAccountForm(
      key: formKey,
      controller: controller,
      initialGroup: initialGroup,
    ),
  );
}

class _NewAccountForm extends StatefulWidget {
  const _NewAccountForm({super.key, required this.controller, this.initialGroup});

  final ScrollController controller;

  /// Pre-selected when opened from a group's long-press (assets screen); null
  /// from the picker header, where nothing is selected initially (spec §5.3).
  final AccountGroup? initialGroup;

  @override
  State<_NewAccountForm> createState() => _NewAccountFormState();
}

class _NewAccountFormState extends State<_NewAccountForm> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();

  AccountGroup? _group; // nothing selected initially (spec §2)
  String _currency = Fx.baseCurrency;

  // The account glyph: an [_icon] OR an [_emoji], drawn on a tile tinted with
  // the chosen colour ([_colorValue]; null = follow the type). [_iconExplicit]
  // records whether the user picked deliberately, so a later type change swaps
  // only an untouched default (spec §7b).
  IconData? _icon;
  String? _emoji;
  int? _colorValue;
  bool _iconExplicit = false;

  // Starting balance and (type-specific) credit limit are held as the raw typed
  // strings the amount sheet drives; payment day is a 1..31 day-of-month.
  String _amountRaw = '';
  String _limitRaw = '';
  int? _paymentDay;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onChanged);
    final g = widget.initialGroup;
    if (g != null) {
      _group = g;
      _icon = defaultIconFor(g); // a default, not an explicit choice
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_onChanged);
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _isLiability => _group?.isLiability ?? false;

  /// True once the user has entered anything worth losing (spec §5.1). A form
  /// opened on a group starts with that group's default glyph, so neither the
  /// pre-selected group nor its default icon counts as dirty.
  bool get _isDirty {
    final g = _group;
    return _name.text.trim().isNotEmpty ||
        g != widget.initialGroup ||
        _amountRaw.isNotEmpty ||
        _limitRaw.isNotEmpty ||
        _paymentDay != null ||
        _iconExplicit;
  }

  /// Dismissal guard (spec §5.1): an untouched form closes silently; a filled
  /// one asks first, reusing the app's standard destructive confirmation.
  /// Returns true when the sheet may close.
  Future<bool> confirmDiscard() async {
    if (!_isDirty) return true;
    if (!mounted) return true;
    final l = AppLocalizations.of(context);
    return showDestructiveConfirm(
      context,
      title: l.qaDiscardTitle,
      message: l.qaDiscardBody,
      impact: const [],
      confirmLabel: l.qaDiscardConfirm,
      cancelLabel: l.dsKeepIt,
    );
  }

  bool _duplicateName(AppStore store) {
    final n = _name.text.trim().toLowerCase();
    if (n.isEmpty) return false;
    return store.accounts.any((a) => a.name.trim().toLowerCase() == n);
  }

  bool _valid(AppStore store) {
    if (_name.text.trim().isEmpty || _group == null) return false;
    if (_duplicateName(store)) return false;
    return true;
  }

  void _selectGroup(AccountGroup g) {
    setState(() {
      _group = g;
      // The default glyph follows the type until the user picks one explicitly
      // (spec §7b): only an untouched default is overwritten.
      if (!_iconExplicit) {
        _icon = defaultIconFor(g);
        _emoji = null;
      }
    });
  }

  /// The colour the account's glyph renders in: a freely-chosen [_colorValue] or
  /// the type's colour (spec §7b). Before a type is chosen it falls back to the
  /// accent so the tile is never colourless.
  Color get _glyphColor => _colorValue != null
      ? Color(_colorValue!)
      : (_group?.color ?? AppColors.accent);

  Future<void> _openIconPicker() async {
    final result = await showIconPicker(
      context,
      typeColor: _group?.color ?? AppColors.accent,
      colorValue: _colorValue,
      icon: _emoji == null ? _icon : null,
      emoji: _emoji,
    );
    if (result == null) return;
    setState(() {
      _iconExplicit = true;
      _colorValue = result.colorValue;
      if (result.emoji != null) {
        _emoji = result.emoji;
        _icon = null;
      } else {
        _icon = result.icon;
        _emoji = null;
      }
    });
  }

  /// Shows the keyboard on a tap anywhere in the name row, even when the field
  /// already holds focus — requestFocus is a no-op then, so a keyboard dismissed
  /// by a drag never returns without asking the platform directly (spec §8a).
  void _focusName() {
    if (!_nameFocus.hasFocus) _nameFocus.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  Future<void> _editBalance() async {
    final l = AppLocalizations.of(context);
    final result = await showAmountEntrySheet(
      context,
      title: _isLiability ? l.qaAmountOwed : l.eaStartingBalance,
      raw: _amountRaw,
      currency: _currency,
    );
    if (result != null) {
      setState(() {
        _amountRaw = result.raw;
        _currency = result.currency;
      });
    }
  }

  Future<void> _editLimit() async {
    final l = AppLocalizations.of(context);
    final result = await showAmountEntrySheet(
      context,
      title: l.eaCreditLimit,
      raw: _limitRaw,
      currency: _currency,
    );
    if (result != null) {
      setState(() {
        _limitRaw = result.raw;
        _currency = result.currency;
      });
    }
  }

  Future<void> _openTypeSheet() async {
    final picked = await showAccountTypeSheet(context, selected: _group);
    if (picked != null) _selectGroup(picked);
  }

  Future<void> _pickPaymentDay() async {
    final picked = await _showDayPicker(context, _paymentDay);
    if (picked != null) setState(() => _paymentDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final group = _group;
    final duplicate = _duplicateName(store);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.controller,
            // Bottom padding clears the footer so the last row is never flush
            // against it (§8b); the footer is a sibling below, not floating, so
            // it can never overlap content.
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.md, Insets.gutter, Insets.xl),
            children: [
              // Row 1 — name field whose leading tile IS the account glyph (§1).
              _nameRow(l),
              if (duplicate)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Insets.xs, Insets.sm, 0, 0),
                  child: Text(l.qaAccountExists,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.negative)),
                ),
              const SizedBox(height: Insets.lg),
              // Row 2 — the type row.
              _card([_typeRow(l)]),
              const SizedBox(height: Insets.lg),
              // Row 3 — starting balance + currency (and any type-specific rows).
              _card([
                _StartingBalanceRow(
                  label: _isLiability ? l.qaAmountOwed : l.eaStartingBalance,
                  raw: _amountRaw,
                  currency: _currency,
                  onTap: _editBalance,
                ),
                if (group == AccountGroup.creditCards) ...[
                  _hair(),
                  FormRow(
                    label: l.eaCreditLimit,
                    value: _limitRaw.isEmpty
                        ? '—'
                        : money(AmountEntry.value(_limitRaw),
                            currency: _currency, forceDecimals: true),
                    showChevron: true,
                    onTap: _editLimit,
                  ),
                ],
                if (group == AccountGroup.bankLoans) ...[
                  _hair(),
                  FormRow(
                    label: l.qaPaymentDay,
                    value: _paymentDay?.toString() ?? '—',
                    showChevron: true,
                    onTap: _pickPaymentDay,
                  ),
                ],
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.xs, Insets.sm, 0, 0),
                child: Text(
                  _isLiability ? l.qaOwedHint : l.qaStartingBalanceHint,
                  // Secondary, not the faintest tertiary: with the field no
                  // longer shouting, this is the main thing drawing attention
                  // to it (§3).
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
              if (group == AccountGroup.bankLoans)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Insets.xs, Insets.xs, 0, 0),
                  child: Text(l.qaPaymentDayHint,
                      style: const TextStyle(
                          fontSize: 11,
                          height: 1.45,
                          color: AppColors.textTertiary)),
                ),
            ],
          ),
        ),
        _SheetFooter(
          label: l.qaCreateSelect,
          enabled: _valid(store),
          onPressed: () {
            final created = store.addAccount(
              name: _name.text.trim(),
              group: group!,
              currency: _currency,
              // addAccount signs liabilities negative; the user enters positive.
              startingBalance: AmountEntry.value(_amountRaw),
              creditLimit:
                  group == AccountGroup.creditCards && _limitRaw.isNotEmpty
                      ? AmountEntry.value(_limitRaw)
                      : null,
              paymentDue:
                  group == AccountGroup.bankLoans ? _paymentDay : null,
              icon: _emoji == null ? _icon : null,
              emoji: _emoji,
              colorValue: _colorValue,
            );
            Navigator.of(context).pop(created);
          },
        ),
      ],
    );
  }

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _nameRow(AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sheetCard,
        borderRadius: BorderRadius.circular(11),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          _iconTile(l),
          const SizedBox(width: Insets.md),
          // Everything but the tile focuses the field (§1). The whole area is
          // one opaque tap target so a tap between the label and the field still
          // opens the keyboard.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _focusName,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.qaAccountName,
                      style: AppText.caption.copyWith(fontSize: 11.5)),
                  TextField(
                    controller: _name,
                    focusNode: _nameFocus,
                    autofocus: true,
                    style: AppText.body.copyWith(fontSize: 15),
                    cursorColor: AppColors.accentSoft,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(top: 2),
                      hintText: l.qaExampleAccount,
                      hintStyle:
                          const TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The leading tile of the name row — the account's glyph, tappable, ≥44×44 pt,
  /// carrying a pencil badge so it reads as its own button (§1/§7b).
  Widget _iconTile(AppLocalizations l) {
    final color = _glyphColor;
    return Semantics(
      button: true,
      label: l.qaIcon,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openIconPicker,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        color.withValues(alpha: 0.18), AppColors.surfaceAlt),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: _emoji != null
                      ? Text(_emoji!, style: const TextStyle(fontSize: 20))
                      : Icon(_icon ?? Icons.account_balance_wallet_rounded,
                          size: 20, color: color),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(
                    color: AppColors.sheetCard,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.edit_rounded,
                      size: 9, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The type row (§2). Unselected shows `REQUIRED`; once a type is chosen the
  /// value slot holds the type's colour dot and name, and `REQUIRED` is gone.
  Widget _typeRow(AppLocalizations l) {
    final g = _group;
    return FormRow(
      label: l.naType,
      showChevron: true,
      onTap: _openTypeSheet,
      trailing: g == null
          ? Text(l.naRequired,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06 * 11,
                color: AppColors.textTertiary,
              ))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: g.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(g.label(l),
                    style: const TextStyle(
                        fontSize: 14.5, color: AppColors.textPrimary)),
              ],
            ),
    );
  }

  Widget _hair() =>
      Container(height: 1, color: Colors.white.withValues(alpha: 0.07));
}

/// The one-line example shown beneath each type in the account-type sheet
/// (spec §4). Recognition beats classification, so these are examples, not
/// definitions; two pairs are deliberately contrasted (debit vs credit card,
/// receivable vs payable) and must not drift into similarity.
String accountGroupDesc(AccountGroup g, AppLocalizations l) => switch (g) {
      AccountGroup.spendable => l.accountGroupSpendableDesc,
      AccountGroup.setAside => l.accountGroupSetAsideDesc,
      AccountGroup.receivables => l.accountGroupReceivablesDesc,
      AccountGroup.investments => l.accountGroupInvestmentsDesc,
      AccountGroup.valuables => l.accountGroupValuablesDesc,
      AccountGroup.creditCards => l.accountGroupCreditCardsDesc,
      AccountGroup.payables => l.accountGroupPayablesDesc,
      AccountGroup.bankLoans => l.accountGroupBankLoansDesc,
    };

/// The account-type sheet (spec §4): the two groups (ASSETS, LIABILITIES) with
/// the eight types in their current order, each with a one-line example. One tap
/// selects and closes; reopening shows a check on the selected row; nothing is
/// preselected on first open.
Future<AccountGroup?> showAccountTypeSheet(BuildContext context,
    {AccountGroup? selected}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<AccountGroup>(
    context,
    title: l.naAccountType,
    initialSize: 0.85,
    cancelLabel: l.actionCancel,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, 0, Insets.gutter, Insets.xxl),
      children: [
        _typeGroup(context, l.qaAssets, AccountGroup.assets, selected),
        const SizedBox(height: Insets.lg),
        _typeGroup(context, l.qaLiabilities, AccountGroup.liabilities, selected),
      ],
    ),
  );
}

Widget _typeGroup(BuildContext context, String label,
    List<AccountGroup> groups, AccountGroup? selected) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Insets.xs, 0, 0, Insets.sm),
        child: Semantics(
          header: true,
          child: Text(label.toUpperCase(), style: AppText.label),
        ),
      ),
      AppCard(
        child: Column(
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const RowDivider(indent: Insets.md),
              _AccountTypeRow(
                group: groups[i],
                selected: groups[i] == selected,
                onTap: () => Navigator.of(context).pop(groups[i]),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _AccountTypeRow extends StatelessWidget {
  const _AccountTypeRow(
      {required this.group, required this.selected, required this.onTap});

  final AccountGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.md, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: group.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(group.label(l),
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      accountGroupDesc(group, l),
                      // ≤ 2 lines in every locale (spec §4).
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: Insets.sm),
                  child: Icon(Icons.check_rounded,
                      size: 18, color: AppColors.accentSoft),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The starting-balance row (spec §3): the amount and currency read as one unit
/// — integer bright, decimals one step dimmer and contiguous, ~6 pt before the
/// currency code, the chevron against it. When the amount does not fit on one
/// line the row falls back to two lines (label above, amount below) rather than
/// ever truncating or shrinking the amount.
class _StartingBalanceRow extends StatelessWidget {
  const _StartingBalanceRow({
    required this.label,
    required this.raw,
    required this.currency,
    required this.onTap,
  });

  final String label;
  final String raw;
  final String currency;
  final VoidCallback onTap;

  static const _labelStyle =
      TextStyle(fontSize: 14.5, color: AppColors.textPrimary);
  static const _intStyle = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const _decStyle = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textTertiary);
  static const _codeStyle = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary);

  static String _groupDigits(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  static double _measure(String s, TextStyle style, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final def = currencyDef(currency);
    final v = AmountEntry.value(raw).abs();
    final wholeStr = _groupDigits(v.truncate().toString());
    String decStr = '';
    if (def.decimals > 0) {
      var factor = 1;
      for (var i = 0; i < def.decimals; i++) {
        factor *= 10;
      }
      final cents = (v * factor).round() % factor;
      decStr = '.${cents.toString().padLeft(def.decimals, '0')}';
    }

    final amount = Text.rich(
      TextSpan(children: [
        TextSpan(text: wholeStr, style: _intStyle),
        if (decStr.isNotEmpty) TextSpan(text: decStr, style: _decStyle),
      ]),
      textAlign: TextAlign.right,
      maxLines: 1,
      softWrap: false,
    );
    final code = Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(def.code, style: _codeStyle),
    );
    const chevron = Padding(
      padding: EdgeInsets.only(left: 2),
      child: Icon(Icons.chevron_right_rounded,
          size: 18, color: AppColors.textTertiary),
    );

    return Semantics(
      button: true,
      label: '$label ${money(AmountEntry.value(raw), currency: currency)}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.md, vertical: 9),
          child: LayoutBuilder(
            builder: (context, c) {
              final scaler = MediaQuery.textScalerOf(context);
              final labelW = _measure(label, _labelStyle, scaler);
              final amountW =
                  _measure(wholeStr + decStr, _intStyle, scaler);
              final codeW = _measure(def.code, _codeStyle, scaler) + 6;
              const chevronW = 20.0;
              // One line only if the label and the amount unit both fit with a
              // little breathing room between them (§3).
              final oneLine =
                  labelW + 16 + amountW + codeW + chevronW <= c.maxWidth;

              if (oneLine) {
                return Row(
                  children: [
                    Expanded(
                        child: Text(label,
                            style: _labelStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    amount,
                    code,
                    chevron,
                  ],
                );
              }
              // Two-line fallback — label above, the full amount below, never
              // truncated or shrunk (§3).
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: _labelStyle),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [Flexible(child: amount), code, chevron],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The starting-balance / amount sheet (spec §5). Reuses the app's own numeric
/// hero + keypad (the Quick Add amount field), adds a currency control that
/// opens the currency picker, and caps the integer part at 12 digits (enforced
/// by [AmountEntry]). Returns the raw amount string and the (possibly changed)
/// currency code.
Future<({String raw, String currency})?> showAmountEntrySheet(
  BuildContext context, {
  required String title,
  required String raw,
  required String currency,
  String? helper,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<({String raw, String currency})>(
    context,
    title: title,
    contentSized: true,
    cancelLabel: l.actionCancel,
    builder: (context, controller) =>
        _AmountEntrySheet(initialRaw: raw, initialCurrency: currency, helper: helper),
  );
}

class _AmountEntrySheet extends StatefulWidget {
  const _AmountEntrySheet(
      {required this.initialRaw, required this.initialCurrency, this.helper});

  final String initialRaw;
  final String initialCurrency;
  final String? helper;

  @override
  State<_AmountEntrySheet> createState() => _AmountEntrySheetState();
}

class _AmountEntrySheetState extends State<_AmountEntrySheet> {
  late String _raw = widget.initialRaw;
  late String _currency = widget.initialCurrency;

  void _press(String key) => setState(() => _raw = AmountEntry.press(_raw, key));
  void _back() => setState(() => _raw = AmountEntry.backspace(_raw));

  Future<void> _changeCurrency() async {
    final picked = await pickCurrency(context, _currency);
    if (picked != null) setState(() => _currency = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: Insets.sm),
        NumericHeroCard(
          label: '',
          raw: _raw,
          currency: _currency,
          accent: AppColors.accent,
          accentDim: AppColors.accent.withValues(alpha: 0.35),
          focused: true,
          onTap: () {},
          onCurrencyTap: _changeCurrency,
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter + Insets.xs, Insets.sm, Insets.gutter, 0),
            child: Text(widget.helper!,
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: Insets.sm),
        NumericKeypad(onKey: _press, onBackspace: _back),
        _SheetFooter(
          label: l.actionDone,
          onPressed: () =>
              Navigator.of(context).pop((raw: _raw, currency: _currency)),
        ),
      ],
    );
  }
}

/// A 1..31 day-of-month picker for a bank loan's payment day (spec: preserved
/// pre-existing field).
Future<int?> _showDayPicker(BuildContext context, int? current) {
  final l = AppLocalizations.of(context);
  return showAppSheet<int>(
    context,
    title: l.qaPaymentDay,
    initialSize: 0.6,
    builder: (context, controller) => GridView.count(
      controller: controller,
      crossAxisCount: 7,
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, 0, Insets.gutter, Insets.xxl),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (var d = 1; d <= 31; d++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(d),
            child: Container(
              decoration: BoxDecoration(
                color: d == current
                    ? AppColors.accent
                    : AppColors.sheetCard,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text('$d',
                  style: TextStyle(
                      fontSize: 14,
                      color: d == current
                          ? Colors.white
                          : AppColors.textPrimary)),
            ),
          ),
      ],
    ),
  );
}

/// The currency picker (spec §6). Search over ~180 built-in currencies plus any
/// the user has defined, a `RECENT` group of the codes already in use (omitted
/// when there are none), and a header `+ Add` that opens the Add-currency sheet
/// and — mirroring the account picker's create-and-select — selects the new
/// currency on success.
Future<String?> pickCurrency(BuildContext context, String current) {
  final l = AppLocalizations.of(context);
  return showAppSheet<String>(
    context,
    title: l.eaCurrency,
    initialSize: 0.85,
    cancelLabel: l.actionCancel,
    actions: [
      _HeaderCreateAction<String>(
        label: l.curAdd,
        onCreate: (ctx) => showAddCurrencySheet(ctx),
      ),
    ],
    builder: (context, controller) =>
        _CurrencyPickerBody(controller: controller, current: current),
  );
}

class _CurrencyPickerBody extends StatefulWidget {
  const _CurrencyPickerBody({required this.controller, required this.current});

  final ScrollController controller;
  final String current;

  @override
  State<_CurrencyPickerBody> createState() => _CurrencyPickerBodyState();
}

class _CurrencyPickerBodyState extends State<_CurrencyPickerBody> {
  String _query = '';

  /// The full catalog: user-defined currencies first (so a custom code shadows a
  /// built-in of the same code), then the built-ins, de-duplicated by code and
  /// sorted alphabetically — the `ALL CURRENCIES` ordering the spec asks for.
  List<CurrencyDef> _allCurrencies(AppStore store) {
    final byCode = <String, CurrencyDef>{};
    for (final c in kBuiltInCurrencies) {
      byCode[c.code] = c;
    }
    for (final c in store.snapshotCustomCurrencies) {
      byCode[c.code] = c;
    }
    final list = byCode.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return list;
  }

  bool _matches(CurrencyDef c, String q) {
    if (q.isEmpty) return true;
    final fold = foldSearch(q);
    return foldSearch(c.code).contains(fold) ||
        foldSearch(c.name).contains(fold);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final q = _query.trim();

    final recentCodes = _query.trim().isEmpty ? store.recentCurrencyCodes : const <String>[];
    final all = _allCurrencies(store).where((c) => _matches(c, q)).toList();

    return Column(
      children: [
        const SizedBox(height: Insets.sm),
        _SearchBar(
          hint: l.curSearch,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: Insets.md),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, 0, Insets.gutter, Insets.xxl),
            children: [
              if (recentCodes.isNotEmpty) ...[
                _CurrencyGroupLabel(l.curRecent),
                _currencyCard(
                    recentCodes.map(currencyDef).toList(), context),
                const SizedBox(height: Insets.lg),
              ],
              _CurrencyGroupLabel(l.curAll),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.xl),
                  child: Text(
                    l.curNoMatch(q),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textTertiary),
                  ),
                )
              else
                _currencyCard(all, context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _currencyCard(List<CurrencyDef> defs, BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < defs.length; i++) ...[
            if (i > 0) const RowDivider(indent: Insets.md),
            _CurrencyRow(
              def: defs[i],
              selected: defs[i].code == widget.current,
              onTap: () => Navigator.of(context).pop(defs[i].code),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrencyGroupLabel extends StatelessWidget {
  const _CurrencyGroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xs, 0, 0, Insets.sm),
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: AppText.label),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow(
      {required this.def, required this.selected, required this.onTap});

  final CurrencyDef def;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Code + name (spec §6), with the symbol as a muted trailing hint so the
    // token the user will see is visible before they commit.
    return FormRow(
      label: def.code,
      subtitle: def.name,
      value: def.tokenIsSymbol ? def.symbol : null,
      valueColor: AppColors.textTertiary,
      onTap: onTap,
      trailing: selected
          ? const Icon(Icons.check_rounded,
              size: 18, color: AppColors.accentSoft)
          : null,
    );
  }
}

/// The Add-currency sheet (spec §7a). Creates a user-defined currency — display
/// metadata only, never a rate (§10) — and returns its code so the picker can
/// select it. A duplicate code keeps `Add currency` disabled with an inline
/// error; an absent symbol falls back to the code, shown live in `Preview`.
Future<String?> showAddCurrencySheet(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showAppSheet<String>(
    context,
    title: l.curAddTitle,
    initialSize: 0.8,
    cancelLabel: l.actionCancel,
    builder: (context, controller) => _AddCurrencyForm(controller: controller),
  );
}

class _AddCurrencyForm extends StatefulWidget {
  const _AddCurrencyForm({required this.controller});
  final ScrollController controller;

  @override
  State<_AddCurrencyForm> createState() => _AddCurrencyFormState();
}

class _AddCurrencyFormState extends State<_AddCurrencyForm> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  bool _before = true;
  int _decimals = 2;

  @override
  void initState() {
    super.initState();
    for (final c in [_code, _name, _symbol]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _symbol]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _codeUp => _code.text.trim().toUpperCase();
  bool get _duplicate => _codeUp.isNotEmpty && currencyCodeExists(_codeUp);
  bool get _valid =>
      _codeUp.isNotEmpty && _name.text.trim().isNotEmpty && !_duplicate;

  CurrencyDef _def() => CurrencyDef(
        code: _codeUp,
        name: _name.text.trim(),
        symbol: _symbol.text.trim().isEmpty ? null : _symbol.text.trim(),
        decimals: _decimals,
        symbolBefore: _before,
        custom: true,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // At a large text scale two controls on one line stop fitting; the spec says
    // split them rather than compress (§7a). One breakpoint governs both rows.
    final split = MediaQuery.textScalerOf(context).scale(14) > 18;
    // Preview uses a fixed example so the shape (grouping, decimals, token side
    // and spacing) is legible before saving.
    final preview =
        formatCurrencyExample(_def().copyWith(code: _codeUp.isEmpty ? 'CUR' : _codeUp), 9850);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.sm, Insets.gutter, Insets.lg),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.sheetCard,
                  borderRadius: BorderRadius.circular(11),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _codeNameRow(l, split),
                    _hair(),
                    _symbolBeforeRow(l, split),
                    _hair(),
                    FormRow(
                      label: l.curDecimals,
                      value: '$_decimals',
                      showChevron: true,
                      onTap: _pickDecimals,
                    ),
                  ],
                ),
              ),
              if (_duplicate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.xs, Insets.sm, 0, 0),
                  child: Text(l.curCodeExists,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.negative)),
                ),
              const SizedBox(height: Insets.lg),
              // Preview row — reflects code, symbol, switch and decimals live.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.sheetCard,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Text(l.curPreview,
                        style: const TextStyle(
                            fontSize: 14.5, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(preview,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.xs, Insets.sm, 0, 0),
                child: Text(l.curInert,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.textTertiary)),
              ),
            ],
          ),
        ),
        _SheetFooter(
          label: l.curAddButton,
          enabled: _valid,
          onPressed: () {
            final store = StoreScope.read(context);
            final def = _def();
            store.addCustomCurrency(def);
            Navigator.of(context).pop(def.code);
          },
        ),
      ],
    );
  }

  Widget _hair() =>
      Container(height: 1, color: Colors.white.withValues(alpha: 0.07));

  /// Row 1 — Code (fixed ~78pt column) │ hairline │ Name (fills). Splits into
  /// two stacked rows at a large text scale (§7a).
  Widget _codeNameRow(AppLocalizations l, bool split) {
    final code = _miniField(
      label: l.curCode,
      controller: _code,
      formatters: [
        LengthLimitingTextInputFormatter(5),
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
        TextInputFormatter.withFunction((_, n) =>
            n.copyWith(text: n.text.toUpperCase())),
      ],
      textCapitalization: TextCapitalization.characters,
    );
    final name = _miniField(label: l.curName, controller: _name);
    if (split) {
      return Column(children: [code, _hair(), name]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 92, child: code),
          _hair(),
          Expanded(child: name),
        ],
      ),
    );
  }

  /// Row 2 — Symbol (fills) │ hairline │ Before amount switch. Splits at scale.
  Widget _symbolBeforeRow(AppLocalizations l, bool split) {
    final symbol = _miniField(
      label: l.curSymbolOptional,
      controller: _symbol,
      // The placeholder shows the current code so the fallback is visible
      // without a sentence explaining it (§7a).
      hint: _codeUp.isEmpty ? null : _codeUp,
    );
    final toggle = ToggleRow(
      label: l.curBeforeAmount,
      value: _before,
      onChanged: (v) => setState(() => _before = v),
    );
    if (split) {
      return Column(children: [symbol, _hair(), toggle]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: symbol),
          _hair(),
          SizedBox(width: 168, child: toggle),
        ],
      ),
    );
  }

  Widget _miniField({
    required String label,
    required TextEditingController controller,
    String? hint,
    List<TextInputFormatter>? formatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.caption.copyWith(fontSize: 11.5)),
          TextField(
            controller: controller,
            inputFormatters: formatters,
            textCapitalization: textCapitalization,
            style: AppText.body.copyWith(fontSize: 15),
            cursorColor: AppColors.accentSoft,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 2),
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDecimals() async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<int>(
      context,
      title: l.curDecimals,
      contentSized: true,
      builder: (context, controller) => ListView(
        controller: controller,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
            Insets.gutter, 0, Insets.gutter, Insets.xxl),
        children: [
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i <= 3; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  FormRow(
                    label: '$i',
                    onTap: () => Navigator.of(context).pop(i),
                    trailing: i == _decimals
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: AppColors.accentSoft)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _decimals = picked);
  }
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
