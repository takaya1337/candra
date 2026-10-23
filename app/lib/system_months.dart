import 'package:sacred_time/sacred_time.dart';

import 'calendar_system.dart';
import 'strings.dart';

/// One month of a calendar system: its first day and how many days it
/// has.
class SystemMonth {
  final CivilDate first;
  final int length;

  const SystemMonth(this.first, this.length);

  CivilDate get last => first.addDays(length - 1);

  bool contains(CivilDate date) =>
      date.dayNumber >= first.dayNumber &&
      date.dayNumber < first.dayNumber + length;

  @override
  bool operator ==(Object other) =>
      other is SystemMonth && other.first == first && other.length == length;

  @override
  int get hashCode => Object.hash(first, length);
}

/// The calendar as the system chosen counts it (owner, 21 October 2026):
/// in the Chinese, Hijri and Javanese systems the calendar's months and
/// years are theirs, not the Gregorian ones with their days written in.
/// Weton and Gregorian keep the Gregorian months.
///
/// Every month is a page, numbered on from 0, so the calendar leafs
/// through them as it leafs through Gregorian months. The Gregorian page
/// of a month is its year times twelve and its month less one. A lunar
/// system's page counts its months from the first month the engine
/// reads: a lunar month is 29 or 30 days, so a page is found from its
/// number by the mean month and the month that day falls in, and a day's
/// page from the start of its month by the same.
class SystemCalendar {
  final CalendarSystem system;

  SystemCalendar._(this.system);

  static final _made = <CalendarSystem, SystemCalendar>{};

  factory SystemCalendar.of(CalendarSystem system) =>
      _made[system] ??= SystemCalendar._(system);

  /// Whether the calendar counts this system's own months.
  bool get shifts => switch (system) {
    CalendarSystem.chinese ||
    CalendarSystem.hijri ||
    CalendarSystem.javanese => true,
    _ => false,
  };

  // The days the engine reads, for a lunar system.
  CivilDate? get _firstDay => switch (system) {
    CalendarSystem.chinese => ChineseDate.firstSupported,
    CalendarSystem.hijri => HijriDate.firstSupported,
    CalendarSystem.javanese => JavaneseDate.firstSupported,
    _ => null,
  };

  CivilDate? get _lastDay => switch (system) {
    CalendarSystem.chinese => ChineseDate.lastSupported,
    CalendarSystem.javanese => JavaneseDate.lastSupported,
    _ => null,
  };

  // A day the engine reads, nearest to [date].
  CivilDate _within(CivilDate date) {
    final first = _firstDay;
    final last = _lastDay;
    if (first != null && date.dayNumber < first.dayNumber) return first;
    if (last != null && date.dayNumber > last.dayNumber) return last;
    return date;
  }

  // The mean month of each arithmetic: the Hijri's 10631 days in 360
  // months; the Javanese kurup's 15 windu less a day in 1440; the Chinese,
  // the moon's own.
  double get _meanMonth => switch (system) {
    CalendarSystem.hijri => 10631 / 360,
    CalendarSystem.javanese => (15 * 2835 - 1) / 1440,
    _ => 29.530588853,
  };

  /// The day of the month [date] is, in this system.
  int dayOf(CivilDate date) {
    if (!shifts) return date.day;
    final day = _within(date);
    return switch (system) {
      CalendarSystem.chinese => ChineseDate.of(day).day,
      CalendarSystem.hijri => HijriDate.of(day).day,
      _ => JavaneseDate.of(day).day,
    };
  }

  /// The month [date] falls in.
  SystemMonth monthOf(CivilDate date) {
    if (!shifts) {
      return SystemMonth(
        CivilDate(date.year, date.month, 1),
        CivilDate.daysInMonth(date.year, date.month),
      );
    }
    final day = _within(date);
    final first = day.addDays(1 - dayOf(day));
    // Every month of these is 29 or 30 days.
    final after = first.addDays(29);
    final length = _readable(after) && dayOf(after) == 1 ? 29 : 30;
    return SystemMonth(first, length);
  }

  bool _readable(CivilDate date) {
    final last = _lastDay;
    return last == null || date.dayNumber <= last.dayNumber;
  }

  // The first day of the first month read, from which pages are counted.
  late final int _epoch = monthOf(
    _firstDay?.addDays(15) ?? CivilDate(2000, 1, 15),
  ).first.dayNumber;

  /// The page of the month [date] falls in.
  int pageOf(CivilDate date) {
    if (!shifts) return date.year * 12 + date.month - 1;
    final first = monthOf(date).first;
    return ((first.dayNumber - _epoch) / _meanMonth).round();
  }

  /// The month on [page].
  SystemMonth monthAt(int page) {
    if (!shifts) {
      final year = page ~/ 12;
      final month = page % 12 + 1;
      return SystemMonth(
        CivilDate(year, month, 1),
        CivilDate.daysInMonth(year, month),
      );
    }
    // The middle of the month, by the mean month: well inside it.
    return monthOf(
      CivilDate.fromDayNumber((_epoch + page * _meanMonth + 15).round()),
    );
  }

  /// How many pages there are: past the last month read there are none.
  int? get pageCount {
    final last = _lastDay;
    return last == null ? null : pageOf(last) + 1;
  }

  /// How many year pages there are: past the last year read there are
  /// none.
  int? get yearCount {
    final last = _lastDay;
    return last == null ? null : yearOf(last) + 1;
  }

  /// The year [date] falls in, as this system numbers its years.
  int yearOf(CivilDate date) {
    if (!shifts) return date.year;
    final day = _within(date);
    return switch (system) {
      CalendarSystem.chinese => ChineseDate.of(day).year,
      CalendarSystem.hijri => HijriDate.of(day).year,
      _ => JavaneseDate.of(day).year,
    };
  }

  int yearOfPage(int page) => yearOf(monthAt(page).first);

  final _years = <int, List<int>>{};

  /// The pages of the months of [year], in order: twelve, or a Chinese
  /// year's thirteen.
  List<int> pagesOfYear(int year) => _years[year] ??= () {
    if (!shifts) return [for (var m = 0; m < 12; m++) year * 12 + m];
    // A guess by the mean year from the first page, then set right.
    var page = ((year - yearOfPage(0)) * 12.37).round();
    if (page < 0) page = 0;
    while (yearOfPage(page) < year) {
      page++;
    }
    while (page > 0 && yearOfPage(page) > year) {
      page--;
    }
    while (page > 0 && yearOfPage(page - 1) == year) {
      page--;
    }
    final count = pageCount;
    return [
      for (
        var p = page;
        (count == null || p < count) && yearOfPage(p) == year;
        p++
      )
        p,
    ];
  }();

  /// The place of [page]'s month in its year, from 1.
  int indexInYear(int page) => pagesOfYear(yearOfPage(page)).indexOf(page) + 1;

  /// The page of the [index]th month (from 1) of [year], or the nearest
  /// it has.
  int pageOfYearMonth(int year, int index) {
    final pages = pagesOfYear(year);
    return pages[(index - 1).clamp(0, pages.length - 1)];
  }

  /// The month's name, as the calendar's title and the day sheet say it.
  String monthName(SystemMonth month, Strings strings) {
    final day = month.first;
    return switch (system) {
      CalendarSystem.chinese => ChineseDate.of(day).monthLabel,
      CalendarSystem.hijri => strings.hijriMonth(HijriDate.of(day).month),
      CalendarSystem.javanese => JavaneseDate.of(day).month.label,
      _ => strings.monthNames[day.month - 1],
    };
  }

  /// The year's number, as the title says it: the Kongzili year for the
  /// Chinese, the year with AH for the Hijri, with its windu year for the
  /// Javanese.
  String yearName(CivilDate within, Strings strings) => switch (system) {
    CalendarSystem.chinese => '${ChineseDate.of(_within(within)).kongziliYear}',
    CalendarSystem.hijri => strings.hijriYear(HijriDate.of(_within(within))),
    CalendarSystem.javanese => strings.javaneseYear(
      JavaneseDate.of(_within(within)),
    ),
    _ => '${within.year}',
  };

  /// The calendar's title for the month on [page]: its name and year.
  String title(int page, Strings strings) {
    final month = monthAt(page);
    return '${monthName(month, strings)} ${yearName(month.first, strings)}';
  }
}
