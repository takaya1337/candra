import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';

// The pictures of the I Ching: a hexagram or a trigram drawn, the coins
// thrown, the stalks counted.

/// A hexagram drawn: six places from the bottom up, each a whole line,
/// a broken one, or still empty. A line that changes is drawn in the
/// mark's colour, glowing, with no sign on it.
class HexagramFigure extends StatelessWidget {
  /// The lines so far, from the bottom up; fewer than six leaves the
  /// rest as places waiting.
  final List<LineValue> lines;
  final double width;
  final Color color;
  final Color faint;
  final Color mark;

  /// The lines the cast is still to give, drawn as places waiting: six
  /// for a hexagram, three for a trigram.
  final int places;

  const HexagramFigure({
    super.key,
    required this.lines,
    required this.width,
    required this.color,
    required this.faint,
    required this.mark,
    this.places = 6,
  });

  /// A figure of whole (true) and broken lines at rest, bottom up.
  HexagramFigure.still({
    super.key,
    required List<bool> figure,
    required this.width,
    required this.color,
  }) : lines = [
         for (final whole in figure)
           whole ? LineValue.youngYang : LineValue.youngYin,
       ],
       faint = color,
       mark = color,
       places = figure.length;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, width * 0.86 * places / 6),
    painter: _FigurePainter(List.of(lines), color, faint, mark, places),
  );
}

class _FigurePainter extends CustomPainter {
  final List<LineValue> lines;
  final Color color;
  final Color faint;
  final Color mark;
  final int places;

  const _FigurePainter(
    this.lines,
    this.color,
    this.faint,
    this.mark,
    this.places,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // A line that changes is brighter than the lines at rest: the mark's
    // colour taken toward white where the lines are light (dark side),
    // toward black where they are dark (light side).
    final lit = Color.lerp(
      mark,
      color.computeLuminance() > 0.5
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF000000),
      0.15,
    )!;
    final step = size.height / places;
    final thick = step * 0.46;
    // Too small a figure (the manual's chips) would drown in its glow.
    final glowing = thick >= minGlow;
    for (var i = 0; i < places; i++) {
      // Place 0 is the bottom line.
      final y = size.height - step * (i + 0.5);
      final cast = i < lines.length ? lines[i] : null;
      final paint = Paint()
        ..color = cast == null
            ? faint
            : (cast.changes ? (glowing ? lit : mark) : color)
        ..strokeWidth = cast == null ? 1 : thick
        ..strokeCap = StrokeCap.butt;
      if (cast == null) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        continue;
      }
      final gap = size.width * 0.16;
      final segments = cast.isYang
          ? [(Offset(0, y), Offset(size.width, y))]
          : [
              (Offset(0, y), Offset(size.width / 2 - gap / 2, y)),
              (Offset(size.width / 2 + gap / 2, y), Offset(size.width, y)),
            ];
      if (cast.changes && glowing) {
        // A line that changes glows: a wide soft halo and a closer one
        // under it, in the mark's colour.
        for (final (alpha, spread, blur) in glows) {
          final glow = Paint()
            ..color = mark.withValues(alpha: alpha)
            ..strokeWidth = thick * spread
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, thick * blur);
          for (final (from, to) in segments) {
            canvas.drawLine(from, to, glow);
          }
        }
      }
      for (final (from, to) in segments) {
        canvas.drawLine(from, to, paint);
      }
    }
  }

  /// The glow of a line that changes: (opacity, width, blur), each as a
  /// share of the line's thickness, the wide one first.
  /// The thinnest line, in logical pixels, that is drawn glowing.
  static const minGlow = 4.0;

  static const glows = [(0.8, 2.8, 1.1), (1.0, 1.5, 0.4)];

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.lines.length != lines.length ||
      old.places != places ||
      old.color != color ||
      old.faint != faint ||
      old.mark != mark ||
      !_same(old.lines, lines);

  static bool _same(List<LineValue> a, List<LineValue> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Three cash coins thrown: they rise, turn over and over, and come
/// down each on the side it was cast to. The face has writing round the
/// square hole; the back is blank.
class CoinsPainter extends CustomPainter {
  final CoinThrow? thrown;
  final double t;
  final Color ink;
  final Color metal;
  final Color ground;

  const CoinsPainter({
    required this.thrown,
    required this.t,
    required this.ink,
    required this.metal,
    required this.ground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width / 8.5, size.height / 3.2);
    final rest = size.height * 0.62;
    for (var i = 0; i < 3; i++) {
      final x = size.width / 2 + (i - 1) * radius * 2.7;
      // Each coin leaves a little after the one before it.
      final own = ((t - i * 0.1) / 0.8).clamp(0.0, 1.0);
      final back = thrown?.backs[i] ?? false;
      // Half-turns in the air: an even number lands face up, an odd
      // number back up.
      final turns = thrown == null ? 0 : (back ? 7 : 6) + i * 2;
      final eased = Curves.easeOutCubic.transform(own);
      final angle = eased * turns * math.pi;
      final height = math.sin(own * math.pi) * size.height * 0.42;
      final squash = math.cos(angle);
      final showsBack = squash < 0;
      final centre = Offset(x, rest - height);

      // Its shadow on the ground, smaller the higher it is.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, rest + radius * 1.05),
          width: radius * 1.5 * (1 - 0.5 * math.sin(own * math.pi)),
          height: radius * 0.22,
        ),
        Paint()..color = ink.withValues(alpha: 0.12),
      );

      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.scale(1, math.max(0.06, squash.abs()));
      final rim = Paint()
        ..color = metal
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.1;
      canvas.drawCircle(Offset.zero, radius, Paint()..color = ground);
      canvas.drawCircle(Offset.zero, radius, rim);
      final hole = radius * 0.3;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: hole * 2, height: hole * 2),
        rim,
      );
      if (!showsBack) {
        // The writing: a mark on each side of the hole.
        final stroke = Paint()
          ..color = metal
          ..strokeWidth = radius * 0.09
          ..strokeCap = StrokeCap.round;
        final far = radius * 0.66;
        final half = radius * 0.13;
        for (final (dx, dy) in const [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
          final at = Offset(dx * far, dy * far);
          canvas.drawLine(at - Offset(half, 0), at + Offset(half, 0), stroke);
          canvas.drawLine(at - Offset(0, half), at + Offset(0, half), stroke);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CoinsPainter old) =>
      old.t != t ||
      old.thrown != thrown ||
      old.metal != metal ||
      old.ink != ink;
}

/// The stalks counted: three changes, one after another. In each the
/// bundle is parted in two, one stalk is hung, the heaps are counted off
/// in fours, and what is left over drops out and is laid aside below.
class StalksPainter extends CustomPainter {
  final StalkLine? line;
  final double t;
  final Color ink;
  final Color aside;

  const StalksPainter({
    required this.line,
    required this.t,
    required this.ink,
    required this.aside,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pitch = math.min(7.0, (size.width - 24) / (Yijing.stalks + 6));
    final tall = size.height * 0.52;
    final top = size.height * 0.08;
    final stalk = Paint()
      ..color = ink
      ..strokeWidth = math.max(1.2, pitch * 0.32)
      ..strokeCap = StrokeCap.round;
    final laid = Paint()
      ..color = aside
      ..strokeWidth = stalk.strokeWidth
      ..strokeCap = StrokeCap.round;

    void bundle(double left, int count, Paint paint, {double lift = 0}) {
      for (var i = 0; i < count; i++) {
        final x = left + i * pitch;
        canvas.drawLine(
          Offset(x, top - lift),
          Offset(x, top + tall - lift),
          paint,
        );
      }
    }

    // The stalks laid aside in the changes already done, in three
    // little heaps along the foot.
    void asideHeaps(int done, {double arriving = 0, int arrivingCount = 0}) {
      final short = size.height * 0.16;
      final base = size.height * 0.96;
      var x = (size.width - 27 * pitch) / 2;
      for (var c = 0; c < 3; c++) {
        final count = c < done
            ? line!.changes[c].removed
            : (c == done ? arrivingCount : 0);
        final alpha = c < done ? 1.0 : arriving;
        for (var i = 0; i < count; i++) {
          canvas.drawLine(
            Offset(x + i * pitch, base - short),
            Offset(x + i * pitch, base),
            Paint()
              ..color = aside.withValues(alpha: alpha)
              ..strokeWidth = laid.strokeWidth
              ..strokeCap = StrokeCap.round,
          );
        }
        x += 9 * pitch;
      }
    }

    final cast = line;
    if (cast == null) {
      // At rest: the forty-nine, waiting.
      bundle(
        (size.width - (Yijing.stalks - 1) * pitch) / 2,
        Yijing.stalks,
        stalk,
      );
      return;
    }

    final at = (t * 3).clamp(0.0, 2.9999);
    final index = at.floor();
    final phase = at - index;
    final change = cast.changes[index];

    final whole = (change.before - 1) * pitch;
    final start = (size.width - whole) / 2;
    // 1: the bundle parts in two.
    final parting = Curves.easeInOut.transform((phase / 0.3).clamp(0.0, 1.0));
    final gap = pitch * 5 * parting;
    // 2: one stalk of the right heap is hung.
    final hanging = Curves.easeOut.transform(
      ((phase - 0.3) / 0.2).clamp(0.0, 1.0),
    );
    // 3: the remainders fall away, and the heaps close up.
    final falling = Curves.easeIn.transform(
      ((phase - 0.55) / 0.45).clamp(0.0, 1.0),
    );

    final leftKeep = change.left - change.leftRemainder;
    final rightKeep = change.right - 1 - change.rightRemainder;
    final closing = gap * (1 - falling);
    final leftAt = start - closing / 2;
    final rightAt = start + change.left * pitch + closing / 2;

    // The left heap: what stays, then what is left over at its end.
    bundle(leftAt, leftKeep, stalk);
    bundle(
      leftAt + leftKeep * pitch,
      change.leftRemainder,
      falling > 0
          ? (Paint()
              ..color = aside.withValues(alpha: 1 - falling)
              ..strokeWidth = stalk.strokeWidth
              ..strokeCap = StrokeCap.round)
          : stalk,
      lift: -falling * size.height * 0.2,
    );
    // The right heap: the one hung, what is left over, what stays.
    final hung = Paint()
      ..color = aside.withValues(alpha: 1 - falling)
      ..strokeWidth = stalk.strokeWidth
      ..strokeCap = StrokeCap.round;
    bundle(
      rightAt,
      1,
      hanging > 0 ? hung : stalk,
      lift: hanging * size.height * 0.06 - falling * size.height * 0.2,
    );
    bundle(
      rightAt + pitch,
      change.rightRemainder,
      falling > 0 ? hung : stalk,
      lift: -falling * size.height * 0.2,
    );
    bundle(rightAt + (1 + change.rightRemainder) * pitch, rightKeep, stalk);

    asideHeaps(index, arriving: falling, arrivingCount: change.removed);
  }

  @override
  bool shouldRepaint(StalksPainter old) =>
      old.t != t || old.line != line || old.ink != ink || old.aside != aside;
}
