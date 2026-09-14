import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';
import '../quick_add/type_menu.dart';
import 'edit_scaffold.dart';
import 'widgets/percent_input_formatter.dart';

/// One screen, two modes (spec §7). In **create** mode the category starts
/// unset and the row is a picker; the limit and the two settings are entered,
/// and there is no spend history to show. In **edit** mode the category is
/// fixed (a locked value) and the three-month history card sits below the form.
///
/// The mode is derived, not passed: a category that carries no monthly budget is
/// being created, one that does is being edited. `Remove budget` used to close
/// this screen; it now lives in the budget detail's ••• menu (spec §5).
class EditBudgetScreen extends StatefulWidget {
  const EditBudgetScreen({super.key, this.categoryId});

  /// The category to edit, the category pre-selected for a new budget (the
  /// Budgets tab's per-row `Set` shortcut), or null to open create mode with no
  /// category chosen yet (the `+` and Quick Add's New budget).
  final String? categoryId;

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

class _EditBudgetScreenState extends State<EditBudgetScreen> {
  late final AppStore _store = StoreScope.read(context);

  /// The budgeted category. Null in create mode until the picker sets it; fixed
  /// (and locked) in edit mode.
  Category? _category;

  /// Whether this screen is *creating* a budget. Latched at construction rather
  /// than recomputed in build: _save writes the budget through the store (firing
  /// notifyListeners) before it pops, and build subscribes via StoreScope.of —
  /// so the predicate would flip true→false for the frames the screen animates
  /// away, blinking the New-budget pill into the plain Edit title.
  late final bool _isNew;

  late final TextEditingController _limit;
  late bool _rollover;
  late double _warn;

  @override
  void initState() {
    super.initState();
    _category = widget.categoryId == null
        ? null
        : _store.categoryById(widget.categoryId!);
    _isNew = _category == null ||
        _store.monthlyBudgetForCategory(_category!.id) == null;
    final existingLimit =
        _category == null ? null : _store.monthlyLimitOf(_category!);
    _limit = TextEditingController(
      text: (existingLimit ?? 0) > 0 ? existingLimit!.toStringAsFixed(0) : '',
    );
    _rollover = _category == null ? false : _store.rolloverOf(_category!);
    _warn = _category == null ? 0.8 : _store.warnThresholdOf(_category!);
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  double get _limitValue => double.tryParse(_limit.text.trim()) ?? 0;

  /// Save is unreachable until the two facts a budget cannot exist without are
  /// present: a category and a positive limit. (Replaced the old `_limitValue >
  /// 0`, which could only ever run with a category already locked in.)
  bool get _canSave => _category != null && _limitValue > 0;

  /// Spec 5.4 — the last three months of actual spend, and a limit suggested
  /// from their average. Only ever read in edit mode, where the category is set.
  List<(DateTime, double)> get _history {
    final out = <(DateTime, double)>[];
    for (var i = 0; i < 3; i++) {
      final month = DateTime(_store.period.year, _store.period.month - i);
      out.add((month, _store.spentInCategory(_category!.id, month)));
    }
    return out;
  }

  double get _average {
    final months = _history.where((m) => m.$2 > 0).toList();
    if (months.isEmpty) return 0;
    return months.fold(0.0, (sum, m) => sum + m.$2) / months.length;
  }

  double get _suggestion => (_average / 50).ceil() * 50;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    return EditScaffold(
      title: l.ebTitle,
      // Creating a budget is reachable from the type menu, so it must be able to
      // reopen it; editing an existing budget has nothing to switch to (§2).
      // The pill also carries the create-mode title, "New budget".
      type: _isNew ? QuickAddType.newBudget : null,
      onTypeTap: _isNew ? _showTypeMenu : null,
      onSave: _canSave ? _save : null,
      children: [
        _card(l, store),
        // No history for a budget that does not exist yet (spec §6).
        if (!_isNew) _historyCard(store.spentInCategory(_category!.id, store.period)),
      ],
    );
  }

  // ── The form card — four single-line rows (spec §2) ─────────────────────────

  Widget _card(AppLocalizations l, AppStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, 0, Insets.gutter, Insets.md),
      child: AppCard(
        child: Column(
          children: [
            _categoryRow(l),
            const RowDivider(),
            _BudgetRow(
              icon: Icons.attach_money_rounded,
              label: l.ebMonthlyLimit,
              trailing: _limitTrailing(store),
            ),
            const RowDivider(),
            _BudgetRow(
              icon: Icons.repeat_rounded,
              label: l.ebRollOver,
              dense: true,
              trailing: Switch.adaptive(
                value: _rollover,
                onChanged: (v) => setState(() => _rollover = v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.surfaceHigh,
              ),
            ),
            const RowDivider(),
            _BudgetRow(
              icon: Icons.notifications_active_rounded,
              label: l.ebWarnAt,
              trailing: _pickerTrailing(_warnLabel(l)),
              onTap: _pickThreshold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow(AppLocalizations l) {
    if (_isNew) {
      // A picker: tapping opens the category sheet; the value is the chosen
      // name, or "Not set" (muted). The InkWell announces it as a button.
      return _BudgetRow(
        icon: Icons.category_rounded,
        label: l.fieldCategory,
        trailing: _pickerTrailing(_category?.name ?? l.eaNotSet,
            muted: _category == null),
        onTap: _pickCategory,
      );
    }
    // Edit mode: the category is fixed. Changing it would detach the budget from
    // the spend history below, so the row is inert and announces enabled: false.
    return Semantics(
      enabled: false,
      child: _BudgetRow(
        icon: Icons.category_rounded,
        label: l.fieldCategory,
        trailing: _lockedTrailing(_category!.name),
      ),
    );
  }

  /// Value + downward chevron. Category (create mode) and Warn me at.
  Widget _pickerTrailing(String value, {bool muted = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppText.body.copyWith(
              fontSize: 14.5,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.textTertiary),
        ],
      );

  /// Value + padlock, no chevron. Category in edit mode.
  Widget _lockedTrailing(String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppText.body
                .copyWith(fontSize: 14.5, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 6),
          const Icon(Icons.lock_rounded, size: 13, color: AppColors.textTertiary),
        ],
      );

  /// The amount field, right-aligned, currency symbol after it. The field's
  /// keyboard and formatting are unchanged from its old home (hard boundary);
  /// only its position changed and an onChanged was added so the Warn me at line
  /// resolves live as the limit is typed.
  Widget _limitTrailing(AppStore store) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            child: TextField(
              controller: _limit,
              textAlign: TextAlign.right,
              style: AppText.amount.copyWith(
                color: _limitValue > 0
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
              cursorColor: AppColors.accentSoft,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            currencySymbol(store.baseCurrency),
            style: AppText.amount.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );

  /// `80%` while the limit is unset or zero; `80% · $1,600` once it is known.
  /// The amount is the figure the percentage resolves to — without it `80%` is
  /// eighty per cent of an unstated number. Never `80% · $0`.
  String _warnLabel(AppLocalizations l) {
    final pct = percent(_warn, decimals: 0);
    if (_limitValue <= 0) return pct;
    return '$pct · ${money(_limitValue * _warn)}';
  }

  Widget _historyCard(double currentSpend) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, Insets.sm),
            child: Text(l.ebWhatSpent.toUpperCase(), style: AppText.label),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            child: Column(
              children: [
                for (final (month, amount) in _history)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            monthShort(month.month, AppLocalizations.of(context)),
                            style: AppText.body.copyWith(fontSize: 14),
                          ),
                        ),
                        Text(
                          money(amount),
                          style: AppText.amount.copyWith(
                            color: amount > _limitValue
                                ? AppColors.negative
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_average > 0) ...[
                  const RowDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.ebAverage(money(_average.roundToDouble()),
                                money(_suggestion)),
                            style: AppText.caption.copyWith(fontSize: 12.5),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _limit.text = _suggestion.toStringAsFixed(0),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentSoft,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(l.actionUse),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the category picker (spec §3): the same sheet the two-step flow used,
  /// now returning a category into this row instead of pushing a screen. The
  /// candidate list is every expense category — budgeted ones are shown dimmed
  /// and unselectable by the sheet — bar those whose budget was removed (they
  /// live in the Archive and are restored, not recreated).
  Future<void> _pickCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final month = DateTime(_store.period.year, _store.period.month);
    final candidates = _store.categories
        .where((c) =>
            c.type == CategoryType.expense &&
            !c.archived &&
            _store.removedOnOf(c) == null)
        .toList()
      ..sort((a, b) {
        final bySpend = _store
            .spentInCategory(b.id, month)
            .compareTo(_store.spentInCategory(a.id, month));
        return bySpend != 0
            ? bySpend
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final picked =
        await pickBudgetCategory(context, candidates: candidates, month: month);
    if (!mounted || picked == null) return;
    setState(() => _category = picked);
  }

  Future<void> _pickThreshold() async {
    // isScrollControlled so the custom row can lift clear of the keyboard
    // instead of being pushed under it (spec §4, rotate/resize case).
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      builder: (context) => _WarnThresholdSheet(
        initial: _warn,
        onChanged: (v) => setState(() => _warn = v),
      ),
    );
  }

  Future<void> _showTypeMenu() async {
    // The limit field may hold the keyboard; it must not linger over the sheet.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showQuickAddTypeMenu(
      context,
      current: QuickAddType.newBudget,
    );
    if (!mounted || picked == null || picked == QuickAddType.newBudget) return;
    await switchCreationType(context, picked);
  }

  void _save() {
    _store.updateBudget(
      _category!,
      monthlyBudget: _limitValue,
      rollover: _rollover,
      warnThreshold: _warn,
    );
    Navigator.of(context).pop();
  }
}

/// One row of the budget form. A single line: leading icon, label, trailing.
/// Every row is capped to the same height by [_kMinHeight], so the four measure
/// equal even though a switch is taller than a line of text; [dense] only trims
/// the switch row's padding so its taller control still lands inside that box.
class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool dense;

  /// Holds every row to one height. Sized to clear a line of label text and a
  /// shrink-wrapped switch at 100% and 130% text scale, so no row exceeds it and
  /// all four resolve to exactly this.
  static const double _kMinHeight = 48;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: dense ? Insets.xs : Insets.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(icon, size: 18, color: AppColors.textSecondary),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(fontSize: 14.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Insets.sm),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// The five preset thresholds. Task 22 widens the picker with a sixth, custom
/// row; the presets themselves — values, order, formatting — are untouched.
const _warnPresets = [0.5, 0.7, 0.8, 0.9, 1.0];

/// Spec (task 22) — the warn-threshold picker: five presets plus a Custom row.
/// The bound is 1–100 because the warning only fires while the budget is *not*
/// yet over (`!over &&` in all three consumers), so a threshold above 100%
/// could never fire and 0% would fire the instant a budget exists.
///
/// The selection lives here as a fraction; `onChanged` commits it to the parent
/// live (as tapping a preset always did), so the budget's main Save writes it.
class _WarnThresholdSheet extends StatefulWidget {
  const _WarnThresholdSheet({required this.initial, required this.onChanged});

  final double initial;
  final ValueChanged<double> onChanged;

  @override
  State<_WarnThresholdSheet> createState() => _WarnThresholdSheetState();
}

class _WarnThresholdSheetState extends State<_WarnThresholdSheet> {
  // Seeded with the current value only when it is *not* one of the five, so a
  // stored 73% opens visible against the Custom row instead of no mark at all.
  late final TextEditingController _custom = TextEditingController(
    text: _isPreset(widget.initial) ? '' : _pct(widget.initial).toString(),
  );

  // The live selection, in fraction form. Null only when the field has been
  // emptied and the stored value was itself custom — i.e. no row left to mark.
  late double? _selected = widget.initial;

  static int _pct(double v) => (v * 100).round();
  static bool _isPreset(double v) => _warnPresets.any((p) => _pct(p) == _pct(v));

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _pickPreset(double t) {
    // Clear the field so a stale number never sits beside a mark that has moved
    // to a preset (spec §1e). controller.clear() bypasses the formatter, so no
    // spurious haptic fires.
    _custom.clear();
    setState(() => _selected = t);
    widget.onChanged(t);
  }

  void _onCustomChanged(String text) {
    if (text.isEmpty) {
      // Emptied: return to the stored preset, or to no mark. Never commit a
      // null or a zero (spec §4).
      setState(() {
        _selected = _isPreset(widget.initial) ? widget.initial : null;
      });
      if (_selected != null) widget.onChanged(_selected!);
      return;
    }
    // The formatter guarantees a 1..100 integer here.
    final v = int.parse(text) / 100;
    setState(() => _selected = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedPct = _selected == null ? null : _pct(_selected!);
    // A typed preset marks the preset, not Custom (spec §1e): Custom is marked
    // only while the live value is not one of the five.
    final customMarked = _selected != null && !_isPreset(_selected!);

    return SafeArea(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.lg),
            Text(l.ebWarnAt, style: AppText.rowTitle),
            const SizedBox(height: Insets.md),
            for (final t in _warnPresets)
              ListTile(
                title: Text(percent(t, decimals: 0), style: AppText.body),
                trailing: selectedPct == _pct(t)
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.accentSoft,
                      )
                    : null,
                onTap: () => _pickPreset(t),
              ),
            const RowDivider(),
            _customRow(l, customMarked),
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
  }

  Widget _customRow(AppLocalizations l, bool marked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
      child: Row(
        children: [
          Expanded(child: Text(l.ebWarnCustom, style: AppText.body)),
          SizedBox(
            width: 96,
            // Label the field and let the 1–100 helper be announced, not left
            // as mute decoration (spec §4, screen-reader case).
            child: Semantics(
              label: l.ebWarnCustom,
              child: TextField(
                key: const Key('warnThresholdCustomField'),
                controller: _custom,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                style: AppText.body,
                inputFormatters: [PercentInputFormatter(_onReject)],
                onChanged: _onCustomChanged,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: '%',
                  helperText: l.ebWarnRange,
                  helperStyle: AppText.caption
                      .copyWith(color: AppColors.textTertiary),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm, vertical: Insets.sm),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          // Reserve the mark's width whether or not it shows, so the field
          // doesn't shift when the mark arrives or leaves.
          SizedBox(
            width: 18 + Insets.sm,
            child: marked
                ? const Padding(
                    padding: EdgeInsets.only(left: Insets.sm),
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.accentSoft,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // A rejected keystroke gets a light bump — a physical "you hit the wall",
  // paired with the visible 1–100 hint so the rule reads as well as feels
  // (spec §1c). lightImpact, matching swipe_actions.dart; no third weight.
  void _onReject() => HapticFeedback.lightImpact();
}
