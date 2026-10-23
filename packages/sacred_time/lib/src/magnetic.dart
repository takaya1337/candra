import 'dart:math' as math;

import 'wmm2025.g.dart';

/// The Earth's magnetic field at a place and time, by the World Magnetic
/// Model 2025 (NOAA NCEI and the British Geological Survey; valid 2025 to
/// 2030; public domain): a compass needle points [declination] degrees
/// east of true north (west if negative). Worked as the model's
/// technical report sets out (Chulliat and others, 2025): geodetic to
/// geocentric, Schmidt semi-normalised Legendre functions to degree 12,
/// the field rotated back to the place's own north. Checked in the tests
/// against all of NOAA's published test values.
class MagneticField {
  /// North, east and down components, in nanotesla.
  final double north;
  final double east;
  final double down;

  const MagneticField(this.north, this.east, this.down);

  /// Degrees east of true north a compass points.
  double get declination => math.atan2(east, north) * 180 / math.pi;

  /// Degrees below the horizon the field dips.
  double get inclination =>
      math.atan2(down, math.sqrt(north * north + east * east)) * 180 / math.pi;

  static const _a = 6378.137;
  static const _f = 1 / 298.257223563;
  static const _reference = 6371.2;
  static const _degree = 12;

  /// The field at geodetic [latitude], [longitude] (degrees), [height] km
  /// above the ellipsoid, at decimal [year].
  static MagneticField at(
    double latitude,
    double longitude, {
    double height = 0,
    required double year,
  }) {
    const rad = math.pi / 180;
    final e2 = _f * (2 - _f);
    final phi = latitude * rad;
    final lambda = longitude * rad;
    final rc = _a / math.sqrt(1 - e2 * math.sin(phi) * math.sin(phi));
    final p = (rc + height) * math.cos(phi);
    final z = (rc * (1 - e2) + height) * math.sin(phi);
    final r = math.sqrt(p * p + z * z);
    final phiC = math.asin(z / r);

    // The coefficients at the year.
    final dt = year - wmmEpoch;
    final g = List.generate(_degree + 1, (_) => List.filled(_degree + 1, 0.0));
    final h = List.generate(_degree + 1, (_) => List.filled(_degree + 1, 0.0));
    for (final (n, m, gnm, hnm, dg, dh) in wmmCoefficients) {
      g[n][m] = gnm + dt * dg;
      h[n][m] = hnm + dt * dh;
    }

    // Schmidt semi-normalised associated Legendre functions of
    // sin(geocentric latitude), and their derivatives in latitude.
    final mu = math.sin(phiC);
    final nu = math.cos(phiC);
    final pnm = List.generate(
      _degree + 2,
      (_) => List.filled(_degree + 2, 0.0),
    );
    final dpnm = List.generate(
      _degree + 2,
      (_) => List.filled(_degree + 2, 0.0),
    );
    pnm[0][0] = 1;
    for (var n = 1; n <= _degree; n++) {
      for (var m = 0; m <= n; m++) {
        if (n == m) {
          // Gauss-normalised diagonal, scaled below.
          pnm[n][m] = nu * pnm[n - 1][m - 1];
          dpnm[n][m] = nu * dpnm[n - 1][m - 1] - mu * pnm[n - 1][m - 1];
        } else if (n == 1) {
          pnm[n][m] = mu * pnm[n - 1][m];
          dpnm[n][m] = mu * dpnm[n - 1][m] + nu * pnm[n - 1][m];
        } else {
          final k = ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3));
          final two = m > n - 2 ? 0.0 : pnm[n - 2][m];
          final dTwo = m > n - 2 ? 0.0 : dpnm[n - 2][m];
          pnm[n][m] = mu * pnm[n - 1][m] - k * two;
          dpnm[n][m] = mu * dpnm[n - 1][m] + nu * pnm[n - 1][m] - k * dTwo;
        }
      }
    }
    // From Gauss to Schmidt normalisation.
    final s = List.generate(_degree + 1, (_) => List.filled(_degree + 1, 0.0));
    s[0][0] = 1;
    for (var n = 1; n <= _degree; n++) {
      s[n][0] = s[n - 1][0] * (2 * n - 1) / n;
      for (var m = 1; m <= n; m++) {
        s[n][m] =
            s[n][m - 1] * math.sqrt((n - m + 1) * (m == 1 ? 2 : 1) / (n + m));
      }
    }

    var xc = 0.0, yc = 0.0, zc = 0.0;
    for (var n = 1; n <= _degree; n++) {
      final ratio = math.pow(_reference / r, n + 2).toDouble();
      for (var m = 0; m <= n; m++) {
        final cosM = math.cos(m * lambda), sinM = math.sin(m * lambda);
        final pn = s[n][m] * pnm[n][m];
        final dpn = s[n][m] * dpnm[n][m];
        final a = g[n][m] * cosM + h[n][m] * sinM;
        xc -= ratio * a * dpn;
        yc += ratio * m * (g[n][m] * sinM - h[n][m] * cosM) * pn;
        zc -= ratio * (n + 1) * a * pn;
      }
    }
    // The derivatives above are in latitude, as the report's equations
    // have them; Y' divides by the cosine of the geocentric latitude.
    yc = yc / nu;

    // Back from geocentric to the place's own north and down.
    final psi = phiC - phi;
    return MagneticField(
      xc * math.cos(psi) - zc * math.sin(psi),
      yc,
      xc * math.sin(psi) + zc * math.cos(psi),
    );
  }

  /// [instant] as a decimal year, as the model counts time.
  static double yearOf(DateTime instant) {
    final t = instant.toUtc();
    final start = DateTime.utc(t.year);
    final end = DateTime.utc(t.year + 1);
    return t.year +
        t.difference(start).inSeconds / end.difference(start).inSeconds;
  }
}
