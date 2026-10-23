import 'package:candra/app_shell.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/hilal/hilal_screen.dart';
import 'package:candra/main.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:candra/utilities.dart';
import 'package:candra/calendar_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));

  Future<void> open(WidgetTester tester, CivilDate date) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    // Bosscha Observatory, Lembang, to the tenth.
    SkyPlace.current.value = (latitude: -6.8, longitude: 107.6);
    addTearDown(() => SkyPlace.current.value = null);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: HilalScreen(date: date, utcOffset: const Duration(hours: 7)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    for (
      var k = 0;
      k < 100 && find.text('Working it out…').evaluate().isNotEmpty;
      k++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  test('Hilal is a utility of the Hijri system, after prayer times', () {
    expect(Utility.of(CalendarSystem.hijri), [Utility.salat, Utility.hilal]);
  });

  testWidgets('opens on the evening of the nearest new moon, the sky drawn '
      'and the criteria judged', (tester) async {
    // A day after the new moon of 28 February 2025 opens on its evening.
    await open(tester, CivilDate(2025, 3, 1));
    expect(find.textContaining('28 February 2025'), findsWidgets);
    expect(key('hilal-sky'), findsOneWidget);
    expect(find.textContaining('Height 3.8°'), findsOneWidget);

    // At Lembang MABIMS's height is met and its elongation not; the
    // upper edge is above the horizon.
    expect(
      find.textContaining('Not met here: 3.8° high (3°), 6.0° apart'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Met: the new moon before sunset'),
      findsOneWidget,
    );
    await settle(tester);
    // Somewhere in Indonesia (the west, Aceh) the elongation is 6.4°: the
    // ministry declared 1 Ramadan 1446 for 1 March 2025.
    expect(find.textContaining('Met somewhere'), findsOneWidget);
  });

  testWidgets('an evening the moon sets first: nothing to see', (tester) async {
    await open(tester, CivilDate(2025, 3, 29));
    expect(find.text('The moon is below the horizon'), findsOneWidget);
    expect(
      find.text('The moon sets before the sun: nothing to see'),
      findsNWidgets(2),
    );
    await tester.tap(key('hilal-panel-evening'));
    await tester.pumpAndSettle();
    expect(find.textContaining('min before'), findsOneWidget);
    expect(find.textContaining('the new moon in'), findsOneWidget);
  });

  testWidgets('the coming new moons, a touch opens one', (tester) async {
    await open(tester, CivilDate(2025, 2, 28));
    await tester.tap(key('hilal-panel-months'));
    await tester.pump();
    await settle(tester);
    expect(key('hilal-months'), findsOneWidget);
    expect(find.textContaining('MABIMS'), findsWidgets);
    await tester.tap(key('hilal-month-1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('March 2025'), findsWidgets);
    expect(key('hilal-mabims'), findsOneWidget);
    // Away from today's new moon the house's today is not lit; it is the
    // way back to the new moon nearest today, and then is lit.
    bool lit() => tester.widget<GlyphButton>(key('today-button')).lit;
    String subtitle() => tester
        .widgetList<Text>(
          find.descendant(
            of: key('hilal-top-bar'),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join(' ');
    expect(lit(), isFalse);
    expect(subtitle(), contains('March 2025'));
    await tester.tap(key('today-button'));
    await tester.pumpAndSettle();
    expect(lit(), isTrue);
    expect(subtitle(), isNot(contains('2025')));
  });

  testWidgets('with no place it asks for one', (tester) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = null;
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: HilalScreen(
          date: CivilDate(2026, 2, 17),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(key('hilal-ask'), findsOneWidget);
    expect(find.byType(Strings), findsNothing);
  });
}
