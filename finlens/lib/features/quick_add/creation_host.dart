import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../planner/edit_budget_screen.dart';
import '../planner/edit_goal_screen.dart';
import 'quick_add_sheet.dart';

/// Task 056 — one creation session: Quick Add, the goal editor and the budget
/// editor live in one route. Switching type shows a different form instead of
/// replacing the route, so every form keeps what was typed until the session
/// closes (Save, Cancel or back pop the route and dispose them all).
enum CreationForm { quickAdd, goal, budget }

CreationForm creationFormFor(QuickAddType t) => switch (t) {
      QuickAddType.newGoal => CreationForm.goal,
      QuickAddType.newBudget => CreationForm.budget,
      _ => CreationForm.quickAdd,
    };

/// Lets a hosted form ask the host to switch. Read with [maybeOf]; absent
/// outside a session (a form opened directly keeps the old pop-and-push).
class CreationSession extends InheritedWidget {
  const CreationSession(
      {super.key, required this.switchTo, required super.child});

  final void Function(QuickAddType next) switchTo;

  static CreationSession? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CreationSession>();

  @override
  bool updateShouldNotify(CreationSession oldWidget) => false;
}

/// How the host asks an already-built Quick Add to change type in place (a
/// ValueNotifier would stay silent when the requested type equals a stale
/// value, so this is a plain callback the screen registers).
class QuickAddTypeRequests {
  void Function(QuickAddType next)? _handler;
  void attach(void Function(QuickAddType next) handler) => _handler = handler;
  void detach() => _handler = null;
  void request(QuickAddType next) => _handler?.call(next);
}

/// Opens a creation session hosting every form. Used by [showQuickAdd] (non
/// editing), [openGoalEditor] (no goalId) and [startNewBudgetFlow].
Future<void> openCreationSession(
  BuildContext context, {
  required QuickAddType type,
  String? fixedFromAccountId,
  String? fixedToAccountId,
  String? initialFromAccountId,
  Txn? copyOf,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CreationHost(
        initialType: type,
        fixedFromAccountId: fixedFromAccountId,
        fixedToAccountId: fixedToAccountId,
        initialFromAccountId: initialFromAccountId,
        copyOf: copyOf,
      ),
    ),
  );
}

class CreationHost extends StatefulWidget {
  const CreationHost({
    super.key,
    required this.initialType,
    this.fixedFromAccountId,
    this.fixedToAccountId,
    this.initialFromAccountId,
    this.copyOf,
  });

  final QuickAddType initialType;
  final String? fixedFromAccountId;
  final String? fixedToAccountId;
  final String? initialFromAccountId;
  final Txn? copyOf;

  @override
  State<CreationHost> createState() => _CreationHostState();
}

class _CreationHostState extends State<CreationHost> {
  late CreationForm _current = creationFormFor(widget.initialType);
  final Map<CreationForm, Widget> _built = {};
  final _quickAddRequests = QuickAddTypeRequests();

  void _switchTo(QuickAddType next) {
    FocusManager.instance.primaryFocus?.unfocus();
    final form = creationFormFor(next);
    final alreadyBuilt = _built.containsKey(form);
    setState(() {
      _current = form;
      // First visit to Quick Add in this session (it started on Goal/Budget):
      // build it on the requested type.
      if (form == CreationForm.quickAdd && !alreadyBuilt) {
        _built[form] = _quickAdd(next);
      }
    });
    if (form == CreationForm.quickAdd && alreadyBuilt) {
      // Already built: it switches type in place, with per-type memory (§3).
      _quickAddRequests.request(next);
    }
  }

  Widget _quickAdd(QuickAddType type) => QuickAddScreen(
        initialType: type,
        // The entry point's account applies to the first Quick Add only.
        fixedFromAccountId: widget.fixedFromAccountId,
        fixedToAccountId: widget.fixedToAccountId,
        initialFromAccountId: widget.initialFromAccountId,
        copyOf: widget.copyOf,
        typeRequests: _quickAddRequests,
      );

  Widget _build(CreationForm f) => _built.putIfAbsent(
        f,
        () => switch (f) {
          CreationForm.quickAdd => _quickAdd(widget.initialType),
          CreationForm.goal => const EditGoalScreen(),
          CreationForm.budget => const EditBudgetScreen(),
        },
      );

  @override
  Widget build(BuildContext context) {
    _build(_current);
    return CreationSession(
      switchTo: _switchTo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final f in CreationForm.values)
            if (_built.containsKey(f))
              Offstage(
                offstage: f != _current,
                child: TickerMode(
                  enabled: f == _current,
                  child: ExcludeFocus(
                    excluding: f != _current,
                    child: KeyedSubtree(key: ValueKey(f), child: _built[f]!),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
