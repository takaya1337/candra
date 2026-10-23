import 'dart:math' as math;

import 'sky_position.dart';

/// How much of the sun or the moon an eclipse takes.
enum EclipseKind { partial, annular, total, penumbral }

/// A solar eclipse as seen from one place: the moon's disc against the
/// sun's, each where it stands from there.
class LocalSolarEclipse {
  final EclipseKind kind;

  /// When the eclipse is greatest from the place, and how much of the
  /// sun's diameter the moon then covers (more than 1 when total).
  final DateTime greatest;
  final double magnitude;

  /// The four contacts: the moon first touching the sun, then (total or
  /// annular only) wholly within or over it, then leaving, then last
  /// touching.
  final DateTime begins;
  final DateTime? centralBegins;
  final DateTime? centralEnds;
  final DateTime ends;

  /// The sun's true height at the greatest eclipse, and at the beginning
  /// and the end: below 0, it is set.
  final double sunAtGreatest;
  final double sunAtBeginning;
  final double sunAtEnd;

  const LocalSolarEclipse({
    required this.kind,
    required this.greatest,
    required this.magnitude,
    required this.begins,
    required this.centralBegins,
    required this.centralEnds,
    required this.ends,
    required this.sunAtGreatest,
    required this.sunAtBeginning,
    required this.sunAtEnd,
  });

  /// Whether any of it happens with the sun up.
  bool get visible => sunAtGreatest > 0 || sunAtBeginning > 0 || sunAtEnd > 0;
}

/// A lunar eclipse, the same for all who have the moon up: the moon in
/// the Earth's shadow.
class LunarEclipse {
  final EclipseKind kind;
  final DateTime greatest;

  /// How far into the umbra the moon reaches at the greatest, in moon
  /// diameters (negative: only the penumbra); and into the penumbra.
  final double umbralMagnitude;
  final double penumbralMagnitude;

  /// The contacts with the penumbra (P1, P4), the umbra (U1, U4) and
  /// totality (U2, U3), where there are any.
  final DateTime penumbraBegins;
  final DateTime? partialBegins;
  final DateTime? totalBegins;
  final DateTime? totalEnds;
  final DateTime? partialEnds;
  final DateTime penumbraEnds;

  const LunarEclipse({
    required this.kind,
    required this.greatest,
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
    required this.penumbraBegins,
    required this.partialBegins,
    required this.totalBegins,
    required this.totalEnds,
    required this.partialEnds,
    required this.penumbraEnds,
  });
}

/// Eclipses worked out from the sun and moon themselves (VSOP87 and the
/// ELP series as the sky engine has them), not looked up: checked in the
/// tests against NASA's catalogue (Espenak).
abstract final class Eclipses {
  static const _rad = math.pi / 180;
  static const _earthRadius = 6378.14;

  // Every new moon (elongation 0) or full moon (180) from [from] over
  // [days] days, to the minute.
  static List<DateTime> _syzygies(DateTime from, int days, double target) {
    double off(DateTime t) =>
        (SkyNow.moonFace(t).elongation - target + 540) % 360 - 180;
    final found = <DateTime>[];
    var before = from;
    var a = off(before);
    for (var h = 6; h <= days * 24; h += 6) {
      final after = from.add(Duration(hours: h));
      final b = off(after);
      if (a < 0 && b >= 0 && b - a < 90) {
        var low = before, high = after;
        while (high.difference(low) > const Duration(seconds: 30)) {
          final middle = low.add(high.difference(low) ~/ 2);
          off(middle) >= 0 ? high = middle : low = middle;
        }
        found.add(low.add(high.difference(low) ~/ 2));
      }
      before = after;
      a = b;
    }
    return found;
  }

  // The moon's distance from the ecliptic at [t], in degrees: an eclipse
  // needs it small at the syzygy.
  static double _moonLatitude(DateTime t) =>
      SkyNow.moon(t, latitude: 0, longitude: 0).eclipticLatitude;

  static double _angle(double a1, double z1, double a2, double z2) {
    final c =
        math.sin(a1 * _rad) * math.sin(a2 * _rad) +
        math.cos(a1 * _rad) * math.cos(a2 * _rad) * math.cos((z1 - z2) * _rad);
    return math.acos(c.clamp(-1.0, 1.0)) / _rad;
  }

  // Bisection for where [f] crosses zero between [a] and [b], to a
  // second; [f] must change sign.
  static DateTime _cross(DateTime a, DateTime b, double Function(DateTime) f) {
    var low = a, high = b;
    final rising = f(a) < f(b);
    while (high.difference(low) > const Duration(seconds: 1)) {
      final middle = low.add(high.difference(low) ~/ 2);
      (f(middle) < 0) == rising ? low = middle : high = middle;
    }
    return low.add(high.difference(low) ~/ 2);
  }

  /// The solar eclipses seen from [latitude], [longitude] from [from]
  /// over [days] days: every new moon near enough the ecliptic, the
  /// moon's disc against the sun's from the place, found to the second.
  /// Only those with the sun up for some of it: below the horizon the
  /// moon and the sun are on the far side of the Earth, and there is no
  /// eclipse to see.
  static List<LocalSolarEclipse> solarFrom(
    DateTime from,
    int days, {
    required double latitude,
    required double longitude,
  }) {
    final found = <LocalSolarEclipse>[];
    for (final newMoon in _syzygies(from, days, 0)) {
      if (_moonLatitude(newMoon).abs() > 1.6) continue;
      ({double sep, double sun, double moon, double sunAlt}) at(DateTime t) {
        final s = SkyNow.sun(t, latitude: latitude, longitude: longitude);
        final m = SkyNow.moon(t, latitude: latitude, longitude: longitude);
        // The moon's disc as seen from the place, a little larger the
        // higher it stands.
        final parallax = math.asin(_earthRadius / m.distance);
        final moonRadius =
            m.semidiameter *
            (1 + math.sin(parallax) * math.sin(m.trueAltitude * _rad));
        return (
          sep: _angle(m.trueAltitude, m.azimuth, s.trueAltitude, s.azimuth),
          sun: s.semidiameter,
          moon: moonRadius,
          sunAlt: s.trueAltitude,
        );
      }

      // The nearest the discs come, within six hours of the new moon.
      var best = newMoon;
      var bestSep = double.infinity;
      for (var m = -360; m <= 360; m += 4) {
        final t = newMoon.add(Duration(minutes: m));
        final sep = at(t).sep;
        if (sep < bestSep) {
          bestSep = sep;
          best = t;
        }
      }
      var low = best.subtract(const Duration(minutes: 4));
      var high = best.add(const Duration(minutes: 4));
      while (high.difference(low) > const Duration(seconds: 1)) {
        final third = high.difference(low) ~/ 3;
        final a = low.add(third), b = high.subtract(third);
        at(a).sep < at(b).sep ? high = b : low = a;
      }
      final greatest = low.add(high.difference(low) ~/ 2);
      final g = at(greatest);
      if (g.sep >= g.sun + g.moon) continue;

      double touching(DateTime t) {
        final p = at(t);
        return p.sep - (p.sun + p.moon);
      }

      double inside(DateTime t) {
        final p = at(t);
        return p.sep - (p.sun - p.moon).abs();
      }

      final early = greatest.subtract(const Duration(hours: 4));
      final late = greatest.add(const Duration(hours: 4));
      final central = g.sep < (g.sun - g.moon).abs();
      final kind = !central
          ? EclipseKind.partial
          : (g.moon > g.sun ? EclipseKind.total : EclipseKind.annular);
      final begins = _cross(early, greatest, touching);
      final ends = _cross(greatest, late, touching);
      if (g.sunAlt <= 0 && at(begins).sunAlt <= 0 && at(ends).sunAlt <= 0) {
        continue;
      }
      found.add(
        LocalSolarEclipse(
          kind: kind,
          greatest: greatest,
          magnitude: (g.sun + g.moon - g.sep) / (2 * g.sun),
          begins: begins,
          centralBegins: central ? _cross(begins, greatest, inside) : null,
          centralEnds: central ? _cross(greatest, ends, inside) : null,
          ends: ends,
          sunAtGreatest: g.sunAlt,
          sunAtBeginning: at(begins).sunAlt,
          sunAtEnd: at(ends).sunAlt,
        ),
      );
    }
    return found;
  }

  /// The lunar eclipses from [from] over [days] days, penumbral ones
  /// included: the moon's centre against the centre of the Earth's
  /// shadow, the shadow's radii by Danjon's rule (the Earth's radius
  /// enlarged by 1/85 for its air, as NASA's catalogue reckons them).
  /// Against NASA's catalogue the magnitudes come out about 0.004 less,
  /// so a penumbral graze of a thousandth (18 July 2027) is not found;
  /// none such can be seen.
  static List<LunarEclipse> lunarFrom(DateTime from, int days) {
    final found = <LunarEclipse>[];
    for (final fullMoon in _syzygies(from, days, 180)) {
      if (_moonLatitude(fullMoon).abs() > 1.8) continue;
      ({double d, double umbra, double penumbra, double moon}) at(DateTime t) {
        final s = SkyNow.sun(t, latitude: 0, longitude: 0);
        final m = SkyNow.moon(t, latitude: 0, longitude: 0);
        final d = _angle(
          m.declination,
          m.rightAscension,
          -s.declination,
          s.rightAscension + 180,
        );
        final moonParallax = math.asin(_earthRadius / m.distance) / _rad;
        final sunParallax = math.asin(_earthRadius / s.distance) / _rad;
        final earth = 1.01 * 0.998340 * moonParallax;
        return (
          d: d,
          umbra: earth + sunParallax - s.semidiameter,
          penumbra: earth + sunParallax + s.semidiameter,
          moon: m.semidiameter,
        );
      }

      var best = fullMoon;
      var bestD = double.infinity;
      for (var m = -240; m <= 240; m += 4) {
        final t = fullMoon.add(Duration(minutes: m));
        final d = at(t).d;
        if (d < bestD) {
          bestD = d;
          best = t;
        }
      }
      var low = best.subtract(const Duration(minutes: 4));
      var high = best.add(const Duration(minutes: 4));
      while (high.difference(low) > const Duration(seconds: 1)) {
        final third = high.difference(low) ~/ 3;
        final a = low.add(third), b = high.subtract(third);
        at(a).d < at(b).d ? high = b : low = a;
      }
      final greatest = low.add(high.difference(low) ~/ 2);
      final g = at(greatest);
      final penumbral = (g.penumbra + g.moon - g.d) / (2 * g.moon);
      if (penumbral <= 0) continue;
      final umbral = (g.umbra + g.moon - g.d) / (2 * g.moon);
      final early = greatest.subtract(const Duration(hours: 5));
      final late = greatest.add(const Duration(hours: 5));
      DateTime? from(double Function(DateTime) f) =>
          f(greatest) < 0 ? _cross(early, greatest, f) : null;
      DateTime? to(double Function(DateTime) f) =>
          f(greatest) < 0 ? _cross(greatest, late, f) : null;
      double pen(DateTime t) {
        final p = at(t);
        return p.d - (p.penumbra + p.moon);
      }

      double part(DateTime t) {
        final p = at(t);
        return p.d - (p.umbra + p.moon);
      }

      double whole(DateTime t) {
        final p = at(t);
        return p.d - (p.umbra - p.moon);
      }

      found.add(
        LunarEclipse(
          kind: umbral >= 1
              ? EclipseKind.total
              : umbral > 0
              ? EclipseKind.partial
              : EclipseKind.penumbral,
          greatest: greatest,
          umbralMagnitude: umbral,
          penumbralMagnitude: penumbral,
          penumbraBegins: from(pen)!,
          partialBegins: from(part),
          totalBegins: from(whole),
          totalEnds: to(whole),
          partialEnds: to(part),
          penumbraEnds: to(pen)!,
        ),
      );
    }
    return found;
  }
}
