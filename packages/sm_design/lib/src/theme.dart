import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Makes [data] available to every widget below it via [SmTheme.of].
class SmTheme extends InheritedWidget {
  final SmThemeData data;

  const SmTheme({super.key, required this.data, required super.child});

  static SmThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<SmTheme>();
    assert(theme != null, 'No SmTheme found above this widget');
    return theme!.data;
  }

  @override
  bool updateShouldNotify(SmTheme oldWidget) => data != oldWidget.data;
}

/// An [SmTheme] whose colours glide to each new value instead of snapping.
/// Retargeting mid-flight continues from the colour currently on screen.
class AnimatedSmTheme extends ImplicitlyAnimatedWidget {
  final SmThemeData data;
  final Widget child;

  const AnimatedSmTheme({
    super.key,
    required this.data,
    required this.child,
    required super.duration,
    super.curve,
  });

  @override
  AnimatedWidgetBaseState<AnimatedSmTheme> createState() =>
      _AnimatedSmThemeState();
}

class _AnimatedSmThemeState extends AnimatedWidgetBaseState<AnimatedSmTheme> {
  _SmColorsTween? _colors;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _colors = visitor(
      _colors,
      widget.data.colors,
      (dynamic value) => _SmColorsTween(begin: value as SmColors),
    ) as _SmColorsTween?;
  }

  @override
  Widget build(BuildContext context) => SmTheme(
    data: widget.data.withColors(_colors!.evaluate(animation)),
    child: widget.child,
  );
}

class _SmColorsTween extends Tween<SmColors> {
  _SmColorsTween({super.begin});

  @override
  SmColors lerp(double t) => SmColors.lerp(begin!, end!, t);
}
