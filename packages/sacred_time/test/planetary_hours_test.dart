import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  const jakarta = (latitude: -6.2, longitude: 106.8);
  const wib = Duration(hours: 7);

  test('Sunday\'s first hour is the sun\'s, and the hours run down the '
      'Chaldean order', () {
    // 18 October 2026 is a Sunday.
    final hours = PlanetaryHours.of(
      CivilDate(2026, 10, 18),
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
      utcOffset: wib,
    )!;
    expect(hours, hasLength(24));
    expect(hours.take(8).map((h) => h.ruler), [
      Body.sun,
      Body.venus,
      Body.mercury,
      Body.moon,
      Body.saturn,
      Body.jupiter,
      Body.mars,
      Body.sun,
    ]);
    // Twelve to the day, twelve to the night, end to end, sunrise to
    // the next sunrise.
    // Sunrise and sunset by the sun's centre on the horizon, no air.
    DateTime passing({required bool rising}) => SkyNow.passing(
      Body.sun,
      CivilDate(2026, 10, 18),
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
      utcOffset: wib,
      altitude: 0,
      rising: rising,
    )!;
    expect(hours.first.start, passing(rising: true));
    expect(hours[11].end, passing(rising: false));
    expect(hours[12].start, passing(rising: false));
    // A few minutes after the almanac's sunrise, which counts the upper
    // edge and the air.
    final almanac = SkyNow.day(
      Body.sun,
      CivilDate(2026, 10, 18),
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
      utcOffset: wib,
    ).rise!;
    expect(
      hours.first.start.difference(almanac).inMinutes,
      inInclusiveRange(2, 5),
    );
    for (var k = 1; k < 24; k++) {
      expect(hours[k].start, hours[k - 1].end);
    }
    expect(hours.where((h) => h.day), hasLength(12));
  });

  test('the next day\'s first hour is the moon\'s: the week\'s order '
      'comes from the hours', () {
    for (var d = 0; d < 7; d++) {
      final date = CivilDate(2026, 10, 18).addDays(d);
      final hours = PlanetaryHours.of(
        date,
        latitude: jakarta.latitude,
        longitude: jakarta.longitude,
        utcOffset: wib,
      )!;
      final next = PlanetaryHours.chaldean.indexOf(hours.last.ruler) + 1;
      expect(
        PlanetaryHours.chaldean[next % 7],
        PlanetaryHours.rulerOf(Weekday.of(date.addDays(1))),
      );
    }
  });

  test('day hours are long in summer and short in winter, far from the '
      'equator', () {
    final june = PlanetaryHours.of(
      CivilDate(2026, 6, 21),
      latitude: 51.5,
      longitude: -0.1,
      utcOffset: const Duration(hours: 1),
    )!;
    final length = june.first.end.difference(june.first.start).inMinutes;
    // The centre's sunrise to sunset, about 16 h 26 min: hours of about
    // 82 minutes.
    expect(length, inInclusiveRange(81, 83));
    // None where the sun does not set.
    expect(
      PlanetaryHours.of(
        CivilDate(2026, 6, 21),
        latitude: 78,
        longitude: 15,
        utcOffset: const Duration(hours: 2),
      ),
      isNull,
    );
  });

  test('the hour that holds a moment: before sunrise, still the night of '
      'the day before', () {
    Duration wibOn(CivilDate _) => wib;
    // Friday 16 October 2026 at 23:00 WIB: Friday's night.
    final night = PlanetaryHours.at(
      DateTime.utc(2026, 10, 16, 16),
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
      offsetOn: wibOn,
    )!;
    expect(night.day, isFalse);
    // Saturday 17 October at 03:00 WIB: still Friday's night.
    final early = PlanetaryHours.at(
      DateTime.utc(2026, 10, 16, 20),
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
      offsetOn: wibOn,
    )!;
    expect(early.day, isFalse);
    final friday = PlanetaryHours.of(
      CivilDate(2026, 10, 16),
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
      utcOffset: wib,
    )!;
    expect(friday.contains(early), isFalse);
    expect(friday.any((h) => h.start == early.start), isTrue);
    // Saturday at noon: Saturday's day hours, Saturn's day.
    final noon = PlanetaryHours.at(
      DateTime.utc(2026, 10, 17, 5),
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
      offsetOn: wibOn,
    )!;
    expect(noon.day, isTrue);
  });
}
