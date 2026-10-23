import 'package:sacred_time/sacred_time.dart';

/// The calendrical system the month grid is currently read through.
/// Its names and date wording live in `Strings`.
enum CalendarSystem {
  weton,
  javanese,
  chinese,
  hijri,
  gregorian;

  CalendarSystem get next => values[(index + 1) % values.length];

  /// The small line under the day number in a grid cell. A pasaran name or
  /// a day of the month, so it reads the same in every language.
  String? cellLabel(CivilDate date) => switch (this) {
    weton => Pasaran.of(date).label,
    javanese =>
      JavaneseDate.supports(date) ? '${JavaneseDate.of(date).day}' : null,
    chinese =>
      ChineseDate.supports(date) ? '${ChineseDate.of(date).day}' : null,
    hijri => HijriDate.supports(date) ? '${HijriDate.of(date).day}' : null,
    gregorian => null,
  };
}
