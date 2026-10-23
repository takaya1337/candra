import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'app_shell.dart';
import 'calendar_system.dart';
import 'tour.dart';

/// A walk for pictures of the layout as the device itself shows it,
/// keyboard and all: only a build made with `--dart-define=LOOK=1` does
/// any of this. Unlike the store's screenshots (`shots.dart`) it writes
/// nothing, chooses nothing and saves nothing: it opens screens, touches
/// fields so the keyboard comes up, and leaves each by its way back, as
/// the tour does. On each screen to be pictured it puts up an invisible
/// marker in the accessibility tree, `shot-ready-NAME` (one picture) or
/// `shot-burst-NAME` (pictures as fast as they come, while something
/// moves), which the UI test `StoreScreenshots.testLook` in
/// `ios/RunnerUITests` waits for. `shot-done` ends it.
///
/// Used for the iPad upright (19 October 2026); see
/// `ios/ios-operations.md`.
abstract final class Look {
  static const enabled = String.fromEnvironment('LOOK') != '';

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

  // One picture, of the screen as it stands, the keyboard left as it is.
  static Future<void> _show(String name) async {
    await _wait(600);
    await _settle();
    _marker.value = 'shot-ready-$name';
    await _wait(4000);
    _marker.value = null;
    await _wait(500);
  }

  // Pictures as fast as they come while [act] does something that moves.
  static Future<void> _burst(
    String name,
    Future<Object?> Function() act,
  ) async {
    await _settle();
    _marker.value = 'shot-burst-$name';
    // The camera takes about four seconds of pictures: soon after it
    // starts, so that the move is in them.
    await _wait(800);
    await act();
    await _wait(2000);
    _marker.value = null;
    await _wait(1500);
  }

  static Future<void> _away() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _wait(1200);
  }

  // `LOOK=bar`: only the bottom bar and the reminder editor's panel,
  // on a tablet upright the phone's scaled (20 October 2026): the day,
  // the journal, and a new reminder on its time, by the clock and by the
  // sun.
  static const _barOnly = String.fromEnvironment('LOOK') == 'bar';

  /// Walks the screens. Called once, after the first frame.
  static Future<void> run(BuildContext Function() context) async {
    _semantics = SemanticsBinding.instance.ensureSemantics();
    await _wait(3000);
    Future<void> step(Future<Object?> Function() go) async {
      try {
        await go();
      } catch (_) {}
      await _wait(1200);
    }

    await _show('01-day');

    if (_barOnly) {
      await step(() => Tour.key('journal-button'));
      await _show('02-journal');
      await step(() => Tour.key('reminder-button'));
      await step(() => Tour.key('reminder-add'));
      await step(_away);
      await step(() => Tour.reveal('field-time'));
      await _show('03-reminder-time');
      await step(() => Tour.reveal('reminder-anchor-sunset'));
      await _show('04-reminder-sunset');
      await step(() => Tour.reveal('reminder-anchor-clock'));
      await step(() => Tour.back(context()));
      await step(() => Tour.key('system-label'));
      await _show('05-day-again');
      _marker.value = 'shot-done';
      await Future<void>.delayed(const Duration(seconds: 30));
      _marker.value = null;
      _semantics?.dispose();
      _semantics = null;
      return;
    }

    await step(() => Tour.key('journal-button'));
    await _show('02-journal');
    await step(() => Tour.key('reminder-button'));
    await _show('03-reminders');

    // A new reminder, named first: the keyboard comes up by itself.
    await _burst('04-reminder-new', () => Tour.key('reminder-add'));
    await _show('04-reminder-keyboard');
    await step(_away);
    await step(() => Tour.key('reminder-tags'));
    await _show('05-reminder-tags');
    await _burst('06-reminder-tags-typing', () => Tour.key('reminder-title'));
    await _show('06-reminder-tags-keyboard');
    await step(_away);
    await step(() => Tour.key('reminder-tags'));
    await step(() => Tour.back(context()));

    // A new category, never kept.
    await step(() => Tour.key('categories'));
    await step(() => Tour.key('category-add'));
    await step(_away);
    await _show('07-category');
    await _burst('08-category-typing', () => Tour.key('category-name'));
    await _show('08-category-keyboard');
    await _burst('09-category-away', () async {
      FocusManager.instance.primaryFocus?.unfocus();
      return true;
    });
    await step(() => Tour.back(context()));
    await step(() => Tour.back(context()));

    // The search, its words.
    await step(() => Tour.key('reminders-search'));
    await _show('10-search');
    // The Words tab asks for the keyboard itself.
    await _burst('11-search-words', () => Tour.reveal('search-field-words'));
    await _show('11-search-words-keyboard');
    await _burst('12-search-words-done', () => Tour.key('search-words-done'));
    await step(() => Tour.back(context()));
    await step(() => Tour.key('system-label'));

    // The star map: the galaxies, then the search.
    SystemScope.of(context()).value = CalendarSystem.gregorian;
    await _wait();
    await step(() => Tour.key('utilities-button'));
    await step(() => Tour.reveal('utility-stars'));
    await _wait(2000);
    await step(() => Tour.reveal('stars-panel-galaxies'));
    await _show('13-stars-galaxies');
    await _burst('14-stars-search', () => Tour.reveal('stars-panel-search'));
    await _show('14-stars-search-keyboard');
    await _burst('15-stars-galaxies-again', () async {
      FocusManager.instance.primaryFocus?.unfocus();
      await _wait(300);
      return Tour.reveal('stars-panel-galaxies');
    });
    await step(() => Tour.back(context()));
    await step(() => Tour.key('utilities-button'));

    // The bar through the two pickers that empty it, the system's and
    // the utilities': its glass is to stand still while the buttons go
    // and the one left rises into it.
    await _burst('16-system-picker', () => Tour.key('system-label'));
    await step(() => Tour.key('picker-done'));
    await _burst('17-utilities', () => Tour.key('utilities-button'));
    await step(() => Tour.key('utilities-button'));

    _marker.value = 'shot-done';
    await Future<void>.delayed(const Duration(seconds: 30));
    _marker.value = null;
    _semantics?.dispose();
    _semantics = null;
  }
}
