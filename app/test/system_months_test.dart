import 'package:candra/calendar_system.dart';
import 'package:candra/strings.dart';
import 'package:candra/system_months.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  group('a system\'s own months', () {
    for (final system in CalendarSystem.values) {
      test('${system.name}: every day\'s page is the month it falls in, and '
          'its months follow on without a gap', () {
        final calendar = SystemCalendar.of(system);
        final (from, to) = switch (system) {
          CalendarSystem.chinese => (
            CivilDate(1901, 3, 1),
            CivilDate(2099, 11, 1),
          ),
          CalendarSystem.javanese => (
            CivilDate(1936, 4, 1),
            CivilDate(2051, 12, 1),
          ),
          CalendarSystem.hijri => (CivilDate(700, 1, 1), CivilDate(2300, 1, 1)),
          _ => (CivilDate(1900, 1, 1), CivilDate(2100, 1, 1)),
        };
        // Every fifth day across the range.
        var previous = -1;
        for (var n = from.dayNumber; n <= to.dayNumber; n += 5) {
          final date = CivilDate.fromDayNumber(n);
          final page = calendar.pageOf(date);
          final month = calendar.monthAt(page);
          expect(month.contains(date), isTrue, reason: '$date on page $page');
          expect(calendar.dayOf(month.first), 1, reason: '$date');
          expect(page >= previous, isTrue);
          if (page > previous && previous >= 0) {
            // The month before ends the day before this one begins.
            expect(
              calendar.monthAt(page - 1).last.addDays(1),
              month.first,
              reason: 'page $page',
            );
          }
          previous = page;
        }
      });
    }

    test('today, 21 October 2026, in the Chinese calendar: the 12th of Kau '
        'Gwee, in a year of twelve or thirteen months', () {
      final calendar = SystemCalendar.of(CalendarSystem.chinese);
      final today = CivilDate(2026, 10, 21);
      expect(calendar.dayOf(today), 12);
      final page = calendar.pageOf(today);
      expect(
        calendar.monthName(calendar.monthAt(page), Strings(AppLanguage.en)),
        'Kau Gwee',
      );
      final year = calendar.yearOfPage(page);
      expect(calendar.pagesOfYear(year).length, anyOf(12, 13));
      expect(calendar.pageOfYearMonth(year, calendar.indexInYear(page)), page);
    });

    test('Hijri and Javanese years have twelve months', () {
      for (final system in [CalendarSystem.hijri, CalendarSystem.javanese]) {
        final calendar = SystemCalendar.of(system);
        final year = calendar.yearOf(CivilDate(2026, 10, 21));
        expect(calendar.pagesOfYear(year), hasLength(12), reason: system.name);
      }
    });
  });
}
