import 'dart:convert';
import 'dart:io';

import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/adhan/times.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  const methods = {
    'Turkey': SalatMethod.turkey,
    'Qatar': SalatMethod.qatar,
    'Dubai': SalatMethod.dubai,
    'Kuwait': SalatMethod.kuwait,
    'MoonsightingCommittee': SalatMethod.moonsightingCommittee,
    'UmmAlQura': SalatMethod.ummAlQura,
    'Singapore': SalatMethod.singapore,
    'Tehran': SalatMethod.tehran,
  };
  const keys = {
    'fajr': Salat.subuh,
    'sunrise': Salat.terbit,
    'dhuhr': Salat.zuhur,
    'asr': Salat.asar,
    'maghrib': Salat.magrib,
    'isha': Salat.isya,
  };

  for (final set in (fixture['sets'] as List).cast<Map<String, dynamic>>()) {
    test('${set['name']}: within two minutes of the published timetable '
        '(${set['source']})', () {
      var worst = 0;
      var exact = 0, all = 0;
      for (final day in (set['days'] as List).cast<Map<String, dynamic>>()) {
        final [y, m, d] = (day['date'] as String)
            .split('-')
            .map(int.parse)
            .toList();
        final times = SalatTimes.of(
          CivilDate(y, m, d),
          latitude: set['latitude'] as double,
          longitude: set['longitude'] as double,
          utcOffset: Duration(minutes: day['offset'] as int),
          method: methods[set['method']]!,
          madhab: set['madhab'] == 'Hanafi' ? Madhab.hanafi : Madhab.standard,
          highLatitude: HighLatitudeRule.middleOfTheNight,
        );
        for (final MapEntry(:key, :value) in keys.entries) {
          final got = times[value]!;
          final want = day[key] as int;
          final off = (got - want).abs();
          if (off > worst) worst = off;
          if (off == 0) exact++;
          all++;
          expect(off, lessThanOrEqualTo(2), reason: '${day['date']} $key');
        }
      }
      print('${set['name']}: worst $worst min, $exact of $all exact');
    });
  }

  test('Indonesia is told from its neighbours by the place alone', () {
    for (final (lat, lon) in [
      (-6.2, 106.8), // Jakarta
      (-10.2, 123.6), // Kupang
      (1.1, 104.0), // Batam
      (0.0, 109.3), // Pontianak
      (3.3, 117.6), // Tarakan
      (-2.5, 140.7), // Jayapura
      (-8.5, 140.4), // Merauke
      (5.9, 95.3), // Sabang
      (-6.1, 106.6), // the Pixel's place
    ]) {
      expect(Indonesia.has(lat, lon), isTrue, reason: '$lat, $lon');
    }
    for (final (lat, lon) in [
      (-8.6, 125.6), // Dili
      (3.1, 101.7), // Kuala Lumpur
      (1.3, 103.8), // Singapore
      (1.5, 110.3), // Kuching
      (4.2, 117.9), // Tawau
      (-9.4, 147.2), // Port Moresby
      (-12.5, 130.8), // Darwin
      (51.5, -0.1), // London
    ]) {
      expect(Indonesia.has(lat, lon), isFalse, reason: '$lat, $lon');
    }
  });

  test('far north in summer the night rules give Subuh and Isya where the '
      'angles give none', () {
    final helsinki = SalatTimes.of(
      CivilDate(2026, 6, 21),
      latitude: 60.2,
      longitude: 24.9,
      utcOffset: const Duration(hours: 3),
      method: SalatMethod.muslimWorldLeague,
    );
    expect(helsinki[Salat.subuh], isNotNull);
    expect(helsinki[Salat.isya], isNotNull);
    expect(helsinki[Salat.imsak], isNull);
    // A seventh of the night from sunset and before sunrise.
    final night = 1440 - helsinki[Salat.magrib]! + helsinki[Salat.terbit]!;
    expect(
      helsinki[Salat.isya]! - helsinki[Salat.magrib]!,
      closeTo(night / 7, 3),
    );
  });

  test('Hanafi Asar is later than the standard', () {
    SalatTimes at(Madhab madhab) => SalatTimes.of(
      CivilDate(2026, 10, 16),
      latitude: 51.5,
      longitude: -0.1,
      utcOffset: const Duration(hours: 1),
      method: SalatMethod.muslimWorldLeague,
      madhab: madhab,
    );
    expect(
      at(Madhab.hanafi)[Salat.asar]!,
      greaterThan(at(Madhab.standard)[Salat.asar]! + 30),
    );
  });

  test('the suggestions put the region\'s own first', () {
    expect(SalatMethod.suggestedFor(39.9, 32.8).first, SalatMethod.turkey);
    expect(
      SalatMethod.suggestedFor(51.5, -0.1).first,
      SalatMethod.muslimWorldLeague,
    );
    expect(SalatMethod.suggestedFor(21.4, 39.8).first, SalatMethod.ummAlQura);
    expect(SalatMethod.suggestedFor(24.9, 67.0).first, SalatMethod.karachi);
    expect(
      SalatMethod.suggestedFor(40.7, -74.0).first,
      SalatMethod.northAmerica,
    );
    final all = SalatMethod.suggestedFor(0, 0);
    expect(all.toSet().length, SalatMethod.values.length - 1);
    expect(all, isNot(contains(SalatMethod.kemenag)));
  });
}
