import 'package:candra/app_shell.dart';
import 'package:candra/light/light_screen.dart';
import 'package:candra/light/meteor_showers.dart';
import 'package:candra/main.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_screen.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  Future<void> open(WidgetTester tester, {int? minute}) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = (latitude: -7.8, longitude: 110.4);
    addTearDown(() => SkyPlace.current.value = null);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: LightScreen(
          date: CivilDate(2026, 6, 15),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleWork(WidgetTester tester, String waiting) async {
    for (var k = 0; k < 80 && find.text(waiting).evaluate().isNotEmpty; k++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Light opens on the hours, with the plan and the day\'s '
      'light', (tester) async {
    await open(tester);
    expect(find.text('Light'), findsOneWidget);
    expect(find.byKey(const ValueKey('light-plan')), findsOneWidget);
    expect(find.byKey(const ValueKey('light-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('light-hours')), findsOneWidget);
    expect(find.text('MORNING GOLDEN'), findsOneWidget);
    expect(find.text('EVENING BLUE'), findsOneWidget);

    // At five in the afternoon in June at Yogyakarta the sun is low:
    // golden, with a long shadow and a rainbow possible.
    expect(find.text('Golden hour'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('light-panel-shadow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('light-shadow')), findsOneWidget);
    expect(find.text('SHADOW LENGTH'), findsOneWidget);
    expect(find.textContaining('top '), findsOneWidget);
  });

  testWidgets('the moon lists the coming full moons, nearest marked; the '
      'Milky Way is dark and moonless on a June new moon', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('light-panel-moon')));
    await tester.pump();
    await settleWork(tester, 'Working it out…');
    expect(find.text('COMING FULL MOONS'), findsOneWidget);
    expect(find.textContaining('nearest'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('light-panel-milkyWay')));
    await tester.pump();
    await settleWork(tester, 'Working it out…');
    expect(find.text('DARK, NO MOON'), findsOneWidget);
    final moonless = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((t) => RegExp(r'^\d\d:\d\d – \d\d:\d\d').hasMatch(t));
    expect(moonless, isNotEmpty);
  });

  testWidgets('lining up: a touch on the plan sets the bearing, and the '
      'days the sun sets along it are found', (tester) async {
    await open(tester);
    await tester.drag(
      find.byKey(const ValueKey('light-panels')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('light-panel-align')));
    await tester.pump();
    final plan = tester.getRect(find.byKey(const ValueKey('light-plan')));
    // Due west of the centre.
    await tester.tapAt(plan.center - Offset(plan.shortestSide / 3, 0));
    await tester.pump();
    expect(find.text('270° W'), findsOneWidget);
    await settleWork(tester, 'Working it out…');
    expect(find.text('SUN SETS ALONG IT'), findsOneWidget);
    // Due west at Yogyakarta: near the equinoxes, March and September.
    expect(find.textContaining('September 2026'), findsWidgets);
  });

  testWidgets('the compass, set to true north, shows where the phone '
      'faces, and stops when touched again', (tester) async {
    var listening = false;
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('candra/heading'),
      MockStreamHandler.inline(
        onListen: (_, events) {
          listening = true;
          // The needle at 269°: at Yogyakarta it points about a degree
          // east of true north, so the phone faces about 270°.
          events.success({'heading': 269.0, 'accuracy': 3});
        },
        onCancel: (_) => listening = false,
      ),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('candra/heading'),
        null,
      ),
    );
    await open(tester);
    expect(find.byKey(const ValueKey('light-facing')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('light-compass')));
    await tester.pump();
    await tester.pump();
    expect(listening, isTrue);
    final facing = tester
        .widget<Text>(find.byKey(const ValueKey('light-facing')))
        .data!;
    expect(facing, startsWith('Facing 270° W, true north (+'));

    await tester.tap(find.byKey(const ValueKey('light-compass')));
    await tester.pump();
    expect(listening, isFalse);
    expect(find.byKey(const ValueKey('light-facing')), findsNothing);
  });

  testWidgets('a bell on a moment makes a reminder of it, ready to save', (
    tester,
  ) async {
    await open(tester);
    // Sunset, by the sun, a quarter of an hour ahead.
    await tester.ensureVisible(
      find.byKey(const ValueKey('light-hours-remind-4')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('light-hours-remind-4')));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderScreen), findsOneWidget);
    expect(find.text('Sunset'), findsWidgets);
    expect(find.textContaining('Sunset · 15 min before'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('reminder-save')));
    await tester.pumpAndSettle();
    final store = tester
        .widget<ReminderScope>(find.byType(ReminderScope))
        .notifier!;
    final saved = store.reminders.single;
    expect(saved.sun, SunAnchor.sunset);
    expect(saved.lead, 15);
    expect(saved.start, CivilDate(2026, 6, 15));
    expect(find.byType(ReminderScreen), findsNothing);
    expect(find.text('Light'), findsOneWidget);
    // The morning golden hour, which no reminder can follow, has no bell.
    expect(find.byKey(const ValueKey('light-hours-remind-2')), findsNothing);
  });

  testWidgets('the night\'s exposure limits, the coming meteor showers and '
      'the eclipses to be seen from here', (tester) async {
    MeteorShower.reset();
    await tester.runAsync(MeteorShower.load);
    await open(tester);
    Future<void> tab(String name) async {
      final finder = find.byKey(ValueKey('light-panel-$name'));
      await tester.scrollUntilVisible(
        finder,
        80,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('light-panels')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tab('night');
    // 14 mm at f/2.8, 5.9 µm pixels, full frame: (98 + 177) ÷ 14 = 19.6,
    // shown whole from ten seconds up.
    expect(find.text('20 s'), findsOneWidget);
    expect(find.text('36 s'), findsOneWidget);
    expect(find.textContaining('south celestial pole, 7.8°'), findsOneWidget);

    await tab('meteors');
    for (
      var k = 0;
      k < 60 && find.text('Working it out…').evaluate().isNotEmpty;
      k++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // From 15 June the next peak is the June Bootids'.
    expect(find.textContaining('June Bootids · 2'), findsOneWidget);

    await tab('eclipses');
    for (
      var k = 0;
      k < 60 && find.text('Working it out…').evaluate().isNotEmpty;
      k++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('light-eclipses')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Total lunar eclipse · 31 December 2028'),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('light-eclipses')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.textContaining('Total lunar eclipse · 31 December 2028'),
      findsOneWidget,
    );

    // The coming year's close pairs, each with when it is best seen.
    await tab('pairs');
    for (
      var k = 0;
      k < 60 && find.text('Working it out…').evaluate().isNotEmpty;
      k++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('light-pairs')), findsOneWidget);
    expect(find.textContaining('Moon and '), findsWidgets);
    expect(find.textContaining('nearest '), findsWidgets);
  });
}
