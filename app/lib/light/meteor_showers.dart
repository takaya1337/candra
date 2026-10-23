import 'dart:convert';

import 'package:flutter/services.dart';

/// A meteor shower of the IMO's working list (Meteor Shower Calendar
/// 2027, Table 5; sources in `docs/provenance/light/notes.md`): when it is
/// active, the sun's longitude at its peak (equinox 2000.0), its radiant
/// at the peak, its meteors' speed, the population index and the rate at
/// the zenith in a perfect sky (0 where the rate varies from year to
/// year).
class MeteorShower {
  final String name;
  final String code;
  final (int, int) from;
  final (int, int) to;
  final double longitude;
  final double rightAscension;
  final double declination;
  final int speed;
  final double populationIndex;
  final int zhr;

  const MeteorShower({
    required this.name,
    required this.code,
    required this.from,
    required this.to,
    required this.longitude,
    required this.rightAscension,
    required this.declination,
    required this.speed,
    required this.populationIndex,
    required this.zhr,
  });

  /// Whether it is active on [month], [day] (a span may cross the year).
  bool activeOn(int month, int day) {
    int key((int, int) d) => d.$1 * 100 + d.$2;
    final k = month * 100 + day;
    final a = key(from), b = key(to);
    return a <= b ? k >= a && k <= b : k >= a || k <= b;
  }

  static Future<List<MeteorShower>>? _loading;

  static Future<List<MeteorShower>> load() => _loading ??= rootBundle
      .loadString('assets/stars/meteor_showers.tsv', cache: false)
      .then(parse);

  /// For tests: forget what was read.
  static void reset() => _loading = null;

  static List<MeteorShower> parse(String tsv) {
    (int, int) date(String s) {
      final [m, d] = s.split('-').map(int.parse).toList();
      return (m, d);
    }

    return [
      for (final row in const LineSplitter().convert(tsv).skip(1))
        if (row.split('\t') case [
          final name,
          final code,
          final from,
          final to,
          final longitude,
          final ra,
          final dec,
          final speed,
          final r,
          final zhr,
        ])
          MeteorShower(
            name: name,
            code: code,
            from: date(from),
            to: date(to),
            longitude: double.parse(longitude),
            rightAscension: double.parse(ra),
            declination: double.parse(dec),
            speed: int.parse(speed),
            populationIndex: double.parse(r),
            zhr: int.parse(zhr),
          ),
    ];
  }
}
