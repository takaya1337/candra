import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  test('day number matches published Julian Day Numbers', () {
    expect(CivilDate(2000, 1, 1).dayNumber, 2451545);
    expect(CivilDate(1970, 1, 1).dayNumber, 2440588);
    expect(CivilDate(1858, 11, 17).dayNumber, 2400001);
  });

  test('day number round-trips for every day from 1600 to 2200', () {
    final start = CivilDate(1600, 1, 1).dayNumber;
    final end = CivilDate(2200, 12, 31).dayNumber;
    var previous = CivilDate.fromDayNumber(start - 1);
    for (var n = start; n <= end; n++) {
      final date = CivilDate.fromDayNumber(n);
      expect(date.dayNumber, n);
      expect(date.compareTo(previous), 1);
      previous = date;
    }
  });

  test('leap years', () {
    expect(CivilDate.daysInMonth(2024, 2), 29);
    expect(CivilDate.daysInMonth(2026, 2), 28);
    expect(CivilDate.daysInMonth(1900, 2), 28);
    expect(CivilDate.daysInMonth(2000, 2), 29);
  });

  test('rejects dates that do not exist', () {
    expect(() => CivilDate(2026, 2, 29), throwsArgumentError);
    expect(() => CivilDate(2026, 13, 1), throwsArgumentError);
    expect(() => CivilDate(2026, 4, 31), throwsArgumentError);
  });

  test('fromDateTime uses the wall-clock date', () {
    expect(
      CivilDate.fromDateTime(DateTime(2026, 10, 11, 23, 59)),
      CivilDate(2026, 10, 11),
    );
  });
}
