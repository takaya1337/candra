import 'package:candra/app_shell.dart';
import 'package:candra/main.dart';
import 'package:candra/planets/planets_screen.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));

  Future<void> open(WidgetTester tester, {AppLanguage? language}) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = (latitude: -6.2, longitude: 106.8);
    addTearDown(() => SkyPlace.current.value = null);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: language ?? AppLanguage.en),
        // Sunday 18 October 2026, nine in the evening, Jakarta.
        home: PlanetsScreen(
          date: CivilDate(2026, 10, 18),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    for (var k = 0; k < 40; k++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String name) async {
    final finder = key('planets-panel-$name');
    await tester.scrollUntilVisible(
      finder,
      80,
      scrollable: find.descendant(
        of: key('planets-panels'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the seven planets, each with its height, brightness and '
      'times; a touch opens one', (tester) async {
    await open(tester);
    expect(find.text('Planets'), findsWidgets);
    expect(key('planets-dome'), findsOneWidget);
    expect(key('planets-strip'), findsOneWidget);
    // Each of the seven, in order down the list.
    for (final body in Planets.all) {
      await tester.scrollUntilVisible(
        key('planets-row-${body.name}'),
        60,
        scrollable: find.descendant(
          of: key('planets-list'),
          matching: find.byType(Scrollable),
        ),
      );
      expect(key('planets-row-${body.name}'), findsOneWidget);
    }
    // Saturn, up through the October night.
    await tester.scrollUntilVisible(
      key('planets-row-saturn'),
      -60,
      scrollable: find.descendant(
        of: key('planets-list'),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('♄  Saturn'), findsOneWidget);
    expect(find.textContaining('Rises '), findsWidgets);
    await tester.ensureVisible(key('planets-row-saturn'));
    await tester.pumpAndSettle();
    await tester.tap(key('planets-row-saturn'));
    await tester.pumpAndSettle();
    expect(key('planets-more-saturn'), findsOneWidget);
  });

  testWidgets('the planetary hours: Sunday\'s first is the sun\'s, the '
      'next Venus\'s; at nine at night a night hour is lit', (tester) async {
    await open(tester);
    await tab(tester, 'hours');
    expect(
      tester.widget<Text>(key('planets-day-ruler')).data,
      'Sunday, the day of ☉ Sun',
    );
    expect(find.textContaining('☉  Sun'), findsWidgets);
    expect(key('planets-hour-0'), findsOneWidget);
    expect(key('planets-hour-1'), findsOneWidget);
    expect(find.text('Day, from sunrise'.toUpperCase()), findsOneWidget);
  });

  testWidgets('the lore: seven, slowest first, each with its metal and its '
      'day, in Indonesian too', (tester) async {
    await open(tester, language: AppLanguage.id);
    await tab(tester, 'lore');
    expect(key('planets-lore-saturn'), findsOneWidget);
    expect(find.textContaining('timbal'), findsOneWidget);
    expect(find.textContaining('Sabtu (dies Saturni)'), findsOneWidget);
    // Saturn first; the moon last, down the list.
    expect(
      tester.getTopLeft(key('planets-lore-saturn')).dy,
      lessThan(tester.getTopLeft(key('planets-lore-jupiter')).dy),
    );
    await tester.scrollUntilVisible(
      key('planets-lore-moon'),
      60,
      scrollable: find.descendant(
        of: key('planets-lore'),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('perak'), findsOneWidget);
    await tester.scrollUntilVisible(
      key('planets-lore-sun'),
      -60,
      scrollable: find.descendant(
        of: key('planets-lore'),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('emas'), findsOneWidget);
    expect(find.textContaining('Jawa Kuno Āditya'), findsOneWidget);
  });
}
