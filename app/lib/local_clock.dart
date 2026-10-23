import 'package:sacred_time/sacred_time.dart';

/// The wall clock of a day: the phone's own, through its time zone, so a
/// day the clocks change on reads right on both sides of the change; or a
/// fixed offset, where one is given (tests, and anything reckoned for
/// another zone).
///
/// The sky's reckonings take one offset for a day (the one at its noon,
/// [dayOffset]) and work on a grid of that day's minutes. Where the
/// clocks change during the day, a moment before the change stands
/// [shift] minutes from where that grid puts it, and is drawn and read
/// there.
abstract final class LocalClock {
  /// For tests: a time zone in place of the phone's.
  static Duration Function(DateTime instant)? zone;

  /// The offset of the wall clock at [instant]: [fixed] if given.
  static Duration offsetAt(DateTime instant, Duration? fixed) =>
      fixed ?? zone?.call(instant) ?? instant.toLocal().timeZoneOffset;

  /// The offset at [date]'s noon: the one its day is reckoned by.
  static Duration dayOffset(CivilDate date, Duration? fixed) {
    if (fixed != null) return fixed;
    final noon = DateTime.utc(date.year, date.month, date.day, 12);
    return offsetAt(noon.subtract(offsetAt(noon, null)), null);
  }

  /// The instant [minute] minutes into [date] by the wall clock.
  static DateTime instant(CivilDate date, int minute, Duration? fixed) {
    final wall = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: minute));
    if (fixed != null) return wall.subtract(fixed);
    final guess = wall.subtract(dayOffset(date, null));
    return wall.subtract(offsetAt(guess, null));
  }

  /// [at] as the wall clock shows it.
  static DateTime wall(DateTime at, Duration? fixed) =>
      at.toUtc().add(offsetAt(at, fixed));

  /// How many minutes the wall clock at [at] stands from [date]'s own
  /// reckoning: the hour before a change in spring is an hour behind it
  /// (-60), in autumn an hour ahead (+60); otherwise 0.
  static int shift(DateTime at, CivilDate date, Duration? fixed) =>
      fixed != null
      ? 0
      : (offsetAt(at, null) - dayOffset(date, null)).inMinutes;
}
