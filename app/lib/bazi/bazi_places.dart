import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The time zones a chart can be placed in, and what the clocks of each
/// stood at on any date.
///
/// A clock is a political thing and has moved: Jakarta kept seven hours
/// twenty minutes ahead of Greenwich in 1930, seven and a half in 1940
/// and nine in 1943. The offsets come from the whole of the IANA time
/// zone database, with its history, never from today's rule.
class BaziPlaces {
  /// The region a manual offset is listed under, beside the continents.
  static const manual = 'UTC';

  /// Degrees east of the city each zone is named for.
  final Map<String, double> longitudes;

  /// What the table says of itself.
  final String source;

  BaziPlaces._(this.longitudes, this.source);

  static BaziPlaces? _loaded;

  /// The zones, read once.
  static Future<BaziPlaces> load([AssetBundle? bundle]) async =>
      _loaded ??= parse(
        await (bundle ?? rootBundle).loadString(
          'assets/bazi/zone_places.v1.json',
        ),
      );

  static BaziPlaces parse(String zonePlaces) {
    tzdata.initializeTimeZones();
    final table = jsonDecode(zonePlaces) as Map<String, dynamic>;
    return BaziPlaces._({
      for (final entry in (table['longitudes'] as Map<String, dynamic>).entries)
        // Only the zones the database knows the history of.
        if (tz.timeZoneDatabase.locations.containsKey(entry.key))
          entry.key: (entry.value as num).toDouble(),
    }, table['source'] as String);
  }

  bool has(String zone) => longitudes.containsKey(zone);

  /// The continents and oceans the zones are filed under.
  late final List<String> regions = {
    for (final zone in longitudes.keys) regionOf(zone),
  }.toList()..sort();

  /// The zones of [region], by the name of their city.
  List<String> zonesIn(String region) => _byRegion[region] ??= [
    for (final zone in longitudes.keys)
      if (regionOf(zone) == region) zone,
  ]..sort((a, b) => cityOf(a).compareTo(cityOf(b)));

  final _byRegion = <String, List<String>>{};

  static String regionOf(String zone) => zone.substring(0, zone.indexOf('/'));

  /// "Ho Chi Minh" of Asia/Ho_Chi_Minh; "Buenos Aires" of
  /// America/Argentina/Buenos_Aires.
  static String cityOf(String zone) =>
      zone.substring(zone.lastIndexOf('/') + 1).replaceAll('_', ' ');

  /// What the clocks of [zone] stood ahead of Greenwich at the clock
  /// time given there.
  static Duration offsetAt(String zone, CivilDate date, int minuteOfDay) =>
      tz.TZDateTime(
        tz.getLocation(zone),
        date.year,
        date.month,
        date.day,
        minuteOfDay ~/ 60,
        minuteOfDay % 60,
      ).timeZoneOffset;

  static const _channel = MethodChannel('candra/clock');

  /// The zone the phone's own clock is set to, or null if it will not
  /// say.
  static Future<String?> ofPhone() async {
    try {
      return await _channel.invokeMethod<String>('zone');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// The manual offsets on offer: every quarter of an hour from twelve
  /// hours behind Greenwich to fourteen ahead.
  static final offsets = [
    for (var quarters = -48; quarters <= 56; quarters++)
      Duration(minutes: quarters * 15),
  ];

  /// "+07:00"; with the seconds, "+07:07:12", where a clock kept them.
  static String label(Duration offset) {
    String two(int value) => value.toString().padLeft(2, '0');
    final seconds = offset.inSeconds.abs();
    return '${offset.isNegative ? '−' : '+'}${two(seconds ~/ 3600)}:'
        '${two(seconds ~/ 60 % 60)}'
        '${seconds % 60 == 0 ? '' : ':${two(seconds % 60)}'}';
  }
}
