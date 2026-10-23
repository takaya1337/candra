import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'app_shell.dart';
import 'calendar_system.dart';
import 'house.dart';
import 'journal/entry.dart';
import 'journal/journal_store.dart';
import 'strings.dart';
import 'tour.dart';

/// The store's screenshots, taken on the phone itself: only a build made
/// with `--dart-define=SHOTS=en` (or `id`) does any of this. It opens in
/// that language, on the day it is run (the phone's status bar shows the
/// date and cannot be changed, so the app shows the same day, and the
/// showcase samples are laid out around it), at a fixed place
/// (Yogyakarta), and walks a short sequence of screens. On
/// each, once it has stopped moving, it puts up an invisible marker in
/// the accessibility tree (`shot-ready-NN-name`) and holds still; the UI
/// test in `ios/RunnerUITests` waits for the marker and takes the
/// phone's own screenshot. `shot-done` ends it.
///
/// Run by `tool/store_screenshots.sh`; see `ios/ios-operations.md`.
abstract final class Shots {
  static const _language = String.fromEnvironment('SHOTS');
  static const enabled = _language != '';

  /// The language the build was asked for.
  static AppLanguage get language =>
      _language == 'id' ? AppLanguage.id : AppLanguage.en;

  /// Yogyakarta, rounded as the app keeps a place.
  static const latitude = -7.8;
  static const longitude = 110.4;

  /// How long each screen is held for the camera.
  static const _hold = Duration(seconds: 8);

  static final _marker = ValueNotifier<String?>(null);
  static SemanticsHandle? _semantics;

  /// Puts the marker over [app]. Does nothing in an ordinary build.
  static Widget wrap(Widget app) => enabled
      ? Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              app,
              Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: ValueListenableBuilder(
                  valueListenable: _marker,
                  builder: (context, name, _) => name == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          container: true,
                          label: name,
                          identifier: name,
                          child: const SizedBox.expand(),
                        ),
                ),
              ),
            ],
          ),
        )
      : app;

  static Future<void> _wait([int milliseconds = 900]) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  // Waits until nothing has been drawn for a while (an animation ended),
  // or [most] has passed, for a screen that never stops moving.
  static Future<void> _settle({int most = 4000}) async {
    final scheduler = SchedulerBinding.instance;
    final started = DateTime.now();
    var still = 0;
    while (still < 600 &&
        DateTime.now().difference(started).inMilliseconds < most) {
      await _wait(100);
      still = scheduler.hasScheduledFrame ? 0 : still + 100;
    }
  }

  static Future<void> _show(String name) async {
    // No keyboard, no focus, nothing moving.
    FocusManager.instance.primaryFocus?.unfocus();
    await _wait(600);
    await _settle();
    _marker.value = 'shot-ready-$name';
    // Android has no UI test to read the marker: the same in the log,
    // for tool/play_screenshots.sh to take the picture by.
    debugPrint('candra-shot: shot-ready-$name');
    await Future<void>.delayed(_hold);
    _marker.value = null;
    await _wait(500);
  }

  /// Walks the screens. Called once, after the first frame.
  static Future<void> run(BuildContext Function() context) async {
    // The accessibility tree is built only for a screen reader, unless
    // asked for; the UI test reads the marker from it.
    _semantics = SemanticsBinding.instance.ensureSemantics();
    await _wait(3000);
    SystemController systems() => SystemScope.of(context());
    Future<void> system(CalendarSystem to) async {
      systems().value = to;
      await _wait();
    }

    Future<void> open(String utility) async {
      await Tour.key('utilities-button');
      await _wait(600);
      await Tour.reveal('utility-$utility');
      await _wait(1500);
    }

    await _show('01-day');
    await Tour.key('zoom-button');
    await _show('02-month');

    await system(CalendarSystem.hijri);
    await open('salat');
    await _show('03-prayer-times');
    // Out of the utility, and its cards let down.
    await Tour.back(context());
    await Tour.back(context());

    await system(CalendarSystem.gregorian);
    await open('stars');
    await _wait(1500);
    await _show('04-sky');
    // Out of the utility, and its cards let down.
    await Tour.back(context());
    await Tour.back(context());

    await system(CalendarSystem.chinese);
    await open('bazi');
    await _show('05-bazi');
    // Out of the utility, and its cards let down.
    await Tour.back(context());
    await Tour.back(context());

    await system(CalendarSystem.gregorian);
    // The journal on the day of the newest entry, with its folder in
    // front, so it shows that writing and the next shot has an entry to
    // open, whatever the hour of the run (22 October 2026: run just after
    // midnight, today's entries are yesterday's; and the Occasion folder,
    // in front by default, has none since the showcase was cut down).
    final entries = JournalScope.of(context()).allEntries();
    Entry? newest;
    if (entries.isNotEmpty) {
      int when(Entry e) => e.date.dayNumber * 1440 + e.minuteOfDay;
      newest = entries.reduce((a, b) => when(a) >= when(b) ? a : b);
      House.maybeOf(context())?.day = newest.date;
    }
    await Tour.key('journal-button');
    await _wait(1200);
    if (newest != null) {
      await Tour.key('pick-${newest.categoryId}');
      await _wait(1200);
    }
    await _show('06-journal');
    await Tour.tile('entry-');
    await _wait(1200);
    await _show('07-entry');
    await Tour.back(context());
    await _wait(1200);

    await Tour.key('journal-search');
    await _wait(1200);
    // One cycle asked for (the first pasaran), so its days are shaded on
    // the year, and the year laid out.
    await Tour.key('search-day-add');
    await Tour.key('search-view');
    await Tour.key('search-view');
    await _wait(1200);
    await _show('08-search-year');
    await Tour.back(context());
    await _wait(1200);

    await Tour.key('reminder-button');
    await _wait(1200);
    await _show('09-reminders');

    _marker.value = 'shot-done';
    debugPrint('candra-shot: shot-done');
    await Future<void>.delayed(const Duration(seconds: 30));
    _marker.value = null;
    _semantics?.dispose();
    _semantics = null;
  }
}
