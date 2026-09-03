import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/persistence/backup_codec.dart';
import '../core/store/app_store.dart';
import '../l10n/app_localizations.dart';
import 'widgets/destructive_sheet.dart';

/// The Restore-from-backup flow: pick a `.json`, validate it, confirm the
/// destructive replace, then [AppStore.loadFrom] it. Shared by More › DATA and
/// the Ledger's first-run screen — two entry points, one flow, so they cannot
/// drift into disagreeing about what a bad file does.
///
/// [AppStore.loadFrom] fires `notifyListeners`, so the attached persister writes
/// the restored data to SQLite on its own — nothing here touches the database.
/// An invalid/corrupt file shows a notice and changes nothing; cancelling the
/// picker or the confirm is a silent no-op.
Future<void> runRestoreFlow(BuildContext context, AppStore store) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final FilePickerResult? picked;
  try {
    picked = await FilePicker.pickFiles(
      dialogTitle: l.moreRestore,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.restoreInvalidMsg)));
    return;
  }
  if (picked == null || picked.files.isEmpty) return; // cancelled

  final bytes = picked.files.single.bytes;
  if (bytes == null) {
    messenger.showSnackBar(SnackBar(content: Text(l.restoreInvalidMsg)));
    return;
  }

  final BackupDocument doc;
  try {
    doc = decodeBackup(utf8.decode(bytes));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.restoreInvalidMsg)));
    return;
  }

  if (!context.mounted) return;
  final ok = await showDestructiveConfirm(
    context,
    title: l.restoreConfirmTitle,
    message: l.restoreConfirmMsg(doc.accountCount, doc.txnCount),
    impact: [
      ImpactLine.lost(l.restoreImpactLost),
      ImpactLine.kept(l.restoreImpactKept),
    ],
    confirmLabel: l.restoreConfirmAction,
  );
  if (!ok) return;

  store.loadFrom(doc.source);
  messenger.showSnackBar(SnackBar(content: Text(l.restoreDoneMsg)));
}
