import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sacred_time/sacred_time.dart';

import 'strings.dart';

/// The moment something was first saved, as every calendar in the app
/// reads it: kept with each new entry and reminder, written once and
/// never worked out again or shown (owner, 17 October 2026). It records
/// when it was made, which is not always the day it is about.
///
/// Every key is always there, in the same order; a value that cannot be
/// had is null (owner, 17 October 2026). What needs the sky of a place
/// (the planetary hour, where the sun, the moon and the planets stood,
/// the light) is read only from the item's own geotag: with none, those
/// are null, and the place set is never used, so a file never says more
/// of where it was written than its writer chose to. A reminder has no
/// geotag, so its sky is always null.
///
/// The words are the files' fixed English, as the calendar lines are.
///
/// Its last key, [id], is the item's one unchanging name: the SHA-256 of
/// every other line of the record, which never changes either. The date
/// and time of an entry may be corrected, and its file then moves; the
/// id stays (owner, 17 October 2026). [nonce], sixteen random hex digits,
/// is in the record so two things saved in the same second with nothing
/// else to tell them apart (no geotag) still have two ids.
abstract final class MomentStamp {
  static final _random = Random.secure();

  static const _words = Strings(AppLanguage.en);

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _pad(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');

  /// Every key, in the order written.
  static const keys = [
    'utc',
    'local',
    'julian_day',
    'weekday',
    'weton',
    'neptu',
    'javanese',
    'hijri',
    'chinese',
    'chinese_day_element',
    'bazi',
    'mangsa',
    'moon_phase',
    'moon_illumination',
    'moon_elongation',
    'sun_longitude',
    'weekday_planet',
    'geotag',
    'planetary_hour',
    'sun',
    'light',
    'moon',
    'planets_up',
    'nonce',
    'id',
  ];

  /// The keys that need the sky of a place: null without a geotag.
  static const skyKeys = [
    'planetary_hour',
    'sun',
    'light',
    'moon',
    'planets_up',
  ];

  /// [now] in every system, the sky from [geotag], the item's own.
  static Map<String, String?> of(
    DateTime now, {
    required Duration utcOffset,
    ({double latitude, double longitude})? geotag,
  }) {
    final utc = now.toUtc();
    final wall = utc.add(utcOffset);
    final date = CivilDate(wall.year, wall.month, wall.day);
    final minutes = utcOffset.inMinutes.abs();
    final offset =
        '${utcOffset.isNegative ? '-' : '+'}'
        '${_pad(minutes ~/ 60)}:${_pad(minutes % 60)}';
    // Every key, null until known; a map literal keeps the order.
    final m = <String, String?>{for (final key in keys) key: null};
    m['utc'] = '${utc.toIso8601String().split('.').first}Z';
    m['local'] =
        '${_pad(wall.year, 4)}-${_pad(wall.month)}-${_pad(wall.day)} '
        '${_pad(wall.hour)}:${_pad(wall.minute)}:${_pad(wall.second)} $offset';
    m['julian_day'] = (2440587.5 + utc.microsecondsSinceEpoch / 86400e6)
        .toStringAsFixed(6);

    final weton = Weton.of(date);
    m['weekday'] = _weekdays[weton.weekday.index];
    m['weton'] = '${weton.weekday.label} ${weton.pasaran.label}';
    m['neptu'] = '${weton.neptu}';
    if (JavaneseDate.supports(date)) {
      final j = JavaneseDate.of(date);
      m['javanese'] = '${j.day} ${j.month.label} ${j.year} ${j.taun.label}';
    }
    if (HijriDate.supports(date)) {
      final h = HijriDate.of(date);
      m['hijri'] = '${h.day} ${_words.hijriMonth(h.month)} ${h.year}';
    }
    if (ChineseDate.supports(date)) {
      final c = ChineseDate.of(date);
      m['chinese'] = '${_words.chinese(c)} ${_words.zodiac(c)}';
      m['chinese_day_element'] = _words.dayElement(date);
    }
    // The four pillars of the moment, read from the clock (as the bazi
    // utility does with no longitude given).
    final chart = BaziChart.at(utc, utcOffset: utcOffset);
    m['bazi'] =
        '${chart.year.hanzi} ${chart.month.hanzi} '
        '${chart.day.hanzi} ${chart.hour.hanzi} '
        '(${chart.year} · ${chart.month} · ${chart.day} · ${chart.hour})';
    if (PranataMangsa.supports(date)) {
      final p = PranataMangsa.of(date);
      m['mangsa'] =
          '${p.mangsa.label}, day ${p.day} of ${p.length}, year ${p.year}';
    }
    final face = SkyNow.moonFace(utc);
    m['moon_phase'] = Moon.of(date, utcOffset: utcOffset).phase.label;
    m['moon_illumination'] = '${(face.illumination * 100).toStringAsFixed(1)}%';
    m['moon_elongation'] = '${face.elongation.toStringAsFixed(2)}°';
    m['sun_longitude'] =
        '${Sun.apparentLongitudeAt(Sun.julianDayOf(utc)).toStringAsFixed(3)}°';
    // The planet the weekday is named for (by the date; the planetary
    // hours' own day turns at sunrise).
    m['weekday_planet'] = _words.planetName(
      PlanetaryHours.rulerOf(weton.weekday),
    );

    if (geotag != null) {
      m['geotag'] = 'on';
      final hour = PlanetaryHours.at(
        utc,
        latitude: geotag.latitude,
        longitude: geotag.longitude,
        offsetOn: (_) => utcOffset,
      );
      if (hour != null) {
        m['planetary_hour'] =
            '${_words.planetName(hour.ruler)}, '
            '${hour.day ? 'day' : 'night'} hour ${hour.number}';
      }
      final sun = SkyNow.sun(
        utc,
        latitude: geotag.latitude,
        longitude: geotag.longitude,
      );
      final moon = SkyNow.moon(
        utc,
        latitude: geotag.latitude,
        longitude: geotag.longitude,
      );
      m['sun'] =
          '${sun.altitude.toStringAsFixed(1)}° up, '
          '${sun.azimuth.toStringAsFixed(1)}° bearing';
      m['light'] = _words.lightBand(LightBand.of(sun.trueAltitude));
      m['moon'] =
          '${moon.altitude.toStringAsFixed(1)}° up, '
          '${moon.azimuth.toStringAsFixed(1)}° bearing';
      final planets = [
        for (final body in Planets.all)
          if (SkyNow.planet(
                body,
                utc,
                latitude: geotag.latitude,
                longitude: geotag.longitude,
              ).altitude >
              0)
            _words.planetName(body),
      ];
      m['planets_up'] = planets.isEmpty ? 'none' : planets.join(', ');
    } else {
      m['geotag'] = 'off';
    }
    m['nonce'] = [for (var k = 0; k < 8; k++) _random.nextInt(256)]
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    m['id'] = idOf(m);
    return m;
  }

  /// The id of a record: the first 32 hex digits of the SHA-256 of its
  /// lines but the id itself, `key: value` (null written `null`), one
  /// to a line, in the order written.
  static String idOf(Map<String, String?> record) {
    final text = [
      for (final MapEntry(:key, :value) in record.entries)
        if (key != 'id') '$key: ${value ?? 'null'}',
    ].join('\n');
    return sha256.convert(utf8.encode(text)).toString().substring(0, 32);
  }

  /// Whether [record] is as it was written: its id still its hash.
  static bool intact(Map<String, String?> record) =>
      record['id'] != null && record['id'] == idOf(record);
}
