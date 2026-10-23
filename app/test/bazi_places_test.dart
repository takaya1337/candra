import 'dart:io';

import 'package:candra/bazi/bazi_places.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  final places = BaziPlaces.parse(
    File('assets/bazi/zone_places.v1.json').readAsStringSync(),
  );

  String at(String zone, int year, int month, int day, [int hour = 12]) =>
      BaziPlaces.label(
        BaziPlaces.offsetAt(zone, CivilDate(year, month, day), hour * 60),
      );

  test('Java\'s clock is read as it stood, not as it stands', () {
    // Batavia mean time, then the Indies' own steps, Tokyo's clock under
    // occupation, and the three zones of 1964.
    expect(at('Asia/Jakarta', 1920, 1, 15), '+07:07:12');
    expect(at('Asia/Jakarta', 1930, 1, 15), '+07:20');
    expect(at('Asia/Jakarta', 1940, 1, 15), '+07:30');
    expect(at('Asia/Jakarta', 1943, 6, 15), '+09:00');
    expect(at('Asia/Jakarta', 1949, 1, 15), '+08:00');
    expect(at('Asia/Jakarta', 1960, 1, 15), '+07:30');
    expect(at('Asia/Jakarta', 1970, 1, 15), '+07:00');
    expect(at('Asia/Jakarta', 2026, 10, 12), '+07:00');
  });

  test('summer time and re-zonings elsewhere are known too', () {
    // China kept summer time from 1986 to 1991.
    expect(at('Asia/Shanghai', 1988, 7, 15), '+09:00');
    expect(at('Asia/Shanghai', 1988, 1, 15), '+08:00');
    expect(at('Asia/Taipei', 1975, 7, 15), '+09:00');
    // Singapore went from seven and a half hours to eight in 1982.
    expect(at('Asia/Singapore', 1981, 6, 15), '+07:30');
    expect(at('Asia/Singapore', 1983, 6, 15), '+08:00');
    expect(at('America/New_York', 2026, 7, 4), '−04:00');
  });

  test('every zone has its city\'s longitude, and is filed by region', () {
    expect(places.longitudes['Asia/Jakarta'], 106.8);
    expect(places.longitudes['Asia/Urumqi'], 87.6);
    expect(places.longitudes['Pacific/Honolulu'], -157.9);
    expect(places.longitudes.length, greaterThan(400));
    expect(
      places.regions,
      containsAll(['Africa', 'America', 'Asia', 'Europe']),
    );
    expect(places.regions, isNot(contains('Etc')));
    final asia = places.zonesIn('Asia');
    expect(asia, contains('Asia/Makassar'));
    expect(BaziPlaces.cityOf('Asia/Ho_Chi_Minh'), 'Ho Chi Minh');
    expect(BaziPlaces.cityOf('America/Argentina/Buenos_Aires'), 'Buenos Aires');
    // Every zone on offer is one the database can answer for.
    for (final zone in places.longitudes.keys) {
      BaziPlaces.offsetAt(zone, CivilDate(1950, 1, 1), 0);
    }
  });

  test('a plain offset can be any quarter of an hour', () {
    expect(BaziPlaces.label(BaziPlaces.offsets.first), '−12:00');
    expect(BaziPlaces.label(BaziPlaces.offsets.last), '+14:00');
    expect(BaziPlaces.offsets, contains(const Duration(hours: 5, minutes: 45)));
  });
}
