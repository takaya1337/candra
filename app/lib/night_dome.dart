import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'app_shell.dart';
import 'appearance.dart';
import 'system_palettes.dart';

/// The sky drawn at night whatever the side: on the light side a dome
/// (the ephemeris's, the star map's, Lintang Jawa's, Light's plan) sits on
/// a soft dark ground in the system's dark colours, so a sky is never
/// white (owner, 16 October 2026). On the dark side it is as it was.
class NightDome extends StatelessWidget {
  final Widget child;

  const NightDome({super.key, required this.child});

  /// Whether [context] is under a dome drawn at night on the light side:
  /// colours darkened for paper ([Legible]) are then shown as they are.
  static bool isNight(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Night>() != null;

  @override
  Widget build(BuildContext context) {
    if (!Legible.light) return child;
    final theme = SmTheme.of(context);
    final dark = SystemScope.of(context).value.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark.surfaceRaised,
          borderRadius: BorderRadius.circular(theme.radii.lg),
        ),
        child: SmTheme(
          data: theme.withColors(dark),
          child: _Night(child: child),
        ),
      ),
    );
  }
}

class _Night extends InheritedWidget {
  const _Night({required super.child});

  @override
  bool updateShouldNotify(_Night oldWidget) => false;
}
