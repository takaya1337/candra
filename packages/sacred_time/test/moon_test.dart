import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

import 'usno_phases.dart';

void main() {
  // Signed difference between two angles, in degrees.
  double angleBetween(double a, double b) => (a - b + 540) % 360 - 180;

  test('elongation at every published phase instant', () {
    var worst = 0.0;
    for (final (instant, phase) in usnoPhases) {
      final error = angleBetween(
        Moon.elongationAt(instant),
        phase.index * 45.0,
      ).abs();
      if (error > worst) worst = error;
      // 0.03 degrees of elongation is about three and a half minutes.
      expect(error, lessThan(0.03), reason: '$instant ${phase.label}');
    }
    printOnFailure('worst error: $worst degrees');
  });

  test('a principal phase names the UTC day it falls in', () {
    for (final (instant, phase) in usnoPhases) {
      // Skip instants so close to midnight that a minute decides the day.
      final minutes = instant.hour * 60 + instant.minute;
      if (minutes < 5 || minutes > 1435) continue;

      final date = CivilDate.fromDateTime(instant);
      expect(
        Moon.of(date, utcOffset: Duration.zero).phase,
        phase,
        reason: '$instant',
      );
      expect(
        Moon.of(date.addDays(1), utcOffset: Duration.zero).phase.isPrincipal,
        isFalse,
      );
      expect(
        Moon.of(date.addDays(-1), utcOffset: Duration.zero).phase.isPrincipal,
        isFalse,
      );
    }
  });

  test('the day depends on the timezone', () {
    // The full moon of 26 October 2026 at 04:12 UT is late on the 25th in
    // New York and mid-morning on the 26th in Jakarta.
    const newYork = Duration(hours: -5);
    const jakarta = Duration(hours: 7);
    final the25th = CivilDate(2026, 10, 25);
    final the26th = CivilDate(2026, 10, 26);

    expect(Moon.of(the25th, utcOffset: newYork).phase, MoonPhase.fullMoon);
    expect(Moon.of(the26th, utcOffset: newYork).phase, MoonPhase.waningGibbous);
    expect(Moon.of(the25th, utcOffset: jakarta).phase, MoonPhase.waxingGibbous);
    expect(Moon.of(the26th, utcOffset: jakarta).phase, MoonPhase.fullMoon);
  });

  test('phases run in order through a lunation', () {
    const offset = Duration(hours: 7);
    var date = CivilDate(2026, 1, 1);
    final seen = <MoonPhase>[];
    for (var i = 0; i < 365; i++, date = date.addDays(1)) {
      final phase = Moon.of(date, utcOffset: offset).phase;
      if (seen.isEmpty || seen.last != phase) seen.add(phase);
    }
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i].index, (seen[i - 1].index + 1) % 8, reason: '$i');
    }
  });

  test('illumination follows the phase', () {
    const offset = Duration(hours: 7);
    for (
      var date = CivilDate(2026, 1, 1);
      date.year == 2026;
      date = date.addDays(1)
    ) {
      final moon = Moon.of(date, utcOffset: offset);
      switch (moon.phase) {
        case MoonPhase.newMoon:
          expect(moon.illumination, lessThan(0.03), reason: '$date');
        case MoonPhase.fullMoon:
          expect(moon.illumination, greaterThan(0.97), reason: '$date');
        case MoonPhase.firstQuarter || MoonPhase.lastQuarter:
          expect(moon.illumination, closeTo(0.5, 0.12), reason: '$date');
        case MoonPhase.waxingCrescent || MoonPhase.waningCrescent:
          expect(moon.illumination, lessThan(0.56), reason: '$date');
        case MoonPhase.waxingGibbous || MoonPhase.waningGibbous:
          expect(moon.illumination, greaterThan(0.44), reason: '$date');
      }
    }
  });

  // The Chinese calendar starts each month on the day of the new moon at
  // UTC+8, so the Hong Kong Observatory table is a second, independent
  // almanac covering 170 years.
  test('every Chinese month from 1930 starts on a new moon day', () {
    const beijing = Duration(hours: 8);
    var months = 0;
    final misses = <CivilDate>[];
    for (
      var date = CivilDate(1930, 1, 30);
      date.compareTo(ChineseDate.lastSupported) <= 0;
      date = date.addDays(1)
    ) {
      if (ChineseDate.of(date).day != 1) continue;
      months++;
      if (Moon.of(date, utcOffset: beijing).phase != MoonPhase.newMoon) {
        misses.add(date);
      }
    }
    expect(months, greaterThan(2000));
    expect(misses, isEmpty);
  });
}
