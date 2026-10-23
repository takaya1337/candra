import 'dart:math' as math;

import 'civil_date.dart';
import 'moon.dart';
import 'planets.dart';
import 'sun.dart';

/// The sun or the moon.
/// The bodies the sky engine places: the sun, the moon, and the planets
/// the eye can see or a small telescope finds.
enum Body { sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune }

/// Where the sun or the moon stands at one instant, seen from one place.
///
/// The equatorial and ecliptic places are apparent and geocentric: as
/// the body is seen from the centre of the Earth, with nutation and
/// aberration allowed for, against the equinox of the date. The height
/// and the bearing are topocentric: from the place itself, which for the
/// moon moves it by up to a degree (its parallax).
class SkyPosition {
  final Body body;

  /// Along the celestial equator from the March equinox, in degrees,
  /// 0..360. Fifteen degrees are an hour of right ascension.
  final double rightAscension;

  /// North (positive) or south of the celestial equator, in degrees.
  final double declination;

  /// Along the ecliptic from the March equinox, in degrees, 0..360.
  final double eclipticLongitude;

  /// North or south of the ecliptic, in degrees; nothing for the sun.
  final double eclipticLatitude;

  /// From the centre of the Earth to the centre of the body, in
  /// kilometres.
  final double distance;

  /// The height of its centre above the horizon of the place, in
  /// degrees, as the eye sees it: lifted by the bending of the air,
  /// which is half a degree at the horizon.
  final double altitude;

  /// The same height with no air: the geometry alone.
  final double trueAltitude;

  /// The bearing along the horizon, in degrees from north through east:
  /// 90 is due east, 180 due south.
  final double azimuth;

  /// How far west of the meridian it has turned, in degrees, -180..180:
  /// negative before it culminates, positive after.
  final double hourAngle;

  /// Half its width as it appears, in degrees.
  final double semidiameter;

  const SkyPosition({
    required this.body,
    required this.rightAscension,
    required this.declination,
    required this.eclipticLongitude,
    required this.eclipticLatitude,
    required this.distance,
    required this.altitude,
    required this.trueAltitude,
    required this.azimuth,
    required this.hourAngle,
    required this.semidiameter,
  });

  /// The distance in astronomical units, as the sun's is told.
  double get distanceAu => distance / SkyNow.astronomicalUnit;
}

/// The moon's face at one instant.
class MoonFace {
  /// The lit part of the disc, 0 at new moon and 1 at full.
  final double illumination;

  /// Angle from the sun to the moon along the ecliptic, in degrees,
  /// 0..360: under 180 while it waxes.
  final double elongation;

  /// The angle at the moon between the sun and the Earth, in degrees:
  /// 180 at new moon, 0 at full.
  final double phaseAngle;

  const MoonFace({
    required this.illumination,
    required this.elongation,
    required this.phaseAngle,
  });

  bool get waxing => elongation < 180;
}

/// A body's day at one place: when it rises, culminates and sets, and,
/// for the sun, when the three twilights begin and end. Instants are in
/// Universal Time, to the second; null when it does not happen within
/// the civil day asked for.
class SkyDay {
  final DateTime? rise;
  final DateTime? transit;
  final DateTime? set;

  /// The height it culminates at, in degrees, as the eye sees it.
  final double? transitAltitude;

  /// The compass bearing it rises and sets at, in degrees from true north
  /// through east: where on the horizon to look, or to stand a camera.
  final double? riseAzimuth;
  final double? setAzimuth;

  /// Morning and evening, with the sun 6, 12 and 18 degrees below the
  /// horizon: civil, nautical and astronomical twilight. The sun's only.
  final DateTime? civilDawn;
  final DateTime? civilDusk;
  final DateTime? nauticalDawn;
  final DateTime? nauticalDusk;
  final DateTime? astronomicalDawn;
  final DateTime? astronomicalDusk;

  const SkyDay({
    this.rise,
    this.transit,
    this.set,
    this.transitAltitude,
    this.riseAzimuth,
    this.setAzimuth,
    this.civilDawn,
    this.civilDusk,
    this.nauticalDawn,
    this.nauticalDusk,
    this.astronomicalDawn,
    this.astronomicalDusk,
  });
}

/// Where the sun and the moon are: the sun to three seconds of arc, the
/// moon to ten.
///
/// The sun from the VSOP87 theory and the moon from the whole of the ELP
/// series as Meeus shortens them (Astronomical Algorithms, 2nd ed., ch.
/// 22, 25, 40, 47 and 48), carried to the place by the apparent sidereal
/// time and the parallax. Checked in the tests against the JPL Horizons
/// ephemeris.
abstract final class SkyNow {
  static const _rad = math.pi / 180;

  /// Kilometres in an astronomical unit (IAU 2012).
  static const astronomicalUnit = 149597870.7;

  /// The Earth's equatorial radius in kilometres (IAU 1976, as Meeus).
  static const _earthRadius = 6378.14;

  /// The sun's semidiameter at one astronomical unit, in degrees.
  static const _sunRadius = 959.63 / 3600;

  /// The moon's mean radius over the Earth's equatorial radius.
  static const _moonRadius = 0.272481;

  /// The sun at [instant] from [latitude], [longitude] (degrees, north
  /// and east positive), [height] metres above the sea.
  static SkyPosition sun(
    DateTime instant, {
    required double latitude,
    required double longitude,
    double height = 0,
  }) => _position(Body.sun, _julianDay(instant), latitude, longitude, height);

  /// The moon at [instant] from [latitude], [longitude].
  static SkyPosition moon(
    DateTime instant, {
    required double latitude,
    required double longitude,
    double height = 0,
  }) => _position(Body.moon, _julianDay(instant), latitude, longitude, height);

  /// A planet at [instant] from [latitude], [longitude]; with
  /// [Planets.view] for its distance, phase and brightness.
  static SkyPosition planet(
    Body body,
    DateTime instant, {
    required double latitude,
    required double longitude,
    double height = 0,
  }) {
    assert(Planets.isPlanet(body));
    return _position(body, _julianDay(instant), latitude, longitude, height);
  }

  /// A planet seen from the Earth's centre at [instant]: where among the
  /// stars, how far, how lit, how bright.
  static PlanetView planetView(Body body, DateTime instant) =>
      Planets.view(body, _julianDay(instant));

  /// [body] at [instant] as seen from the centre of the Earth, turned to
  /// the horizon of [latitude], [longitude]: no parallax, so the moon
  /// stands up to a degree higher than from the ground. For the
  /// crescent's criteria that reckon so (Yallop's arc of vision).
  static SkyPosition fromCentre(
    Body body,
    DateTime instant, {
    required double latitude,
    required double longitude,
  }) => _position(
    body,
    _julianDay(instant),
    latitude,
    longitude,
    0,
    geocentric: true,
  );

  /// The moon's face at [instant], as seen from the centre of the Earth.
  static MoonFace moonFace(DateTime instant) {
    final jd = _julianDay(instant);
    final sunLongitude = Sun.apparentLongitudeAt(jd) * _rad;
    final sunDistance = Sun.distanceAt(jd) * astronomicalUnit;
    final nutation = Sun.nutationAt(jd).longitude / 3600;
    final lambda = (Moon.moonLongitudeAt(jd) + nutation) * _rad;
    final beta = Moon.moonLatitudeAt(jd) * _rad;
    final distance = Moon.moonDistanceAt(jd);
    // Meeus 48.2 and 48.3.
    final psi = math.acos(math.cos(beta) * math.cos(lambda - sunLongitude));
    final phase = math.atan2(
      sunDistance * math.sin(psi),
      distance - sunDistance * math.cos(psi),
    );
    return MoonFace(
      illumination: (1 + math.cos(phase)) / 2,
      elongation: ((lambda - sunLongitude) / _rad) % 360,
      phaseAngle: phase / _rad,
    );
  }

  /// The day of [body] at a place, for the civil day [date] running
  /// midnight to midnight at [utcOffset].
  ///
  /// It rises and sets when its upper edge touches the horizon as the
  /// eye sees it: the centre half a degree and more below, for the air
  /// lifts it by 34 minutes of arc there (the almanacs' rule).
  ///
  /// [samples], if given, are its places every ten minutes from local
  /// midnight to the next, 145 of them, already worked out (for drawing
  /// its path): they are used rather than worked out again.
  static SkyDay day(
    Body body,
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    double height = 0,
    List<SkyPosition>? samples,
  }) {
    final midnight =
        date.dayNumber - 0.5 - utcOffset.inSeconds / Duration.secondsPerDay;
    SkyPosition at(double jd) =>
        _position(body, jd, latitude, longitude, height);

    // Every ten minutes, then each crossing narrowed to the second.
    const steps = 144;
    assert(samples == null || samples.length == steps + 1);
    final points =
        samples ?? [for (var i = 0; i <= steps; i++) at(midnight + i / steps)];

    DateTime? crossing(double Function(SkyPosition) height, bool rising) {
      for (var i = 0; i < steps; i++) {
        final before = height(points[i]);
        final after = height(points[i + 1]);
        if (rising ? (before < 0 && after >= 0) : (before >= 0 && after < 0)) {
          var low = midnight + i / steps;
          var high = midnight + (i + 1) / steps;
          while ((high - low) * 86400 > 0.5) {
            final middle = (low + high) / 2;
            (height(at(middle)) >= 0) == rising ? high = middle : low = middle;
          }
          return _instant((low + high) / 2);
        }
      }
      return null;
    }

    // The upper edge on the horizon, as seen.
    double edge(SkyPosition p) =>
        p.trueAltitude + p.semidiameter + 34 / 60 + _dip(height);
    double below(SkyPosition p, double depth) => p.trueAltitude + depth;

    // The meridian: the hour angle passing from east to west.
    DateTime? transit;
    for (var i = 0; i < steps; i++) {
      final before = points[i].hourAngle;
      final after = points[i + 1].hourAngle;
      if (before < 0 && after >= 0 && after - before < 90) {
        var low = midnight + i / steps;
        var high = midnight + (i + 1) / steps;
        while ((high - low) * 86400 > 0.5) {
          final middle = (low + high) / 2;
          at(middle).hourAngle >= 0 ? high = middle : low = middle;
        }
        transit = _instant((low + high) / 2);
        break;
      }
    }

    final isSun = body == Body.sun;
    final rise = crossing(edge, true);
    final set = crossing(edge, false);
    return SkyDay(
      rise: rise,
      set: set,
      riseAzimuth: rise == null ? null : at(_julianDay(rise)).azimuth,
      setAzimuth: set == null ? null : at(_julianDay(set)).azimuth,
      transit: transit,
      transitAltitude: transit == null
          ? null
          : at(_julianDay(transit)).altitude,
      civilDawn: isSun ? crossing((p) => below(p, 6), true) : null,
      civilDusk: isSun ? crossing((p) => below(p, 6), false) : null,
      nauticalDawn: isSun ? crossing((p) => below(p, 12), true) : null,
      nauticalDusk: isSun ? crossing((p) => below(p, 12), false) : null,
      astronomicalDawn: isSun ? crossing((p) => below(p, 18), true) : null,
      astronomicalDusk: isSun ? crossing((p) => below(p, 18), false) : null,
    );
  }

  /// The instant within the civil day [date] (midnight to midnight at
  /// [utcOffset]) that the centre of [body] passes [altitude] degrees,
  /// with no air, going up if [rising] and down if not. In Universal
  /// Time, to the second; null if it does not that day.
  static DateTime? passing(
    Body body,
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    required double altitude,
    required bool rising,
  }) {
    final midnight =
        date.dayNumber - 0.5 - utcOffset.inSeconds / Duration.secondsPerDay;
    double above(double jd) =>
        _position(body, jd, latitude, longitude, 0).trueAltitude - altitude;
    const steps = 144;
    var before = above(midnight);
    for (var i = 0; i < steps; i++) {
      final after = above(midnight + (i + 1) / steps);
      if (rising ? (before < 0 && after >= 0) : (before >= 0 && after < 0)) {
        var low = midnight + i / steps;
        var high = midnight + (i + 1) / steps;
        while ((high - low) * 86400 > 0.5) {
          final middle = (low + high) / 2;
          (above(middle) >= 0) == rising ? high = middle : low = middle;
        }
        return _instant((low + high) / 2);
      }
      before = after;
    }
    return null;
  }

  /// How far the air lifts a body whose true height is [h] degrees, in
  /// degrees, for air at 10 °C and 1010 hPa (Saemundsson, in Meeus 16.4):
  /// half a degree at the horizon, a minute of arc at 45 degrees.
  static double refraction(double h) {
    if (h < -1.9) return 0;
    final r = 1.02 / math.tan((h + 10.3 / (h + 5.11)) * _rad);
    return math.max(0, r) / 60;
  }

  // How far the sea horizon lies below the level at [height] metres, in
  // degrees: 1.76 minutes of arc times the root of the height.
  static double _dip(double height) =>
      height <= 0 ? 0 : 1.76 * math.sqrt(height) / 60;

  static SkyPosition _position(
    Body body,
    double jd,
    double latitude,
    double longitude,
    double height, {
    bool geocentric = false,
  }) {
    final nutation = Sun.nutationAt(jd);
    final double lambdaDegrees;
    final double betaDegrees;
    final double distance;
    PlanetView? planet;
    if (body == Body.sun) {
      lambdaDegrees = Sun.apparentLongitudeAt(jd);
      betaDegrees = 0;
      distance = Sun.distanceAt(jd) * astronomicalUnit;
    } else if (Planets.isPlanet(body)) {
      planet = Planets.view(body, jd);
      lambdaDegrees = planet.eclipticLongitude;
      betaDegrees = planet.eclipticLatitude;
      distance = planet.distance * astronomicalUnit;
    } else {
      lambdaDegrees =
          (Moon.moonLongitudeAt(jd) + nutation.longitude / 3600) % 360;
      betaDegrees = Moon.moonLatitudeAt(jd);
      distance = Moon.moonDistanceAt(jd);
    }
    final semidiameter = body == Body.sun
        ? _sunRadius / (distance / astronomicalUnit)
        : planet != null
        ? planet.diameter / 2 / 3600
        : math.asin(
                _moonRadius * math.sin(math.asin(_earthRadius / distance)),
              ) /
              _rad;
    return place(
      body,
      jd,
      lambdaDegrees,
      betaDegrees,
      distance,
      semidiameter,
      latitude,
      longitude,
      height,
      geocentric: geocentric,
    );
  }

  /// A body at apparent ecliptic [lambdaDegrees], [betaDegrees] of date
  /// and [distance] km from the Earth's centre, at Julian Day [jd] (UT),
  /// carried to the horizon of the place: for the sun, the moon and the
  /// planets alike.
  static SkyPosition place(
    Body body,
    double jd,
    double lambdaDegrees,
    double betaDegrees,
    double distance,
    double semidiameter,
    double latitude,
    double longitude,
    double height, {
    bool geocentric = false,
  }) {
    final nutation = Sun.nutationAt(jd);
    final t = (jd - 2451545) / 36525;
    // The mean obliquity (Meeus 22.2), then the true.
    final meanTilt =
        23.4392911 -
        (46.8150 * t + 0.00059 * t * t - 0.001813 * t * t * t) / 3600;
    final tilt = (meanTilt + nutation.obliquity / 3600) * _rad;
    final lambda = lambdaDegrees * _rad;
    final beta = betaDegrees * _rad;

    // Ecliptic to equator (Meeus 13.3, 13.4).
    final alpha = math.atan2(
      math.sin(lambda) * math.cos(tilt) - math.tan(beta) * math.sin(tilt),
      math.cos(lambda),
    );
    final delta = math.asin(
      math.sin(beta) * math.cos(tilt) +
          math.cos(beta) * math.sin(tilt) * math.sin(lambda),
    );

    // Apparent sidereal time at Greenwich (Meeus 12.4, with the equation
    // of the equinoxes), then the hour angle here.
    final mean =
        280.46061837 +
        360.98564736629 * (jd - 2451545) +
        0.000387933 * t * t -
        t * t * t / 38710000;
    final sidereal = mean + nutation.longitude / 3600 * math.cos(tilt);
    final hourAngle = (sidereal + longitude) * _rad - alpha;

    // From the centre of the Earth to the place (Meeus ch. 11, 40).
    final phi = latitude * _rad;
    final u = math.atan(0.99664719 * math.tan(phi));
    final rhoSin = 0.99664719 * math.sin(u) + height / 6378140 * math.sin(phi);
    final rhoCos = math.cos(u) + height / 6378140 * math.cos(phi);
    final parallax = math.asin(_earthRadius / distance);
    // From the centre the place's own displacement is nothing.
    final shifted = geocentric ? 0.0 : parallax;
    final shift = math.atan2(
      -rhoCos * math.sin(shifted) * math.sin(hourAngle),
      math.cos(delta) - rhoCos * math.sin(shifted) * math.cos(hourAngle),
    );
    final topoDelta = math.atan2(
      (math.sin(delta) - rhoSin * math.sin(shifted)) * math.cos(shift),
      math.cos(delta) - rhoCos * math.sin(shifted) * math.cos(hourAngle),
    );
    final topoHour = hourAngle - shift;

    // To the horizon (Meeus 13.5, 13.6), the bearing turned to count from
    // the north.
    final trueAltitude =
        math.asin(
          math.sin(phi) * math.sin(topoDelta) +
              math.cos(phi) * math.cos(topoDelta) * math.cos(topoHour),
        ) /
        _rad;
    final azimuth =
        (math.atan2(
                  math.sin(topoHour),
                  math.cos(topoHour) * math.sin(phi) -
                      math.tan(topoDelta) * math.cos(phi),
                ) /
                _rad +
            180) %
        360;
    final hour = ((topoHour / _rad) + 540) % 360 - 180;

    return SkyPosition(
      body: body,
      rightAscension: (alpha / _rad) % 360,
      declination: delta / _rad,
      eclipticLongitude: lambdaDegrees % 360,
      eclipticLatitude: betaDegrees,
      distance: distance,
      altitude: trueAltitude + refraction(trueAltitude),
      trueAltitude: trueAltitude,
      azimuth: azimuth,
      hourAngle: hour,
      semidiameter: semidiameter,
    );
  }

  static double _julianDay(DateTime instant) =>
      2440587.5 + instant.toUtc().microsecondsSinceEpoch / 86400e6;

  static DateTime _instant(double julianDay) =>
      DateTime.fromMillisecondsSinceEpoch(
        ((julianDay - 2440587.5) * 86400).round() * 1000,
        isUtc: true,
      );
}
