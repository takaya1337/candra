import 'dart:math' as math;

import 'civil_date.dart';

/// The eight named phases of the moon.
enum MoonPhase {
  newMoon('New Moon'),
  waxingCrescent('Waxing Crescent'),
  firstQuarter('First Quarter'),
  waxingGibbous('Waxing Gibbous'),
  fullMoon('Full Moon'),
  waningGibbous('Waning Gibbous'),
  lastQuarter('Last Quarter'),
  waningCrescent('Waning Crescent');

  final String label;

  const MoonPhase(this.label);

  /// New, first quarter, full and last quarter: the phases that happen at
  /// an instant rather than lasting for days.
  bool get isPrincipal => index.isEven;

  bool get isWaxing => index > 0 && index < 4;
}

/// The moon on a given civil day.
///
/// Computed from the truncated lunar and solar series in Meeus,
/// *Astronomical Algorithms* (chapters 25 and 47). Phase instants land
/// within a few minutes of published almanac times.
class Moon {
  final MoonPhase phase;

  /// Angle from the sun to the moon along the ecliptic at local noon, in
  /// degrees: 0 at new moon, 180 at full.
  final double elongation;

  const Moon._(this.phase, this.elongation);

  /// The moon on [date], for a day running midnight to midnight at
  /// [utcOffset]. A principal phase names the day its instant falls in.
  factory Moon.of(CivilDate date, {required Duration utcOffset}) {
    final midnight =
        date.dayNumber - 0.5 - utcOffset.inSeconds / Duration.secondsPerDay;
    final start = _elongation(midnight);
    final dayArc = (_elongation(midnight + 1) - start) % 360;

    var phase = MoonPhase.values[2 * (start ~/ 90) + 1];
    for (var quarter = 0; quarter < 4; quarter++) {
      if ((quarter * 90 - start) % 360 < dayArc) {
        phase = MoonPhase.values[2 * quarter];
      }
    }
    return Moon._(phase, _elongation(midnight + 0.5));
  }

  /// Sun-to-moon elongation in degrees, 0..360, at [instant].
  static double elongationAt(DateTime instant) =>
      _elongation(2440587.5 + instant.toUtc().microsecondsSinceEpoch / 86400e6);

  /// The sun's apparent longitude along the ecliptic in degrees, 0..360,
  /// at a Julian Day in Universal Time: 0 at the March equinox. What the
  /// solar terms of the Chinese calendar are counted by.
  static double sunLongitudeAt(double julianDay) {
    final year = 2000 + (julianDay - 2451545) / 365.25;
    final t = (julianDay + _deltaT(year) / 86400 - 2451545) / 36525;
    return _sunLongitude(t) % 360;
  }

  /// Terrestrial Time minus Universal Time in seconds, for a year given
  /// with its fraction.
  static double deltaTSeconds(double year) => _deltaT(year);

  /// The moon's geocentric longitude along the ecliptic in degrees,
  /// 0..360, at a Julian Day in Universal Time.
  static double moonLongitudeAt(double julianDay) {
    final year = 2000 + (julianDay - 2451545) / 365.25;
    final t = (julianDay + _deltaT(year) / 86400 - 2451545) / 36525;
    return _moonLongitude(t) % 360;
  }

  /// The moon's geocentric latitude off the ecliptic in degrees, at a
  /// Julian Day in Universal Time: the whole of Meeus table 47.B, good to
  /// some four seconds of arc.
  static double moonLatitudeAt(double julianDay) {
    final t = _centuries(julianDay);
    final (:d, :m, :mp, :f, :e) = _arguments(t);
    final mean = _meanLongitude(t) * _rad;
    var sum = 0.0;
    for (final [cd, cm, cmp, cf, coefficient] in _latitudeTerms) {
      sum +=
          coefficient *
          _eccentricity(cm, e) *
          math.sin(cd * d + cm * m + cmp * mp + cf * f);
    }
    final a1 = (119.75 + 131.849 * t) * _rad;
    final a3 = (313.45 + 481266.484 * t) * _rad;
    sum +=
        -2235 * math.sin(mean) +
        382 * math.sin(a3) +
        175 * math.sin(a1 - f) +
        175 * math.sin(a1 + f) +
        127 * math.sin(mean - mp) -
        115 * math.sin(mean + mp);
    return sum / 1e6;
  }

  /// The distance between the centres of the Earth and the moon in
  /// kilometres, at a Julian Day in Universal Time (Meeus table 47.A):
  /// within fifty kilometres of the JPL ephemeris.
  static double moonDistanceAt(double julianDay) {
    final (:d, :m, :mp, :f, :e) = _arguments(_centuries(julianDay));
    var sum = 0.0;
    for (final [cd, cm, cmp, cf, _, coefficient] in _longitudeTerms) {
      if (coefficient == 0) continue;
      sum +=
          coefficient *
          _eccentricity(cm, e) *
          math.cos(cd * d + cm * m + cmp * mp + cf * f);
    }
    return 385000.56 + sum / 1000;
  }

  // Julian centuries of Terrestrial Time from J2000 at a Julian Day in
  // Universal Time.
  static double _centuries(double julianDay) {
    final year = 2000 + (julianDay - 2451545) / 365.25;
    return (julianDay + _deltaT(year) / 86400 - 2451545) / 36525;
  }

  // Terms with the sun's anomaly once or twice shrink with the Earth's
  // orbit, which is slowly becoming rounder.
  static double _eccentricity(num multiple, double e) =>
      multiple.abs() == 2 ? e * e : (multiple == 0 ? 1.0 : e);

  // The moon's mean longitude, in degrees.
  static double _meanLongitude(double t) =>
      218.3164477 +
      481267.88123421 * t -
      0.0015786 * t * t +
      t * t * t / 538841 -
      t * t * t * t / 65194000;

  // The fundamental arguments in radians (Meeus 47.2 to 47.6): the
  // moon's elongation, the sun's and the moon's anomalies, the moon's
  // distance from its node; and the eccentricity factor.
  static ({double d, double m, double mp, double f, double e}) _arguments(
    double t,
  ) => (
    d:
        (297.8501921 +
            445267.1114034 * t -
            0.0018819 * t * t +
            t * t * t / 545868 -
            t * t * t * t / 113065000) *
        _rad,
    m:
        (357.5291092 +
            35999.0502909 * t -
            0.0001536 * t * t +
            t * t * t / 24490000) *
        _rad,
    mp:
        (134.9633964 +
            477198.8675055 * t +
            0.0087414 * t * t +
            t * t * t / 69699 -
            t * t * t * t / 14712000) *
        _rad,
    f:
        (93.2720950 +
            483202.0175233 * t -
            0.0036539 * t * t -
            t * t * t / 3526000 +
            t * t * t * t / 863310000) *
        _rad,
    e: 1 - 0.002516 * t - 0.0000074 * t * t,
  );

  /// The lit fraction of the disc, 0 at new moon and 1 at full.
  double get illumination => (1 - math.cos(elongation * _rad)) / 2;

  @override
  String toString() => '${phase.label} ${(illumination * 100).round()}%';

  static const _rad = math.pi / 180;

  /// Apparent geocentric elongation at a Julian Day in Universal Time.
  static double _elongation(double julianDay) {
    final year = 2000 + (julianDay - 2451545) / 365.25;
    final t = (julianDay + _deltaT(year) / 86400 - 2451545) / 36525;
    return (_moonLongitude(t) - _sunLongitude(t)) % 360;
  }

  /// Terrestrial Time minus Universal Time, in seconds (Espenak & Meeus
  /// polynomials, 1900 onward).
  static double _deltaT(double year) {
    if (year < 1920) {
      final u = year - 1900;
      return -2.79 +
          1.494119 * u -
          0.0598939 * u * u +
          0.0061966 * u * u * u -
          0.000197 * u * u * u * u;
    }
    if (year < 1941) {
      final u = year - 1920;
      return 21.20 + 0.84493 * u - 0.076100 * u * u + 0.0020936 * u * u * u;
    }
    if (year < 1961) {
      final u = year - 1950;
      return 29.07 + 0.407 * u - u * u / 233 + u * u * u / 2547;
    }
    if (year < 1986) {
      final u = year - 1975;
      return 45.45 + 1.067 * u - u * u / 260 - u * u * u / 718;
    }
    if (year < 2005) {
      final u = year - 2000;
      return 63.86 +
          0.3345 * u -
          0.060374 * u * u +
          0.0017275 * u * u * u +
          0.000651814 * u * u * u * u +
          0.00002373599 * u * u * u * u * u;
    }
    if (year < 2050) {
      final u = year - 2000;
      return 62.92 + 0.32217 * u + 0.005589 * u * u;
    }
    final u = (year - 1820) / 100;
    return -20 + 32 * u * u - 0.5628 * (2150 - year);
  }

  /// Sun's apparent longitude less nutation (Meeus ch. 25). Nutation is
  /// left out of both bodies because it cancels in their difference.
  static double _sunLongitude(double t) {
    final mean = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
    final anomaly = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) * _rad;
    final centre =
        (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(anomaly) +
        (0.019993 - 0.000101 * t) * math.sin(2 * anomaly) +
        0.000289 * math.sin(3 * anomaly);
    return mean + centre - 0.00569;
  }

  /// Moon's geocentric longitude less nutation (Meeus ch. 47).
  static double _moonLongitude(double t) {
    final mean = _meanLongitude(t);
    final (:d, :m, :mp, :f, :e) = _arguments(t);

    var sum = 0.0;
    for (final [cd, cm, cmp, cf, coefficient, _] in _longitudeTerms) {
      sum +=
          coefficient *
          _eccentricity(cm, e) *
          math.sin(cd * d + cm * m + cmp * mp + cf * f);
    }
    sum +=
        3958 * math.sin((119.75 + 131.849 * t) * _rad) +
        1962 * math.sin(mean * _rad - f) +
        318 * math.sin((53.09 + 479264.290 * t) * _rad);

    return mean + sum / 1e6;
  }

  // Meeus table 47.A, all sixty terms: multiples of D, M, M' and F,
  // then the sine coefficient for longitude in millionths of a degree
  // and the cosine coefficient for distance in metres.
  static const _longitudeTerms = [
    [0, 0, 1, 0, 6288774, -20905355],
    [2, 0, -1, 0, 1274027, -3699111],
    [2, 0, 0, 0, 658314, -2955968],
    [0, 0, 2, 0, 213618, -569925],
    [0, 1, 0, 0, -185116, 48888],
    [0, 0, 0, 2, -114332, -3149],
    [2, 0, -2, 0, 58793, 246158],
    [2, -1, -1, 0, 57066, -152138],
    [2, 0, 1, 0, 53322, -170733],
    [2, -1, 0, 0, 45758, -204586],
    [0, 1, -1, 0, -40923, -129620],
    [1, 0, 0, 0, -34720, 108743],
    [0, 1, 1, 0, -30383, 104755],
    [2, 0, 0, -2, 15327, 10321],
    [0, 0, 1, 2, -12528, 0],
    [0, 0, 1, -2, 10980, 79661],
    [4, 0, -1, 0, 10675, -34782],
    [0, 0, 3, 0, 10034, -23210],
    [4, 0, -2, 0, 8548, -21636],
    [2, 1, -1, 0, -7888, 24208],
    [2, 1, 0, 0, -6766, 30824],
    [1, 0, -1, 0, -5163, -8379],
    [1, 1, 0, 0, 4987, -16675],
    [2, -1, 1, 0, 4036, -12831],
    [2, 0, 2, 0, 3994, -10445],
    [4, 0, 0, 0, 3861, -11650],
    [2, 0, -3, 0, 3665, 14403],
    [0, 1, -2, 0, -2689, -7003],
    [2, 0, -1, 2, -2602, 0],
    [2, -1, -2, 0, 2390, 10056],
    [1, 0, 1, 0, -2348, 6322],
    [2, -2, 0, 0, 2236, -9884],
    [0, 1, 2, 0, -2120, 5751],
    [0, 2, 0, 0, -2069, 0],
    [2, -2, -1, 0, 2048, -4950],
    [2, 0, 1, -2, -1773, 4130],
    [2, 0, 0, 2, -1595, 0],
    [4, -1, -1, 0, 1215, -3958],
    [0, 0, 2, 2, -1110, 0],
    [3, 0, -1, 0, -892, 3258],
    [2, 1, 1, 0, -810, 2616],
    [4, -1, -2, 0, 759, -1897],
    [0, 2, -1, 0, -713, -2117],
    [2, 2, -1, 0, -700, 2354],
    [2, 1, -2, 0, 691, 0],
    [2, -1, 0, -2, 596, 0],
    [4, 0, 1, 0, 549, -1423],
    [0, 0, 4, 0, 537, -1117],
    [4, -1, 0, 0, 520, -1571],
    [1, 0, -2, 0, -487, -1739],
    [2, 1, 0, -2, -399, 0],
    [0, 0, 2, -2, -381, -4421],
    [1, 1, 1, 0, 351, 0],
    [3, 0, -2, 0, -340, 0],
    [4, 0, -3, 0, 330, 0],
    [2, -1, 2, 0, 327, 0],
    [0, 2, 1, 0, -323, 1165],
    [1, 1, -1, 0, 299, 0],
    [2, 0, 3, 0, 294, 0],
    [2, 0, -1, -2, 0, 8752],
  ];

  // Meeus table 47.B, all sixty terms: multiples of D, M, M' and F, and
  // the sine coefficient for latitude in millionths of a degree.
  static const _latitudeTerms = [
    [0, 0, 0, 1, 5128122],
    [0, 0, 1, 1, 280602],
    [0, 0, 1, -1, 277693],
    [2, 0, 0, -1, 173237],
    [2, 0, -1, 1, 55413],
    [2, 0, -1, -1, 46271],
    [2, 0, 0, 1, 32573],
    [0, 0, 2, 1, 17198],
    [2, 0, 1, -1, 9266],
    [0, 0, 2, -1, 8822],
    [2, -1, 0, -1, 8216],
    [2, 0, -2, -1, 4324],
    [2, 0, 1, 1, 4200],
    [2, 1, 0, -1, -3359],
    [2, -1, -1, 1, 2463],
    [2, -1, 0, 1, 2211],
    [2, -1, -1, -1, 2065],
    [0, 1, -1, -1, -1870],
    [4, 0, -1, -1, 1828],
    [0, 1, 0, 1, -1794],
    [0, 0, 0, 3, -1749],
    [0, 1, -1, 1, -1565],
    [1, 0, 0, 1, -1491],
    [0, 1, 1, 1, -1475],
    [0, 1, 1, -1, -1410],
    [0, 1, 0, -1, -1344],
    [1, 0, 0, -1, -1335],
    [0, 0, 3, 1, 1107],
    [4, 0, 0, -1, 1021],
    [4, 0, -1, 1, 833],
    [0, 0, 1, -3, 777],
    [4, 0, -2, 1, 671],
    [2, 0, 0, -3, 607],
    [2, 0, 2, -1, 596],
    [2, -1, 1, -1, 491],
    [2, 0, -2, 1, -451],
    [0, 0, 3, -1, 439],
    [2, 0, 2, 1, 422],
    [2, 0, -3, -1, 421],
    [2, 1, -1, 1, -366],
    [2, 1, 0, 1, -351],
    [4, 0, 0, 1, 331],
    [2, -1, 1, 1, 315],
    [2, -2, 0, -1, 302],
    [0, 0, 1, 3, -283],
    [2, 1, 1, -1, -229],
    [1, 1, 0, -1, 223],
    [1, 1, 0, 1, 223],
    [0, 1, -2, -1, -220],
    [2, 1, -1, -1, -220],
    [1, 0, 1, 1, -185],
    [2, -1, -2, -1, 181],
    [0, 1, 2, 1, -177],
    [4, 0, -2, -1, 176],
    [4, -1, -1, -1, 166],
    [1, 0, 1, -1, -164],
    [4, 0, 1, -1, 132],
    [1, 0, -1, -1, -119],
    [4, -1, 0, -1, 115],
    [2, -2, 0, 1, 107],
  ];
}
