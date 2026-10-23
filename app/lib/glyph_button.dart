import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

/// The line drawings a [GlyphButton] can carry.
enum Glyph {
  expand,
  copy,
  saveImage,
  yearView,
  monthView,
  today,
  journal,
  add,
  close,
  delete,
  edit,
  categories,
  save,
  bold,
  italic,
  strike,
  code,
  heading,
  list,
  quote,
  archive,
  share,
  import,
  reminder,
  sync,
  underline,
  footnote,
  back,
  calendar,
  place,
  bazi,
  mangsa,
  sky,
  stars,
  lintang,
  light,
  compass,
  salat,
  hilal,
  planets,
  lock,
  search,
  tag,
  utilities,
  menu,
  dayView,
  practice,
  start,
  stop,
  countdown,
  tally,
  reset;

  /// The glyphs of the house's bar, which are drawn filled while the house
  /// is in their room (`GlyphButton.here`).
  static const solids = {menu, utilities, practice, reminder, journal};
}

/// A framed button holding a small line drawing instead of a label. Every
/// glyph button of the same [size] has the same outline.
class GlyphButton extends StatelessWidget {
  final Glyph glyph;
  final VoidCallback onTap;

  /// Bar-sized (as tall as a bar button) or compact (for use inside rows).
  final bool compact;

  /// Bar height but only as wide as it is tall, for tight rows.
  final bool square;

  /// When set, holding the button fills it from the centre and then fires.
  final VoidCallback? onHold;

  /// Shows a small dot in the corner.
  final bool marked;

  /// Draws the frame and the glyph in the accent colour.
  final bool lit;

  /// Draws the frame and the glyph in this colour: for a button that
  /// destroys something.
  final Color? tint;

  /// A small figure in the corner, saying more about what the glyph
  /// stands for: the level of a heading.
  final String? badge;

  /// Filled with the accent, the glyph in the background's colour: the
  /// one button a screen is for.
  final bool filled;

  /// Lit from behind: in the house's bar, the room the house is in
  /// (see `House`). It comes and goes eased.
  final bool here;

  const GlyphButton({
    super.key,
    required this.glyph,
    required this.onTap,
    this.compact = false,
    this.square = false,
    this.onHold,
    this.marked = false,
    this.lit = false,
    this.tint,
    this.badge,
    this.filled = false,
    this.here = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;

    final radius = BorderRadius.circular(
      compact
          ? theme.radii.sm + 2
          : square
          ? theme.radii.md
          : theme.radii.lg,
    );

    // The border is drawn over the box rather than added around it, so the
    // outline is exactly padding plus glyph: a bar-sized button is as tall
    // as a bar button, and a compact one as tall as a line of title text.
    Widget body(BuildContext context, double holdProgress) =>
        TweenAnimationBuilder<double>(
          tween: Tween(end: here ? 1 : 0),
          duration: theme.motion.medium,
          curve: theme.motion.curve,
          builder: (context, lit, child) => DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                color: Color.lerp(
                  tint?.withValues(alpha: 0.7) ??
                      (this.lit ? theme.colors.accent : theme.colors.outline),
                  theme.colors.textFaint,
                  this.lit || tint != null ? 0 : lit,
                )!,
              ),
              borderRadius: radius,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: theme.colors.surfaceRaised.withValues(alpha: lit),
                child: child,
              ),
            ),
          ),
          child: _face(theme, spacing, holdProgress),
        );

    if (onHold == null) {
      return SmPressable(onTap: onTap, child: body(context, 0));
    }
    return SmHoldPressable(onTap: onTap, onHold: onHold!, builder: body);
  }

  Widget _face(SmThemeData theme, SmSpacing spacing, double holdProgress) =>
      CustomPaint(
        painter: SmRadialFillPainter(
          // Full, and solid, when filled.
          progress: filled ? 1 : holdProgress,
          color: theme.colors.accent.withValues(alpha: filled ? 1 : 0.45),
        ),
        child: Stack(
          // Centred, for a button made wider than its glyph needs.
          alignment: Alignment.center,
          children: [
            Padding(
              padding: compact
                  ? const EdgeInsets.all(6)
                  : square
                  ? EdgeInsets.all(spacing.sm + spacing.xs)
                  : EdgeInsets.symmetric(
                      horizontal: spacing.lg - spacing.xs,
                      vertical: spacing.sm + spacing.xs,
                    ),
              child: CustomPaint(
                // 16 matches the line height of a bar button's label.
                size: Size.square(compact ? 14 : 16),
                // The room the house is in: the glyph filled, in the
                // accent, glowing (owner, 20 October 2026).
                painter: _GlyphPainter(
                  glyph,
                  tint ??
                      (filled
                          ? theme.colors.background
                          : lit || here
                          ? theme.colors.accent
                          : compact
                          ? theme.colors.textSecondary
                          : theme.colors.textPrimary),
                  solid: here && Glyph.solids.contains(glyph),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                right: 5,
                bottom: 3,
                child: Text(
                  badge!,
                  style: theme.type.caption.copyWith(
                    fontSize: 9,
                    color: theme.colors.accent,
                  ),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedOpacity(
                opacity: marked ? 1 : 0,
                duration: theme.motion.medium,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// A glyph on its own, with no button round it: a small mark beside words.
class GlyphMark extends StatelessWidget {
  final Glyph glyph;
  final double size;
  final Color color;

  const GlyphMark({
    super.key,
    required this.glyph,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(glyph, color),
  );
}

/// A glyph as a picture, white on nothing, [pixels] square: for handing
/// to the phone's own side, which tints it and draws it in a button of
/// its own.
Future<Uint8List> glyphPng(
  Glyph glyph, {
  int pixels = 72,
  bool solid = false,
}) async {
  final recorder = ui.PictureRecorder();
  _GlyphPainter(
    glyph,
    const Color(0xFFFFFFFF),
    solid: solid,
  ).paint(Canvas(recorder), Size.square(pixels.toDouble()));
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

class _GlyphPainter extends CustomPainter {
  final Glyph glyph;
  final Color color;

  /// Drawn filled, with a glow under it: the bar's glyph for the room the
  /// house is in ([Glyph.solids]).
  final bool solid;

  const _GlyphPainter(this.glyph, this.color, {this.solid = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in a unit square and scaled up.
    canvas.scale(size.shortestSide);
    if (solid) {
      // The glow: the same shape, blurred, under it.
      canvas.saveLayer(
        const Rect.fromLTRB(-0.5, -0.5, 1.5, 1.5),
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 0.12, sigmaY: 0.12),
      );
      _solid(canvas);
      canvas.restore();
      _solid(canvas);
      return;
    }
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (glyph) {
      // Two arrows pulling apart towards opposite corners.
      case Glyph.expand:
        for (var corner = 0; corner < 2; corner++) {
          canvas.drawLine(
            const Offset(0.58, 0.42),
            const Offset(0.92, 0.08),
            line,
          );
          canvas.drawPath(
            Path()
              ..moveTo(0.62, 0.08)
              ..lineTo(0.92, 0.08)
              ..lineTo(0.92, 0.38),
            line,
          );
          canvas
            ..translate(1, 1)
            ..scale(-1, -1);
        }

      // One sheet in front of another.
      case Glyph.copy:
        const corner = Radius.circular(0.10);
        canvas.drawRRect(RRect.fromLTRBR(0.34, 0.30, 0.94, 0.94, corner), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.20, 0.70)
            ..lineTo(0.16, 0.70)
            ..arcToPoint(const Offset(0.06, 0.60), radius: corner)
            ..lineTo(0.06, 0.16)
            ..arcToPoint(const Offset(0.16, 0.06), radius: corner)
            ..lineTo(0.60, 0.06)
            ..arcToPoint(const Offset(0.70, 0.16), radius: corner)
            ..lineTo(0.70, 0.18),
          line,
        );

      // Many small months: a three-by-three of dots.
      case Glyph.yearView:
        final dot = Paint()..color = color;
        for (var row = 0; row < 3; row++) {
          for (var column = 0; column < 3; column++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  0.08 + column * 0.31,
                  0.08 + row * 0.31,
                  0.22,
                  0.22,
                ),
                const Radius.circular(0.05),
              ),
              dot,
            );
          }
        }

      // Bazi: the eight characters, four stems over four branches.
      case Glyph.bazi:
        final dot = Paint()..color = color;
        for (var row = 0; row < 2; row++) {
          for (var column = 0; column < 4; column++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  0.06 + column * 0.235,
                  0.2 + row * 0.34,
                  0.17,
                  0.26,
                ),
                const Radius.circular(0.04),
              ),
              dot,
            );
          }
        }

      // Mangsa: the wheel of the year, twelve arcs as long as their
      // mangsa, Kasa opening at the top.
      case Glyph.mangsa:
        const days = [41, 23, 24, 25, 27, 43, 43, 26, 25, 24, 23, 41];
        const gap = 0.2;
        final arc = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.13
          ..strokeCap = StrokeCap.butt;
        var start = -math.pi / 2;
        for (final length in days) {
          final sweep = length / 365 * 2 * math.pi;
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(0.5, 0.5), radius: 0.38),
            start + gap / 2,
            sweep - gap,
            false,
            arc,
          );
          start += sweep;
        }

      // Sky: the sun half risen over the horizon, the crescent moon
      // above.
      case Glyph.sky:
        final fill = Paint()..color = color;
        canvas.drawLine(
          const Offset(0.06, 0.74),
          const Offset(0.94, 0.74),
          line,
        );
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(0.38, 0.74), radius: 0.22),
          math.pi,
          math.pi,
          true,
          fill,
        );
        canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(
              Rect.fromCircle(center: const Offset(0.72, 0.26), radius: 0.15),
            ),
            Path()..addOval(
              Rect.fromCircle(center: const Offset(0.80, 0.21), radius: 0.13),
            ),
          ),
          fill,
        );

      // The star map: a small constellation, four stars joined, the
      // brightest larger.
      case Glyph.stars:
        final fill = Paint()..color = color;
        const points = [
          Offset(0.16, 0.70),
          Offset(0.40, 0.46),
          Offset(0.66, 0.58),
          Offset(0.84, 0.24),
        ];
        final thin = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.035
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k + 1 < points.length; k++) {
          canvas.drawLine(points[k], points[k + 1], thin);
        }
        for (final (k, p) in points.indexed) {
          canvas.drawCircle(p, k == 3 ? 0.10 : 0.065, fill);
        }

      // Lintang Jawa: Waluku, the plough, as Orion is drawn: four
      // corner stars and the three of the Belt across the middle.
      case Glyph.lintang:
        final fill = Paint()..color = color;
        const corners = [
          Offset(0.26, 0.16),
          Offset(0.76, 0.22),
          Offset(0.70, 0.84),
          Offset(0.22, 0.78),
        ];
        const belt = [
          Offset(0.38, 0.56),
          Offset(0.50, 0.50),
          Offset(0.62, 0.44),
        ];
        for (final (k, p) in corners.indexed) {
          canvas.drawCircle(p, k == 0 || k == 2 ? 0.085 : 0.065, fill);
        }
        for (final p in belt) {
          canvas.drawCircle(p, 0.06, fill);
        }

      // Light: a lens's aperture, six blades about an open middle.
      case Glyph.light:
        const c = Offset(0.5, 0.5);
        canvas.drawCircle(c, 0.4, line);
        final corners = [
          for (var k = 0; k < 6; k++)
            c +
                Offset(
                      math.cos(k * math.pi / 3 + math.pi / 6),
                      math.sin(k * math.pi / 3 + math.pi / 6),
                    ) *
                    0.17,
        ];
        for (var k = 0; k < 6; k++) {
          // Each blade's edge, from a corner of the opening on past the
          // next, out to the rim.
          final from = corners[k];
          final along = corners[(k + 1) % 6] - from;
          final unit = along / along.distance;
          final b = 2 * ((from - c).dx * unit.dx + (from - c).dy * unit.dy);
          final cc = (from - c).distanceSquared - 0.16;
          final t = (-b + math.sqrt(b * b - 4 * cc)) / 2;
          canvas.drawLine(from, from + unit * t, line);
        }

      // The compass: a ring, and a needle across it, its north half filled.
      case Glyph.compass:
        const c = Offset(0.5, 0.5);
        canvas.drawCircle(c, 0.4, line);
        final fill = Paint()..color = color;
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0.16)
            ..lineTo(0.6, 0.5)
            ..lineTo(0.4, 0.5)
            ..close(),
          fill,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0.84)
            ..lineTo(0.6, 0.5)
            ..lineTo(0.4, 0.5)
            ..close(),
          line,
        );

      // Search: a magnifying glass.
      case Glyph.search:
        canvas.drawCircle(const Offset(0.42, 0.42), 0.26, line);
        canvas.drawLine(
          const Offset(0.61, 0.61),
          const Offset(0.88, 0.88),
          line,
        );

      // Tag: a label with a hole, its point to the left.
      case Glyph.tag:
        canvas.drawPath(
          Path()
            ..moveTo(0.1, 0.5)
            ..lineTo(0.34, 0.22)
            ..lineTo(0.88, 0.22)
            ..lineTo(0.88, 0.78)
            ..lineTo(0.34, 0.78)
            ..close(),
          line,
        );
        canvas.drawCircle(
          const Offset(0.36, 0.5),
          0.06,
          Paint()..color = color,
        );

      // Lock: a padlock, its shackle closed.
      case Glyph.lock:
        canvas.drawRRect(
          RRect.fromLTRBR(0.2, 0.46, 0.8, 0.88, const Radius.circular(0.08)),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.32, 0.46)
            ..lineTo(0.32, 0.32)
            ..arcToPoint(
              const Offset(0.68, 0.32),
              radius: const Radius.circular(0.18),
            )
            ..lineTo(0.68, 0.46),
          line,
        );

      // Prayer times: a day's dial, midnight at the top, and the five
      // times marked on it.
      case Glyph.salat:
        canvas.drawCircle(const Offset(0.5, 0.5), 0.38, line);
        // Subuh, Zuhur, Asar, Magrib and Isya, about where they fall.
        for (final hour in const [4.5, 12.0, 15.2, 18.0, 19.2]) {
          final angle = hour / 24 * 2 * math.pi - math.pi / 2;
          canvas.drawCircle(
            Offset(0.5 + 0.38 * math.cos(angle), 0.5 + 0.38 * math.sin(angle)),
            0.06,
            Paint()..color = color,
          );
        }
        canvas.drawLine(const Offset(0.5, 0.5), const Offset(0.5, 0.24), line);

      // Hilal: a thin crescent over the horizon, as the evening after
      // the new moon shows it.
      case Glyph.hilal:
        canvas.drawLine(
          const Offset(0.08, 0.84),
          const Offset(0.92, 0.84),
          line,
        );
        // Horns up, as the young moon lies near the equator.
        canvas.drawPath(
          Path()
            ..arcTo(
              Rect.fromCircle(center: const Offset(0.5, 0.36), radius: 0.34),
              0.12,
              math.pi - 0.24,
              true,
            )
            ..arcTo(
              Rect.fromCircle(center: const Offset(0.5, 0.2), radius: 0.36),
              math.pi - 0.42,
              -(math.pi - 0.84),
              false,
            )
            ..close(),
          Paint()..color = color,
        );

      // Planets: a ringed planet.
      case Glyph.planets:
        canvas.drawCircle(const Offset(0.5, 0.5), 0.22, line);
        canvas.save();
        canvas.translate(0.5, 0.5);
        canvas.rotate(-0.38);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 0.88, height: 0.26),
          line,
        );
        canvas.restore();

      // Utilities: a four-pointed star, what a system has besides its
      // dates.
      case Glyph.utilities:
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0.06)
            ..quadraticBezierTo(0.54, 0.46, 0.94, 0.5)
            ..quadraticBezierTo(0.54, 0.54, 0.5, 0.94)
            ..quadraticBezierTo(0.46, 0.54, 0.06, 0.5)
            ..quadraticBezierTo(0.46, 0.46, 0.5, 0.06)
            ..close(),
          line,
        );

      // Menu: three lines, everything that has no button of its own.
      case Glyph.menu:
        for (final y in const [0.26, 0.5, 0.74]) {
          canvas.drawLine(Offset(0.14, y), Offset(0.86, y), line);
        }

      // Practice: a stopwatch, its hand at ten past.
      case Glyph.practice:
        canvas.drawCircle(const Offset(0.5, 0.56), 0.34, line);
        canvas.drawLine(const Offset(0.5, 0.22), const Offset(0.5, 0.08), line);
        canvas.drawLine(const Offset(0.4, 0.08), const Offset(0.6, 0.08), line);
        canvas.drawLine(
          const Offset(0.5, 0.56),
          const Offset(0.66, 0.42),
          line,
        );

      // Start: a triangle pointing on.
      case Glyph.start:
        canvas.drawPath(
          Path()
            ..moveTo(0.3, 0.16)
            ..lineTo(0.82, 0.5)
            ..lineTo(0.3, 0.84)
            ..close(),
          line,
        );

      // Countdown: an hourglass.
      case Glyph.countdown:
        canvas.drawPath(
          Path()
            ..moveTo(0.24, 0.1)
            ..lineTo(0.76, 0.1)
            ..lineTo(0.5, 0.5)
            ..lineTo(0.76, 0.9)
            ..lineTo(0.24, 0.9)
            ..lineTo(0.5, 0.5)
            ..close(),
          line,
        );

      // The tally: a hand counter, its window and the button on top.
      case Glyph.tally:
        canvas.drawRRect(
          RRect.fromLTRBR(0.16, 0.26, 0.84, 0.9, const Radius.circular(0.16)),
          line,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(0.32, 0.44, 0.68, 0.64, const Radius.circular(0.05)),
          line,
        );
        canvas.drawLine(const Offset(0.5, 0.26), const Offset(0.5, 0.1), line);
        canvas.drawLine(const Offset(0.38, 0.1), const Offset(0.62, 0.1), line);

      // Reset: one arrow come round to where it began.
      case Glyph.reset:
        canvas.drawArc(
          const Rect.fromLTRB(0.14, 0.14, 0.86, 0.86),
          -1.2,
          5.0,
          false,
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.52, 0.06)
            ..lineTo(0.68, 0.18)
            ..lineTo(0.52, 0.3),
          line,
        );

      // Stop: a square.
      case Glyph.stop:
        canvas.drawRRect(
          RRect.fromLTRBR(0.2, 0.2, 0.8, 0.8, const Radius.circular(0.08)),
          line,
        );

      // One day: a sheet torn from a block, its number a single mark.
      case Glyph.dayView:
        canvas.drawRRect(
          RRect.fromLTRBR(0.16, 0.12, 0.84, 0.90, const Radius.circular(0.12)),
          line,
        );
        canvas.drawLine(
          const Offset(0.16, 0.32),
          const Offset(0.84, 0.32),
          line,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(0.38, 0.46, 0.62, 0.76, const Radius.circular(0.05)),
          Paint()..color = color,
        );

      // One month: a single framed sheet with a header line.
      case Glyph.monthView:
        canvas.drawRRect(
          RRect.fromLTRBR(0.10, 0.12, 0.90, 0.90, const Radius.circular(0.12)),
          line,
        );
        canvas.drawLine(
          const Offset(0.10, 0.36),
          const Offset(0.90, 0.36),
          line,
        );

      // Today: one point at the centre of a ring.
      case Glyph.today:
        canvas.drawCircle(const Offset(0.5, 0.5), 0.40, line);
        canvas.drawCircle(const Offset(0.5, 0.5), 0.13, Paint()..color = color);

      // The journal: an open book.
      case Glyph.journal:
        canvas.drawLine(const Offset(0.5, 0.22), const Offset(0.5, 0.88), line);
        for (final side in [1.0, -1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(0.5, 0.22)
              ..cubicTo(
                0.5 + side * 0.14,
                0.10,
                0.5 + side * 0.32,
                0.10,
                0.5 + side * 0.44,
                0.16,
              )
              ..lineTo(0.5 + side * 0.44, 0.82)
              ..cubicTo(
                0.5 + side * 0.32,
                0.76,
                0.5 + side * 0.14,
                0.76,
                0.5,
                0.88,
              ),
            line,
          );
        }

      // New: a plus.
      case Glyph.add:
        canvas.drawLine(const Offset(0.5, 0.12), const Offset(0.5, 0.88), line);
        canvas.drawLine(const Offset(0.12, 0.5), const Offset(0.88, 0.5), line);

      // Leave without saving: a cross.
      case Glyph.close:
        canvas.drawLine(
          const Offset(0.16, 0.16),
          const Offset(0.84, 0.84),
          line,
        );
        canvas.drawLine(
          const Offset(0.84, 0.16),
          const Offset(0.16, 0.84),
          line,
        );

      // Categories: a card with the strips of others showing above it.
      case Glyph.categories:
        const corner = Radius.circular(0.08);
        canvas.drawRRect(RRect.fromLTRBR(0.08, 0.50, 0.92, 0.92, corner), line);
        for (final y in [0.32, 0.14]) {
          canvas.drawPath(
            Path()
              ..moveTo(0.08, y + 0.18)
              ..lineTo(0.08, y + 0.06)
              ..arcToPoint(Offset(0.16, y - 0.02), radius: corner)
              ..lineTo(0.84, y - 0.02)
              ..arcToPoint(Offset(0.92, y + 0.06), radius: corner)
              ..lineTo(0.92, y + 0.18),
            line,
          );
        }

      // Edit: a pencil.
      case Glyph.edit:
        canvas.drawPath(
          Path()
            ..moveTo(0.12, 0.88)
            ..lineTo(0.18, 0.64)
            ..lineTo(0.68, 0.14)
            ..lineTo(0.86, 0.32)
            ..lineTo(0.36, 0.82)
            ..close(),
          line,
        );
        canvas.drawLine(
          const Offset(0.56, 0.26),
          const Offset(0.74, 0.44),
          line,
        );

      // Delete: a bin with its lid.
      case Glyph.delete:
        canvas.drawLine(
          const Offset(0.10, 0.24),
          const Offset(0.90, 0.24),
          line,
        );
        canvas.drawLine(
          const Offset(0.38, 0.10),
          const Offset(0.62, 0.10),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.22, 0.24)
            ..lineTo(0.28, 0.92)
            ..lineTo(0.72, 0.92)
            ..lineTo(0.78, 0.24),
          line,
        );
        canvas.drawLine(
          const Offset(0.42, 0.42),
          const Offset(0.42, 0.74),
          line,
        );
        canvas.drawLine(
          const Offset(0.58, 0.42),
          const Offset(0.58, 0.74),
          line,
        );

      // An arrow dropping into a tray.
      case Glyph.saveImage:
        canvas.drawLine(const Offset(0.5, 0.06), const Offset(0.5, 0.64), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.26, 0.42)
            ..lineTo(0.5, 0.66)
            ..lineTo(0.74, 0.42),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.08, 0.66)
            ..lineTo(0.08, 0.92)
            ..lineTo(0.92, 0.92)
            ..lineTo(0.92, 0.66),
          line,
        );

      // Back: an arrow to the left. One step back, wherever that is.
      case Glyph.back:
        canvas.drawLine(const Offset(0.14, 0.5), const Offset(0.86, 0.5), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.44, 0.2)
            ..lineTo(0.14, 0.5)
            ..lineTo(0.44, 0.8),
          line,
        );

      // The calendar: a page with its two rings, a day marked on it.
      // Only on a button that lands on the month screen.
      case Glyph.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(0.1, 0.2, 0.9, 0.92),
            const Radius.circular(0.1),
          ),
          line,
        );
        canvas.drawLine(const Offset(0.1, 0.44), const Offset(0.9, 0.44), line);
        for (final x in [0.32, 0.68]) {
          canvas.drawLine(Offset(x, 0.08), Offset(x, 0.28), line);
        }
        canvas.drawCircle(
          const Offset(0.36, 0.68),
          0.07,
          Paint()..color = color,
        );

      // A place: a map pin.
      case Glyph.place:
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0.94)
            ..cubicTo(0.36, 0.74, 0.18, 0.58, 0.18, 0.38)
            ..arcToPoint(
              const Offset(0.82, 0.38),
              radius: const Radius.circular(0.32),
            )
            ..cubicTo(0.82, 0.58, 0.64, 0.74, 0.5, 0.94)
            ..close(),
          line,
        );
        canvas.drawCircle(const Offset(0.5, 0.38), 0.1, Paint()..color = color);

      // Save: a tick.
      case Glyph.save:
        canvas.drawPath(
          Path()
            ..moveTo(0.14, 0.54)
            ..lineTo(0.4, 0.8)
            ..lineTo(0.88, 0.2),
          line,
        );

      // Bold: a heavy B.
      case Glyph.bold:
        canvas.drawPath(
          Path()
            ..moveTo(0.28, 0.48)
            ..lineTo(0.28, 0.12)
            ..lineTo(0.52, 0.12)
            ..arcToPoint(
              const Offset(0.52, 0.48),
              radius: const Radius.circular(0.18),
            )
            ..lineTo(0.28, 0.48)
            ..lineTo(0.28, 0.88)
            ..lineTo(0.56, 0.88)
            ..arcToPoint(
              const Offset(0.56, 0.48),
              radius: const Radius.circular(0.2),
              clockwise: false,
            ),
          line..strokeWidth = 0.15,
        );

      // Italic: a leaning I.
      case Glyph.italic:
        canvas.drawLine(
          const Offset(0.62, 0.12),
          const Offset(0.38, 0.88),
          line,
        );
        canvas.drawLine(
          const Offset(0.46, 0.12),
          const Offset(0.8, 0.12),
          line,
        );
        canvas.drawLine(
          const Offset(0.2, 0.88),
          const Offset(0.54, 0.88),
          line,
        );

      // Struck through: an S with a line across it.
      case Glyph.strike:
        canvas.drawPath(
          Path()
            ..moveTo(0.72, 0.26)
            ..cubicTo(0.62, 0.04, 0.24, 0.08, 0.27, 0.32)
            ..cubicTo(0.3, 0.54, 0.74, 0.44, 0.74, 0.68)
            ..cubicTo(0.74, 0.94, 0.36, 0.96, 0.25, 0.74),
          line,
        );
        canvas.drawLine(const Offset(0.08, 0.5), const Offset(0.92, 0.5), line);

      // Code: a pair of angle brackets.
      case Glyph.code:
        canvas.drawPath(
          Path()
            ..moveTo(0.36, 0.24)
            ..lineTo(0.1, 0.5)
            ..lineTo(0.36, 0.76)
            ..moveTo(0.64, 0.24)
            ..lineTo(0.9, 0.5)
            ..lineTo(0.64, 0.76),
          line,
        );

      // Heading: an H.
      case Glyph.heading:
        canvas.drawLine(
          const Offset(0.22, 0.14),
          const Offset(0.22, 0.86),
          line,
        );
        canvas.drawLine(
          const Offset(0.78, 0.14),
          const Offset(0.78, 0.86),
          line,
        );
        canvas.drawLine(const Offset(0.22, 0.5), const Offset(0.78, 0.5), line);

      // List: three bullets, each with its line.
      case Glyph.list:
        for (final y in const [0.22, 0.5, 0.78]) {
          canvas.drawCircle(Offset(0.14, y), 0.055, Paint()..color = color);
          canvas.drawLine(Offset(0.34, y), Offset(0.9, y), line);
        }

      // Quote: a bar down the side of two lines.
      case Glyph.quote:
        canvas.drawLine(
          const Offset(0.14, 0.16),
          const Offset(0.14, 0.84),
          line..strokeWidth = 0.13,
        );
        line.strokeWidth = 0.09;
        canvas.drawLine(
          const Offset(0.38, 0.34),
          const Offset(0.9, 0.34),
          line,
        );
        canvas.drawLine(
          const Offset(0.38, 0.66),
          const Offset(0.72, 0.66),
          line,
        );
      // The journal as a file: a box with its lid.
      case Glyph.archive:
        canvas.drawRect(const Rect.fromLTRB(0.08, 0.14, 0.92, 0.38), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.16, 0.38)
            ..lineTo(0.16, 0.88)
            ..lineTo(0.84, 0.88)
            ..lineTo(0.84, 0.38),
          line,
        );
        canvas.drawLine(const Offset(0.4, 0.58), const Offset(0.6, 0.58), line);

      // Share: an arrow rising out of a tray.
      case Glyph.share:
        canvas.drawLine(const Offset(0.5, 0.64), const Offset(0.5, 0.08), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.26, 0.3)
            ..lineTo(0.5, 0.06)
            ..lineTo(0.74, 0.3),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.08, 0.66)
            ..lineTo(0.08, 0.92)
            ..lineTo(0.92, 0.92)
            ..lineTo(0.92, 0.66),
          line,
        );

      // Import: an arrow going in through an open side.
      case Glyph.import:
        canvas.drawLine(const Offset(0.06, 0.5), const Offset(0.62, 0.5), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.4, 0.28)
            ..lineTo(0.64, 0.5)
            ..lineTo(0.4, 0.72),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.56, 0.1)
            ..lineTo(0.92, 0.1)
            ..lineTo(0.92, 0.9)
            ..lineTo(0.56, 0.9),
          line,
        );
      // Reminders: a bell.
      case Glyph.reminder:
        canvas.drawPath(
          Path()
            ..moveTo(0.1, 0.74)
            ..lineTo(0.9, 0.74)
            ..lineTo(0.76, 0.56)
            ..lineTo(0.76, 0.4)
            ..arcToPoint(
              const Offset(0.24, 0.4),
              radius: const Radius.circular(0.26),
              clockwise: false,
            )
            ..lineTo(0.24, 0.56)
            ..close(),
          line,
        );
        canvas.drawLine(const Offset(0.5, 0.06), const Offset(0.5, 0.14), line);
        canvas.drawLine(const Offset(0.42, 0.9), const Offset(0.58, 0.9), line);
      // Sync: two arrows chasing each other round.
      case Glyph.sync:
        for (var half = 0; half < 2; half++) {
          canvas.drawArc(
            const Rect.fromLTRB(0.14, 0.14, 0.86, 0.86),
            -2.9,
            2.3,
            false,
            line,
          );
          canvas.drawPath(
            Path()
              ..moveTo(0.62, 0.12)
              ..lineTo(0.86, 0.26)
              ..lineTo(0.7, 0.46),
            line,
          );
          canvas
            ..translate(1, 1)
            ..scale(-1, -1);
        }
      // Underline: a U with a line beneath it.
      case Glyph.underline:
        canvas.drawPath(
          Path()
            ..moveTo(0.26, 0.1)
            ..lineTo(0.26, 0.44)
            ..arcToPoint(
              const Offset(0.74, 0.44),
              radius: const Radius.circular(0.24),
              clockwise: false,
            )
            ..lineTo(0.74, 0.1),
          line,
        );
        canvas.drawLine(const Offset(0.16, 0.9), const Offset(0.84, 0.9), line);

      // Footnote: a line of text with a small figure raised at its end.
      case Glyph.footnote:
        canvas.drawLine(const Offset(0.08, 0.5), const Offset(0.56, 0.5), line);
        canvas.drawLine(const Offset(0.08, 0.8), const Offset(0.8, 0.8), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.7, 0.2)
            ..lineTo(0.84, 0.08)
            ..lineTo(0.84, 0.52),
          line,
        );
    }
  }

  // The filled forms of the bar's glyphs.
  void _solid(Canvas canvas) {
    final fill = Paint()..color = color;
    final thick = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // What is cut out of a filled shape, to show through.
    final cut = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1
      ..strokeCap = StrokeCap.round;
    switch (glyph) {
      // Three bars, full.
      case Glyph.menu:
        for (final y in const [0.24, 0.5, 0.76]) {
          canvas.drawRRect(
            RRect.fromLTRBR(
              0.1,
              y - 0.08,
              0.9,
              y + 0.08,
              const Radius.circular(0.08),
            ),
            fill,
          );
        }
      // The star, full.
      case Glyph.utilities:
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0.02)
            ..quadraticBezierTo(0.56, 0.44, 0.98, 0.5)
            ..quadraticBezierTo(0.56, 0.56, 0.5, 0.98)
            ..quadraticBezierTo(0.44, 0.56, 0.02, 0.5)
            ..quadraticBezierTo(0.44, 0.44, 0.5, 0.02)
            ..close(),
          fill,
        );
      // The stopwatch's face full, its hand cut out of it.
      case Glyph.practice:
        canvas.drawLine(
          const Offset(0.5, 0.22),
          const Offset(0.5, 0.08),
          thick,
        );
        canvas.drawLine(
          const Offset(0.38, 0.08),
          const Offset(0.62, 0.08),
          thick,
        );
        canvas.saveLayer(const Rect.fromLTRB(0, 0, 1, 1), Paint());
        canvas.drawCircle(const Offset(0.5, 0.56), 0.39, fill);
        canvas.drawLine(const Offset(0.5, 0.56), const Offset(0.66, 0.42), cut);
        canvas.restore();
      // The bell full, its clapper and its ring.
      case Glyph.reminder:
        canvas.drawPath(
          Path()
            ..moveTo(0.06, 0.78)
            ..lineTo(0.94, 0.78)
            ..lineTo(0.8, 0.58)
            ..lineTo(0.8, 0.4)
            ..arcToPoint(
              const Offset(0.2, 0.4),
              radius: const Radius.circular(0.3),
              clockwise: false,
            )
            ..lineTo(0.2, 0.58)
            ..close(),
          fill,
        );
        canvas.drawLine(
          const Offset(0.5, 0.04),
          const Offset(0.5, 0.12),
          thick,
        );
        canvas.drawLine(
          const Offset(0.4, 0.91),
          const Offset(0.6, 0.91),
          thick,
        );
      // The book's two leaves full, the spine between them.
      case Glyph.journal:
        for (final side in [1.0, -1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(0.5 + side * 0.04, 0.2)
              ..cubicTo(
                0.5 + side * 0.16,
                0.07,
                0.5 + side * 0.34,
                0.07,
                0.5 + side * 0.48,
                0.13,
              )
              ..lineTo(0.5 + side * 0.48, 0.84)
              ..cubicTo(
                0.5 + side * 0.34,
                0.78,
                0.5 + side * 0.16,
                0.78,
                0.5 + side * 0.04,
                0.9,
              )
              ..close(),
            fill,
          );
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.solid != solid;
}

/// The button that deletes everything in front, in the journal (the card)
/// and in the reminders (the category's) alike: a red trash can at the
/// top right of the screen. Faint, and deaf, where there is nothing to
/// delete.
class DeleteCardButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const DeleteCardButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  /// Brighter than the Sunday red it began as (owner, 20 October 2026).
  static const red = Color(0xFFFF6B47);

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.25,
    child: IgnorePointer(
      ignoring: !enabled,
      child: GlyphButton(
        key: const ValueKey('delete-card'),
        glyph: Glyph.delete,
        square: true,
        tint: red,
        onTap: onTap,
      ),
    ),
  );
}
