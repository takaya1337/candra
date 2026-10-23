import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'appearance.dart';

/// The moon | sun pill, made as the EN | ID one is: a raised thumb under
/// the side the app is on, and its mark lit. A touch anywhere on it
/// switches to the other side. Until a side is chosen it
/// shows the phone's; choosing the phone's side goes back to following
/// the phone (see [AppearanceController]).
class AppearanceToggle extends StatelessWidget {
  const AppearanceToggle({super.key});

  static const _segmentWidth = 38.0;
  static const _height = 30.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final motion = theme.motion;
    final controller = AppearanceScope.of(context);
    final phone = MediaQuery.platformBrightnessOf(context);
    final side = controller.of(phone);
    final radius = BorderRadius.circular(_height / 2);

    return DecoratedBox(
      key: const ValueKey('appearance-toggle'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: radius,
      ),
      child: SizedBox(
        width: _segmentWidth * 2,
        height: _height,
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: side == Brightness.dark
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: motion.medium,
              curve: motion.transitionCurve,
              child: Container(
                width: _segmentWidth,
                height: _height,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: radius,
                ),
              ),
            ),
            Row(
              children: [
                for (final option in [Brightness.dark, Brightness.light])
                  GestureDetector(
                    key: ValueKey('appearance-${option.name}'),
                    behavior: HitTestBehavior.opaque,
                    // Either half switches to the other side: the pill is
                    // one button (owner, 16 October 2026).
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.choose(
                        side == Brightness.dark
                            ? Brightness.light
                            : Brightness.dark,
                        phone,
                      );
                    },
                    child: SizedBox(
                      width: _segmentWidth,
                      height: _height,
                      child: Center(
                        child: CustomPaint(
                          size: const Size.square(13),
                          painter: _SideMark(
                            side: option,
                            color: option == side
                                ? colors.accent
                                : colors.textFaint,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A crescent for the dark side, a sun with eight rays for the light.
class _SideMark extends CustomPainter {
  final Brightness side;
  final Color color;

  const _SideMark({required this.side, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (side == Brightness.dark) {
      // The disc less a disc moved up and to the right.
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: centre, radius: r * 0.92)),
        Path()..addOval(
          Rect.fromCircle(
            center: centre + Offset(r * 0.42, -r * 0.34),
            radius: r * 0.78,
          ),
        ),
      );
      canvas.drawPath(moon, paint);
      return;
    }
    canvas.drawCircle(centre, r * 0.42, paint);
    final rays = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(centre + d * r * 0.66, centre + d * r * 0.98, rays);
    }
  }

  @override
  bool shouldRepaint(_SideMark old) => old.side != side || old.color != color;
}
