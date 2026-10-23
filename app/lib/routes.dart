import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'edge_swipe_back.dart';

/// A route that fades its screen in and out, as every screen here does.
/// On an iPhone the screen can also be drawn off from either edge to go
/// back ([EdgeSwipeBack]).
PageRouteBuilder<T> fadeRoute<T>(BuildContext context, WidgetBuilder builder) {
  final motion = SmTheme.of(context).motion;
  return PageRouteBuilder<T>(
    transitionDuration: motion.medium,
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, _, _) => EdgeSwipeBack(child: builder(context)),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    ),
  );
}

/// The day a journal or reminders screen was left on.
///
/// The two can be switched between, each taking the other's place, and
/// the one left hands on the promise of the one that took over: so
/// [result] may be a day, or a promise of one, any number of times over.
Future<CivilDate?> dayLeftOn(Object? result) async {
  while (result is Future) {
    result = await result;
  }
  return result is CivilDate ? result : null;
}

/// Puts [route] in the place of the screen [context] is on, handing that
/// screen's caller the new one's result.
void switchTo(BuildContext context, Route<Object?> route) =>
    Navigator.of(context).pushReplacement(route, result: route.popped);
