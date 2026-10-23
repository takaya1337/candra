import 'dart:math' as math;

import 'civil_date.dart';
import 'sky_position.dart';

/// Yallop's classes of the crescent (NAO Technical Note 69, 1997): A
/// easily seen, B seen in perfect conditions, C may need optical aid to
/// find, D will need it, E not seen with a telescope, F below the Danjon
/// limit.
enum YallopClass { a, b, c, d, e, f }

/// Odeh's zones (Experimental Astronomy 18, 2004): A seen by the naked
/// eye, B with optical aid and maybe the naked eye, C with optical aid
/// only, D not even with optical aid.
enum OdehZone { a, b, c, d }

/// The young crescent on one evening at one place: where the moon stands
/// at sunset after the new moon, and what the published criteria make of
/// it. Astronomy only: whether a month begins is for those who rule on
/// it, by their own criterion and, for many, by sight.
///
/// Sunset is the sun's upper edge on the horizon as the eye sees it, the
/// air lifting it 34′, with no dip (the almanacs' rule, and Bosscha
/// Observatory's). The moon's height at sunset is its centre, from the
/// place, with no air, as Bosscha's releases give it; [apparentAltitude]
/// adds the air. Elongations are between centres.
class CrescentEvening {
  /// The new moon nearest the evening: the moon and the sun at one
  /// longitude, from the Earth's centre (ijtimak).
  final DateTime conjunction;

  final DateTime sunset;

  /// The moon's upper edge on the horizon, as the sunset; null if it
  /// does not set within a day of sunset.
  final DateTime? moonset;

  /// At sunset.
  final double altitude;
  final double apparentAltitude;
  final double sunAzimuth;
  final double moonAzimuth;

  /// From the Earth's centre, and from the place.
  final double elongation;
  final double topocentricElongation;

  /// The lit part of the disc, 0 to 1.
  final double illumination;

  /// Muhammadiyah's height of the moon's upper edge, as its Pedoman
  /// Hisab (2009) works it: the centre's from the place, plus 34′30″ of
  /// air and the semidiameter.
  final double upperEdge;

  /// Yallop's and Odeh's best time, sunset and four ninths of the lag,
  /// and their numbers then; null where the moon sets first.
  final DateTime? bestTime;
  final double? yallopArcv;
  final double? yallopWidth;
  final double? q;
  final double? odehArcv;
  final double? odehWidth;
  final double? v;

  const CrescentEvening({
    required this.conjunction,
    required this.sunset,
    required this.moonset,
    required this.altitude,
    required this.apparentAltitude,
    required this.sunAzimuth,
    required this.moonAzimuth,
    required this.elongation,
    required this.topocentricElongation,
    required this.illumination,
    required this.upperEdge,
    required this.bestTime,
    required this.yallopArcv,
    required this.yallopWidth,
    required this.q,
    required this.odehArcv,
    required this.odehWidth,
    required this.v,
  });

  /// From the new moon to sunset; negative when the new moon is still to
  /// come.
  Duration get age => sunset.difference(conjunction);

  /// From sunset to moonset; negative when the moon sets first.
  Duration? get lag => moonset?.difference(sunset);

  /// MABIMS (2021, Indonesia's ministry from 1443 H, 2022): the moon at
  /// least 3° high and 6.4° from the sun at sunset. The elongation is
  /// from the Earth's centre, as the ministry agreed in March 2023
  /// (Brunei, Malaysia and Singapore take it from the place).
  bool get mabims => age > Duration.zero && altitude >= 3 && elongation >= 6.4;

  /// The new moon before sunset and the moon's upper edge above the
  /// horizon then: Muhammadiyah's wujudul hilal, its rule until 1446 H
  /// (2025), when its global calendar (KHGT) took over.
  bool get wujudulHilal => age > Duration.zero && upperEdge > 0;

  /// Yallop's class, from q; null where the moon sets first.
  YallopClass? get yallop {
    final q = this.q;
    if (q == null) return null;
    if (q > 0.216) return YallopClass.a;
    if (q > -0.014) return YallopClass.b;
    if (q > -0.160) return YallopClass.c;
    if (q > -0.232) return YallopClass.d;
    if (q > -0.293) return YallopClass.e;
    return YallopClass.f;
  }

  /// Odeh's zone, from V; null where the moon sets first.
  OdehZone? get odeh {
    final v = this.v;
    if (v == null) return null;
    if (v >= 5.65) return OdehZone.a;
    if (v >= 2) return OdehZone.b;
    if (v >= -0.96) return OdehZone.c;
    return OdehZone.d;
  }
}

/// The crescent's evenings, worked from the sun and the moon themselves
/// (`SkyNow`).
abstract final class Hilal {
  static const _rad = math.pi / 180;
  static const _earthRadius = 6378.14;

  /// The new moon nearest [instant], to the second: where the moon's
  /// longitude from the Earth's centre meets the sun's.
  static DateTime conjunctionNear(DateTime instant) {
    var t = instant;
    for (var k = 0; k < 8; k++) {
      final off = (SkyNow.moonFace(t).elongation + 180) % 360 - 180;
      // The moon gains about 12.19° a day on the sun.
      final step = Duration(microseconds: (-off / 12.19 * 86400e6).round());
      t = t.add(step);
      if (step.abs() < const Duration(milliseconds: 500)) break;
    }
    return t;
  }

  /// Yallop's q (NAO TN 69, eq. 6.1): the arc of vision against the
  /// cubic in the width, in minutes of arc.
  static double yallopQ(double arcv, double width) =>
      (arcv -
          (11.8371 -
              6.3226 * width +
              0.7319 * width * width -
              0.1018 * width * width * width)) /
      10;

  /// Odeh's V (2004): the same cubic, its constant 7.1651.
  static double odehV(double arcv, double width) =>
      arcv -
      (-0.1018 * width * width * width +
          0.7319 * width * width -
          6.3226 * width +
          7.1651);

  static double _between(double a1, double z1, double a2, double z2) {
    final c =
        math.sin(a1 * _rad) * math.sin(a2 * _rad) +
        math.cos(a1 * _rad) * math.cos(a2 * _rad) * math.cos((z1 - z2) * _rad);
    return math.acos(c.clamp(-1.0, 1.0)) / _rad;
  }

  /// The crescent's numbers at [t] by Yallop's reckoning (from the
  /// Earth's centre, no air) and Odeh's (from the place, no air): each
  /// arc of vision, and each width, the moon's semidiameter as the place
  /// sees it (Yallop's SD′) times one less the cosine of the elongation.
  static ({double yArcv, double yWidth, double oArcv, double oWidth}) at(
    DateTime t, {
    required double latitude,
    required double longitude,
  }) {
    final sunG = SkyNow.fromCentre(
      Body.sun,
      t,
      latitude: latitude,
      longitude: longitude,
    );
    final moonG = SkyNow.fromCentre(
      Body.moon,
      t,
      latitude: latitude,
      longitude: longitude,
    );
    final sun = SkyNow.sun(t, latitude: latitude, longitude: longitude);
    final moon = SkyNow.moon(t, latitude: latitude, longitude: longitude);
    final arclG = _between(
      moonG.declination,
      moonG.rightAscension,
      sunG.declination,
      sunG.rightAscension,
    );
    final arclT = _between(
      moon.trueAltitude,
      moon.azimuth,
      sun.trueAltitude,
      sun.azimuth,
    );
    // Yallop: SD = 0.27245 π, SD′ = SD (1 + sin h sin π), h the
    // geocentric height; in minutes of arc.
    final parallax = math.asin(_earthRadius / moonG.distance);
    final sd = 0.27245 * parallax / _rad * 60;
    final sdPrime =
        sd * (1 + math.sin(moonG.trueAltitude * _rad) * math.sin(parallax));
    return (
      yArcv: moonG.trueAltitude - sunG.trueAltitude,
      yWidth: sdPrime * (1 - math.cos(arclG * _rad)),
      oArcv: moon.trueAltitude - sun.trueAltitude,
      oWidth: sdPrime * (1 - math.cos(arclT * _rad)),
    );
  }

  /// Only the moon's height and elongation at sunset on [date], as
  /// [evening] has them, for a sweep over many places (whether the
  /// MABIMS criterion is met anywhere in Indonesia); null where the sun
  /// does not set.
  static ({double altitude, double elongation})? atSunset(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
  }) {
    final sunset = SkyNow.day(
      Body.sun,
      date,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
    ).set;
    if (sunset == null) return null;
    final moon = SkyNow.moon(sunset, latitude: latitude, longitude: longitude);
    final sunG = SkyNow.fromCentre(
      Body.sun,
      sunset,
      latitude: latitude,
      longitude: longitude,
    );
    final moonG = SkyNow.fromCentre(
      Body.moon,
      sunset,
      latitude: latitude,
      longitude: longitude,
    );
    return (
      altitude: moon.trueAltitude,
      elongation: _between(
        moonG.declination,
        moonG.rightAscension,
        sunG.declination,
        sunG.rightAscension,
      ),
    );
  }

  /// The evening of [date] at [latitude], [longitude], its day running
  /// midnight to midnight at [utcOffset]; null where the sun does not set
  /// that day.
  static CrescentEvening? evening(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
  }) {
    final sunDay = SkyNow.day(
      Body.sun,
      date,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
    );
    final sunset = sunDay.set;
    if (sunset == null) return null;

    // The moon's setting nearest after sunset, or just before it.
    DateTime? moonset;
    for (final day in [date, date.addDays(1)]) {
      final set = SkyNow.day(
        Body.moon,
        day,
        latitude: latitude,
        longitude: longitude,
        utcOffset: utcOffset,
      ).set;
      if (set == null) continue;
      final gap = set.difference(sunset);
      if (gap > const Duration(hours: -12) && gap < const Duration(hours: 24)) {
        moonset = set;
        break;
      }
    }

    final sun = SkyNow.sun(sunset, latitude: latitude, longitude: longitude);
    final moon = SkyNow.moon(sunset, latitude: latitude, longitude: longitude);
    final sunG = SkyNow.fromCentre(
      Body.sun,
      sunset,
      latitude: latitude,
      longitude: longitude,
    );
    final moonG = SkyNow.fromCentre(
      Body.moon,
      sunset,
      latitude: latitude,
      longitude: longitude,
    );

    final lag = moonset?.difference(sunset);
    DateTime? best;
    ({double yArcv, double yWidth, double oArcv, double oWidth})? b;
    if (lag != null && lag > Duration.zero) {
      best = sunset.add(lag * 4 ~/ 9);
      b = at(best, latitude: latitude, longitude: longitude);
    }

    return CrescentEvening(
      conjunction: conjunctionNear(sunset),
      sunset: sunset,
      moonset: moonset,
      altitude: moon.trueAltitude,
      apparentAltitude: moon.altitude,
      sunAzimuth: sun.azimuth,
      moonAzimuth: moon.azimuth,
      elongation: _between(
        moonG.declination,
        moonG.rightAscension,
        sunG.declination,
        sunG.rightAscension,
      ),
      topocentricElongation: _between(
        moon.trueAltitude,
        moon.azimuth,
        sun.trueAltitude,
        sun.azimuth,
      ),
      illumination: SkyNow.moonFace(sunset).illumination,
      upperEdge: moon.trueAltitude + 34.5 / 60 + moon.semidiameter,
      bestTime: best,
      yallopArcv: b?.yArcv,
      yallopWidth: b?.yWidth,
      q: b == null ? null : yallopQ(b.yArcv, b.yWidth),
      odehArcv: b?.oArcv,
      odehWidth: b?.oWidth,
      v: b == null ? null : odehV(b.oArcv, b.oWidth),
    );
  }
}
