import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  ChineseDate chinese(int y, int m, int d) =>
      ChineseDate.of(CivilDate(y, m, d));

  group('Imlek (1 Cia Gwee)', () {
    final newYears = {
      CivilDate(1985, 2, 20): (2536, Shio.kerbau, Unsur.kayu),
      CivilDate(2000, 2, 5): (2551, Shio.naga, Unsur.logam),
      CivilDate(2020, 1, 25): (2571, Shio.tikus, Unsur.logam),
      CivilDate(2023, 1, 22): (2574, Shio.kelinci, Unsur.air),
      CivilDate(2024, 2, 10): (2575, Shio.naga, Unsur.kayu),
      CivilDate(2025, 1, 29): (2576, Shio.ular, Unsur.kayu),
      CivilDate(2026, 2, 17): (2577, Shio.kuda, Unsur.api),
      CivilDate(2027, 2, 6): (2578, Shio.kambing, Unsur.api),
    };

    newYears.forEach((date, expected) {
      final (kongzili, shio, unsur) = expected;
      test('$date opens $kongzili Kongzili, ${shio.label} ${unsur.label}', () {
        final result = ChineseDate.of(date);
        expect(result.toString(), '1 Cia Gwee $kongzili');
        expect(result.shio, shio);
        expect(result.unsur, unsur);
        expect(ChineseDate.of(date.addDays(-1)).kongziliYear, kongzili - 1);
        expect(ChineseDate.of(date.addDays(-1)).month, 12);
      });
    });
  });

  test('festivals', () {
    // Cap Go Meh.
    expect('${chinese(2026, 3, 3)}', '15 Cia Gwee 2577');
    // Peh Cun.
    expect('${chinese(2025, 5, 31)}', '5 Go Gwee 2576');
    // Mid-autumn.
    expect('${chinese(2025, 10, 6)}', '15 Pe Gwee 2576');
    expect('${chinese(2026, 9, 25)}', '15 Pe Gwee 2577');
  });

  test('leap months', () {
    expect('${chinese(2020, 5, 23)}', '1 Lun Si Gwee 2571');
    expect('${chinese(2023, 3, 22)}', '1 Lun Ji Gwee 2574');
    expect('${chinese(2025, 7, 25)}', '1 Lun Lak Gwee 2576');
    expect('${chinese(2025, 7, 24)}', '30 Lak Gwee 2576');
    expect('${chinese(2025, 8, 23)}', '1 Cit Gwee 2576');
    // The rare leap eleventh month of 2033.
    expect('${chinese(2033, 12, 22)}', '1 Lun Cap It Gwee 2584');
    expect(chinese(2026, 6, 15).isLeapMonth, isFalse);
  });

  test('every day advances the date by exactly one step', () {
    var previous = ChineseDate.of(ChineseDate.firstSupported);
    expect('$previous', '1 Cia Gwee 2452');
    for (
      var date = ChineseDate.firstSupported.addDays(1);
      date.compareTo(ChineseDate.lastSupported) <= 0;
      date = date.addDays(1)
    ) {
      final current = ChineseDate.of(date);
      if (current.day != 1) {
        expect(current.day, previous.day + 1, reason: '$date');
        expect(current.month, previous.month);
        expect(current.isLeapMonth, previous.isLeapMonth);
        expect(current.year, previous.year);
      } else {
        expect(previous.day, anyOf(29, 30), reason: '$date');
        if (current.isLeapMonth) {
          expect(current.month, previous.month);
          expect(previous.isLeapMonth, isFalse);
        } else if (current.month == 1) {
          expect(previous.month, 12);
          expect(current.year, previous.year + 1);
        } else {
          expect(current.month, previous.month + 1);
        }
      }
      previous = current;
    }
  });

  test('rejects dates outside the table', () {
    expect(ChineseDate.firstSupported, CivilDate(1901, 2, 19));
    expect(ChineseDate.lastSupported, CivilDate(2100, 2, 8));
    expect(ChineseDate.supports(CivilDate(1901, 2, 18)), isFalse);
    expect(ChineseDate.supports(CivilDate(2100, 2, 9)), isFalse);
    expect(() => ChineseDate.of(CivilDate(2100, 2, 9)), throwsArgumentError);
  });

  test('the element of the day follows the sixty-day cycle', () {
    // 1 October 1949 was jiazi, the first day of the sixty: wood.
    expect(ChineseDate.dayUnsur(CivilDate(1949, 10, 1)), Unsur.kayu);
    // 1 January 2000 was wuwu: the stem wu is earth.
    expect(ChineseDate.dayUnsur(CivilDate(2000, 1, 1)), Unsur.tanah);
    // Two days each, in the order wood, fire, earth, metal, water.
    final start = CivilDate(1949, 10, 1);
    expect(
      [for (var i = 0; i < 12; i++) ChineseDate.dayUnsur(start.addDays(i))],
      [
        Unsur.kayu,
        Unsur.kayu,
        Unsur.api,
        Unsur.api,
        Unsur.tanah,
        Unsur.tanah,
        Unsur.logam,
        Unsur.logam,
        Unsur.air,
        Unsur.air,
        Unsur.kayu,
        Unsur.kayu,
      ],
    );
  });
}
