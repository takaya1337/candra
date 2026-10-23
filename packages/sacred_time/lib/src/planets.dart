import 'dart:math' as math;

import 'moon.dart';
import 'sky_position.dart';
import 'sun.dart';
import 'vsop87d.g.dart';

/// A planet as the Earth sees it at one instant: where it stands among
/// the stars, how far, how lit, how bright.
class PlanetView {
  final Body body;

  /// Apparent geocentric ecliptic longitude and latitude of date, in
  /// degrees.
  final double eclipticLongitude;
  final double eclipticLatitude;

  /// From the Earth's centre, and from the sun, in astronomical units.
  final double distance;
  final double sunDistance;

  /// The angle at the Earth between the sun and the planet, and at the
  /// planet between the sun and the Earth, in degrees.
  final double elongation;
  final double phaseAngle;

  /// East of the sun (seen in the evening) or west (in the morning).
  final bool east;

  /// The lit part of the disc, 0 to 1.
  double get illumination => (1 + math.cos(phaseAngle * math.pi / 180)) / 2;

  /// The apparent visual magnitude (Mallama and Hilton 2018); smaller is
  /// brighter.
  final double magnitude;

  /// The apparent diameter, in seconds of arc.
  final double diameter;

  const PlanetView({
    required this.body,
    required this.eclipticLongitude,
    required this.eclipticLatitude,
    required this.distance,
    required this.sunDistance,
    required this.elongation,
    required this.phaseAngle,
    required this.east,
    required this.magnitude,
    required this.diameter,
  });
}

/// The planets from VSOP87D (Bretagnon and Francou 1988), the series
/// truncated as `vsop87d.g.dart` says, carried to the Earth as Meeus
/// sets it out (Astronomical Algorithms, 2nd ed., ch. 32 and 33): the
/// light-time, the FK5 frame, the annual aberration and the nutation.
/// Checked in the tests against JPL Horizons.
abstract final class Planets {
  static const _rad = math.pi / 180;
  static const _au = SkyNow.astronomicalUnit;

  /// The seven, nearest the sun first.
  static const all = [
    Body.mercury,
    Body.venus,
    Body.mars,
    Body.jupiter,
    Body.saturn,
    Body.uranus,
    Body.neptune,
  ];

  /// Whether [body] is a planet.
  static bool isPlanet(Body body) => body != Body.sun && body != Body.moon;

  /// Equatorial radius in km (IAU 2015), for the apparent diameter.
  static const _radius = {
    Body.mercury: 2440.53,
    Body.venus: 6051.8,
    Body.mars: 3396.19,
    Body.jupiter: 71492.0,
    Body.saturn: 60268.0,
    Body.uranus: 25559.0,
    Body.neptune: 24764.0,
  };

  // The series' name of each.
  static String _name(Body body) => body == Body.sun ? 'earth' : body.name;

  /// Heliocentric longitude and latitude (radians, ecliptic and equinox
  /// of date) and distance (AU) of [body] (the sun meaning the Earth) at
  /// the Julian Ephemeris Day [jde].
  static ({double l, double b, double r}) heliocentric(Body body, double jde) {
    final tau = (jde - 2451545) / 365250;
    final series = vsop87d[_name(body)]!;
    double sum(List<List<double>> powers) {
      var total = 0.0;
      var tk = 1.0;
      for (final terms in powers) {
        var part = 0.0;
        for (var i = 0; i + 2 < terms.length; i += 3) {
          part += terms[i] * math.cos(terms[i + 1] + terms[i + 2] * tau);
        }
        total += part * tk;
        tk *= tau;
      }
      return total;
    }

    return (
      l: sum(series[0]) % (2 * math.pi),
      b: sum(series[1]),
      r: sum(series[2]),
    );
  }

  static double _ephemerisDay(double jd) =>
      jd + Moon.deltaTSeconds(2000 + (jd - 2451545) / 365.25) / 86400;

  /// [body] seen from the Earth's centre at the Julian Day [jd] (UT).
  static PlanetView view(Body body, double jd) {
    assert(isPlanet(body));
    final jde = _ephemerisDay(jd);
    final earth = heliocentric(Body.sun, jde);
    final ex = earth.r * math.cos(earth.b) * math.cos(earth.l);
    final ey = earth.r * math.cos(earth.b) * math.sin(earth.l);
    final ez = earth.r * math.sin(earth.b);

    // The light-time: the planet where it was when the light left it.
    var tau = 0.0;
    late ({double l, double b, double r}) p;
    late double x, y, z, delta;
    for (var k = 0; k < 3; k++) {
      p = heliocentric(body, jde - tau);
      x = p.r * math.cos(p.b) * math.cos(p.l) - ex;
      y = p.r * math.cos(p.b) * math.sin(p.l) - ey;
      z = p.r * math.sin(p.b) - ez;
      delta = math.sqrt(x * x + y * y + z * z);
      tau = 0.0057755183 * delta;
    }
    var lambda = math.atan2(y, x);
    var beta = math.atan2(z, math.sqrt(x * x + y * y));

    final t = (jde - 2451545) / 36525;
    // To the FK5 frame (Meeus 32.3).
    final l1 = lambda - (1.397 * t + 0.00031 * t * t) * _rad;
    lambda +=
        (-0.09033 + 0.03916 * (math.cos(l1) + math.sin(l1)) * math.tan(beta)) /
        3600 *
        _rad;
    beta += 0.03916 * (math.cos(l1) - math.sin(l1)) / 3600 * _rad;

    // The annual aberration (Meeus 23.2), the sun's true longitude the
    // Earth's turned about.
    const kappa = 20.49552 / 3600 * _rad;
    final sunLongitude = earth.l + math.pi;
    final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
    final pi = (102.93735 + 1.71946 * t + 0.00046 * t * t) * _rad;
    final dLambda =
        (-kappa * math.cos(sunLongitude - lambda) +
            e * kappa * math.cos(pi - lambda)) /
        math.cos(beta);
    final dBeta =
        -kappa *
        math.sin(beta) *
        (math.sin(sunLongitude - lambda) - e * math.sin(pi - lambda));
    lambda += dLambda;
    beta += dBeta;

    // The nutation in longitude.
    lambda += Sun.nutationAt(jd).longitude / 3600 * _rad;

    // The angles at the Earth and at the planet.
    final r = p.r, rE = earth.r;
    final elongation = math.acos(
      ((rE * rE + delta * delta - r * r) / (2 * rE * delta)).clamp(-1.0, 1.0),
    );
    final phase = math.acos(
      ((r * r + delta * delta - rE * rE) / (2 * r * delta)).clamp(-1.0, 1.0),
    );
    final east = ((lambda - sunLongitude) / _rad + 360) % 360 < 180;
    final alpha = phase / _rad;
    return PlanetView(
      body: body,
      eclipticLongitude: (lambda / _rad) % 360,
      eclipticLatitude: beta / _rad,
      distance: delta,
      sunDistance: r,
      elongation: elongation / _rad,
      phaseAngle: alpha,
      east: east,
      magnitude: _magnitude(
        body,
        r,
        delta,
        alpha,
        jde,
        lambda / _rad,
        beta / _rad,
        p.l / _rad,
        p.b / _rad,
      ),
      diameter: 2 * math.atan(_radius[body]! / (delta * _au)) / _rad * 3600,
    );
  }

  // How far from Uranus's equator, in degrees, a body lies that is seen
  // from Uranus at ecliptic [lon], [lat] (degrees, of date) turned
  // round: the latitude on Uranus of whatever looks at it from there.
  static double _poleLatitude(double lon, double lat, double jde) {
    // The pole, J2000 equatorial, to ecliptic J2000.
    const ra = 257.311 * _rad, dec = -15.175 * _rad;
    const tilt = 23.4392911 * _rad;
    final px = math.cos(dec) * math.cos(ra);
    final py =
        math.cos(dec) * math.sin(ra) * math.cos(tilt) +
        math.sin(dec) * math.sin(tilt);
    final pz =
        -math.cos(dec) * math.sin(ra) * math.sin(tilt) +
        math.sin(dec) * math.cos(tilt);
    // The direction from Uranus to the observer, back to J2000 by the
    // precession in longitude (a second of arc's worth over a century
    // in latitude is ignored).
    final t = (jde - 2451545) / 36525;
    final l0 = (lon + 180 - 1.396971 * t) * _rad;
    final b0 = -lat * _rad;
    final dx = math.cos(b0) * math.cos(l0);
    final dy = math.cos(b0) * math.sin(l0);
    final dz = math.sin(b0);
    return math.asin((px * dx + py * dy + pz * dz).clamp(-1.0, 1.0)) / _rad;
  }

  /// The apparent visual magnitude by Mallama and Hilton, "Computing
  /// apparent planetary magnitudes for The Astronomical Almanac",
  /// Astronomy and Computing 25 (2018), 10–24, their equations 2 to 17,
  /// each where it holds. Left out: Mars's corrections for the markings
  /// turned toward us and its season (a table, up to about 0.1 mag).
  static double _magnitude(
    Body body,
    double r,
    double delta,
    double a,
    double jde,
    double lambda,
    double beta,
    double l,
    double b,
  ) {
    final base = 5 * math.log(r * delta) / math.ln10;
    switch (body) {
      case Body.mercury:
        return base -
            0.613 +
            6.3280e-02 * a -
            1.6336e-03 * a * a +
            3.3644e-05 * math.pow(a, 3) -
            3.4265e-07 * math.pow(a, 4) +
            1.6893e-09 * math.pow(a, 5) -
            3.0334e-12 * math.pow(a, 6);
      case Body.venus:
        return a <= 163.7
            ? base -
                  4.384 -
                  1.044e-03 * a +
                  3.687e-04 * a * a -
                  2.814e-06 * math.pow(a, 3) +
                  8.938e-09 * math.pow(a, 4)
            : base + 236.05828 - 2.81914 * a + 8.39034e-03 * a * a;
      case Body.mars:
        return a <= 50
            ? base - 1.601 + 0.02267 * a - 0.0001302 * a * a
            : base - 0.367 - 0.02573 * a + 0.0003445 * a * a;
      case Body.jupiter:
        if (a <= 12) return base - 9.395 - 3.7e-04 * a + 6.16e-04 * a * a;
        final x = a / 180;
        return base -
            9.428 -
            2.5 *
                math.log(
                  1 -
                      1.507 * x -
                      0.363 * x * x -
                      0.062 * math.pow(x, 3) +
                      2.809 * math.pow(x, 4) -
                      1.876 * math.pow(x, 5),
                ) /
                math.ln10;
      case Body.saturn:
        // The rings' tilt to the Earth and to the sun (Meeus 45.3):
        // their plane at inclination i and node Ω on the ecliptic of
        // date.
        final t = (jde - 2451545) / 36525;
        final i = (28.075216 - 0.012998 * t + 0.000004 * t * t) * _rad;
        final node = (169.508470 + 1.394681 * t + 0.000412 * t * t) * _rad;
        double tilt(double lon, double lat) => math.asin(
          math.sin(i) * math.cos(lat * _rad) * math.sin(lon * _rad - node) -
              math.cos(i) * math.sin(lat * _rad),
        );
        final fromEarth = tilt(lambda, beta);
        final fromSun = tilt(l, b);
        final open = fromEarth * fromSun > 0
            ? math.sqrt(fromEarth * fromSun)
            : 0.0;
        if (a <= 6.5 && open.abs() < 27 * _rad) {
          final s = math.sin(open);
          return base -
              8.914 -
              1.825 * s +
              0.026 * a -
              0.378 * s * math.exp(-2.25 * a);
        }
        return a <= 6
            ? base - 8.95 - 3.7e-04 * a + 6.16e-04 * a * a
            : base -
                  8.94 +
                  2.446e-4 * a +
                  2.672e-4 * a * a -
                  1.505e-6 * math.pow(a, 3) +
                  4.767e-9 * math.pow(a, 4);
      case Body.uranus:
        // φ′, the mean of the planetographic latitudes (taken here as
        // planetocentric) of the Earth and the sun on Uranus, from the
        // IAU's pole of the planet (right ascension 257.311°,
        // declination −15.175°), its equator turned to the ecliptic.
        final latitude =
            (_poleLatitude(lambda, beta, jde).abs() +
                _poleLatitude(l, b, jde).abs()) /
            2;
        return base -
            7.110 -
            8.4e-04 * latitude +
            6.587e-3 * a +
            1.045e-4 * a * a;
      case Body.neptune:
        // Neptune brightened from 1980 to 2000 (their equation 16).
        final year = 2000 + (jde - 2451545) / 365.25;
        final v0 = year > 2000
            ? -7.00
            : year < 1980
            ? -6.89
            : -6.89 - 0.0054 * (year - 1980);
        return base + v0 + 7.944e-3 * a + 9.617e-5 * a * a;
      case Body.sun:
      case Body.moon:
        throw ArgumentError(body);
    }
  }
}
