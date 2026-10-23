import 'dart:math' as math;

import 'moon.dart';

/// The sun's place along the ecliptic, to about a second of arc: the one
/// piece of astronomy the solar terms, and so the pillars of a bazi chart,
/// rest on. A second of arc is some twenty-five seconds of time, so a
/// crossing found from it is good to the minute.
///
/// Worked from the Earth's heliocentric longitude and distance by the
/// VSOP87 theory, in the shortened form Meeus gives (Astronomical
/// Algorithms, 2nd ed., ch. 25 and appendix III), corrected to the FK5
/// frame, for nutation and for aberration. No tables of dates anywhere.
abstract final class Sun {
  static const _rad = math.pi / 180;

  /// The sun's apparent geocentric longitude in degrees, 0..360, at a
  /// Julian Day in Universal Time: 0 at the March equinox.
  static double apparentLongitudeAt(double julianDay) {
    final jde = _ephemerisDay(julianDay);
    final tau = (jde - 2451545) / 365250;
    final t = tau * 10;

    final earth = _series(_l, tau) / _rad;
    // Geocentric, in the FK5 frame.
    var longitude = earth + 180 - 0.09033 / 3600;
    longitude += _nutation(t) / 3600;
    // Aberration: the light left the sun some eight minutes ago.
    longitude -= 20.4898 / 3600 / _series(_r, tau);
    return longitude % 360;
  }

  /// The equation of time in minutes at a Julian Day in Universal Time:
  /// how far a sundial is ahead of a clock keeping the mean time of the
  /// same meridian. About -14 in mid-February and +16 in early November.
  static double equationOfTimeAt(double julianDay) {
    final jde = _ephemerisDay(julianDay);
    final tau = (jde - 2451545) / 365250;
    final t = tau * 10;
    final mean =
        280.4664567 +
        360007.6982779 * tau +
        0.03032028 * tau * tau +
        tau * tau * tau / 49931;
    final nutation = _nutation(t) / 3600;
    final tilt =
        (23.4392911 -
            0.0130042 * t +
            9.2 / 3600 * math.cos((125.04452 - 1934.136261 * t) * _rad)) *
        _rad;
    final longitude = apparentLongitudeAt(julianDay) * _rad;
    final rightAscension =
        math.atan2(math.cos(tilt) * math.sin(longitude), math.cos(longitude)) /
        _rad;
    final degrees =
        (mean - 0.0057183 - rightAscension + nutation * math.cos(tilt) + 540) %
            360 -
        180;
    return degrees * 4;
  }

  /// The first instant at or after [after] that the sun's apparent
  /// longitude is [longitude] degrees. In Universal Time, to the second.
  static DateTime nextCrossing(DateTime after, double longitude) {
    final start = _julianDay(after);
    if (_onIt(start, longitude)) return _dateTime(_refine(start, longitude));
    final ahead = (longitude - apparentLongitudeAt(start)) % 360;
    var found = _refine(start + ahead / _rate, longitude);
    // Seeded just past a crossing it may settle on the one behind.
    if (found < start - _same) {
      found = _refine(found + 360 / _rate, longitude);
    }
    return _dateTime(found);
  }

  /// The last instant at or before [before] that the sun's apparent
  /// longitude was [longitude] degrees.
  static DateTime previousCrossing(DateTime before, double longitude) {
    final end = _julianDay(before);
    if (_onIt(end, longitude)) return _dateTime(_refine(end, longitude));
    final behind = (apparentLongitudeAt(end) - longitude) % 360;
    var found = _refine(end - behind / _rate, longitude);
    if (found > end + _same) {
      found = _refine(found - 360 / _rate, longitude);
    }
    return _dateTime(found);
  }

  /// The distance between the Earth and the sun in astronomical units,
  /// at a Julian Day in Universal Time: within three hundred kilometres
  /// of the JPL ephemeris.
  static double distanceAt(double julianDay) =>
      _series(_r, (_ephemerisDay(julianDay) - 2451545) / 365250);

  /// Nutation in longitude and in obliquity, in seconds of arc, at a
  /// Julian Day in Universal Time: the nod of the Earth's axis, which
  /// moves where every star and planet appears to stand. The four largest
  /// terms of each (Meeus ch. 22), good to half a second.
  static ({double longitude, double obliquity}) nutationAt(double julianDay) {
    final t = (_ephemerisDay(julianDay) - 2451545) / 36525;
    final node = (125.04452 - 1934.136261 * t) * _rad;
    final sun = (280.4665 + 36000.7698 * t) * _rad;
    final moon = (218.3165 + 481267.8813 * t) * _rad;
    return (
      longitude: _nutation(t),
      obliquity:
          9.20 * math.cos(node) +
          0.57 * math.cos(2 * sun) +
          0.10 * math.cos(2 * moon) -
          0.09 * math.cos(2 * node),
    );
  }

  /// The Julian Day, in Universal Time, of an instant.
  static double julianDayOf(DateTime instant) => _julianDay(instant);

  // A crossing is given to the whole second; an instant within a second
  // of one is that crossing.
  static const _same = 1.0 / 86400;

  // Whether the sun is within a second of crossing [longitude].
  static bool _onIt(double julianDay, double longitude) =>
      ((apparentLongitudeAt(julianDay) - longitude + 540) % 360 - 180).abs() <
      _rate * _same;

  // Degrees a day, on average.
  static const _rate = 360 / 365.2422;

  // Newton's method: the sun's speed is all but steady, so a few steps
  // bring it to well under a second.
  static double _refine(double julianDay, double longitude) {
    var day = julianDay;
    for (var i = 0; i < 8; i++) {
      final off = (apparentLongitudeAt(day) - longitude + 540) % 360 - 180;
      day -= off / _rate;
      if (off.abs() < 1e-7) break;
    }
    return day;
  }

  static double _julianDay(DateTime instant) =>
      2440587.5 + instant.toUtc().microsecondsSinceEpoch / 86400e6;

  static DateTime _dateTime(double julianDay) =>
      DateTime.fromMillisecondsSinceEpoch(
        ((julianDay - 2440587.5) * 86400).round() * 1000,
        isUtc: true,
      );

  // Universal Time to the uniform time the theory runs on.
  static double _ephemerisDay(double julianDay) =>
      julianDay +
      Moon.deltaTSeconds(2000 + (julianDay - 2451545) / 365.25) / 86400;

  // Nutation in longitude, in seconds of arc: its four largest terms.
  static double _nutation(double t) {
    final node = (125.04452 - 1934.136261 * t) * _rad;
    final sun = (280.4665 + 36000.7698 * t) * _rad;
    final moon = (218.3165 + 481267.8813 * t) * _rad;
    return -17.20 * math.sin(node) -
        1.32 * math.sin(2 * sun) -
        0.23 * math.sin(2 * moon) +
        0.21 * math.sin(2 * node);
  }

  // Sums a VSOP87 series: each power of tau has terms A cos(B + C tau).
  static double _series(List<List<List<double>>> powers, double tau) {
    var sum = 0.0;
    var power = 1.0;
    for (final terms in powers) {
      var part = 0.0;
      for (final [a, b, c] in terms) {
        part += a * math.cos(b + c * tau);
      }
      sum += part * power;
      power *= tau;
    }
    return sum / 1e8;
  }

  // The Earth's heliocentric longitude, in units of 1e-8 radian.
  static const _l = <List<List<double>>>[
    [
      [175347046, 0, 0],
      [3341656, 4.6692568, 6283.0758500],
      [34894, 4.62610, 12566.15170],
      [3497, 2.7441, 5753.3849],
      [3418, 2.8289, 3.5231],
      [3136, 3.6277, 77713.7715],
      [2676, 4.4181, 7860.4194],
      [2343, 6.1352, 3930.2097],
      [1324, 0.7425, 11506.7698],
      [1273, 2.0371, 529.6910],
      [1199, 1.1096, 1577.3435],
      [990, 5.233, 5884.927],
      [902, 2.045, 26.298],
      [857, 3.508, 398.149],
      [780, 1.179, 5223.694],
      [753, 2.533, 5507.553],
      [505, 4.583, 18849.228],
      [492, 4.205, 775.523],
      [357, 2.920, 0.067],
      [317, 5.849, 11790.629],
      [284, 1.899, 796.298],
      [271, 0.315, 10977.079],
      [243, 0.345, 5486.778],
      [206, 4.806, 2544.314],
      [205, 1.869, 5573.143],
      [202, 2.458, 6069.777],
      [156, 0.833, 213.299],
      [132, 3.411, 2942.463],
      [126, 1.083, 20.775],
      [115, 0.645, 0.980],
      [103, 0.636, 4694.003],
      [102, 0.976, 15720.839],
      [102, 4.267, 7.114],
      [99, 6.21, 2146.17],
      [98, 0.68, 155.42],
      [86, 5.98, 161000.69],
      [85, 1.30, 6275.96],
      [85, 3.67, 71430.70],
      [80, 1.81, 17260.15],
      [79, 3.04, 12036.46],
      [75, 1.76, 5088.63],
      [74, 3.50, 3154.69],
      [74, 4.68, 801.82],
      [70, 0.83, 9437.76],
      [62, 3.98, 8827.39],
      [61, 1.82, 7084.90],
      [57, 2.78, 6286.60],
      [56, 4.39, 14143.50],
      [56, 3.47, 6279.55],
      [52, 0.19, 12139.55],
      [52, 1.33, 1748.02],
      [51, 0.28, 5856.48],
      [49, 0.49, 1194.45],
      [41, 5.37, 8429.24],
      [41, 2.40, 19651.05],
      [39, 6.17, 10447.39],
      [37, 6.04, 10213.29],
      [37, 2.57, 1059.38],
      [36, 1.71, 2352.87],
      [36, 1.78, 6812.77],
      [33, 0.59, 17789.85],
      [30, 0.44, 83996.85],
      [30, 2.74, 1349.87],
      [25, 3.16, 4690.48],
    ],
    [
      [628331966747, 0, 0],
      [206059, 2.678235, 6283.075850],
      [4303, 2.6351, 12566.1517],
      [425, 1.590, 3.523],
      [119, 5.796, 26.298],
      [109, 2.966, 1577.344],
      [93, 2.59, 18849.23],
      [72, 1.14, 529.69],
      [68, 1.87, 398.15],
      [67, 4.41, 5507.55],
      [59, 2.89, 5223.69],
      [56, 2.17, 155.42],
      [45, 0.40, 796.30],
      [36, 0.47, 775.52],
      [29, 2.65, 7.11],
      [21, 5.34, 0.98],
      [19, 1.85, 5486.78],
      [19, 4.97, 213.30],
      [17, 2.99, 6275.96],
      [16, 0.03, 2544.31],
      [16, 1.43, 2146.17],
      [15, 1.21, 10977.08],
      [12, 2.83, 1748.02],
      [12, 3.26, 5088.63],
      [12, 5.27, 1194.45],
      [12, 2.08, 4694.00],
      [11, 0.77, 553.57],
      [10, 1.30, 6286.60],
      [10, 4.24, 1349.87],
      [9, 2.70, 242.73],
      [9, 5.64, 951.72],
      [8, 5.30, 2352.87],
      [6, 2.65, 9437.76],
      [6, 4.67, 4690.48],
    ],
    [
      [52919, 0, 0],
      [8720, 1.0721, 6283.0758],
      [309, 0.867, 12566.152],
      [27, 0.05, 3.52],
      [16, 5.19, 26.30],
      [16, 3.68, 155.42],
      [10, 0.76, 18849.23],
      [9, 2.06, 77713.77],
      [7, 0.83, 775.52],
      [5, 4.66, 1577.34],
      [4, 1.03, 7.11],
      [4, 3.44, 5573.14],
      [3, 5.14, 796.30],
      [3, 6.05, 5507.55],
      [3, 1.19, 242.73],
      [3, 6.12, 529.69],
      [3, 0.31, 398.15],
      [3, 2.28, 553.57],
      [2, 4.38, 5223.69],
      [2, 3.75, 0.98],
    ],
    [
      [289, 5.844, 6283.076],
      [35, 0, 0],
      [17, 5.49, 12566.15],
      [3, 5.20, 155.42],
      [1, 4.72, 3.52],
      [1, 5.30, 18849.23],
      [1, 5.97, 242.73],
    ],
    [
      [114, 3.142, 0],
      [8, 4.13, 6283.08],
      [1, 3.84, 12566.15],
    ],
    [
      [1, 3.14, 0],
    ],
  ];

  // The Earth's distance from the sun in units of 1e-8 of the mean
  // distance: the whole of Meeus appendix III, R0 to R4.
  static const _r = <List<List<double>>>[
    [
      [100013989, 0, 0],
      [1670700, 3.0984635, 6283.0758500],
      [13956, 3.05525, 12566.15170],
      [3084, 5.1985, 77713.7715],
      [1628, 1.1739, 5753.3849],
      [1576, 2.8469, 7860.4194],
      [925, 5.453, 11506.770],
      [542, 4.564, 3930.210],
      [472, 3.661, 5884.927],
      [346, 0.964, 5507.553],
      [329, 5.900, 5223.694],
      [307, 0.299, 5573.143],
      [243, 4.273, 11790.629],
      [212, 5.847, 1577.344],
      [186, 5.022, 10977.079],
      [175, 3.012, 18849.228],
      [110, 5.055, 5486.778],
      [98, 0.89, 6069.78],
      [86, 5.69, 15720.84],
      [86, 1.27, 161000.69],
      [65, 0.27, 17260.15],
      [63, 0.92, 529.69],
      [57, 2.01, 83996.85],
      [56, 5.24, 71430.70],
      [49, 3.25, 2544.31],
      [47, 2.58, 775.52],
      [45, 5.54, 9437.76],
      [43, 6.01, 6275.96],
      [39, 5.36, 4694.00],
      [38, 2.39, 8827.39],
      [37, 0.83, 19651.05],
      [37, 4.90, 12139.55],
      [36, 1.67, 12036.46],
      [35, 1.84, 2942.46],
      [33, 0.24, 7084.90],
      [32, 0.18, 5088.63],
      [32, 1.78, 398.15],
      [28, 1.21, 6286.60],
      [28, 1.90, 6279.55],
      [26, 4.59, 10447.39],
    ],
    [
      [103019, 1.107490, 6283.075850],
      [1721, 1.0644, 12566.1517],
      [702, 3.142, 0],
      [32, 1.02, 18849.23],
      [31, 2.84, 5507.55],
      [25, 1.32, 5223.69],
      [18, 1.42, 1577.34],
      [10, 5.91, 10977.08],
      [9, 1.42, 6275.96],
      [9, 0.27, 5486.78],
    ],
    [
      [4359, 5.7846, 6283.0758],
      [124, 5.579, 12566.152],
      [12, 3.14, 0],
      [9, 3.63, 77713.77],
      [6, 1.87, 5573.14],
      [3, 5.47, 18849.23],
    ],
    [
      [145, 4.273, 6283.076],
      [7, 3.92, 12566.15],
    ],
    [
      [4, 2.56, 6283.08],
    ],
  ];
}
