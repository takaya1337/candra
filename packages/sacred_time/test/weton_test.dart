import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  // Publicly documented Gregorian -> weton pairs.
  final references = {
    // Proclamation of Indonesian independence.
    CivilDate(1945, 8, 17): const Weton(Weekday.jumat, Pasaran.legi),
    // First day of Sultan Agung's Javanese calendar (1 Sura 1555).
    CivilDate(1633, 7, 8): const Weton(Weekday.jumat, Pasaran.legi),
    // Birth of Sukarno.
    CivilDate(1901, 6, 6): const Weton(Weekday.kamis, Pasaran.pon),
    // Birth of Suharto.
    CivilDate(1921, 6, 8): const Weton(Weekday.rabu, Pasaran.kliwon),
    // Birth of Joko Widodo.
    CivilDate(1961, 6, 21): const Weton(Weekday.rabu, Pasaran.pon),
  };

  references.forEach((date, weton) {
    test('$date is $weton', () {
      expect(Weton.of(date), weton);
    });
  });

  test('pasaran advances one step per day and wraps after Kliwon', () {
    var date = CivilDate(1945, 8, 17);
    for (final expected in [...Pasaran.values, Pasaran.legi]) {
      expect(Pasaran.of(date), expected);
      date = date.addDays(1);
    }
  });

  test('a weton recurs every 35 days and not before', () {
    final start = CivilDate(2026, 1, 1);
    final weton = Weton.of(start);
    for (var offset = 1; offset < 35; offset++) {
      expect(Weton.of(start.addDays(offset)), isNot(weton));
    }
    expect(Weton.of(start.addDays(35)), weton);
  });

  test('neptu is weekday plus pasaran', () {
    expect(const Weton(Weekday.jumat, Pasaran.legi).neptu, 11);
    expect(const Weton(Weekday.sabtu, Pasaran.pahing).neptu, 18);
    expect(const Weton(Weekday.selasa, Pasaran.wage).neptu, 7);
  });
}
