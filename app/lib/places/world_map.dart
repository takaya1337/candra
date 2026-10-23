import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'kecamatan_outlines.dart';

/// The countries' outlines, read once from `assets/places/world.bin`
/// (Natural Earth 1:50m, public domain, simplified; sources in
/// `docs/provenance/places/notes.md`), as one path in degrees: x the
/// longitude, y the latitude turned downward.
abstract final class WorldOutline {
  static Future<Path>? _loading;

  static Future<Path> load() => _loading ??= _read();

  static Future<Path> _read() async {
    final bytes = await rootBundle.load('assets/places/world.bin');
    final rings = await Isolate.run(() => parse(bytes));
    final path = Path();
    for (final ring in rings) {
      path.moveTo(ring[0], -ring[1]);
      for (var k = 2; k + 1 < ring.length; k += 2) {
        path.lineTo(ring[k], -ring[k + 1]);
      }
      path.close();
    }
    return path;
  }

  /// Each ring as longitude, latitude pairs in degrees.
  static List<Float32List> parse(ByteData data) {
    var at = 0;
    final count = data.getUint32(at, Endian.little);
    at += 4;
    final rings = <Float32List>[];
    for (var r = 0; r < count; r++) {
      final n = data.getUint16(at, Endian.little);
      at += 2;
      final ring = Float32List(n * 2);
      for (var k = 0; k < n * 2; k++) {
        ring[k] = data.getInt16(at, Endian.little) / 100;
        at += 2;
      }
      rings.add(ring);
    }
    return rings;
  }
}

/// Where the map looks: its centre and how many logical pixels a degree
/// takes.
typedef MapView = ({double longitude, double latitude, double scale});

/// The world as a flat map, longitude across and latitude up
/// (equirectangular: straight, and true on the equator), drawn by the
/// app: the land, the lines every 15°, the equator stronger, the place
/// chosen as a pin and other places as dots. Drawn and pinched to zoom;
/// a touch picks the point under it through [onPick].
class WorldMap extends StatefulWidget {
  final Path? outline;
  final ValueNotifier<MapView> view;
  final ({double latitude, double longitude})? pin;
  final List<({double latitude, double longitude})> dots;
  final void Function(double latitude, double longitude) onPick;

  /// Indonesia's kecamatan, drawn faint when the map is near enough, and
  /// the one the place is in, drawn in the accent.
  final KecamatanOutlines? kecamatan;
  final KecamatanOutline? chosen;

  const WorldMap({
    super.key,
    required this.outline,
    required this.view,
    required this.pin,
    required this.onPick,
    this.dots = const [],
    this.kecamatan,
    this.chosen,
  });

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> {
  MapView? _start;
  Offset? _startFocal;
  Size _size = Size.zero;

  static const _most = 600.0;

  double _least(Size size) => size.width / 360;

  MapView _clamp(MapView v) {
    final scale = v.scale.clamp(_least(_size), _most).toDouble();
    final halfHeight = _size.height / 2 / scale;
    final latitude = halfHeight >= 90
        ? 0.0
        : v.latitude.clamp(-90 + halfHeight, 90 - halfHeight).toDouble();
    final longitude = (v.longitude + 540) % 360 - 180;
    return (longitude: longitude, latitude: latitude, scale: scale);
  }

  // From the screen to the earth, under the view [v].
  ({double latitude, double longitude}) _toEarth(Offset p, MapView v) => (
    longitude: v.longitude + (p.dx - _size.width / 2) / v.scale,
    latitude: v.latitude - (p.dy - _size.height / 2) / v.scale,
  );

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) {
            _start = widget.view.value;
            _startFocal = d.localFocalPoint;
          },
          onScaleUpdate: (d) {
            final start = _start!;
            final scale = (start.scale * d.scale)
                .clamp(_least(_size), _most)
                .toDouble();
            // The point under the fingers at the start stays under them.
            final held = _toEarth(_startFocal!, start);
            widget.view.value = _clamp((
              longitude:
                  held.longitude -
                  (d.localFocalPoint.dx - _size.width / 2) / scale,
              latitude:
                  held.latitude +
                  (d.localFocalPoint.dy - _size.height / 2) / scale,
              scale: scale,
            ));
          },
          onTapUp: (d) {
            final at = _toEarth(d.localPosition, widget.view.value);
            if (at.latitude.abs() > 90) return;
            HapticFeedback.selectionClick();
            widget.onPick(at.latitude, (at.longitude + 540) % 360 - 180);
          },
          child: ClipRect(
            child: ValueListenableBuilder(
              valueListenable: widget.view,
              builder: (context, view, _) => CustomPaint(
                size: _size,
                painter: _MapPainter(
                  outline: widget.outline,
                  view: _clamp(view),
                  pin: widget.pin,
                  dots: widget.dots,
                  kecamatan: widget.kecamatan,
                  chosen: widget.chosen,
                  land: colors.surfaceRaised,
                  border: colors.outline,
                  grid: colors.outline.withValues(alpha: 0.35),
                  accent: colors.accent,
                  faint: colors.textFaint,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  final Path? outline;
  final MapView view;
  final ({double latitude, double longitude})? pin;
  final List<({double latitude, double longitude})> dots;
  final KecamatanOutlines? kecamatan;
  final KecamatanOutline? chosen;
  final Color land, border, grid, accent, faint;

  /// How many points a degree takes before the kecamatan are drawn.
  static const kecamatanFrom = 60.0;

  _MapPainter({
    required this.outline,
    required this.view,
    required this.pin,
    required this.dots,
    required this.kecamatan,
    required this.chosen,
    required this.land,
    required this.border,
    required this.grid,
    required this.accent,
    required this.faint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = view.scale;
    Offset at(double lat, double lon) {
      var dx = lon - view.longitude;
      if (dx > 180) dx -= 360;
      if (dx < -180) dx += 360;
      return Offset(
        size.width / 2 + dx * s,
        size.height / 2 + (view.latitude - lat) * s,
      );
    }

    // The lines every 15°, the equator stronger.
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var lat = -75; lat <= 75; lat += 15) {
      final y = at(lat.toDouble(), view.longitude).dy;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        lat == 0
            ? (Paint()
                ..color = border
                ..strokeWidth = 1.2)
            : line,
      );
    }
    for (var lon = -180; lon < 180; lon += 15) {
      final x = at(0, lon.toDouble()).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }

    // The land, drawn three times across so the date line joins up.
    final path = outline;
    if (path != null) {
      final fill = Paint()..color = land;
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0
        ..color = border;
      for (final turn in const [-360.0, 0.0, 360.0]) {
        final left = size.width / 2 + (turn - 180 - view.longitude) * s;
        final right = left + 360 * s;
        if (right < 0 || left > size.width) continue;
        canvas
          ..save()
          ..translate(
            size.width / 2 + (turn - view.longitude) * s,
            size.height / 2 + view.latitude * s,
          )
          ..scale(s, s)
          ..drawPath(path, fill)
          ..drawPath(path, edge)
          ..restore();
      }
    }

    // Indonesia's kecamatan, only those in view; and the one chosen. The
    // date line is far from Indonesia, so once across is enough.
    final regions = kecamatan;
    final one = chosen;
    if ((regions != null && s >= kecamatanFrom) || one != null) {
      final seen = Rect.fromLTRB(
        view.longitude - size.width / 2 / s,
        -(view.latitude + size.height / 2 / s),
        view.longitude + size.width / 2 / s,
        -(view.latitude - size.height / 2 / s),
      );
      canvas
        ..save()
        ..translate(
          size.width / 2 - view.longitude * s,
          size.height / 2 + view.latitude * s,
        )
        ..scale(s, s);
      if (regions != null && s >= kecamatanFrom) {
        final edge = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0
          ..color = border.withValues(alpha: 0.55);
        for (final g in regions.groups) {
          // The boxes are in latitude upward; the paths downward.
          final box = Rect.fromLTRB(
            g.box.left,
            -g.box.bottom,
            g.box.right,
            -g.box.top,
          );
          if (box.overlaps(seen)) canvas.drawPath(g.path, edge);
        }
      }
      if (one != null) {
        final path = one.path;
        canvas
          ..drawPath(path, Paint()..color = accent.withValues(alpha: 0.14))
          ..drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6 / s
              ..color = accent,
          );
      }
      canvas.restore();
    }

    for (final d in dots) {
      canvas.drawCircle(
        at(d.latitude, d.longitude),
        2.5,
        Paint()..color = faint,
      );
    }

    final p = pin;
    if (p != null) {
      final c = at(p.latitude, p.longitude);
      canvas
        ..drawCircle(
          c,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = accent,
        )
        ..drawCircle(c, 3, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.view != view ||
      old.pin != pin ||
      !identical(old.outline, outline) ||
      !identical(old.dots, dots) ||
      !identical(old.kecamatan, kecamatan) ||
      !identical(old.chosen, chosen) ||
      old.land != land;
}

/// A view of [place] at a scale that shows about [degrees] across
/// [width].
MapView viewOf(
  ({double latitude, double longitude}) place,
  double width, {
  double degrees = 40,
}) => (
  longitude: place.longitude,
  latitude: place.latitude,
  scale: math.max(width / 360, width / degrees),
);
