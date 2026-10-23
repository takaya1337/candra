import 'package:candra/app_shell.dart';
import 'package:candra/main.dart';
import 'package:candra/sky/sky_screen.dart';
import 'package:candra/sky/sky_year.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:candra/date_picker.dart';
import 'package:candra/glyph_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));
  // A day that is not today, whatever day the tests run on: the screen
  // opens on today's moment and on any other day's noon.
  final now = DateTime.now();
  final date =
      CivilDate(now.year, now.month, now.day) == CivilDate(2026, 10, 20)
      ? CivilDate(2026, 10, 21)
      : CivilDate(2026, 10, 20);
  const offset = Duration(hours: 7);

  setUp(() {
    SkyPlace.current.value = (latitude: -6.2, longitude: 106.8);
    // Worked out at once, not in an isolate the test clock cannot see.
    SkyYear.build = (year, latitude, longitude, offsets) async =>
        SkyYear.compute(year, latitude, longitude, offsets);
    SkyMonth.build = (year, month, latitude, longitude, offsets) async =>
        SkyMonth.compute(year, month, latitude, longitude, offsets);
  });
  tearDown(() => SkyPlace.current.value = null);

  Future<void> pump(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
  }) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: language),
        home: SkyScreen(date: date, utcOffset: offset),
      ),
    );
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String name) =>
      tester.widget<Text>(key(name)).data!;

  testWidgets('opens on noon of a day not today, the sun\'s figures in the '
      'panel', (tester) async {
    await pump(tester);
    expect(text(tester, 'sky-clock'), '12:00');
    expect(tester.getRect(key('sky-dome')).width, greaterThan(340));
    expect(key('sky-sun-rows'), findsOneWidget);
    // The figures are the engine's: the sun at noon, 05:00 UT.
    final sun = SkyNow.sun(
      DateTime.utc(date.year, date.month, date.day, 5),
      latitude: -6.2,
      longitude: 106.8,
    );
    expect(find.text('+${sun.altitude.toStringAsFixed(2)}°'), findsOneWidget);
    expect(find.text('CULMINATES'), findsOneWidget);
    expect(find.text('EQUATION OF TIME'), findsOneWidget);
  });

  testWidgets('the moon\'s panel, chosen from the strip of panels', (
    tester,
  ) async {
    await pump(tester, language: AppLanguage.id);
    await tester.tap(key('sky-panel-moon'));
    await tester.pumpAndSettle();
    expect(key('sky-moon-rows'), findsOneWidget);
    expect(find.text('ELONGASI'), findsOneWidget);
    expect(find.textContaining(' km'), findsOneWidget);
  });

  testWidgets('dragging along the day moves the moment, and the glyph '
      'beside the calendar brings back today and now', (tester) async {
    await pump(tester);
    // The way back to today is the house's, right of the menu button;
    // the far right is left for the journal.
    final menu = tester.getRect(key('menu-button'));
    final now = tester.getRect(key('today-button'));
    expect(now.left, greaterThan(menu.right));
    expect(now.left, lessThan(menu.right + 24));
    final strip = tester.getRect(key('sky-strip'));
    // A quarter of the way along: six in the morning.
    await tester.tapAt(Offset(strip.left + strip.width / 4, strip.top + 10));
    await tester.pumpAndSettle();
    expect(text(tester, 'sky-clock'), '06:00');
    await tester.dragFrom(
      Offset(strip.left + strip.width / 4, strip.top + 10),
      Offset(strip.width / 2, 0),
    );
    await tester.pumpAndSettle();
    expect(text(tester, 'sky-clock'), '18:00');
    await tester.tap(key('today-button'));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    expect(
      find.textContaining(
        Strings(AppLanguage.en)
            .gregorian(CivilDate(today.year, today.month, today.day)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the date is chosen on wheels in the panel', (tester) async {
    await pump(tester);
    await tester.tap(key('sky-panel-date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePicker), findsOneWidget);
  });

  testWidgets('the views go day, month, year, as the calendar\'s do; the '
      'lock is there only over a month or a year', (tester) async {
    await pump(tester);
    Glyph view() => tester.widget<GlyphButton>(key('sky-view')).glyph;
    expect(view(), Glyph.monthView);
    // The lock stands beside the wheels of the time panel.
    await tester.tap(key('sky-panel-time'));
    await tester.pumpAndSettle();
    expect(key('sky-lock'), findsNothing);
    await tester.tap(key('sky-view'));
    await tester.pumpAndSettle();
    expect(view(), Glyph.yearView);
    expect(key('sky-month-strip'), findsOneWidget);
    expect(key('sky-lock'), findsOneWidget);
    await tester.tap(key('sky-view'));
    await tester.pumpAndSettle();
    expect(view(), Glyph.dayView);
    expect(key('sky-year-strip'), findsOneWidget);
    await tester.tap(key('sky-view'));
    await tester.pumpAndSettle();
    expect(view(), Glyph.monthView);
    expect(key('sky-strip'), findsOneWidget);
    expect(key('sky-lock'), findsNothing);
  });

  testWidgets('the month view: the sun and the moon at the moment\'s hour '
      'on every day of the month', (tester) async {
    await pump(tester);
    await tester.tap(key('sky-view'));
    await tester.pumpAndSettle();
    final dome = tester.widget<SkyDome>(key('sky-dome'));
    expect(dome.view, SkyView.month);
    // Height and bearing for each of October's 31 days.
    expect(dome.sunLocus, hasLength(62));
    expect(dome.moonLocus, hasLength(62));
    // As each worked out on its own.
    final noon = SkyNow.moon(
      DateTime.utc(2026, 10, 2, 5),
      latitude: -6.2,
      longitude: 106.8,
    );
    expect(dome.moonLocus[2], closeTo(noon.altitude, 0.01));
    expect(dome.moonLocus[3], closeTo(noon.azimuth, 0.01));
    // The moon comes some fifty minutes later each day, so at one clock
    // time it stands far from where it stood the day before.
    final apart =
        (dome.moonLocus[3] - dome.moonLocus[1]).abs() +
        (dome.moonLocus[2] - dome.moonLocus[0]).abs();
    expect(apart, greaterThan(5));
    // The sun barely moves.
    expect((dome.sunLocus[2] - dome.sunLocus[0]).abs(), lessThan(1));
  });

  testWidgets('the year view: the sun-path diagram over the dome, and the '
      'year as a picture that moves the day and the hour at once; locked, '
      'the day alone', (tester) async {
    await pump(tester);
    await tester.tap(key('sky-view'));
    await tester.pumpAndSettle();
    await tester.tap(key('sky-view'));
    await tester.pumpAndSettle();
    expect(key('sky-year-strip'), findsOneWidget);
    final dome = tester.widget<SkyDome>(key('sky-dome'));
    expect(dome.year!.year, 2026);
    expect(dome.year!.tracks, hasLength(12));
    // At 6° S the sun is up at nine every day of the year, and never at
    // midnight.
    expect(dome.year!.loops[9], isNotEmpty);
    expect(dome.year!.loops[0], isEmpty);
    // The figure of the moment's hour, every day.
    expect(dome.sunLocus, hasLength(2 * 365));

    // The middle of the picture, across and down: early July, at noon.
    final strip = tester.getRect(key('sky-year-strip'));
    const band = PeriodStrip.height - PeriodStrip.labelHeight;
    await tester.tapAt(
      Offset(strip.left + strip.width / 2, strip.top + band / 2),
    );
    await tester.pumpAndSettle();
    expect(text(tester, 'sky-clock'), '12:00');
    expect(find.textContaining('July 2026'), findsOneWidget);
    // A quarter down: six in the morning; a quarter across: April.
    await tester.tapAt(
      Offset(strip.left + strip.width / 4, strip.top + band / 4),
    );
    await tester.pumpAndSettle();
    expect(text(tester, 'sky-clock'), '06:00');
    expect(find.textContaining('April 2026'), findsOneWidget);

    // Locked, the hour stays where it is however the touch goes; the lock
    // is beside the wheels of the time panel.
    await tester.tap(key('sky-panel-time'));
    await tester.pumpAndSettle();
    await tester.tap(key('sky-lock'));
    await tester.pumpAndSettle();
    expect(tester.widget<GlyphButton>(key('sky-lock')).lit, isTrue);
    await tester.tapAt(
      Offset(strip.left + strip.width * 0.9, strip.top + band * 0.8),
    );
    await tester.pumpAndSettle();
    expect(text(tester, 'sky-clock'), '06:00');
    expect(find.textContaining('November 2026'), findsOneWidget);
  });

  testWidgets('without a place it asks for one', (tester) async {
    SkyPlace.current.value = null;
    await pump(tester);
    expect(key('sky-ask-place'), findsOneWidget);
    expect(key('place-here'), findsOneWidget);
  });
}
