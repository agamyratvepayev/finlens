import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/search_fold.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/category_cell.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart' show SegmentedPicker;
import '../../shared/widgets/swipe_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
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
  // Caps how far the sheet may be dragged, as a screen fraction. Null keeps the
  // computed ceiling (window − status bar − 44pt barrier). A caller-supplied cap
  // only ever *lowers* that ceiling, never past the barrier rule. Only the
  // currency picker (§1) passes it today.
  double? maxSize,
  // When non-null the draggable sheet snaps to these fractions instead of
  // resting anywhere. Sanitised to (0.4, maxSize] before use. Only the currency
  // picker passes it (§1: snaps between its half-height and full-height); every
  // other sheet stays free-dragging.
  List<double>? snapSizes,
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
      final computedMax =
          ((media.size.height - media.padding.top - 44) / media.size.height)
              .clamp(0.5, 0.94);
      // A caller cap can only pull the ceiling down, never above the barrier rule.
      final resolvedMax =
          maxSize == null ? computedMax : math.min(maxSize, computedMax);
      final initial = initialSize > resolvedMax ? resolvedMax : initialSize;
      return _AppSheetBody(
        title: title,
        actions: actions,
        builder: builder,
        initialSize: initial,
        maxSize: resolvedMax,
        snapSizes: snapSizes,
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
    this.snapSizes,
    this.onDismiss,
    this.cancelLabel,
    this.contentSized = false,
  });

  final String title;
  final List<Widget> actions;
  final Widget Function(BuildContext, ScrollController) builder;
  final double initialSize;
  final double maxSize;
  final List<double>? snapSizes;
  final Future<bool> Function()? onDismiss;
  final String? cancelLabel;
  final bool contentSized;

  @override
  State<_AppSheetBody> createState() => _AppSheetBodyState();
}

class _AppSheetBodyState extends State<_AppSheetBody> {
  /// Owned on the draggable path (every non-`contentSized` sheet). A guarded
  /// sheet drives it to intercept the swipe-down close; the currency picker
  /// drives it to grow itself when search takes focus (§1.1). Exposed to the
  /// body through [_SheetDragScope].
  DraggableScrollableController? _dragController;

  /// Owned only on the content-sized path (spec §4), where there is no
  /// DraggableScrollableSheet to hand the body a controller of its own.
  ScrollController? _contentController;

  /// Re-entrancy latch: the swipe listener can fire repeatedly at the minimum
  /// extent, and Cancel/scrim can race the confirmation sheet.
  bool _dismissing = false;

  bool get _guarded => widget.onDismiss != null;

  /// The room the system navigation bar needs at the sheet's foot.
  ///
  /// The keyboard is `viewInsets`; the system navigation bar is `padding`. The
  /// sheet used to reserve only the first, so on an edge-to-edge device the
  /// last row of every picker was drawn under the nav bar — the account row
  /// was cut in half. The two are not additive: on Android `padding.bottom`
  /// usually collapses to 0 while the keyboard is up, and where it does not
  /// the keyboard already covers the bar — so only the part of the nav inset
  /// the keyboard leaves exposed is reserved, never both in full.
  double _navBarInset(MediaQueryData media) =>
      math.max(0.0, media.padding.bottom - media.viewInsets.bottom);

  @override
  void initState() {
    super.initState();
    // The draggable path always owns a controller now (guarded sheets need it to
    // intercept the close; the currency picker needs it to grow on search focus).
    if (!widget.contentSized) _dragController = DraggableScrollableController();
    if (widget.contentSized) _contentController = ScrollController();
  }

  /// Snap points sanitised into (0.4, maxSize], sorted and de-duplicated — a
  /// caller may pass a max above the barrier-clamped ceiling (0.95 vs a computed
  /// 0.94), and DraggableScrollableSheet asserts every snap sits within bounds.
  List<double>? get _snapSizes {
    final raw = widget.snapSizes;
    if (raw == null) return null;
    final out = <double>{};
    for (final s in raw) {
      final c = s.clamp(0.0, widget.maxSize);
      if (c > 0.4 && c <= widget.maxSize) {
        out.add(double.parse(c.toStringAsFixed(4)));
      }
    }
    if (out.isEmpty) return null;
    return out.toList()..sort();
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
          // Different type sizes on one line: align the letters, not the boxes.
          // Centring put a 19pt title's line box and a 44pt tap target on the
          // same midpoint, which left their baselines ~2px apart on device.
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
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
    final navBarInset = _navBarInset(media);
    // Sit above the keyboard and the navigation bar, and never taller than the
    // space that leaves ≥44pt of barrier tappable below the status bar.
    // Subtracting both insets here (and padding for them below) keeps the
    // search field and a row visible when the keyboard is open on a small
    // device (§7), and keeps the last row clear of the nav bar.
    final maxHeight = (media.size.height -
            media.viewInsets.bottom -
            navBarInset -
            media.padding.top -
            44)
        .clamp(0.0, media.size.height);
    return Padding(
      padding:
          EdgeInsets.only(bottom: media.viewInsets.bottom + navBarInset),
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
    // A plain Padding rather than folding the inset into maxChildSize: the
    // child sizes are fractions of whatever height the sheet is given, so
    // shrinking that height reserves the bar's room without touching the
    // fraction defaults or the 44pt barrier rule.
    final snaps = _snapSizes;
    final sheetBody = DraggableScrollableSheet(
      controller: _dragController,
      initialChildSize: widget.initialSize,
      minChildSize: 0.4,
      maxChildSize: widget.maxSize,
      expand: false,
      // Snap between the caller's sizes when asked (currency picker §1); free
      // dragging everywhere else.
      snap: snaps != null,
      snapSizes: snaps,
      // Guarded sheets intercept the min-extent close in the notification
      // listener below so it can route through the discard confirmation.
      shouldCloseOnMinExtent: !_guarded,
      builder: (context, controller) {
        // Expose the drag controller to the body so a body can grow the sheet
        // itself (§1.1). Sits above the builder's subtree so [_SheetDragScope
        // .maybeOf] resolves from inside it.
        Widget sheet = _SheetDragScope(
          controller: _dragController!,
          expandedSize: widget.maxSize,
          child: Container(
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
    return Padding(
      padding:
          EdgeInsets.only(bottom: _navBarInset(MediaQuery.of(context))),
      child: sheetBody,
    );
  }
}

/// Hands a sheet's [DraggableScrollableController] (and its full-height target)
/// down to the body, so a body can grow the sheet programmatically — the
/// currency picker's search field does this on focus (§1.1). Present only on the
/// draggable path; a `contentSized` sheet has no such controller and
/// [maybeOf] returns null, which every body treats as "cannot grow, stay put".
class _SheetDragScope extends InheritedWidget {
  const _SheetDragScope({
    required this.controller,
    required this.expandedSize,
    required super.child,
  });

  final DraggableScrollableController controller;
  final double expandedSize;

  static _SheetDragScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetDragScope>();

  @override
  bool updateShouldNotify(_SheetDragScope old) =>
      controller != old.controller || expandedSize != old.expandedSize;
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

/// Spec 4.2 — account picker. The `+ New` affordance lives in the header (right
/// of the title) and **stays there in every state**, exactly as [pickCategory]
/// does — reachable the instant the sheet opens, while a search is active, and
/// when there is nothing to list.
///
/// It used to move: with no accounts the header action disappeared and a filled
/// button took its place in the body, so the one action in the sheet jumped from
/// the middle to the top-right corner the moment the first account existed, and
/// changed shape and label on the way. One affordance, one place.
Future<Account?> pickAccount(
  BuildContext context, {
  String? title,
  bool Function(Account)? filter,
  String? excludeId,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<Account>(
    context,
    title: title ?? l.qaSelectAccount,
    // An accessible, labelled dismissal (spec §6) — the picker previously had
    // only the drag handle. Matches the New account sheet's Cancel exactly;
    // with nothing to discard it simply pops.
    cancelLabel: l.actionCancel,
    contentSized: true,
    actions: [
      _HeaderCreateAction<Account>(
        // "+ New", as the category picker shows. The sheet lists accounts and
        // its empty state says "No accounts yet", so the context is carried —
        // and the long label is where a locale overflows first, beside Cancel.
        label: l.qaNewShort,
        // …but a reader still hears the full name.
        semanticsLabel: l.qaNewAccount,
        // Do not prefill the name from the picker's search query (§3).
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

  /// State 1 body: a heading and a direction-neutral line. Nothing else.
  ///
  /// The filled primary button that used to close this Column is gone: the
  /// header's `+ New` is present in this state too now, so a second create
  /// control here would be the same action twice. No pointer sentence replaces
  /// it either — in a content-sized sheet the header sits ~40pt above this text
  /// and is in view at a glance, so describing it would be noise.
  Widget _emptyState(BuildContext context, AppLocalizations l) {
    // The navigation-bar inset is reserved by the sheet shell now; padding it
    // here as well would double the gap.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xxl,
        Insets.lg,
        Insets.xxl,
        Insets.xl,
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

/// Category picker (spec §1–§4). Mirrors [pickAccount]: `+ New` lives in the
/// header and stays there in every state, the sheet is sized to its content, the
/// grid is five columns ordered by use, and the search field appears only at ten
/// categories. Expense and income share this one widget — only the title and the
/// source list differ.
Future<Category?> pickCategory(
  BuildContext context, {
  required CategoryType type,
  /// The sides the sheet may offer (task 030). Empty or of length one (the
  /// default) is today's sheet, byte for byte: one title, one grid, no tab
  /// strip. Two entries put a tab strip above the grid and let the chosen side
  /// answer a question the caller would otherwise have to ask separately — for a
  /// scheduled task, picking `Salary` *is* saying the money comes in.
  List<CategoryType> types = const [],
  String? title,
  String? selectedId,
  /// Categories already taken elsewhere in the caller's set — rendered as
  /// chosen but dimmed, and not selectable. The Split sheet passes the
  /// categories its *other* lines hold: a split is a set, so one category
  /// cannot appear on two lines (spec §1a). Every other caller omits it.
  Set<String> usedIds = const {},
}) {
  final l = AppLocalizations.of(context);
  // The sides on offer. Anything but exactly-two collapses to the single seed
  // type, so every existing caller (which passes no `types`) is unchanged.
  final tabs = types.length >= 2 ? types : <CategoryType>[type];
  final twoSided = tabs.length >= 2;
  // The active side, shared between the header `+ New` (which creates INTO the
  // active side, §2) and the body (which swaps the grid). Seeded to `type`, so
  // the common case opens on the side the caller asked for and costs no tap. A
  // bare ValueNotifier with no attached listeners needs no disposal; the body
  // reads it through the widget, not a listenable, and it is GC'd with the sheet.
  final active = ValueNotifier<CategoryType>(type);
  return showAppSheet<Category>(
    context,
    // Two-sided: the sheet asks for a `Category`, full stop — the tab names the
    // side (§2). One-sided: today's per-type title. A caller title always wins.
    title: title ??
        (twoSided
            ? l.fieldCategory
            : (type == CategoryType.expense
                ? l.qaExpenseCategory
                : l.qaIncomeCategory)),
    // A labelled, accessible dismissal, matching the account picker.
    cancelLabel: l.actionCancel,
    contentSized: true,
    // The header `+ New` is present in ALL four states, never moving and never
    // hiding (spec §1) — including the empty state, whose body carries no button.
    // The category set cannot change while the modal is up (creating one pops the
    // sheet), so a single unconditional action is correct. [pickAccount] now does
    // the same; it used to drop this action when empty and show a body button
    // instead, and that divergence is gone.
    actions: [
      _HeaderCreateAction<Category>(
        label: l.qaNewShort,
        // Follows the active tab (§2): a sheet showing Income creates an income
        // category. A single-type sheet reads the fixed seed, exactly as before.
        onCreate: (ctx) => showNewCategorySheet(ctx, type: active.value),
      ),
    ],
    builder: (context, controller) => _CategoryPickerBody(
        controller: controller,
        tabs: tabs,
        active: active,
        selectedId: selectedId,
        usedIds: usedIds),
  );
}

class _CategoryPickerBody extends StatefulWidget {
  const _CategoryPickerBody({
    required this.controller,
    required this.tabs,
    required this.active,
    this.selectedId,
    this.usedIds = const {},
  });

  final ScrollController controller;

  /// The sides this sheet offers. One entry → no tab strip, today's sheet. Two
  /// → a tab strip above the grid (task 030 §2).
  final List<CategoryType> tabs;

  /// The active side, shared with the header `+ New` action. The body is the
  /// only writer; the header only reads it, at tap time.
  final ValueNotifier<CategoryType> active;

  /// The transaction's current category, highlighted in the grid when supplied.
  final String? selectedId;

  /// Categories taken by the caller's other lines: shown chosen-but-dimmed and
  /// not selectable (spec §1a).
  final Set<String> usedIds;

  @override
  State<_CategoryPickerBody> createState() => _CategoryPickerBodyState();
}

class _CategoryPickerBodyState extends State<_CategoryPickerBody> {
  String _query = '';

  static const _kColumns = 5;

  /// Ten is two full rows of the five-column grid: below it the whole set is
  /// visible at a glance and there is nothing to filter (spec §4). Tied to the
  /// column count — if [_kColumns] ever changes, this threshold moves with it.
  static const _kSearchThreshold = _kColumns * 2;

  CategoryType get _active => widget.active.value;
  bool get _twoSided => widget.tabs.length >= 2;

  /// Switches the active side (task 030 §2): the grid swaps in place, the search
  /// query and scroll reset to the top, and `contentSized` re-measures on the
  /// next layout so the sheet does not keep the taller side's height.
  void _selectTab(CategoryType type) {
    if (type == _active) return;
    setState(() {
      widget.active.value = type;
      _query = '';
    });
    if (widget.controller.hasClients) widget.controller.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    // The list this sheet draws from, before any query. Empty here is state 1 —
    // a different thing from a query that matched nothing, and the two must
    // never be confused (§1). Usage-ordered, ties newest-first (§3). In two-sided
    // mode this reads the ACTIVE tab, so the empty state belongs to the tab, not
    // the sheet (§2): an empty Income side still shows the tab strip above it.
    final source = store.categoriesOfTypeByUsage(_active);

    final showSearch = source.length >= _kSearchThreshold;
    final rawQuery = _query.trim();
    final hasQuery = rawQuery.isNotEmpty;
    final q = rawQuery.toLowerCase();
    final matches = source
        .where((c) => !hasQuery || c.name.toLowerCase().contains(q))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_twoSided) _tabStrip(context, l),
        if (source.isEmpty)
          _emptyState(context, l)
        else ...[
          if (showSearch)
            _SearchBar(
              hint: l.qaSearchCategories,
              onChanged: (v) {
                setState(() => _query = v);
                // The now-unfiltered grid is taller; drop back to the top when
                // the query empties so the user isn't left scrolled into the
                // middle.
                if (v.isEmpty && widget.controller.hasClients) {
                  widget.controller.jumpTo(0);
                }
              },
            ),
          Flexible(
            child: ListView(
              controller: widget.controller,
              // shrinkWrap so a short grid keeps the sheet short (§2); the outer
              // Flexible caps it and it scrolls once the grid outgrows the sheet.
              shrinkWrap: true,
              // No spent/budget figures here — this is a picker; budget progress
              // lives on the Planner tab (§2).
              padding: const EdgeInsets.fromLTRB(14, Insets.md, 14, Insets.xxl),
              children: [
                // State 4 — and ONLY state 4: categories exist, a real query was
                // typed, and it matched nothing. An empty/whitespace query can
                // never reach here (§1, §4).
                if (hasQuery && matches.isEmpty)
                  _noMatchLine(context, l, rawQuery),
                if (matches.isNotEmpty) _grid(context, matches),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The two-sided tab strip (task 030 §2): the app's segmented control, full
  /// width with `Insets.gutter` side margins, sitting directly above the grid.
  /// The chosen side is the task's direction — picking Income is saying the
  /// money comes in.
  Widget _tabStrip(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, Insets.sm, Insets.gutter, Insets.xs),
      child: SegmentedPicker<CategoryType>(
        values: widget.tabs,
        labelOf: (t) =>
            t == CategoryType.expense ? l.quickAddExpense : l.quickAddIncome,
        selected: _active,
        onChanged: _selectTab,
      ),
    );
  }

  /// The five-column grid (§2). Tiles are a fixed 54 pt; the leftover width is
  /// distributed into the gaps, so on a narrow device the gaps shrink and the
  /// tile does not (§9). No create tile — that action lives in the header — and
  /// no group headings (§3): the usage order carries the meaning.
  Widget _grid(BuildContext context, List<Category> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const tile = 54.0;
        final gap =
            ((constraints.maxWidth - tile * _kColumns) / (_kColumns - 1))
                .clamp(2.0, 16.0);
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [
            for (final c in items)
              SizedBox(
                width: tile,
                child: CategoryCell(
                  category: c,
                  selected: c.id == widget.selectedId ||
                      widget.usedIds.contains(c.id),
                  enabled: !widget.usedIds.contains(c.id),
                  tileSize: tile,
                  reserveTwoLines: true,
                  onTap: () => Navigator.of(context).pop(c),
                ),
              ),
          ],
        );
      },
    );
  }

  /// State 1 (§1): two lines of copy and no button. `+ New` is in the header,
  /// ~60 pt above this message, so a second control here would be the same
  /// action twice.
  Widget _emptyState(BuildContext context, AppLocalizations l) {
    // The navigation-bar inset is reserved by the sheet shell now; padding it
    // here as well would double the gap.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xxl,
        Insets.lg,
        Insets.xxl,
        Insets.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.qaNoCategoriesYet,
              style: AppText.rowTitle.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            // The sentence names the control literally, so it is composed from
            // the same localised `+ New` the header shows — never a hard-coded
            // string (spec §8 / §11).
            l.qaCategoryEmptyBody('+ ${l.qaNewShort}'),
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// State 4's one line (§4): no quotation marks, the query trimmed and set off
  /// by the primary text colour against the message's secondary colour, held to
  /// one ellipsised line so it never grows the sheet. Same technique as the
  /// account picker: a sentinel is interpolated through the localised template
  /// then split back out, so it works wherever the placeholder sits in a locale.
  Widget _noMatchLine(BuildContext context, AppLocalizations l, String query) {
    const sentinel = '\u0000';
    final template = l.qaNoCategoryMatch(sentinel);
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

/// New Budget's category picker (§1–§7). Deliberately *not* [pickCategory]: it
/// lists expense categories — including ones with no spending in the period,
/// which is the whole point of the flow — names the period's spend once over the
/// value column (not a per-row filter), and the caller filters and sorts (spend
/// descending, then name). Categories that already carry a budget are passed in
/// too and shown dimmed and unselectable, rather than hidden (spec §3c).
///
/// The sheet ALWAYS opens (§1): the caller no longer guards on an empty list.
/// With nothing to pick the body is a single empty block (§3) and the title-row
/// `New category` action (§2) is the way forward — present in both states, since
/// it is part of the sheet, not a recovery affordance for the empty case.
Future<Category?> pickBudgetCategory(
  BuildContext context, {
  required List<Category> candidates,
  required DateTime month,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<Category>(
    context,
    // The field's own name — the picker is no longer a step with its own title,
    // it fills the budget screen's Category row (spec §3b).
    title: l.fieldCategory,
    // Mirrors [pickAccount] (§2). `CategoryType.expense` is not a guess: the
    // candidate filter only ever offers expense categories, so an income one
    // created here could never be budgeted. `_HeaderCreateAction` pops the sheet
    // with the created category, so it flows straight back through this return
    // value and the caller pushes EditBudgetScreen for it with no extra code.
    actions: [
      _HeaderCreateAction<Category>(
        label: l.qaNewCategory,
        onCreate: (ctx) =>
            showNewCategorySheet(ctx, type: CategoryType.expense),
      ),
    ],
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

  /// The value column's right edge, expressed as an inset from the card's inner
  /// edge: the chevron box (18) + its 8pt gap + the row's [Insets.md] right
  /// padding. §5's month label shares this exact inset, so it sits directly over
  /// the figures it names. (§5's prose reads "18 + 8"; that omits the row's
  /// [Insets.md] padding — matching the true value edge requires including it.)
  static const double _valueInset = Insets.md + 18 + 8;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    // One empty block whatever the cause — no categories, all budgeted, or all
    // remaining ones having a removed budget (§3/§7). No branch on why, and no
    // button: the create action lives in the title row. Kept scrollable so it
    // still dismisses by drag and grows at large text scale.
    if (candidates.isEmpty) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.symmetric(vertical: Insets.xl),
        children: [
          EmptyState(
            icon: Icons.pie_chart_outline_rounded,
            iconBackdrop: true,
            titleAsHeader: true,
            title: l.qaBudgetNeedsCategory,
            message: l.qaBudgetNeedsCategoryMsg,
          ),
        ],
      );
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.xxl,
      ),
      children: [
        // §5 — one label row over the value column, the period's month in caps.
        // Right-aligned to the value column via [_valueInset], and part of the
        // scrollable content (not sticky). It renders only when the card does.
        Padding(
          padding: const EdgeInsets.only(
            right: _valueInset,
            top: Insets.xs,
            bottom: Insets.sm,
          ),
          child: Text(
            monthLong(month.month, l).toUpperCase(),
            style: AppText.label,
            textAlign: TextAlign.right,
          ),
        ),
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

  /// A single 48pt line (§4): icon, name, the period's spend right-aligned, and
  /// the chevron. A category that already carries a budget stays in the list but
  /// renders dimmed and inert (spec §3c) — hiding it would answer "where is
  /// Grocery?" with a blank. The height is a `minHeight` floor, not a hard box,
  /// so a normal row is 48pt yet grows at large text scale rather than clipping
  /// (§7).
  Widget _budgetCategoryRow(
    BuildContext context,
    AppStore store,
    AppLocalizations l,
    Category c,
  ) {
    if (store.monthlyBudgetForCategory(c.id) != null) {
      return _budgetedRow(l, c);
    }
    final spent = store.spentInCategory(c.id, month);
    // The period's spend, right-aligned and never shrinking. A confident $0
    // would be a claim rather than a blank, so zero renders as an em dash — the
    // same convention Balance uses on its own first run (§4).
    final value = Text(
      spent > 0 ? money(spent) : '—',
      style: AppText.amount.copyWith(
        color: spent > 0 ? AppColors.textSecondary : AppColors.textTertiary,
      ),
    );
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(c),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Row(
              children: [
                IconTile(c.icon, color: c.color, size: 30),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    c.name,
                    style:
                        AppText.rowTitle.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                value,
                const SizedBox(width: 8),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.formChevron,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A category that already carries a budget: kept in the list, dimmed, and
  /// unselectable (no `InkWell`, no chevron). The spend/chevron a live row shows
  /// give way to an `Already budgeted` reason — the row previously showed nothing
  /// for these categories (they were filtered out), so the reason is added, not
  /// replacing an existing figure. Announced with the reason so a screen reader
  /// hears why the row is inert, not merely that it is (spec §3c/§8).
  Widget _budgetedRow(AppLocalizations l, Category c) {
    return Semantics(
      enabled: false,
      excludeSemantics: true,
      label: '${c.name}, ${l.qaAlreadyBudgeted}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Row(
            children: [
              // The category colour, faded — the dim ramp (spec §3c).
              Opacity(
                opacity: 0.45,
                child: IconTile(c.icon, color: c.color, size: 30),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      c.name,
                      style: AppText.rowTitle.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l.qaAlreadyBudgeted,
                      style: AppText.caption.copyWith(
                        fontSize: 11.5,
                        color: AppColors.textQuaternary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a budget covers, chosen in one tabbed, multi-select sheet (spec 022 §1).
/// Three tabs — Categories, Accounts, Tags — each listing what the store has.
/// Selection is multi within a tab and **exclusive across tabs** (a budget has
/// one scope), so switching tabs with a selection made confirms before clearing.
/// Overlap with another budget is announced, never blocked (spec §1c). Returns
/// the chosen scope + target ids, or null if dismissed.
Future<({BudgetScope scope, Set<String> targets})?> pickBudgetTargets(
  BuildContext context, {
  BudgetScope initialScope = BudgetScope.categories,
  Set<String> initialTargets = const {},
}) {
  return showModalBottomSheet<({BudgetScope scope, Set<String> targets})>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _BudgetTargetsSheet(
      initialScope: initialScope,
      initialTargets: initialTargets,
    ),
  );
}

class _BudgetTargetsSheet extends StatefulWidget {
  const _BudgetTargetsSheet(
      {required this.initialScope, required this.initialTargets});

  final BudgetScope initialScope;
  final Set<String> initialTargets;

  @override
  State<_BudgetTargetsSheet> createState() => _BudgetTargetsSheetState();
}

class _BudgetTargetsSheetState extends State<_BudgetTargetsSheet> {
  late BudgetScope _scope = widget.initialScope;
  late final Set<String> _selected = {...widget.initialTargets};

  static const _scopes = [
    BudgetScope.categories,
    BudgetScope.account,
    BudgetScope.tag,
  ];

  String _tabLabel(AppLocalizations l, BudgetScope s) => switch (s) {
        BudgetScope.categories => l.bgTargets,
        BudgetScope.account => l.bgAccountsScope,
        BudgetScope.tag => l.bgTagsScope,
      };

  Future<void> _switchTo(BudgetScope s) async {
    if (s == _scope) return;
    if (_selected.isNotEmpty) {
      final l = AppLocalizations.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          title: Text(l.bgScopeSwitchTitle, style: AppText.rowTitle),
          content: Text(l.bgScopeSwitchMsg,
              style: AppText.body.copyWith(fontSize: 13.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary),
              child: Text(l.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.accentLight),
              child: Text(l.bgScopeSwitchConfirm),
            ),
          ],
        ),
      );
      if (ok != true) return;
      _selected.clear();
    }
    if (mounted) setState(() => _scope = s);
  }

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  /// The first already-budgeted selection, for the overlap note (spec §1c). A
  /// target already claimed by any *other* active budget — categories check every
  /// active category budget, accounts every active account budget, and so on.
  String? _overlapName(AppStore store) {
    for (final id in _selected) {
      final claimed = store.budgets.any((b) =>
          !b.isArchived &&
          !b.isFinished &&
          b.scope == _scope &&
          b.targets.contains(id));
      if (claimed) return _targetName(store, id);
    }
    return null;
  }

  String _targetName(AppStore store, String id) => switch (_scope) {
        BudgetScope.categories => store.categoryById(id)?.name ?? id,
        BudgetScope.account => store.accountById(id)?.name ?? id,
        BudgetScope.tag => store.tagById(id)?.name ?? id,
      };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final overlap = _overlapName(store);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.sm),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            // Title + Done.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.gutter, Insets.sm, Insets.sm, Insets.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.bgTargets,
                        style: AppText.title.copyWith(fontSize: 19)),
                  ),
                  // + New category — reuses the create sheet, but adds the result
                  // to the multi-selection rather than popping the picker (spec
                  // §1b). Only on the Categories tab.
                  if (_scope == BudgetScope.categories)
                    Semantics(
                      button: true,
                      label: l.qaNewCategory,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () async {
                          final created = await showNewCategorySheet(context,
                              type: CategoryType.expense);
                          if (created != null && mounted) {
                            setState(() => _selected.add(created.id));
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 10),
                            child: Text('+ ${l.qaNewShort}',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accentLight,
                                )),
                          ),
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context)
                            .pop((scope: _scope, targets: {..._selected})),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentLight),
                    child: Text(l.actionDone),
                  ),
                ],
              ),
            ),
            // Three tabs.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              child: Row(
                children: [
                  for (final s in _scopes)
                    Expanded(
                      child: _ScopeTab(
                        label: _tabLabel(l, s),
                        selected: s == _scope,
                        onTap: () => _switchTo(s),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
            Flexible(child: _tabBody(store, l)),
            if (overlap != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.bgOverlapNote(overlap),
                        style: AppText.caption.copyWith(
                            color: AppColors.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  Widget _tabBody(AppStore store, AppLocalizations l) {
    switch (_scope) {
      case BudgetScope.categories:
        final cats = store.categories
            .where((c) => c.type == CategoryType.expense && !c.archived)
            .toList();
        return _rows([
          for (final c in cats)
            (id: c.id, icon: c.icon, color: c.color, name: c.name, sub: null),
        ]);
      case BudgetScope.account:
        final accounts = store.visibleAccounts;
        return _rows([
          for (final a in accounts)
            (
              id: a.id,
              icon: a.displayIcon,
              color: a.color,
              name: a.name,
              sub: null
            ),
        ]);
      case BudgetScope.tag:
        final counts = store.tagUsageCounts();
        final tags = store.activeTags;
        return _rows([
          for (final t in tags)
            (
              id: t.id,
              icon: Icons.sell_rounded,
              color: AppColors.tagDot,
              name: '#${t.name}',
              sub: '${counts[t.id] ?? 0}'
            ),
        ]);
    }
  }

  Widget _rows(
      List<({String id, IconData icon, Color color, String name, String? sub})>
          items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Text(AppLocalizations.of(context).eaNotSet,
              style: AppText.caption.copyWith(color: AppColors.textSecondary)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        final on = _selected.contains(it.id);
        return Semantics(
          button: true,
          selected: on,
          child: InkWell(
            onTap: () => _toggle(it.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Row(
                  children: [
                    IconTile(it.icon, color: it.color, size: 30),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(it.name,
                          style: AppText.rowTitle
                              .copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (it.sub != null) ...[
                      Text(it.sub!,
                          style: AppText.caption
                              .copyWith(color: AppColors.textTertiary)),
                      const SizedBox(width: Insets.sm),
                    ],
                    Icon(
                      on
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: on ? AppColors.accentLight : AppColors.formChevron,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              color: selected ? AppColors.accentLight : Colors.transparent,
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
/// A text button — `+ New …` — with a ≥44 pt hit area that extends above and
/// below the visible text. It opens the create sheet *over* the picker and, on
/// success, pops the picker with the created item selected.
///
/// The ink is [AppColors.accentLight], not [AppColors.accent]. On the sheet's
/// `surfaceAlt` #1C1C1E ground the accent measures 3.36:1 — below WCAG AA's
/// 4.5:1 for 14.5pt text — while accentLight measures 7.52:1. All four pickers
/// draw this control on that same ground, so all four take the fix.
class _HeaderCreateAction<T> extends StatelessWidget {
  const _HeaderCreateAction({
    required this.label,
    required this.onCreate,
    this.semanticsLabel,
  });

  /// The visible text.
  final String label;

  /// What a screen reader announces, when it should differ from [label] — the
  /// account picker shortens the visible text to "New" but must still say
  /// "New account". Null keeps the two identical, as the other three pickers do.
  final String? semanticsLabel;

  final Future<T?> Function(BuildContext) onCreate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      // Without this the wrapper *merges* its children, so the node reads
      // "New account / + / New" — the glyph and the short text spoken after the
      // name. One button, one label.
      excludeSemantics: true,
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
                      color: AppColors.accentLight,
                    )),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentLight,
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
  const _SearchBar({
    required this.hint,
    required this.onChanged,
    this.onFocusChange,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  /// Fired when the field gains or loses focus. Only the currency picker passes
  /// it — to grow its half-height sheet when search begins (§1.1); the account
  /// and category pickers omit it and are unaffected.
  final ValueChanged<bool>? onFocusChange;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  // Owned here so the clear button can empty the field programmatically; the
  // parent still learns of every change through [widget.onChanged].
  final _controller = TextEditingController();

  /// Present only when a caller listens for focus; drives [_SearchBar
  /// .onFocusChange] so the currency sheet can grow on focus (§1.1).
  late final FocusNode? _focusNode =
      widget.onFocusChange == null ? null : FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode?.addListener(_onFocus);
  }

  void _onFocus() => widget.onFocusChange?.call(_focusNode!.hasFocus);

  @override
  void dispose() {
    _focusNode?.removeListener(_onFocus);
    _focusNode?.dispose();
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
                focusNode: _focusNode,
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

// ── Contextual create: New Category (spec §7) ───────────────────────────────

/// The new-category form (spec §7), opened by the picker's header `+ New`. The
/// direction is already known and never asked for — only the title, the helper
/// line and the created category's type differ between expense and income.
Future<Category?> showNewCategorySheet(
  BuildContext context, {
  required CategoryType type,
  String initialName = '',
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<Category>(
    context,
    title:
        type == CategoryType.expense ? l.qaNewExpenseCategory : l.qaNewIncomeCategory,
    contentSized: true,
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
  final _nameFocus = FocusNode();

  // The category glyph: an [_icon] OR an [_emoji], on a tile tinted with
  // [_color]. Defaults are the app's long-standing new-category defaults — the
  // shopping-basket icon and the first category-palette colour — until the user
  // opens the picker (spec §7).
  IconData? _icon = Icons.shopping_basket_rounded;
  String? _emoji;
  Color _color = AppColors.categoryPalette.first;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_onChanged);
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// A duplicate name in the SAME direction is rejected (spec §7): two categories
  /// with one name split every report that groups by category. An expense and an
  /// income category may still share a name.
  bool _duplicateName(AppStore store) {
    final n = _name.text.trim().toLowerCase();
    if (n.isEmpty) return false;
    return store
        .categoriesOfType(widget.type)
        .any((c) => c.name.trim().toLowerCase() == n);
  }

  bool _valid(AppStore store) =>
      _name.text.trim().isNotEmpty && !_duplicateName(store);

  Future<void> _openIconPicker() async {
    final result = await showIconPicker(
      context,
      typeColor: _color,
      colorValue: _color.toARGB32(),
      icon: _emoji == null ? _icon : null,
      emoji: _emoji,
    );
    if (result == null) return;
    setState(() {
      if (result.colorValue != null) _color = Color(result.colorValue!);
      if (result.emoji != null) {
        _emoji = result.emoji;
        _icon = null;
      } else {
        _icon = result.icon;
        _emoji = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final duplicate = _duplicateName(store);
    return Column(
      // Hug the content: the footer sits just below the fields (task 20).
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            controller: widget.controller,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.md, Insets.gutter, Insets.xl),
            children: [
              // One row: the name field with the icon tile as its leading control
              // — byte-for-byte the account form's pattern (spec §7).
              _nameRow(l),
              if (duplicate)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Insets.xs, Insets.sm, 0, 0),
                  child: Text(l.qaCategoryExists,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.negative)),
                ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Insets.xs, Insets.sm, 0, 0),
                child: Text(
                  widget.type == CategoryType.expense
                      ? l.qaCategoryExpenseHelper
                      : l.qaCategoryIncomeHelper,
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        _SheetFooter(
          label: l.qaCreateSelect,
          enabled: _valid(store),
          onPressed: () {
            final created = store.addCategory(
              name: _name.text.trim(),
              type: widget.type,
              icon: _icon ?? Icons.category_rounded,
              color: _color,
              emoji: _emoji,
            );
            Navigator.of(context).pop(created);
          },
        ),
      ],
    );
  }

  Widget _nameRow(AppLocalizations l) {
    // One name line (task 004): the glyph tile leads, the hint is the label. The
    // tile is a 44 pt hit target, so the row pins that height rather than growing
    // intrinsically — the editors, whose neighbours are shorter value rows, do
    // not (§2).
    return NameField(
      controller: _name,
      focusNode: _nameFocus,
      autofocus: true,
      hint: l.qaExampleCategory,
      semanticsLabel: l.qaCategoryName,
      surface: AppColors.sheetCard,
      radius: 11,
      fixedHeight: 48,
      leadingTile: NameGlyphTile(
        color: _color,
        onTap: _openIconPicker,
        semanticsLabel: l.qaIcon,
        icon: _icon,
        emoji: _emoji,
        fallbackIcon: Icons.category_rounded,
      ),
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

/// The two numeric rows the docked keypad can write to. A credit card shows
/// both; every other type shows only the balance.
enum _NumField { balance, limit }

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
  // Seeded in [initState] from the store's base currency. With no base set yet
  // (no accounts), that getter falls back to the device locale's currency
  // (spec §2b), so the very first account on a Turkmen device defaults to TMT
  // rather than the old hard-coded USD.
  late String _currency;

  // The account glyph: an [_icon] OR an [_emoji], drawn on a tile tinted with
  // the chosen colour ([_colorValue]; null = follow the type). [_iconExplicit]
  // records whether the user picked deliberately, so a later type change swaps
  // only an untouched default (spec §7b).
  IconData? _icon;
  String? _emoji;
  int? _colorValue;
  bool _iconExplicit = false;

  // Starting balance and (type-specific) credit limit are held as the raw typed
  // strings the docked keypad drives; payment day is a 1..31 day-of-month.
  String _amountRaw = '';
  String _limitRaw = '';
  int? _paymentDay;

  /// Which numeric row the docked keypad writes to; null = keypad closed.
  _NumField? _numFocus;

  @override
  void initState() {
    super.initState();
    _currency = StoreScope.read(context).baseCurrency;
    _name.addListener(_onChanged);
    _nameFocus.addListener(_onNameFocus);
    final g = widget.initialGroup;
    if (g != null) {
      _group = g;
      _icon = defaultIconFor(g); // a default, not an explicit choice
    }
  }

  void _onChanged() => setState(() {});

  /// The system keyboard and the keypad are never open together: the name
  /// field taking focus — however focus arrived — closes the keypad.
  void _onNameFocus() {
    if (_nameFocus.hasFocus && _numFocus != null) {
      setState(() => _numFocus = null);
    }
  }

  @override
  void dispose() {
    _name.removeListener(_onChanged);
    _nameFocus.removeListener(_onNameFocus);
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
      // A type switch can remove the credit-limit row from under the keypad;
      // focus falls back to the balance row and the keypad keeps working.
      if (g != AccountGroup.creditCards && _numFocus == _NumField.limit) {
        _numFocus = _NumField.balance;
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

  /// Focuses a numeric row: the accent outline and caret move to it, the
  /// docked keypad opens (or retargets) and keys land here. The system
  /// keyboard goes first — keypad and keyboard are never up together.
  void _focusNum(_NumField field) {
    _nameFocus.unfocus();
    if (_numFocus == field) return;
    setState(() => _numFocus = field);
    // A sighted user gets the outline; a screen reader is told which field
    // the keypad now feeds.
    SemanticsService.sendAnnouncement(
      View.of(context),
      _numLabel(field, AppLocalizations.of(context)),
      Directionality.of(context),
    );
  }

  String _numLabel(_NumField field, AppLocalizations l) => switch (field) {
        _NumField.balance => _isLiability ? l.qaAmountOwed : l.eaStartingBalance,
        _NumField.limit => l.eaCreditLimit,
      };

  void _pressKey(String key) {
    setState(() {
      switch (_numFocus) {
        case _NumField.balance:
          _amountRaw = AmountEntry.press(_amountRaw, key);
        case _NumField.limit:
          _limitRaw = AmountEntry.press(_limitRaw, key);
        case null:
          break;
      }
    });
  }

  void _backspace() {
    setState(() {
      switch (_numFocus) {
        case _NumField.balance:
          _amountRaw = AmountEntry.backspace(_amountRaw);
        case _NumField.limit:
          _limitRaw = AmountEntry.backspace(_limitRaw);
        case null:
          break;
      }
    });
  }

  Future<void> _changeCurrency() async {
    final picked = await pickCurrency(context, _currency);
    // The typed digits are kept and re-render in the new currency; the focused
    // row stays focused.
    if (picked != null && mounted) setState(() => _currency = picked);
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
              // The numeric rows are typed in place: a tap focuses the row and
              // the keypad docked at the sheet's foot writes to it (task 8).
              _card([
                _StartingBalanceRow(
                  label: _isLiability ? l.qaAmountOwed : l.eaStartingBalance,
                  raw: _amountRaw,
                  currency: _currency,
                  focused: _numFocus == _NumField.balance,
                  onTap: () => _focusNum(_NumField.balance),
                  onCurrencyTap: _changeCurrency,
                ),
                if (group == AccountGroup.creditCards) ...[
                  _hair(),
                  _StartingBalanceRow(
                    label: l.eaCreditLimit,
                    raw: _limitRaw,
                    currency: _currency,
                    focused: _numFocus == _NumField.limit,
                    onTap: () => _focusNum(_NumField.limit),
                    onCurrencyTap: _changeCurrency,
                  ),
                ],
                if (group == AccountGroup.bankLoans) ...[
                  _hair(),
                  FormRow(
                    label: l.qaPaymentDay,
                    value: _paymentDay?.toString() ?? '—',
                    showChevron: true,
                    // _pickPaymentDay raises a bottom sheet.
                    opensSheet: true,
                    onTap: _pickPaymentDay,
                  ),
                ],
              ]),
              // The starting-balance explainer ("Enter this once. From now on
              // the balance is calculated from your transactions.") is removed
              // by owner decision (More ▸ Accounts §4) — deliberately not
              // replaced by any hint, placeholder, tooltip or info icon. The
              // liability form keeps its own hint, which explains entering a
              // debt as a positive number — a different point this removal does
              // not touch.
              if (_isLiability)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Insets.xs, Insets.sm, 0, 0),
                  child: Text(
                    l.qaOwedHint,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary),
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
        if (_numFocus != null) ...[
          NumericKeypad(onKey: _pressKey, onBackspace: _backspace),
          // The home-indicator inset below the keys is the sheet shell's now.
          const SizedBox(height: Insets.sm),
        ],
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
    // One name line (task 004): the glyph tile leads, the hint is the label. The
    // tile is a 44 pt hit target, so the row pins that height rather than growing
    // intrinsically — the editors, whose neighbours are shorter value rows, do
    // not (§2).
    return NameField(
      controller: _name,
      focusNode: _nameFocus,
      autofocus: true,
      hint: l.qaExampleAccount,
      semanticsLabel: l.qaAccountName,
      surface: AppColors.sheetCard,
      radius: 11,
      fixedHeight: 48,
      leadingTile: NameGlyphTile(
        color: _glyphColor,
        onTap: _openIconPicker,
        semanticsLabel: l.qaIcon,
        icon: _icon,
        emoji: _emoji,
        fallbackIcon: Icons.account_balance_wallet_rounded,
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
      // _openTypeSheet raises the account-type bottom sheet.
      opensSheet: true,
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
    contentSized: true,
    cancelLabel: l.actionCancel,
    builder: (context, controller) => ListView(
      controller: controller,
      shrinkWrap: true,
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
          // Task 042: level with every label-and-value row at 48pt (was 44).
          constraints: const BoxConstraints(minHeight: 48),
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
                            fontSize: 14.5, color: AppColors.textPrimary)),
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

/// A focusable numeric row (task 8; layout from the starting-balance spec §3):
/// the amount and currency read as one unit — the typed digits grouped and
/// bright, the untyped decimal remainder one step dimmer *while typing* and
/// contiguous, ~6 pt before the currency code. A tap opens nothing: it focuses
/// the row, and the keypad docked at the sheet's foot writes here. Focus is
/// marked three ways at once so it never rests on colour alone: the accent
/// outline the old amount sheet drew around its own input, a caret after the
/// last typed digit, and the dimmed decimal padding. Once the row is filled and
/// unfocused that padding brightens too (task 11: pale means "not typed yet",
/// so a finished amount has no pale part). The currency code stays tappable and opens the
/// currency picker. When the amount does not fit on one line the row falls
/// back to two lines (label above, amount below) rather than ever truncating
/// or shrinking the amount.
class _StartingBalanceRow extends StatefulWidget {
  const _StartingBalanceRow({
    required this.label,
    required this.raw,
    required this.currency,
    required this.focused,
    required this.onTap,
    required this.onCurrencyTap,
  });

  final String label;
  final String raw;
  final String currency;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback onCurrencyTap;

  @override
  State<_StartingBalanceRow> createState() => _StartingBalanceRowState();
}

class _StartingBalanceRowState extends State<_StartingBalanceRow>
    with SingleTickerProviderStateMixin {
  /// Caret blink, same 1050 ms period as the Quick Add hero's. Runs only while
  /// the row holds focus so unfocused rows cost nothing.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  static const _labelStyle =
      TextStyle(fontSize: 14.5, color: AppColors.textPrimary);
  static const _codeStyle = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary);

  /// The number's glyph style at a given [color]. Both the typed digits and the
  /// decimal padding share one size and weight — only the colour differs, and
  /// only by state (task 11): pale is "not typed yet", never "this is a
  /// decimal".
  static TextStyle _numStyle(Color color) =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color);

  @override
  void initState() {
    super.initState();
    if (widget.focused) _blink.repeat();
  }

  @override
  void didUpdateWidget(_StartingBalanceRow old) {
    super.didUpdateWidget(old);
    if (widget.focused && !old.focused) _blink.repeat();
    if (!widget.focused && old.focused) _blink.stop();
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
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
    final def = currencyDef(widget.currency);
    final focused = widget.focused;
    final filled = widget.raw.isNotEmpty;
    final parts = AmountEntry.splitPlain(widget.raw, widget.currency);

    // Task 11: the typed digits are always bright; the untyped decimal padding
    // is dim only while the keypad is still writing here (or the field is
    // empty), and joins the number at full brightness once the row is filled
    // and unfocused. Pale means "not typed yet", not "these are decimals".
    final restColor = (filled && !focused)
        ? AppColors.textPrimary
        : AppColors.textTertiary;

    final amount = Text.rich(
      TextSpan(children: [
        if (parts.typed.isNotEmpty)
          TextSpan(text: parts.typed, style: _numStyle(AppColors.textPrimary)),
        if (focused)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: AnimatedBuilder(
              animation: _blink,
              builder: (context, _) => Opacity(
                opacity: _blink.value < 0.5 ? 1 : 0,
                child: Container(
                  width: 2,
                  height: 17,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        if (parts.rest.isNotEmpty)
          TextSpan(text: parts.rest, style: _numStyle(restColor)),
      ]),
      textAlign: TextAlign.right,
      maxLines: 1,
      softWrap: false,
    );
    // The currency code doubles as the currency control now that the amount
    // sheet (whose chip used to open the picker) is gone.
    final code = Semantics(
      button: true,
      label: def.code,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onCurrencyTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(def.code, style: _codeStyle),
        ),
      ),
    );

    return Semantics(
      button: true,
      focused: focused,
      label:
          '${widget.label} ${money(AmountEntry.value(widget.raw), currency: widget.currency)}',
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          // Focused: the accent outline the old amount sheet's input carried,
          // inset inside the card. The margin/padding swap keeps the content
          // in place and the whole tap target at ≥44 pt.
          margin: focused ? const EdgeInsets.all(3) : EdgeInsets.zero,
          decoration: focused
              ? BoxDecoration(
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.55),
                      width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          // Task 042: 48pt unfocused; the accent frame insets 3 all round, so the
          // focused box is 48 − 6 and the content does not move on focus (§7).
          constraints: BoxConstraints(minHeight: focused ? 42 : 48),
          padding: EdgeInsets.symmetric(
              horizontal: focused ? Insets.md - 3 : Insets.md,
              vertical: focused ? 6 : 9),
          child: LayoutBuilder(
            builder: (context, c) {
              final scaler = MediaQuery.textScalerOf(context);
              final labelW = _measure(widget.label, _labelStyle, scaler);
              final amountW = _measure(parts.typed + parts.rest,
                      _numStyle(AppColors.textPrimary), scaler) +
                  (focused ? 4 : 0); // caret column
              final codeW = _measure(def.code, _codeStyle, scaler) + 6;
              // One line only if the label and the amount unit both fit with a
              // little breathing room between them (§3).
              final oneLine = labelW + 16 + amountW + codeW <= c.maxWidth;

              if (oneLine) {
                return Row(
                  children: [
                    Expanded(
                        child: Text(widget.label,
                            style: _labelStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    amount,
                    code,
                  ],
                );
              }
              // Two-line fallback — label above, the full amount below, never
              // truncated or shrunk (§3).
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.label, style: _labelStyle),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [Flexible(child: amount), code],
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

/// A 1..31 day-of-month picker for a bank loan's payment day (spec: preserved
/// pre-existing field).
Future<int?> _showDayPicker(BuildContext context, int? current) {
  final l = AppLocalizations.of(context);
  return showAppSheet<int>(
    context,
    title: l.qaPaymentDay,
    contentSized: true,
    builder: (context, controller) => GridView.count(
      controller: controller,
      shrinkWrap: true,
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
Future<String?> pickCurrency(BuildContext context, String current,
    {String? title}) {
  final l = AppLocalizations.of(context);
  // §1: this sheet lists ~150 currencies, so "size to the content" resolved to
  // "the ceiling" and it opened near-full over whatever the user was reading. It
  // opts back out of `contentSized` (the rule the twelve short-content siblings
  // keep) and opens at half height instead, draggable up to full.
  //
  // 0.5 is a floor, not a cap: at a large text scale the pinned chrome (grabber,
  // title, + Add, Cancel, search) needs more than half a small screen, so the
  // opening fraction grows with the text scale rather than clipping its header
  // (§1 / §5). 100% → 0.5, 130% → 0.65.
  final scale = MediaQuery.textScalerOf(context).scale(1.0);
  final initial = (0.5 * scale).clamp(0.5, 0.95).toDouble();
  return showAppSheet<String>(
    context,
    // Existing callers (edit account) pass nothing and keep the generic
    // "Currency" title; the base-currency flow (spec §12) passes its own so the
    // sheet's rows/behaviour are otherwise unchanged.
    title: title ?? l.eaCurrency,
    initialSize: initial,
    maxSize: 0.95,
    snapSizes: [initial, 0.95],
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

  /// Focusing search grows the sheet toward full height (§1.1). It does not
  /// shrink back when the query clears — a sheet that resized on every keystroke
  /// would be worse than one that is simply tall.
  void _onSearchFocusChanged(bool hasFocus) {
    if (!hasFocus) return;
    final scope = _SheetDragScope.maybeOf(context);
    final c = scope?.controller;
    if (c == null || !c.isAttached) return;
    final target = scope!.expandedSize;
    if (c.size >= target - 0.001) return;
    c.animateTo(target, duration: Durations.short4, curve: Curves.easeOut);
  }

  /// Whether a delete action should be offered for [def]: only a currency the
  /// user added, and only while nothing references it. In-use ⇒ Edit only; the
  /// action is absent, never a disabled button behind a swipe (§3).
  bool _showsDelete(AppStore store, CurrencyDef def) =>
      def.custom &&
      !(store.currencyInUse(def.code) || store.baseCurrency == def.code);

  Future<void> _openEdit(CurrencyDef def) async {
    closeOpenSwipeRow();
    await showEditCurrencySheet(context, def);
    // The store notifies on save/delete/reset, so this body rebuilds through its
    // StoreScope.of subscription; no manual refresh needed.
  }

  Future<void> _confirmDelete(CurrencyDef def) async {
    closeOpenSwipeRow();
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final store = StoreScope.read(context);
    // Delete only surfaces for an unused custom currency, so the block guard the
    // edit sheet carries cannot trigger here — a plain destructive confirm, the
    // app's standard pattern, is enough.
    final ok = await showDestructiveConfirm(
      context,
      title: l.curDeleteTitle(def.name),
      message: l.curDeleteMsg,
      impact: [ImpactLine.kept(l.curDeleteImpact)],
      confirmLabel: l.curDeleteButton,
    );
    if (!ok) return;
    store.removeCustomCurrency(def.code);
  }

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
      // Hug the content: a short (searched) list keeps the sheet short; the
      // full catalog caps at the ceiling and scrolls (task 20).
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: Insets.sm),
        _SearchBar(
          hint: l.curSearch,
          onChanged: (v) => setState(() => _query = v),
          onFocusChange: _onSearchFocusChanged,
        ),
        const SizedBox(height: Insets.md),
        Flexible(
          child: ListView(
            controller: widget.controller,
            shrinkWrap: true,
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
    final store = StoreScope.of(context);
    return AppCard(
      // The swipe action strip paints to the row's edge; clip it to the card's
      // rounded corners (AppCard exposes this exactly for swipe rows).
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < defs.length; i++) ...[
            if (i > 0) const RowDivider(indent: Insets.md),
            _CurrencyRow(
              def: defs[i],
              selected: defs[i].code == widget.current,
              onTap: () => Navigator.of(context).pop(defs[i].code),
              onEdit: () => _openEdit(defs[i]),
              onDelete: _showsDelete(store, defs[i])
                  ? () => _confirmDelete(defs[i])
                  : null,
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
  const _CurrencyRow({
    required this.def,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  final CurrencyDef def;
  final bool selected;
  final VoidCallback onTap;

  /// Swipe-to-Edit — every row has it (§3). The tap still selects; the swipe is
  /// the deliberate gesture that reaches the display settings.
  final VoidCallback onEdit;

  /// Swipe-to-Delete — present only for an unused custom currency (§3); null
  /// leaves the row a single Edit action rather than a disabled Delete.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Code + name (spec §6), with the symbol as a muted trailing hint so the
    // token the user will see is visible before they commit. A user-added
    // currency carries a CUSTOM tag after its code — the only thing on the row
    // that explains why it swipes to two actions and its neighbour to one (§3.1).
    final row = FormRow(
      label: def.code,
      subtitle: def.name,
      value: def.tokenIsSymbol ? def.symbol : null,
      valueColor: AppColors.textTertiary,
      onTap: onTap,
      labelBadge: def.custom ? const _CustomBadge() : null,
      trailing: selected
          ? const Icon(Icons.check_rounded,
              size: 18, color: AppColors.accentSoft)
          : null,
    );

    final actions = <SwipeActionItem>[
      SwipeActionItem(
        icon: Icons.edit_outlined,
        label: l.curEdit,
        color: AppColors.accent,
        onTap: onEdit,
      ),
      if (onDelete != null)
        SwipeActionItem(
          icon: Icons.delete_outline,
          label: l.actionDelete,
          color: AppColors.negative,
          onTap: onDelete!,
        ),
    ];

    // A swipe-only action is unreachable to a screen reader; expose each as a
    // custom action so it is announced and invokable without the gesture (§5).
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: l.curEdit): onEdit,
        CustomSemanticsAction(label: l.actionDelete): ?onDelete,
      },
      child: SwipeActions(actions: actions, child: row),
    );
  }
}

/// The `CUSTOM` tag after a user-added currency's code (§3.1) — 10pt in
/// [AppColors.accentLight] (#A5A3FF, the spec's colour, already a token). It sits
/// outside the code's flexible box so it never truncates; the name (the row's
/// subtitle) is what gives way at 320pt.
class _CustomBadge extends StatelessWidget {
  const _CustomBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        AppLocalizations.of(context).curCustom.toUpperCase(),
        maxLines: 1,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.accentLight,
        ),
      ),
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
    contentSized: true,
    cancelLabel: l.actionCancel,
    builder: (context, controller) => _AddCurrencyForm(controller: controller),
  );
}

/// The same sheet in **edit** mode (spec §2), seeded from an existing
/// definition. Four differences and no fifth: the title, a locked code, a Save
/// primary, and a destructive action — Delete for a custom currency, Reset to
/// default for a built-in you have overridden.
///
/// Editing a built-in writes a *custom* def under the built-in's own code.
/// Nothing in the formatter changes: [currencyDef] already prefers a custom
/// entry over a built-in of the same code, and [customCurrencyDef] already
/// routes [money] down the metadata branch.
///
/// Returns true when something was written (saved, deleted or reset), so the
/// caller can react; null on cancel.
Future<bool?> showEditCurrencySheet(BuildContext context, CurrencyDef def) {
  final l = AppLocalizations.of(context);
  return showAppSheet<bool>(
    context,
    title: l.curEditTitle,
    contentSized: true,
    cancelLabel: l.actionCancel,
    builder: (context, controller) =>
        _AddCurrencyForm(controller: controller, initial: def),
  );
}

/// A single numeric prompt (spec 021b §3 / 021e §1): enter a positive decimal to
/// [maxDecimals] places. Returns the parsed value, or null on cancel. Refuses
/// `0`, negatives and empty by keeping Save disabled — the one rate rule every
/// rate entry in the app shares.
Future<double?> promptDecimal(
  BuildContext context, {
  required String title,
  double? initial,
  String? hint,
  int maxDecimals = 6,
}) {
  return showAppSheet<double>(
    context,
    title: title,
    contentSized: true,
    cancelLabel: AppLocalizations.of(context).actionCancel,
    builder: (context, controller) => _DecimalPromptForm(
      controller: controller,
      initial: initial,
      hint: hint,
      maxDecimals: maxDecimals,
    ),
  );
}

class _DecimalPromptForm extends StatefulWidget {
  const _DecimalPromptForm({
    required this.controller,
    required this.maxDecimals,
    this.initial,
    this.hint,
  });
  final ScrollController controller;
  final double? initial;
  final String? hint;
  final int maxDecimals;

  @override
  State<_DecimalPromptForm> createState() => _DecimalPromptFormState();
}

class _DecimalPromptFormState extends State<_DecimalPromptForm> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(
        text: widget.initial == null ? '' : formatRate(widget.initial!, maxDecimals: widget.maxDecimals));
    _field.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  double? get _value {
    final v = double.tryParse(_field.text.trim());
    if (v == null || v <= 0) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            controller: widget.controller,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.md, Insets.gutter, Insets.lg),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sheetCard,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: TextField(
                  controller: _field,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: AppText.body.copyWith(fontSize: 18),
                  cursorColor: AppColors.accentSoft,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: AppText.body
                        .copyWith(fontSize: 15, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
        _SheetFooter(
          label: l.actionSave,
          enabled: _value != null,
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}

class _AddCurrencyForm extends StatefulWidget {
  const _AddCurrencyForm({required this.controller, this.initial});
  final ScrollController controller;

  /// Non-null puts the form in edit mode (spec §2).
  final CurrencyDef? initial;

  @override
  State<_AddCurrencyForm> createState() => _AddCurrencyFormState();
}

class _AddCurrencyFormState extends State<_AddCurrencyForm> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  bool _before = true;
  int _decimals = 2;

  /// The rate typed in place in the Rate row (task 033 §3). [_rate] is the live
  /// editing buffer; [_rateOverride] tracks its parsed value, non-null only once
  /// the user has typed a usable rate, and is what Save writes (021a §4a). Null
  /// means "no change — keep the stored rate".
  final _rate = TextEditingController();
  final _rateFocusNode = FocusNode();
  bool _rateSeeded = false;
  double? _rateOverride;

  bool get _editing => widget.initial != null;

  /// A standard currency's code AND name are ISO facts, not preferences (§4), so
  /// both are read-only when editing one; only symbol, position and decimals —
  /// how *this app* prints it — stay editable. "Standard" means a built-in
  /// exists for the code, which stays true after the user overrides its
  /// symbol/decimals (that override is itself `custom`), so the predicate keys
  /// off the built-in catalogue, not the def's flag. A currency the user
  /// invented has no built-in behind it, so all five fields stay theirs.
  ///
  /// The code is locked in *every* edit mode regardless (custom included): it is
  /// stored as a bare string on every account and transaction, so a rename would
  /// orphan them — decided separately from this fact/preference split.
  bool get _factsLocked =>
      _editing && builtInCurrencyDef(widget.initial!.code) != null;

  /// Save is offered only once something actually changed (§4). Add mode is
  /// always dirty — there is a new currency to create.
  bool get _dirty {
    final i = widget.initial;
    if (i == null) return true;
    final iSym = (i.symbol != null && i.symbol!.isNotEmpty) ? i.symbol! : '';
    return _name.text.trim() != i.name ||
        _symbol.text.trim() != iSym ||
        _before != i.symbolBefore ||
        _decimals != i.decimals;
  }

  @override
  void initState() {
    super.initState();
    final seed = widget.initial;
    if (seed != null) {
      _code.text = seed.code;
      _name.text = seed.name;
      _symbol.text = seed.symbol ?? '';
      _before = seed.symbolBefore;
      _decimals = seed.decimals;
    }
    for (final c in [_code, _name, _symbol]) {
      c.addListener(() => setState(() {}));
    }
  }

  /// Seeds the Rate row's buffer from the stored rate and wires its listeners —
  /// once, here rather than in [initState], because the store needs a context.
  /// Seeding assigns [_rate] *before* the change listener is attached, so the
  /// seed does not read as a user-typed override (Save must stay disabled until
  /// something actually changes, §4).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rateSeeded) return;
    _rateSeeded = true;
    final store = StoreScope.read(context);
    final code = _rateCode;
    if (code.isNotEmpty && code != store.baseCurrency) {
      final r = store.rateFor(code);
      if (r != null) _rate.text = formatRate(r);
    }
    _rate.addListener(_onRateChanged);
    _rateFocusNode.addListener(_onRateFocusChanged);
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _symbol, _rate]) {
      c.dispose();
    }
    _rateFocusNode.dispose();
    super.dispose();
  }

  /// The rate the user has typed, or null when the field is empty or unusable.
  /// Parsed with the app's one decimal parser ([double.tryParse]); a typed
  /// comma is normalised to a dot first so the `[0-9.,]` field a locale offers
  /// still lands on that parser rather than a second one (§3).
  double? get _typedRate {
    final v = double.tryParse(_rate.text.trim().replaceAll(',', '.'));
    return (v != null && v > 0) ? v : null;
  }

  void _onRateChanged() => setState(() => _rateOverride = _typedRate);

  /// On blur, canonicalise a good value and restore a bad or empty one to the
  /// last valid rate — the empty case then reads as the designed `Set rate`
  /// state rather than a half-typed number (§3).
  void _onRateFocusChanged() {
    if (_rateFocusNode.hasFocus) return;
    final v = _typedRate;
    if (v != null) {
      final s = formatRate(v);
      if (_rate.text != s) _rate.text = s;
    } else {
      final stored = StoreScope.read(context).rateFor(_rateCode);
      _rate.text = stored != null ? formatRate(stored) : '';
    }
    setState(() {});
  }

  String get _codeUp => _code.text.trim().toUpperCase();

  /// Create keeps the full duplicate guard. Edit exempts the row's own code —
  /// an override for `TMT` *must* reuse the built-in's code (spec §2), and the
  /// code cannot change anyway, so no other code can collide.
  bool get _duplicate =>
      !_editing &&
      _codeUp.isNotEmpty &&
      currencyCodeExists(_codeUp, excluding: widget.initial?.code);
  bool get _valid =>
      _codeUp.isNotEmpty && _name.text.trim().isNotEmpty && !_duplicate;

  CurrencyDef _def() => CurrencyDef(
        code: _editing ? widget.initial!.code : _codeUp,
        name: _name.text.trim(),
        symbol: _symbol.text.trim().isEmpty ? null : _symbol.text.trim(),
        decimals: _decimals,
        symbolBefore: _before,
        custom: true,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Preview uses a fixed example so the shape (grouping, decimals, token side
    // and spacing) is legible before saving.
    final preview =
        formatCurrencyExample(_def().copyWith(code: _codeUp.isEmpty ? 'CUR' : _codeUp), 9850);

    return Column(
      // Hug the content: the footer sits just below the form (task 20).
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            controller: widget.controller,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.sm, Insets.gutter, Insets.lg),
            children: [
              // The Rate block, above the format rows (021a §4a): a rate against
              // the reporting currency, then the "does not change past entries"
              // note. Absent for the base currency (its rate is 1 by definition).
              ..._rateBlock(context, l),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.sheetCard,
                  borderRadius: BorderRadius.circular(11),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Code and Name were paired side by side to save height. They
                    // did not: each half was a caption over a value, so the pair
                    // cost two rows' height and bought a second layout for large
                    // text scales. Four single rows are the same height, read in
                    // one rhythm, and delete the `split` branch outright (§1).
                    //
                    // Code is locked in every edit mode (a rename orphans rows);
                    // Name is locked only for a built-in (an ISO fact). Add mode
                    // types both. `_factsLocked` is name's condition, not code's —
                    // using it for code would unlock a custom currency's code.
                    _editing
                        ? FormRow(
                            key: const Key('curRowCode'),
                            label: l.curCode,
                            value: _codeUp,
                            locked: true)
                        : _inlineTextRow(
                            rowKey: const Key('curRowCode'),
                            label: l.curCode,
                            controller: _code,
                            formatters: [
                              LengthLimitingTextInputFormatter(5),
                              FilteringTextInputFormatter.allow(
                                  RegExp('[A-Za-z]')),
                              TextInputFormatter.withFunction((_, n) =>
                                  n.copyWith(text: n.text.toUpperCase())),
                            ],
                            textCapitalization:
                                TextCapitalization.characters,
                          ),
                    _hair(),
                    _factsLocked
                        ? FormRow(
                            key: const Key('curRowName'),
                            label: l.curName,
                            value: _name.text,
                            locked: true)
                        : _inlineTextRow(
                            rowKey: const Key('curRowName'),
                            label: l.curName,
                            controller: _name),
                    _hair(),
                    // Optionality is carried by the empty value and the code-
                    // shaped hint, not by a word in the label (§2).
                    _inlineTextRow(
                      rowKey: const Key('curRowSymbol'),
                      label: l.curSymbol,
                      controller: _symbol,
                      hint: _codeUp.isEmpty ? null : _codeUp,
                    ),
                    _hair(),
                    _positionRow(l),
                    _hair(),
                    FormRow(
                      key: const Key('curRowDecimals'),
                      label: l.curDecimals,
                      value: '$_decimals',
                      showChevron: true,
                      // _pickDecimals raises a bottom sheet.
                      opensSheet: true,
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
              // Preview row — reflects code, symbol, position and decimals live.
              Container(
                padding: const EdgeInsets.all(Insets.md),
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
                    // 14.5, not 16: weight and colour carry the emphasis, so the
                    // sheet's most important figure is not also its tallest row
                    // (§1).
                    Text(preview,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.xs, Insets.sm, 0, 0),
                child: Text(_editing ? l.curCodeLocked : l.curInert,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.textTertiary)),
              ),
              if (_editing) ...[
                const SizedBox(height: Insets.lg),
                _CurrencyDestructiveAction(
                  def: widget.initial!,
                  // A custom currency is deleted; an overridden built-in is
                  // reset, which is not a delete — it drops the override and
                  // lets the shipped definition take over (§2).
                  isReset: isOverriddenBuiltIn(widget.initial!.code),
                ),
              ],
            ],
          ),
        ),
        _SheetFooter(
          label: _editing ? l.curSaveButton : l.curAddButton,
          // In edit mode Save waits for a real change (§4) — a rate edit counts;
          // add mode only needs a valid new currency.
          enabled: _editing
              ? ((_valid && _dirty) || _rateOverride != null)
              : _valid,
          onPressed: () {
            final store = StoreScope.read(context);
            // Write the rate (021a §4a) first, so it lands whether or not the
            // definition itself changed. A built-in edited for its rate only is
            // NOT turned into an override.
            if (_rateOverride != null &&
                _rateCode.isNotEmpty &&
                _rateCode != store.baseCurrency) {
              store.setRate(_rateCode, _rateOverride!);
            }
            final def = _def();
            if (_editing) {
              if (_dirty) store.updateCustomCurrency(def);
              Navigator.of(context).pop(true);
            } else {
              store.addCustomCurrency(def);
              Navigator.of(context).pop(def.code);
            }
          },
        ),
      ],
    );
  }

  /// The code this sheet's rate belongs to — the edited currency, or the code
  /// being typed in add mode.
  String get _rateCode => _editing ? widget.initial!.code : _codeUp;

  /// The Rate block (021a §4a) — shown for any currency that is not the base.
  /// One card, one row: the rate is typed here rather than on a sheet over this
  /// one (task 033 §3).
  List<Widget> _rateBlock(BuildContext context, AppLocalizations l) {
    final store = StoreScope.of(context);
    final code = _rateCode;
    if (code.isEmpty || code == store.baseCurrency) return const [];
    return [
      Container(
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: _rateRow(l, store.baseCurrency, code),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Insets.xs, Insets.sm, 0, 0),
        child: Text(l.curRateNote,
            style: const TextStyle(
                fontSize: 11, height: 1.45, color: AppColors.textTertiary)),
      ),
      const SizedBox(height: Insets.lg),
    ];
  }

  /// The rate row (task 033 §3). One row, `FormRow` tall: the question on the
  /// left, the answer on the right, typed here rather than on a sheet over this
  /// one. The code beside the field is static — only the number is editable.
  ///
  /// The clear button appears only when there is a value; clearing drops the row
  /// to the existing `curSetRate` state, so the empty case is one that was
  /// already designed rather than a new one. It is overlaid in a `Stack` so its
  /// 36×36 tap target never makes this row taller than the FormRows beside it —
  /// the row's height comes from the 14.5pt line, exactly like `FormRow`.
  Widget _rateRow(AppLocalizations l, String base, String code) {
    final focused = _rateFocusNode.hasFocus;
    final hasValue = _rate.text.trim().isNotEmpty;
    // Focused, the row takes TxnNoteFieldRow's accent outline, inset by a 3pt
    // margin with the padding reduced to match, so the content does not move.
    final pad = Insets.md - (focused ? 3 : 0);

    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_rateFocusNode.hasFocus) _rateFocusNode.requestFocus();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad),
        child: Row(
          children: [
            Text('1 $base =',
                style: AppText.body.copyWith(
                    fontSize: 14.5, color: AppColors.textSecondary)),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rate,
                      focusNode: _rateFocusNode,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: AppText.body.copyWith(
                          fontSize: 14.5, fontWeight: FontWeight.w600),
                      cursorColor: AppColors.accentSoft,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        // Empty reads as the designed "Set rate" state, in
                        // warning, rather than a blank field (§3).
                        hintText: l.curSetRate,
                        hintStyle: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning),
                      ),
                    ),
                  ),
                  if (hasValue) ...[
                    const SizedBox(width: 5),
                    Text(code,
                        style: AppText.body.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ],
                  // Reserve room for the overlaid clear button so the code and
                  // number never sit under it.
                  SizedBox(width: hasValue ? 34 : 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    Widget row = Stack(
      key: const Key('curRowRate'),
      alignment: Alignment.centerRight,
      children: [
        content,
        if (hasValue)
          Padding(
            padding: EdgeInsets.only(right: pad - 6),
            child: _rateClearButton(l),
          ),
      ],
    );

    if (focused) {
      row = Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.55), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: row,
      );
    }
    return row;
  }

  /// Clears the typed rate, dropping the row to its `Set rate` state (§3).
  Widget _rateClearButton(AppLocalizations l) {
    return Semantics(
      button: true,
      label: l.actionClear,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The controller's listener sets `_rateOverride` to null and rebuilds.
        onTap: _rate.clear,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 19, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hair() =>
      Container(height: 1, color: Colors.white.withValues(alpha: 0.07));

  /// A single-line editable row inside the format card, the same height as a
  /// [FormRow] (§1/§2): the label on the left, a right-aligned field on the
  /// right, sharing FormRow's `Insets.md` padding, 14.5pt text and `accentSoft`
  /// cursor. It replaces the old caption-over-value `_miniField`, which stood
  /// twice as tall. Locked fields are plain [FormRow]s, so this never needs a
  /// read-only branch.
  Widget _inlineTextRow({
    Key? rowKey,
    required String label,
    required TextEditingController controller,
    String? hint,
    List<TextInputFormatter>? formatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.md, vertical: Insets.md),
      child: Row(
        children: [
          Text(label,
              style: AppText.body
                  .copyWith(fontSize: 14.5, color: AppColors.textPrimary)),
          const SizedBox(width: Insets.md),
          Expanded(
            child: TextField(
              controller: controller,
              inputFormatters: formatters,
              textCapitalization: textCapitalization,
              textAlign: TextAlign.right,
              style: AppText.body.copyWith(fontSize: 14.5),
              cursorColor: AppColors.accentSoft,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The Position row (§1): the label plus the existing [SegmentedPicker],
  /// right-aligned. The picker carries its own ~40pt height, so this row takes a
  /// reduced 2pt vertical padding to land level with the FormRows around it —
  /// equal height, not equal padding.
  Widget _positionRow(AppLocalizations l) {
    return Padding(
      key: const Key('curRowPosition'),
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(l.curPosition,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body
                    .copyWith(fontSize: 14.5, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: Insets.md),
          SizedBox(
            width: 168,
            child: SegmentedPicker<bool>(
              values: const [true, false],
              labelOf: (v) => v ? l.curPosBefore : l.curPosAfter,
              selected: _before,
              onChanged: (v) => setState(() => _before = v),
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
/// Delete (custom) or Reset to default (an overridden built-in), at the foot of
/// the edit sheet (spec §2).
///
/// Delete is refused while anything still names the code. The message follows
/// the shape the category guard already uses (`ctBlockedTitle`/`ctBlockedMsg`):
/// name what is holding it, then name the one thing to do first. It does not
/// offer to reassign the accounts — that is a bulk data migration and out of
/// scope. Reset needs no such guard: it changes formatting only, never data.
class _CurrencyDestructiveAction extends StatelessWidget {
  const _CurrencyDestructiveAction({required this.def, required this.isReset});

  final CurrencyDef def;
  final bool isReset;

  Future<void> _run(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final store = StoreScope.read(context);

    if (!isReset) {
      // Blocked delete — an account naming it is the clearest thing to report,
      // so it wins; otherwise say how many entries hold it.
      final accounts = store.accountsUsingCurrency(def.code);
      final txns = store.txnCountForCurrency(def.code);
      if (accounts.isNotEmpty || txns > 0) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surfaceAlt,
            title: Text(l.curBlockedTitle(def.name), style: AppText.rowTitle),
            content: Text(
              accounts.isNotEmpty
                  ? l.curBlockedAccount(accounts.first.name)
                  : l.curBlockedTxns(txns),
              style: AppText.body.copyWith(fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentLight),
                child: Text(l.actionClose),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    final ok = await showDestructiveConfirm(
      context,
      title: isReset ? l.curResetTitle(def.name) : l.curDeleteTitle(def.name),
      message: isReset ? l.curResetMsg : l.curDeleteMsg,
      impact: [
        ImpactLine.kept(isReset ? l.curResetImpact : l.curDeleteImpact),
      ],
      confirmLabel: isReset ? l.curResetButton : l.curDeleteButton,
    );
    if (!ok || !context.mounted) return;

    // Both are the same store call: drop the override. For a custom currency
    // that is the delete; for a built-in it hands display back to the catalog.
    store.removeCustomCurrency(def.code);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: TextButton(
        onPressed: () => _run(context),
        style: TextButton.styleFrom(
          foregroundColor:
              isReset ? AppColors.accentLight : AppColors.negative,
        ),
        child: Text(isReset ? l.curResetButton : l.curDeleteButton),
      ),
    );
  }
}

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
    // The navigation-bar inset is reserved by the sheet shell now, whether or
    // not a keypad docks below the footer — no per-widget compensation.
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        Insets.md,
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
