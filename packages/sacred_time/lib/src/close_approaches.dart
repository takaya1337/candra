import 'dart:math' as math;

import 'sky_position.dart';

/// Two bodies passing close in the sky, and when it is to be seen from
/// one place.
class CloseApproach {
  /// The moon or a planet, and a planet.
  final Body first;
  final Body second;

  /// When they stand nearest each other as seen from the Earth's centre,
  /// and how near, in degrees.
  final DateTime closest;
  final double separation;

  /// The moment of the nearest dark night (the sun 6° down or more) when
  /// both stand highest together at the place, the lower of the two
  /// heights then, and how far apart they are then as seen from there;
  /// null where they are not both up in the dark within a day of it.
  final DateTime? seen;
  final double? height;
  final double? seenSeparation;

  const CloseApproach({
    required this.first,
    required this.second,
    required this.closest,
    required this.separation,
    required this.seen,
    required this.height,
    required this.seenSeparation,
  });
}

/// The close approaches of the moon and the five planets the eye sees,
/// worked out from their places (`SkyNow`): the moon within 3° of a
/// planet, two planets within 2° of each other. What astronomers call a
/// conjunction is a meeting in right ascension or longitude; this is the
/// least distance on the sky, which is what is photographed.
abstract final class CloseApproaches {
  static const _rad = math.pi / 180;

  /// The five planets the eye sees.
  static const naked = [
    Body.mercury,
    Body.venus,
    Body.mars,
    Body.jupiter,
    Body.saturn,
  ];

  static const moonWithin = 3.0;
  static const planetsWithin = 2.0;

  static double _between(double ra1, double dec1, double ra2, double dec2) {
    final c =
        math.sin(dec1 * _rad) * math.sin(dec2 * _rad) +
        math.cos(dec1 * _rad) *
            math.cos(dec2 * _rad) *
            math.cos((ra1 - ra2) * _rad);
    return math.acos(c.clamp(-1.0, 1.0)) / _rad;
  }

  static ({double ra, double dec}) _place(Body body, DateTime t) {
    final p = body == Body.moon
        ? SkyNow.moon(t, latitude: 0, longitude: 0)
        : SkyNow.planet(body, t, latitude: 0, longitude: 0);
    return (ra: p.rightAscension, dec: p.declination);
  }

  static double _separation(Body a, Body b, DateTime t) {
    final p = _place(a, t), q = _place(b, t);
    return _between(p.ra, p.dec, q.ra, q.dec);
  }

  /// Every close approach from [from] over [days] days, soonest first,
  /// each with when it is best seen from [latitude], [longitude].
  static List<CloseApproach> within(
    DateTime from,
    int days, {
    required double latitude,
    required double longitude,
  }) {
    final found = <CloseApproach>[];
    // The moon every three hours, the planets every day: steps short
    // enough that no meeting slips between two.
    void sweep(Body a, Body b, Duration step, double within) {
      final steps = days * Duration.hoursPerDay * 60 ~/ step.inMinutes;
      final seps = [
        for (var k = 0; k <= steps; k++) _separation(a, b, from.add(step * k)),
      ];
      for (var k = 1; k < steps; k++) {
        if (!(seps[k] <= seps[k - 1] && seps[k] < seps[k + 1])) continue;
        if (seps[k] > within + 1) continue;
        // Narrowed to the minute.
        var low = from.add(step * (k - 1)), high = from.add(step * (k + 1));
        while (high.difference(low) > const Duration(minutes: 1)) {
          final third = high.difference(low) ~/ 3;
          final x = low.add(third), y = high.subtract(third);
          _separation(a, b, x) < _separation(a, b, y) ? high = y : low = x;
        }
        final closest = low.add(high.difference(low) ~/ 2);
        final separation = _separation(a, b, closest);
        if (separation > within) continue;
        final seen = _bestSeen(a, b, closest, latitude, longitude);
        found.add(
          CloseApproach(
            first: a,
            second: b,
            closest: closest,
            separation: separation,
            seen: seen?.at,
            height: seen?.height,
            seenSeparation: seen?.separation,
          ),
        );
      }
    }

    for (final p in naked) {
      sweep(Body.moon, p, const Duration(hours: 3), moonWithin);
    }
    for (var i = 0; i < naked.length; i++) {
      for (var j = i + 1; j < naked.length; j++) {
        sweep(naked[i], naked[j], const Duration(days: 1), planetsWithin);
      }
    }
    found.sort((x, y) => x.closest.compareTo(y.closest));
    return found;
  }

  // Within a day either side of [closest], every ten minutes, the best
  // moment with the sun 6° down or more and both 5° up: the lower of the
  // two as high as may be up to 30°, and above that the nearer together
  // the better (two degrees of height for each degree apart); null where
  // they are never both up in the dark.
  static ({DateTime at, double height, double separation})? _bestSeen(
    Body a,
    Body b,
    DateTime closest,
    double latitude,
    double longitude,
  ) {
    SkyPosition at(Body body, DateTime t) => body == Body.moon
        ? SkyNow.moon(t, latitude: latitude, longitude: longitude)
        : SkyNow.planet(body, t, latitude: latitude, longitude: longitude);
    ({DateTime at, double height, double separation})? best;
    for (var m = -24 * 60; m <= 24 * 60; m += 10) {
      final t = closest.add(Duration(minutes: m));
      final sun = SkyNow.sun(t, latitude: latitude, longitude: longitude);
      if (sun.trueAltitude > -6) continue;
      final p = at(a, t), q = at(b, t);
      final low = math.min(p.altitude, q.altitude);
      if (low < 5) continue;
      final c =
          math.sin(p.trueAltitude * _rad) * math.sin(q.trueAltitude * _rad) +
          math.cos(p.trueAltitude * _rad) *
              math.cos(q.trueAltitude * _rad) *
              math.cos((p.azimuth - q.azimuth) * _rad);
      final apart = math.acos(c.clamp(-1.0, 1.0)) / _rad;
      double score(double height, double separation) =>
          math.min(height, 30) - 2 * separation;
      if (best == null ||
          score(low, apart) > score(best.height, best.separation)) {
        best = (at: t, height: low, separation: apart);
      }
    }
    return best;
  }
}
