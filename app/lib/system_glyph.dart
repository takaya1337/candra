import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'calendar_system.dart';
import 'dragon_outline.dart';
import 'gunungan_outline.dart';

/// A small drawing standing for a calendar system, each a filled shape
/// (owner, 20 and 21 October 2026, chosen from the options in
/// `docs/glyph-options/`):
///
/// - Weton: a keris of five luk: its wavy blade to a needle point, the
///   guard (ganja) across its root, the hilt bent at its end.
/// - Javanese: a gunungan (kayon), the trunk of its tree cut through it
///   from its tip down to the leaf's base; the handle the dalang holds it
///   by under it, whole. The shape traced from a public-domain picture
///   (see gunungan_outline.dart).
/// - Imlek: a Chinese dragon in flight, a public-domain silhouette traced
///   from OpenClipart (see dragon_outline.dart).
/// - Hijri: the crescent and the star.
/// - Gregorian: the sun of the old almanacs, drawn after the Sol de
///   Uruguay without its face (Wikimedia Commons, public domain): six
///   straight rays turn about with six waving flames round a disc, the
///   heraldic line down each and round the disc cut through.
///
/// Each is drawn one way everywhere. Where it stands for the room the
/// house is in (the bar's centre, at home), it is its inverse: the same
/// shape in the ground's colour on a solid accent ([SystemButton]).
class SystemGlyph extends StatelessWidget {
  final CalendarSystem system;
  final double size;
  final Color color;

  const SystemGlyph({
    super.key,
    required this.system,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _SystemGlyphPainter(system, color),
  );
}

/// A system's glyph as a picture, white on nothing, [pixels] square:
/// for the phone's own side to tint and draw.
Future<Uint8List> systemGlyphPng(
  CalendarSystem system, {
  int pixels = 96,
}) async {
  final recorder = ui.PictureRecorder();
  _SystemGlyphPainter(
    system,
    const Color(0xFFFFFFFF),
  ).paint(Canvas(recorder), Size.square(pixels.toDouble()));
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

class _SystemGlyphPainter extends CustomPainter {
  final CalendarSystem system;
  final Color color;

  const _SystemGlyphPainter(this.system, this.color);

  // Built once each: an outline has up to several hundred points.
  static Path _shape(List<double> outline) => Path()
    ..addPolygon([
      for (var i = 0; i < outline.length; i += 2)
        Offset(outline[i], outline[i + 1]),
    ], true);
  static final Path _dragon = _shape(dragonOutline);
  static final Path _gunungan = _shape(gununganOutline);
  static final Rect _gununganBox = _gunungan.getBounds();
  static final Path _keris = _drawKeris();

  @override
  void paint(Canvas canvas, Size size) {
    // Every glyph is drawn in a unit square and scaled up.
    canvas.scale(size.shortestSide);
    final fill = Paint()..color = color;

    switch (system) {
      case CalendarSystem.weton:
        canvas.drawPath(_keris, fill);

      case CalendarSystem.javanese:
        // The trunk cut out of the leaf, from its tip to its base; the
        // handle under it left whole.
        final box = _gununganBox;
        canvas
          ..saveLayer(const Rect.fromLTRB(-1, -1, 2, 2), Paint())
          ..drawPath(_gunungan, fill)
          ..drawLine(
            Offset(box.center.dx, box.top + box.height * 0.16),
            Offset(box.center.dx, box.top + box.height * _gununganBase),
            _cut(0.03),
          )
          ..restore();

      case CalendarSystem.chinese:
        canvas.drawPath(_dragon, fill);

      case CalendarSystem.hijri:
        final crescent = Path.combine(
          PathOperation.difference,
          Path()..addOval(
            Rect.fromCircle(center: const Offset(0.44, 0.5), radius: 0.40),
          ),
          Path()..addOval(
            Rect.fromCircle(center: const Offset(0.58, 0.5), radius: 0.33),
          ),
        );
        canvas.drawPath(crescent, fill);
        final star = Path();
        const heart = Offset(0.70, 0.5);
        for (var i = 0; i < 10; i++) {
          final point =
              heart +
              Offset.fromDirection(
                -math.pi / 2 + i * math.pi / 5,
                i.isEven ? 0.17 : 0.07,
              );
          i == 0
              ? star.moveTo(point.dx, point.dy)
              : star.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(star..close(), fill);

      case CalendarSystem.gregorian:
        canvas
          ..saveLayer(const Rect.fromLTRB(-1, -1, 2, 2), Paint())
          ..save()
          ..translate(0.5, 0.5)
          ..scale(_solScale)
          ..drawPath(_sol, fill)
          // The drawing's own lines, cut through: down each flame and
          // ray, and round the disc.
          ..drawPath(_solLines, _cut(1.1))
          ..drawCircle(Offset.zero, 11, _cut(1.1))
          ..restore()
          ..restore();
    }
  }

  // A line cut through what is drawn, in the ground's colour.
  static Paint _cut(double width) => Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // The Sol, in its own measure: a disc of 11, its rays and flames 33 out
  // from the centre; drawn [_solScale] of that in the unit square.
  static const _solScale = 0.49 / 33;
  static final Path _sol = _drawSol();
  static final Path _solLines = _drawSolLines();

  // One flame, as the Sol de Uruguay's file has it, pointing down; and
  // one straight ray.
  static Path _flame() => Path()
    ..moveTo(0, 0)
    ..lineTo(6, 12)
    ..cubicTo(-2, 25, 7, 27, 0, 33)
    ..cubicTo(3, 25, -4, 28, -3, 13)
    ..close();
  static Path _ray() => Path()
    ..moveTo(0, 0)
    ..lineTo(6, 0)
    ..lineTo(0, 33)
    ..lineTo(-6, 0)
    ..close();

  static Float64List _turn(double degrees) {
    final a = degrees * math.pi / 180;
    final c = math.cos(a);
    final s = math.sin(a);
    return Float64List.fromList([
      c,
      s,
      0,
      0,
      -s,
      c,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]);
  }

  // Six rays, and six flames between them.
  static Path _drawSol() {
    final sol = Path();
    for (var k = 0; k < 6; k++) {
      sol
        ..addPath(_ray().transform(_turn(60.0 * k + 180)), Offset.zero)
        ..addPath(_flame().transform(_turn(60.0 * k + 210)), Offset.zero);
    }
    return sol..addOval(Rect.fromCircle(center: Offset.zero, radius: 11));
  }

  static Path _drawSolLines() {
    final lines = Path();
    for (var k = 0; k < 6; k++) {
      lines
        ..addPath(
          (Path()
                ..moveTo(0, 12)
                ..lineTo(0, 30))
              .transform(_turn(60.0 * k + 180)),
          Offset.zero,
        )
        ..addPath(
          (Path()
                ..moveTo(0, 11)
                ..cubicTo(-2, 24, 4.5, 28, 0, 33))
              .transform(_turn(60.0 * k + 210)),
          Offset.zero,
        );
    }
    return lines;
  }

  // Where the leaf of the gunungan ends and its handle begins, as a share
  // of its height from the top.
  static const _gununganBase = 0.88;

  // A keris of five luk from the hilt at the lower left to the point at
  // the upper right.
  static Path _drawKeris() {
    const a = Offset(0.30, 0.70);
    const tip = Offset(0.90, 0.10);
    final d = tip - a;
    final u = d / d.distance;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final spine = [
      for (var i = 0; i <= 40; i++)
        a +
            d * (i / 40) +
            n * (0.028 * math.sin(i / 40 * 5 * math.pi) * (1 - i / 40 * 0.6)),
    ];
    // The blade, broad at its root to a needle point.
    final blade = _ribbon(spine, (t) => 0.065 * math.pow(1 - t, 0.8));
    // The guard (ganja), a sliver across the root, wider on one side.
    final guard = Path()
      ..addPolygon([
        a + n * 0.10 + u * 0.01,
        a + n * 0.12 - u * 0.03,
        a - n * 0.09 - u * 0.03,
        a - n * 0.06 + u * 0.01,
      ], true);
    // The hilt, short and stout, bent at its end.
    final hilt = _ribbon(
      _cubic(
        a - u * 0.03,
        a - u * 0.14,
        const Offset(0.10, 0.86),
        const Offset(0.14, 0.95),
      ),
      (t) => 0.04 + 0.012 * math.sin(t * math.pi),
    );
    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, blade, guard),
      hilt,
    );
  }

  // A band along [spine], [half] wide either side at each point.
  static Path _ribbon(List<Offset> spine, double Function(double t) half) {
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < spine.length; i++) {
      final a = spine[math.max(0, i - 1)];
      final b = spine[math.min(spine.length - 1, i + 1)];
      final d = b - a;
      final n = Offset(-d.dy, d.dx) / d.distance;
      final h = half(i / (spine.length - 1));
      left.add(spine[i] + n * h);
      right.add(spine[i] - n * h);
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  static List<Offset> _cubic(Offset a, Offset b, Offset c, Offset d) => [
    for (var i = 0; i <= 20; i++)
      () {
        final t = i / 20;
        final v = 1 - t;
        return a * (v * v * v) +
            b * (3 * v * v * t) +
            c * (3 * v * t * t) +
            d * (t * t * t);
      }(),
  ];

  @override
  bool shouldRepaint(_SystemGlyphPainter oldDelegate) =>
      oldDelegate.system != system || oldDelegate.color != color;
}
