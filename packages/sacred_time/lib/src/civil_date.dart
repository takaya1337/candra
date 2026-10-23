/// A Gregorian calendar date with no time and no timezone.
///
/// Every converter in this package takes a [CivilDate]. The day turns at
/// local midnight: [CivilDate.fromDateTime] reads the wall-clock fields of
/// the [DateTime] it is given.
class CivilDate implements Comparable<CivilDate> {
  final int year;
  final int month;
  final int day;

  CivilDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be 1..12');
    }
    if (day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError.value(day, 'day', 'not a day of $year-$month');
    }
  }

  factory CivilDate.fromDateTime(DateTime dateTime) =>
      CivilDate(dateTime.year, dateTime.month, dateTime.day);

  /// Inverse of [dayNumber].
  factory CivilDate.fromDayNumber(int dayNumber) {
    final a = dayNumber + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - 146097 * b ~/ 4;
    final d = (4 * c + 3) ~/ 1461;
    final e = c - 1461 * d ~/ 4;
    final m = (5 * e + 2) ~/ 153;
    return CivilDate(
      100 * b + d - 4800 + m ~/ 10,
      m + 3 - 12 * (m ~/ 10),
      e - (153 * m + 2) ~/ 5 + 1,
    );
  }

  /// Julian Day Number: a continuous count of days. All cycle arithmetic
  /// (weekday, pasaran, ...) is a modulo over this.
  int get dayNumber {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  CivilDate addDays(int days) => CivilDate.fromDayNumber(dayNumber + days);

  static bool isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  static int daysInMonth(int year, int month) => switch (month) {
    2 => isLeapYear(year) ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  @override
  int compareTo(CivilDate other) => dayNumber.compareTo(other.dayNumber);

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
