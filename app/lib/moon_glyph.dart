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
