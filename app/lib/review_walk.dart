import 'package:flutter/widgets.dart';

import 'app_shell.dart';
import 'calendar_system.dart';
import 'practice/practice.dart';
import 'sigil.dart';
import 'tour.dart';

/// The walk App Review asked to see recorded (Guideline 2.1, 23 October
/// 2026): only a build made with `--dart-define=REVIEW=1` does it. It
/// opens on the sigil, then goes through what people use, at a pace a
/// person would, touching the app as [Tour] does, while the Mac records
/// the phone's screen (`app/tool/review_recording.sh`). Nothing is saved:
/// an entry is read, a new one begun and let go, the practice discarded.
abstract final class ReviewWalk {
  static const enabled = String.fromEnvironment('REVIEW') != '';

  static Future<void> _wait(double seconds) =>
      Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));

  /// Walks the app. Called once, after the first frame.
  static Future<void> run(BuildContext Function() context) async {
    // The sigil draws itself, then gives way.
    while (SigilOpening.showing.value) {
      await _wait(0.25);
    }
    await _wait(3);

    Future<void> back() async {
      await Tour.back(context());
      await _wait(1.5);
    }

    Future<void> touch(String key, [double look = 2.5]) async {
      await Tour.key(key);
      await _wait(look);
    }

    // The calendar: the day whole, then the month and the year.
    await touch('expand-reading', 4);
    await back();
    await touch('zoom-button', 3);
    await touch('zoom-button', 3);
    await touch('zoom-button', 2);

    // Another calendar from the five cards, and its tools.
    Future<void> calendar(CalendarSystem system) async {
      await touch('system-label', 1.5);
      SystemScope.of(context()).value = system;
      await _wait(1.5);
      await touch('picker-done', 2);
    }

    Future<void> utility(String name, [double look = 5]) async {
      await touch('utilities-button', 2);
      await Tour.reveal('utility-$name');
      await _wait(look);
      await back();
      await back();
    }

    await calendar(CalendarSystem.hijri);
    await utility('salat');
    await calendar(CalendarSystem.chinese);
    await utility('bazi');
    await calendar(CalendarSystem.javanese);
    await utility('mangsa');
    await calendar(CalendarSystem.gregorian);
    await utility('stars', 6);

    // The journal: a new entry begun and let go, then the search, which
    // finds the entries there are.
    await touch('journal-button', 3);
    await touch('new-entry', 2.5);
    await Tour.keyboardAway();
    await _wait(1.5);
    await back();
    await touch('journal-search', 4);
    await back();

    // A reminder.
    await touch('reminder-button', 3);
    await Tour.tile(
      'reminder-',
      but: const ['reminder-toggle-', 'reminder-time-'],
    );
    await _wait(3.5);
    await back();

    // The practice, started and thrown away.
    await touch('practice-button', 2);
    await touch('practice-start', 5);
    PracticeTimer.discard();
    await _wait(2);

    // The menu: the manual, the privacy policy, and the sigil again.
    await touch('menu-button', 2.5);
    await touch('menu-manual', 3);
    await Tour.reveal('manual-row-colours');
    await _wait(5);
    await back();
    await back();
    await Tour.reveal('menu-privacy');
    await _wait(3.5);
    await back();
    await touch('menu-about', 16);
    debugPrint('candra-review: done');
  }
}
