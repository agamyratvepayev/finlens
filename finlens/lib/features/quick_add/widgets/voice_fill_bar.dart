import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import 'form_kit.dart';

/// The stage of the voice-entry flow, owned by the Quick Add screen.
enum VoiceFillState { idle, recording, processing }

/// A full-width tap target under the amount hero (expense/income only) that
/// drives voice entry: tap to record, tap again to stop, then the fields fill.
/// Nothing here writes to the store — it only kicks off parsing; the user still
/// reviews and presses Save.
class VoiceFillBar extends StatelessWidget {
  const VoiceFillBar({
    super.key,
    required this.state,
    required this.accent,
    required this.onTap,
  });

  final VoiceFillState state;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = formScale(context);
    final t = formTextScale(context);

    final recording = state == VoiceFillState.recording;
    final processing = state == VoiceFillState.processing;

    final (Widget leading, String label, Color tint) = switch (state) {
      VoiceFillState.recording => (
          Icon(Icons.stop_circle_rounded, size: 20 * s, color: AppColors.negative),
          l.qaVoiceListening,
          AppColors.negative,
        ),
      VoiceFillState.processing => (
          SizedBox(
            width: 18 * s,
            height: 18 * s,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          l.qaVoiceProcessing,
          accent,
        ),
      VoiceFillState.idle => (
          Icon(Icons.mic_rounded, size: 20 * s, color: accent),
          l.qaVoiceHint,
          accent,
        ),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(kFormMargin, 10 * s, kFormMargin, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Ignore taps while parsing so a second clip can't race the first.
        onTap: processing ? null : onTap,
        child: Container(
          height: 48 * s,
          padding: EdgeInsets.symmetric(horizontal: kRowPadding * s),
          decoration: BoxDecoration(
            color: AppColors.tint(tint, recording ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.tint(tint, recording ? 0.55 : 0.30),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              leading,
              SizedBox(width: kIconGap * s),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14 * s * t,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: tint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
