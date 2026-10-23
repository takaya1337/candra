import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sacred_time/sacred_time.dart';

/// The sun (and, over a month, the moon) over a run of days at one place,
/// every ten minutes of every day by the local clock: worked out once,
/// away from the screen, and everything the month's and the year's views
/// draw is read from it. Dragging through the days then costs nothing.
///
/// A track is a run of height, bearing pairs in degrees, as the eye sees
/// them.
class SkyGrid {
  final double latitude;
  final double longitude;

  /// The first day.
  final CivilDate first;

  /// How many days.
  final int days;

  /// Samples in a day: midnight to the next midnight, every ten minutes.
  static const samples = 145;

  /// Half hours in a day, the rows of the pictures.
  static const halfHours = 48;

  /// `days` tracks of [samples] pairs each.
  final Float32List sun;
  final Float32List? moon;

  SkyGrid({
    required this.latitude,
    required this.longitude,
    required this.first,
    required this.days,
    required this.sun,
    this.moon,
  });

  /// The track of day [day] (0 is [first]).
  Float32List trackOf(Float32List grid, int day) =>
      Float32List.sublistView(grid, day * samples * 2, (day + 1) * samples * 2);

  /// How high it stands at each half hour of each day: the picture's
  /// cells.
  Float32List heightsOf(Float32List grid) {
    final heights = Float32List(days * halfHours);
    for (var day = 0; day < days; day++) {
      for (var half = 0; half < halfHours; half++) {
        heights[day * halfHours + half] = grid[(day * samples + half * 3) * 2];
      }
    }
    return heights;
  }

  late final Float32List sunHeights = heightsOf(sun);
  late final Float32List? moonHeights = moon == null ? null : heightsOf(moon!);

  /// Where it stands at [minute] by the clock on every [every]th day,
  /// between the ten-minute samples by a straight line (the sun moves a
  /// quarter of a degree a minute, the line is good to a hundredth).
  Float32List locus(Float32List grid, int minute, {int every = 1}) {
    final step = minute ~/ 10;
    final part = (minute % 10) / 10;
    final count = (days + every - 1) ~/ every;
    final points = Float32List(count * 2);
    for (var i = 0; i < count; i++) {
      final at = (i * every * samples + step) * 2;
      final next = math.min(step + 1, samples - 1) - step;
      final h0 = grid[at];
      final a0 = grid[at + 1];
      final h1 = grid[at + next * 2];
      var a1 = grid[at + next * 2 + 1];
      // The bearing the short way round.
      if (a1 - a0 > 180) a1 -= 360;
      if (a0 - a1 > 180) a1 += 360;
      points[i * 2] = h0 + (h1 - h0) * part;
      points[i * 2 + 1] = (a0 + (a1 - a0) * part) % 360;
    }
    return points;
  }

  /// The grid of [days] days from [first], each day's clock ahead of UTC
  /// by [offsetSeconds].
  static ({Float32List sun, Float32List? moon}) work(
    CivilDate first,
    int days,
    double latitude,
    double longitude,
    List<int> offsetSeconds, {
    required bool withMoon,
  }) {
    final sun = Float32List(days * samples * 2);
    final moon = withMoon ? Float32List(days * samples * 2) : null;
    for (var day = 0; day < days; day++) {
      final date = first.addDays(day);
      final midnight = DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(seconds: offsetSeconds[day]));
      for (var i = 0; i < samples; i++) {
        final at = midnight.add(Duration(minutes: i * 10));
        final k = (day * samples + i) * 2;
        final s = SkyNow.sun(at, latitude: latitude, longitude: longitude);
        sun[k] = s.altitude;
        sun[k + 1] = s.azimuth;
        if (moon != null) {
          final m = SkyNow.moon(at, latitude: latitude, longitude: longitude);
          moon[k] = m.altitude;
          moon[k + 1] = m.azimuth;
        }
      }
    }
    return (sun: sun, moon: moon);
  }
}

/// The sun over a whole year: the year view's sun-path diagram and its
/// picture.
///
///  * [tracks]: its path on the 21st of each month, the twelve arcs of
///    the diagram, the solstices outermost.
///  * [loops]: where it stands at each whole hour of the clock through
///    the year, every other day: the figure-of-eight (the analemma) of
///    each hour.
class SkyYear extends SkyGrid {
  final int year;

  SkyYear({
    required this.year,
    required super.latitude,
    required super.longitude,
    required super.days,
    required super.sun,
  }) : super(first: CivilDate(year, 1, 1));

  /// Twelve tracks, January's first.
  late final List<Float32List> tracks = [
    for (var month = 1; month <= 12; month++)
      trackOf(sun, CivilDate(year, month, 21).dayNumber - first.dayNumber),
  ];

  /// Twenty-four loops, midnight's first; one the sun never stands above
  /// the horizon at is empty.
  late final List<Float32List> loops = [
    for (var hour = 0; hour < 24; hour++) _loop(hour),
  ];

  Float32List _loop(int hour) {
    final loop = locus(sun, hour * 60, every: 2);
    for (var i = 0; i < loop.length; i += 2) {
      if (loop[i] > 0) return loop;
    }
    return Float32List(0);
  }

  /// Works the year out away from the screen, so nothing stutters.
  /// Replaced in tests with [compute] itself.
  static Future<SkyYear> Function(
    int year,
    double latitude,
    double longitude,
    List<int> offsetSeconds,
  )
  build = (year, latitude, longitude, offsetSeconds) =>
      Isolate.run(() => compute(year, latitude, longitude, offsetSeconds));

  /// The year, its clock ahead of UTC on each day by [offsetSeconds].
  static SkyYear compute(
    int year,
    double latitude,
    double longitude,
    List<int> offsetSeconds,
  ) {
    final first = CivilDate(year, 1, 1);
    final days = CivilDate(year + 1, 1, 1).dayNumber - first.dayNumber;
    final grid = SkyGrid.work(
      first,
      days,
      latitude,
      longitude,
      offsetSeconds,
      withMoon: false,
    );
    return SkyYear(
      year: year,
      latitude: latitude,
      longitude: longitude,
      days: days,
      sun: grid.sun,
    );
  }
}

/// The sun and the moon over one month: the month view.
class SkyMonth extends SkyGrid {
  final int year;
  final int month;

  SkyMonth({
    required this.year,
    required this.month,
    required super.latitude,
    required super.longitude,
    required super.days,
    required super.sun,
    required Float32List super.moon,
  }) : super(first: CivilDate(year, month, 1));

  /// Works the month out away from the screen. Replaced in tests with
  /// [compute] itself.
  static Future<SkyMonth> Function(
    int year,
    int month,
    double latitude,
    double longitude,
    List<int> offsetSeconds,
  )
  build = (year, month, latitude, longitude, offsetSeconds) => Isolate.run(
    () => compute(year, month, latitude, longitude, offsetSeconds),
  );

  /// The month, its clock ahead of UTC on each day by [offsetSeconds].
  static SkyMonth compute(
    int year,
    int month,
    double latitude,
    double longitude,
    List<int> offsetSeconds,
  ) {
    final first = CivilDate(year, month, 1);
    final days =
        (month == 12
                ? CivilDate(year + 1, 1, 1)
                : CivilDate(year, month + 1, 1))
            .dayNumber -
        first.dayNumber;
    final grid = SkyGrid.work(
      first,
      days,
      latitude,
      longitude,
      offsetSeconds,
      withMoon: true,
    );
    return SkyMonth(
      year: year,
      month: month,
      latitude: latitude,
      longitude: longitude,
      days: days,
      sun: grid.sun,
      moon: grid.moon!,
    );
  }
}
