import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

/// One kecamatan's outline on the map: the row it is in the place
/// catalogue, its rings as longitude, latitude pairs in degrees, and the
/// box that holds them.
class KecamatanOutline {
  final int row;
  final List<Float32List> rings;
  final Rect box;

  KecamatanOutline(this.row, this.rings, this.box);

  /// Whether [longitude], [latitude] is inside, by the even-odd rule.
  bool holds(double longitude, double latitude) {
    if (!box.contains(Offset(longitude, latitude))) return false;
    var hit = false;
    for (final ring in rings) {
      final n = ring.length ~/ 2;
      for (var i = 0, j = n - 1; i < n; j = i++) {
        final x1 = ring[2 * i], y1 = ring[2 * i + 1];
        final x2 = ring[2 * j], y2 = ring[2 * j + 1];
        if ((y1 > latitude) != (y2 > latitude) &&
            longitude < x1 + (latitude - y1) * (x2 - x1) / (y2 - y1)) {
          hit = !hit;
        }
      }
    }
    return hit;
  }

  /// The outline as a path in degrees, x the longitude and y the latitude
  /// turned downward, as the world's.
  late final Path path = _path();

  Path _path() {
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
}

/// Indonesia's kecamatan as the map has them, read once from
/// `assets/places/kecamatan.bin` (cahyadsn/wilayah_boundaries, MIT;
/// sources in `docs/provenance/places/notes.md`): a touch on the map in
/// Indonesia picks the kecamatan it falls in, and the place goes to the
/// point inside it the catalogue gives.
class KecamatanOutlines {
  final List<KecamatanOutline> all;

  /// The outlines in runs of a hundred neighbours, each one path with
  /// the box that holds it, for drawing only what is in view; made the
  /// first time the map is near enough to draw them.
  late final List<({Path path, Rect box})> groups = _group(all);

  KecamatanOutlines._(this.all);

  static Future<KecamatanOutlines>? _loading;

  static Future<KecamatanOutlines> load() => _loading ??= _read();

  /// For tests: forget what was read.
  static void reset() => _loading = null;

  static Future<KecamatanOutlines> _read() async {
    final bytes = await rootBundle.load('assets/places/kecamatan.bin');
    final outlines = await Isolate.run(() => parse(bytes));
    return KecamatanOutlines._(outlines);
  }

  /// The outlines from the bytes of their file.
  static List<KecamatanOutline> parse(ByteData data) {
    var at = 0;
    int u16() {
      final v = data.getUint16(at, Endian.little);
      at += 2;
      return v;
    }

    int i16() {
      final v = data.getInt16(at, Endian.little);
      at += 2;
      return v;
    }

    int i32() {
      final v = data.getInt32(at, Endian.little);
      at += 4;
      return v;
    }

    final count = data.getUint32(0, Endian.little);
    at = 4;
    final all = <KecamatanOutline>[];
    for (var k = 0; k < count; k++) {
      final row = data.getUint32(at, Endian.little);
      at += 4;
      final ringCount = u16();
      final rings = <Float32List>[];
      var w = 180.0, e = -180.0, s = 90.0, n = -90.0;
      for (var r = 0; r < ringCount; r++) {
        final points = u16();
        final ring = Float32List(points * 2);
        var x = i32(), y = i32();
        for (var p = 0; p < points; p++) {
          if (p > 0) {
            x += i16();
            y += i16();
          }
          final lon = x / 1e4, lat = y / 1e4;
          ring[2 * p] = lon;
          ring[2 * p + 1] = lat;
          if (lon < w) w = lon;
          if (lon > e) e = lon;
          if (lat < s) s = lat;
          if (lat > n) n = lat;
        }
        rings.add(ring);
      }
      all.add(KecamatanOutline(row, rings, Rect.fromLTRB(w, s, e, n)));
    }
    return all;
  }

  // The file is in code order, so a run lies together.
  static List<({Path path, Rect box})> _group(List<KecamatanOutline> all) {
    final groups = <({Path path, Rect box})>[];
    for (var start = 0; start < all.length; start += 100) {
      final run = all.sublist(start, (start + 100).clamp(0, all.length));
      final path = Path();
      var box = run.first.box;
      for (final k in run) {
        path.addPath(k.path, Offset.zero);
        box = box.expandToInclude(k.box);
      }
      groups.add((path: path, box: box));
    }
    return groups;
  }

  /// The kecamatan [longitude], [latitude] falls in; where outlines
  /// overlap, the smallest.
  KecamatanOutline? at(double latitude, double longitude) {
    KecamatanOutline? found;
    for (final k in all) {
      if (!k.holds(longitude, latitude)) continue;
      if (found == null ||
          k.box.width * k.box.height < found.box.width * found.box.height) {
        found = k;
      }
    }
    return found;
  }

  /// The kecamatan at catalogue row [row], if any.
  KecamatanOutline? ofRow(int row) {
    for (final k in all) {
      if (k.row == row) return k;
    }
    return null;
  }
}
