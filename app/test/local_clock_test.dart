import 'package:candra/app_shell.dart';
import 'package:candra/light/light_screen.dart';
import 'package:candra/local_clock.dart';
import 'package:candra/main.dart';
import 'package:candra/salat/salat_choice.dart';
import 'package:candra/salat/salat_screen.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:candra/sky/sky_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  // London: GMT, then BST from 01:00 UTC on 29 March 2026 until 01:00 UTC
  // on 25 October.
  Duration london(DateTime instant) {
    final at = instant.toUtc();
    final summer =
        !at.isBefore(DateTime.utc(2026, 3, 29, 1)) &&
        at.isBefore(DateTime.utc(2026, 10, 25, 1));
    return Duration(hours: summer ? 1 : 0);
  }

  setUp(() => LocalClock.zone = london);
  tearDown(() => LocalClock.zone = null);

  test('a spring day is reckoned by its summer noon; the hour before the '
      'change stands an hour behind its grid', () {
    final day = CivilDate(2026, 3, 29);
    expect(LocalClock.dayOffset(day, null), const Duration(hours: 1));
    // 00:30 by the clock is 00:30 UTC, still winter.
    final early = LocalClock.instant(day, 30, null);
    expect(early, DateTime.utc(2026, 3, 29, 0, 30));
    expect(LocalClock.shift(early, day, null), -60);
    // 03:30 by the clock is 02:30 UTC, summer.
    final late = LocalClock.instant(day, 3 * 60 + 30, null);
    expect(late, DateTime.utc(2026, 3, 29, 2, 30));
    expect(LocalClock.shift(late, day, null), 0);
    expect(LocalClock.wall(late, null).hour, 3);
    // A fixed offset knows nothing of changes.
    expect(LocalClock.shift(early, day, const Duration(hours: 1)), 0);
  });

  test('an autumn day: the hour before the change is an hour ahead', () {
    final day = CivilDate(2026, 10, 25);
    expect(LocalClock.dayOffset(day, null), Duration.zero);
    final early = DateTime.utc(2026, 10, 24, 23, 30); // 00:30 BST
    expect(LocalClock.wall(early, null).hour, 0);
    expect(LocalClock.shift(early, day, null), 60);
  });

  test('the day\'s samples stand where the clock had them, never going '
      'back past the start', () {
    final paths = SkyDayPaths(
      path: (_) => const [],
      day: (_, _) => const SkyDay(),
      shift: [for (var k = 0; k <= 144; k++) k < 6 ? -60 : 0],
    );
    expect(paths.fractionAt(0), 0);
    expect(paths.fractionAt(5), 0);
    expect(paths.fractionAt(6), 60 / 1440);
    expect(paths.fractionAt(144), 1);
  });

  test('prayer times before a change are moved by it', () {
    final times = SalatTimes.of(
      CivilDate(2026, 6, 21),
      latitude: 51.5,
      longitude: -0.1,
      utcOffset: const Duration(hours: 1),
      method: SalatMethod.muslimWorldLeague,
    );
    final moved = times.shifted((m) => m < 120 ? m - 60 : m);
    for (final s in Salat.values) {
      final a = times[s], b = moved[s];
      if (a == null) continue;
      expect(b, a < 120 ? a - 60 : a);
    }
  });

  testWidgets('the ephemeris, Light and the prayer times open on a spring '
      'change day in London, by its own clock', (tester) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = (latitude: 51.5, longitude: -0.1);
    SalatChoice.method.value = SalatMethod.muslimWorldLeague;
    addTearDown(() {
      SkyPlace.current.value = null;
      SalatChoice.method.value = null;
    });
    final day = CivilDate(2026, 3, 29);
    for (final screen in <Widget>[
      SkyScreen(date: day),
      LightScreen(date: day),
      SalatScreen(date: day),
    ]) {
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(saved: AppLanguage.en),
          home: screen,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    // Sunrise that day in London was 06:44 BST: printed by the clock.
    expect(find.textContaining('06:4'), findsWidgets);
  });
}
