import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/edit_account_screen.dart';
import '../quick_add/pickers.dart' show showNewAccountSheet;

/// More ▸ Accounts.
///
/// **Balance answers *how much you have*. More ▸ Accounts answers *how your
/// accounts are set up*.** That boundary is absolute: no balance, total, amount
/// or net-worth figure appears here in any state — only name, type, currency and
/// archive state. A figure here would be a second code path from Balance's, and
/// the first time the two disagreed the app would hold two truths about one
/// account.
///
/// A flat list, not grouped by [AccountGroup]: at the current account count the
/// section headers would outnumber the rows they group, so the type moved into
/// each row's subtitle (`Spendable · USD`) instead. Archived accounts sit in
/// their own dimmed section below, restorable in place; they also remain in the
/// Archive screen, which this screen does not touch. Every mutation
/// (create / edit / archive / restore) is performed by screens that already own
/// it — this one only lists and routes.
class AccountsManagementScreen extends StatelessWidget {
  const AccountsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final active = store.manageableAccounts;
    final archived = store.archivedAccounts;
    final empty = active.isEmpty && archived.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              showBack: true,
              showAdd: false,
              titleWidget: _HeaderTitle(
                activeCount: active.length,
                archivedCount: archived.length,
              ),
            ),
            Expanded(
              child: empty
                  // No accounts at all (§3.5): a single centred line. The pinned
                  // button below stays — getting the user to it is the whole job
                  // of this state, so there is no card, section or subtitle.
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Insets.gutter),
                        child: Text(
                          l.qaNoAccountsYet,
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(
                              fontSize: 14.5, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      children: [
                        const SizedBox(height: Insets.xs),
                        if (active.isNotEmpty) _AccountsCard(accounts: active),
                        // The ARCHIVED section is absent — not empty, not
                        // collapsed — when nothing is archived (§3.3).
                        if (archived.isNotEmpty) ...[
                          SectionLabel(
                            l.accSectionArchived,
                            // Left edge aligned to the card's 12 pt margin, not
                            // the 20 pt page gutter SectionLabel defaults to.
                            padding: const EdgeInsets.fromLTRB(
                                Insets.md, Insets.lg, Insets.md, Insets.sm),
                          ),
                          _ArchivedCard(accounts: archived),
                        ],
                      ],
                    ),
            ),
            // Pinned (§3.4): sits above the safe-area inset and does not scroll
            // with the list.
            const _NewAccountButton(),
          ],
        ),
      ),
    );
  }
}

/// Title + the screen's only count, baseline-aligned to the right of it (§3.1).
/// With zero accounts there is no subtitle at all.
class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.activeCount, required this.archivedCount});

  final int activeCount;
  final int archivedCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Same title style as the Categories management screen (AppText.title).
    final title = Text(
      l.moreAccounts,
      style: AppText.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (activeCount + archivedCount == 0) return title;

    final subtitle = archivedCount == 0
        ? l.accActive(activeCount)
        : l.accActiveArchived(activeCount, archivedCount);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: title),
        // Flexible + ellipsis: at a narrow width or 130 % scale the count loses
        // room before it overflows. It is a count, not a control, so truncation
        // is acceptable here (unlike Restore below). The gap is padding rather
        // than a SizedBox so every child of this baseline row carries a text
        // baseline.
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(left: Insets.sm),
            child: Text(
              subtitle,
              style: AppText.rowSubtitle.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

/// The active list — one flat card, no section headers (§3.2).
class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceAlt,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < accounts.length; i++) ...[
            // Hairline between rows only — never below the last row (§3.2).
            if (i > 0) const RowDivider(),
            _AccountRow(account: accounts[i]),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // `{Type} · {CURRENCY}`; the type string is `group.label`, byte-identical to
    // the New account sheet's Type row.
    final subtitle =
        '${account.group.label(l)} · ${account.currency.toUpperCase()}';
    return Semantics(
      button: true,
      label: '${account.name}, $subtitle',
      child: InkWell(
        // Tapping an active row opens Edit Account — never archives, deletes, or
        // opens a menu. Those live inside Edit Account. Pushed on the root
        // navigator, as the Categories cell pushes its editor.
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => EditAccountScreen(accountId: account.id),
          ),
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 9),
          child: Row(
            children: [
              _GlyphTile(account: account),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.name,
                      style: AppText.body.copyWith(
                          fontSize: 14.5, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.caption.copyWith(
                          fontSize: 11.5, color: AppColors.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textQuaternary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The account's own glyph on a neutral tile (§3.2): an emoji keeps its own
/// colours; an icon renders in the account's own colour.
class _GlyphTile extends StatelessWidget {
  const _GlyphTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.sheetCard,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: account.hasEmoji
          ? Text(account.emoji!, style: const TextStyle(fontSize: 15))
          : Icon(account.displayIcon, size: 15, color: account.color),
    );
  }
}

/// The archived section (§3.3): a dimmer card, dimmed rows, and Restore as the
/// row's only affordance.
class _ArchivedCard extends StatelessWidget {
  const _ArchivedCard({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.fieldCard,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < accounts.length; i++) ...[
            if (i > 0) const RowDivider(),
            _ArchivedRow(account: accounts[i]),
          ],
        ],
      ),
    );
  }
}

class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = StoreScope.read(context);
    final subtitle =
        '${account.group.label(l)} · ${account.currency.toUpperCase()}';
    return Semantics(
      container: true,
      label: '${account.name}, $subtitle, ${l.accSectionArchived}',
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 9),
        child: Row(
          children: [
            // The account's colour is deliberately not used here: an archived
            // account must not look active. The glyph is always an icon (never
            // its emoji) so nothing carries colour.
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(account.displayIcon,
                  size: 15, color: AppColors.textQuaternary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    account.name,
                    style: AppText.body.copyWith(
                        fontSize: 14.5, color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.caption.copyWith(
                        fontSize: 11.5, color: AppColors.textQuaternary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            // Restore is the row's ONLY tap target — no chevron, the body inert.
            // It never shrinks, wraps or truncates: it is a control, so it is not
            // wrapped in the Flexible the name uses.
            Semantics(
              button: true,
              label: l.actionRestore,
              child: InkWell(
                onTap: () => store.restoreAccount(account),
                borderRadius: BorderRadius.circular(Radii.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm, vertical: Insets.xs),
                  child: Text(
                    l.actionRestore,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentLight,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pinned New-account action (§3.4). Modelled on the app's existing pinned
/// FilledButton (the tag sheet footer / scoped-ledger add): accent fill, white
/// label, [Radii.md] corners, 50 pt tall, [AppText.button] text. Opens the
/// existing New account sheet; a successful save returns here with the account
/// in the list because the store notifies and this screen rebuilds (§5) — the
/// destination is here, at the call site, never inside the sheet.
class _NewAccountButton extends StatelessWidget {
  const _NewAccountButton();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.md,
        Insets.sm,
        Insets.md,
        MediaQuery.paddingOf(context).bottom + Insets.md,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => showNewAccountSheet(context),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            textStyle: AppText.button,
          ),
          child: Text(l.qaNewAccount,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
