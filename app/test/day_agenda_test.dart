import 'package:candra/day_agenda.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  test('weeks are numbered the ISO way: Monday first, and the first week '
      'is the one with the year\'s first Thursday', () {
    expect(DayAgenda.weekOf(CivilDate(2026, 10, 13)), (week: 42, year: 2026));
    expect(DayAgenda.weekOf(CivilDate(2026, 1, 1)), (week: 1, year: 2026));
    // A Friday: still the last week of the year before.
    expect(DayAgenda.weekOf(CivilDate(2027, 1, 1)), (week: 53, year: 2026));
    // A Monday: already the first week of the year to come.
    expect(DayAgenda.weekOf(CivilDate(2024, 12, 30)), (week: 1, year: 2025));
    expect(DayAgenda.weekOf(CivilDate(2021, 1, 3)), (week: 53, year: 2020));
  });
}
