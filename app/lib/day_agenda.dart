import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';

import 'day_reading.dart';
import 'reminders/reminder.dart';
import 'reminders/reminder_time.dart';
import 'strings.dart';

/// The lower panel of the day view. The sheet above already names the
/// day in every calendar system, so this keeps to what is general and
/// the sheet does not say: where the day stands in the year and the
/// week, and its reminders, earliest first.
///
/// A tap opens the detailed reading, as it does on the month screen.
class DayAgenda extends StatelessWidget {
  /// How many reminders are listed before the rest are only counted.
  static const maxReminders = 3;

  final CivilDate date;
  final Strings strings;

  /// The day's reminders, earliest first.
  final List<Reminder> reminders;

  /// The colour of the bell opposite the heading; null on a day with no
  /// reminders.
  final Color? bell;
  final VoidCallback? onExpand;

  const DayAgenda({
    super.key,
    required this.date,
    required this.strings,
    this.reminders = const [],
    this.bell,
    this.onExpand,
  });

  /// The ISO week [date] is in, and the year that week belongs to: weeks
  /// start on Monday, and the first is the one with the year's first
  /// Thursday.
  static ({int week, int year}) weekOf(CivilDate date) {
    // Monday is 0.
    final weekday = Weton.of(date).weekday.index;
    final thursday = date.addDays(3 - weekday);
    final first = CivilDate(thursday.year, 1, 1);
    return (
      week: (thursday.dayNumber - first.dayNumber) ~/ 7 + 1,
      year: thursday.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    ReadingPart plain(String text) => (text: text, color: null);

    final dayOfYear = date.dayNumber - CivilDate(date.year, 1, 1).dayNumber + 1;
    final daysInYear =
        CivilDate(date.year + 1, 1, 1).dayNumber -
        CivilDate(date.year, 1, 1).dayNumber;
    final week = weekOf(date);

    return ReadingPanel(
      title: strings.dayOfYear(dayOfYear, daysInYear),
      bell: bell,
      onTap: onExpand,
      lines: [
        (
          label: strings.agendaLeft,
          parts: [plain(strings.daysLeft(daysInYear - dayOfYear))],
          moon: null,
        ),
        (
          label: strings.agendaWeek,
          parts: [plain(strings.weekOfYear(week.week, week.year))],
          moon: null,
        ),
        // Each reminder under its time.
        for (final reminder in reminders.take(maxReminders))
          (
            label: reminderClock(reminder, date),
            parts: [plain(reminder.title)],
            moon: null,
          ),
        if (reminders.length > maxReminders)
          (
            label: '',
            parts: [
              plain(strings.moreReminders(reminders.length - maxReminders)),
            ],
            moon: null,
          ),
      ],
    );
  }
}
