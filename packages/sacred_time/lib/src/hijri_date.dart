import 'civil_date.dart';

/// The twelve months of the Islamic year, in Indonesian spelling.
enum HijriMonth {
  muharam('Muharam'),
  safar('Safar'),
  rabiulawal('Rabiulawal'),
  rabiulakhir('Rabiulakhir'),
  jumadilawal('Jumadilawal'),
  jumadilakhir('Jumadilakhir'),
  rajab('Rajab'),
  syakban('Syakban'),
  ramadan('Ramadan'),
  syawal('Syawal'),
  zulkaidah('Zulkaidah'),
  zulhijah('Zulhijah');

  final String label;

  const HijriMonth(this.label);
}

/// A date in the tabular (arithmetic) Islamic calendar.
///
/// This is a fixed rule, not an observation: months alternate 30 and 29
/// days, and 11 years in every 30 add a day to Zulhijah (years 2, 5, 7, 10,
/// 13, 16, 18, 21, 24, 26 and 29 of the cycle). It counts from Friday
/// 16 July AD 622 (Julian). Dates announced from moon sighting, including
/// Indonesia's official ones, can differ from it by a day either way.
///
/// Here the day turns at civil midnight, as every [CivilDate] does; by
/// tradition the Islamic day begins at sunset, the evening before.
class HijriDate {
  final int year;
  final HijriMonth month;
  final int day;

  const HijriDate._(this.year, this.month, this.day);

  // Day number of 1 Muharam 1 H.
  static const _epoch = 1948440;
  static const _daysPerCycle = 10631;

  static final CivilDate firstSupported = CivilDate.fromDayNumber(_epoch);

  static bool supports(CivilDate date) => date.dayNumber >= _epoch;

  factory HijriDate.of(CivilDate date) {
    if (!supports(date)) {
      throw ArgumentError.value(date, 'date', 'before 1 Muharam 1 H');
    }
    final days = date.dayNumber - _epoch;
    var year = (30 * days + 10646) ~/ _daysPerCycle;
    var remaining = date.dayNumber - _newYear(year);

    for (final month in HijriMonth.values) {
      final length = daysInMonth(year, month);
      if (remaining < length) return HijriDate._(year, month, remaining + 1);
      remaining -= length;
    }
    throw StateError('unreachable: $date');
  }

  static int _newYear(int year) =>
      _epoch + (year - 1) * 354 + (3 + 11 * year) ~/ 30;

  static bool isLeapYear(int year) => (11 * year + 14) % 30 < 11;

  /// Months alternate 30 and 29 days; Zulhijah has 30 in a leap year.
  static int daysInMonth(int year, HijriMonth month) {
    if (month == HijriMonth.zulhijah) return isLeapYear(year) ? 30 : 29;
    return month.index.isEven ? 30 : 29;
  }

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$day ${month.label} $year H';
}
