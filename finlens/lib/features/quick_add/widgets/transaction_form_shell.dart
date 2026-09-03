import '../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'amount_hero.dart';
import 'form_kit.dart';

/// One field in a section. Data, not a widget — the shell decides how it is
/// drawn so every type gets identical metrics.
///
/// A null [onTap] marks a computed row (`Current`, `Difference`, `Receives`):
/// dim label, no chevron, no ripple.
class FieldSpec {
  const FieldSpec({
    required this.icon,
    required this.label,
    this.value,
    this.emptyText,
    this.valueColor,
    this.onTap,
    this.flashId,
    this.hideLabel = false,
    this.valueMaxLines = 1,
    this.semanticValue,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? emptyText;
  final Color? valueColor;

  /// Tints the leading icon — the Repeat row uses the accent when set (§3).
  final Color? iconColor;
  final VoidCallback? onTap;

  /// Ties this row to a [Blocker.flashId] so an incomplete Save can flash it
  /// (spec §3). Null for rows that are never a validation target.
  final String? flashId;

  /// The Note row hides its label, allows the value two lines, and announces
  /// the full note (spec §3, §5). Every other field leaves these at defaults.
  final bool hideLabel;
  final int valueMaxLines;
  final String? semanticValue;
}

/// The hero card's content: a number the keypad drives, or free text.
sealed class HeroSpec {
  const HeroSpec();
}

class NumericHero extends HeroSpec {
  const NumericHero({
    required this.label,
    required this.raw,
    required this.currency,
    this.onCurrencyTap,
  });

  final String label;
  final String raw;
  final String currency;
  final VoidCallback? onCurrencyTap;
}

class TextHero extends HeroSpec {
  const TextHero({
    required this.caption,
    required this.placeholder,
    required this.controller,
    required this.focusNode,
  });

  final String caption;
  final String placeholder;
  final TextEditingController controller;
  final FocusNode focusNode;
}

/// A named section of fields. [title] of null renders the card with no label,
/// which is how the hero stays unlabelled.
class FieldGroup {
  const FieldGroup(this.title, this.fields);

  final String? title;
  final List<FieldSpec> fields;
}

/// One unmet requirement. The first unmet one becomes Save's label.
class Blocker {
  const Blocker({required this.unmet, required this.label, this.flashId});

  final bool unmet;
  final String label;

  /// Which field to flash when this blocker is the first unmet one on Save
  /// (spec §3). 'amount' targets the hero; others match a [FieldSpec.flashId].
  final String? flashId;
}

/// Everything that differs between the six types.
class FormConfig {
  const FormConfig({
    required this.typeName,
    required this.accent,
    required this.accentDim,
    required this.hero,
    required this.groups,
    required this.toggles,
    required this.saveLabel,
    required this.blockers,
    this.action,
    this.hint,
    this.trailing = const [],
  });

  final String typeName;
  final Color accent;
  final Color accentDim;
  final HeroSpec hero;

  /// Ordered sections — `REQUIRED`, then any extra group, then `OPTIONAL`.
  final List<FieldGroup> groups;

  final List<FormToggle> toggles;

  /// A single full-width transformation beneath the card (Split). Null when the
  /// type has none. Rendered after any [toggles].
  final FormActionSpec? action;

  final String saveLabel;

  /// Evaluated in order; the first unmet one names the blocker on Save.
  final List<Blocker> blockers;

  /// Explains what saving will actually book (Rebalance, Goal).
  final HintSpec? hint;

  /// Edit-only extras appended below the toggles.
  final List<Widget> trailing;

  Blocker? get firstUnmet {
    for (final b in blockers) {
      if (b.unmet) return b;
    }
    return null;
  }
}

class HintSpec {
  const HintSpec(this.spans);

  /// `strong` segments render white and heavier — the figure, not the prose.
  final List<({String text, bool strong})> spans;

  /// Convenience for the common "prose <figure> prose" shape.
  factory HintSpec.parts(List<String> parts) => HintSpec([
        for (var i = 0; i < parts.length; i++)
          (text: parts[i], strong: i.isOdd),
      ]);
}

/// Renders the skeleton every type shares. Adding a seventh type must not
/// require touching this widget — only supplying another [FormConfig].
class TransactionFormShell extends StatelessWidget {
  const TransactionFormShell({
    super.key,
    required this.config,
    required this.onCancel,
    required this.onTypeTap,
    required this.onSave,
    required this.keypadOpen,
    required this.onHeroTap,
    required this.onKey,
    required this.onBackspace,
    required this.onDismissKeypad,
    this.typeLocked = false,
    this.flashTarget,
    this.flashPulse,
  });

  final FormConfig config;
  final VoidCallback onCancel;
  final VoidCallback onTypeTap;
  final VoidCallback onSave;
  final bool keypadOpen;
  final VoidCallback onHeroTap;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onDismissKeypad;
  final bool typeLocked;

  /// The field currently flagged as missing (spec §3): 'amount' for the hero,
  /// or a [FieldSpec.flashId]. Its value renders red and its background pulses.
  final String? flashTarget;
  final Animation<double>? flashPulse;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.formBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FormNavBar(
              typeName: config.typeName,
              accent: config.accent,
              onCancel: onCancel,
              onTypeTap: onTypeTap,
              onSave: onSave,
              // Save stays enabled regardless of validity; an incomplete tap
              // names the missing field and flashes it instead (spec §3).
              canSave: true,
              locked: typeLocked,
            ),
            Expanded(
              child: NotificationListener<ScrollStartNotification>(
                // Scrolling the list is one of the two ways out of the keypad.
                onNotification: (n) {
                  if (keypadOpen && n.dragDetails != null) onDismissKeypad();
                  return false;
                },
                child: Listener(
                  // The other way out: a pointer anywhere that is not the
                  // hero. The hero re-opens on tap-up, so it wins the race.
                  onPointerDown: (_) {
                    if (keypadOpen) onDismissKeypad();
                  },
                  child: Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.only(top: 12 * s, bottom: 24 * s),
                        children: _body(context),
                      ),
                      // Keeps content from cutting abruptly at the nav bar.
                      IgnorePointer(
                        child: Container(
                          height: 12 * s,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.formBg,
                                Color(0x00000000),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // The pinned validation bar is gone (spec §3): Save in the nav bar
            // is the only commit, and it names/flashes what is missing on tap.
            if (keypadOpen)
              Padding(
                padding: EdgeInsets.only(top: 10 * s),
                child: NumericKeypad(onKey: onKey, onBackspace: onBackspace),
              ),
            SizedBox(height: bottomInset + 8 * s),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final hero = config.hero;
    final heroWidget = switch (hero) {
      NumericHero() => NumericHeroCard(
          label: hero.label,
          raw: hero.raw,
          currency: hero.currency,
          accent: config.accent,
          accentDim: config.accentDim,
          focused: keypadOpen,
          onTap: onHeroTap,
          onCurrencyTap: hero.onCurrencyTap,
        ),
      TextHero() => TextHeroCard(
          caption: hero.caption,
          placeholder: hero.placeholder,
          controller: hero.controller,
          focusNode: hero.focusNode,
        ),
    };
    return [
      // No section label: position alone marks the hero required.
      _FieldFlash(
        active: flashTarget == 'amount',
        pulse: flashPulse,
        radius: 16,
        child: heroWidget,
      ),
      for (final group in config.groups) ...[
        if (group.title != null) FormSectionLabel(group.title!),
        TxnCard(
          children: [
            for (final f in group.fields)
              _FieldFlash(
                active: f.flashId != null && f.flashId == flashTarget,
                pulse: flashPulse,
                radius: 0,
                child: TxnFieldRow(
                  icon: f.icon,
                  label: f.label,
                  value: f.value,
                  emptyText: f.emptyText,
                  // A flagged field's value goes red until it is filled (§3).
                  valueColor: (f.flashId != null && f.flashId == flashTarget)
                      ? AppColors.negative
                      : f.valueColor,
                  onTap: f.onTap,
                  hideLabel: f.hideLabel,
                  valueMaxLines: f.valueMaxLines,
                  semanticValue: f.semanticValue,
                  iconColor: f.iconColor,
                ),
              ),
          ],
        ),
        if (config.hint != null && group.title == AppLocalizations.of(context).qaGroupRequired.toUpperCase())
          HintStrip(spans: config.hint!.spans, accent: config.accent),
      ],
      FormToggleBar(toggles: config.toggles),
      if (config.action != null) FormAction(spec: config.action!),
      ...config.trailing,
    ];
  }
}

/// Wraps a hero or a field row and, while [active], pulses a red background
/// twice over the life of [pulse] (spec §3). Inert otherwise, so an unflagged
/// field renders exactly as before.
class _FieldFlash extends StatelessWidget {
  const _FieldFlash({
    required this.active,
    required this.pulse,
    required this.radius,
    required this.child,
  });

  final bool active;
  final Animation<double>? pulse;
  final double radius;
  final Widget child;

  // Two triangular humps across t ∈ [0,1].
  static double _hump(double t) {
    final phase = (t * 2) % 1.0;
    return phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  }

  @override
  Widget build(BuildContext context) {
    if (!active || pulse == null) return child;
    // A decoration painted behind the child — it changes no layout, so nothing
    // moves or resizes during the pulse (spec §3).
    return AnimatedBuilder(
      animation: pulse!,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color:
                AppColors.negative.withValues(alpha: 0.16 * _hump(pulse!.value)),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        );
      },
    );
  }
}
