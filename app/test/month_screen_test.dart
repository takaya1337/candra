import 'dart:ui' as ui;

import 'package:candra/journal/geo.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/app_shell.dart';
import 'package:candra/bar_button.dart';
import 'package:candra/calendar_system.dart';
import 'package:candra/bazi/bazi_screen.dart';
import 'package:candra/mangsa/mangsa_screen.dart';
import 'package:candra/salat/salat_screen.dart';
import 'package:candra/sky/sky_screen.dart';
import 'package:candra/menu/menu_screen.dart';
import 'package:candra/date_picker.dart';
import 'package:candra/day_page.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/day_reading.dart';
import 'package:candra/dot_picker.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/journal/card_stack.dart';
import 'package:candra/journal/categories_screen.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_file.dart';
import 'package:candra/journal/journal_file_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/language_toggle.dart';
import 'package:candra/main.dart';
import 'package:candra/reading_screen.dart';
import 'package:candra/reminders/reminders_screen.dart';
import 'package:candra/parts.dart';
import 'package:candra/strings.dart';
import 'package:candra/system_button.dart';
import 'package:candra/system_picker.dart';
import 'package:candra/utilities.dart';
import 'package:candra/year_grid.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/moon_glyph.dart';
import 'package:candra/system_glyph.dart';
import 'package:candra/system_palettes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

/// Whichever button closes what is open: the tick of a picker, or the
/// calendar or back glyph of a screen.
final doneButton = find.byWidgetPredicate((widget) {
  final key = widget.key;
  return widget is GlyphButton &&
      key is ValueKey<String> &&
      key.value.endsWith('done');
});

/// The phone's own back, as the house hands it to the room in front.
Future<void> goBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Stands in for the phone when the sky asks where it is.
class FakeSkyLocator extends Locator {
  @override
  Future<Fix> find() async =>
      (latitude: -7.607874, longitude: 110.203751, accuracy: 12.0);

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> open(GeoTag place) async => true;
}

void main() {
  // What the short reading shows in characters lasts as long as the app
  // runs; start every test with words.
  setUp(() {
    HanziChoice.date.value = false;
    HanziChoice.zodiac.value = false;
  });

  // The button at the centre of the bar, and the system its glyph is of.
  final systemButton = find.byKey(const ValueKey('system-label'));
  CalendarSystem shown(WidgetTester tester) =>
      tester.widget<SystemButton>(systemButton).system;

  // The short reading opens the detailed one when tapped anywhere but on
  // the Chinese date or the shio: here, on its title.
  Future<void> tapReading(WidgetTester tester) => tester.tapAt(
    tester.getTopLeft(find.byKey(const ValueKey('expand-reading'))) +
        const Offset(40, 30),
  );

  // The text of a tappable part of the Chinese row.
  String chinesePart(WidgetTester tester, String name) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(name)),
          matching: find.byType(Text),
        ),
      )
      .let((text) => text.data ?? text.textSpan!.toPlainText());

  // Most tests start in Weton, as an unlocked system the user shifted to.
  Future<void> pumpScreen(
    WidgetTester tester, {
    SystemController? controller,
    LanguageController? language,
    MonthScreenView? lockedView,
    ValueChanged<MonthScreenView?>? onLockView,
  }) async {
    // A Pixel 4 XL: 411 x 869 logical pixels.
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CalendarJournalApp(
        controller:
            controller ?? (SystemController()..value = CalendarSystem.weton),
        language: language ?? LanguageController(),
        home: MonthScreen(
          today: CivilDate(2026, 10, 11),
          utcOffset: const Duration(hours: 7),
          lockedView: lockedView,
          onLockView: onLockView,
        ),
      ),
    );
    // Lets the months either side of this one be laid out, as they are
    // on a device once the first frame is up.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
  }

  // Text inside the grid of the month on screen. The months either side are
  // kept built too, so a bare find.text('17') would match three grids.
  Finder inGrid(String text, {String month = '2026-10'}) => find.descendant(
    of: find.byKey(ValueKey('month-$month')),
    matching: find.text(text),
  );

  Finder card(CalendarSystem system) =>
      find.byKey(ValueKey('card-${system.name}'));

  Future<void> openSystems(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('system-label')));
    await tester.pumpAndSettle();
  }

  // Brings a system card to the centre of the strip, which chooses it.
  Future<void> tapCard(WidgetTester tester, CalendarSystem system) async {
    await tester.ensureVisible(card(system));
    await tester.pumpAndSettle();
    await tester.tap(card(system));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on today with its short reading: moon, Chinese, weton', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('11 October 2026'), findsOneWidget);
    expect(find.textContaining('Waxing Crescent'), findsOneWidget);
    expect(chinesePart(tester, 'chinese-date'), '2 Kau Gwee 2577');
    expect(chinesePart(tester, 'chinese-zodiac'), 'Fire Horse');
    expect(find.text('Minggu Legi · neptu 10'), findsOneWidget);
    // The other systems are in the detailed reading only.
    expect(find.text('HIJRI'), findsNothing);
    expect(find.text('JAVANESE'), findsNothing);
    expect(find.text('28 Bakdamulud 1960 Be'), findsNothing);
    // And there is no button for it any more: the view button and the
    // house bar's six.
    expect(find.byType(GlyphButton), findsNWidgets(7));
  });

  testWidgets('shows the moon in the reading only', (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('Waxing Crescent'), findsOneWidget);

    // Only in the reading; the grid cells carry no moon.
    expect(find.byType(MoonGlyph), findsOneWidget);

    await tester.tap(inGrid('26'));
    await tester.pump();
    expect(find.text('Full Moon · 100%'), findsOneWidget);

    await tester.tap(inGrid('10'));
    await tester.pump();
    expect(find.text('New Moon · 0%'), findsOneWidget);
  });

  testWidgets('the reading lists the systems in order and scrolls', (
    tester,
  ) async {
    await pumpScreen(tester);
    final rows = [
      find.text('11 October 2026'),
      find.textContaining('Waxing Crescent'),
      find.byKey(const ValueKey('chinese-date')),
      find.text('Minggu Legi · neptu 10'),
    ];
    for (var i = 1; i < rows.length; i++) {
      expect(
        tester.getTopLeft(rows[i]).dy,
        greaterThan(tester.getTopLeft(rows[i - 1]).dy),
      );
    }
    expect(
      find.ancestor(of: rows.last, matching: find.byType(Scrollable)),
      findsOneWidget,
    );
  });

  testWidgets('the header gaps and the reading header gap are one unit', (
    tester,
  ) async {
    await pumpScreen(tester);
    const unit = 16.0;

    final button = tester.getRect(
      find
          .ancestor(
            of: find.text('October 2026'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final subtitle = tester.getRect(find.text('Pasaran'));
    final weekdays = tester.getRect(find.text('M'));
    expect(subtitle.top - button.bottom, unit);
    expect(weekdays.top - subtitle.bottom, unit);

    final header = tester.getRect(find.text('11 October 2026'));
    final firstRow = tester.getRect(find.textContaining('Waxing Crescent'));
    expect(firstRow.top - header.bottom, unit);
  });

  testWidgets('tapping a day reads that day', (tester) async {
    await pumpScreen(tester);

    await tester.tap(inGrid('17'));
    await tester.pump();

    expect(find.textContaining('Sabtu Pahing'), findsOneWidget);
    expect(find.text('17 October 2026'), findsOneWidget);
    expect(chinesePart(tester, 'chinese-date'), '8 Kau Gwee 2577');
  });

  testWidgets('picking a system turns the calendar to its own months, the '
      'Gregorian days they span under the title', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Pasaran'), findsOneWidget);
    expect(find.text('Kliwon'), findsWidgets);
    await openSystems(tester);

    // 11 October 2026 in each: the month's title, and its Gregorian span.
    const months = {
      CalendarSystem.javanese: (
        'Bakdamulud 1960 Be',
        'September – October 2026',
      ),
      CalendarSystem.chinese: ('Kau Gwee 2577', 'October – November 2026'),
      CalendarSystem.hijri: (
        "Rabi' al-Thani 1448 AH",
        'September – October 2026',
      ),
    };
    for (final MapEntry(key: system, value: (title, span)) in months.entries) {
      await tapCard(tester, system);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: system.name);
      expect(find.text(span), findsOneWidget, reason: system.name);
      expect(find.text('Kliwon'), findsNothing);
    }
    // Back to the Gregorian: its own month again.
    await tapCard(tester, CalendarSystem.gregorian);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('each system tints the app in its own colours', (tester) async {
    await pumpScreen(tester);
    SmColors colors() =>
        SmTheme.of(tester.element(find.byType(MonthScreen))).colors;

    expect(colors().accent, CalendarSystem.weton.colors.accent);
    final accents = {colors().accent};
    await openSystems(tester);

    for (final system in CalendarSystem.values.skip(1)) {
      await tapCard(tester, system);
      await tester.pumpAndSettle();
      expect(colors().accent, system.colors.accent);
      expect(colors().background, system.colors.background);
      accents.add(colors().accent);
    }
    expect(accents, hasLength(CalendarSystem.values.length));
  });

  testWidgets('the colours change by fading a picture of the old screen', (
    tester,
  ) async {
    final controller = SystemController()..value = CalendarSystem.weton;
    await pumpScreen(tester, controller: controller);
    final picture = find.byKey(const ValueKey('colour-shift'));
    Color background() =>
        SmTheme.of(tester.element(find.byType(MonthScreen))).colors.background;
    double opacity() => tester.widget<RawImage>(picture).opacity!.value;

    expect(picture, findsNothing);
    controller.value = CalendarSystem.hijri;
    await tester.pump();
    // The theme is the new one at once; the old screen lies over it.
    expect(background(), CalendarSystem.hijri.colors.background);
    expect(picture, findsOneWidget);
    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacity(), inExclusiveRange(0, 1));

    // A change in the middle of a fade starts another from what shows.
    controller.value = CalendarSystem.chinese;
    await tester.pump();
    expect(picture, findsOneWidget);
    expect(opacity(), 1);

    await tester.pumpAndSettle();
    expect(picture, findsNothing);
    expect(background(), CalendarSystem.chinese.colors.background);
  });

  group('system picker', () {
    testWidgets('opens a card for every system in place of the reading', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openSystems(tester);

      for (final system in CalendarSystem.values) {
        expect(card(system), findsOneWidget);
      }
      // One on each card; the bar's own has given way to the tick.
      expect(find.byType(SystemGlyph), findsNWidgets(5));
      expect(find.byKey(const ValueKey('picker-done')), findsOneWidget);
      expect(find.textContaining('Waxing Crescent'), findsNothing);
      // Each card reads the selected day its own way.
      expect(find.text('Minggu Legi'), findsOneWidget);
      expect(find.text("28 Rabi' al-Thani 1448 AH"), findsOneWidget);
      expect(find.text('2 Ninth Month 2577'), findsOneWidget);
    });

    testWidgets('the bar\'s centre becomes the tick; the rest of the bar '
        'stays', (tester) async {
      await pumpScreen(tester);
      await openSystems(tester);

      expect(doneButton.hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('picker-done')), findsOneWidget);
      expect(systemButton, findsNothing);
      // The house's bar never changes otherwise.
      expect(
        find.byKey(const ValueKey('today-button')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('journal-button')).hitTestable(),
        findsOneWidget,
      );

      // The tick lets the cards down, and the system comes back.
      await tester.tap(doneButton);
      await tester.pumpAndSettle();
      expect(card(CalendarSystem.weton), findsNothing);
      expect(systemButton, findsOneWidget);
    });

    double centreOf(WidgetTester tester, CalendarSystem system) =>
        tester.getCenter(card(system)).dx;

    for (final system in CalendarSystem.values) {
      testWidgets('opens with ${system.name} at the centre when it is active', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          controller: SystemController()..value = system,
        );
        await openSystems(tester);
        expect(centreOf(tester, system), moreOrLessEquals(411 / 2, epsilon: 1));
      });
    }

    testWidgets('tapping a card brings it to the centre, and the system '
        'follows when it arrives', (tester) async {
      final controller = SystemController()..value = CalendarSystem.weton;
      await pumpScreen(tester, controller: controller);
      await openSystems(tester);

      await tester.tap(card(CalendarSystem.javanese));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Still on its way.
      expect(controller.value, CalendarSystem.weton);
      await tester.pumpAndSettle();
      expect(controller.value, CalendarSystem.javanese);
      expect(
        centreOf(tester, CalendarSystem.javanese),
        moreOrLessEquals(411 / 2, epsilon: 1),
      );
      expect(card(CalendarSystem.weton), findsOneWidget);

      await tester.tap(doneButton);
      await tester.pumpAndSettle();
      expect(card(CalendarSystem.weton), findsNothing);
      expect(shown(tester), CalendarSystem.javanese);
      expect(find.textContaining('Waxing Crescent'), findsOneWidget);
    });

    testWidgets('swiping sets whichever card comes to rest at the centre', (
      tester,
    ) async {
      final controller = SystemController()..value = CalendarSystem.weton;
      await pumpScreen(tester, controller: controller);
      await openSystems(tester);

      // A drag of about one card.
      await tester.drag(find.byType(SystemPicker), const Offset(-170, 0));
      await tester.pumpAndSettle();
      expect(controller.value, CalendarSystem.javanese);
      expect(
        centreOf(tester, CalendarSystem.javanese),
        moreOrLessEquals(411 / 2, epsilon: 1),
      );

      // A drag that stops between two cards settles on the nearer.
      await tester.drag(find.byType(SystemPicker), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(controller.value, CalendarSystem.javanese);
      expect(
        centreOf(tester, CalendarSystem.javanese),
        moreOrLessEquals(411 / 2, epsilon: 1),
      );

      // A fling carries further.
      await tester.fling(
        find.byType(SystemPicker),
        const Offset(-200, 0),
        2500,
      );
      await tester.pumpAndSettle();
      expect(controller.value.index, greaterThan(2));
      expect(
        centreOf(tester, controller.value),
        moreOrLessEquals(411 / 2, epsilon: 1),
      );
    });

    testWidgets('the nearer a card is to the centre, the more it stands out', (
      tester,
    ) async {
      final controller = SystemController()..value = CalendarSystem.chinese;
      await pumpScreen(tester, controller: controller);
      await openSystems(tester);

      double opacityOf(CalendarSystem system) => tester
          .widget<Opacity>(
            find
                .descendant(of: card(system), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      expect(opacityOf(CalendarSystem.chinese), 1);
      expect(opacityOf(CalendarSystem.javanese), lessThan(0.8));

      // Half way to the next card, the two look alike.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SystemPicker)),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-82, 0));
      await tester.pump();
      expect(
        opacityOf(CalendarSystem.chinese),
        moreOrLessEquals(opacityOf(CalendarSystem.hijri), epsilon: 0.08),
      );
      // Nothing is chosen until it comes to rest.
      expect(controller.value, CalendarSystem.chinese);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('keeps its state through opening and closing', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(const ValueKey('system-label')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final opening = tester.state(find.byType(SystemPicker));

      await tester.pumpAndSettle();
      expect(tester.state(find.byType(SystemPicker)), same(opening));

      await tester.tap(doneButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.state(find.byType(SystemPicker)), same(opening));
      await tester.pumpAndSettle();
    });

    testWidgets('opens already at its place, without a jump', (tester) async {
      await pumpScreen(
        tester,
        controller: SystemController()..value = CalendarSystem.gregorian,
      );
      await tester.tap(find.byKey(const ValueKey('system-label')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final early = tester.getTopLeft(card(CalendarSystem.gregorian)).dx;

      await tester.pumpAndSettle();
      final settled = tester.getRect(card(CalendarSystem.gregorian));
      expect((settled.left - early).abs(), lessThan(12));
    });

    testWidgets('of cards tapped in quick succession, the last one wins', (
      tester,
    ) async {
      // Both taps must land on their cards, not beside them.
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      // From the middle, so that a card is in sight on either side.
      final controller = SystemController()..value = CalendarSystem.chinese;
      await pumpScreen(tester, controller: controller);
      await openSystems(tester);

      await tester.tap(card(CalendarSystem.hijri));
      await tester.pump(const Duration(milliseconds: 30));
      // On its way to the first, and nothing chosen yet.
      expect(controller.value, CalendarSystem.chinese);
      // The card on the left is partly past the screen's edge: tapped on
      // the part in sight.
      const inSight = Alignment(0.5, 0);
      final javanese = card(CalendarSystem.javanese);
      final box = tester.getRect(javanese);
      final at = inSight.withinRect(box);
      // On the screen; mid-glide the strip, not the card, hears it.
      expect(at.dx, inInclusiveRange(0, 411));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(controller.value, CalendarSystem.javanese);
      expect(
        centreOf(tester, CalendarSystem.javanese),
        moreOrLessEquals(411 / 2, epsilon: 1),
      );
      // Until this test tapped both cards it passed by tapping only the
      // second: the first was off the screen. Tapped for real, the second
      // tap fell while the strip glided, when a scroll view lets nothing
      // in it be touched; the strip now hears such a tap itself.
    });

    testWidgets('the month button switches to the date picker', (tester) async {
      await pumpScreen(tester);
      await openSystems(tester);

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
      expect(card(CalendarSystem.weton), findsNothing);
    });
  });

  testWidgets('swiping up moves to the next month', (tester) async {
    await pumpScreen(tester);

    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('November 2026'), findsOneWidget);
  });

  group('date picker', () {
    Future<void> openPicker(WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
    }

    Future<void> spin(WidgetTester tester, String wheel, int items) async {
      await tester.drag(find.byKey(ValueKey(wheel)), Offset(0, -36.0 * items));
      await tester.pumpAndSettle();
      // The grid follows once the wheels have been still for a moment.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
    }

    testWidgets('replaces the day reading and closes again', (tester) async {
      await openPicker(tester);
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
      expect(find.textContaining('Minggu Legi'), findsNothing);

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      expect(find.byType(ListWheelScrollView), findsNothing);
      expect(find.textContaining('Minggu Legi'), findsOneWidget);
    });

    testWidgets('the bar stays as it is while picking; the month button '
        'closes the wheels', (tester) async {
      await pumpScreen(tester);
      expect(doneButton, findsNothing);
      expect(
        find.byKey(const ValueKey('today-button')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('journal-button')).hitTestable(),
        findsOneWidget,
      );
      expect(shown(tester), CalendarSystem.weton);

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      // No tick for the wheels: the house's bar is unchanged.
      expect(doneButton, findsNothing);
      expect(
        find.byKey(const ValueKey('today-button')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('journal-button')).hitTestable(),
        findsOneWidget,
      );
      expect(systemButton.hitTestable(), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('month-button')));
      await tester.pumpAndSettle();
      expect(doneButton, findsNothing);
      expect(find.byType(ListWheelScrollView), findsNothing);
      expect(find.textContaining('Minggu Legi'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('today-button')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('both layers are on screen mid-transition', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('October 2026'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Minggu Legi'), findsOneWidget);
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
      await tester.pumpAndSettle();
    });

    testWidgets('spinning the wheels moves the grid', (tester) async {
      await openPicker(tester);

      await spin(tester, 'picker-month', 2);
      expect(find.text('December 2026'), findsOneWidget);

      await spin(tester, 'picker-year', 1);
      expect(find.text('December 2027'), findsOneWidget);

      await spin(tester, 'picker-day', 3);
      await tester.tap(find.text('December 2027'));
      await tester.pumpAndSettle();
      expect(find.textContaining('14 December 2027'), findsOneWidget);
    });

    testWidgets('the day wheel moves the highlight notch by notch', (
      tester,
    ) async {
      await openPicker(tester);
      bool isSelected(String day) => tester
          .widgetList<Container>(
            find.ancestor(of: find.text(day), matching: find.byType(Container)),
          )
          .any((c) => (c.decoration as BoxDecoration?)?.color != null);

      final wheel = find.byKey(const ValueKey('picker-day'));
      final spin = await tester.startGesture(tester.getCenter(wheel));
      await spin.moveBy(const Offset(0, -36));
      await tester.pump();
      await spin.moveBy(const Offset(0, -36));
      await tester.pump();

      // No waiting for the wheel to settle.
      expect(isSelected('13'), isTrue);
      expect(isSelected('11'), isFalse);
      await spin.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the bar\'s glyph follows the system, one giving way to '
        'the next, and the button never changes size', (tester) async {
      final controller = SystemController()..value = CalendarSystem.weton;
      await pumpScreen(tester, controller: controller);
      final size = tester.getSize(systemButton);
      final centre = tester.getCenter(systemButton).dx;
      Finder glyphs() =>
          find.descendant(of: systemButton, matching: find.byType(SystemGlyph));
      expect(glyphs(), findsOneWidget);

      for (final system in CalendarSystem.values) {
        controller.value = system;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 25));
        await tester.pumpAndSettle();
        expect(shown(tester), system);
        expect(glyphs(), findsOneWidget);
        expect(tester.widget<SystemGlyph>(glyphs()).system, system);
        // The same size and the same place for every system, the
        // Chinese one with its bazi button included: the bar's centre.
        expect(tester.getSize(systemButton), size);
        expect(tester.getCenter(systemButton).dx, centre);
        expect(
          centre,
          closeTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
            0.01,
          ),
        );
      }
    });

    testWidgets('a fast spin moves the grid once, when it settles', (
      tester,
    ) async {
      await openPicker(tester);

      final wheel = find.byKey(const ValueKey('picker-year'));
      final spin = await tester.startGesture(tester.getCenter(wheel));
      for (var notch = 0; notch < 5; notch++) {
        await spin.moveBy(const Offset(0, -36));
        await tester.pump(const Duration(milliseconds: 40));
        expect(find.text('October 2026'), findsOneWidget);
      }
      await spin.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsNothing);
      expect(find.textContaining('October 203'), findsOneWidget);
    });

    testWidgets('closing applies a date the grid has not caught up to', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.drag(
        find.byKey(const ValueKey('picker-month')),
        const Offset(0, -36),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('month-button')));
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);
      expect(find.textContaining('11 November 2026'), findsOneWidget);
    });

    testWidgets('clamps the day when the month is shorter', (tester) async {
      await openPicker(tester);
      await spin(tester, 'picker-day', 20);
      await spin(tester, 'picker-month', 1);

      await tester.tap(find.text('November 2026'));
      await tester.pumpAndSettle();
      expect(find.textContaining('30 November 2026'), findsOneWidget);
    });

    testWidgets('follows a day tapped in the grid', (tester) async {
      await openPicker(tester);
      await tester.tap(inGrid('Pahing').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 October 2026'), findsOneWidget);
    });
  });

  group('default system', () {
    testWidgets('starts in Gregorian when nothing is locked', (tester) async {
      await pumpScreen(tester, controller: SystemController());
      expect(shown(tester), CalendarSystem.gregorian);
    });

    testWidgets('starts in the locked system', (tester) async {
      await pumpScreen(
        tester,
        controller: SystemController(locked: CalendarSystem.chinese),
      );
      expect(shown(tester), CalendarSystem.chinese);
      // The calendar in the Chinese months: Kau Gwee, and the Gregorian
      // days it spans.
      expect(find.text('Kau Gwee 2577'), findsOneWidget);
      expect(find.text('October – November 2026'), findsOneWidget);
    });

    testWidgets('holding the system label locks it', (tester) async {
      final locked = <CalendarSystem?>[];
      final controller = SystemController(onLock: locked.add)
        ..value = CalendarSystem.javanese;
      await pumpScreen(tester, controller: controller);

      final hold = await tester.startGesture(tester.getCenter(systemButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(locked, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(locked, [CalendarSystem.javanese]);
      expect(controller.locked, CalendarSystem.javanese);
      await tester.pump();
      expect(
        find.text(
          'Javanese is now your default calendar '
          'and will persist on restart.',
        ),
        findsOneWidget,
      );

      // Letting go after the lock must not also shift the system.
      await hold.up();
      await tester.pump();
      expect(controller.value, CalendarSystem.javanese);

      // The reading steps back almost out of sight while the toast shows.
      final dimmed = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.textContaining('Minggu Legi'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(dimmed.opacity, lessThan(0.05));

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.textContaining('is now your default'), findsNothing);
    });

    testWidgets('a tap on the system label opens the picker, no lock', (
      tester,
    ) async {
      final locked = <CalendarSystem?>[];
      final controller = SystemController(onLock: locked.add);
      await pumpScreen(tester, controller: controller);

      await tester.tap(systemButton);
      await tester.pumpAndSettle();
      expect(find.byType(SystemPicker), findsOneWidget);
      expect(controller.value, CalendarSystem.gregorian);
      expect(locked, isEmpty);
    });

    testWidgets('letting go early neither shifts nor locks', (tester) async {
      final locked = <CalendarSystem?>[];
      final controller = SystemController(onLock: locked.add);
      await pumpScreen(tester, controller: controller);

      final hold = await tester.startGesture(tester.getCenter(systemButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await hold.up();
      await tester.pumpAndSettle();

      expect(controller.value, CalendarSystem.gregorian);
      expect(locked, isEmpty);
    });
  });

  group('detailed mode', () {
    Future<void> openDetail(WidgetTester tester) async {
      await pumpScreen(tester);
      await tapReading(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('a tap on the reading opens the day on a sheet that has the '
        'whole screen above the bar', (tester) async {
      await openDetail(tester);

      expect(find.byType(ReadingScreen), findsOneWidget);
      Finder inRow(String row, String text) => find.descendant(
        of: find.byKey(ValueKey('detail-$row')),
        matching: find.text(text),
      );
      // At the head the moon drawing itself, the date, and the moon said.
      expect(find.byType(TracedMoon), findsOneWidget);
      expect(inRow('head', '11 October 2026'), findsOneWidget);
      expect(inRow('head', 'Waxing Crescent'), findsOneWidget);
      expect(inRow('head', '0% lit'), findsOneWidget);
      // Each value in two tiers.
      expect(inRow('weton', 'Minggu Legi'), findsOneWidget);
      expect(inRow('weton', 'neptu 10'), findsOneWidget);
      // The Javanese reckonings, then the Hijri, then the two in
      // characters, last.
      double top(String row) =>
          tester.getTopLeft(find.byKey(ValueKey('detail-$row'))).dy;
      final order = ['weton', 'javanese', 'mangsa', 'hijri', 'chinese', 'bazi'];
      for (var i = 1; i < order.length; i++) {
        expect(top(order[i]), greaterThan(top(order[i - 1])), reason: order[i]);
      }
      // No expand glyph on the sheet itself, and no button to close it:
      // the house's bar stands under it, as everywhere.
      expect(find.byKey(const ValueKey('expand-reading')), findsNothing);
      expect(doneButton, findsNothing);
      expect(
        find.byKey(const ValueKey('today-button')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('journal-button')).hitTestable(),
        findsOneWidget,
      );

      // Copy and Save image are glyph buttons with identical outlines,
      // as tall as the bar's, in a row at the top right.
      final copy = find.byKey(const ValueKey('copy-reading'));
      final save = find.byKey(const ValueKey('save-reading'));
      expect(tester.getSize(copy), tester.getSize(save));
      expect(
        tester.getSize(copy).height,
        tester.getSize(find.byKey(const ValueKey('journal-button'))).height,
      );
      expect(tester.getCenter(copy).dy, tester.getCenter(save).dy);
      expect(tester.getCenter(save).dx, greaterThan(tester.getCenter(copy).dx));

      // No top bar and no lower panel: the sheet runs from under that
      // row to the bar, edge to edge but for its margin.
      final screen = tester.getRect(find.byType(ReadingScreen));
      final sheet = tester.getRect(find.byKey(const ValueKey('day-sheet')));
      expect(tester.getRect(copy).top - screen.top, lessThan(60));
      expect(sheet.top - tester.getRect(copy).bottom, lessThan(20));
      expect(screen.right - tester.getRect(save).right, lessThan(20));
      expect(sheet.left - screen.left, lessThan(20));
      expect(screen.right - sheet.right, lessThan(20));
      expect(
        tester
                .getRect(
                  find.descendant(
                    of: find.byType(ReadingScreen),
                    matching: find.byKey(const ValueKey('room-bar')),
                  ),
                )
                .top -
            sheet.bottom,
        lessThan(40),
      );
      // On a day with no reminders it is the only sheet.
      expect(find.byKey(const ValueKey('reminders-sheet')), findsNothing);

      // Under the reading, the sky. With no place set there are no rise
      // or set times, only what holds everywhere, and how to set one.
      expect(find.byKey(const ValueKey('sky-section')), findsOneWidget);
      expect(find.byKey(const ValueKey('sun-chart')), findsNothing);
      expect(find.byKey(const ValueKey('sunrise')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('next-full-moon')),
          matching: find.text('26 October 2026 · in 15 days'),
        ),
        findsOneWidget,
      );
      // How much is lit is said once, at the head.
      expect(find.byKey(const ValueKey('moon-lit')), findsNothing);
      expect(find.textContaining('depend on where you are'), findsOneWidget);
    });

    testWidgets('with a place set, the sky has the sun\'s and the moon\'s '
        'paths and their times', (tester) async {
      SkyPlace.current.value = SkyPlace.rounded(-7.8234, 110.3812);
      addTearDown(() => SkyPlace.current.value = null);
      await openDetail(tester);

      expect(find.byKey(const ValueKey('sun-chart')), findsOneWidget);
      expect(find.byKey(const ValueKey('moon-chart')), findsOneWidget);
      String valueOf(String row) => tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(ValueKey(row)),
                  matching: find.byType(Text),
                )
                .last,
          )
          .data!;
      // Yogyakarta, 11 October 2026.
      expect(valueOf('sunrise'), matches(RegExp(r'^05:1\d$')));
      expect(valueOf('sunset'), matches(RegExp(r'^17:3\d$')));
      expect(valueOf('daylight'), matches(RegExp(r'^12 h \d+ m$')));
      // A new moon rises and sets with the sun, near enough.
      expect(valueOf('moonrise'), matches(RegExp(r'^0[45]:\d\d$')));
      expect(valueOf('moonset'), matches(RegExp(r'^1[78]:\d\d$')));
      // It says which place, and that it is rounded.
      expect(
        find.textContaining('-7.8, 110.4, a position rounded to about 11 km'),
        findsOneWidget,
      );
    });

    testWidgets('a tap sets the sky\'s place from the phone, rounded', (
      tester,
    ) async {
      final phone = FakeSkyLocator();
      Locator.current = phone;
      addTearDown(() {
        Locator.current = const PhoneLocator();
        SkyPlace.current.value = null;
      });
      await openDetail(tester);
      final place = find.byKey(const ValueKey('sky-place'));
      await tester.ensureVisible(place);
      await tester.pumpAndSettle();
      await tester.tap(place);
      await tester.pumpAndSettle();

      expect(SkyPlace.current.value, (latitude: -7.6, longitude: 110.2));
      expect(find.byKey(const ValueKey('sun-chart')), findsOneWidget);
    });

    testWidgets('back returns to the month screen', (tester) async {
      await openDetail(tester);
      await tester.binding.handlePopRoute();
      // The back goes through the house to the room in front: the card
      // starts to go on the frame after.
      await tester.pump();
      await tester.pump();

      // The card is mostly gone within three frames, and off in 180 ms.
      await tester.pump(const Duration(milliseconds: 50));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(ReadingScreen),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, lessThan(0.4));
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pump();
      expect(find.byType(ReadingScreen), findsNothing);
      await tester.pumpAndSettle();

      expect(find.byType(ReadingScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('today-button')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('home closes the reading, and does nothing else', (
      tester,
    ) async {
      await openDetail(tester);
      expect(find.byType(ReadingScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('system-label')));
      await tester.pumpAndSettle();
      expect(find.byType(ReadingScreen), findsNothing);
      // The calendars' cards stay down: that is the next tap's.
      expect(find.byKey(const ValueKey('picker-done')), findsNothing);
    });

    testWidgets('Copy puts the reading on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await openDetail(tester);

      await tester.tap(find.byKey(const ValueKey('copy-reading')));
      await tester.pump();
      await tester.pump();
      expect(
        copied,
        '11 October 2026\n'
        'Moon: Waxing Crescent · 0%\n'
        'Weton: Minggu Legi · neptu 10\n'
        'Javanese: 28 Bakdamulud 1960 Be\n'
        'Mangsa: 24 Kapat 172 · Labuh\n'
        "Hijri: 28 Rabi' al-Thani 1448 AH\n"
        'Chinese: 陽土 丙午年九月初二 · Fire Horse (火馬)\n'
        'Bazi: 丙午年 戊戌月 戊午日',
      );
      expect(find.text('Copied.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Copied.'), findsNothing);
    });

    testWidgets('Save image hands a PNG of the card to the gallery', (
      tester,
    ) async {
      Map<Object?, Object?>? saved;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('candra/gallery'),
        (call) async {
          saved = call.arguments as Map<Object?, Object?>;
          return null;
        },
      );
      await openDetail(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('save-reading')));
        for (var i = 0; i < 50 && saved == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!['name'], 'candra-2026-10-11.png');
      final bytes = saved!['bytes']! as Uint8List;
      // The PNG signature.
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(find.text('Saved to Pictures/Candra.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('outside days sit at half strength, without a layer each', (
    tester,
  ) async {
    await pumpScreen(tester);
    final faint = CalendarSystem.weton.colors.textFaint;
    Color colorOf(Finder cell) => tester.widget<Text>(cell).style!.color!;

    // 28 September leads the grid; 28 October is in the month.
    expect(colorOf(inGrid('28').first), faint.withValues(alpha: 0.5));
    expect(colorOf(inGrid('28').last), CalendarSystem.weton.colors.textPrimary);
    expect(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('Today lights up only while today is selected and on screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    bool lit() => tester
        .widget<GlyphButton>(find.byKey(const ValueKey('today-button')))
        .lit;

    expect(lit(), isTrue);

    await tester.tap(inGrid('17'));
    // The house's bar hears of it after the frame.
    await tester.pump();
    await tester.pump();
    expect(lit(), isFalse);

    await tester.tap(find.byKey(const ValueKey('today-button')));
    await tester.pumpAndSettle();
    expect(lit(), isTrue);

    await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();
    expect(lit(), isFalse);
  });

  group('language', () {
    Future<void> switchTo(WidgetTester tester, AppLanguage language) async {
      await tester.tap(find.byKey(ValueKey('language-${language.name}')));
      await tester.pumpAndSettle();
    }

    testWidgets('starts in English and shows both codes', (tester) async {
      await pumpScreen(tester);
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-button')), findsOneWidget);
    });

    testWidgets('Indonesian translates everything on the month screen', (
      tester,
    ) async {
      await pumpScreen(tester);
      await switchTo(tester, AppLanguage.id);

      expect(find.text('Oktober 2026'), findsOneWidget);
      expect(find.text('October 2026'), findsNothing);
      // Senin Selasa Rabu Kamis Jumat Sabtu Minggu.
      for (final initial in ['R', 'K', 'J']) {
        expect(find.text(initial), findsOneWidget);
      }
      expect(find.text('11 Oktober 2026'), findsOneWidget);
      expect(find.text('BULAN'), findsOneWidget);
      expect(find.text('Sabit Muda · 0%'), findsOneWidget);
      expect(find.text('IMLEK'), findsOneWidget);
      expect(chinesePart(tester, 'chinese-date'), '2 Kau Gwee 2577');
      expect(chinesePart(tester, 'chinese-zodiac'), 'Kuda Api');
      // Names in their own tradition are the same in both languages.
      expect(find.text('Minggu Legi · neptu 10'), findsOneWidget);
      expect(find.text('Pasaran'), findsOneWidget);
    });

    testWidgets('Indonesian reaches the pickers, cards and toasts', (
      tester,
    ) async {
      final controller = SystemController()..value = CalendarSystem.chinese;
      await pumpScreen(tester, controller: controller);
      await switchTo(tester, AppLanguage.id);
      expect(find.text('Kau Gwee 2577'), findsOneWidget);
      expect(find.text('Oktober – November 2026'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('system-label')));
      await tester.pumpAndSettle();
      expect(doneButton, findsOneWidget);
      expect(find.text('MASEHI'), findsOneWidget);
      expect(find.text('2 Kau Gwee 2577'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('month-button')));
      await tester.pumpAndSettle();
      expect(find.text('November'), findsOneWidget);
      expect(find.text('Desember'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('month-button')));
      await tester.pumpAndSettle();

      final hold = await tester.startGesture(tester.getCenter(systemButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      expect(
        find.text(
          'Imlek sekarang menjadi kalender bawaan '
          'dan tetap tersimpan saat aplikasi dibuka kembali.',
        ),
        findsOneWidget,
      );
      await hold.up();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('the choice is reported for saving and restored', (
      tester,
    ) async {
      final saved = <AppLanguage>[];
      await pumpScreen(
        tester,
        language: LanguageController(onChange: saved.add),
      );
      await switchTo(tester, AppLanguage.id);
      expect(saved, [AppLanguage.id]);
      await switchTo(tester, AppLanguage.id);
      expect(saved, [AppLanguage.id]);

      await pumpScreen(
        tester,
        language: LanguageController(saved: AppLanguage.id),
      );
      await tester.pumpAndSettle();
      expect(find.text('Oktober 2026'), findsOneWidget);
    });

    testWidgets('the switch cross-fades; nothing snaps', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(const ValueKey('language-id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Mid-switch both wordings are on screen, fading past each other.
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Oktober 2026'), findsOneWidget);
      expect(find.text('11 October 2026'), findsOneWidget);
      expect(find.text('11 Oktober 2026'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsNothing);
      expect(find.text('11 October 2026'), findsNothing);
    });

    testWidgets('detailed mode and the clipboard follow the language', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await pumpScreen(tester);
      await switchTo(tester, AppLanguage.id);
      await tapReading(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ReadingScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('copy-reading')));
      await tester.pump();
      await tester.pump();
      expect(
        copied,
        '11 Oktober 2026\n'
        'Bulan: Sabit Muda · 0%\n'
        'Weton: Minggu Legi · neptu 10\n'
        'Jawa: 28 Bakdamulud 1960 Be\n'
        'Mangsa: 24 Kapat 172 · Labuh\n'
        'Hijriah: 28 Rabiulakhir 1448 H\n'
        'Imlek: 陽土 2 Kau Gwee 2577 · Kuda Api (火馬)\n'
        'Bazi: 丙午年 戊戌月 戊午日',
      );
      expect(find.text('Disalin.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  group('Chinese row', () {
    // The value of the reading row as its coloured and plain runs.
    List<InlineSpan> spansOf(WidgetTester tester, Finder row) =>
        (tester.widget<Text>(row).textSpan! as TextSpan).children!;

    Finder date() => find.byKey(const ValueKey('chinese-date'));
    Finder zodiac() => find.byKey(const ValueKey('chinese-zodiac'));

    testWidgets('both languages use the Hokkien months, and no characters', (
      tester,
    ) async {
      for (final language in AppLanguage.values) {
        await pumpScreen(tester, language: LanguageController(saved: language));
        await tester.pumpAndSettle();
        expect(chinesePart(tester, 'chinese-date'), '2 Kau Gwee 2577');
        expect(
          chinesePart(tester, 'chinese-zodiac'),
          language == AppLanguage.en ? 'Fire Horse' : 'Kuda Api',
        );
      }
    });

    testWidgets('tapping the date turns it into characters, and it stays', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(date());
      await tester.pumpAndSettle();
      expect(chinesePart(tester, 'chinese-date'), '丙午年九月初二');
      // Only the date; and the detailed reading did not open.
      expect(chinesePart(tester, 'chinese-zodiac'), 'Fire Horse');
      expect(find.byType(ReadingScreen), findsNothing);

      // Another day, another language: still characters.
      await tester.tap(inGrid('17'));
      await tester.pumpAndSettle();
      expect(chinesePart(tester, 'chinese-date'), '丙午年九月初八');
      await tester.tap(find.byType(LanguageToggle));
      await tester.pumpAndSettle();
      expect(chinesePart(tester, 'chinese-date'), '丙午年九月初八');

      // Tapped again, back to words.
      await tester.tap(date());
      await tester.pumpAndSettle();
      expect(chinesePart(tester, 'chinese-date'), '8 Kau Gwee 2577');
    });

    testWidgets('tapping the shio does the same for it alone', (tester) async {
      await pumpScreen(tester);
      await tester.tap(zodiac());
      await tester.pumpAndSettle();
      expect(chinesePart(tester, 'chinese-zodiac'), '火馬');
      expect(chinesePart(tester, 'chinese-date'), '2 Kau Gwee 2577');
      expect(find.byType(ReadingScreen), findsNothing);
    });

    testWidgets('the element is coloured, in word and in character', (
      tester,
    ) async {
      await pumpScreen(tester);
      final fire = elementColors[Unsur.api];
      List<String?> coloured() => [
        for (final span in spansOf(
          tester,
          find.descendant(of: zodiac(), matching: find.byType(Text)),
        ))
          if (span.style?.color == fire) (span as TextSpan).text,
      ];
      expect(coloured(), ['Fire']);
      await tester.tap(zodiac());
      await tester.pumpAndSettle();
      expect(coloured(), ['火']);
    });

    testWidgets('the element of the day leads the row, as a coloured '
        'character', (tester) async {
      await pumpScreen(tester);
      final element = find.byKey(const ValueKey('chinese-day-element'));
      // 11 October 2026 is an earth day, 12 October too; then metal.
      expect(tester.widget<Text>(element).data, '陽土');
      expect(
        tester.widget<Text>(element).style!.color,
        elementColors[Unsur.tanah],
      );
      // To the left of the date.
      expect(
        tester.getRect(element).right,
        lessThan(tester.getRect(date()).left + 1),
      );
      await tester.tap(inGrid('13'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(element).data, '陽金');
      expect(
        tester.widget<Text>(element).style!.color,
        elementColors[Unsur.logam],
      );
    });

    testWidgets('in the Chinese calendar each cell has its day\'s element '
        'to the right of the date', (tester) async {
      await pumpScreen(
        tester,
        controller: SystemController(locked: CalendarSystem.chinese),
      );
      // The cell of 11 October: the 2nd of the Chinese month, its
      // Gregorian day and its element, an earth day, under it.
      final cell = find.text('11 陽土', findRichText: true);
      expect(cell, findsWidgets);
      // The character is in earth's colour.
      Color? colourOf(String character) {
        Color? found;
        tester.widgetList<RichText>(cell).first.text.visitChildren((span) {
          if (span is TextSpan && span.text?.trim() == character) {
            found = span.style?.color;
          }
          return true;
        });
        return found;
      }

      // Whichever month's cell is found first, dimmed or not.
      expect(colourOf('陽土')!.withValues(alpha: 1), elementColors[Unsur.tanah]);
      // The 13th is a metal day.
      expect(find.text('13 陽金', findRichText: true), findsWidgets);

      // No other calendar shows it in its cells.
      await pumpScreen(
        tester,
        controller: SystemController(locked: CalendarSystem.javanese),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 陽土', findRichText: true), findsNothing);
      expect(find.text('4 陽金', findRichText: true), findsNothing);
    });

    testWidgets('the pillars of the day are in the detailed reading only', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('BAZI'), findsNothing);

      await tapReading(tester);
      await tester.pumpAndSettle();
      expect(find.text('BAZI'), findsOneWidget);
      // Three pillars side by side, each captioned with what it is the
      // pillar of.
      Finder inBazi(String text) => find.descendant(
        of: find.byKey(const ValueKey('detail-bazi')),
        matching: find.text(text),
      );
      for (final (pillar, mark) in [('丙午', '年'), ('戊戌', '月'), ('戊午', '日')]) {
        expect(inBazi(pillar), findsOneWidget);
        expect(inBazi(mark), findsOneWidget);
      }
      // Each stem is in its element's colour: fire, earth, earth.
      Color? stem(String pillar) =>
          (spansOf(tester, inBazi(pillar)).first as TextSpan).style!.color;
      expect(stem('丙午'), elementColors[Unsur.api]);
      expect(stem('戊戌'), elementColors[Unsur.tanah]);
      expect(stem('戊午'), elementColors[Unsur.tanah]);
    });

    testWidgets('a tap anywhere else on the reading opens the detailed one', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Minggu Legi · neptu 10'));
      await tester.pumpAndSettle();
      expect(find.byType(ReadingScreen), findsOneWidget);
      // Every system, each value in two tiers.
      Finder inRow(String row, String text) => find.descendant(
        of: find.byKey(ValueKey('detail-$row')),
        matching: find.text(text),
      );
      expect(inRow('chinese', '陽土 丙午年九月初二'), findsOneWidget);
      expect(inRow('chinese', 'Fire Horse'), findsOneWidget);
      expect(inRow('hijri', "28 Rabi' al-Thani"), findsOneWidget);
      expect(inRow('hijri', '1448 AH'), findsOneWidget);
      expect(inRow('javanese', '28 Bakdamulud'), findsOneWidget);
      expect(inRow('javanese', '1960 Be'), findsOneWidget);
    });

    testWidgets('leap months and the turn of the year', (tester) async {
      expect(
        Strings.chineseHanzi(ChineseDate.of(CivilDate(2025, 7, 25))),
        '乙巳年閏六月初一',
      );
      expect(
        Strings.chineseHanzi(ChineseDate.of(CivilDate(2026, 2, 17))),
        '丙午年正月初一',
      );
      expect(
        Strings.chineseHanzi(ChineseDate.of(CivilDate(2026, 2, 16))),
        '乙巳年十二月廿九',
      );
      expect(
        Strings.chineseHanzi(ChineseDate.of(CivilDate(2026, 3, 3))),
        '丙午年正月十五',
      );
      expect(
        Strings.chineseHanzi(ChineseDate.of(CivilDate(2025, 7, 24))),
        '乙巳年六月三十',
      );
      expect(
        Strings.chineseHanzi(ChineseDate.of(CivilDate(2026, 11, 28))),
        '丙午年十月二十',
      );
    });
  });

  group('year view', () {
    Future<void> zoomOut(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('zoom-button')));
      await tester.pumpAndSettle();
    }

    // Where a month's slot sits on screen in the year grid.
    Offset slotCentre(WidgetTester tester, int month) {
      final grid = tester.getRect(find.byType(YearGrid));
      return grid.topLeft + YearGrid.slotOf(month, grid.size).center;
    }

    testWidgets('the zoom button swaps the month for the year', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(YearGrid), findsNothing);

      await zoomOut(tester);
      expect(find.byType(YearGrid), findsOneWidget);
      // The month button names the year alone, and the weekday row is gone.
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('October 2026'), findsNothing);
      expect(find.text('M').hitTestable(), findsNothing);
      expect(
        find.byKey(const ValueKey('today-button')).hitTestable(),
        findsOneWidget,
      );

      // On from the year is the day, and then the month again.
      await tester.tap(find.byKey(const ValueKey('zoom-button')));
      await tester.pumpAndSettle();
      expect(find.byType(YearGrid), findsNothing);
      await tester.tap(find.byKey(const ValueKey('zoom-button')));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('the month shrinks into its own slot', (tester) async {
      await pumpScreen(tester);
      final full = tester.getRect(find.byKey(const ValueKey('month-2026-10')));

      await tester.tap(find.byKey(const ValueKey('zoom-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 230));
      final midway = tester.getRect(
        find.byKey(const ValueKey('month-2026-10')),
      );
      // Smaller than it was, and heading for the bottom-left: October is
      // the first of the last row.
      expect(midway.width, lessThan(full.width));
      expect(midway.height, lessThan(full.height));
      expect(midway.center.dx, lessThan(full.center.dx));
      expect(midway.center.dy, greaterThan(full.center.dy));
      expect(find.byType(YearGrid), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping a mini-month zooms in to it', (tester) async {
      await pumpScreen(tester);
      await zoomOut(tester);

      await tester.tapAt(slotCentre(tester, 3));
      await tester.pumpAndSettle();
      expect(find.byType(YearGrid), findsNothing);
      expect(find.text('March 2026'), findsOneWidget);
      // The selected day is still the same day.
      expect(find.text('11 October 2026'), findsOneWidget);
    });

    testWidgets('swiping changes the year', (tester) async {
      await pumpScreen(tester);
      await zoomOut(tester);

      await tester.fling(find.byType(YearGrid), const Offset(0, -400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);

      await tester.tapAt(slotCentre(tester, 10));
      await tester.pumpAndSettle();
      expect(find.text('October 2027'), findsOneWidget);
    });

    testWidgets('pinching in zooms out, spreading zooms in on that month', (
      tester,
    ) async {
      await pumpScreen(tester);
      final grid = tester.getRect(find.byKey(const ValueKey('month-2026-10')));

      Future<void> pinch(Offset centre, {required bool inward}) async {
        final near = inward ? 120.0 : 30.0;
        final far = inward ? 30.0 : 120.0;
        final a = await tester.startGesture(centre - Offset(near, 0));
        final b = await tester.startGesture(
          centre + Offset(near, 0),
          pointer: 2,
        );
        await tester.pump();
        for (var step = 1; step <= 6; step++) {
          final reach = near + (far - near) * step / 6;
          await a.moveTo(centre - Offset(reach, 0));
          await b.moveTo(centre + Offset(reach, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await a.up();
        await b.up();
        await tester.pumpAndSettle();
      }

      await pinch(grid.center, inward: true);
      expect(find.byType(YearGrid), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);

      await pinch(slotCentre(tester, 5), inward: false);
      expect(find.byType(YearGrid), findsNothing);
      expect(find.text('May 2026'), findsOneWidget);
    });

    testWidgets('the subtitle and the reading speak for the year', (
      tester,
    ) async {
      final controller = SystemController()..value = CalendarSystem.weton;
      await pumpScreen(tester, controller: controller);
      await zoomOut(tester);

      // Weton: the weton whose returns are marked.
      expect(find.text('Minggu Legi'), findsOneWidget);
      expect(find.text('2026 · New year'), findsOneWidget);
      expect(find.text('2577 Fire Horse (火馬) · 17 February'), findsOneWidget);
      expect(find.text('1448 AH · 17 June'), findsOneWidget);
      expect(find.text('1960 Be · 17 June'), findsOneWidget);
      expect(find.text('Minggu Legi · 11 times in 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('expand-reading')), findsNothing);

      controller.value = CalendarSystem.javanese;
      await tester.pumpAndSettle();
      // The Javanese year, and the Gregorian days it spans.
      expect(find.text('1960 Be'), findsOneWidget);
      expect(find.text('June 2026 – June 2027'), findsOneWidget);

      controller.value = CalendarSystem.chinese;
      await tester.pumpAndSettle();
      expect(find.text('2577'), findsOneWidget);
      expect(find.text('February 2026 – February 2027'), findsOneWidget);

      controller.value = CalendarSystem.hijri;
      await tester.pumpAndSettle();
      expect(find.text('1448 AH'), findsOneWidget);
      expect(find.text('June 2026 – June 2027'), findsOneWidget);
    });

    testWidgets('Today and the date picker move the year', (tester) async {
      await pumpScreen(tester);
      await zoomOut(tester);
      bool lit() => tester
          .widget<GlyphButton>(find.byKey(const ValueKey('today-button')))
          .lit;
      expect(lit(), isTrue);

      await tester.fling(find.byType(YearGrid), const Offset(0, -400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);
      expect(lit(), isFalse);

      await tester.tap(find.byKey(const ValueKey('today-button')));
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOneWidget);
      expect(lit(), isTrue);

      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('picker-year')),
        const Offset(0, -72),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('month-button')));
      await tester.pumpAndSettle();
      expect(find.text('2028'), findsOneWidget);
      expect(find.text('2028 · New year'), findsOneWidget);
    });
  });

  group('locks', () {
    Future<void> hold(WidgetTester tester, Finder target) async {
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }

    Future<void> clearToast(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    final zoomButton = find.byKey(const ValueKey('zoom-button'));

    testWidgets('holding a locked system releases the lock', (tester) async {
      final saved = <CalendarSystem?>[];
      final controller = SystemController(onLock: saved.add)
        ..value = CalendarSystem.javanese;
      await pumpScreen(tester, controller: controller);

      await hold(tester, systemButton);
      expect(controller.locked, CalendarSystem.javanese);
      await clearToast(tester);

      await hold(tester, systemButton);
      expect(controller.locked, isNull);
      expect(saved, [CalendarSystem.javanese, null]);
      expect(find.text('Default calendar reset to Gregorian.'), findsOneWidget);
      // Releasing the lock does not change what is on screen.
      expect(controller.value, CalendarSystem.javanese);
      await clearToast(tester);
    });

    testWidgets('holding the zoom button locks the view on screen', (
      tester,
    ) async {
      final saved = <MonthScreenView?>[];
      await pumpScreen(tester, onLockView: saved.add);
      bool marked() => tester.widget<GlyphButton>(zoomButton).marked;
      expect(marked(), isFalse);

      // A tap still zooms, without locking.
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(find.byType(YearGrid), findsOneWidget);
      expect(saved, isEmpty);

      await hold(tester, zoomButton);
      expect(saved, [MonthScreenView.year]);
      expect(marked(), isTrue);
      expect(
        find.text('Year view is now your default and will persist on restart.'),
        findsOneWidget,
      );
      // The hold does not also zoom.
      expect(find.byType(YearGrid), findsOneWidget);
      await clearToast(tester);

      // The dot belongs to the locked view only: not the day's, nor the
      // month's, on the way round to the year again.
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(marked(), isFalse);
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(marked(), isFalse);
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(marked(), isTrue);

      await hold(tester, zoomButton);
      expect(saved, [MonthScreenView.year, null]);
      expect(marked(), isFalse);
      expect(find.text('Default view reset to month.'), findsOneWidget);
      await clearToast(tester);
    });

    testWidgets('month view can be locked too', (tester) async {
      final saved = <MonthScreenView?>[];
      await pumpScreen(tester, onLockView: saved.add);

      await hold(tester, zoomButton);
      expect(saved, [MonthScreenView.month]);
      expect(
        find.text(
          'Month view is now your default and will persist on restart.',
        ),
        findsOneWidget,
      );
      await clearToast(tester);
    });

    testWidgets('a locked year view is where the app starts', (tester) async {
      await pumpScreen(tester, lockedView: MonthScreenView.year);
      await tester.pumpAndSettle();

      expect(find.byType(YearGrid), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(tester.widget<GlyphButton>(zoomButton).marked, isTrue);

      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('with nothing locked the app starts in month view', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.byType(YearGrid), findsNothing);
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('a pressed mini-month lights up and stays lit as it opens', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      dynamic painter() => tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(YearGrid),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter;
      expect(painter().pressed, isNull);

      final grid = tester.getRect(find.byType(YearGrid));
      final march = grid.topLeft + YearGrid.slotOf(3, grid.size).center;
      final press = await tester.startGesture(march);
      await tester.pump(const Duration(milliseconds: 120));
      expect(painter().pressed, 3);

      await press.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter().pressed, 3);
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
    });
  });

  group('month button', () {
    Size button(WidgetTester tester) =>
        tester.getSize(find.byKey(const ValueKey('month-button')));

    testWidgets('keeps one size through every month of the year', (
      tester,
    ) async {
      await pumpScreen(tester);
      final october = button(tester);

      for (var step = 0; step < 12; step++) {
        await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
        await tester.pumpAndSettle();
        expect(button(tester), october);
      }
      expect(find.text('October 2027'), findsOneWidget);
    });

    testWidgets('only changes size between month and year view', (
      tester,
    ) async {
      await pumpScreen(tester);
      final month = button(tester);

      await tester.tap(find.byKey(const ValueKey('zoom-button')));
      await tester.pumpAndSettle();
      expect(button(tester).width, lessThan(month.width));

      // Round by the day view to the month again.
      await tester.tap(find.byKey(const ValueKey('zoom-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zoom-button')));
      await tester.pumpAndSettle();
      expect(button(tester), month);
    });
  });

  group('back', () {
    late List<String> platformCalls;

    Future<void> pumpWithBack(WidgetTester tester) async {
      platformCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call.method);
          return null;
        },
      );
      await pumpScreen(tester);
    }

    Future<void> pressBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pump();
    }

    bool exited() => platformCalls.contains('SystemNavigator.pop');

    testWidgets('the first press asks, the second leaves', (tester) async {
      await pumpWithBack(tester);

      await pressBack(tester);
      await tester.pumpAndSettle();
      expect(find.text('Press back again to exit.'), findsOneWidget);
      expect(exited(), isFalse);
      // The reading steps back behind it, as for any toast.
      final dimmed = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('11 October 2026'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(dimmed.opacity, lessThan(0.05));

      await pressBack(tester);
      expect(exited(), isTrue);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('waiting for the toast to go starts over', (tester) async {
      await pumpWithBack(tester);

      await pressBack(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Press back again to exit.'), findsNothing);

      await pressBack(tester);
      await tester.pumpAndSettle();
      expect(exited(), isFalse);
      expect(find.text('Press back again to exit.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('closes an open picker first', (tester) async {
      await pumpWithBack(tester);
      await tester.tap(find.byKey(const ValueKey('system-label')));
      await tester.pumpAndSettle();

      await pressBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SystemPicker), findsNothing);
      expect(find.text('Press back again to exit.'), findsNothing);
      expect(exited(), isFalse);
    });

    testWidgets('leaves detailed mode without asking', (tester) async {
      await pumpWithBack(tester);
      await tapReading(tester);
      await tester.pumpAndSettle();

      await pressBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ReadingScreen), findsNothing);
      expect(find.text('Press back again to exit.'), findsNothing);
      expect(exited(), isFalse);
    });
  });

  group('toasts', () {
    testWidgets('one at a time: the old one leaves before the new arrives', (
      tester,
    ) async {
      final controller = SystemController()..value = CalendarSystem.javanese;
      await pumpScreen(tester, controller: controller);
      const lock =
          'Javanese is now your default calendar '
          'and will persist on restart.';
      const back = 'Press back again to exit.';
      double strength(String message) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text(message),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      final hold = await tester.startGesture(tester.getCenter(systemButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await hold.up();
      await tester.pumpAndSettle();
      expect(strength(lock), 1);

      // A second toast is asked for while the first is still up.
      await tester.binding.handlePopRoute();
      await tester.pump();
      var sawLockLeaving = false;
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final lockShowing = find.text(lock).evaluate().isNotEmpty;
        final backShowing = find.text(back).evaluate().isNotEmpty;
        // Never both.
        expect(lockShowing && backShowing, isFalse);
        if (lockShowing && strength(lock) < 1) sawLockLeaving = true;
      }
      // It faded out; it did not vanish. And within about a tenth of a
      // second the new one had taken its place.
      expect(sawLockLeaving, isTrue);
      expect(find.text(lock), findsNothing);
      expect(find.text(back), findsOneWidget);

      await tester.pumpAndSettle();
      expect(strength(back), 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(back), findsNothing);
    });

    testWidgets('a picker does not wait for a toast', (tester) async {
      final controller = SystemController()..value = CalendarSystem.javanese;
      await pumpScreen(tester, controller: controller);
      const lock =
          'Javanese is now your default calendar '
          'and will persist on restart.';
      double panelStrength() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('reading-layer')),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;

      for (final open in [
        find.byKey(const ValueKey('system-label')),
        find.byKey(const ValueKey('month-button')),
      ]) {
        final hold = await tester.startGesture(tester.getCenter(systemButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await hold.up();
        await tester.pumpAndSettle();
        expect(find.text(lock), findsOneWidget);

        // The toast has seconds left when the picker is asked for.
        await tester.tap(open);
        await tester.pump();
        expect(panelStrength(), 1);
        await tester.pump(const Duration(milliseconds: 60));
        // Still leaving, not cut off...
        expect(find.text(lock), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pump();
        // ...and gone in about a tenth of a second.
        expect(find.text(lock), findsNothing);

        await tester.pumpAndSettle();
        // Back closes whichever picker it was.
        await goBack(tester);
        expect(find.byType(SystemPicker), findsNothing);
        expect(find.byType(ListWheelScrollView), findsNothing);
        // Release the lock again for the next round.
        final release = await tester.startGesture(
          tester.getCenter(systemButton),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await release.up();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }
    });
  });

  group('journal', () {
    // 11 October 2026 is a Sunday: Ritual (2 entries), Plant log (1) and
    // Dream (1) in the stand-in data.
    Future<void> openJournal(WidgetTester tester, {String? day}) async {
      await pumpScreen(tester);
      if (day != null) {
        await tester.tap(inGrid(day));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('journal-button')));
      await tester.pumpAndSettle();
    }

    // A card, found by the category name in its header strip.
    Finder cardFinder(String category) => find
        .ancestor(
          of: find.text(category),
          matching: find.byType(RepaintBoundary),
        )
        .first;

    Rect cardOf(WidgetTester tester, String category) =>
        tester.getRect(cardFinder(category));

    const names = {
      'ritual': 'RITUAL',
      'plant': 'PLANT LOG',
      'observance': 'OBSERVANCE',
      'dream': 'DREAM',
      'divination': 'DIVINATION',
    };

    // The folders, rear first: the last is the one in front.
    List<String> backToFront(WidgetTester tester) => [
      for (final child
          in tester
              .widget<Stack>(
                find
                    .descendant(
                      of: find.byType(CardStack),
                      matching: find.byType(Stack),
                    )
                    .first,
              )
              .children)
        names[(child.key! as ValueKey<String>).value]!,
    ];

    Rect tabOf(WidgetTester tester, String id) =>
        tester.getRect(find.byKey(ValueKey('tab-$id')));

    Future<void> deal(WidgetTester tester, {bool right = true}) async {
      // On the card below its entries: a swipe that starts on an entry
      // and goes left is that entry's own, for its delete button.
      await tester.flingFrom(
        tester.getRect(find.byType(CardStack)).bottomCenter -
            const Offset(0, 40),
        Offset(right ? 300 : -300, 0),
        1200,
      );
      await tester.pumpAndSettle();
    }

    String? chosenDot(WidgetTester tester, String picker) =>
        tester.widget<DotPicker>(find.byKey(ValueKey(picker))).selected;

    testWidgets('the journal button opens the selected day', (tester) async {
      await openJournal(tester);
      expect(find.byType(JournalScreen), findsOneWidget);
      expect(find.text('11 October 2026'), findsOneWidget);
      expect(find.text('Minggu Legi'), findsOneWidget);
      expect(find.byType(CardStack), findsOneWidget);

      // Back, at the journal room's own page, goes to the living room.
      await goBack(tester);
      expect(find.byType(JournalScreen), findsNothing);
      expect(find.byType(MonthScreen), findsOneWidget);
    });

    testWidgets('folders stand in one place, their tabs stepping across the '
        'top and overlapping', (tester) async {
      await openJournal(tester);
      final stack = tester.getRect(find.byType(CardStack));
      expect(backToFront(tester), ['DREAM', 'PLANT LOG', 'RITUAL']);
      for (final category in ['DREAM', 'PLANT LOG', 'RITUAL']) {
        expect(cardOf(tester, category), stack);
      }
      // The tabs keep the order of the categories, whichever is in front.
      final tabs = [
        for (final id in ['ritual', 'plant', 'dream']) tabOf(tester, id),
      ];
      for (final tab in tabs) {
        expect(tab.top, closeTo(stack.top, 0.01));
        expect(tab.height, CardStack.tabHeight);
      }
      expect(tabs.first.left, closeTo(stack.left, 0.01));
      for (var i = 0; i < tabs.length - 1; i++) {
        expect(tabs[i + 1].left, greaterThan(tabs[i].left + 40));
        expect(tabs[i + 1].left, lessThan(tabs[i].right));
      }
      expect(tabs.last.right, lessThanOrEqualTo(stack.right + 0.01));
    });

    testWidgets('the front folder is the same size and place on any day', (
      tester,
    ) async {
      // Tuesday has one folder, Saturday five.
      await openJournal(tester, day: '13');
      final alone = cardOf(tester, 'RITUAL');
      await goBack(tester);

      await tester.tap(inGrid('17'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('journal-button')));
      await tester.pumpAndSettle();
      expect(cardOf(tester, backToFront(tester).last), alone);
    });

    testWidgets('four folders stand at any time; a deal brings the next one '
        'waiting into the row', (tester) async {
      // Saturday: five categories.
      await openJournal(tester, day: '17');
      final stack = tester.getRect(find.byType(CardStack));
      List<String> tabs() => [
        for (final id in names.keys)
          if (find.byKey(ValueKey('tab-$id')).evaluate().isNotEmpty) id,
      ];
      void fourAcross() {
        final rects = [for (final id in tabs()) tabOf(tester, id)];
        expect(rects, hasLength(4));
        expect(rects.first.left, closeTo(stack.left, 0.01));
        for (var i = 0; i < 3; i++) {
          expect(rects[i + 1].left, greaterThan(rects[i].left + 40));
          expect(
            rects[i].right - rects[i + 1].left,
            closeTo(CardStack.lean, 0.01),
          );
        }
        expect(rects.last.right, lessThanOrEqualTo(stack.right));
      }

      expect(tabs(), ['ritual', 'plant', 'observance', 'dream']);
      expect(backToFront(tester).last, 'RITUAL');
      fourAcross();

      // Ritual goes to the back of the line; divination takes the place
      // left in the row, and the tabs keep the categories' order.
      await deal(tester);
      expect(tabs(), ['plant', 'observance', 'dream', 'divination']);
      expect(backToFront(tester).last, 'PLANT LOG');
      fourAcross();

      // Round it goes: five deals and it is back where it began.
      for (var i = 0; i < 4; i++) {
        await deal(tester);
        expect(tabs(), hasLength(4));
      }
      expect(tabs(), ['ritual', 'plant', 'observance', 'dream']);
      expect(backToFront(tester).last, 'RITUAL');

      // One waiting out of sight is brought forward from the picker.
      await tester.tap(find.byKey(const ValueKey('pick-divination')));
      await tester.pumpAndSettle();
      expect(backToFront(tester).last, 'DIVINATION');
      expect(tabs(), ['ritual', 'plant', 'observance', 'divination']);
      fourAcross();
    });

    testWidgets('tapping a tab brings its folder to the front', (tester) async {
      await openJournal(tester);
      expect(backToFront(tester).last, 'RITUAL');
      expect(find.text('Evening offering'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-dream')));
      await tester.pumpAndSettle();
      expect(backToFront(tester).last, 'DREAM');
      expect(find.text('Evening offering'), findsNothing);
      expect(chosenDot(tester, 'category-picker'), 'dream');
    });

    testWidgets('a tab has a dot per entry under its name, four at most', (
      tester,
    ) async {
      await openJournal(tester);
      int dots(String id) => find
          .byWidgetPredicate((w) => '${w.key}'.contains('dot-$id-'))
          .evaluate()
          .length;
      expect(dots('ritual'), 2);
      expect(dots('plant'), 1);
      expect(dots('dream'), 1);

      for (final id in ['ritual', 'plant', 'dream']) {
        final dot = tester.getRect(find.byKey(ValueKey('dot-$id-0')));
        final tab = tabOf(tester, id);
        final name = tester.getRect(find.text(names[id]!));
        expect(dot.top, greaterThanOrEqualTo(name.bottom));
        expect(dot.bottom, lessThan(tab.bottom));
        expect(dot.left, closeTo(name.left, 0.01));
      }

      // Saturday: one category has six entries.
      await goBack(tester);
      await tester.tap(inGrid('17'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('journal-button')));
      await tester.pumpAndSettle();
      final crowded = names.keys.where((id) => dots(id) == 4);
      expect(crowded, hasLength(1));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('an entry is a one-line title and three lines of text', (
      tester,
    ) async {
      await openJournal(tester);
      final title = tester.widget<Text>(find.text('Evening offering'));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(title.style!.fontSize, 14);

      final content = tester.widget<Text>(find.textContaining('Three flowers'));
      expect(content.maxLines, 3);
      expect(content.overflow, TextOverflow.ellipsis);
      expect(content.textSpan!.style!.fontSize, 12);
    });

    testWidgets('a card lists every entry of its category and scrolls', (
      tester,
    ) async {
      // Saturday's Plant log has six.
      await openJournal(tester, day: '17');
      await tester.tap(find.byKey(const ValueKey('pick-plant')));
      await tester.pumpAndSettle();
      expect(backToFront(tester).last, 'PLANT LOG');

      int listed() => find
          .byWidgetPredicate(
            (w) =>
                '${w.key}'.contains('entry-') && '${w.key}'.contains('-plant-'),
          )
          .evaluate()
          .length;
      expect(listed(), 6);

      // The last entry starts below the card's edge; dragging the card up
      // brings it into view.
      final card = cardOf(tester, 'PLANT LOG');
      final last = find.byWidgetPredicate(
        (w) =>
            '${w.key}'.contains('entry-') && '${w.key}'.endsWith("-plant-5'>]"),
      );
      expect(tester.getRect(last).bottom, greaterThan(card.bottom));
      await tester.drag(cardFinder('PLANT LOG'), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(card.bottom));
      // Scrolling up and down does not deal the card.
      expect(backToFront(tester).last, 'PLANT LOG');
    });

    testWidgets('a swipe to either side deals the front card to the back', (
      tester,
    ) async {
      await openJournal(tester);
      expect(backToFront(tester).last, 'RITUAL');

      await tester.flingFrom(
        tester.getRect(find.byType(CardStack)).bottomCenter -
            const Offset(0, 40),
        const Offset(-300, 0),
        1200,
      );
      await tester.pump();
      // Mid-deal the card is on its way out, not gone.
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('RITUAL'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(backToFront(tester), ['RITUAL', 'DREAM', 'PLANT LOG']);
      expect(chosenDot(tester, 'category-picker'), 'plant');

      await deal(tester, right: true);
      await deal(tester);
      expect(backToFront(tester).last, 'RITUAL');
      expect(chosenDot(tester, 'category-picker'), 'ritual');
    });

    testWidgets('a short drag lets the card fall back', (tester) async {
      await openJournal(tester);
      await tester.drag(find.byType(CardStack), const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(backToFront(tester).last, 'RITUAL');
    });

    testWidgets('one card: nothing to swipe', (tester) async {
      // Tuesday.
      await openJournal(tester, day: '13');
      final card = cardOf(tester, 'RITUAL');

      await deal(tester);
      expect(cardOf(tester, 'RITUAL'), card);
    });

    testWidgets('no entries: an empty card of the first category, ready to '
        'be written in', (tester) async {
      // Thursday.
      await openJournal(tester, day: '15');
      expect(find.byType(CardStack), findsOneWidget);
      expect(find.text('RITUAL'), findsOneWidget);
      expect(find.text('Nothing logged on this day.'), findsOneWidget);
      // Nothing to delete.
      expect(
        find.byKey(const ValueKey('delete-card')).hitTestable(),
        findsNothing,
      );
    });

    group('the four parts', () {
      Finder key(String name) => find.byKey(ValueKey(name));

      testWidgets('top bar, cards, lower panel and bar, in that order', (
        tester,
      ) async {
        await openJournal(tester);
        final date = tester.getRect(key('journal-date'));
        final stack = tester.getRect(find.byType(CardStack));
        final line = tester.getRect(key('panel-separator'));
        final picker = tester.getRect(key('category-picker'));
        final strip = tester.getRect(key('day-strip'));
        // The house's bar, under every room.
        final bar = tester.getRect(key('journal-button'));

        expect(date.bottom, lessThan(stack.top));
        expect(stack.bottom, lessThan(line.top));
        expect(line.bottom, lessThanOrEqualTo(picker.top));
        expect(picker.bottom, lessThanOrEqualTo(strip.top + 1));
        expect(strip.bottom, lessThan(bar.top));
        // The weton is under the date, where the month's subtitle is.
        expect(find.text('Minggu Legi'), findsOneWidget);
      });

      testWidgets('the top bar is where the month screen has it', (
        tester,
      ) async {
        await pumpScreen(tester);
        final month = tester.getRect(key('month-button'));
        await tester.tap(key('journal-button'));
        await tester.pumpAndSettle();
        final date = tester.getRect(key('journal-date'));

        expect(date.top, month.top);
        expect(date.left, month.left);
        expect(date.height, month.height);
      });

      testWidgets('the date opens the date picker in the lower panel', (
        tester,
      ) async {
        await openJournal(tester);
        await tester.tap(key('journal-date'));
        await tester.pumpAndSettle();

        expect(find.byType(DatePicker), findsOneWidget);
        expect(key('day-strip'), findsNothing);
        // The panel's buttons give way to the wheels.
        expect(key('new-entry'), findsNothing);
        expect(
          tester.getRect(find.byType(DatePicker)).top,
          greaterThan(tester.getRect(key('panel-separator')).top),
        );

        // Turning the day wheel changes the day and its cards.
        await tester.drag(key('picker-day'), const Offset(0, -36));
        await tester.pumpAndSettle();
        expect(find.text('12 October 2026'), findsOneWidget);
        expect(find.text('Senin Pahing'), findsOneWidget);

        // The date again closes it.
        await tester.tap(key('journal-date'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePicker), findsNothing);
        expect(key('day-strip'), findsOneWidget);
        expect(find.byType(JournalScreen), findsOneWidget);
      });

      testWidgets('back closes the picker before it leaves the journal', (
        tester,
      ) async {
        await openJournal(tester);
        await tester.tap(key('journal-date'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(DatePicker), findsNothing);
        expect(find.byType(JournalScreen), findsOneWidget);
      });

      testWidgets('the day strip is swiped to the next day and the last', (
        tester,
      ) async {
        await openJournal(tester);
        // A fifth of the strip is one day.
        final width = tester.getSize(key('day-strip')).width;
        await tester.drag(key('day-strip'), Offset(-width / 5, 0));
        await tester.pumpAndSettle();
        expect(find.text('12 October 2026'), findsOneWidget);
        // Monday's cards, not Sunday's: two categories, where Sunday has
        // three.
        expect(find.text('Senin Pahing'), findsOneWidget);
        expect(find.text('DREAM'), findsNothing);

        await tester.drag(key('day-strip'), Offset(2 * width / 5, 0));
        await tester.pumpAndSettle();
        expect(find.text('10 October 2026'), findsOneWidget);
        expect(find.text('Sabtu Kliwon'), findsOneWidget);
      });

      testWidgets('after a date is picked, the strip goes on from that date', (
        tester,
      ) async {
        await openJournal(tester);
        // Pick the 16th with the date picker.
        await tester.tap(key('journal-date'));
        await tester.pumpAndSettle();
        await tester.drag(key('picker-day'), const Offset(0, -36 * 5));
        await tester.pumpAndSettle();
        expect(find.text('16 October 2026'), findsOneWidget);
        await tester.tap(key('journal-date'));
        await tester.pumpAndSettle();

        // The strip is on the 16th, and a swipe goes to the 17th: not
        // back to the day the journal was opened on.
        expect(
          tester.getCenter(key('day-${CivilDate(2026, 10, 16).dayNumber}')).dx,
          moreOrLessEquals(411.4 / 2, epsilon: 1),
        );
        final width = tester.getSize(key('day-strip')).width;
        await tester.drag(key('day-strip'), Offset(-width / 5, 0));
        await tester.pumpAndSettle();
        expect(find.text('17 October 2026'), findsOneWidget);
        await tester.drag(key('day-strip'), Offset(2 * width / 5, 0));
        await tester.pumpAndSettle();
        expect(find.text('15 October 2026'), findsOneWidget);
      });

      testWidgets('the today button goes back to today, and is lit there', (
        tester,
      ) async {
        await openJournal(tester);
        // The house's today, which the journal's day answers to.
        GlyphButton today() => tester.widget<GlyphButton>(key('today-button'));
        expect(today().lit, isTrue);
        expect(today().glyph, Glyph.today);
        // Between the menu and the utilities, as in every room.
        expect(
          tester.getCenter(key('today-button')).dx,
          inExclusiveRange(
            tester.getCenter(key('menu-button')).dx,
            tester.getCenter(key('utilities-button')).dx,
          ),
        );

        // A few days off by the strip.
        final width = tester.getSize(key('day-strip')).width;
        await tester.drag(key('day-strip'), Offset(-2 * width / 5, 0));
        await tester.pumpAndSettle();
        expect(find.text('13 October 2026'), findsOneWidget);
        expect(today().lit, isFalse);
        await tester.tap(key('today-button'));
        await tester.pumpAndSettle();
        expect(find.text('11 October 2026'), findsOneWidget);
        expect(today().lit, isTrue);

        // And from far off, by the date picker.
        await tester.tap(key('journal-date'));
        await tester.pumpAndSettle();
        await tester.drag(key('picker-year'), const Offset(0, -36 * 2));
        await tester.pumpAndSettle();
        await tester.tap(key('journal-date'));
        await tester.pumpAndSettle();
        expect(find.text('11 October 2028'), findsOneWidget);
        await tester.tap(key('today-button'));
        await tester.pumpAndSettle();
        expect(find.text('11 October 2026'), findsOneWidget);
      });

      testWidgets('a day on the strip can be tapped', (tester) async {
        await openJournal(tester);
        await tester.tap(key('day-${CivilDate(2026, 10, 13).dayNumber}'));
        await tester.pumpAndSettle();
        expect(find.text('13 October 2026'), findsOneWidget);
      });

      testWidgets('the calendar follows the day the journal was left on', (
        tester,
      ) async {
        await openJournal(tester);
        final width = tester.getSize(key('day-strip')).width;
        await tester.drag(key('day-strip'), Offset(-2 * width / 5, 0));
        await tester.pumpAndSettle();
        await goBack(tester);

        expect(find.byType(JournalScreen), findsNothing);
        // The reading on the month screen is the 13th's.
        expect(find.text('13 October 2026'), findsOneWidget);
      });

      testWidgets('each entry on a card is a tile of its own', (tester) async {
        await openJournal(tester);
        final first = tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                '${w.key}'.contains('entry-') &&
                '${w.key}'.contains('-ritual-0'),
          ),
        );
        final second = tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                '${w.key}'.contains('entry-') &&
                '${w.key}'.contains('-ritual-1'),
          ),
        );
        // A gap between them, and each framed.
        expect(second.top - first.bottom, greaterThanOrEqualTo(8));
        final tile = tester.widget<Container>(
          find
              .descendant(
                of: find.byWidgetPredicate(
                  (w) =>
                      '${w.key}'.contains('entry-') &&
                      '${w.key}'.contains('-ritual-0'),
                ),
                matching: find.byType(Container),
              )
              .first,
        );
        expect((tile.decoration! as BoxDecoration).border, isNotNull);
      });
    });

    testWidgets('back leaves the journal without asking', (tester) async {
      await openJournal(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(JournalScreen), findsNothing);
      expect(find.text('Press back again to exit.'), findsNothing);
    });

    group('category picker', () {
      testWidgets('shows a dot per category in its colour', (tester) async {
        await openJournal(tester);
        final picker = tester.widget<DotPicker>(
          find.byKey(const ValueKey('category-picker')),
        );
        // Every category has its dot; those with nothing today are hollow.
        expect(picker.dots.map((d) => d.id), [
          'ritual',
          'plant',
          'observance',
          'dream',
          'divination',
        ]);
        expect(picker.hollow, {'observance', 'divination'});
        expect(picker.dots.first.color, categoryPalette[2]);
        expect(picker.selected, 'ritual');
        // The old counter is gone.
        expect(find.text('1 of 3'), findsNothing);
      });

      testWidgets('tapping a dot brings that card to the front, the rest '
          'following in order', (tester) async {
        // Saturday: ritual, plant, observance, dream, divination.
        await openJournal(tester, day: '17');
        await tester.tap(find.byKey(const ValueKey('pick-dream')));
        await tester.pumpAndSettle();

        // Dream leads; divination, ritual and plant follow behind it.
        expect(backToFront(tester), [
          'PLANT LOG',
          'RITUAL',
          'DIVINATION',
          'DREAM',
        ]);
        expect(chosenDot(tester, 'category-picker'), 'dream');
      });

      testWidgets('a dot is small but its tap area is not', (tester) async {
        await openJournal(tester);
        final slot = tester.getSize(find.byKey(const ValueKey('pick-plant')));
        expect(slot.width, DotPicker.slot);
        expect(slot.height, greaterThanOrEqualTo(36));
        final dot = tester.getSize(
          find.descendant(
            of: find.byKey(const ValueKey('pick-plant')),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(dot.width, lessThanOrEqualTo(8));
      });

      testWidgets('is never wider than twelve dots', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SmTheme(
              data: SmThemeData.dusk,
              child: Center(
                child: DotPicker(
                  dots: [
                    for (var i = 0; i < 20; i++)
                      (id: '$i', color: const Color(0xFFFFFFFF)),
                  ],
                  selected: '0',
                  onPick: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(DotPicker)).width,
          DotPicker.limit * DotPicker.slot,
        );
        // The rest are reached by scrolling sideways.
        expect(
          find.byKey(const ValueKey('pick-19')).hitTestable(),
          findsNothing,
        );
        await tester.drag(find.byType(DotPicker), const Offset(-400, 0));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('pick-19')).hitTestable(),
          findsOneWidget,
        );
      });
    });
  });

  group('entry screen', () {
    late String? clipboard;

    // Sunday 11 October: Ritual (2), Plant log (1), Dream (1).
    Future<void> openJournal(WidgetTester tester, {String? day}) async {
      clipboard = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboard = (call.arguments as Map)['text'] as String;
            case 'Clipboard.getData':
              return {'text': clipboard};
            case 'Clipboard.hasStrings':
              return {'value': clipboard != null};
          }
          return null;
        },
      );
      await pumpScreen(tester);
      if (day != null) {
        await tester.tap(inGrid(day));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('journal-button')));
      await tester.pumpAndSettle();
    }

    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(EditableText),
    );

    EditableText editable(WidgetTester tester, String key) =>
        tester.widget<EditableText>(field(key));

    String textOf(WidgetTester tester, String key) =>
        editable(tester, key).controller.text;

    int dots(String id) => find
        .byWidgetPredicate((w) => '${w.key}'.contains('dot-$id-'))
        .evaluate()
        .length;

    final done = find.byKey(const ValueKey('entry-done'));
    final editButton = find.byKey(const ValueKey('entry-edit'));
    final bin = find.byKey(const ValueKey('entry-delete'));

    // While a field has the focus the bar holds the format buttons, and
    // the tags and the tick floating on the sheet step out of the way;
    // they come back with the keyboard put away.
    Future<void> putKeyboardAway(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder target) async {
      // A format button further along the strip: scrolled to first.
      if (target.hitTestable().evaluate().isEmpty &&
          find
              .descendant(
                of: find.byKey(const ValueKey('format-bar')),
                matching: target,
              )
              .evaluate()
              .isNotEmpty) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }
      if (target.hitTestable().evaluate().isEmpty &&
          find.byKey(const ValueKey('format-bar')).evaluate().isNotEmpty) {
        await putKeyboardAway(tester);
      }
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    // What the entry is in: reading, with the pencil floating on the
    // sheet ('Done': nothing to save), or editing, with the tick ('Save').
    String barLabel(WidgetTester tester) {
      if (done.evaluate().isNotEmpty) {
        expect(editButton, findsNothing);
        expect(tester.widget<GlyphButton>(done).glyph, Glyph.save);
        return 'Save';
      }
      expect(tester.widget<GlyphButton>(editButton).glyph, Glyph.edit);
      return 'Done';
    }

    testWidgets('tapping an entry opens it for reading, not editing', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, find.text('Evening offering'));

      expect(find.byType(EntryScreen), findsOneWidget);
      expect(textOf(tester, 'entry-title'), 'Evening offering');
      expect(textOf(tester, 'entry-content'), startsWith('Three flowers'));
      expect(editable(tester, 'entry-title').readOnly, isTrue);
      expect(editable(tester, 'entry-content').readOnly, isTrue);
      expect(find.text('Minggu Legi · 19:30'), findsOneWidget);
      expect(find.text('RITUAL'), findsOneWidget);

      // No way back on the page: the pencil floats at the sheet's bottom
      // right, beside the tags, and the bin is a small red glyph at the
      // right of the sheet's header strip.
      expect(barLabel(tester), 'Done');
      expect(done, findsNothing);
      expect(tester.widget<GlyphButton>(bin).glyph, Glyph.delete);
      expect(tester.widget<GlyphButton>(bin).tint, DeleteCardButton.red);
      // At the sheet's top right, as far in from the top as from the
      // right, level with the category's name.
      final paper = tester.getRect(find.byKey(const ValueKey('entry-sheet')));
      final binAt = tester.getRect(bin);
      expect(
        binAt.top - paper.top,
        moreOrLessEquals(paper.right - binAt.right, epsilon: 0.5),
      );
      final sheet = tester.getRect(find.byKey(const ValueKey('entry-sheet')));
      final pencil = tester.getRect(editButton);
      final tags = tester.getRect(find.byKey(const ValueKey('entry-tags')));
      expect(sheet.contains(pencil.center), isTrue);
      expect(pencil.center.dx, greaterThan(sheet.center.dx));
      expect(pencil.center.dy, greaterThan(sheet.center.dy));
      expect(tags.center.dy, pencil.center.dy);
      expect(tags.center.dx, lessThan(pencil.center.dx));
      expect(
        tester.getCenter(bin).dx,
        greaterThan(tester.getCenter(find.text('RITUAL')).dx),
      );
      // The category cannot be changed while reading.
      expect(find.byKey(const ValueKey('entry-category-picker')), findsNothing);
    });

    testWidgets('the whole text is there to read, not cut to three lines', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, find.text('Evening offering'));
      expect(textOf(tester, 'entry-content'), endsWith('whole way through.'));
      expect(editable(tester, 'entry-content').maxLines, isNull);
    });

    testWidgets('edit turns Done into Save; Save returns to reading', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, find.text('Evening offering'));
      await tap(tester, editButton);

      await putKeyboardAway(tester);

      expect(barLabel(tester), 'Save');
      expect(editable(tester, 'entry-title').readOnly, isFalse);

      await tester.enterText(field('entry-title'), 'Dusk offering');
      await tap(tester, done);

      // Still on the entry, reading what was saved.
      expect(find.byType(EntryScreen), findsOneWidget);
      expect(barLabel(tester), 'Done');
      expect(editable(tester, 'entry-title').readOnly, isTrue);
      expect(textOf(tester, 'entry-title'), 'Dusk offering');

      // Back, while reading, leaves.
      await goBack(tester);
      expect(find.byType(EntryScreen), findsNothing);
      expect(find.text('Dusk offering'), findsOneWidget);
      expect(find.text('Evening offering'), findsNothing);
    });

    testWidgets('leaving the editor without saving restores the text', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, find.text('Evening offering'));
      await tap(tester, editButton);
      await tester.enterText(field('entry-title'), 'Something else');
      // Back, while editing, stops editing without saving.
      await goBack(tester);

      expect(find.byType(EntryScreen), findsOneWidget);
      expect(barLabel(tester), 'Done');
      expect(textOf(tester, 'entry-title'), 'Evening offering');
      await goBack(tester);
      expect(find.text('Evening offering'), findsOneWidget);
    });

    testWidgets('a new entry starts in the editor', (tester) async {
      await openJournal(tester);
      await tap(tester, find.byKey(const ValueKey('new-entry')));

      await putKeyboardAway(tester);

      expect(barLabel(tester), 'Save');
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Write here'), findsOneWidget);
      // Nothing to delete yet.
      expect(bin.hitTestable(), findsNothing);

      await tester.enterText(field('entry-title'), 'Night walk');
      await tester.enterText(field('entry-content'), 'Cold air.\nNo moon.');
      // It is written in the front card's category, and stays there:
      // nothing on this screen moves it.
      expect(find.text('RITUAL'), findsOneWidget);
      expect(find.byType(DotPicker), findsNothing);
      await putKeyboardAway(tester);
      await tap(tester, done);

      expect(barLabel(tester), 'Done');
      expect(find.text('RITUAL'), findsOneWidget);
      expect(bin.hitTestable(), findsOneWidget);

      await goBack(tester);
      // Back in the journal, on the new entry's card.
      expect(find.text('Night walk'), findsOneWidget);
      expect(dots('ritual'), 3);
      expect(
        tester
            .widget<DotPicker>(find.byKey(const ValueKey('category-picker')))
            .selected,
        'ritual',
      );
    });

    testWidgets('closing a new entry unsaved leaves nothing behind', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, find.byKey(const ValueKey('new-entry')));
      await tester.enterText(field('entry-title'), 'Half a thought');
      await goBack(tester);

      expect(find.byType(EntryScreen), findsNothing);
      expect(find.text('Half a thought'), findsNothing);
    });

    testWidgets('an empty entry is not saved: Save leaves, as cancelling '
        'would', (tester) async {
      await openJournal(tester);
      final before = tester
          .widget<JournalScope>(find.byType(JournalScope))
          .notifier!
          .allEntries()
          .length;
      await tap(tester, find.byKey(const ValueKey('new-entry')));
      // The keyboard is up: Save is the tick at the right of the bar, and
      // with nothing written it is the way out.
      await tap(tester, find.byKey(const ValueKey('entry-save')));
      expect(find.byType(EntryScreen), findsNothing);
      expect(
        tester
            .widget<JournalScope>(find.byType(JournalScope))
            .notifier!
            .allEntries(),
        hasLength(before),
      );
    });

    testWidgets('the category is chosen in the journal, before writing', (
      tester,
    ) async {
      await openJournal(tester);
      // Observance has nothing today: its dot is hollow. Choosing it puts
      // an empty Observance card at the front.
      await tap(tester, find.byKey(const ValueKey('pick-observance')));
      expect(find.text('OBSERVANCE'), findsOneWidget);
      expect(find.text('Nothing logged on this day.'), findsOneWidget);

      await tap(tester, find.byKey(const ValueKey('new-entry')));
      expect(find.text('OBSERVANCE'), findsOneWidget);
      await tester.enterText(field('entry-title'), 'Fast day');
      await tap(tester, done);
      await goBack(tester);

      expect(dots('observance'), 1);
      expect(find.text('Fast day'), findsOneWidget);
      final picker = tester.widget<DotPicker>(
        find.byKey(const ValueKey('category-picker')),
      );
      expect(picker.selected, 'observance');
      expect(picker.hollow, {'divination'});
    });

    testWidgets('reading: only the sheet, with the day and the time inside '
        'it', (tester) async {
      await openJournal(tester);
      await tap(tester, find.text('Evening offering'));

      final sheet = tester.getRect(find.byKey(const ValueKey('entry-sheet')));
      // No top bar: the sheet starts right under the status bar.
      expect(find.byKey(const ValueKey('entry-top-bar')), findsNothing);
      expect(sheet.top, lessThan(40));
      // The day, the weton and the time are in the sheet.
      final when = find.byKey(const ValueKey('entry-when'));
      expect(
        find.descendant(of: when, matching: find.text('11 October 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: when, matching: find.text('Minggu Legi · 19:30')),
        findsOneWidget,
      );
      expect(sheet.contains(tester.getCenter(when)), isTrue);
      // And the sheet runs down to the bar: no lower panel.
      expect(
        tester
                .getRect(
                  find.descendant(
                    of: find.byType(EntryScreen),
                    matching: find.byKey(const ValueKey('room-bar')),
                  ),
                )
                .top -
            sheet.bottom,
        lessThan(48),
      );
      // The selection is in the category's colour, and strong.
      expect(
        editable(tester, 'entry-content').selectionColor,
        categoryPalette[2].withValues(alpha: 0.5),
      );
    });

    testWidgets('editing: the top bar comes back above the sheet', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, find.text('Evening offering'));
      await tap(tester, editButton);

      final bar = find.byKey(const ValueKey('entry-top-bar'));
      expect(tester.getRect(bar).height, greaterThan(60));
      expect(
        find.descendant(of: bar, matching: find.text('11 October 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Minggu Legi · 19:30')),
        findsOneWidget,
      );
      // The sheet no longer repeats them, and starts below the bar.
      expect(find.byKey(const ValueKey('entry-when')), findsNothing);
      expect(
        tester.getRect(find.byKey(const ValueKey('entry-sheet'))).top,
        greaterThan(tester.getRect(bar).bottom - 1),
      );
      // Nothing moves an entry to another category.
      expect(find.byType(DotPicker), findsNothing);
    });

    testWidgets('deleting asks first', (tester) async {
      await openJournal(tester);
      await tap(tester, find.text('Midnight sitting'));

      await tap(tester, bin);
      expect(find.text('Delete this entry?'), findsOneWidget);
      expect(find.byType(EntryScreen), findsOneWidget);
      // The pencil steps out of the way; the answer is in the panel.
      expect(editButton.hitTestable(), findsNothing);
      expect(find.byKey(const ValueKey('confirm-delete')), findsOneWidget);

      // The cross takes the question back, and so does back.
      await tap(tester, find.byKey(const ValueKey('confirm-cancel')));
      expect(find.text('Delete this entry?'), findsNothing);
      expect(editButton.hitTestable(), findsOneWidget);
      await tap(tester, bin);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Delete this entry?'), findsNothing);
      expect(find.byType(EntryScreen), findsOneWidget);

      await tap(tester, bin);
      await tap(tester, find.byKey(const ValueKey('confirm-delete')));
      expect(find.byType(EntryScreen), findsNothing);
      expect(find.text('Midnight sitting'), findsNothing);
      expect(dots('ritual'), 1);
    });

    testWidgets('deleting a card\'s last entry removes the card', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, find.byKey(const ValueKey('pick-plant')));
      await tap(tester, find.text('Jasmine by the gate'));
      await tap(tester, bin);
      await tap(tester, find.byKey(const ValueKey('confirm-delete')));

      expect(find.text('PLANT LOG'), findsNothing);
      final picker = tester.widget<DotPicker>(
        find.byKey(const ValueKey('category-picker')),
      );
      // Its dot is hollow again, and the first card leads.
      expect(picker.hollow, contains('plant'));
      expect(picker.selected, 'ritual');
    });

    testWidgets('back leaves the entry without asking', (tester) async {
      await openJournal(tester);
      await tap(tester, find.text('Evening offering'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EntryScreen), findsNothing);
      expect(find.byType(JournalScreen), findsOneWidget);
    });

    group('entry picker', () {
      DotPicker picker(WidgetTester tester) =>
          tester.widget<DotPicker>(find.byKey(const ValueKey('entry-picker')));

      testWidgets('one dot per entry of the category, in its colour', (
        tester,
      ) async {
        await openJournal(tester);
        await tap(tester, find.text('Evening offering'));

        expect(picker(tester).dots, hasLength(2));
        expect(
          picker(tester).dots.every((d) => d.color == categoryPalette[2]),
          isTrue,
        );
        // Earliest first: the 19:30 entry is the first of the two.
        expect(picker(tester).selected, picker(tester).dots.first.id);
      });

      testWidgets('tapping a dot turns to that entry', (tester) async {
        await openJournal(tester);
        await tap(tester, find.text('Evening offering'));
        final other = picker(tester).dots.last.id;

        await tap(tester, find.byKey(ValueKey('pick-$other')));
        expect(textOf(tester, 'entry-title'), 'Midnight sitting');
        expect(find.text('Minggu Legi · 23:05'), findsOneWidget);
        expect(picker(tester).selected, other);
      });

      testWidgets('reaches every entry of a long day', (tester) async {
        // Saturday's Plant log has six.
        await openJournal(tester, day: '17');
        await tap(tester, find.byKey(const ValueKey('pick-plant')));
        await tap(tester, find.text('Jasmine by the gate').first);

        expect(picker(tester).dots, hasLength(6));
        await tap(
          tester,
          find.byKey(ValueKey('pick-${picker(tester).dots.last.id}')),
        );
        expect(textOf(tester, 'entry-title'), 'Frangipani');
      });

      testWidgets('is absent for an only entry and while editing', (
        tester,
      ) async {
        await openJournal(tester);
        await tap(tester, find.text('Evening offering'));
        await tap(tester, editButton);
        expect(find.byKey(const ValueKey('entry-picker')), findsNothing);
        // Out of editing, and out of the entry.
        await goBack(tester);
        await goBack(tester);

        await tap(tester, find.byKey(const ValueKey('pick-plant')));
        await tap(tester, find.text('Jasmine by the gate'));
        expect(find.byKey(const ValueKey('entry-picker')), findsNothing);
      });
    });

    group('text', () {
      Future<void> newEntryWith(WidgetTester tester, String text) async {
        await openJournal(tester);
        await tap(tester, find.byKey(const ValueKey('new-entry')));
        await tester.enterText(field('entry-content'), text);
        await tester.pump();
      }

      testWidgets('long press selects a word, with handles and a toolbar', (
        tester,
      ) async {
        await newEntryWith(tester, 'incense smoke');
        final box = tester.getRect(field('entry-content'));
        await tester.longPressAt(box.topLeft + const Offset(20, 8));
        await tester.pumpAndSettle();

        final selection = editable(
          tester,
          'entry-content',
        ).controller.selection;
        expect(selection.textInside('incense smoke'), 'incense');
        expect(find.text('Cut'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Select all'), findsOneWidget);
        // Nothing on the clipboard yet, so nothing to paste.
        expect(find.text('Paste'), findsNothing);

        // A drag handle hangs under each end of the selection.
        final handles = find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle &&
              w.child is SizedBox,
        );
        expect(handles, findsNWidgets(2));

        await tap(tester, find.text('Copy'));
        expect(clipboard, 'incense');
      });

      testWidgets('select all, cut and paste', (tester) async {
        await newEntryWith(tester, 'incense smoke');
        final box = tester.getRect(field('entry-content'));

        await tester.longPressAt(box.topLeft + const Offset(20, 8));
        await tester.pumpAndSettle();
        await tap(tester, find.text('Select all'));
        await tap(tester, find.text('Cut'));
        expect(textOf(tester, 'entry-content'), '');
        expect(clipboard, 'incense smoke');

        await tester.longPressAt(box.topLeft + const Offset(20, 8));
        await tester.pumpAndSettle();
        await tap(tester, find.text('Paste'));
        expect(textOf(tester, 'entry-content'), 'incense smoke');
      });

      group('while reading', () {
        Finder key(String name) => find.byKey(ValueKey(name));

        // Evening offering: "Three flowers, incense, a bowl of water set
        // facing east. The air was still until the second stick caught;
        // after that the smoke leaned north the whole way through."
        Future<void> holdAWord(WidgetTester tester) async {
          await openJournal(tester);
          await tap(tester, find.text('Evening offering'));
          final box = tester.getRect(field('entry-content'));
          await tester.longPressAt(box.topLeft + const Offset(20, 8));
          await tester.pumpAndSettle();
        }

        String selected(WidgetTester tester) {
          final controller = editable(tester, 'entry-content').controller;
          return controller.selection.textInside(controller.text);
        }

        testWidgets('holding a word clears the bar for what to copy', (
          tester,
        ) async {
          await holdAWord(tester);
          expect(selected(tester), 'Three');
          expect(key('copy-bar'), findsOneWidget);
          for (final unit in ['word', 'sentence', 'paragraph', 'all']) {
            expect(key('copy-$unit'), findsOneWidget);
          }
          // The choices are in the lower panel, and there is no floating
          // toolbar.
          expect(
            find.descendant(
              of: key('entry-copy-panel'),
              matching: key('copy-bar'),
            ),
            findsOneWidget,
          );
          expect(find.text('Copy'), findsNothing);
          expect(find.text('Cut'), findsNothing);
        });

        testWidgets('word, sentence, paragraph and all each copy just that', (
          tester,
        ) async {
          await holdAWord(tester);

          await tap(tester, key('copy-word'));
          expect(clipboard, 'Three');
          expect(find.text('Copied.'), findsOneWidget);

          await tap(tester, key('copy-sentence'));
          expect(
            clipboard,
            'Three flowers, incense, a bowl of water set facing east.',
          );
          // What was taken is shown selected.
          expect(selected(tester), clipboard);

          await tap(tester, key('copy-paragraph'));
          expect(clipboard, startsWith('Three flowers'));
          expect(clipboard, endsWith('the whole way through.'));

          // All is the whole entry, title first.
          await tap(tester, key('copy-all'));
          expect(clipboard, startsWith('Evening offering\n\nThree flowers'));
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
        });

        testWidgets('a tap anywhere on the page lets go of the selection', (
          tester,
        ) async {
          await holdAWord(tester);
          // Well below the words, on the empty part of the sheet.
          final sheet = tester.getRect(key('entry-sheet'));
          await tester.tapAt(sheet.bottomCenter - const Offset(0, 40));
          await tester.pumpAndSettle();

          expect(selected(tester), isEmpty);
          expect(key('copy-bar'), findsNothing);
          expect(key('entry-copy-panel'), findsNothing);
          expect(editButton.hitTestable(), findsOneWidget);
          expect(
            editable(tester, 'entry-content').showSelectionHandles,
            isFalse,
          );
        });

        testWidgets('the handles are a wide, solid target', (tester) async {
          await holdAWord(tester);
          // Each handle catches a finger well outside its disc, to the
          // sides and below, but never over the line it hangs from.
          final handles = find.byWidgetPredicate(
            (w) =>
                w is GestureDetector &&
                w.behavior == HitTestBehavior.opaque &&
                w.child is Padding &&
                (w.child! as Padding).padding ==
                    const EdgeInsets.fromLTRB(22, 2, 22, 16),
          );
          expect(handles, findsNWidgets(2));
          expect(tester.getSize(handles.first).width, greaterThanOrEqualTo(60));
        });
      });

      testWidgets('the toolbar and the bar speak Indonesian too', (
        tester,
      ) async {
        clipboard = null;
        await pumpScreen(
          tester,
          language: LanguageController(saved: AppLanguage.id),
        );
        await tap(tester, find.byKey(const ValueKey('journal-button')));
        await tap(tester, find.byKey(const ValueKey('new-entry')));
        expect(find.text('Judul'), findsOneWidget);
        await putKeyboardAway(tester);
        expect(barLabel(tester), 'Save');

        await tester.enterText(field('entry-content'), 'asap dupa');
        await tester.pump();
        final box = tester.getRect(field('entry-content'));
        await tester.longPressAt(box.topLeft + const Offset(20, 8));
        await tester.pumpAndSettle();
        expect(find.text('Salin'), findsOneWidget);
        expect(find.text('Pilih semua'), findsOneWidget);
      });
    });

    group('format bar', () {
      Finder key(String name) => find.byKey(ValueKey(name));

      Future<void> startWriting(WidgetTester tester) async {
        await openJournal(tester);
        await tap(tester, find.text('Evening offering'));
        await tap(tester, editButton);
      }

      testWidgets('takes the bar\'s place while a field has the focus', (
        tester,
      ) async {
        await openJournal(tester);
        await tap(tester, find.text('Evening offering'));
        // Reading: the house's bar.
        expect(key('format-bar'), findsNothing);
        expect(key('journal-button').hitTestable(), findsOneWidget);
        expect(editButton, findsOneWidget);

        await tap(tester, editButton);
        expect(key('format-bar'), findsOneWidget);
        for (final name in [
          'bold',
          'italic',
          'underline',
          'strike',
          'list',
          'footnote',
          'heading',
          'code',
        ]) {
          expect(key('format-$name'), findsOneWidget);
        }
        // In that order, left to right.
        final order = [
          for (final name in [
            'bold',
            'italic',
            'underline',
            'strike',
            'list',
            'footnote',
            'heading',
            'code',
          ])
            tester.getTopLeft(key('format-$name')).dx,
        ];
        expect(order, [...order]..sort());
        // Save is a tick, at the far right; the house's bar has given way,
        // and the tick floating on the sheet has stepped out of the way.
        expect(tester.widget<GlyphButton>(key('entry-save')).glyph, Glyph.save);
        expect(
          tester.getCenter(key('entry-save')).dx,
          greaterThan(tester.getCenter(key('format-bold')).dx),
        );
        expect(tester.getRect(key('entry-save')).right, lessThan(411));
        expect(done.hitTestable(), findsNothing);
        expect(editButton, findsNothing);
        expect(bin, findsNothing);
        expect(key('journal-button').hitTestable(), findsNothing);

        // Keyboard away: the house's bar again, and the tick on the sheet.
        await putKeyboardAway(tester);
        expect(key('format-bar'), findsNothing);
        expect(barLabel(tester), 'Save');
        expect(done.hitTestable(), findsOneWidget);
        expect(key('journal-button').hitTestable(), findsOneWidget);
      });

      testWidgets('a format button marks the selection and keeps the '
          'keyboard up', (tester) async {
        await startWriting(tester);
        final controller = editable(tester, 'entry-content').controller;
        controller.value = const TextEditingValue(
          text: 'Three flowers',
          selection: TextSelection(baseOffset: 6, extentOffset: 13),
        );
        await tester.pump();

        await tap(tester, key('format-bold'));
        expect(controller.text, 'Three **flowers**');
        expect(controller.selection.textInside(controller.text), 'flowers');
        expect(editable(tester, 'entry-content').focusNode.hasFocus, isTrue);
        expect(key('format-bar'), findsOneWidget);

        await tap(tester, key('format-italic'));
        expect(controller.text, 'Three ***flowers***');
        await tap(tester, key('format-bold'));
        expect(controller.text, 'Three *flowers*');
        await tap(tester, key('format-heading'));
        expect(controller.text, '# Three *flowers*');
      });

      testWidgets('the tick saves what was written, marks and all', (
        tester,
      ) async {
        await startWriting(tester);
        await tester.enterText(field('entry-content'), 'A **bold** claim');
        await tap(tester, key('entry-save'));

        // Back to reading, the words kept as written.
        expect(key('format-bar'), findsNothing);
        expect(barLabel(tester), 'Done');
        expect(textOf(tester, 'entry-content'), 'A **bold** claim');
        expect(editable(tester, 'entry-content').readOnly, isTrue);
      });

      testWidgets('the format buttons step back while the title is typed', (
        tester,
      ) async {
        await openJournal(tester);
        await tap(tester, key('new-entry'));
        // A new entry starts in its title.
        expect(key('format-bar'), findsOneWidget);
        final content = editable(tester, 'entry-content').controller;
        await tester.tap(key('format-bold'), warnIfMissed: false);
        await tester.pump();
        expect(content.text, isEmpty);
        expect(textOf(tester, 'entry-title'), isEmpty);

        await tester.tap(field('entry-content'));
        await tester.pumpAndSettle();
        await tap(tester, key('format-bold'));
        expect(content.text, '****');
        expect(content.selection.baseOffset, 2);
      });

      testWidgets('a keyboard put away with the back button brings the '
          'ordinary bar back', (tester) async {
        addTearDown(tester.view.resetViewInsets);
        await startWriting(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 1000);
        await tester.pumpAndSettle();
        expect(key('format-bar'), findsOneWidget);

        // The keyboard goes; nothing in the app was pressed.
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(key('format-bar'), findsNothing);
        expect(barLabel(tester), 'Save');
        expect(done.hitTestable(), findsOneWidget);
        expect(key('journal-button').hitTestable(), findsOneWidget);
      });

      testWidgets('a button is lit while the caret is inside what it marks, '
          'and then takes the mark off', (tester) async {
        await startWriting(tester);
        final controller = editable(tester, 'entry-content').controller;
        bool lit(String name) =>
            tester.widget<GlyphButton>(key('format-$name')).lit;

        // The caret in the middle of "bold".
        controller.value = const TextEditingValue(
          text: 'A **bold** and ~~gone~~ word',
          selection: TextSelection.collapsed(offset: 6),
        );
        await tester.pump();
        expect(lit('bold'), isTrue);
        expect(lit('italic'), isFalse);
        expect(lit('strike'), isFalse);

        await tap(tester, key('format-bold'));
        expect(controller.text, 'A bold and ~~gone~~ word');
        expect(lit('bold'), isFalse);

        // Moved into the struck word.
        controller.selection = const TextSelection.collapsed(offset: 15);
        await tester.pump();
        expect(lit('strike'), isTrue);
        await tap(tester, key('format-strike'));
        expect(controller.text, 'A bold and gone word');

        // Tapped in the middle of a plain word, it marks that word.
        controller.selection = const TextSelection.collapsed(offset: 3);
        await tester.pump();
        await tap(tester, key('format-underline'));
        expect(controller.text, 'A <u>bold</u> and gone word');
        expect(lit('underline'), isTrue);
      });

      testWidgets('the heading button says which level, and is dark at none', (
        tester,
      ) async {
        await startWriting(tester);
        final controller = editable(tester, 'entry-content').controller;
        GlyphButton heading() =>
            tester.widget<GlyphButton>(key('format-heading'));

        controller.value = const TextEditingValue(
          text: 'Title',
          selection: TextSelection.collapsed(offset: 5),
        );
        await tester.pump();
        expect(heading().lit, isFalse);
        expect(heading().badge, isNull);

        for (final level in ['1', '2', '3']) {
          await tap(tester, key('format-heading'));
          expect(heading().lit, isTrue);
          expect(heading().badge, level);
        }
        await tap(tester, key('format-heading'));
        expect(heading().lit, isFalse);
        expect(heading().badge, isNull);
        expect(controller.text, 'Title');
      });

      testWidgets('list and footnote light up too', (tester) async {
        await startWriting(tester);
        final controller = editable(tester, 'entry-content').controller;
        bool lit(String name) =>
            tester.widget<GlyphButton>(key('format-$name')).lit;

        controller.value = const TextEditingValue(
          text: 'incense',
          selection: TextSelection.collapsed(offset: 7),
        );
        await tester.pump();
        await tap(tester, key('format-list'));
        expect(controller.text, '- incense');
        expect(lit('list'), isTrue);
        await tap(tester, key('format-list'));
        expect(lit('list'), isFalse);

        // A footnote: its mark where the caret was, and a line at the foot
        // to say what it is, with the caret on it.
        await tap(tester, key('format-footnote'));
        expect(controller.text, 'incense[^1]\n\n[^1]: ');
        expect(controller.selection.baseOffset, controller.text.length);
        expect(lit('footnote'), isTrue);
        // Tapped again while on it, the mark and the line both go.
        await tap(tester, key('format-footnote'));
        expect(controller.text, 'incense');
      });

      testWidgets('the checklist button, and a touch on a box while '
          'reading ticks it and keeps it so', (tester) async {
        await startWriting(tester);
        final controller = editable(tester, 'entry-content').controller;
        controller.value = const TextEditingValue(
          text: 'incense\nflowers',
          selection: TextSelection.collapsed(offset: 2),
        );
        await tester.pump();
        await tap(tester, key('format-checklist'));
        expect(controller.text, '- [ ] incense\nflowers');
        expect(tester.widget<GlyphButton>(key('format-checklist')).lit, isTrue);
        await putKeyboardAway(tester);
        await tap(tester, done);
        expect(editButton, findsOneWidget);

        // Reading: a touch on the box ticks it, and it is saved so.
        RenderEditable field() => tester
            .state<EditableTextState>(
              find.descendant(
                of: key('entry-content'),
                matching: find.byType(EditableText),
              ),
            )
            .renderEditable;
        final box = field().localToGlobal(
          field().getLocalRectForCaret(const TextPosition(offset: 3)).center,
        );
        await tester.tapAt(box);
        await tester.pumpAndSettle();
        expect(textOf(tester, 'entry-content'), '- [x] incense\nflowers');
        final saved = tester
            .widget<JournalScope>(find.byType(JournalScope))
            .notifier!
            .allEntries()
            .firstWhere((e) => e.content.contains('incense'));
        expect(saved.content, '- [x] incense\nflowers');
      });

      testWidgets('a link to a day from the date wheels; reading, a touch '
          'on it goes to that day in the journal, and an address opens', (
        tester,
      ) async {
        final opened = <String>[];
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('candra/app'),
            null,
          ),
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('candra/app'),
          (call) async {
            if (call.method == 'open') {
              opened.add((call.arguments as Map)['url'] as String);
            }
            return true;
          },
        );
        await startWriting(tester);
        final controller = editable(tester, 'entry-content').controller;
        controller.value = const TextEditingValue(
          text: 'see ',
          selection: TextSelection.collapsed(offset: 4),
        );
        await tester.pump();
        await tap(tester, key('format-day'));
        // The keyboard down, the date wheels in the panel; the entry's own
        // day to begin with.
        expect(key('format-bar'), findsNothing);
        expect(key('entry-day-panel'), findsOneWidget);
        await tap(tester, key('entry-day-insert'));
        expect(controller.text, 'see [[2026-10-11]]');
        expect(key('entry-day-panel'), findsNothing);

        controller.text = 'see [[2026-10-04]] and https://example.org';
        await tap(tester, done);
        expect(editButton, findsOneWidget);

        RenderEditable field() => tester
            .state<EditableTextState>(
              find.descendant(
                of: key('entry-content'),
                matching: find.byType(EditableText),
              ),
            )
            .renderEditable;
        Offset onChar(int offset) => field().localToGlobal(
          field().getLocalRectForCaret(TextPosition(offset: offset)).center,
        );
        final text = textOf(tester, 'entry-content');

        // The address opens through the phone.
        await tester.tapAt(onChar(text.indexOf('example') + 2));
        await tester.pumpAndSettle();
        expect(opened, ['https://example.org']);

        // The day: the entry closes, the journal stands on it.
        await tester.tapAt(onChar(text.indexOf('2026') + 3));
        await tester.pumpAndSettle();
        expect(find.byType(EntryScreen), findsNothing);
        expect(
          find.descendant(
            of: key('journal-date'),
            matching: find.textContaining('4 October 2026'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a link to an entry from the day\'s entries under the '
          'wheels; reading, it opens that entry, or says it has gone', (
        tester,
      ) async {
        await startWriting(tester);
        final store = tester
            .widget<JournalScope>(find.byType(JournalScope))
            .notifier!;
        final controller = editable(tester, 'entry-content').controller;
        controller.value = const TextEditingValue(
          text: 'as in ',
          selection: TextSelection.collapsed(offset: 6),
        );
        await tester.pump();
        await tap(tester, key('format-day'));
        // The day's other entries, under the wheels.
        final other = store
            .entriesFor(
              CivilDate(2026, 10, 11),
              utcOffset: const Duration(hours: 7),
            )
            .firstWhere((e) => e.title != 'Evening offering');
        // The day's entries are a button away from the wheels.
        await tap(tester, key('entry-day-show-entries'));
        await tester.scrollUntilVisible(
          key('entry-day-entry-${other.id}'),
          100,
          scrollable: find
              .descendant(
                of: key('entry-day-entries'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tap(tester, key('entry-day-entry-${other.id}'));
        expect(controller.text, startsWith('as in [${other.title}](/entries/'));
        expect(controller.text, endsWith('${EntryFile.pathOf(other)})'));
        await tap(tester, done);

        RenderEditable field() => tester
            .state<EditableTextState>(
              find.descendant(
                of: key('entry-content'),
                matching: find.byType(EditableText),
              ),
            )
            .renderEditable;
        Offset onChar(int offset) => field().localToGlobal(
          field().getLocalRectForCaret(TextPosition(offset: offset)).center,
        );

        // Reading, a touch opens it over this one; back comes back.
        await tester.tapAt(onChar(8));
        await tester.pumpAndSettle();
        expect(find.byType(EntryScreen, skipOffstage: false), findsNWidgets(2));
        expect(find.text(other.title), findsWidgets);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(EntryScreen), findsOneWidget);

        // The entry gone, the link says so, and nothing is rewritten.
        store.delete(other);
        await tester.pumpAndSettle();
        await tester.tapAt(onChar(8));
        await tester.pump();
        expect(
          find.textContaining('has moved or been deleted'),
          findsOneWidget,
        );
        expect(find.byType(EntryScreen), findsOneWidget);
        expect(
          textOf(tester, 'entry-content'),
          endsWith('${EntryFile.pathOf(other)})'),
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      });

      testWidgets('Enter carries a list on', (tester) async {
        await startWriting(tester);
        await tester.enterText(field('entry-content'), '- incense');
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '- incense\n',
            selection: TextSelection.collapsed(offset: 10),
          ),
        );
        await tester.pump();
        expect(textOf(tester, 'entry-content'), '- incense\n- ');
      });
    });
  });

  group('categories', () {
    Future<void> openJournal(WidgetTester tester, {String? day}) async {
      await pumpScreen(tester);
      if (day != null) {
        await tester.tap(inGrid(day));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('journal-button')));
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Finder key(String name) => find.byKey(ValueKey(name));

    JournalStore storeOf(WidgetTester tester) =>
        tester.widget<JournalScope>(find.byType(JournalScope)).notifier!;

    Finder nameField() => find.descendant(
      of: key('category-name'),
      matching: find.byType(EditableText),
    );

    // Whether a row is open: then its own tick saves ('Save'); else the
    // list is at rest, with the plus at the bottom right ('Done').
    String barLabel(WidgetTester tester) {
      if (key('categories-done').evaluate().isNotEmpty) {
        expect(
          tester.widget<GlyphButton>(key('categories-done')).glyph,
          Glyph.save,
        );
        expect(key('category-add').hitTestable(), findsNothing);
        return 'Save';
      }
      expect(key('category-add').hitTestable(), findsOneWidget);
      return 'Done';
    }

    testWidgets('the palette has twenty-four distinct colours', (tester) async {
      expect(categoryPalette, hasLength(24));
      expect(categoryPalette.toSet(), hasLength(24));
      expect(JournalStore.maxCategories, categoryPalette.length);
    });

    testWidgets('the bar: the menu, today, the system label, '
        'reminders, the journal', (tester) async {
      await pumpScreen(tester);
      final xs = [
        for (final name in [
          'menu-button',
          'today-button',
          'system-label',
          'reminder-button',
          'journal-button',
        ])
          tester.getCenter(key(name)).dx,
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i - 1], lessThan(xs[i]));
      }
      // The label is at the very centre, the pairs mirror each other.
      expect(xs[2], moreOrLessEquals(411.4 / 2, epsilon: 0.5));
      expect(xs[2] - xs[1], moreOrLessEquals(xs[3] - xs[2], epsilon: 0.5));
      expect(xs[1] - xs[0], moreOrLessEquals(xs[4] - xs[3], epsilon: 0.5));
      expect(tester.widget<GlyphButton>(key('menu-button')).glyph, Glyph.menu);
      expect(
        tester.widget<GlyphButton>(key('reminder-button')).glyph,
        Glyph.reminder,
      );
    });

    testWidgets('the system label never reaches the buttons beside it', (
      tester,
    ) async {
      for (final language in AppLanguage.values) {
        for (final system in CalendarSystem.values) {
          await pumpScreen(
            tester,
            controller: SystemController(locked: system),
            language: LanguageController(saved: language),
          );
          await tester.pumpAndSettle();
          final label = tester.getRect(key('system-label'));
          expect(
            label.left,
            greaterThan(tester.getRect(key('today-button')).right + 8),
          );
          expect(
            label.right,
            lessThan(tester.getRect(key('reminder-button')).left - 8),
          );
        }
      }
    });

    testWidgets('the bell opens the reminders', (tester) async {
      await pumpScreen(tester);
      await tap(tester, key('reminder-button'));
      expect(find.byType(RemindersScreen), findsOneWidget);
      expect(find.text('No reminders yet.'), findsOneWidget);

      // Back, at the reminders room's own page, goes to the living room.
      await goBack(tester);
      expect(find.byType(RemindersScreen), findsNothing);
      expect(find.byType(MonthScreen), findsOneWidget);
    });

    testWidgets('the menu at the left of the bar leads to export and import', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tap(tester, key('menu-button'));
      expect(find.byType(MenuScreen), findsOneWidget);
      await tap(tester, key('menu-data'));
      expect(find.byType(JournalFileScreen), findsOneWidget);
      expect(find.text('Export and import'), findsOneWidget);

      await goBack(tester);
      expect(find.byType(JournalFileScreen), findsNothing);
      expect(find.byType(MenuScreen), findsOneWidget);
      await goBack(tester);
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(find.byType(MenuScreen), findsNothing);
    });

    testWidgets('a line parts the grid from the reading', (tester) async {
      await pumpScreen(tester);
      final line = tester.getRect(key('panel-separator'));
      expect(line.height, 1);
      expect(line.width, moreOrLessEquals(411.4, epsilon: 0.5));
      expect(
        line.top,
        greaterThan(tester.getRect(find.byType(PageView).first).bottom - 1),
      );
      expect(
        line.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(DayReading)).top + 1),
      );
    });

    testWidgets('the journal: the dots, the search, categories and the plus '
        'along the panel\'s top; delete is a red trash can at the top right; '
        'the bar is the house\'s', (tester) async {
      await openJournal(tester);
      final row = [
        for (final name in [
          'category-picker',
          'journal-search',
          'categories',
          'new-entry',
        ])
          tester.getRect(key(name)),
      ];
      for (var i = 1; i < row.length; i++) {
        expect(row[i - 1].center.dx, lessThan(row[i].center.dx));
      }
      // One row, in the lower panel, under its line.
      final line = tester.getRect(key('panel-separator'));
      for (final rect in row) {
        expect(rect.top, greaterThanOrEqualTo(line.bottom));
      }
      expect(
        tester.getCenter(key('journal-search')).dy,
        moreOrLessEquals(tester.getCenter(key('new-entry')).dy, epsilon: 0.5),
      );
      // The plus is what the screen is for: lit, at the right.
      expect(tester.widget<GlyphButton>(key('new-entry')).lit, isTrue);
      expect(row.last.right, closeTo(411.43 - 16, 0.5));
      // The house's bar, with the journal lit from behind; no way back.
      expect(doneButton, findsNothing);
      expect(tester.widget<GlyphButton>(key('journal-button')).here, isTrue);
      // The delete-card button is the red one, in the top bar.
      final trash = tester.widget<GlyphButton>(key('delete-card'));
      expect(trash.tint, DeleteCardButton.red);
      expect(trash.glyph, Glyph.delete);
      expect(trash.square, isTrue);
      expect(
        tester.getRect(key('delete-card')).bottom,
        lessThan(tester.getRect(find.byType(CardStack)).top),
      );
      expect(
        tester.getCenter(key('delete-card')).dy,
        moreOrLessEquals(tester.getCenter(key('journal-date')).dy, epsilon: 1),
      );
      expect(tester.getRect(key('delete-card')).right, closeTo(395.43, 0.1));
    });

    testWidgets('the plus writes straight into the front card\'s category', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, key('pick-dream'));
      await tap(tester, key('new-entry'));

      // No category to choose: it is already Dream.
      expect(find.byType(EntryScreen), findsOneWidget);
      expect(find.text('DREAM'), findsOneWidget);
      expect(find.byType(CategoriesScreen), findsNothing);
    });

    testWidgets('the categories button lists them; tapping one opens it for '
        'changes, never an entry', (tester) async {
      await openJournal(tester);
      await tap(tester, key('categories'));

      expect(find.byType(CategoriesScreen), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('5 / 24'), findsOneWidget);
      for (final name in [
        'Ritual',
        'Plant log',
        'Observance',
        'Dream',
        'Divination',
      ]) {
        expect(find.text(name), findsOneWidget);
      }

      await tap(tester, key('category-observance'));
      expect(find.byType(CategoriesScreen), findsOneWidget);
      expect(find.byType(EntryScreen), findsNothing);
      expect(key('category-editor'), findsOneWidget);
      expect(barLabel(tester), 'Save');
      expect(
        tester.widget<EditableText>(nameField()).controller.text,
        'Observance',
      );

      // The cross closes the row; back leaves for the journal, not for an
      // entry.
      await tap(tester, key('category-cancel'));
      expect(barLabel(tester), 'Done');
      await goBack(tester);
      expect(find.byType(CategoriesScreen), findsNothing);
      expect(find.byType(EntryScreen), findsNothing);
      expect(find.byType(JournalScreen), findsOneWidget);
    });

    testWidgets(
      'on a day with nothing, the plus starts in the first category',
      (tester) async {
        // Thursday.
        await openJournal(tester, day: '15');
        expect(key('delete-card').hitTestable(), findsNothing);
        await tap(tester, key('new-entry'));
        expect(find.byType(CategoriesScreen), findsNothing);
        expect(find.byType(EntryScreen), findsOneWidget);
        expect(find.text('RITUAL'), findsOneWidget);
      },
    );

    testWidgets('with no categories at all, the plus opens the categories', (
      tester,
    ) async {
      await openJournal(tester, day: '15');
      final store = storeOf(tester);
      for (final category in store.categories) {
        store.deleteCategory(category.id);
      }
      await tester.pumpAndSettle();
      await tap(tester, key('new-entry'));
      expect(find.byType(CategoriesScreen), findsOneWidget);
      expect(find.text('0 / 24'), findsOneWidget);
    });

    testWidgets('making a category', (tester) async {
      await openJournal(tester);
      await tap(tester, key('categories'));
      await tap(tester, key('category-add'));

      expect(key('category-editor'), findsOneWidget);
      expect(find.text('Category name'), findsOneWidget);
      expect(barLabel(tester), 'Save');
      // Nothing to delete yet.
      expect(key('category-delete').hitTestable(), findsNothing);

      // A name is required.
      await tester.tap(key('categories-done'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Give it a name first.'), findsOneWidget);

      await tester.enterText(nameField(), 'Offerings');
      await tap(tester, key('categories-done'));
      expect(barLabel(tester), 'Done');
      expect(find.text('Offerings'), findsOneWidget);
      expect(find.text('6 / 24'), findsOneWidget);

      final store = storeOf(tester);
      final made = store.categories.last;
      expect(made.name, 'Offerings');
      // It was given a colour nobody else had.
      expect(
        store.categories.where((c) => c.colorIndex == made.colorIndex),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('renaming a category renames its cards', (tester) async {
      await openJournal(tester);
      await tap(tester, key('categories'));
      await tap(tester, key('category-ritual'));
      await tester.enterText(nameField(), 'Rites');
      await tap(tester, key('categories-done'));
      await goBack(tester);

      expect(find.byType(CategoriesScreen), findsNothing);
      expect(find.text('RITES'), findsOneWidget);
      expect(find.text('RITUAL'), findsNothing);
    });

    testWidgets('choosing a free colour recolours the category', (
      tester,
    ) async {
      await openJournal(tester);
      final store = storeOf(tester);
      await tap(tester, key('categories'));
      await tap(tester, key('category-ritual'));

      final free = store.freeColor;
      await tap(tester, key('swatch-$free'));
      await tap(tester, key('categories-done'));
      expect(store.category('ritual')!.colorIndex, free);
      expect(store.category('ritual')!.color, categoryPalette[free]);
    });

    group('colour trade', () {
      Future<JournalStore> askFor(WidgetTester tester) async {
        await openJournal(tester);
        final store = storeOf(tester);
        await tap(tester, key('categories'));
        await tap(tester, key('category-ritual'));
        await tap(tester, key('swatch-${store.category('dream')!.colorIndex}'));
        await tap(tester, key('categories-done'));
        return store;
      }

      testWidgets('saving with another category\'s colour asks first', (
        tester,
      ) async {
        await openJournal(tester);
        final store = storeOf(tester);
        final ritual = store.category('ritual')!.colorIndex;
        final dream = store.category('dream')!.colorIndex;
        await tap(tester, key('categories'));
        await tap(tester, key('category-ritual'));
        await tap(tester, key('swatch-$dream'));
        // Choosing it asks nothing yet.
        expect(key('trade-question'), findsNothing);

        await tap(tester, key('categories-done'));
        expect(key('trade-question'), findsOneWidget);
        expect(find.textContaining('Dream already has this colour'), findsOne);
        expect(key('confirm-swap'), findsOneWidget);
        expect(tester.widget<BarButton>(key('confirm-swap')).label, 'Swap');
        // Answered in the body's foot, under the open row.
        expect(
          tester.getRect(key('confirm-swap')).top,
          greaterThan(tester.getRect(key('category-editor')).bottom),
        );
        // Nothing has changed hands yet.
        expect(store.category('ritual')!.colorIndex, ritual);
        expect(store.category('dream')!.colorIndex, dream);
      });

      testWidgets('Swap as offered trades the two colours', (tester) async {
        await openJournal(tester);
        final store = storeOf(tester);
        final ritual = store.category('ritual')!.colorIndex;
        final dream = store.category('dream')!.colorIndex;
        await tap(tester, key('categories'));
        await tap(tester, key('category-ritual'));
        await tap(tester, key('swatch-$dream'));
        await tap(tester, key('categories-done'));
        await tap(tester, key('confirm-swap'));

        expect(store.category('ritual')!.colorIndex, dream);
        expect(store.category('dream')!.colorIndex, ritual);
        expect(key('category-editor'), findsNothing);
        expect(barLabel(tester), 'Done');
      });

      testWidgets('the other category can be given any free colour', (
        tester,
      ) async {
        final store = await askFor(tester);
        final dream = store.category('dream')!.colorIndex;
        final ritual = store.category('ritual')!.colorIndex;
        final free = store.freeColor;
        await tap(tester, key('swatch-$free'));
        await tap(tester, key('confirm-swap'));

        expect(store.category('ritual')!.colorIndex, dream);
        expect(store.category('dream')!.colorIndex, free);
        // The colour Ritual left is nobody's now.
        expect(store.ownerOf(ritual), isNull);
      });

      testWidgets('a third category\'s colour cannot be taken in the trade', (
        tester,
      ) async {
        final store = await askFor(tester);
        final ritual = store.category('ritual')!.colorIndex;
        final plant = store.category('plant')!.colorIndex;
        await tap(tester, key('swatch-$plant'));
        await tap(tester, key('confirm-swap'));

        expect(store.category('plant')!.colorIndex, plant);
        expect(store.category('dream')!.colorIndex, ritual);
        expect(
          store.categories.map((c) => c.colorIndex).toSet(),
          hasLength(store.categories.length),
        );
      });

      testWidgets('the cross and back return to the editor, nothing changed', (
        tester,
      ) async {
        final store = await askFor(tester);
        final ritual = store.category('ritual')!.colorIndex;
        await tap(tester, key('confirm-cancel'));
        expect(key('trade-question'), findsNothing);
        expect(key('category-editor'), findsOneWidget);
        expect(barLabel(tester), 'Save');

        await tap(tester, key('categories-done'));
        expect(key('trade-question'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(key('trade-question'), findsNothing);
        expect(key('category-editor'), findsOneWidget);
        expect(store.category('ritual')!.colorIndex, ritual);
      });

      testWidgets('a new category asks the same way', (tester) async {
        await openJournal(tester);
        final store = storeOf(tester);
        final dream = store.category('dream')!.colorIndex;
        await tap(tester, key('categories'));
        await tap(tester, key('category-add'));
        await tester.enterText(nameField(), 'Offerings');
        await tap(tester, key('swatch-$dream'));
        await tap(tester, key('categories-done'));

        expect(key('trade-question'), findsOneWidget);
        expect(store.categories, hasLength(5));
        await tap(tester, key('confirm-swap'));
        expect(store.categories.last.name, 'Offerings');
        expect(store.categories.last.colorIndex, dream);
        expect(store.category('dream')!.colorIndex, isNot(dream));
        expect(store.categories.map((c) => c.colorIndex).toSet(), hasLength(6));
      });
    });

    testWidgets('the colours are in the lower panel, only while a category '
        'is open', (tester) async {
      await openJournal(tester);
      await tap(tester, key('categories'));
      expect(key('swatch-panel'), findsNothing);

      await tap(tester, key('category-ritual'));
      expect(key('swatch-grid'), findsOneWidget);
      // Below the list, above the bar.
      final panel = tester.getRect(key('swatch-panel'));
      expect(
        panel.top,
        greaterThanOrEqualTo(tester.getRect(key('category-list')).bottom - 1),
      );
      expect(
        panel.bottom,
        lessThanOrEqualTo(
          tester
                  .getRect(
                    find.descendant(
                      of: find.byType(CategoriesScreen),
                      matching: key('room-bar'),
                    ),
                  )
                  .top +
              0.5,
        ),
      );
      // The open row itself holds the name only.
      expect(
        find.descendant(of: key('category-editor'), matching: key('swatch-2')),
        findsNothing,
      );

      await tap(tester, key('category-cancel'));
      expect(key('swatch-panel'), findsNothing);
    });

    testWidgets('with the keyboard up the colours fold into one row', (
      tester,
    ) async {
      addTearDown(tester.view.resetViewInsets);
      await openJournal(tester);
      await tap(tester, key('categories'));
      await tap(tester, key('category-dream'));
      final grid = tester.getSize(key('swatch-panel')).height;

      tester.view.viewInsets = const FakeViewPadding(bottom: 1050);
      await tester.pumpAndSettle();
      expect(key('swatch-row'), findsOneWidget);
      expect(key('swatch-grid'), findsNothing);
      expect(tester.getSize(key('swatch-panel')).height, lessThan(grid / 2));
      // It scrolls sideways, and has been brought to Dream's colour.
      final dream = storeOf(tester).category('dream')!.colorIndex;
      final swatch = tester.getRect(key('swatch-$dream'));
      expect(swatch.left, greaterThanOrEqualTo(0));
      expect(swatch.right, lessThanOrEqualTo(411.5));

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(key('swatch-grid'), findsOneWidget);
    });

    testWidgets('the categories\' top bar is where the journal has it', (
      tester,
    ) async {
      await openJournal(tester);
      final date = tester.getRect(
        find.descendant(
          of: key('journal-date'),
          matching: find.text('11 October 2026'),
        ),
      );
      await tap(tester, key('categories'));
      final title = tester.getRect(find.text('Categories'));
      expect(title.top, moreOrLessEquals(date.top, epsilon: 0.5));
      expect(title.height, date.height);
      expect(find.text('5 / 24'), findsOneWidget);
    });

    testWidgets('the editor is brought above the keyboard', (tester) async {
      await openJournal(tester);
      final store = storeOf(tester);
      while (store.categories.length < 20) {
        store.addCategory('Extra ${store.categories.length}');
      }
      await tap(tester, key('categories'));
      addTearDown(tester.view.resetViewInsets);

      bool editorShows() {
        final editor = tester.getRect(key('category-editor'));
        final list = tester.getRect(key('category-list'));
        return editor.top >= list.top - 0.5 &&
            editor.bottom <= list.bottom + 0.5;
      }

      // Opening the last row for changes: it grows past the bottom.
      await tap(tester, key('category-${store.categories.last.id}'));
      expect(editorShows(), isTrue);
      await tap(tester, key('category-cancel'));

      // A new category starts below everything else.
      await tester.tap(key('category-add'));
      await tester.pumpAndSettle();
      expect(editorShows(), isTrue);

      // The keyboard rises: the editor rises with it.
      for (final height in [300.0, 700.0, 1050.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: height);
        await tester.pump();
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(editorShows(), isTrue);
      expect(tester.getRect(key('category-list')).height, lessThan(450));
    });

    testWidgets('leaving the editor unsaved changes nothing', (tester) async {
      await openJournal(tester);
      final store = storeOf(tester);
      final before = store.category('ritual')!.colorIndex;
      await tap(tester, key('categories'));
      await tap(tester, key('category-ritual'));
      await tester.enterText(nameField(), 'Something else');
      await tap(tester, key('swatch-${store.freeColor}'));
      // The cross, in the open row.
      await tap(tester, key('category-cancel'));

      expect(store.category('ritual')!.name, 'Ritual');
      expect(store.category('ritual')!.colorIndex, before);
      expect(barLabel(tester), 'Done');
    });

    group('deleting a category', () {
      testWidgets('asks first', (tester) async {
        await openJournal(tester);
        final store = storeOf(tester);
        // A category nothing has been written in.
        final empty = store.addCategory('Empty')!.id;
        await tap(tester, key('categories'));
        await tap(tester, key('category-$empty'));

        await tap(tester, key('category-delete'));
        expect(find.text('Delete the category Empty?'), findsOneWidget);
        expect(store.category(empty), isNotNull);
        expect(
          tester.widget<BarButton>(key('confirm-delete')).tint,
          dangerColor,
        );

        // An empty category goes on the first yes.
        await tap(tester, key('confirm-delete'));
        expect(store.category(empty), isNull);
        expect(find.text('5 / 24'), findsOneWidget);
        expect(find.text('Delete the category Empty?'), findsNothing);
        expect(barLabel(tester), 'Done');
      });

      testWidgets('one with entries is asked about twice, with the count', (
        tester,
      ) async {
        await openJournal(tester);
        final store = storeOf(tester);
        await tap(tester, key('categories'));
        await tap(tester, key('category-ritual'));
        await tap(tester, key('category-delete'));
        expect(find.text('Delete the category Ritual?'), findsOneWidget);

        await tap(tester, key('confirm-delete'));
        expect(store.category('ritual'), isNotNull);
        expect(
          find.text(
            'Ritual has ${store.entryCount('ritual')} entries. '
            'Delete them all along with the category?',
          ),
          findsOneWidget,
        );

        await tap(tester, key('confirm-delete'));
        expect(store.category('ritual'), isNull);
        expect(store.entryCount('ritual'), 0);
        await goBack(tester);
        expect(find.text('RITUAL'), findsNothing);
        expect(find.text('Evening offering'), findsNothing);
      });

      testWidgets('the cross and back take the question back', (tester) async {
        await openJournal(tester);
        final store = storeOf(tester);
        await tap(tester, key('categories'));
        await tap(tester, key('category-ritual'));
        await tap(tester, key('category-delete'));
        await tap(tester, key('confirm-delete'));
        await tap(tester, key('confirm-cancel'));
        expect(find.textContaining('Ritual has '), findsNothing);
        expect(key('category-editor'), findsOneWidget);

        await tap(tester, key('category-delete'));
        // Asked from the start again.
        expect(find.text('Delete the category Ritual?'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Delete the category Ritual?'), findsNothing);
        expect(key('category-editor'), findsOneWidget);
        expect(store.category('ritual'), isNotNull);
      });
    });

    testWidgets('twenty-four is the limit', (tester) async {
      await openJournal(tester);
      final store = storeOf(tester);
      while (store.canAddCategory) {
        store.addCategory('Extra ${store.categories.length}');
      }
      expect(store.categories, hasLength(24));
      expect(store.addCategory('One too many'), isNull);
      expect(store.categories.map((c) => c.colorIndex).toSet(), hasLength(24));

      await tap(tester, key('categories'));
      expect(find.text('24 / 24'), findsOneWidget);
      await tester.tap(key('category-add'));
      await tester.pump();
      await tester.pump();
      expect(find.text('24 categories is the limit.'), findsOneWidget);
      expect(key('category-editor'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('back leaves the editor before it leaves the screen', (
      tester,
    ) async {
      await openJournal(tester);
      await tap(tester, key('categories'));
      await tap(tester, key('category-ritual'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CategoriesScreen), findsOneWidget);
      expect(key('category-editor'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CategoriesScreen), findsNothing);
    });

    group('deleting a card', () {
      const question =
          'This deletes EVERY entry in Ritual on 11 October 2026: all 2 entries. '
          'To delete only one, swipe it left.';

      testWidgets('asks first, where a toast would be', (tester) async {
        await openJournal(tester);
        await tap(tester, key('delete-card'));

        expect(find.text(question), findsOneWidget);
        expect(key('confirm-delete'), findsOneWidget);
        expect(
          tester.widget<BarButton>(key('confirm-delete')).tint,
          dangerColor,
        );
        expect(key('confirm-cancel'), findsOneWidget);
        // Answered at the foot of the lower panel, where a toast would be.
        expect(
          find.descendant(
            of: key('confirm-bar'),
            matching: key('confirm-delete'),
          ),
          findsOneWidget,
        );
        expect(
          tester.getRect(key('confirm-bar')).top,
          greaterThan(tester.getRect(key('panel-separator')).bottom),
        );
        // The panel's buttons step aside, and nothing is deleted yet.
        expect(key('new-entry').hitTestable(), findsNothing);
        expect(find.text('RITUAL'), findsOneWidget);
        // The stack steps back behind the question.
        final dimmed = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(CardStack),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(dimmed.opacity, lessThan(0.05));
      });

      testWidgets('the cross takes the question back', (tester) async {
        await openJournal(tester);
        await tap(tester, key('delete-card'));
        await tap(tester, key('confirm-cancel'));

        expect(find.text(question), findsNothing);
        expect(find.text('RITUAL'), findsOneWidget);
        expect(key('new-entry').hitTestable(), findsOneWidget);
      });

      testWidgets('back takes the question back too', (tester) async {
        await openJournal(tester);
        await tap(tester, key('delete-card'));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.byType(JournalScreen), findsOneWidget);
        expect(find.text(question), findsNothing);
        expect(find.text('RITUAL'), findsOneWidget);
      });

      testWidgets('Delete removes every entry of that card, that day only', (
        tester,
      ) async {
        await openJournal(tester);
        final store = storeOf(tester);
        await tap(tester, key('delete-card'));
        await tap(tester, key('confirm-delete'));

        expect(find.text('RITUAL'), findsNothing);
        expect(find.text('Evening offering'), findsNothing);
        expect(find.text(question), findsNothing);
        // The next card leads, and the category itself is untouched.
        expect(
          tester.widget<DotPicker>(key('category-picker')).selected,
          'plant',
        );
        expect(store.category('ritual'), isNotNull);
        expect(key('new-entry'), findsOneWidget);
      });

      testWidgets('one entry is asked about as one', (tester) async {
        await openJournal(tester);
        await tap(tester, key('pick-plant'));
        await tap(tester, key('delete-card'));
        expect(
          find.textContaining(
            'This deletes EVERY entry in Plant log on 11 October 2026: 1 entry.',
          ),
          findsOneWidget,
        );
      });
    });
  });

  group('the day view', () {
    Finder key(String name) => find.byKey(ValueKey(name));
    final zoomButton = key('zoom-button');
    // 11 October 2026, the day the tests call today: a Sunday.
    final today = CivilDate(2026, 10, 11);
    Finder page(CivilDate date) => key('day-page-${date.dayNumber}');
    Finder on(CivilDate date, String text) =>
        find.descendant(of: page(date), matching: find.text(text));

    Future<void> toDay(WidgetTester tester) async {
      // Month, year, then day.
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
    }

    testWidgets('the zoom button goes round month, year and day, showing '
        'where a tap leads', (tester) async {
      await pumpScreen(tester);
      GlyphButton button() => tester.widget<GlyphButton>(zoomButton);
      expect(button().glyph, Glyph.yearView);
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(find.byType(YearGrid), findsOneWidget);
      expect(button().glyph, Glyph.dayView);
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(page(today), findsOneWidget);
      expect(find.byType(YearGrid), findsNothing);
      expect(button().glyph, Glyph.monthView);
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(key('day-view'), findsNothing);
      expect(inGrid('11').hitTestable(), findsOneWidget);
    });

    testWidgets('a sheet has the date very large, every system round it, '
        'and Sunday in red', (tester) async {
      await pumpScreen(tester);
      await toDay(tester);
      final sheet = tester.getRect(page(today));
      final number = tester.getRect(key('day-page-number'));
      // The number is the sheet: at least a fifth of its height, even
      // in the test's wide typeface.
      expect(number.height, greaterThan(sheet.height / 5));
      // As far from the last line of the corners above it as from the
      // weekday below it.
      final above =
          number.top - tester.getRect(key('day-page-javanese')).bottom;
      final below = tester.getRect(key('day-page-weekday')).top - number.bottom;
      expect(above, closeTo(below, 0.5));
      expect(above, greaterThanOrEqualTo(DayPage.numberGap));
      expect((number.center.dx - sheet.center.dx).abs(), lessThan(1));
      expect(tester.widget<Text>(key('day-page-number')).data, '11');
      // The figure and the weekday alone are in JetBrains Mono; the rest
      // of the sheet in the app's face.
      for (final name in ['day-page-number', 'day-page-weekday']) {
        expect(
          tester.widget<Text>(key(name)).style!.fontFamily,
          contains('JetBrainsMono'),
          reason: name,
        );
      }
      expect(
        tester.widget<Text>(on(today, 'OCTOBER')).style!.fontFamily,
        contains('IBMPlexMono'),
      );
      expect(
        tester.widget<Text>(key('day-page-number')).style!.color,
        DayPage.sunday,
      );
      expect(on(today, 'OCTOBER'), findsOneWidget);
      expect(on(today, '2026'), findsOneWidget);
      // Under the weton: the weekday, its pasaran and its neptu.
      expect(
        find.descendant(
          of: page(today),
          matching: find.text('MINGGU · LEGI · 10', findRichText: true),
        ),
        findsOneWidget,
      );
      // Each system in its corner, clear of the number.
      for (final system in [
        CalendarSystem.hijri,
        CalendarSystem.chinese,
        CalendarSystem.javanese,
        CalendarSystem.weton,
      ]) {
        final corner = tester.getRect(key('day-page-${system.name}'));
        expect(sheet.contains(corner.topLeft), isTrue);
        expect(sheet.contains(corner.bottomRight), isTrue);
        expect(corner.overlaps(number.deflate(8)), isFalse, reason: '$system');
      }
      expect(on(today, '28 Rabi\' al-Thani'), findsOneWidget);
      // Under the Chinese day, the day's element in full, in its colour.
      expect(on(today, '丙午年九月初二'), findsNothing);
      expect(
        tester.widget<Text>(on(today, '陽土')).style!.color,
        elementColors[Unsur.tanah],
      );
      expect(on(today, 'Minggu Legi'), findsOneWidget);
      expect(on(today, 'neptu 10'), findsOneWidget);
      // The system the calendar is set to is the one picked out.
      final accent = SmTheme.of(tester.element(page(today))).colors.accent;
      expect(on(today, 'WETON').evaluate().single.widget, isA<Text>());
      expect(tester.widget<Text>(on(today, 'WETON')).style!.color, accent);
      expect(
        tester.widget<Text>(on(today, 'HIJRI')).style!.color,
        isNot(accent),
      );
    });

    testWidgets('leafing to the next sheet selects that day, and the '
        'reading and the title follow', (tester) async {
      await pumpScreen(tester);
      await toDay(tester);
      await tester.fling(key('day-view'), const Offset(0, -300), 1500);
      await tester.pumpAndSettle();
      final next = CivilDate(2026, 10, 12);
      expect(page(next), findsOneWidget);
      // A Monday is not red.
      expect(
        tester.widget<Text>(key('day-page-number')).style!.color,
        isNot(DayPage.sunday),
      );
      // The panel below says how far that is from today.
      expect(find.text('Tomorrow'), findsOneWidget);
      // Today brings its sheet back.
      await tester.tap(key('today-button'));
      await tester.pumpAndSettle();
      expect(page(today), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // Across a month's end the title names the new month, and stepping
      // out lands on it.
      final store = tester.state(find.byType(MonthScreen));
      expect(store, isNotNull);
      for (var i = 0; i < 21; i++) {
        await tester.fling(key('day-view'), const Offset(0, -300), 1500);
        await tester.pumpAndSettle();
      }
      expect(page(CivilDate(2026, 11, 1)), findsOneWidget);
      expect(find.text('In 21 days'), findsOneWidget);
      await tester.tap(zoomButton);
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(inGrid('1', month: '2026-11').hitTestable(), findsWidgets);
    });

    testWidgets('over a sheet the picker button says how far the day is, '
        'not the month the sheet already names; the panel keeps to the '
        'year, the week and the reminders', (tester) async {
      await pumpScreen(tester);
      await toDay(tester);
      final button = key('month-button');
      expect(
        find.descendant(of: button, matching: find.text('Today')),
        findsOneWidget,
      );
      expect(find.text('October 2026'), findsNothing);
      // 11 October is the 284th day of 2026.
      expect(find.text('Day 284 of 365'), findsOneWidget);
      expect(find.text('81 days in the year'), findsOneWidget);
      expect(find.text('41 of 2026'), findsOneWidget);
      expect(find.text('BAZI'), findsNothing);
      // It still opens the wheels.
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(DatePicker), findsOneWidget);
    });

    testWidgets('the view button is anchored right of the language toggle, '
        'in the same place in every view and system', (tester) async {
      final controller = SystemController();
      await pumpScreen(tester, controller: controller);
      final place = tester.getRect(zoomButton);
      final toggle = tester.getRect(find.byType(LanguageToggle));
      expect(place.left, greaterThanOrEqualTo(toggle.right + 16));
      expect(place.right, closeTo(411.43 - 16, 0.1));
      // And what is under the header never moves when the system does,
      // whether or not the system has a subtitle.
      final grid = tester.getRect(key('month-view'));
      for (final system in CalendarSystem.values) {
        controller.value = system;
        await tester.pumpAndSettle();
        expect(tester.getRect(key('month-view')), grid, reason: '$system');
        expect(tester.getRect(zoomButton), place, reason: '$system');
      }
      for (var view = 0; view < 3; view++) {
        await tester.tap(zoomButton);
        await tester.pumpAndSettle();
        expect(tester.getRect(zoomButton), place);
      }
    });

    testWidgets('a second tap on the chosen day steps in to its sheet', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(inGrid('17'));
      await tester.pumpAndSettle();
      expect(key('day-view'), findsNothing);
      await tester.tap(inGrid('17'));
      await tester.pumpAndSettle();
      expect(page(CivilDate(2026, 10, 17)), findsOneWidget);
    });

    testWidgets('can be locked as the view to start in', (tester) async {
      final saved = <MonthScreenView?>[];
      await pumpScreen(tester, onLockView: saved.add);
      await toDay(tester);
      final gesture = await tester.startGesture(tester.getCenter(zoomButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(saved, [MonthScreenView.day]);
      expect(
        find.text('Day view is now your default and will persist on restart.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, lockedView: MonthScreenView.day);
      await tester.pumpAndSettle();
      expect(page(today), findsOneWidget);
    });

    testWidgets('under a system of its own the sheet is that system\'s: its '
        'day large, its month under it, the Gregorian in its corner', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        controller: SystemController(locked: CalendarSystem.chinese),
        lockedView: MonthScreenView.day,
      );
      await tester.pumpAndSettle();
      // 11 October 2026: the 2nd of Kau Gwee, an earth day.
      expect(tester.widget<Text>(key('day-page-number')).data, '2');
      expect(
        find.descendant(
          of: page(today),
          matching: find.text('SUNDAY · 陽土', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(on(today, 'KAU GWEE'), findsOneWidget);
      expect(on(today, '2577'), findsOneWidget);
      // The Gregorian date where the Chinese stood.
      expect(key('day-page-chinese'), findsNothing);
      expect(key('day-page-gregorian'), findsOneWidget);
      expect(on(today, '11 October'), findsOneWidget);
    });

    testWidgets('speaks Indonesian', (tester) async {
      await pumpScreen(
        tester,
        language: LanguageController(saved: AppLanguage.id),
        lockedView: MonthScreenView.day,
      );
      await tester.pumpAndSettle();
      expect(on(today, 'OKTOBER'), findsOneWidget);
      expect(
        find.descendant(
          of: page(today),
          matching: find.text('MINGGU · LEGI · 10', findRichText: true),
        ),
        findsOneWidget,
      );
    });
  });

  group('the bar and the reading, by system and by reminders', () {
    Finder key(String name) => find.byKey(ValueKey(name));

    testWidgets('a system with utilities has their button left of its own, '
        'and it brings them up in the lower panel', (tester) async {
      // Weton has none: the button stands faint, and opens nothing.
      await pumpScreen(tester);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: key('utilities-button'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0.35,
      );
      await tester.tap(key('utilities-button'));
      await tester.pumpAndSettle();
      expect(find.byType(UtilityPicker), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(
        tester,
        controller: SystemController(locked: CalendarSystem.chinese),
      );
      await tester.pumpAndSettle();
      // Beside the system's own button, on its left; the practice
      // button is left of the bell.
      final utilities = tester.getRect(key('utilities-button'));
      final bell = tester.getRect(key('reminder-button'));
      final label = tester.getRect(key('system-label'));
      expect(utilities.center.dy, bell.center.dy);
      expect(utilities.right, lessThan(label.left - 8));
      expect(
        utilities.left,
        greaterThan(tester.getRect(key('today-button')).right),
      );
      final practice = tester.getRect(key('practice-button'));
      expect(practice.right, lessThan(bell.left));
      expect(practice.left, greaterThan(label.right + 8));

      await tester.tap(key('utilities-button'));
      await tester.pumpAndSettle();
      // In the lower panel, as the systems are: a card for each, with
      // its name and a line on what it is.
      final card = tester.getRect(key('utility-bazi'));
      final line = tester.getRect(key('panel-separator'));
      expect(card.top, greaterThan(line.bottom));
      expect(card.center.dx, moreOrLessEquals(411.4 / 2, epsilon: 1));
      expect(find.text('BAZI CHART'), findsOneWidget);
      expect(find.text('The four pillars of a moment'), findsOneWidget);
      expect(key('utility-mangsa'), findsNothing);
      // No tick at the centre: nothing is chosen here. The utilities'
      // button is lit from behind while they are up, and a second tap
      // lets them down, opening nothing.
      expect(key('picker-done'), findsNothing);
      expect(key('system-label'), findsOneWidget);
      expect(tester.widget<GlyphButton>(key('utilities-button')).here, isTrue);
      await tester.tap(key('utilities-button'));
      await tester.pumpAndSettle();
      expect(tester.widget<GlyphButton>(key('utilities-button')).here, isFalse);
      expect(key('utility-bazi'), findsNothing);
      expect(find.byType(BaziScreen), findsNothing);
      // A card opens its utility, and coming back is coming back to the
      // strip of utilities, still open.
      await tester.tap(key('utilities-button'));
      await tester.pumpAndSettle();
      await tester.tap(key('utility-bazi'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BaziScreen), findsOneWidget);
      await goBack(tester);
      expect(find.byType(BaziScreen), findsNothing);
      expect(key('utility-bazi'), findsOneWidget);
    });

    testWidgets('the Javanese calendar\'s utility is the pranata mangsa, '
        'its button where the Chinese one\'s is', (tester) async {
      await pumpScreen(
        tester,
        controller: SystemController(locked: CalendarSystem.chinese),
      );
      await tester.pumpAndSettle();
      final chinese = tester.getRect(key('utilities-button'));
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(
        tester,
        controller: SystemController(locked: CalendarSystem.javanese),
        language: LanguageController(saved: AppLanguage.id),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(key('utilities-button')), chinese);
      await tester.tap(key('utilities-button'));
      await tester.pumpAndSettle();
      expect(key('utility-bazi'), findsNothing);
      expect(find.text('Tahun musim orang Jawa'), findsOneWidget);
      await tester.tap(key('utility-mangsa'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MangsaScreen), findsOneWidget);
    });

    testWidgets('the Gregorian calendar\'s utility is the sky, and the '
        'Hijri calendar\'s the prayer times', (tester) async {
      for (final (system, name, screen) in [
        (CalendarSystem.gregorian, 'sky', SkyScreen),
        (CalendarSystem.hijri, 'salat', SalatScreen),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await pumpScreen(tester, controller: SystemController(locked: system));
        await tester.pumpAndSettle();
        await tester.tap(key('utilities-button'));
        await tester.pumpAndSettle();
        expect(key('utility-bazi'), findsNothing);
        await tester.tap(key('utility-$name'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(screen), findsOneWidget);
      }
    });

    testWidgets('the day sheet no longer has a way into bazi', (tester) async {
      await pumpScreen(tester);
      await tester.tap(key('expand-reading'));
      await tester.pumpAndSettle();
      expect(find.byType(ReadingScreen), findsOneWidget);
      expect(key('open-bazi'), findsNothing);
    });

    testWidgets('a day with a reminder has a bell opposite its date, as '
        'tall as the date\'s line', (tester) async {
      await pumpScreen(tester);
      expect(key('reading-bell'), findsNothing);
      final reminders = tester
          .widget<ReminderScope>(find.byType(ReminderScope))
          .notifier!;
      reminders.save(
        Reminder(
          id: '',
          title: 'Water the plants',
          start: CivilDate(2026, 10, 11),
          minuteOfDay: 8 * 60,
          repeat: Repeat.once,
        ),
      );
      await tester.pumpAndSettle();
      final bell = tester.getRect(key('reading-bell'));
      final date = tester.getRect(find.text('11 October 2026'));
      expect(bell.height, date.height);
      expect(bell.top, date.top);
      expect(bell.left, greaterThan(date.left + 200));
      // Another day has none.
      await tester.tap(inGrid('17'));
      await tester.pumpAndSettle();
      expect(key('reading-bell'), findsNothing);
    });
  });

  group('on its side', () {
    Finder key(String name) => find.byKey(ValueKey(name));

    Future<void> pumpSideways(WidgetTester tester) async {
      // The Pixel turned: 869 x 411 logical pixels.
      tester.view.physicalSize = const Size(3040, 1440);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(),
          home: MonthScreen(
            today: CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
    }

    testWidgets('the main body takes the left at full height, and the top '
        'bar, the lower panel and the bottom bar stand in a column on the '
        'right, in that order', (tester) async {
      await pumpSideways(tester);
      final body = tester.getRect(key('month-view'));
      final line = tester.getRect(key('panel-separator'));
      final top = tester.getRect(key('month-button'));
      final panel = tester.getRect(find.byType(DayReading));
      final bar = tester.getRect(key('system-label'));

      // The body on the left, nearly the whole height.
      expect(body.right, lessThan(line.left));
      expect(body.height, greaterThan(411.43 * 0.85));
      // An upright line between the two sides.
      expect(line.width, 1);
      expect(line.height, greaterThan(400));
      // The column: an upright phone's width, on the right.
      expect(868.57 - line.right, closeTo(FourParts.columnWidth, 0.5));
      for (final part in [top, panel, bar]) {
        expect(part.left, greaterThanOrEqualTo(line.right));
      }
      // Top bar over panel over bar.
      expect(top.bottom, lessThan(panel.top));
      expect(panel.bottom, lessThanOrEqualTo(bar.top));
      // The panel has more room than it has upright.
      expect(panel.height, greaterThan(180));
      // The bar's buttons keep their places within the column.
      expect(
        tester.getRect(key('menu-button')).left,
        closeTo(line.right + 16, 0.5),
      );
      expect(
        tester.getCenter(key('system-label')).dx,
        closeTo(line.right + FourParts.columnWidth / 2, 0.5),
      );
    });

    testWidgets('turning the phone moves the parts and keeps them: the '
        'month on screen and the chosen day stay as they were', (tester) async {
      tester.view.physicalSize = const Size(1440, 3040);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(),
          home: MonthScreen(
            today: CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      // On to November, and the 17th chosen.
      await tester.fling(key('month-view'), const Offset(0, -300), 1500);
      await tester.pumpAndSettle();
      await tester.tap(inGrid('17', month: '2026-11'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);

      for (final size in const [Size(3040, 1440), Size(1440, 3040)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('November 2026'), findsOneWidget);
        expect(find.text('17 November 2026'), findsOneWidget);
        expect(inGrid('17', month: '2026-11').hitTestable(), findsOneWidget);
      }
    });

    testWidgets('typing sideways: what is being written stays above the '
        'keyboard, and the column gives up its top bar for the panel', (
      tester,
    ) async {
      await pumpSideways(tester);
      await tester.tap(key('journal-button'));
      await tester.pumpAndSettle();
      await tester.tap(key('categories'));
      await tester.pumpAndSettle();
      await tester.tap(key('category-add'));
      await tester.pumpAndSettle();
      // The keyboard, more than half the height.
      tester.view.viewInsets = const FakeViewPadding(bottom: 230 * 3.5);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const keyboardTop = 411.43 - 230;
      // The name being typed, the colours and the bar are all above it.
      expect(
        tester.getRect(key('category-name')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(
        tester.getRect(key('swatch-panel')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(
        tester.getRect(key('categories-done')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(tester.getRect(key('swatch-panel')).height, greaterThan(40));
    });

    testWidgets('the year and the day views fill the same body, and the '
        'pickers open in the column', (tester) async {
      await pumpSideways(tester);
      final line = tester.getRect(key('panel-separator'));
      await tester.tap(key('zoom-button'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(YearGrid)).right, lessThan(line.left));
      await tester.tap(key('zoom-button'));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(DayPage).first);
      expect(sheet.right, lessThan(line.left));
      expect(sheet.height, greaterThan(300));
      await tester.tap(key('month-button'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(DatePicker)).left,
        greaterThanOrEqualTo(line.right),
      );
    });
  });

  group('drawing a row to the left', () {
    Finder key(String name) => find.byKey(ValueKey(name));

    Future<void> openJournal(WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(key('journal-button'));
      await tester.pumpAndSettle();
    }

    JournalStore journalOf(WidgetTester tester) =>
        tester.widget<JournalScope>(find.byType(JournalScope)).notifier!;

    // An Android phone sets a shorter distance than Flutter's own
    // before a moving finger is a drag. The stack of cards behind the
    // entry goes by the phone's; the entry's drag must too, or the
    // stack takes every swipe first.
    testWidgets('takes hold on a phone with a short touch slop, as slowly '
        'as a finger moves', (tester) async {
      tester.view.gestureSettings = const ui.GestureSettings(
        physicalTouchSlop: 8 * 3.5,
      );
      addTearDown(tester.view.resetGestureSettings);
      await openJournal(tester);
      final journal = journalOf(tester);
      final entry = journal
          .entriesFor(
            CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          )
          .firstWhere((e) => e.title == 'Evening offering');
      final gesture = await tester.startGesture(
        tester.getCenter(key('entry-${entry.id}')),
      );
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(-2, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(key('swipe-delete-${entry.id}'), findsOneWidget);
    });

    testWidgets('shows an entry its own delete button, which asks, then '
        'deletes that entry and no other', (tester) async {
      // Every tap must land on what it means to touch.
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      await openJournal(tester);
      final journal = journalOf(tester);
      final day = CivilDate(2026, 10, 11);
      List<Entry> entries() =>
          journal.entriesFor(day, utcOffset: const Duration(hours: 7));
      final before = entries().length;
      final entry = entries().firstWhere((e) => e.title == 'Evening offering');
      final tile = key('entry-${entry.id}');
      expect(key('swipe-delete-${entry.id}'), findsNothing);

      final closed = tester.getRect(tile);
      await tester.drag(tile, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(key('swipe-delete-${entry.id}'), findsOneWidget);
      // The entry has not moved: its left edge is where it was, and its
      // right edge has come in to make room for the button beside it.
      final open = tester.getRect(tile);
      final button = tester.getRect(key('swipe-delete-${entry.id}'));
      expect(open.left, closed.left);
      expect(open.right, lessThan(closed.right));
      expect(button.left, greaterThanOrEqualTo(open.right));
      expect(button.right, lessThanOrEqualTo(closed.right));
      // A touch anywhere else on the screen closes it.
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
      expect(key('swipe-delete-${entry.id}'), findsNothing);
      expect(tester.getRect(tile), closed);
      await tester.drag(tile, const Offset(-120, 0));
      await tester.pumpAndSettle();
      // Open, a tap on the entry closes it and opens nothing. The entry
      // itself hears no touch while open: the row over it takes the tap.
      final row = find.ancestor(
        of: tile,
        matching: find.byWidgetPredicate(
          (w) => w is GestureDetector && w.child is IgnorePointer,
        ),
      );
      expect(row, findsOneWidget);
      expect(tester.getRect(row).contains(tester.getCenter(tile)), isTrue);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(EntryScreen), findsNothing);
      expect(key('swipe-delete-${entry.id}'), findsNothing);

      await tester.drag(tile, const Offset(-120, 0));
      await tester.pumpAndSettle();
      // It asks first, in the lower panel; the cross takes it back.
      await tester.tap(key('swipe-delete-${entry.id}'));
      await tester.pumpAndSettle();
      expect(entries(), hasLength(before));
      expect(key('confirm-delete'), findsOneWidget);
      await tester.tap(key('confirm-cancel'));
      await tester.pumpAndSettle();
      expect(entries(), hasLength(before));
      await tester.drag(tile, const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(key('swipe-delete-${entry.id}'));
      await tester.pumpAndSettle();
      await tester.tap(key('confirm-delete'));
      await tester.pumpAndSettle();
      expect(entries(), hasLength(before - 1));
      expect(find.text('Evening offering'), findsNothing);
    });

    testWidgets('on a category asks first, as deleting from its editor '
        'does', (tester) async {
      await openJournal(tester);
      await tester.tap(key('categories'));
      await tester.pumpAndSettle();
      final journal = journalOf(tester);
      final category = journal.categories.first;
      await tester.drag(key('category-${category.id}'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(key('swipe-delete-${category.id}'));
      await tester.pumpAndSettle();
      // Asked, not done.
      expect(journal.category(category.id), isNotNull);
      expect(key('confirm-delete'), findsOneWidget);
      await tester.tap(key('confirm-cancel'));
      await tester.pumpAndSettle();
      expect(journal.category(category.id), isNotNull);
      // Taken back: the list again, not the row's editor.
      expect(key('category-editor'), findsNothing);
      expect(key('category-add').hitTestable(), findsOneWidget);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T it) f) => f(this);
}
