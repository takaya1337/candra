import 'dart:math' as math;

import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  const lat = -7.80, lon = 110.36, wib = Duration(hours: 7);

  test('the golden and blue hours begin and end where the sun stands at '
      'their heights, in order through the day', () {
    final date = CivilDate(2026, 10, 16);
    final h = LightHours.of(
      date,
      latitude: lat,
      longitude: lon,
      utcOffset: wib,
    );
    double sunAt(DateTime t) =>
        SkyNow.sun(t, latitude: lat, longitude: lon).trueAltitude;
    expect(sunAt(h.morningBlue!.start), closeTo(-6, 0.01));
    expect(sunAt(h.morningBlue!.end), closeTo(-4, 0.01));
    expect(h.morningGolden!.start, h.morningBlue!.end);
    expect(sunAt(h.morningGolden!.end), closeTo(6, 0.01));
    expect(sunAt(h.eveningGolden!.start), closeTo(6, 0.01));
    expect(h.eveningBlue!.start, h.eveningGolden!.end);
    expect(sunAt(h.eveningBlue!.end), closeTo(-6, 0.01));
    // Near the equator the sun climbs steeply: the golden hour is under
    // an hour, the blue some eight minutes.
    final golden = h.morningGolden!.end.difference(h.morningGolden!.start);
    expect(golden.inMinutes, inInclusiveRange(35, 50));
    final blue = h.morningBlue!.end.difference(h.morningBlue!.start);
    expect(blue.inMinutes, inInclusiveRange(6, 11));
    expect(LightBand.of(10), LightBand.day);
    expect(LightBand.of(0), LightBand.golden);
    expect(LightBand.of(-5), LightBand.blue);
    expect(LightBand.of(-12), LightBand.night);
  });

  test('far north at midsummer the sun never sinks to the blue hour', () {
    final h = LightHours.of(
      CivilDate(2026, 6, 21),
      latitude: 69.65,
      longitude: 18.96,
      utcOffset: const Duration(hours: 2),
    );
    expect(h.morningBlue, isNull);
    expect(h.eveningBlue, isNull);
  });

  test('a shadow is as long as the thing over the tangent of the sun\'s '
      'height, falling away from it; the rainbow\'s top is 42° less it', () {
    final sun = SkyNow.sun(
      DateTime.utc(2026, 10, 16, 1),
      latitude: lat,
      longitude: lon,
    );
    expect(sun.altitude, greaterThan(0));
    final s = SunLight.shadow(sun)!;
    expect(s.length * math.tan(sun.altitude * math.pi / 180), closeTo(1, 1e-9));
    expect(((s.bearing - sun.azimuth) % 360), closeTo(180, 1e-9));
    final low = SkyNow.sun(
      DateTime.utc(2026, 10, 16, 23, 0),
      latitude: lat,
      longitude: lon,
    );
    if (low.altitude > 0 && low.altitude < 42) {
      expect(SunLight.rainbow(low)!.top, closeTo(42 - low.altitude, 1e-9));
    }
    // Noon in October at Yogyakarta: the sun far above 42°, no bow.
    final noon = SkyNow.sun(
      DateTime.utc(2026, 10, 16, 5),
      latitude: lat,
      longitude: lon,
    );
    expect(noon.altitude, greaterThan(42));
    expect(SunLight.rainbow(noon), isNull);
  });

  test('the full moons of 2026 fall at the published instants', () {
    // USNO: 3 January 10:03, 3 March 11:38, 24 December 01:28 UT.
    final moons = FullMoons.within(DateTime.utc(2026, 1, 1), 365);
    expect(moons.length, 13);
    void near(DateTime got, DateTime want) =>
        expect(got.difference(want).inMinutes.abs(), lessThanOrEqualTo(3));
    near(moons.first.at, DateTime.utc(2026, 1, 3, 10, 3));
    near(moons[2].at, DateTime.utc(2026, 3, 3, 11, 38));
    near(moons.last.at, DateTime.utc(2026, 12, 24, 1, 28));
    // The December one is the nearest of the year.
    final nearest = moons.reduce((a, b) => a.distance < b.distance ? a : b);
    expect(nearest.at.month, 12);
    expect(nearest.distance, inInclusiveRange(356000, 360000));
  });

  test('the sun rises again on its own bearing: the alignment finds the '
      'day', () {
    final day = SkyNow.day(
      Body.sun,
      CivilDate(2026, 8, 10),
      latitude: lat,
      longitude: lon,
      utcOffset: wib,
    );
    final found = Alignments.find(
      Body.sun,
      rising: true,
      bearing: day.riseAzimuth!,
      from: CivilDate(2026, 8, 1),
      days: 366,
      latitude: lat,
      longitude: lon,
      utcOffset: wib,
    );
    // Once on the way north... and once on the way back, in May.
    expect(found.length, 2);
    expect(found.first.date, CivilDate(2026, 8, 10));
    expect(found.last.date.month, 5);
  });

  test('the Milky Way\'s heart is dark and high on a June night, and '
      'never in a December one', () {
    // 15 June 2026 is a new moon.
    final june = MilkyWay.night(
      CivilDate(2026, 6, 15),
      latitude: lat,
      longitude: lon,
      utcOffset: wib,
    );
    expect(june.moonless, isNotEmpty);
    final hours = june.moonless.fold<int>(
      0,
      (sum, s) => sum + s.end.difference(s.start).inMinutes,
    );
    expect(hours, greaterThan(5 * 60));
    final december = MilkyWay.night(
      CivilDate(2026, 12, 15),
      latitude: lat,
      longitude: lon,
      utcOffset: wib,
    );
    expect(december.dark, isEmpty);
  });

  test('north of 51° the heart counts from near its highest, and is '
      'found on an August night in London', () {
    expect(MilkyWay.lowestAt(-7.8), 10);
    expect(MilkyWay.lowestAt(51.5), closeTo(90 - 80.5 - 3, 0.01));
    expect(MilkyWay.lowestAt(70), isNull);
    // 10 August 2026, near new moon: some 7° up once the sky is fully
    // dark, late in the evening.
    final london = MilkyWay.night(
      CivilDate(2026, 8, 10),
      latitude: 51.5,
      longitude: -0.1,
      utcOffset: const Duration(hours: 1),
    );
    expect(london.dark, isNotEmpty);
  });

  test('meteor showers peak where the sun stands: the IMO\'s 2027 dates '
      'from their solar longitudes', () {
    CivilDate day(DateTime t) => CivilDate(t.year, t.month, t.day);
    // IMO Meteor Shower Calendar 2027, Table 5: maximum dates for 2027.
    expect(day(SunLongitude.when(2027, 283.15)), CivilDate(2027, 1, 4));
    // "peak on January 4 shortly after 03h UT".
    expect(SunLongitude.when(2027, 283.15).hour, inInclusiveRange(2, 4));
    expect(day(SunLongitude.when(2027, 45.5)), CivilDate(2027, 5, 6));
    expect(day(SunLongitude.when(2027, 140.0)), CivilDate(2027, 8, 13));
    expect(day(SunLongitude.when(2027, 235.27)), CivilDate(2027, 11, 18));
    expect(day(SunLongitude.when(2027, 262.2)), CivilDate(2027, 12, 14));
  });
}
