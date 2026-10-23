import 'dart:math' as math;

import 'civil_date.dart';
import 'sky_position.dart';
import 'stars.dart';
import 'sun.dart';

/// A stretch of time, in Universal Time.
typedef Span = ({DateTime start, DateTime end});

/// How the sun lights the land at a moment, by the height of its centre
/// with no air (its true altitude): the bands photographers plan by.
enum LightBand {
  /// The sun more than 6° up.
  day,

  /// From 6° up to 4° down: low, warm, long-shadowed light.
  golden,

  /// From 4° down to 6° down: the sky blue, the land without shadow.
  blue,

  /// The sun more than 6° down.
  night;

  /// The band of a sun whose true altitude is [altitude] degrees.
  static LightBand of(double altitude) => altitude > LightHours.goldenTop
      ? day
      : altitude > LightHours.blueTop
      ? golden
      : altitude > LightHours.blueBottom
      ? blue
      : night;
}

/// The golden and blue hours of a civil day at a place: the stretches
/// when the sun's centre, with no air, stands between [goldenTop] and
/// [blueTop] (golden) and between [blueTop] and [blueBottom] (blue),
/// morning and evening.
///
/// These bands are a convention of photographers, not a measure of the
/// light: the same convention as the photography planners use. Whether
/// the light is good on the day is the weather's, which is not known
/// here.
class LightHours {
  static const goldenTop = 6.0;
  static const blueTop = -4.0;
  static const blueBottom = -6.0;

  /// Each null where the sun does not pass both its ends that day (far
  /// from the equator, or a sun that never climbs to 6°).
  final Span? morningBlue;
  final Span? morningGolden;
  final Span? eveningGolden;
  final Span? eveningBlue;

  const LightHours({
    this.morningBlue,
    this.morningGolden,
    this.eveningGolden,
    this.eveningBlue,
  });

  static LightHours of(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
  }) {
    DateTime? pass(double altitude, bool rising) => SkyNow.passing(
      Body.sun,
      date,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
      altitude: altitude,
      rising: rising,
    );
    Span? span(DateTime? start, DateTime? end) =>
        start == null || end == null || !end.isAfter(start)
        ? null
        : (start: start, end: end);
    final upBlue = pass(blueBottom, true);
    final upGold = pass(blueTop, true);
    final upDay = pass(goldenTop, true);
    final downDay = pass(goldenTop, false);
    final downGold = pass(blueTop, false);
    final downBlue = pass(blueBottom, false);
    return LightHours(
      morningBlue: span(upBlue, upGold),
      morningGolden: span(upGold, upDay),
      eveningGolden: span(downDay, downGold),
      eveningBlue: span(downGold, downBlue),
    );
  }
}

/// What the sun does to things on the ground at a moment.
abstract final class SunLight {
  /// The shadow of an upright thing on level ground: its length for each
  /// unit of the thing's height, and the bearing it falls towards (away
  /// from the sun). Null with the sun down.
  static ({double length, double bearing})? shadow(SkyPosition sun) {
    if (sun.altitude <= 0) return null;
    return (
      length: 1 / math.tan(sun.altitude * math.pi / 180),
      bearing: (sun.azimuth + 180) % 360,
    );
  }

  /// Where a rainbow would stand, if there were rain and sun together: it
  /// is a circle 42° about the point opposite the sun (the second bow
  /// 51°), so its top is 42° less the sun's height, at the bearing away
  /// from the sun. Null where the whole bow is below the horizon, the sun
  /// higher than 42° (or down).
  static ({double top, double? secondTop, double bearing})? rainbow(
    SkyPosition sun,
  ) {
    if (sun.altitude <= 0 || sun.altitude >= 42) return null;
    return (
      top: 42 - sun.altitude,
      secondTop: sun.altitude < 51 ? 51 - sun.altitude : null,
      bearing: (sun.azimuth + 180) % 360,
    );
  }
}

/// The heart of the Milky Way, its brightest part toward the galaxy's
/// centre (Sagittarius A*, J2000), and when it can be photographed.
abstract final class MilkyWay {
  static const rightAscension = 266.41683;
  static const declination = -29.00781;

  /// How high it must stand to be worth a photograph, in degrees.
  static const lowest = 10.0;

  /// How high it must stand at [latitude]: [lowest], or where it never
  /// climbs so high (north of about 51°), within 3° of the highest it
  /// gets; null where it never clears 3°.
  static double? lowestAt(double latitude) {
    final highest = 90 - (latitude - declination).abs();
    if (highest < 3) return null;
    return math.min(lowest, highest - 3);
  }

  /// Where it stands at [instant].
  static ({double altitude, double azimuth}) at(
    DateTime instant, {
    required double latitude,
    required double longitude,
  }) => StarSky.at(
    instant,
    latitude: latitude,
    longitude: longitude,
  ).place(rightAscension, declination);

  /// The night that begins on the evening of [date]: the stretches,
  /// to five minutes, when the core stands [lowestAt] or higher, the
  /// sky is fully dark (the sun 18° down), and, for [moonless], the moon
  /// is down too.
  static ({List<Span> dark, List<Span> moonless}) night(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
  }) {
    final noon = DateTime.utc(
      date.year,
      date.month,
      date.day,
      12,
    ).subtract(utcOffset);
    const step = Duration(minutes: 5);
    final dark = <Span>[];
    final moonless = <Span>[];
    final floor = lowestAt(latitude);
    if (floor == null) return (dark: dark, moonless: moonless);
    DateTime? darkFrom, moonlessFrom;
    for (var k = 0; k <= 24 * 12; k++) {
      final t = noon.add(step * k);
      final last = k == 24 * 12;
      var isDark = false, isMoonless = false;
      if (!last) {
        final sun = SkyNow.sun(t, latitude: latitude, longitude: longitude);
        if (sun.trueAltitude <= -18) {
          final core = at(t, latitude: latitude, longitude: longitude);
          if (core.altitude >= floor) {
            isDark = true;
            isMoonless =
                SkyNow.moon(
                  t,
                  latitude: latitude,
                  longitude: longitude,
                ).altitude <
                0;
          }
        }
      }
      if (isDark) {
        darkFrom ??= t;
      } else if (darkFrom != null) {
        dark.add((start: darkFrom, end: t));
        darkFrom = null;
      }
      if (isMoonless) {
        moonlessFrom ??= t;
      } else if (moonlessFrom != null) {
        moonless.add((start: moonlessFrom, end: t));
        moonlessFrom = null;
      }
    }
    return (dark: dark, moonless: moonless);
  }
}

/// Days the sun or the moon rises or sets along a chosen bearing: to
/// line it up behind a landmark.
abstract final class Alignments {
  /// The days from [from], over [days] days, that [body] rises (or, not
  /// [rising], sets) within [within] degrees of [bearing]. Where it does
  /// so several days running (the sun moves slowly along the horizon),
  /// only the day nearest the bearing.
  static List<Aligned> find(
    Body body, {
    required bool rising,
    required double bearing,
    required CivilDate from,
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    int days = 366,
    double within = 1,
  }) {
    final both = risesAndSets(
      body,
      bearing: bearing,
      from: from,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
      days: days,
      within: within,
    );
    return rising ? both.rises : both.sets;
  }

  /// [find] for its rising and its setting together, each day worked out
  /// once.
  static ({List<Aligned> rises, List<Aligned> sets}) risesAndSets(
    Body body, {
    required double bearing,
    required CivilDate from,
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    int days = 366,
    double within = 1,
  }) {
    double off(double azimuth) => ((azimuth - bearing + 540) % 360 - 180).abs();
    final rises = <Aligned>[], sets = <Aligned>[];
    Aligned? riseRun, setRun;
    Aligned? step(
      List<Aligned> found,
      Aligned? run,
      CivilDate date,
      DateTime? at,
      double? azimuth,
    ) {
      if (at != null && azimuth != null && off(azimuth) <= within) {
        final here = (date: date, at: at, azimuth: azimuth);
        return run == null || off(azimuth) < off(run.azimuth) ? here : run;
      }
      if (run != null) found.add(run);
      return null;
    }

    for (var d = 0; d < days; d++) {
      final date = from.addDays(d);
      final day = SkyNow.day(
        body,
        date,
        latitude: latitude,
        longitude: longitude,
        utcOffset: utcOffset,
      );
      riseRun = step(rises, riseRun, date, day.rise, day.riseAzimuth);
      setRun = step(sets, setRun, date, day.set, day.setAzimuth);
    }
    if (riseRun != null) rises.add(riseRun);
    if (setRun != null) sets.add(setRun);
    return (rises: rises, sets: sets);
  }
}

/// A day a body rises or sets along a chosen bearing: the day, the
/// instant, and the bearing it truly does.
typedef Aligned = ({CivilDate date, DateTime at, double azimuth});

/// The full moons over a stretch, each with how far the moon is.
abstract final class FullMoons {
  /// Each full moon (the moon opposite the sun in longitude) from [from]
  /// over [days] days: its instant, to the minute, and the distance from
  /// the centre of the Earth to the moon's, in kilometres.
  static List<({DateTime at, double distance})> within(
    DateTime from,
    int days,
  ) {
    double past(DateTime t) =>
        (SkyNow.moonFace(t).elongation - 180 + 540) % 360 - 180;
    final found = <({DateTime at, double distance})>[];
    var before = from;
    var a = past(before);
    for (var h = 6; h <= days * 24; h += 6) {
      final after = from.add(Duration(hours: h));
      final b = past(after);
      // Through opposition: from just short of it to just past it.
      if (a < 0 && b >= 0 && b - a < 90) {
        var low = before, high = after;
        while (high.difference(low) > const Duration(seconds: 30)) {
          final middle = low.add(high.difference(low) ~/ 2);
          past(middle) >= 0 ? high = middle : low = middle;
        }
        final at = low.add(high.difference(low) ~/ 2);
        found.add((
          at: at,
          distance: SkyNow.moon(at, latitude: 0, longitude: 0).distance,
        ));
      }
      before = after;
      a = b;
    }
    return found;
  }
}

/// When the sun stands at a longitude: meteor showers peak at fixed
/// longitudes of the sun, on a date that drifts with the leap years.
abstract final class SunLongitude {
  /// The instant in [year] (UTC) at which the sun's longitude reaches
  /// [degrees], to the minute: measured from the equinox of 2000.0, as the
  /// IMO gives its showers' maxima, the general precession (1.3970° a
  /// century, Lieske's) taken off the apparent longitude of the date.
  static DateTime when(int year, double degrees) {
    double off(DateTime t) {
      final jd = 2440587.5 + t.microsecondsSinceEpoch / 86400e6;
      final precession = 1.396971 * (jd - 2451545) / 36525;
      return (Sun.apparentLongitudeAt(jd) - precession - degrees + 540) % 360 -
          180;
    }

    var before = DateTime.utc(year);
    var a = off(before);
    for (var d = 1; d <= 367; d++) {
      final after = DateTime.utc(year).add(Duration(days: d));
      final b = off(after);
      if (a < 0 && b >= 0) {
        var low = before, high = after;
        while (high.difference(low) > const Duration(minutes: 1)) {
          final middle = low.add(high.difference(low) ~/ 2);
          off(middle) >= 0 ? high = middle : low = middle;
        }
        return low;
      }
      before = after;
      a = b;
    }
    return DateTime.utc(year);
  }
}
