import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  governmentDates();
  String hijri(int y, int m, int d) =>
      HijriDate.of(CivilDate(y, m, d)).toString();

  test('the calendar counts from Friday 16 July 622 (Julian)', () {
    // 19 July 622 in the proleptic Gregorian calendar.
    expect(HijriDate.firstSupported, CivilDate(622, 7, 19));
    expect(hijri(622, 7, 19), '1 Muharam 1 H');
    expect(Weekday.of(HijriDate.firstSupported), Weekday.jumat);
    expect(HijriDate.supports(CivilDate(622, 7, 18)), isFalse);
    expect(() => HijriDate.of(CivilDate(622, 7, 18)), throwsArgumentError);
  });

  test('published tabular conversions', () {
    expect(hijri(1979, 11, 21), '1 Muharam 1400 H');
    expect(hijri(2000, 1, 1), '24 Ramadan 1420 H');
    expect(hijri(2000, 4, 6), '1 Muharam 1421 H');
    expect(hijri(2023, 7, 19), '1 Muharam 1445 H');
    expect(hijri(2025, 6, 27), '1 Muharam 1447 H');
  });

  test('eleven leap years in every thirty', () {
    final leap = [
      for (var year = 1; year <= 30; year++)
        if (HijriDate.isLeapYear(year)) year,
    ];
    expect(leap, [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]);
    expect(HijriDate.isLeapYear(1447), HijriDate.isLeapYear(1447 - 30));
  });

  test('a thirty-year cycle is 10,631 days', () {
    final start = CivilDate(1979, 11, 21);
    expect('${HijriDate.of(start.addDays(10631))}', '1 Muharam 1430 H');
  });

  test('every day advances the date by exactly one step', () {
    var previous = HijriDate.of(CivilDate(1900, 1, 1));
    for (
      var date = CivilDate(1900, 1, 2);
      date.year <= 2100;
      date = date.addDays(1)
    ) {
      final current = HijriDate.of(date);
      if (current.day != 1) {
        expect(current.day, previous.day + 1, reason: '$date');
        expect(current.month, previous.month);
        expect(current.year, previous.year);
      } else if (current.month != HijriMonth.muharam) {
        expect(current.month.index, previous.month.index + 1);
        expect(
          previous.day,
          HijriDate.daysInMonth(previous.year, previous.month),
        );
      } else {
        expect(previous.month, HijriMonth.zulhijah);
        expect(current.year, previous.year + 1);
        expect(previous.day, HijriDate.isLeapYear(previous.year) ? 30 : 29);
      }
      previous = current;
    }
  });

  // Both are tabular Islamic lunar calendars, so across kurup Asapon the
  // Javanese day of the month never strays more than a day from the Hijri.
  test('stays within a day of the Javanese calendar', () {
    for (
      var date = JavaneseDate.firstSupported;
      date.compareTo(JavaneseDate.lastSupported) <= 0;
      date = date.addDays(1)
    ) {
      final javanese = JavaneseDate.of(date);
      // A 30th has no counterpart when the other calendar's month has 29.
      if (javanese.day == 30) continue;
      final match = [-1, 0, 1].any((shift) {
        final hijri = HijriDate.of(date.addDays(shift));
        return hijri.day == javanese.day &&
            hijri.month.index == javanese.month.index;
      });
      expect(match, isTrue, reason: '$date');
    }
  });
}

// The dates Indonesia's government set, by the rulings of the Ministry of
// Religious Affairs (sidang isbat, for Ramadan, Syawal and Zulhijah) and
// by the joint ministerial decrees on national holidays (for the rest),
// each as reported at the time; see docs/hijri-calendar-notes.md. They
// are here to measure how far the tabular calendar is from them, not as
// something it is meant to reproduce.
const _government = [
  (2023, 2, 18, 1444, HijriMonth.rajab, 27),
  (2023, 3, 23, 1444, HijriMonth.ramadan, 1),
  (2023, 4, 22, 1444, HijriMonth.syawal, 1),
  (2023, 6, 29, 1444, HijriMonth.zulhijah, 10),
  (2023, 7, 19, 1445, HijriMonth.muharam, 1),
  (2023, 9, 28, 1445, HijriMonth.rabiulawal, 12),
  (2024, 2, 8, 1445, HijriMonth.rajab, 27),
  (2024, 3, 12, 1445, HijriMonth.ramadan, 1),
  (2024, 4, 10, 1445, HijriMonth.syawal, 1),
  (2024, 6, 17, 1445, HijriMonth.zulhijah, 10),
  (2024, 7, 7, 1446, HijriMonth.muharam, 1),
  (2024, 9, 16, 1446, HijriMonth.rabiulawal, 12),
  (2025, 1, 27, 1446, HijriMonth.rajab, 27),
  (2025, 3, 1, 1446, HijriMonth.ramadan, 1),
  (2025, 3, 31, 1446, HijriMonth.syawal, 1),
  (2025, 6, 6, 1446, HijriMonth.zulhijah, 10),
  (2025, 6, 27, 1447, HijriMonth.muharam, 1),
  (2025, 9, 5, 1447, HijriMonth.rabiulawal, 12),
  (2026, 1, 16, 1447, HijriMonth.rajab, 27),
  (2026, 2, 19, 1447, HijriMonth.ramadan, 1),
  (2026, 3, 21, 1447, HijriMonth.syawal, 1),
  (2026, 5, 27, 1447, HijriMonth.zulhijah, 10),
  (2026, 6, 16, 1448, HijriMonth.muharam, 1),
  (2026, 8, 25, 1448, HijriMonth.rabiulawal, 12),
];

void governmentDates() {
  group('against the dates Indonesia\'s government set, 2023 to 2026', () {
    test('agrees on 15 of 24, and is never more than a day away', () {
      var same = 0;
      for (final (y, m, d, year, month, day) in _government) {
        final civil = CivilDate(y, m, d);
        final ours = HijriDate.of(civil);
        if (ours.year == year && ours.month == month && ours.day == day) {
          same++;
          continue;
        }
        // The government's date is the day before ours or the day after.
        final near = [
          HijriDate.of(civil.addDays(-1)),
          HijriDate.of(civil.addDays(1)),
        ];
        expect(
          near.any((h) => h.year == year && h.month == month && h.day == day),
          isTrue,
          reason: '$civil',
        );
      }
      expect(same, 15);
    });
  });
}
