import 'package:sacred_time/sacred_time.dart';

import '../sky_place.dart';
import 'reminder.dart';

/// The clock time [reminder] falls at on [date]: by the sun at the place
/// set, where it is reckoned by the sun and there is a place; else its
/// own time.
String reminderClock(Reminder reminder, CivilDate date) {
  final minute =
      reminder.minuteOn(
        date,
        place: SkyPlace.current.value,
        utcOffset: DateTime(date.year, date.month, date.day, 12).timeZoneOffset,
      ) ??
      reminder.minuteOfDay;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(minute ~/ 60)}:${two(minute % 60)}';
}
