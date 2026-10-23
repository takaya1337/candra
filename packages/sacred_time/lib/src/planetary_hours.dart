import 'civil_date.dart';
import 'sky_position.dart';
import 'weton.dart';

/// One planetary hour: a twelfth of the day (sunrise to sunset) or of
/// the night (sunset to the next sunrise), and the planet that rules it.
class PlanetaryHour {
  final Body ruler;
  final DateTime start;
  final DateTime end;

  /// The first twelve are the day's, the last twelve the night's.
  final bool day;

  /// 1 to 12, within the day or the night.
  final int number;

  const PlanetaryHour({
    required this.ruler,
    required this.start,
    required this.end,
    required this.day,
    required this.number,
  });

  bool holds(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);
}

/// The planetary hours of the old astrologers. The daylight from sunrise
/// to sunset is cut into twelve equal hours and the night after it into
/// twelve more, so the hours of a summer day are long and of a winter
/// day short (Agrippa II.34; Chaucer, Astrolabe II.10–12; the Key of
/// Solomon I.2). Sunrise and sunset are the sun's centre on the horizon,
/// with no air, as the tradition took them (Chaucer: the sun's own degree
/// on the horizon); the almanacs' upper edge and refraction are modern.
/// The night belongs to the day before it: Thursday night, malam Jumat,
/// is in Thursday's hours.
///
/// The hours are given to the seven planets in the Chaldean order, from
/// the slowest to the swiftest (Saturn, Jupiter, Mars, the sun, Venus,
/// Mercury, the moon), over and over; the first hour of the day belongs
/// to the planet the day is named for. Twenty-four hours on,
/// the next day's first hour falls to the planet three places further
/// down the order, which is how the week's days have the order they do.
abstract final class PlanetaryHours {
  /// Slowest to swiftest.
  static const chaldean = [
    Body.saturn,
    Body.jupiter,
    Body.mars,
    Body.sun,
    Body.venus,
    Body.mercury,
    Body.moon,
  ];

  /// The planet a weekday is named for, and whose day it is: the sun's
  /// Sunday, the moon's Monday, Mars's Tuesday, Mercury's Wednesday,
  /// Jupiter's Thursday, Venus's Friday, Saturn's Saturday.
  static Body rulerOf(Weekday weekday) => switch (weekday) {
    Weekday.minggu => Body.sun,
    Weekday.senin => Body.moon,
    Weekday.selasa => Body.mars,
    Weekday.rabu => Body.mercury,
    Weekday.kamis => Body.jupiter,
    Weekday.jumat => Body.venus,
    Weekday.sabtu => Body.saturn,
  };

  /// The twenty-four hours of the planetary day that begins at sunrise on
  /// [date] at the place: null where the sun does not both rise that day
  /// and the next and set between (far north and south).
  static List<PlanetaryHour>? of(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    Duration? nextOffset,
  }) {
    DateTime? centre(CivilDate day, Duration offset, {required bool rising}) =>
        SkyNow.passing(
          Body.sun,
          day,
          latitude: latitude,
          longitude: longitude,
          utcOffset: offset,
          altitude: 0,
          rising: rising,
        );
    final rise = centre(date, utcOffset, rising: true);
    final set = centre(date, utcOffset, rising: false);
    final next = centre(date.addDays(1), nextOffset ?? utcOffset, rising: true);
    if (rise == null || set == null || next == null || !set.isAfter(rise)) {
      return null;
    }
    final first = chaldean.indexOf(rulerOf(Weekday.of(date)));
    final dayHour = set.difference(rise) ~/ 12;
    final nightHour = next.difference(set) ~/ 12;
    return [
      for (var k = 0; k < 24; k++)
        PlanetaryHour(
          ruler: chaldean[(first + k) % 7],
          start: k < 12 ? rise.add(dayHour * k) : set.add(nightHour * (k - 12)),
          end: k < 11
              ? rise.add(dayHour * (k + 1))
              : k == 11
              ? set
              : k < 23
              ? set.add(nightHour * (k - 11))
              : next,
          day: k < 12,
          number: k % 12 + 1,
        ),
    ];
  }

  /// The hour that holds [instant] at the place: the day's from its
  /// sunrise, or before sunrise the night of the day before. [offsetOn]
  /// gives the clock's offset on a date. Null where there are no hours.
  static PlanetaryHour? at(
    DateTime instant, {
    required double latitude,
    required double longitude,
    required Duration Function(CivilDate date) offsetOn,
  }) {
    final wall = instant.toUtc().add(offsetOn(_dateOf(instant)));
    final date = CivilDate(wall.year, wall.month, wall.day);
    for (final day in [date, date.addDays(-1)]) {
      final hours = of(
        day,
        latitude: latitude,
        longitude: longitude,
        utcOffset: offsetOn(day),
        nextOffset: offsetOn(day.addDays(1)),
      );
      if (hours == null) continue;
      for (final h in hours) {
        if (h.holds(instant)) return h;
      }
    }
    return null;
  }

  // The UTC date of [instant], for a first guess at its offset.
  static CivilDate _dateOf(DateTime instant) {
    final u = instant.toUtc();
    return CivilDate(u.year, u.month, u.day);
  }
}
