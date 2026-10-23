import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  String javanese(int y, int m, int d) =>
      JavaneseDate.of(CivilDate(y, m, d)).toString();

  group('published reference dates', () {
    test('kurup Asapon opens on 24 March 1936, Selasa Pon', () {
      expect(javanese(1936, 3, 24), '1 Sura 1867 Alip');
      expect(
        Weton.of(CivilDate(1936, 3, 24)),
        const Weton(Weekday.selasa, Pasaran.pon),
      );
    });

    test('kurup Asapon closes on 25 August 2052', () {
      expect(JavaneseDate.lastSupported, CivilDate(2052, 8, 25));
      expect(javanese(2052, 8, 25), '29 Besar 1986 Jimakir');
    });

    test('the day after Asapon is Senin Pahing, the next kurup\'s name', () {
      expect(
        Weton.of(JavaneseDate.lastSupported.addDays(1)),
        const Weton(Weekday.senin, Pasaran.pahing),
      );
    });

    // Keraton Yogyakarta observed malam 1 Sura Dal 1959 on the night of
    // Thursday 26 June 2025.
    test('1 Sura 1959 Dal is 27 June 2025', () {
      expect(javanese(2025, 6, 27), '1 Sura 1959 Dal');
      expect(javanese(2025, 6, 26), '29 Besar 1958 Je');
    });

    test('recent new years', () {
      expect(javanese(2023, 7, 20), '1 Sura 1957 Jimawal');
      expect(javanese(2024, 7, 8), '1 Sura 1958 Je');
    });

    // Calendar-mode example from F. Beauducel's weton.m documentation.
    test('dates from an independent implementation', () {
      expect(javanese(1994, 4, 1), '19 Sawal 1926 Je');
      expect(javanese(1994, 4, 30), '19 Dulkangidah 1926 Je');
    });

    // Garebeg Mulud of the Dal year, on the Mawlid public holiday.
    test('12 Mulud 1959 Dal is 5 September 2025', () {
      expect(javanese(2025, 9, 5), '12 Mulud 1959 Dal');
    });
  });

  test('1 Sura falls on the Asapon weton for every year of the kurup', () {
    const newYearWeton = {
      Taun.alip: Weton(Weekday.selasa, Pasaran.pon),
      Taun.ehe: Weton(Weekday.sabtu, Pasaran.pahing),
      Taun.jimawal: Weton(Weekday.kamis, Pasaran.pahing),
      Taun.je: Weton(Weekday.senin, Pasaran.legi),
      Taun.dal: Weton(Weekday.jumat, Pasaran.kliwon),
      Taun.be: Weton(Weekday.rabu, Pasaran.kliwon),
      Taun.wawu: Weton(Weekday.minggu, Pasaran.wage),
      Taun.jimakir: Weton(Weekday.kamis, Pasaran.pon),
    };
    var newYears = 0;
    for (
      var date = JavaneseDate.firstSupported;
      date.compareTo(JavaneseDate.lastSupported) <= 0;
      date = date.addDays(1)
    ) {
      final javaneseDate = JavaneseDate.of(date);
      if (javaneseDate.month == JavaneseMonth.sura && javaneseDate.day == 1) {
        expect(
          Weton.of(date),
          newYearWeton[javaneseDate.taun],
          reason: '$date',
        );
        newYears++;
      }
    }
    expect(newYears, 120);
  });

  test('every day advances the date by exactly one step', () {
    var previous = JavaneseDate.of(JavaneseDate.firstSupported);
    for (
      var date = JavaneseDate.firstSupported.addDays(1);
      date.compareTo(JavaneseDate.lastSupported) <= 0;
      date = date.addDays(1)
    ) {
      final current = JavaneseDate.of(date);
      if (current.day != 1) {
        expect(current.day, previous.day + 1);
        expect(current.month, previous.month);
        expect(current.year, previous.year);
      } else if (current.month != JavaneseMonth.sura) {
        expect(current.month.index, previous.month.index + 1);
        expect(current.year, previous.year);
        expect(previous.day, anyOf(29, 30));
      } else {
        expect(previous.month, JavaneseMonth.besar);
        expect(current.year, previous.year + 1);
      }
      previous = current;
    }
  });

  test('rejects dates outside kurup Asapon', () {
    expect(JavaneseDate.supports(CivilDate(1936, 3, 23)), isFalse);
    expect(JavaneseDate.supports(CivilDate(2052, 8, 26)), isFalse);
    expect(() => JavaneseDate.of(CivilDate(1936, 3, 23)), throwsArgumentError);
    expect(() => JavaneseDate.of(CivilDate(2052, 8, 26)), throwsArgumentError);
  });
}
