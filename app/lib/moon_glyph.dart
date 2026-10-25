import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';

/// A small drawing of the moon's disc as it is lit on a given day.
class MoonGlyph extends StatelessWidget {
  final Moon moon;
  final double size;
  final Color color;

  const MoonGlyph({
    super.key,
    required this.moon,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MoonPainter(
      illumination: moon.illumination,
      waxing: moon.elongation < 180,
      color: color,
    ),
  );
}

/// The moon's disc lit by a fraction given outright: for a moment
/// rather than a day.
class MoonFaceGlyph extends StatelessWidget {
  final double illumination;
  final bool waxing;
  final double size;
  final Color color;

  const MoonFaceGlyph({
    super.key,
    required this.illumination,
    required this.waxing,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MoonPainter(
      illumination: illumination,
      waxing: waxing,
      color: color,
    ),
  );
}

class _MoonPainter extends CustomPainter {
  final double illumination;
  final bool waxing;
  final Color color;

  const _MoonPainter({
    required this.illumination,
    required this.waxing,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    canvas.translate(size.width / 2, size.height / 2);

    // The whole disc as a faint ring, so a new moon is still a moon.
    canvas.drawCircle(
      Offset.zero,
      radius - 0.5,
      Paint()
        ..color = color.withValues(alpha: color.a * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (illumination < 0.02) return;

    // Drawn lit on the right (waxing) and mirrored for a waning moon. The
    // lit area is the right half-disc, cut or extended by the terminator:
    // a half-ellipse that bulges right for a crescent, left for a gibbous.
    if (!waxing) canvas.scale(-1, 1);
    final terminator = radius * (1 - 2 * illumination);
    final lit = Path()
      ..moveTo(0, -radius)
      ..arcToPoint(Offset(0, radius), radius: Radius.circular(radius))
      ..arcToPoint(
        Offset(0, -radius),
        radius: Radius.elliptical(terminator.abs(), radius),
        clockwise: terminator < 0,
      );
    canvas.drawPath(lit, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) =>
      oldDelegate.illumination != illumination ||
      oldDelegate.waxing != waxing ||
      oldDelegate.color != color;
}

/// The moon of a day drawing itself, as the sigil's moons do (owner, 26
/// October 2026: "animating it the same way we're animating my glyphs"):
/// the pen goes once round the rim from the top, a dot at its tip, and
/// then the lit part waxes to the day's phase, fading in as it grows.
/// Where the phone asks for less motion it stands drawn at once.
class TracedMoon extends StatefulWidget {
  final Moon moon;
  final double size;
  final Color color;

  /// How long the drawing takes.
  static const duration = Duration(milliseconds: 1600);

  const TracedMoon({
    super.key,
    required this.moon,
    required this.size,
    required this.color,
  });

  @override
  State<TracedMoon> createState() => _TracedMoonState();
}

class _TracedMoonState extends State<TracedMoon>
    with SingleTickerProviderStateMixin {
  late final _drawing = AnimationController(
    vsync: this,
    duration: TracedMoon.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _drawing.value = 1;
    } else if (!_drawing.isAnimating && _drawing.value == 0) {
      _drawing.forward();
    }
  }

  @override
  void dispose() {
    _drawing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _TracedMoonPainter(
        drawing: _drawing,
        illumination: widget.moon.illumination,
        waxing: widget.moon.elongation < 180,
        color: widget.color,
      ),
    ),
  );
}

class _TracedMoonPainter extends CustomPainter {
  final Animation<double> drawing;
  final double illumination;
  final bool waxing;
  final Color color;

  _TracedMoonPainter({
    required this.drawing,
    required this.illumination,
    required this.waxing,
    required this.color,
  }) : super(repaint: drawing);

  // The rim over the first part of the drawing, the light over the rest,
  // the two overlapping a little, as the sigil's steps do.
  static const _rimEnd = 0.5;
  static const _waxFrom = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    final t = drawing.value;
    final radius = size.shortestSide / 2;
    final stroke = math.max(1.0, radius * 0.06);
    canvas.translate(size.width / 2, size.height / 2);

    final rim = Curves.easeInOut.transform((t / _rimEnd).clamp(0.0, 1.0));
    if (rim > 0) {
      final box = Rect.fromCircle(center: Offset.zero, radius: radius - stroke);
      final sweep = 2 * math.pi * rim;
      final pen = Paint()
        ..color = color.withValues(alpha: color.a * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      // A whole turn as two halves, as the sigil lays its rings.
      if (rim >= 1) {
        canvas.drawPath(
          Path()
            ..addArc(box, -math.pi / 2, math.pi)
            ..arcTo(box, math.pi / 2, math.pi, false),
          pen,
        );
      } else {
        canvas.drawArc(box, -math.pi / 2, sweep, false, pen);
        // The pen's tip.
        final at = -math.pi / 2 + sweep;
        canvas.drawCircle(
          Offset(math.cos(at), math.sin(at)) * (radius - stroke),
          stroke * 1.4,
          Paint()..color = color,
        );
      }
    }

    final wax = Curves.easeOutCubic.transform(
      ((t - _waxFrom) / (1 - _waxFrom)).clamp(0.0, 1.0),
    );
    final lit = illumination * wax;
    if (wax <= 0 || illumination < 0.02) return;
    if (!waxing) canvas.scale(-1, 1);
    final terminator = radius * (1 - 2 * lit);
    final path = Path()
      ..moveTo(0, -radius)
      ..arcToPoint(Offset(0, radius), radius: Radius.circular(radius))
      ..arcToPoint(
        Offset(0, -radius),
        radius: Radius.elliptical(math.max(terminator.abs(), 0.01), radius),
        clockwise: terminator < 0,
      );
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: color.a * wax),
    );
  }

  @override
  bool shouldRepaint(_TracedMoonPainter old) =>
      old.illumination != illumination ||
      old.waxing != waxing ||
      old.color != color ||
      old.drawing != drawing;
}
