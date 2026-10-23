import 'dart:math' as math;

import 'civil_date.dart';
import 'hijri_date.dart';
import 'salat_method.dart';
import 'sky_position.dart';

/// The times of the day by which prayer is kept in Indonesia, in the
/// order they come: the five prayers, and beside them imsak (the stop
/// before dawn in the fasting month), sunrise (when the dawn prayer's time
/// ends) and duha.
enum Salat {
  imsak(prayer: false),
  subuh(prayer: true),
  terbit(prayer: false),
  duha(prayer: false),
  zuhur(prayer: true),
  asar(prayer: true),
  magrib(prayer: true),
  isya(prayer: true);

  /// One of the five obligatory prayers.
  final bool prayer;

  const Salat({required this.prayer});

  /// The five, in the order of the day.
  static const five = [subuh, zuhur, asar, magrib, isya];
}

/// The prayer times of one civil day at one place, reckoned as the
/// Ministry of Religious Affairs (Kementerian Agama) reckons its
/// published schedules:
///
///  * Subuh when the sun's centre is 20° below the horizon, Isya when it
///    is 18° below.
///  * Terbit and Magrib with the centre 1° below the horizon: the upper
///    edge rising or setting, the air's bending and a few tens of metres
///    of height above the land around.
///  * Duha with the sun 4.5° up.
///  * Zuhur at the meridian.
///  * Asar when a thing's shadow is its own length beyond its shadow at
///    noon (the Shafi'i reckoning).
///  * Imsak ten minutes before Subuh.
///
/// To each a margin of safety, the ihtiyat: two minutes later (three for
/// Zuhur), and two minutes earlier for Terbit, which ends a time rather
/// than beginning one. Then whole minutes, rounded up, and Terbit down,
/// so the margin is never eaten by the rounding. Checked in the tests
/// against the ministry's own schedules for four cities across three time
/// zones: every time within a minute, nine in ten to the minute.
class SalatTimes {
  /// Minutes after local midnight, by the clock of the UTC offset asked
  /// for; null for a time that does not come that day, as Isya does not
  /// in a northern midsummer.
  final Map<Salat, int?> minutes;

  /// The sun's meridian that day, which Zuhur is reckoned from: in
  /// Universal Time, to the second.
  final DateTime? noon;

  const SalatTimes._(this.minutes, this.noon);

  int? operator [](Salat salat) => minutes[salat];

  /// The same times, each moved by [by] (minutes after midnight in,
  /// minutes after midnight out): for a day the clocks change, where a
  /// time before the change stands where the clock then had it.
  SalatTimes shifted(int Function(int minute) by) => SalatTimes._({
    for (final MapEntry(:key, :value) in minutes.entries)
      key: value == null ? null : by(value),
  }, noon);

  /// The degrees below the horizon of the sun's centre at Subuh and
  /// Isya.
  static const dawnDepth = 20.0;
  static const nightDepth = 18.0;

  /// The height of the sun's centre at Terbit and Magrib.
  static const horizon = -1.0;

  /// The height of the sun at Duha.
  static const duhaHeight = 4.5;

  static const _rad = math.pi / 180;

  /// The times by [method]; Indonesia's ministry unless another is
  /// given. [madhab] and [highLatitude] are for the other methods only:
  /// the ministry's own reckoning is Shafi'i, and leaves out a time that
  /// does not come.
  factory SalatTimes.of(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    SalatMethod method = SalatMethod.kemenag,
    Madhab madhab = Madhab.standard,
    HighLatitudeRule? highLatitude,
  }) {
    if (method != SalatMethod.kemenag) {
      return SalatTimes._elsewhere(
        date,
        latitude: latitude,
        longitude: longitude,
        utcOffset: utcOffset,
        method: method,
        madhab: madhab,
        highLatitude: highLatitude ?? HighLatitudeRule.recommended(latitude),
      );
    }
    DateTime? passing(double altitude, bool rising) => SkyNow.passing(
      Body.sun,
      date,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
      altitude: altitude,
      rising: rising,
    );

    // Minutes after local midnight, the margin added, then whole.
    final midnight = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(utcOffset);
    int? clock(DateTime? at, int margin, {bool down = false}) {
      if (at == null) return null;
      final minutes = at.difference(midnight).inMilliseconds / 60000 + margin;
      return down ? minutes.floor() : minutes.ceil();
    }

    final noon = SkyNow.day(
      Body.sun,
      date,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
    ).transit;

    // Asar: the height at which a shadow is one length longer than at
    // noon, the noon shadow being tan |latitude - declination|.
    double? asarHeight;
    if (noon != null) {
      final declination = SkyNow.sun(
        noon,
        latitude: latitude,
        longitude: longitude,
      ).declination;
      final shadow = 1 + math.tan((latitude - declination).abs() * _rad);
      asarHeight = math.atan(1 / shadow) / _rad;
    }

    final subuh = clock(passing(-dawnDepth, true), 2);
    return SalatTimes._({
      Salat.imsak: subuh == null ? null : subuh - 10,
      Salat.subuh: subuh,
      Salat.terbit: clock(passing(horizon, true), -2, down: true),
      Salat.duha: clock(passing(duhaHeight, true), 2),
      Salat.zuhur: clock(noon, 3),
      Salat.asar: asarHeight == null
          ? null
          : clock(passing(asarHeight, false), 2),
      Salat.magrib: clock(passing(horizon, false), 2),
      Salat.isya: clock(passing(-nightDepth, false), 2),
    }, noon);
  }

  /// The conventions of other bodies, as the adhan library reckons them:
  /// sunrise and sunset with the sun's centre 50′ down (its upper edge
  /// and the air), dawn and nightfall by the method's angles held within
  /// the night by [highLatitude] (or, for the Moonsighting Committee, by
  /// the season), Asar by the madhab's shadow, each body's own minutes
  /// added, then rounded to the nearest minute (up, for Singapore).
  /// No Imsak, which is Indonesia's; Duha with the sun 4.5° up, as the
  /// ministry.
  factory SalatTimes._elsewhere(
    CivilDate date, {
    required double latitude,
    required double longitude,
    required Duration utcOffset,
    required SalatMethod method,
    required Madhab madhab,
    required HighLatitudeRule highLatitude,
  }) {
    DateTime? passing(double altitude, bool rising, [CivilDate? on]) =>
        SkyNow.passing(
          Body.sun,
          on ?? date,
          latitude: latitude,
          longitude: longitude,
          utcOffset: utcOffset,
          altitude: altitude,
          rising: rising,
        );
    const edge = -50 / 60;
    final midnight = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(utcOffset);
    int? clock(DateTime? at, String time) {
      if (at == null) return null;
      final minutes =
          at.difference(midnight).inMilliseconds / 60000 +
          method.adjustment(time);
      return method.roundUp ? minutes.ceil() : minutes.round();
    }

    final noon = SkyNow.day(
      Body.sun,
      date,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
    ).transit;
    final sunrise = passing(edge, true);
    final sunset = passing(edge, false);
    final tomorrowSunrise = passing(edge, true, date.addDays(1));
    final night = sunset == null || tomorrowSunrise == null
        ? null
        : tomorrowSunrise.difference(sunset);

    var fajr = passing(-method.fajrAngle, true);
    DateTime? isha;
    if (method.ishaInterval > 0) {
      // Ramadan by the tabular Hijri calendar, which may stand a day off
      // the Umm al-Qura calendar at either end of the month.
      final ramadan =
          method == SalatMethod.ummAlQura &&
          HijriDate.supports(date) &&
          HijriDate.of(date).month == HijriMonth.ramadan;
      isha = sunset?.add(
        Duration(minutes: method.ishaInterval + (ramadan ? 30 : 0)),
      );
    } else {
      isha = passing(-method.ishaAngle, false);
    }

    if (sunrise != null && sunset != null && night != null) {
      final ({double fajr, double isha}) portion = switch (highLatitude) {
        HighLatitudeRule.middleOfTheNight => (fajr: 1 / 2, isha: 1 / 2),
        HighLatitudeRule.seventhOfTheNight => (fajr: 1 / 7, isha: 1 / 7),
        HighLatitudeRule.twilightAngle => (
          fajr: method.fajrAngle / 60,
          isha: method.ishaAngle / 60,
        ),
      };
      DateTime safeFajr, safeIsha;
      if (method == SalatMethod.moonsightingCommittee) {
        if (latitude.abs() >= 55) {
          safeFajr = sunrise.subtract(night ~/ 7);
          safeIsha = sunset.add(night ~/ 7);
          fajr = safeFajr;
          isha = safeIsha;
        } else {
          final days = _daysSinceSolstice(date, latitude);
          safeFajr = sunrise.subtract(
            Duration(seconds: (_morning(latitude, days) * 60).round()),
          );
          safeIsha = sunset.add(
            Duration(seconds: (_evening(latitude, days) * 60).round()),
          );
        }
      } else {
        safeFajr = sunrise.subtract(night * portion.fajr);
        safeIsha = sunset.add(night * portion.isha);
      }
      if (fajr == null || safeFajr.isAfter(fajr)) fajr = safeFajr;
      if (method.ishaInterval == 0 &&
          (isha == null || safeIsha.isBefore(isha))) {
        isha = safeIsha;
      }
    }

    var maghrib = sunset;
    final maghribAngle = method.maghribAngle;
    if (maghribAngle != null && sunset != null) {
      final later = passing(-maghribAngle, false);
      if (later != null &&
          later.isAfter(sunset) &&
          (isha == null || isha.isAfter(later))) {
        maghrib = later;
      }
    }

    double? asarHeight;
    if (noon != null) {
      final declination = SkyNow.sun(
        noon,
        latitude: latitude,
        longitude: longitude,
      ).declination;
      final shadow =
          madhab.shadow + math.tan((latitude - declination).abs() * _rad);
      asarHeight = math.atan(1 / shadow) / _rad;
    }

    return SalatTimes._({
      Salat.imsak: null,
      Salat.subuh: clock(fajr, 'subuh'),
      Salat.terbit: clock(sunrise, 'terbit'),
      Salat.duha: clock(passing(duhaHeight, true), 'duha'),
      Salat.zuhur: clock(noon, 'zuhur'),
      Salat.asar: asarHeight == null
          ? null
          : clock(passing(asarHeight, false), 'asar'),
      Salat.magrib: clock(maghrib, 'magrib'),
      Salat.isya: clock(isha, 'isya'),
    }, noon);
  }

  // The Moonsighting Committee's season, after the adhan library: days
  // since the winter solstice of the place's hemisphere, near enough.
  static int _daysSinceSolstice(CivilDate date, double latitude) {
    final leap =
        date.year % 4 == 0 && (date.year % 100 != 0 || date.year % 400 == 0);
    final length = leap ? 366 : 365;
    final dayOfYear = date.dayNumber - CivilDate(date.year, 1, 1).dayNumber + 1;
    if (latitude >= 0) {
      final d = dayOfYear + 10;
      return d >= length ? d - length : d;
    }
    final d = dayOfYear - (leap ? 173 : 172);
    return d < 0 ? d + length : d;
  }

  static double _seasonal(double a, double b, double c, double d, int days) {
    if (days < 91) return a + (b - a) / 91 * days;
    if (days < 137) return b + (c - b) / 46 * (days - 91);
    if (days < 183) return c + (d - c) / 46 * (days - 137);
    if (days < 229) return d + (c - d) / 46 * (days - 183);
    if (days < 275) return c + (b - c) / 46 * (days - 229);
    return b + (a - b) / 91 * (days - 275);
  }

  // Minutes from dawn to sunrise.
  static double _morning(double latitude, int days) {
    final l = latitude.abs();
    return _seasonal(
      75 + 28.65 / 55 * l,
      75 + 19.44 / 55 * l,
      75 + 32.74 / 55 * l,
      75 + 48.10 / 55 * l,
      days,
    );
  }

  // Minutes from sunset to nightfall (the general shafaq).
  static double _evening(double latitude, int days) {
    final l = latitude.abs();
    return _seasonal(
      75 + 25.60 / 55 * l,
      75 + 2.05 / 55 * l,
      75 - 9.21 / 55 * l,
      75 + 6.14 / 55 * l,
      days,
    );
  }
}
