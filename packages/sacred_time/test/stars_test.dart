import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

/// The fixed stars: precession checked against Meeus's worked example,
/// and the turn to the horizon against what must hold for any star.
void main() {
  DateTime fromJulianDay(double jd) => DateTime.fromMillisecondsSinceEpoch(
    ((jd - 2440587.5) * 86400000).round(),
    isUtc: true,
  );

  test('precession agrees with Meeus example 21.b, theta Persei to 2028', () {
    // The J2000 place with the star's own motion already carried to the
    // date, as the example gives it; the answer to the sixth decimal.
    final sky = StarSky.at(
      fromJulianDay(2462088.69),
      latitude: 0,
      longitude: 0,
    );
    final of = sky.ofDate(41.054063, 49.227750);
    expect(of.rightAscension, closeTo(41.547214, 0.00002));
    expect(of.declination, closeTo(49.348483, 0.00002));
  });

  test('a star culminates at 90 degrees less its distance from the zenith, '
      'due south or north', () {
    // Sirius (J2000) from Jakarta, through a whole night in ten-minute
    // steps: the highest it gets is 90 - |latitude - declination|.
    const ra = 101.287155, dec = -16.716116;
    const latitude = -6.2;
    var best = -90.0;
    var bearing = 0.0;
    final start = DateTime.utc(2026, 1, 15, 10);
    for (var m = 0; m < 24 * 60; m += 2) {
      final p = StarSky.at(
        start.add(Duration(minutes: m)),
        latitude: latitude,
        longitude: 106.8,
      ).place(ra, dec);
      if (p.altitude > best) {
        best = p.altitude;
        bearing = p.azimuth;
      }
    }
    final ofDate = StarSky.at(start, latitude: 0, longitude: 0).ofDate(ra, dec);
    expect(best, closeTo(90 - (latitude - ofDate.declination).abs(), 0.1));
    // South of the zenith from Jakarta: it culminates due south.
    expect(bearing, closeTo(180, 1.5));
  });

  test('the celestial pole stands as high as the latitude is', () {
    // The pole of the date, at any hour: its height is the latitude.
    final sky = StarSky.at(
      DateTime.utc(2026, 10, 16, 15),
      latitude: 45,
      longitude: 10,
    );
    // The J2000 pole, precessed 26 years, is within a few arcminutes of
    // the pole of date: its height within a tenth of a degree.
    final pole = sky.place(0, 90);
    expect(pole.altitude, closeTo(45, 0.15));
  });

  test('Orion\'s Belt first stands in the east before dawn at the turn '
      'of June and July, and has set by dawn at the end of December, '
      'from Yogyakarta', () {
    // Alnilam, J2000; the sun 12° down; the star 5° up.
    const ra = 84.05338, dec = -1.20192;
    CivilDate? first(CivilDate from, bool Function(double, double) holds) =>
        StarMornings.first(
          ra,
          dec,
          from,
          200,
          latitude: -7.80,
          longitude: 110.36,
          utcOffset: const Duration(hours: 7),
          holds: holds,
        );
    final rises = first(
      CivilDate(2026, 4, 1),
      (alt, az) => alt >= 5 && az < 180,
    )!;
    expect(
      rises.dayNumber,
      inInclusiveRange(
        CivilDate(2026, 6, 25).dayNumber,
        CivilDate(2026, 7, 5).dayNumber,
      ),
    );
    final sets = first(
      CivilDate(2026, 9, 1),
      (alt, az) => alt <= 5 && az > 180,
    )!;
    expect(
      sets.dayNumber,
      inInclusiveRange(
        CivilDate(2026, 12, 22).dayNumber,
        CivilDate(2027, 1, 3).dayNumber,
      ),
    );
    // The morning before it first holds, it does not.
    final before = StarMornings.atDawn(
      ra,
      dec,
      CivilDate.fromDayNumber(rises.dayNumber - 1),
      latitude: -7.80,
      longitude: 110.36,
      utcOffset: const Duration(hours: 7),
    )!;
    expect(before.altitude < 5 || before.azimuth >= 180, isTrue);
  });

  test('there is no dawn of 12° where the sun never sinks that far', () {
    // Tromsø at midsummer: the sun stays up all night.
    expect(
      StarMornings.atDawn(
        84.05338,
        -1.20192,
        CivilDate(2026, 6, 21),
        latitude: 69.65,
        longitude: 18.96,
        utcOffset: const Duration(hours: 2),
      ),
      isNull,
    );
  });
}
