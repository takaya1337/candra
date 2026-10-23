import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  String clock(int? minute) => minute == null
      ? 'none'
      : '${(minute ~/ 60).toString().padLeft(2, '0')}:'
            '${(minute % 60).toString().padLeft(2, '0')}';

  group('the sun', () {
    test('rises and sets in London at midsummer as the almanacs say', () {
      // 21 June 2024, British Summer Time: 04:43 and 21:21.
      final sun = Sky.sun(
        CivilDate(2024, 6, 21),
        latitude: 51.5074,
        longitude: -0.1278,
        utcOffset: const Duration(hours: 1),
      );
      expect(sun.rise, closeTo(4 * 60 + 43, 2), reason: clock(sun.rise));
      expect(sun.set, closeTo(21 * 60 + 21, 2), reason: clock(sun.set));
      // Highest about 62 degrees, at about one in the afternoon.
      expect(sun.highest, closeTo(61.9, 0.5));
      expect(sun.highestAt, closeTo(13 * 60, 10));
    });

    test('keeps near twelve hours of day on the equator all year', () {
      for (final month in [1, 4, 7, 10]) {
        final sun = Sky.sun(
          CivilDate(2026, month, 12),
          latitude: 0,
          longitude: 110.4,
          utcOffset: const Duration(hours: 7),
        );
        expect(sun.set! - sun.rise!, closeTo(12 * 60 + 7, 3));
      }
    });

    test('in Yogyakarta in October is up a little after five', () {
      final sun = Sky.sun(
        CivilDate(2026, 10, 12),
        latitude: -7.8,
        longitude: 110.4,
        utcOffset: const Duration(hours: 7),
      );
      expect(sun.rise, closeTo(5 * 60 + 14, 4), reason: clock(sun.rise));
      expect(sun.set, closeTo(17 * 60 + 32, 4), reason: clock(sun.set));
      expect(sun.altitudes, hasLength(145));
      expect(sun.altitudeAt(0), lessThan(0));
      expect(sun.altitudeAt(sun.rise!), closeTo(-0.83, 0.3));
    });

    test(
      'does not set at midsummer in the far north, nor rise at midwinter',
      () {
        final summer = Sky.sun(
          CivilDate(2026, 6, 21),
          latitude: 78.2,
          longitude: 15.6,
          utcOffset: const Duration(hours: 2),
        );
        expect(summer.rise, isNull);
        expect(summer.set, isNull);
        expect(summer.altitudes.every((a) => a > 0), isTrue);
        final winter = Sky.sun(
          CivilDate(2026, 12, 21),
          latitude: 78.2,
          longitude: 15.6,
          utcOffset: const Duration(hours: 1),
        );
        expect(winter.rise, isNull);
        expect(winter.altitudes.every((a) => a < 0), isTrue);
      },
    );
  });

  group('the moon', () {
    const yogya = (latitude: -7.8, longitude: 110.4);
    const offset = Duration(hours: 7);

    SkyPath moonOn(CivilDate date) => Sky.moon(
      date,
      latitude: yogya.latitude,
      longitude: yogya.longitude,
      utcOffset: offset,
    );

    test('rises about as the sun sets when it is full', () {
      // 26 October 2026 is a full moon.
      final date = CivilDate(2026, 10, 26);
      final sun = Sky.sun(
        date,
        latitude: yogya.latitude,
        longitude: yogya.longitude,
        utcOffset: offset,
      );
      final moon = moonOn(date);
      expect(moon.rise, closeTo(sun.set!, 45), reason: clock(moon.rise));
    });

    test('rises with the sun when it is new, and later every day after', () {
      final dark = Sky.nextPhase(
        CivilDate(2026, 10, 1),
        utcOffset: offset,
        elongation: 0,
      ).add(offset);
      final date = CivilDate(dark.year, dark.month, dark.day);
      final sun = Sky.sun(
        date,
        latitude: yogya.latitude,
        longitude: yogya.longitude,
        utcOffset: offset,
      );
      expect(moonOn(date).rise, closeTo(sun.rise!, 45));

      // About fifty minutes later each day, give or take.
      for (var day = 1; day < 8; day++) {
        final today = moonOn(date.addDays(day)).rise!;
        final yesterday = moonOn(date.addDays(day - 1)).rise!;
        expect(today - yesterday, inInclusiveRange(25, 80));
      }
    });

    test('has one day in a month with no moonrise', () {
      var without = 0;
      for (var day = 0; day < 30; day++) {
        if (moonOn(CivilDate(2026, 10, 1).addDays(day)).rise == null) {
          without++;
        }
      }
      expect(without, 1);
    });
  });

  group('the next phase', () {
    const offset = Duration(hours: 7);

    test('is the full moon of 26 October 2026, from any day before it', () {
      for (final from in [CivilDate(2026, 10, 12), CivilDate(2026, 10, 26)]) {
        final full = Sky.nextPhase(from, utcOffset: offset);
        // 04:12 Universal Time.
        expect(
          full.difference(DateTime.utc(2026, 10, 26, 4, 12)).inMinutes.abs(),
          lessThan(5),
          reason: '$full',
        );
        expect(Moon.elongationAt(full), closeTo(180, 0.01));
      }
    });

    test('is the one after, from the day after', () {
      final full = Sky.nextPhase(CivilDate(2026, 10, 27), utcOffset: offset);
      expect(full.month, 11);
      expect(full.day, 24);
    });

    test('finds the new moon too', () {
      final dark = Sky.nextPhase(
        CivilDate(2026, 10, 1),
        utcOffset: offset,
        elongation: 0,
      );
      expect(
        Moon.elongationAt(dark) % 360,
        anyOf(lessThan(0.01), greaterThan(359.99)),
      );
      expect(dark.month, 10);
      expect(dark.day, 10);
    });
  });
}
