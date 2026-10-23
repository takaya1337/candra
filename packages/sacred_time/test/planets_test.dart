import 'dart:io';
import 'dart:math' as math;

import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  const bodies = {
    'mercury': Body.mercury,
    'venus': Body.venus,
    'earth': Body.sun,
    'mars': Body.mars,
    'jupiter': Body.jupiter,
    'saturn': Body.saturn,
    'uranus': Body.uranus,
    'neptune': Body.neptune,
  };

  test('the truncated series against IMCCE\'s own check values of the '
      'full VSOP87D', () {
    for (final line in File(
      'test/fixtures/planets/vsop87d_check.txt',
    ).readAsLinesSync()) {
      if (line.startsWith('#') || line.trim().isEmpty) continue;
      final f = line.split(' ');
      final h = Planets.heliocentric(bodies[f[0]]!, double.parse(f[1]));
      final arc = 206264.806;
      final dl =
          ((h.l - double.parse(f[2]) + 3 * math.pi) % (2 * math.pi) - math.pi) *
          arc;
      expect(dl.abs(), lessThan(0.5), reason: '${f[0]} ${f[1]} l');
      expect(
        ((h.b - double.parse(f[3])) * arc).abs(),
        lessThan(0.5),
        reason: '${f[0]} ${f[1]} b',
      );
      expect(
        (h.r - double.parse(f[4])).abs(),
        lessThan(3e-6),
        reason: '${f[0]} ${f[1]} r',
      );
    }
  });

  test('apparent places, brightness and phase against JPL Horizons', () {
    const ids = {
      199: Body.mercury,
      299: Body.venus,
      499: Body.mars,
      599: Body.jupiter,
      699: Body.saturn,
      799: Body.uranus,
      899: Body.neptune,
    };
    var cases = 0;
    for (final line in File(
      'test/fixtures/planets/horizons.txt',
    ).readAsLinesSync()) {
      if (line.startsWith('#') || line.trim().isEmpty) continue;
      final head = line.split('|')[0].trim().split(RegExp(r'\s+'));
      final body = ids[int.parse(head[0])]!;
      final t = DateTime.parse('${head[1]}T${head[2]}:00Z');
      final f = line.split('|')[1].trim().split(RegExp(r'\s+'));
      final ra = double.parse(f[2]), dec = double.parse(f[3]);
      final p = SkyNow.planet(body, t, latitude: 0, longitude: 0);
      final v = SkyNow.planetView(body, t);
      final why = '${body.name} ${head[1]}';
      final dRa =
          ((p.rightAscension - ra + 540) % 360 - 180) *
          math.cos(dec * math.pi / 180) *
          3600;
      expect(dRa.abs(), lessThan(2), reason: '$why RA');
      expect(((p.declination - dec) * 3600).abs(), lessThan(2), reason: why);
      // Mars's markings and season are left out (up to about 0.1).
      expect(
        v.magnitude,
        closeTo(double.parse(f[4]), body == Body.mars ? 0.1 : 0.02),
        reason: '$why magnitude',
      );
      expect(v.illumination * 100, closeTo(double.parse(f[6]), 0.02));
      expect(v.distance, closeTo(double.parse(f[7]), 1e-4), reason: why);
      expect(v.elongation, closeTo(double.parse(f[9]), 0.02), reason: why);
      expect(v.east, f[10] == '/T', reason: '$why east');
      expect(v.phaseAngle, closeTo(double.parse(f[11]), 0.01), reason: why);
      cases++;
    }
    expect(cases, 21);
  });

  test('a planet rises and sets like the sun and the moon', () {
    final day = SkyNow.day(
      Body.venus,
      CivilDate(2026, 10, 16),
      latitude: -6.2,
      longitude: 106.8,
      utcOffset: const Duration(hours: 7),
    );
    expect(day.rise, isNotNull);
    expect(day.set, isNotNull);
    expect(day.transit, isNotNull);
    // Three degrees from the sun in October 2026: up and down with it,
    // within the hour.
    final sun = SkyNow.day(
      Body.sun,
      CivilDate(2026, 10, 16),
      latitude: -6.2,
      longitude: 106.8,
      utcOffset: const Duration(hours: 7),
    );
    expect(day.set!.difference(sun.set!).inMinutes.abs(), lessThan(60));
  });
}
