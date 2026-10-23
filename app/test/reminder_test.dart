import 'package:candra/reminders/reminder.dart';
import 'package:candra/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  const offset = Duration(hours: 7);
  // Sunday, Minggu Legi, 28 Bakdamulud 1960, 28 Rabiulakhir 1448,
  // 2 Kau Gwee 2577.
  final start = CivilDate(2026, 10, 11);

  Reminder every(Repeat repeat, [CivilDate? from]) => Reminder(
    id: 'r',
    title: 'Offering',
    start: from ?? start,
    minuteOfDay: 19 * 60 + 30,
    repeat: repeat,
  );

  List<String> next(Repeat repeat, int count, {CivilDate? from}) => [
    for (final date in every(
      repeat,
      from,
    ).occurrences((from ?? start).addDays(1), utcOffset: offset, count: count))
      '$date',
  ];

  test('once falls on its day and never again', () {
    final reminder = every(Repeat.once);
    expect(reminder.occursOn(start, utcOffset: offset), isTrue);
    expect(reminder.occursOn(start.addDays(35), utcOffset: offset), isFalse);
    expect(reminder.occurrences(start, utcOffset: offset, count: 3), [start]);
    expect(reminder.occurrences(start.addDays(1), utcOffset: offset), isEmpty);
  });

  test('nothing falls before its first day', () {
    expect(
      every(Repeat.daily).occursOn(start.addDays(-1), utcOffset: offset),
      isFalse,
    );
    // Asked from earlier, the first is the first day itself.
    expect(
      every(Repeat.weton).occurrences(start.addDays(-100), utcOffset: offset),
      [start],
    );
  });

  test('the day cycles: every day, weekday, pasaran and weton', () {
    expect(next(Repeat.daily, 2), ['2026-10-12', '2026-10-13']);
    expect(next(Repeat.weekday, 2), ['2026-10-18', '2026-10-25']);
    expect(next(Repeat.pasaran, 2), ['2026-10-16', '2026-10-21']);
    expect(next(Repeat.weton, 2), ['2026-11-15', '2026-12-20']);
    // And they are what they claim to be.
    for (final date in every(
      Repeat.weton,
    ).occurrences(start, utcOffset: offset, count: 5)) {
      expect(Weton.of(date), Weton.of(start));
    }
  });

  test('Gregorian: the same day each month, or each year', () {
    expect(next(Repeat.gregorianMonth, 2), ['2026-11-11', '2026-12-11']);
    expect(next(Repeat.gregorianYear, 2), ['2027-10-11', '2028-10-11']);
    // A 31st skips the months that have none.
    expect(next(Repeat.gregorianMonth, 3, from: CivilDate(2026, 1, 31)), [
      '2026-03-31',
      '2026-05-31',
      '2026-07-31',
    ]);
    // 29 February comes only in leap years.
    expect(next(Repeat.gregorianYear, 1, from: CivilDate(2024, 2, 29)), [
      '2028-02-29',
    ]);
  });

  test('Javanese, Hijri and Chinese: the same day each of their months, or '
      'years', () {
    for (final (monthly, yearly, read) in [
      (
        Repeat.javaneseMonth,
        Repeat.javaneseYear,
        (CivilDate d) =>
            (JavaneseDate.of(d).day, JavaneseDate.of(d).month.index),
      ),
      (
        Repeat.hijriMonth,
        Repeat.hijriYear,
        (CivilDate d) => (HijriDate.of(d).day, HijriDate.of(d).month.index),
      ),
      (
        Repeat.chineseMonth,
        Repeat.chineseYear,
        (CivilDate d) => (ChineseDate.of(d).day, ChineseDate.of(d).month),
      ),
    ]) {
      final months = every(monthly)
          .occurrences(start, utcOffset: offset, count: 4);
      expect(months, hasLength(4));
      expect(months.first, start);
      for (final date in months) {
        expect(read(date).$1, read(start).$1);
      }
      // About a lunar month apart.
      expect(
        months[1].dayNumber - months[0].dayNumber,
        inInclusiveRange(29, 30),
      );

      final years = every(yearly)
          .occurrences(start, utcOffset: offset, count: 3, horizon: 1200);
      expect(years, hasLength(3));
      for (final date in years) {
        expect(read(date), read(start));
      }
      // About a lunar year apart (a Chinese year may have a leap month).
      expect(
        years[1].dayNumber - years[0].dayNumber,
        inInclusiveRange(353, 385),
      );
    }
  });

  test('the moon: each time it is at that phase again', () {
    final full = CivilDate(2026, 10, 26);
    expect(Moon.of(full, utcOffset: offset).phase, MoonPhase.fullMoon);
    final moons = every(
      Repeat.moon,
      full,
    ).occurrences(full, utcOffset: offset, count: 4);
    expect(moons, hasLength(4));
    for (var i = 1; i < moons.length; i++) {
      expect(
        moons[i].dayNumber - moons[i - 1].dayNumber,
        inInclusiveRange(29, 30),
      );
      expect(Moon.of(moons[i], utcOffset: offset).phase, MoonPhase.fullMoon);
    }
  });

  test('only the repeats that make sense for the day are offered', () {
    final offered = Reminder.offeredFor(start, utcOffset: offset);
    expect(offered.first, Repeat.once);
    expect(offered, containsAll(Repeat.values.where((r) => r != Repeat.moon)));
    // An ordinary day of the moon has no phase to return to.
    expect(offered, isNot(contains(Repeat.moon)));
    expect(
      Reminder.offeredFor(CivilDate(2026, 10, 26), utcOffset: offset),
      contains(Repeat.moon),
    );
    // The Javanese calendar here does not reach 1900.
    expect(
      Reminder.offeredFor(CivilDate(1900, 1, 1), utcOffset: offset),
      isNot(contains(Repeat.javaneseMonth)),
    );
  });

  test('is written and read back whole', () {
    final reminder = every(Repeat.javaneseYear).copyWith(enabled: false);
    final read = Reminder.fromJson(reminder.toJson())!;
    expect(read.id, 'r');
    expect(read.title, 'Offering');
    expect(read.start, start);
    expect(read.minuteOfDay, 19 * 60 + 30);
    expect(read.repeat, Repeat.javaneseYear);
    expect(read.enabled, isFalse);
    expect(reminder.toJson()['start'], '2026-10-11');
    expect(reminder.toJson()['time'], '19:30');
    expect(Reminder.fromJson({'id': 'x', 'start': 'soon'}), isNull);
  });

  test('by the sun: the moment at the place, so many minutes before', () {
    const yogya = (latitude: -7.8, longitude: 110.4);
    final sunset = every(Repeat.daily)
        .copyWith(sun: SunAnchor.sunset, lead: 20);
    final day = SkyNow.day(
      Body.sun,
      start,
      latitude: yogya.latitude,
      longitude: yogya.longitude,
      utcOffset: offset,
    );
    final set = day.set!.add(offset);
    final minutes = set.hour * 60 + set.minute;
    expect(
      sunset.minuteOn(start, place: yogya, utcOffset: offset),
      inInclusiveRange(minutes - 21, minutes - 19),
    );
    // With no place, no time.
    expect(sunset.minuteOn(start, place: null, utcOffset: offset), isNull);
    // By the clock, the clock.
    expect(
      every(Repeat.daily).minuteOn(start, place: yogya, utcOffset: offset),
      19 * 60 + 30,
    );
    // The evening golden hour begins before sunset, the blue after it.
    final golden = sunset
        .copyWith(sun: SunAnchor.eveningGolden, lead: 0)
        .minuteOn(start, place: yogya, utcOffset: offset)!;
    final blue = sunset
        .copyWith(sun: SunAnchor.eveningBlue, lead: 0)
        .minuteOn(start, place: yogya, utcOffset: offset)!;
    expect(golden, lessThan(minutes));
    expect(blue, greaterThan(minutes));
  });

  test('a sun reminder is written and read back whole; an old one reads '
      'as the clock', () {
    final sunrise = every(Repeat.daily)
        .copyWith(sun: SunAnchor.sunrise, lead: 15);
    final back = Reminder.fromJson(sunrise.toJson())!;
    expect(back.sun, SunAnchor.sunrise);
    expect(back.lead, 15);
    expect(every(Repeat.daily).toJson().containsKey('sun'), isFalse);
    expect(Reminder.fromJson(every(Repeat.daily).toJson())!.bySun, isFalse);
  });

  test('the moon\'s day is read by each day\'s own clock where the clocks '
      'change', () {
    // A full moon an hour or less before midnight in winter time (UTC+1)
    // is after midnight in summer time (UTC+2): find one, over some years.
    final moons = FullMoons.within(DateTime.utc(2026, 1, 1), 365 * 4);
    final late = moons.firstWhere((m) => m.at.hour == 22);
    final first = moons.first.at.add(const Duration(hours: 1));
    final reminder = Reminder(
      id: 'r',
      title: 'Full moon',
      start: CivilDate(first.year, first.month, first.day),
      minuteOfDay: 20 * 60,
      repeat: Repeat.moon,
    );
    final winterDay = late.at.add(const Duration(hours: 1));
    final date = CivilDate(winterDay.year, winterDay.month, winterDay.day);
    // Read by that day's own offset (winter, +1): the full moon's day.
    expect(
      reminder.occursOn(
        date,
        utcOffset: const Duration(hours: 2),
        offsetOn: (_) => const Duration(hours: 1),
      ),
      isTrue,
    );
    // Read by another season's (+2), as before: the next day instead.
    expect(
      reminder.occursOn(date, utcOffset: const Duration(hours: 2)),
      isFalse,
    );
  });

  test('by the planetary hour: the planet\'s first hour from sunrise, '
      'and kept in the file', () {
    // Sunday 18 October 2026 at Jakarta: the sun's hour first, then
    // Venus's.
    final sunday = CivilDate(2026, 10, 18);
    const jakarta = (latitude: -6.2, longitude: 106.8);
    const wib = Duration(hours: 7);
    final reminder = Reminder(
      id: 'p1',
      title: 'Venus',
      start: sunday,
      minuteOfDay: 0,
      repeat: Repeat.daily,
      sun: SunAnchor.planetaryHour,
      planet: Body.venus,
      lead: 5,
    );
    final hours = PlanetaryHours.of(
      sunday,
      latitude: jakarta.latitude,
      longitude: jakarta.longitude,
      utcOffset: wib,
    )!;
    expect(hours[1].ruler, Body.venus);
    final start = hours[1].start.add(wib);
    expect(
      reminder.minuteOn(sunday, place: jakarta, utcOffset: wib),
      start.hour * 60 + start.minute - 5,
    );
    expect(reminder.minuteOn(sunday, place: null, utcOffset: wib), isNull);
    final back = Reminder.fromJson(reminder.toJson())!;
    expect(back.sun, SunAnchor.planetaryHour);
    expect(back.planet, Body.venus);
    expect(back.lead, 5);
    expect(
      const Strings(AppLanguage.en).reminderTimeWords(reminder),
      'Hour of Venus · 5 min before',
    );
  });
}
