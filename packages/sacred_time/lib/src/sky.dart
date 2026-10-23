import 'dart:math' as math;

import 'civil_date.dart';
import 'moon.dart';

/// The path of the sun or the moon across one civil day at one place: how
/// high it stands through the day, and when it rises and sets.
///
/// Times are minutes after local midnight, by the clock of the UTC offset
/// asked for. They are good to a minute or two, which is as well as the
/// horizon and the air allow anyway.
class SkyPath {
  /// Minutes between two of [altitudes].
  static const step = 10;

  /// Height above the horizon in degrees, every [step] minutes from local
  /// midnight to the next midnight inclusive: 145 of them.
  final List<double> altitudes;

  /// When it comes up over the horizon, or null if it does not that day:
  /// it stays up, stays down, or (the moon, about one day a month) rises
  /// only after midnight.
  final int? rise;

  /// When it goes down, or null if it does not that day.
  final int? set;

  const SkyPath({required this.altitudes, this.rise, this.set});

  /// The most it stands above the horizon that day, in degrees.
  double get highest => altitudes.reduce(math.max);

  /// When it stands highest, in minutes after local midnight.
  int get highestAt => altitudes.indexOf(highest) * step;

  /// Its height at [minute] after local midnight, in degrees.
  double altitudeAt(int minute) {
    final at = (minute / step).clamp(0, altitudes.length - 1.0);
    final before = at.floor();
    final after = math.min(before + 1, altitudes.length - 1);
    return altitudes[before] +
        (altitudes[after] - altitudes[before]) * (at - before);
  }
}

/// Where the sun and the moon are in the sky of a place.
abstract final class Sky {
  static const _rad = math.pi / 180;

  // The altitude of its centre at which a body is seen to touch the
  // horizon: the sun's upper edge with the air's bending allowed for, and
  // the moon's with its nearness allowed for as well.
  static const _sunHorizon = -0.833;
  static const _moonHorizon = 0.125;

  /// The sun's path over [date] as seen from [latitude], [longitude]
  /// (degrees, north and east positive).
  static SkyPath sun(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
  }) => _path(
    date,
    latitude,
    longitude,
    utcOffset,
    _sunHorizon,
    (jd) => (Moon.sunLongitudeAt(jd), 0.0),
  );

  /// The moon's path over [date] as seen from [latitude], [longitude].
  static SkyPath moon(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
  }) => _path(
    date,
    latitude,
    longitude,
    utcOffset,
    _moonHorizon,
    (jd) => (Moon.moonLongitudeAt(jd), Moon.moonLatitudeAt(jd)),
  );

  /// The next instant, at or after the start of [from], that the moon is
  /// [elongation] degrees round from the sun: 180 for the full moon, 0 for
  /// the new. In Universal Time.
  static DateTime nextPhase(
    CivilDate from, {
    required Duration utcOffset,
    double elongation = 180,
  }) {
    final start = DateTime.utc(
      from.year,
      from.month,
      from.day,
    ).subtract(utcOffset);
    // How far short of the phase the moon is, -180..180; it grows by
    // about twelve degrees a day.
    double short(DateTime at) =>
        (Moon.elongationAt(at) - elongation + 540) % 360 - 180;

    var before = start;
    // A phase in the first hours of the day is still that day's.
    if (short(before) >= 0 && short(before) < 1) return before;
    while (true) {
      final after = before.add(const Duration(hours: 6));
      if (short(before) < 0 && short(after) >= 0) {
        var low = before;
        var high = after;
        while (high.difference(low) > const Duration(seconds: 30)) {
          final middle = low.add(high.difference(low) ~/ 2);
          short(middle) < 0 ? low = middle : high = middle;
        }
        return high;
      }
      before = after;
    }
  }

  static SkyPath _path(
    CivilDate date,
    double latitude,
    double longitude,
    Duration utcOffset,
    double horizon,
    (double longitude, double latitude) Function(double julianDay) body,
  ) {
    // The Julian Day of local midnight, in Universal Time.
    final midnight =
        date.dayNumber - 0.5 - utcOffset.inSeconds / Duration.secondsPerDay;
    double at(double minute) =>
        _altitude(midnight + minute / 1440, latitude, longitude, body);

    final altitudes = [
      for (var minute = 0; minute <= 1440; minute += SkyPath.step)
        at(minute.toDouble()),
    ];
    int? rise;
    int? set;
    for (var i = 0; i + 1 < altitudes.length; i++) {
      final up = altitudes[i] < horizon && altitudes[i + 1] >= horizon;
      final down = altitudes[i] >= horizon && altitudes[i + 1] < horizon;
      if (!up && !down) continue;
      // Narrowed to the minute.
      var low = i * SkyPath.step.toDouble();
      var high = low + SkyPath.step;
      while (high - low > 0.5) {
        final middle = (low + high) / 2;
        (at(middle) >= horizon) == up ? high = middle : low = middle;
      }
      final minute = ((low + high) / 2).round();
      if (up) {
        rise ??= minute;
      } else {
        set ??= minute;
      }
    }
    return SkyPath(altitudes: altitudes, rise: rise, set: set);
  }

  // Height above the horizon, in degrees, of a body at ecliptic
  // coordinates given by [body], at a Julian Day in Universal Time.
  static double _altitude(
    double julianDay,
    double latitude,
    double longitude,
    (double, double) Function(double) body,
  ) {
    final (lambdaDegrees, betaDegrees) = body(julianDay);
    final lambda = lambdaDegrees * _rad;
    final beta = betaDegrees * _rad;
    final t = (julianDay - 2451545) / 36525;
    final tilt = (23.4392911 - 0.0130042 * t) * _rad;

    final rightAscension = math.atan2(
      math.sin(lambda) * math.cos(tilt) - math.tan(beta) * math.sin(tilt),
      math.cos(lambda),
    );
    final declination = math.asin(
      math.sin(beta) * math.cos(tilt) +
          math.cos(beta) * math.sin(tilt) * math.sin(lambda),
    );
    // Sidereal time at Greenwich, then here.
    final sidereal =
        (280.46061837 + 360.98564736629 * (julianDay - 2451545) + longitude) *
        _rad;
    final hourAngle = sidereal - rightAscension;
    final phi = latitude * _rad;
    return math.asin(
          math.sin(phi) * math.sin(declination) +
              math.cos(phi) * math.cos(declination) * math.cos(hourAngle),
        ) /
        _rad;
  }
}
