import 'dart:math' as math;

import 'civil_date.dart';
import 'sky_position.dart';

/// Where the fixed stars stand in the sky of a place at a moment.
///
/// A catalogue gives each star's place on the sky for the year 2000 (its
/// right ascension and declination, J2000). The Earth's axis wobbles
/// slowly (precession, a full turn in about 26,000 years), so by today
/// every star has moved some twenty minutes of arc from where the
/// catalogue puts it. [StarSky.at] turns the J2000 sky to the moment
/// once, by the rigorous method of Meeus (Astronomical Algorithms, 2nd
/// ed., ch. 21, the IAU 1976 angles), then each star is read off it, to
/// the local horizon (ch. 13) and lifted by the same refraction as the sun
/// and moon.
///
/// Nutation and aberration, each under twenty seconds of arc, and the
/// stars' own motions are left out: invisible on a map of the whole sky.
class StarSky {
  /// The precession of J2000 positions to the moment, as a rotation of
  /// the unit sphere: rows of a 3 by 3 matrix.
  final List<double> _p;

  /// The local sidereal time, radians, and the latitude.
  final double _sidereal;
  final double _sinPhi;
  final double _cosPhi;

  StarSky._(this._p, this._sidereal, this._sinPhi, this._cosPhi);

  static const _rad = math.pi / 180;
  static const _arcsecond = _rad / 3600;

  /// The sky over [latitude], [longitude] at [instant].
  factory StarSky.at(
    DateTime instant, {
    required double latitude,
    required double longitude,
  }) {
    final jd = instant.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;
    final t = (jd - 2451545) / 36525;

    // Meeus 21.2, from J2000 (his T = 0).
    final zeta =
        (2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) * _arcsecond;
    final z =
        (2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) * _arcsecond;
    final theta =
        (2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) * _arcsecond;

    // Meeus 21.4 applied to the three axes gives the rotation's columns.
    List<double> turned(double alpha0, double delta0) {
      final a = math.cos(delta0) * math.sin(alpha0 + zeta);
      final b =
          math.cos(theta) * math.cos(delta0) * math.cos(alpha0 + zeta) -
          math.sin(theta) * math.sin(delta0);
      final c =
          math.sin(theta) * math.cos(delta0) * math.cos(alpha0 + zeta) +
          math.cos(theta) * math.sin(delta0);
      final alpha = math.atan2(a, b) + z;
      final delta = math.asin(c.clamp(-1.0, 1.0));
      return [
        math.cos(delta) * math.cos(alpha),
        math.cos(delta) * math.sin(alpha),
        math.sin(delta),
      ];
    }

    final x = turned(0, 0);
    final y = turned(math.pi / 2, 0);
    final zz = turned(0, math.pi / 2);
    final p = [x[0], y[0], zz[0], x[1], y[1], zz[1], x[2], y[2], zz[2]];

    // Mean sidereal time at Greenwich (Meeus 12.4), then here. The
    // positions are mean of the date, so the mean time goes with them.
    final greenwich =
        280.46061837 +
        360.98564736629 * (jd - 2451545) +
        0.000387933 * t * t -
        t * t * t / 38710000;
    final phi = latitude * _rad;
    return StarSky._(
      p,
      ((greenwich + longitude) % 360) * _rad,
      math.sin(phi),
      math.cos(phi),
    );
  }

  /// The right ascension and declination of the moment, in degrees, of a
  /// star the catalogue puts at [rightAscension], [declination] (J2000,
  /// degrees).
  ({double rightAscension, double declination}) ofDate(
    double rightAscension,
    double declination,
  ) {
    final (alpha, delta) = _precess(rightAscension * _rad, declination * _rad);
    return (rightAscension: (alpha / _rad) % 360, declination: delta / _rad);
  }

  (double, double) _precess(double alpha0, double delta0) {
    final cd = math.cos(delta0);
    final x = cd * math.cos(alpha0);
    final y = cd * math.sin(alpha0);
    final z = math.sin(delta0);
    final p = _p;
    final x1 = p[0] * x + p[1] * y + p[2] * z;
    final y1 = p[3] * x + p[4] * y + p[5] * z;
    final z1 = p[6] * x + p[7] * y + p[8] * z;
    return (math.atan2(y1, x1), math.asin(z1.clamp(-1.0, 1.0)));
  }

  /// Where a star the catalogue puts at [rightAscension], [declination]
  /// (J2000, degrees) stands here and now: its height above the horizon
  /// as seen, refraction and all, and its bearing from true north through
  /// east, both in degrees.
  ({double altitude, double azimuth}) place(
    double rightAscension,
    double declination,
  ) {
    final (alpha, delta) = _precess(rightAscension * _rad, declination * _rad);
    final hour = _sidereal - alpha;
    final sinAlt =
        _sinPhi * math.sin(delta) + _cosPhi * math.cos(delta) * math.cos(hour);
    final trueAltitude = math.asin(sinAlt.clamp(-1.0, 1.0)) / _rad;
    final azimuth =
        (math.atan2(
                  math.sin(hour),
                  math.cos(hour) * _sinPhi - math.tan(delta) * _cosPhi,
                ) /
                _rad +
            180) %
        360;
    return (
      altitude: trueAltitude + SkyNow.refraction(trueAltitude),
      azimuth: azimuth,
    );
  }
}

/// A star at dawn: where it stands, morning by morning, at the moment the
/// sun is a given depth below the eastern horizon. What farmers and
/// sailors read: a star first seen in the east before sunrise (its
/// heliacal rising), or last seen in the west at dawn (its setting at
/// dawn).
abstract final class StarMornings {
  /// Where the star at [rightAscension], [declination] (J2000, degrees)
  /// stands on the morning of [date] when the sun is [depression] degrees
  /// below the horizon, rising; null if the sun never gets so low (far
  /// from the equator in summer).
  static ({double altitude, double azimuth})? atDawn(
    double rightAscension,
    double declination,
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    double depression = 12,
  }) {
    final midnight = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(utcOffset);
    double sunAt(int minute) => SkyNow.sun(
      midnight.add(Duration(minutes: minute)),
      latitude: latitude,
      longitude: longitude,
    ).trueAltitude;
    // From midnight to noon the morning sun climbs through −depression
    // once; find it to the minute.
    var low = 0, high = 12 * 60;
    if (sunAt(low) >= -depression || sunAt(high) < -depression) return null;
    while (high - low > 1) {
      final middle = (low + high) ~/ 2;
      sunAt(middle) < -depression ? low = middle : high = middle;
    }
    final sky = StarSky.at(
      midnight.add(Duration(minutes: high)),
      latitude: latitude,
      longitude: longitude,
    );
    return sky.place(rightAscension, declination);
  }

  /// The first morning from [from], over at most [days] days, on which
  /// [holds] is true of the star's place at dawn.
  static CivilDate? first(
    double rightAscension,
    double declination,
    CivilDate from,
    int days, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    required bool Function(double altitude, double azimuth) holds,
    double depression = 12,
  }) {
    for (var d = 0; d < days; d++) {
      final date = from.addDays(d);
      final p = atDawn(
        rightAscension,
        declination,
        date,
        latitude: latitude,
        longitude: longitude,
        utcOffset: utcOffset,
        depression: depression,
      );
      if (p != null && holds(p.altitude, p.azimuth)) return date;
    }
    return null;
  }
}
