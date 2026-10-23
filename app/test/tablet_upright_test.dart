import 'dart:math' as math;

import 'dart:io';

import 'package:candra/app_shell.dart';
import 'package:candra/bazi/bazi_places.dart';
import 'package:candra/bazi/bazi_screen.dart';
import 'package:candra/bazi/bazi_tables.dart';
import 'package:candra/hilal/hilal_screen.dart';
import 'package:candra/journal/categories_screen.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/light/light_screen.dart';
import 'package:candra/main.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/panel_tabs.dart';
import 'package:candra/parts.dart';
import 'package:candra/places/place_screen.dart';
import 'package:candra/planets/planets_screen.dart';
import 'package:candra/reminders/reminder_screen.dart';
import 'package:candra/reminders/reminders_screen.dart';
import 'package:candra/salat/salat_screen.dart';
import 'package:candra/search/search_screen.dart';
import 'package:candra/search/tags_ui.dart';
import 'package:candra/sky/sky_screen.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/stars/star_catalog.dart';
import 'package:candra/stars/star_screen.dart';
import 'package:candra/strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// A tablet upright (the iPad mini, 744 x 1133 points, 19 October 2026):
/// the lower panel the phone's, scaled to the width; the day's sheet the
/// phone's layout scaled; and on every device the four parts as fixed
/// segments, which a tab changed in the panel never resizes and the
/// keyboard only moves.
void main() {
  Finder key(String name) => find.byKey(ValueKey(name));
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 15);

  const tablet = Size(744, 1133);
  const tabletSideways = Size(1133, 744);
  const pixel = Size(412, 869);
  const iphone = Size(440, 956);
  // The iPad mini's keyboard upright.
  const keyboard = 320.0;
  // The smaller of the two ratios (20 October 2026): on the iPad mini the
  // heights', 1133 / 869.
  final scale = math.min(
    tablet.width / FourParts.phone.width,
    tablet.height / FourParts.phone.height,
  );

  // The main pages' panel on the iPad mini upright, with the line over
  // it, as the app lays it out on Android: the phone's 4 of 17 of what
  // the phone's bar (73 points, its line and all) leaves, scaled.
  final standardPanel = (869 - 73 - 1) * 4 / 17 * scale + 1;

  void sizeTo(WidgetTester tester, Size size) {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  void raiseKeyboard(WidgetTester tester, double height) {
    tester.view.viewInsets = FakeViewPadding(bottom: height * 2);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> pump(WidgetTester tester, Size size, Widget home) async {
    sizeTo(tester, size);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect part(WidgetTester tester, String name) =>
      tester.getRect(key('part-$name').last);

  Map<String, Rect> parts(WidgetTester tester) => {
    for (final name in const ['top', 'body', 'panel', 'bar'])
      name: part(tester, name),
  };

  testWidgets('a tablet is upright only when held so and at least 600 wide', (
    tester,
  ) async {
    final seen = <Size, bool>{};
    for (final size in const [
      tablet,
      Size(600, 960),
      tabletSideways,
      pixel,
      iphone,
      Size(507, 1133),
    ]) {
      sizeTo(tester, size);
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen[size] = FourParts.tabletUpright(context);
            return const SizedBox();
          },
        ),
      );
    }
    expect(seen, {
      tablet: true,
      const Size(600, 960): true,
      tabletSideways: false,
      pixel: false,
      iphone: false,
      // An iPad in split screen is a phone.
      const Size(507, 1133): false,
    });
  });

  group('the lower panel upright on a tablet is the phone\'s, scaled', () {
    for (final (name, home) in [
      (
        'journal',
        () => JournalScreen(date: day, utcOffset: offset, today: day),
      ),
      (
        'reminders',
        () => RemindersScreen(day: day, utcOffset: offset, today: day),
      ),
    ]) {
      testWidgets('the $name\'s day strip keeps the phone\'s proportions to '
          'the width', (tester) async {
        await pump(tester, pixel, home());
        final phonePanel = part(tester, 'panel');
        final phoneChip = tester.getRect(key('day-${day.dayNumber}'));
        final phoneNumber = tester.getRect(
          find.descendant(
            of: key('day-${day.dayNumber}'),
            matching: find.text('15'),
          ),
        );

        await pump(tester, tablet, home());
        expect(tester.takeException(), isNull);
        final panel = part(tester, 'panel');
        final chip = tester.getRect(key('day-${day.dayNumber}'));
        final number = tester.getRect(
          find.descendant(
            of: key('day-${day.dayNumber}'),
            matching: find.text('15'),
          ),
        );
        void scaled(double ipad, double phone) =>
            expect(ipad, closeTo(phone * scale, phone * scale * 0.02));
        scaled(panel.height, phonePanel.height);
        scaled(chip.height, phoneChip.height);
        scaled(number.height, phoneNumber.height);
        // Still five days across, the chosen one at the middle; each a
        // little inside its fifth (4 points either side, scaled).
        expect(chip.width, closeTo(tablet.width / 5 - 2 * 4 * scale, 2));
        expect(chip.center.dx, closeTo(tablet.width / 2, 1));
      });
    }

    testWidgets('phones and a tablet on its side are as they were', (
      tester,
    ) async {
      // Upright on a phone the panel has 4 of 17 of what the bar leaves.
      for (final size in const [pixel, iphone]) {
        await pump(
          tester,
          size,
          JournalScreen(date: day, utcOffset: offset, today: day),
        );
        final panel = part(tester, 'panel');
        final bar = part(tester, 'bar');
        expect(panel.height, closeTo((bar.top - 1) * 4 / 17, 0.5));
        expect(panel.bottom, bar.top);
      }
      await pump(
        tester,
        tabletSideways,
        JournalScreen(date: day, utcOffset: offset, today: day),
      );
      final panel = part(tester, 'panel');
      expect(panel.width, FourParts.columnWidth);
    });

    testWidgets('the search\'s panel is the phone\'s too, and gives way to '
        'the keyboard in the phone\'s measure', (tester) async {
      await pump(tester, pixel, SearchScreen(date: day, utcOffset: offset));
      final phonePanel = part(tester, 'panel');
      await pump(tester, tablet, SearchScreen(date: day, utcOffset: offset));
      final panel = part(tester, 'panel');
      expect(panel.height, closeTo(phonePanel.height * scale, 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('an editor\'s panel on a tablet upright stands as the main pages\' '
      'panel does', () {
    // Where the main pages' line over the panel stands, and the bar.
    Future<Rect> mainLine(WidgetTester tester) async {
      await pump(
        tester,
        tablet,
        JournalScreen(date: day, utcOffset: offset, today: day),
      );
      final line = tester.getRect(key('panel-separator'));
      final panel = part(tester, 'panel');
      expect(panel.height + 1, closeTo(standardPanel, 0.5));
      return line;
    }

    testWidgets('the reminder editor, every field: its panel the standard '
        'height, the wheels and lists in all of it', (tester) async {
      final line = await mainLine(tester);
      await pump(tester, tablet, ReminderScreen(day: day));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(key('field-time'));
      await tester.pumpAndSettle();
      // The standard less the panel's own line, in the screen's points.
      final room = standardPanel - scale;
      void standing(String what) {
        final panel = part(tester, 'panel');
        expect(panel.top, closeTo(line.top, 0.5), reason: what);
        expect(panel.height, closeTo(standardPanel, 0.5), reason: what);
        expect(panel.bottom, part(tester, 'bar').top, reason: what);
      }

      standing('the time');
      expect(tester.getRect(key('instrument-time')).height, closeTo(room, 1));
      for (final (tab, list) in const [
        ('reminder-anchor-sunset', 'reminder-leads'),
        ('reminder-anchor-planetaryHour', 'reminder-planets'),
        ('reminder-anchor-clock', null),
      ]) {
        await reach(tester, tab);
        await tester.tap(key(tab).hitTestable());
        await tester.pumpAndSettle();
        standing(tab);
        if (list != null) {
          // Down to the foot of the panel.
          expect(
            tester.getRect(key(list)).bottom,
            closeTo(part(tester, 'panel').bottom, 0.5),
          );
        }
      }
      for (final field in const [
        'field-start',
        'field-repeat',
        'field-category',
      ]) {
        await reach(tester, field);
        await tester.tap(key(field).hitTestable());
        await tester.pumpAndSettle();
        standing(field);
      }
      await reach(tester, 'field-repeat');
      await tester.tap(key('field-repeat').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.getRect(key('picker-repeat')).height, closeTo(room, 1));
      await tester.tap(key('reminder-tags'));
      await tester.pumpAndSettle();
      expect(key('instrument-tags'), findsOneWidget);
      standing('the tags');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the entry editor\'s date and time and its tags: the same', (
      tester,
    ) async {
      final line = await mainLine(tester);
      await pump(tester, tablet, EntryScreen(date: day, utcOffset: offset));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(key('entry-when-change'));
      await tester.pumpAndSettle();
      expect(key('entry-when-panel'), findsOneWidget);
      var panel = part(tester, 'panel');
      expect(panel.top, closeTo(line.top, 0.5));
      expect(panel.bottom, part(tester, 'bar').top);
      await tester.tap(key('entry-when-change'));
      await tester.pumpAndSettle();
      await tester.tap(key('entry-tags'));
      await tester.pumpAndSettle();
      panel = part(tester, 'panel');
      expect(
        tester.getRect(find.byType(TagPanel)).height,
        closeTo(standardPanel, 0.5),
      );
      expect(panel.top, closeTo(line.top, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the category page\'s colours stand at least as tall', (
      tester,
    ) async {
      final line = await mainLine(tester);
      await pump(tester, tablet, const CategoriesScreen());
      await tester.tap(key('category-add'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(key('swatch-grid'), findsOneWidget);
      expect(part(tester, 'panel').top, lessThan(line.top));
    });

    testWidgets('on a phone the editors keep their own panels', (tester) async {
      await pump(tester, pixel, ReminderScreen(day: day));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(key('field-time'));
      await tester.pumpAndSettle();
      expect(part(tester, 'panel').height, 181);
      await pump(tester, pixel, EntryScreen(date: day, utcOffset: offset));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(key('entry-tags'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TagPanel)).height, 190);
    });
  });

  group('the bottom bar on a tablet upright is the phone\'s, scaled and '
      'centred', () {
    const buttons = [
      'menu-button',
      'today-button',
      'utilities-button',
      'system-label',
      'practice-button',
      'reminder-button',
      'journal-button',
    ];
    Widget month() => MonthScreen(today: day, utcOffset: offset);
    Map<String, Rect> barOf(WidgetTester tester) => {
      for (final name in buttons) name: tester.getRect(key(name)),
    };
    // The glyph a button draws: the smallest picture in it.
    Rect glyphOf(WidgetTester tester, String name) => find
        .descendant(of: key(name), matching: find.byType(CustomPaint))
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .reduce((a, b) => a.width <= b.width ? a : b);

    testWidgets('its buttons, glyphs and gaps the phone\'s times the scale, '
        'about the middle', (tester) async {
      await pump(tester, pixel, month());
      final phone = barOf(tester);
      final phoneBar = part(tester, 'bar');
      final phoneGlyph = glyphOf(tester, 'today-button');

      await pump(tester, tablet, month());
      expect(tester.takeException(), isNull);
      final ipad = barOf(tester);
      final bar = part(tester, 'bar');
      void scaled(double ipad, double phone, String what) =>
          expect(ipad, closeTo(phone * scale, 0.5), reason: what);
      // The band and its line across the foot; inside it the phone's
      // bar, 412 x 1.30 = 537 wide, at the middle.
      expect(bar.width, tablet.width);
      scaled(bar.height - 1, phoneBar.height - 1, 'the bar');
      for (final name in buttons) {
        scaled(ipad[name]!.width, phone[name]!.width, name);
        scaled(ipad[name]!.height, phone[name]!.height, name);
        scaled(
          ipad[name]!.center.dx - tablet.width / 2,
          phone[name]!.center.dx - pixel.width / 2,
          name,
        );
      }
      expect(ipad['system-label']!.center.dx, closeTo(tablet.width / 2, 0.5));
      // The gaps between them.
      for (var i = 1; i < buttons.length; i++) {
        scaled(
          ipad[buttons[i]]!.left - ipad[buttons[i - 1]]!.right,
          phone[buttons[i]]!.left - phone[buttons[i - 1]]!.right,
          'before ${buttons[i]}',
        );
      }
      // The outermost buttons stand in from the phone's bar's edges, not
      // the tablet's.
      expect(
        ipad['menu-button']!.left,
        closeTo((tablet.width - pixel.width * scale) / 2 + 16 * scale, 0.5),
      );
      final glyph = glyphOf(tester, 'today-button');
      scaled(glyph.width, phoneGlyph.width, 'the glyph');
    });

    testWidgets('phones and a tablet on its side keep their bars', (
      tester,
    ) async {
      for (final size in const [pixel, iphone]) {
        await pump(tester, size, month());
        final bar = part(tester, 'bar');
        final menu = tester.getRect(key('menu-button'));
        final journal = tester.getRect(key('journal-button'));
        expect(bar.height, 73);
        expect(menu, Rect.fromLTWH(16, bar.top + 17, 40, 40));
        expect(journal.right, moreOrLessEquals(size.width - 16));
        expect(glyphOf(tester, 'today-button').size, const Size(16, 16));
      }
      await pump(tester, tabletSideways, month());
      final bar = part(tester, 'bar');
      expect(bar.width, FourParts.columnWidth);
      expect(bar.height, 73);
      final menu = tester.getRect(key('menu-button'));
      expect(menu.size, const Size(40, 40));
      expect(menu.left, bar.left + 16);
      expect(
        tester.getRect(key('journal-button')).right,
        moreOrLessEquals(bar.right - 16),
      );
    });
  });

  group('the keyboard on a tablet upright', () {
    testWidgets('a new reminder: the name above the keyboard, the bar on it', (
      tester,
    ) async {
      await pump(tester, tablet, ReminderScreen(day: day));
      raiseKeyboard(tester, keyboard);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const top = 1133 - keyboard;
      expect(tester.getRect(key('reminder-title')).bottom, lessThan(top));
      expect(part(tester, 'bar').bottom, closeTo(1133, 0.5));
      expect(tester.getRect(key('reminder-save')).bottom, lessThan(top));
    });

    testWidgets('the reminder\'s tags rise over the keyboard, as the '
        'entry\'s do', (tester) async {
      for (final size in [tablet, pixel]) {
        await pump(tester, size, ReminderScreen(day: day));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.tap(key('reminder-tags'));
        await tester.pumpAndSettle();
        expect(key('instrument-tags'), findsOneWidget);
        final kb = size == tablet ? keyboard : 300.0;
        raiseKeyboard(tester, kb);
        await tester.tap(key('reminder-title'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(key('instrument-tags'), findsOneWidget);
        final tags = tester.getRect(key('instrument-tags'));
        final bar = part(tester, 'bar');
        expect(tags.bottom, lessThanOrEqualTo(bar.top + 0.5));
        expect(tags.height, greaterThan(150));
        expect(
          tester.getRect(key('reminder-title')).bottom,
          lessThan(tags.top),
        );
        tester.view.resetViewInsets();
      }
    });

    testWidgets('an entry being written: the line in sight, the tags over '
        'the keyboard', (tester) async {
      await pump(tester, tablet, EntryScreen(date: day, utcOffset: offset));
      raiseKeyboard(tester, keyboard);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(key('entry-title')).bottom,
        lessThan(1133 - keyboard),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(key('entry-tags'));
      await tester.pumpAndSettle();
      raiseKeyboard(tester, keyboard);
      await tester.tap(key('entry-title'));
      await tester.pumpAndSettle();
      final tags = tester.getRect(find.byType(TagPanel));
      // The standard panel's height with its line (see "an editor's
      // panel ... stands as the main pages' panel does").
      expect(tags.height, closeTo(standardPanel, 1));
      expect(tags.bottom, lessThanOrEqualTo(part(tester, 'bar').top + 0.5));
      expect(part(tester, 'bar').top, lessThan(1133 - keyboard));
      expect(tester.getRect(key('entry-title')).bottom, lessThan(tags.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the category page keeps its grid of colours, keyboard or '
        'not, and nothing jumps as the keyboard rises', (tester) async {
      await pump(tester, tablet, const CategoriesScreen());
      await tester.tap(key('category-add'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(key('swatch-grid'), findsOneWidget);
      final down = tester.getRect(key('swatch-grid'));
      // The keyboard rising, frame by frame: the grid rides on the bar,
      // as tall as ever, and stays a grid.
      var last = down;
      for (var k = 20.0; k <= keyboard; k += 20) {
        raiseKeyboard(tester, k);
        await tester.pump(const Duration(milliseconds: 16));
        expect(key('swatch-row'), findsNothing);
        final grid = tester.getRect(key('swatch-grid'));
        expect(grid.height, closeTo(down.height, 0.5));
        expect(last.top - grid.top, lessThanOrEqualTo(20.5));
        last = grid;
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(key('category-name')).bottom, lessThan(last.top));
      expect(last.bottom, lessThanOrEqualTo(1133 - keyboard + 1));
    });

    testWidgets('on a phone the colours fold into a row for the keyboard, '
        'the panel easing from one height to the other', (tester) async {
      await pump(tester, pixel, const CategoriesScreen());
      await tester.tap(key('category-add'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      final grid = part(tester, 'panel');
      raiseKeyboard(tester, 300);
      final heights = <double>[];
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        heights.add(part(tester, 'panel').height);
      }
      await tester.pumpAndSettle();
      expect(key('swatch-row'), findsOneWidget);
      // Down from the grid's height to the row's, a little each frame,
      // never all at once.
      var previous = grid.height;
      for (final h in heights) {
        expect(h, lessThanOrEqualTo(previous + 0.5));
        expect(previous - h, lessThan((grid.height - heights.last) * 0.5));
        previous = h;
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the day\'s sheet upright on a tablet', () {
    Future<({Rect page, Rect number, Rect weekday, Rect corner})> dayOf(
      WidgetTester tester,
      Size size,
    ) async {
      await pump(tester, size, MonthScreen(today: day, utcOffset: offset));
      for (var i = 0; i < 3 && key('day-page-number').evaluate().isEmpty; i++) {
        await tester.tap(key('zoom-button'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final page = key('day-page-${day.dayNumber}');
      Finder inPage(String name) =>
          find.descendant(of: page, matching: key(name));
      return (
        page: tester.getRect(page),
        number: tester.getRect(inPage('day-page-number')),
        weekday: tester.getRect(inPage('day-page-weekday')),
        corner: tester.getRect(inPage('day-page-hijri')),
      );
    }

    testWidgets('is the phone\'s layout scaled whole', (tester) async {
      final phone = await dayOf(tester, pixel);
      final ipad = await dayOf(tester, tablet);
      void same(double a, double b) => expect(a, closeTo(b, b * 0.03));
      same(
        ipad.number.height / ipad.weekday.height,
        phone.number.height / phone.weekday.height,
      );
      same(
        (ipad.weekday.top - ipad.number.bottom) / ipad.number.height,
        (phone.weekday.top - phone.number.bottom) / phone.number.height,
      );
      same(
        ipad.corner.height / ipad.number.height,
        phone.corner.height / phone.number.height,
      );
      final k = ipad.weekday.height / phone.weekday.height;
      expect(k, greaterThan(1.2));
      same(ipad.number.height, phone.number.height * k);
      expect(ipad.weekday.center.dx, closeTo(ipad.number.center.dx, 1));
      expect(ipad.number.center.dx, closeTo(ipad.page.center.dx, 1));
    });
  });

  // The four parts as fixed segments, everywhere: a tab changed in the
  // panel moves none of the others, and the keyboard pushes the bar and
  // the panel up over the body without resizing anything.
  group('the four parts hold still', () {
    final tables = BaziTables.parse(
      File('assets/bazi/hidden_stems.ziping.v1.json').readAsStringSync(),
      File('assets/bazi/relations.ziping.v1.json').readAsStringSync(),
    );
    final places = BaziPlaces.parse(
      File('assets/bazi/zone_places.v1.json').readAsStringSync(),
    );
    final june = CivilDate(2026, 6, 15);
    final screens = <String, Widget Function()>{
      'star map': () => StarScreen(date: june, utcOffset: offset),
      'lintang': () =>
          StarScreen(date: june, utcOffset: offset, javanese: true),
      'light': () => LightScreen(date: june, utcOffset: offset),
      'planets': () => PlanetsScreen(date: june, utcOffset: offset),
      'hilal': () => HilalScreen(date: june, utcOffset: offset),
      'ephemeris': () => SkyScreen(date: june, utcOffset: offset),
      'prayer times': () => SalatScreen(date: june, utcOffset: offset),
      'bazi': () => BaziScreen(
        date: june,
        utcOffset: offset,
        minuteOfDay: 600,
        tables: tables,
        places: places,
      ),
      'search': () => SearchScreen(date: day, utcOffset: offset, today: day),
    };

    Future<void> open(WidgetTester tester, Size size, String name) async {
      SkyPlace.current.value = (latitude: -7.8, longitude: 110.4);
      addTearDown(() => SkyPlace.current.value = null);
      await tester.runAsync(StarCatalog.load);
      await tester.runAsync(Galaxy.load);
      sizeTo(tester, size);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(saved: AppLanguage.en),
          home: screens[name]!(),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);
    }

    for (final size in [pixel, tablet, tabletSideways, Size(869, 412)]) {
      for (final name in screens.keys) {
        testWidgets('$name at ${size.width.round()} x '
            '${size.height.round()}: a tab changed moves no other part', (
          tester,
        ) async {
          await open(tester, size, name);
          final before = parts(tester);
          // The tabs of the panel, or the search's fields.
          final tabs = name == 'search'
              ? [
                  for (final e
                      in find
                          .byWidgetPredicate(
                            (w) =>
                                w.key is ValueKey<String> &&
                                (w.key! as ValueKey<String>).value.startsWith(
                                  'search-field-',
                                ),
                          )
                          .evaluate())
                    (e.widget.key! as ValueKey<String>).value,
                ]
              : [
                  for (final row
                      in find
                          .byWidgetPredicate((w) => w is PanelTabs)
                          .evaluate())
                    for (final tab in (row.widget as dynamic).tabs as List)
                      (row.widget as dynamic).keyOf(tab) as String,
                ];
          expect(tabs, isNotEmpty);
          for (final tab in [...tabs, tabs.first]) {
            await reach(tester, tab);
            expect(key(tab).hitTestable(), findsOneWidget, reason: tab);
            await tester.tap(key(tab).hitTestable());
            await settle(tester);
            // A field with words puts the keyboard up; here it is not,
            // so it is put away again.
            FocusManager.instance.primaryFocus?.unfocus();
            await settle(tester);
            final now = parts(tester);
            for (final part in const ['top', 'body', 'panel', 'bar']) {
              expect(now[part], before[part], reason: '$tab moved the $part');
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final size in [pixel, tablet]) {
      testWidgets('the star map at ${size.width.round()} x '
          '${size.height.round()}: the keyboard for the search pushes the '
          'bar and the panel up over the dome, which keeps its size', (
        tester,
      ) async {
        await open(tester, size, 'star map');
        await reach(tester, 'stars-panel-galaxies');
        await tester.tap(key('stars-panel-galaxies'));
        await settle(tester);
        final before = parts(tester);
        final dome = tester.getRect(key('stars-dome'));
        await reach(tester, 'stars-panel-search');
        await tester.tap(key('stars-panel-search'));
        final kb = size == tablet ? keyboard : 288.0;
        for (var k = 32.0; k <= kb; k += 32) {
          raiseKeyboard(tester, k);
          await tester.pump(const Duration(milliseconds: 16));
          final now = parts(tester);
          expect(now['top'], before['top']);
          expect(now['body'], before['body']);
          expect(now['panel']!.height, closeTo(before['panel']!.height, 1e-6));
          expect(now['bar']!.bottom, before['bar']!.bottom);
          expect(tester.getRect(key('stars-dome')), dome);
        }
        await settle(tester);
        // Bar on the keyboard, panel on the bar.
        expect(
          part(tester, 'panel').bottom,
          closeTo(part(tester, 'bar').top, 1e-6),
        );
        expect(part(tester, 'bar').bottom, size.height);
        expect(
          part(tester, 'panel').top,
          closeTo(before['body']!.bottom + 1 - kb, 1e-6),
        );
        expect(tester.takeException(), isNull);
      });
    }

    // On an iPhone or an iPad the bar is the phone's own glass, and a bar
    // with a field in it is drawn by the app over a capsule of it instead:
    // as tall as the other, so the field's coming moves nothing.
    for (final (name, tab) in const [
      ('star map', 'stars-panel-search'),
      ('search', 'search-field-words'),
    ]) {
      testWidgets('$name on an iPad upright: the bar with the field in it is '
          'as tall as the glass bar it replaces', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await open(tester, tablet, name);
        await reach(tester, tab);
        final before = parts(tester);
        await tester.tap(key(tab));
        await settle(tester);
        expect(find.byType(UiKitView), findsOneWidget);
        final now = parts(tester);
        for (final part in const ['top', 'body', 'panel', 'bar']) {
          expect(now[part], before[part], reason: 'the $part moved');
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    for (final size in [pixel, tablet]) {
      testWidgets('the place finder at ${size.width.round()} x '
          '${size.height.round()}: the keyboard for its field pushes the '
          'bar and the list up over the map, which keeps its size', (
        tester,
      ) async {
        sizeTo(tester, size);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          CalendarJournalApp(
            controller: SystemController(),
            language: LanguageController(saved: AppLanguage.en),
            home: const PlaceScreen(),
          ),
        );
        await settle(tester);
        final before = parts(tester);
        final map = tester.getRect(key('place-map'));
        await tester.tap(key('place-query'));
        final kb = size == tablet ? keyboard : 300.0;
        for (var k = 20.0; k <= kb; k += 20) {
          raiseKeyboard(tester, k);
          await tester.pump(const Duration(milliseconds: 16));
          final now = parts(tester);
          expect(now['top'], before['top']);
          expect(now['body'], before['body']);
          expect(now['panel']!.height, closeTo(before['panel']!.height, 1e-6));
          expect(tester.getRect(key('place-map')), map);
        }
        await settle(tester);
        expect(
          tester.getRect(key('place-query')).bottom,
          lessThan(size.height - kb),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }

    // The editors size their own panels: their tabs change what is in the
    // panel, never its height, so the sheet over it holds still.
    for (final size in [pixel, tablet]) {
      testWidgets('the reminder editor at ${size.width.round()} x '
          '${size.height.round()}: its fields and the time\'s anchors move '
          'no other part', (tester) async {
        await pump(tester, size, ReminderScreen(day: day));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.tap(key('field-time'));
        await tester.pumpAndSettle();
        final before = parts(tester);
        for (final tab in const [
          'field-category',
          'field-start',
          'field-repeat',
          'field-time',
          'reminder-anchor-sunset',
          'reminder-anchor-planetaryHour',
          'reminder-anchor-clock',
        ]) {
          await reach(tester, tab);
          await tester.tap(key(tab).hitTestable());
          await tester.pumpAndSettle();
          final now = parts(tester);
          for (final part in const ['top', 'body', 'panel', 'bar']) {
            expect(now[part], before[part], reason: '$tab moved the $part');
          }
        }
        expect(tester.takeException(), isNull);
      });
    }

    for (final size in [pixel, tablet]) {
      testWidgets('the entry editor at ${size.width.round()} x '
          '${size.height.round()}: the date and time tabs move no other '
          'part', (tester) async {
        await pump(tester, size, EntryScreen(date: day, utcOffset: offset));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.tap(key('entry-when-change'));
        await tester.pumpAndSettle();
        expect(key('entry-when-panel'), findsOneWidget);
        final before = parts(tester);
        for (final tab in const [
          'entry-when-time',
          'entry-when-date',
          'entry-when-time',
        ]) {
          await tester.tap(key(tab).hitTestable());
          await tester.pumpAndSettle();
          final now = parts(tester);
          for (final part in const ['top', 'body', 'panel', 'bar']) {
            expect(now[part], before[part], reason: '$tab moved the $part');
          }
        }
        expect(tester.takeException(), isNull);
      });
    }

    for (final size in [pixel, tablet]) {
      testWidgets('the search at ${size.width.round()} x '
          '${size.height.round()}: as the keyboard rises for the words the '
          'panel gives way and the list holds still', (tester) async {
        await open(tester, size, 'search');
        await reach(tester, 'search-field-words');
        final before = parts(tester);
        await tester.tap(key('search-field-words'));
        await tester.pump();
        final kb = size == tablet ? keyboard : 300.0;
        var lastPanel = before['panel']!.height;
        for (var k = 20.0; k <= kb; k += 20) {
          raiseKeyboard(tester, k);
          await tester.pump(const Duration(milliseconds: 16));
          final now = parts(tester);
          expect(now['top'], before['top']);
          expect(now['body'], before['body']);
          // Never more than the keyboard rose in the frame.
          expect(lastPanel - now['panel']!.height, lessThanOrEqualTo(20.5));
          lastPanel = now['panel']!.height;
        }
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Scrolls the row of tabs (or fields) that holds [name] until it is in
/// sight, from the row's start.
Future<void> reach(WidgetTester tester, String name) async {
  final target = find.byKey(ValueKey(name));
  final rows = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
  );
  for (final row in rows.evaluate().toList().reversed) {
    final position =
        ((row as StatefulElement).state as ScrollableState).position;
    position.jumpTo(position.minScrollExtent);
    await tester.pump();
    while (target.hitTestable().evaluate().isEmpty &&
        position.pixels < position.maxScrollExtent) {
      position.jumpTo(
        (position.pixels + 80).clamp(0, position.maxScrollExtent).toDouble(),
      );
      await tester.pump();
    }
    if (target.hitTestable().evaluate().isNotEmpty) {
      await settle(tester);
      return;
    }
  }
}

/// Frames for a second, without waiting on what never settles (a clock,
/// a sky being worked out).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
