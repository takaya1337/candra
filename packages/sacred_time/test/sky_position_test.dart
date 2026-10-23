import 'dart:math' as math;

import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

// JPL Horizons (DE441), fetched 14 October 2026 from
// ssd.jpl.nasa.gov/api/horizons.api with EXTRA_PREC: apparent places,
// geocentric (CENTER 500@399) and from 6.2° S, 106.8° E at sea level
// (Jakarta), airless and refracted. Each row: the instant in UT;
// geocentric right ascension, declination and distance in au; the
// azimuth and the airless and refracted elevation from Jakarta.
const _sun = [
  (
    '2020-01-01T09:36:00Z',
    281.330673064,
    -23.027580332,
    0.98328455420980,
    247.687632477,
    20.819708327,
    null,
  ),
  (
    '2023-02-24T19:12:00Z',
    337.691500293,
    -9.345288838,
    0.98966974306930,
    116.067278772,
    -54.963019664,
    null,
  ),
  (
    '2026-10-14T00:00:00Z',
    199.089201170,
    -8.069791534,
    0.99765124663132,
    96.298522652,
    20.861428248,
    null,
  ),
  (
    '2026-10-14T06:00:00Z',
    199.321031561,
    -8.162809370,
    0.99757921574734,
    263.206239510,
    69.782303769,
    null,
  ),
  (
    '2026-10-14T15:00:00Z',
    199.669037540,
    -8.302110496,
    0.99747113423644,
    239.796750810,
    -61.423597188,
    null,
  ),
  (
    '2029-12-30T02:24:00Z',
    279.431060843,
    -23.151964682,
    0.98337700663302,
    118.998340780,
    49.874395468,
    null,
  ),
];

const _moon = [
  (
    '2020-01-01T09:36:00Z',
    353.639341270,
    -8.240417012,
    0.00270281718093,
    131.605703892,
    86.868282701,
    86.869211636,
  ),
  (
    '2023-02-24T19:12:00Z',
    33.676604106,
    13.530209509,
    0.00254489033140,
    288.786119161,
    -65.223119603,
    null,
  ),
  (
    '2026-10-14T00:00:00Z',
    236.087499320,
    -25.013983738,
    0.00267263037834,
    117.332275788,
    -13.226911676,
    null,
  ),
  (
    '2026-10-14T06:00:00Z',
    239.374829902,
    -25.649485517,
    0.00267749974975,
    138.006166866,
    62.464727472,
    62.473565111,
  ),
  (
    '2026-10-14T15:00:00Z',
    244.341961271,
    -26.458592869,
    0.00268420648963,
    240.344812239,
    -16.269757194,
    null,
  ),
  (
    '2029-12-30T02:24:00Z',
    207.197707224,
    -15.814512342,
    0.00245940168464,
    251.194244431,
    54.349406550,
    54.361554535,
  ),
];

// The US Naval Observatory's one-day table (aa.usno.navy.mil/api/rstt),
// fetched 14 October 2026: the place, its clock, the date, then the sun's
// civil dawn, rise, transit, set and civil dusk, and the moon's rise,
// transit and set, to the minute; null where it does not happen that day.
const _usno = [
  (
    -6.2,
    106.8,
    7,
    '2026-10-14',
    ['05:11', '05:32', '11:39', '17:46', '18:07'],
    ['07:58', '14:22', '20:47'],
  ),
  (
    -6.2,
    106.8,
    7,
    '2026-06-21',
    ['05:39', '06:02', '11:55', '17:47', '18:10'],
    ['11:21', '17:31', '23:41'],
  ),
  (
    -6.2,
    106.8,
    7,
    '2026-12-22',
    ['05:14', '05:37', '11:51', '18:06', '18:29'],
    ['16:18', '22:21', '03:20'],
  ),
  (
    -6.2,
    106.8,
    7,
    '2027-03-05',
    ['05:37', '05:58', '12:04', '18:10', '18:31'],
    ['03:23', '09:43', '16:03'],
  ),
  (
    60.2,
    24.9,
    2,
    '2026-06-21',
    ['01:00', '02:54', '12:22', '21:51', '23:44'],
    ['11:54', '18:08', '00:01'],
  ),
  (
    60.2,
    24.9,
    2,
    '2026-12-22',
    ['08:26', '09:25', '12:19', '15:13', '16:12'],
    ['12:38', '23:03', '08:15'],
  ),
];

void main() {
  test('a day worked from samples already made is the same day', () {
    final date = CivilDate(2026, 10, 14);
    const offset = Duration(hours: 7);
    final midnight = DateTime.utc(2026, 10, 14).subtract(offset);
    for (final body in const [Body.sun, Body.moon]) {
      final samples = [
        for (var minute = 0; minute <= 1440; minute += 10)
          (body == Body.sun ? SkyNow.sun : SkyNow.moon)(
            midnight.add(Duration(minutes: minute)),
            latitude: -6.2,
            longitude: 106.8,
          ),
      ];
      SkyDay of({List<SkyPosition>? samples}) => SkyNow.day(
        body,
        date,
        latitude: -6.2,
        longitude: 106.8,
        utcOffset: offset,
        samples: samples,
      );
      final plain = of();
      final given = of(samples: samples);
      expect(given.rise, plain.rise);
      expect(given.transit, plain.transit);
      expect(given.set, plain.set);
      expect(given.civilDusk, plain.civilDusk);
    }
  });

  group('the day agrees with the USNO to the minute', () {
    for (final (latitude, longitude, hours, date, sun, moon) in _usno) {
      test('$date at $latitude, $longitude', () {
        final [y, m, d] = date.split('-').map(int.parse).toList();
        final offset = Duration(hours: hours);
        SkyDay of(Body body) => SkyNow.day(
          body,
          CivilDate(y, m, d),
          latitude: latitude,
          longitude: longitude,
          utcOffset: offset,
        );
        int? minutes(DateTime? at) {
          if (at == null) return null;
          final local = at.add(offset);
          return local.hour * 60 + local.minute + (local.second >= 30 ? 1 : 0);
        }

        int clock(String hm) {
          final [h, mm] = hm.split(':').map(int.parse).toList();
          return h * 60 + mm;
        }

        final s = of(Body.sun);
        final moonDay = of(Body.moon);
        final ours = [
          minutes(s.civilDawn),
          minutes(s.rise),
          minutes(s.transit),
          minutes(s.set),
          minutes(s.civilDusk),
          minutes(moonDay.rise),
          minutes(moonDay.transit),
          minutes(moonDay.set),
        ];
        final theirs = [...sun, ...moon].map(clock).toList();
        for (var i = 0; i < ours.length; i++) {
          expect(ours[i], isNotNull, reason: 'event $i');
          expect(
            (ours[i]! - theirs[i]).abs(),
            lessThanOrEqualTo(1),
            reason: 'event $i: ours ${ours[i]}, theirs ${theirs[i]}',
          );
        }
      });
    }
  });

  void check(
    String name,
    List<(String, double, double, double, double, double, double?)> rows,
    SkyPosition Function(
      DateTime, {
      required double latitude,
      required double longitude,
      double height,
    })
    of, {
    required double angle,
    required double kilometres,
  }) {
    for (final (at, ra, dec, au, az, el, seen) in rows) {
      test('$name at $at', () {
        final p = of(DateTime.parse(at), latitude: -6.2, longitude: 106.8);
        double off(double a, double b) => ((a - b + 540) % 360 - 180).abs();
        expect(off(p.rightAscension, ra), lessThan(angle));
        expect((p.declination - dec).abs(), lessThan(angle));
        expect(
          (p.distance - au * SkyNow.astronomicalUnit).abs(),
          lessThan(kilometres),
        );
        expect(off(p.azimuth, az) * (1 - el.abs() / 90), lessThan(angle));
        expect((p.trueAltitude - el).abs(), lessThan(angle));
        if (seen != null) expect((p.altitude - seen).abs(), lessThan(angle));
      });
    }
  }

  check('sun', _sun, SkyNow.sun, angle: 3 / 3600, kilometres: 300);
  check('moon', _moon, SkyNow.moon, angle: 10 / 3600, kilometres: 50);

  group('the bearing of the rise and set', () {
    // Where a body meets the horizon, by the spherical triangle alone:
    // cos A = sin(declination) / cos(latitude), A from north through
    // east. Refraction and the disc shift the true bearing by a few tenths
    // of a degree, so half a degree is the tolerance.
    double horizonBearing(double declination, double latitude) {
      const rad = math.pi / 180;
      return math.acos(math.sin(declination * rad) / math.cos(latitude * rad)) /
          rad;
    }

    for (final (date, label) in [
      (CivilDate(2026, 6, 21), 'June solstice'),
      (CivilDate(2026, 3, 20), 'March equinox'),
      (CivilDate(2026, 12, 21), 'December solstice'),
    ]) {
      test('the sun at Jakarta, $label', () {
        const latitude = -6.2, longitude = 106.8;
        const offset = Duration(hours: 7);
        final day = SkyNow.day(
          Body.sun,
          date,
          latitude: latitude,
          longitude: longitude,
          utcOffset: offset,
        );
        final noon = SkyNow.sun(
          day.transit!,
          latitude: latitude,
          longitude: longitude,
        );
        final rise = horizonBearing(noon.declination, latitude);
        expect(day.riseAzimuth!, closeTo(rise, 0.5));
        expect(day.setAzimuth!, closeTo(360 - rise, 0.5));
      });
    }

    test('a body that does not rise has no bearing either', () {
      // Far north in midwinter, the sun stays down all day.
      final day = SkyNow.day(
        Body.sun,
        CivilDate(2026, 12, 21),
        latitude: 78.2,
        longitude: 15.6,
        utcOffset: const Duration(hours: 1),
      );
      expect(day.rise, isNull);
      expect(day.riseAzimuth, isNull);
      expect(day.setAzimuth, isNull);
    });
  });
}
