import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_typography.dart';

/// How long an undo bar stays.
///
/// Five seconds, not Material's default four: the thing being undone is a
/// gesture (a drag, a swipe) and the user's eyes are still on the row, not on
/// the bar — four is the floor to notice-read-decide-reach. Past ~seven the bar
/// stops reading as a transient confirmation and starts to feel modal. One
/// constant so the app's undo bars never disagree about the window.
const Duration undoBarWindow = Duration(seconds: 5);

/// The app's undo bar.
///
/// Wraps the two things every undo bar here must get right: `persist: false`
/// — since Flutter 3.37 a SnackBar with an action does not auto-dismiss and its
/// duration is ignored — and one shared window ([undoBarWindow]), so the bars
/// never disagree about how long the user has.
///
/// Returns the controller so a caller can commit on `.closed` (see the Ledger's
/// delete, which is only really deleted once this bar goes away).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  String? actionLabel,
}) {
  return (ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar())
      .showSnackBar(
    SnackBar(
      content: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: AppText.body.copyWith(fontSize: 13.5),
        ),
      ),
      persist: false,
      duration: undoBarWindow,
      action: SnackBarAction(
        // Defaults to "Undo"; Insight's out-of-window notice passes "Go to date"
        // — the same transient-bar mechanism carrying a non-undo action (§8).
        label: actionLabel ?? AppLocalizations.of(context).actionUndo,
        onPressed: onUndo,
      ),
    ),
  );
}
