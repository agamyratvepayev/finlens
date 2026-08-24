import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// A tool button in [AppToolbar] — 30×28, radius 8, surface fill.
class ToolbarTool {
  const ToolbarTool({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Brand fill + white icon, for a toggle that is currently "on".
  final bool filled;

  final String? tooltip;
}

/// The 44px bar that sits under a screen header: filter tabs on the left,
/// tool buttons on the right, and an inline search mode that swaps in without
/// changing the bar's height.
///
/// Shared by Balance (All/Assets/Liabilities) and Ledger (All/In/Out) — the
/// tabs and tools are passed in.
class AppToolbar extends StatefulWidget {
  const AppToolbar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onTabChanged,
    this.tools = const [],
    this.onQueryChanged,
    this.searchHint,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onTabChanged;
  final List<ToolbarTool> tools;

  /// Providing this adds the search tool. Cleared to '' when search is closed.
  final ValueChanged<String>? onQueryChanged;
  final String? searchHint;

  static const height = 44.0;

  @override
  State<AppToolbar> createState() => _AppToolbarState();
}

class _AppToolbarState extends State<AppToolbar> {
  bool _searching = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    // The field is built in the same frame; focus it once it exists so the
    // keyboard comes up without a second tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _closeSearch() {
    _controller.clear();
    _focus.unfocus();
    setState(() => _searching = false);
    widget.onQueryChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppToolbar.height,
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _searching ? _searchRow() : _tabsRow(),
      ),
    );
  }

  Widget _tabsRow() {
    return Row(
      key: const ValueKey('tabs'),
      children: [
        // The tools always keep their space; the tabs scroll instead of
        // overflowing when the labels are long or text is scaled up.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < widget.tabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 19),
                  _Tab(
                    label: widget.tabs[i],
                    selected: i == widget.index,
                    onTap: () => widget.onTabChanged(i),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: Insets.sm),
        for (final tool in widget.tools) ...[
          _ToolButton(tool: tool),
          const SizedBox(width: 5),
        ],
        if (widget.onQueryChanged != null)
          _ToolButton(
            tool: ToolbarTool(
              icon: Icons.search_rounded,
              onTap: _openSearch,
              tooltip: AppLocalizations.of(context).actionSearch,
            ),
          ),
      ],
    );
  }

  Widget _searchRow() {
    return Row(
      key: const ValueKey('search'),
      children: [
        Expanded(
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: widget.onQueryChanged,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14, height: 1.1),
                    cursorColor: AppColors.accentSoft,
                    cursorHeight: 15,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText:
                          widget.searchHint ?? AppLocalizations.of(context).actionSearch,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _closeSearch,
          child: const Padding(
            padding: EdgeInsets.only(left: Insets.md),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.accentSoft,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: AppToolbar.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            // The underline sits on top of the bar's own divider.
            Positioned(
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: selected ? 24 : 0,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool});

  final ToolbarTool tool;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tool.onTap,
      child: SizedBox(
        height: AppToolbar.height,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 30,
                height: 28,
                decoration: BoxDecoration(
                  color:
                      tool.filled ? AppColors.accent : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(
                  tool.icon,
                  size: 15,
                  color: tool.filled
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
