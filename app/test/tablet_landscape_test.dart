import 'package:candra/app_shell.dart';
import 'package:candra/calendar_system.dart';
import 'package:candra/day_page.dart';
import 'package:candra/journal/card_stack.dart';
import 'package:candra/journal/categories_screen.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_file_screen.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/journal/geo.dart';
import 'package:candra/house.dart';
import 'package:candra/main.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/panel_tabs.dart';
import 'package:candra/parts.dart';
import 'package:candra/places/place_catalog.dart';
import 'package:candra/places/place_screen.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_screen.dart';
import 'package:candra/reminders/reminders_screen.dart';
import 'package:candra/search/search_screen.dart';
import 'package:candra/search/tags_ui.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:candra/system_picker.dart';
import 'package:candra/utilities.dart';
import 'package:candra/wheel_row.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

/// A tablet on its side (the iPad mini, 1133 x 744 points), against a
/// phone on its side and upright: the rows of cards in a tall lower panel
/// run down it, and every screen that is typed in stays whole above a
/// keyboard of more than half the height.
void main() {
  Finder key(String name) => find.byKey(ValueKey(name));
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 15);

  // In points, at two device pixels a point.
  const tablet = Size(1133, 744);
  const tabletUpright = Size(744, 1133);
  const phoneSideways = Size(915, 412);
  const phoneUpright = Size(412, 915);
  // The keyboard on the tablet, assumed at more than half the height.
  const keyboard = 400.0;
  const keyboardTop = 744 - keyboard;

  void sizeTo(WidgetTester tester, Size size) {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  void raiseKeyboard(WidgetTester tester, [double height = keyboard]) {
    tester.view.viewInsets = FakeViewPadding(bottom: height * 2);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> pump(WidgetTester tester, Size size, Widget home) async {
    sizeTo(tester, size);
    // Nothing kept from a screen pumped before.
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

  Axis axisOf(WidgetTester tester, Finder scrollable) => tester
      .widget<Scrollable>(
        find
            .descendant(of: scrollable, matching: find.byType(Scrollable))
            .first,
      )
      .axis;

  testWidgets('a panel is tall only on a tablet on its side', (tester) async {
    final seen = <Size, bool>{};
    for (final size in const [
      tablet,
      tabletUpright,
      phoneSideways,
      phoneUpright,
    ]) {
      sizeTo(tester, size);
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen[size] = FourParts.tallPanel(context);
            return const SizedBox();
          },
        ),
      );
    }
    expect(seen, {
      tablet: true,
      tabletUpright: false,
      phoneSideways: false,
      phoneUpright: false,
    });
  });

  group('the day strip', () {
    Widget journal() => JournalScreen(date: day, utcOffset: offset, today: day);

    testWidgets('runs down a tall panel, its days as wide as the column and '
        'short, the chosen one at the middle', (tester) async {
      await pump(tester, tablet, journal());
      expect(tester.takeException(), isNull);
      final strip = key('day-strip');
      expect(axisOf(tester, strip), Axis.vertical);
      final area = tester.getRect(strip);
      final chosen = tester.getRect(key('day-${day.dayNumber}'));
      expect(chosen.width, greaterThan(FourParts.columnWidth - 40));
      expect(chosen.height, lessThan(area.height / 4));
      expect(chosen.center.dy, closeTo(area.center.dy, 1));
      // The weekday, the number and the pasaran on one line.
      final number = tester.getRect(
        find.descendant(
          of: key('day-${day.dayNumber}'),
          matching: find.text('15'),
        ),
      );
      final pasaran = tester.getRect(
        find.descendant(
          of: key('day-${day.dayNumber}'),
          matching: find.text(Weton.of(day).pasaran.label),
        ),
      );
      expect(pasaran.center.dy, closeTo(number.center.dy, 4));
      expect(pasaran.left, greaterThan(number.right));

      // The day below, touched, comes to the middle and is chosen.
      final next = day.addDays(1);
      await tester.tap(key('day-${next.dayNumber}'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(key('day-${next.dayNumber}')).center.dy,
        closeTo(area.center.dy, 1),
      );
      expect(find.text(Weton.of(next).toString()), findsWidgets);
      // A drag upwards goes on to later days.
      await tester.drag(strip, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(key('day-${next.dayNumber}')).center.dy,
        lessThan(area.center.dy - 50),
      );
    });

    testWidgets('down a tall panel the day reads at twice the size it '
        'has on a phone, all five days whole', (tester) async {
      Rect numberOf(WidgetTester tester) => tester.getRect(
        find.descendant(
          of: key('day-${day.dayNumber}'),
          matching: find.text('${day.day}'),
        ),
      );
      double sizeOf(WidgetTester tester, String text) => tester
          .widget<Text>(
            find.descendant(
              of: key('day-${day.dayNumber}'),
              matching: find.text(text),
            ),
          )
          .style!
          .fontSize!;
      final pasaran = Weton.of(day).pasaran.label;

      await pump(tester, phoneUpright, journal());
      final before = numberOf(tester).height;
      final pasaranBefore = sizeOf(tester, pasaran);
      final weekdayBefore = sizeOf(tester, 'THU');

      // The iPad mini, and the smallest tablet, 600 points high.
      for (final size in const [tablet, Size(960, 600)]) {
        await pump(tester, size, journal());
        expect(tester.takeException(), isNull);
        final number = numberOf(tester);
        expect(number.height, closeTo(2 * before, 0.5));
        expect(sizeOf(tester, pasaran), 2 * pasaranBefore);
        expect(sizeOf(tester, 'THU'), 2 * weekdayBefore);
        final chip = tester.getRect(key('day-${day.dayNumber}'));
        expect(number.top, greaterThan(chip.top));
        expect(number.bottom, lessThan(chip.bottom));
        // The number still on the strip's middle line.
        expect(number.center.dx, closeTo(chip.center.dx, 1));
      }
    });

    testWidgets('runs sideways on a phone, on its side or upright', (
      tester,
    ) async {
      for (final size in const [phoneSideways, phoneUpright]) {
        await pump(tester, size, journal());
        expect(tester.takeException(), isNull);
        expect(axisOf(tester, key('day-strip')), Axis.horizontal);
        final chip = tester.getRect(key('day-${day.dayNumber}'));
        expect(chip.height, greaterThan(chip.width));
      }
    });

    testWidgets('runs down the reminders\' tall panel too', (tester) async {
      await pump(tester, tablet, RemindersScreen(day: day, today: day));
      expect(tester.takeException(), isNull);
      expect(axisOf(tester, key('day-strip')), Axis.vertical);
    });
  });

  group('the month screen\'s strips', () {
    Future<void> pumpMonth(WidgetTester tester, Size size) async {
      sizeTo(tester, size);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(saved: AppLanguage.en),
          home: MonthScreen(today: day, utcOffset: offset),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('the systems run down a tall panel, the chosen one at the '
        'middle, and one touched comes there and is chosen', (tester) async {
      await pumpMonth(tester, tablet);
      await tester.tap(key('system-label'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final strip = find.byType(SystemPicker);
      expect(axisOf(tester, strip), Axis.vertical);
      final area = tester.getRect(strip);
      final chosen = tester.getRect(key('card-gregorian'));
      expect(chosen.width, greaterThan(FourParts.columnWidth - 40));
      expect(chosen.height, lessThan(100));
      expect(chosen.center.dy, closeTo(area.center.dy, 1));
      // Every system's card is there, one under another.
      final weton = tester.getRect(key('card-weton'));
      expect(weton.bottom, lessThanOrEqualTo(chosen.top));

      await tester.tap(key('card-hijri'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(key('card-hijri')).center.dy,
        closeTo(area.center.dy, 1),
      );
      final app = tester.state<State>(find.byType(MonthScreen));
      expect(
        SystemScope.of(app.context).value,
        CalendarSystem.hijri,
        reason: 'the card at the middle is the system',
      );
    });

    testWidgets('the utilities run down a tall panel, each card the glyph '
        'beside its name, and a touch opens one', (tester) async {
      await pumpMonth(tester, tablet);
      await tester.tap(key('utilities-button'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(axisOf(tester, find.byType(UtilityPicker)), Axis.vertical);
      final cards = [
        for (final utility in Utility.of(CalendarSystem.gregorian))
          tester.getRect(key('utility-${utility.name}')),
      ];
      for (final (i, card) in cards.indexed) {
        expect(card.width, greaterThan(FourParts.columnWidth - 40));
        expect(card.height, lessThan(100));
        if (i > 0) expect(card.top, greaterThan(cards[i - 1].bottom));
      }
    });

    testWidgets('on a phone they run sideways as before', (tester) async {
      for (final size in const [phoneSideways, phoneUpright]) {
        await pumpMonth(tester, size);
        await tester.tap(key('system-label'));
        await tester.pumpAndSettle();
        expect(axisOf(tester, find.byType(SystemPicker)), Axis.horizontal);
        await tester.tap(key('picker-done'));
        await tester.pumpAndSettle();
        await tester.tap(key('utilities-button'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(axisOf(tester, find.byType(UtilityPicker)), Axis.horizontal);
        final card = tester.getRect(key('utility-sky'));
        expect(card.height, greaterThan(card.width * 0.6));
      }
    });
  });

  testWidgets('the journal file\'s actions run down a tall panel, and '
      'sideways on a phone', (tester) async {
    await pump(tester, tablet, const JournalFileScreen());
    expect(tester.takeException(), isNull);
    expect(axisOf(tester, key('action-strip')), Axis.vertical);
    final area = tester.getRect(key('action-strip'));
    final first = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('action-') &&
          w.key != const ValueKey('action-strip'),
    );
    final card = tester.getRect(first.first);
    expect(card.height, lessThan(area.height / 2));
    expect(card.width, greaterThan(card.height));

    await pump(tester, phoneSideways, const JournalFileScreen());
    expect(tester.takeException(), isNull);
    expect(axisOf(tester, key('action-strip')), Axis.horizontal);
  });

  group('with the keyboard up on a tablet on its side', () {
    testWidgets('a new reminder: the name is in sight, the field\'s '
        'instrument stays in the column, the bar over the keyboard', (
      tester,
    ) async {
      await pump(tester, tablet, ReminderScreen(day: day));
      await tester.tap(key('reminder-title'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = tester.getRect(key('reminder-title'));
      expect(title.top, greaterThanOrEqualTo(0));
      expect(title.bottom, lessThanOrEqualTo(keyboardTop));
      final panel = tester.getRect(key('reminder-panel'));
      expect(panel.top, greaterThanOrEqualTo(0));
      expect(panel.bottom, lessThanOrEqualTo(keyboardTop));
      expect(panel.left, greaterThan(tablet.width - FourParts.columnWidth - 2));
      expect(
        tester.getRect(key('reminder-save')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      // The rest of the reminder is reached by scrolling, above the
      // keyboard.
      await tester.drag(key('reminder-title'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a phone on its side the panel still gives way', (
      tester,
    ) async {
      await pump(tester, phoneSideways, ReminderScreen(day: day));
      await tester.tap(key('reminder-title'));
      raiseKeyboard(tester, 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(key('reminder-panel'), findsNothing);
    });

    testWidgets('an entry: the line being written stays above the keyboard', (
      tester,
    ) async {
      await pump(tester, tablet, EntryScreen(date: day, utcOffset: offset));
      final content = key('entry-content');
      await tester.tap(content);
      await tester.enterText(
        content,
        [for (var i = 1; i <= 60; i++) 'Line $i'].join('\n'),
      );
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The text that has the caret.
      final editable = tester.allRenderObjects
          .whereType<RenderEditable>()
          .singleWhere((e) => e.hasFocus);
      final caret = MatrixUtils.transformRect(
        editable.getTransformTo(null),
        editable.getLocalRectForCaret(editable.selection!.extent),
      );
      expect(caret.top, greaterThanOrEqualTo(0));
      expect(caret.bottom, lessThanOrEqualTo(keyboardTop));
      expect(
        tester.getRect(key('format-bar')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
    });

    testWidgets('a new category: the name and all the colours in sight', (
      tester,
    ) async {
      await pump(tester, tablet, const CategoriesScreen());
      await tester.tap(key('category-add'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(key('category-name')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      // The grid of colours, not the one row a phone has room for.
      expect(key('swatch-grid'), findsOneWidget);
      final swatches = tester.getRect(key('swatch-grid'));
      expect(swatches.top, greaterThanOrEqualTo(0));
      expect(swatches.bottom, lessThanOrEqualTo(keyboardTop));
    });

    testWidgets('the search: the words, the fields and what is found in '
        'sight, the top bar folded away', (tester) async {
      await pump(
        tester,
        tablet,
        SearchScreen(date: day, utcOffset: offset, today: day),
      );
      await tester.drag(key('search-fields'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(key('search-field-words'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(key('search-words')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      final panel = tester.getRect(key('search-panel'));
      expect(panel.top, greaterThanOrEqualTo(0));
      expect(panel.bottom, lessThanOrEqualTo(keyboardTop));
      expect(panel.height, greaterThan(200));
      expect(key('search-field-words').hitTestable(), findsOneWidget);
    });

    testWidgets('the place finder: the map whole above the keyboard, the '
        'list beside it', (tester) async {
      SkyPlace.current.value = (latitude: -6.2, longitude: 106.8);
      addTearDown(() => SkyPlace.current.value = null);
      PlaceCatalog.reset();
      await tester.runAsync(PlaceCatalog.load);
      await pump(tester, tablet, const PlaceScreen());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.tap(key('place-query'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(key('place-query')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(
        tester.getRect(key('place-map')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      final list = tester.getRect(key('place-list'));
      expect(list.bottom, lessThanOrEqualTo(keyboardTop));
      expect(list.height, greaterThan(200));
    });
  });

  group('the second round (19 October 2026)', () {
    // The column's middle on the tablet: under the top bar while it is
    // there, under the top of the screen once it has folded away.
    double columnLeft() => tablet.width - FourParts.columnWidth;

    testWidgets('an entry being written keeps its tags at the top of a '
        'tall panel, with the keyboard down and up', (tester) async {
      await pump(tester, tablet, EntryScreen(date: day, utcOffset: offset));
      expect(tester.takeException(), isNull);
      expect(key('entry-kept-tags'), findsOneWidget);
      final topBar = tester.getRect(key('entry-top-bar'));
      var tags = tester.getRect(key('tag-panel'));
      expect(tags.left, greaterThan(columnLeft() - 2));
      // Right under the top bar, not down by the bar.
      expect(tags.top, lessThan(topBar.bottom + 40));
      expect(key('tag-new').hitTestable(), findsOneWidget);
      // The tag button has nothing to do: kept out of sight and reach.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(key('entry-tags'), findsNothing);

      await tester.tap(key('entry-content'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tags = tester.getRect(key('tag-panel'));
      expect(tags.top, lessThan(40));
      expect(tags.bottom, lessThanOrEqualTo(keyboardTop));
      expect(key('tag-new').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(key('format-bar')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
    });

    testWidgets('on a phone, and upright, the tags still wait for their '
        'button', (tester) async {
      for (final size in const [phoneSideways, phoneUpright, tabletUpright]) {
        await pump(tester, size, EntryScreen(date: day, utcOffset: offset));
        // A new entry starts with the writing in hand; the ordinary bar
        // comes back once it is let go.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(key('entry-kept-tags'), findsNothing);
        expect(key('tag-panel'), findsNothing);
        expect(key('entry-tags').hitTestable(), findsOneWidget);
      }
    });

    testWidgets('a reminder with the keyboard up has its panel at the top '
        'of the column; down, by the bar', (tester) async {
      await pump(tester, tablet, ReminderScreen(day: day));
      final bar = tester.getRect(key('reminder-save'));
      var panel = tester.getRect(key('reminder-panel'));
      // The time's tabs and wheels, at the foot as before.
      expect(panel.bottom, greaterThan(bar.top - 40));

      await tester.tap(key('reminder-title'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      panel = tester.getRect(key('reminder-panel'));
      expect(panel.left, greaterThan(columnLeft() - 2));
      expect(panel.top, lessThan(10));
      expect(panel.bottom, lessThanOrEqualTo(keyboardTop));
      expect(key('reminder-anchors').hitTestable(), findsOneWidget);
    });

    testWidgets('a reminder\'s category, picked, stands at the top of the '
        'column, the keyboard down or up', (tester) async {
      await pump(tester, tablet, ReminderScreen(day: day));
      final topBar = tester.getRect(key('reminder-top-bar'));
      await tester.tap(key('field-category'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(key('instrument-category'), findsOneWidget);
      var panel = tester.getRect(key('reminder-panel'));
      expect(panel.top, lessThan(topBar.bottom + 40));

      await tester.tap(key('reminder-title'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      panel = tester.getRect(key('reminder-panel'));
      expect(panel.top, lessThan(10));
      expect(panel.bottom, lessThanOrEqualTo(keyboardTop));
    });

    testWidgets('a reminder on a phone on its side keeps its panel by the '
        'bar', (tester) async {
      await pump(tester, phoneSideways, ReminderScreen(day: day));
      await tester.tap(key('field-category'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final panel = tester.getRect(key('reminder-panel'));
      final bar = tester.getRect(key('reminder-save'));
      expect(panel.bottom, greaterThan(bar.top - 40));
    });

    testWidgets('the category page: the colours stand at the top of the '
        'column, the keyboard down or up', (tester) async {
      await pump(tester, tablet, const CategoriesScreen());
      await tester.tap(key('category-add'));
      await tester.pumpAndSettle();
      var swatches = tester.getRect(key('swatch-grid'));
      // Down, at the top as well (third round).
      expect(swatches.top, lessThan(120));

      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      swatches = tester.getRect(key('swatch-grid'));
      expect(swatches.top, lessThan(10));
      expect(swatches.bottom, lessThanOrEqualTo(keyboardTop));
    });
  });

  group('the third round (19 October 2026)', () {
    // The bar's place on the page [button] is on: the room's stand-in
    // for the house's bar, which the keyboard lifts.
    Rect barOf(WidgetTester tester, String button) => tester.getRect(
      find.descendant(
        of: find.ancestor(of: key(button), matching: find.byType(FourParts)),
        matching: find.byType(RoomBar),
      ),
    );

    testWidgets('a reminder\'s time wheels reach down to the bar, the '
        'keyboard down or up, more rows in sight at the same height', (
      tester,
    ) async {
      await pump(tester, tablet, ReminderScreen(day: day));
      expect(tester.takeException(), isNull);
      var wheel = tester.getRect(key('picker-hour'));
      var bar = barOf(tester, 'reminder-save');
      expect(wheel.bottom, closeTo(bar.top, 2));
      expect(wheel.height, greaterThan(400));
      // The rows as tall as ever: so many more of them.
      expect(
        tester.widget<ListWheelScrollView>(key('picker-hour')).itemExtent,
        36,
      );
      // Counted with the wheel at noon: a new reminder starts at the next
      // full hour, and by 22:00 the wheel's end leaves fewer rows built.
      (tester.widget<ListWheelScrollView>(key('picker-hour')).controller!
              as FixedExtentScrollController)
          .jumpToItem(12);
      await tester.pumpAndSettle();
      final rows = find.descendant(
        of: key('picker-hour'),
        matching: find.byType(WheelRow),
      );
      expect(rows.evaluate().length, greaterThan(9));

      await tester.tap(key('reminder-title'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      wheel = tester.getRect(key('picker-hour'));
      bar = barOf(tester, 'reminder-save');
      expect(
        tester.getRect(key('reminder-save')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(wheel.bottom, closeTo(bar.top, 2));
      expect(wheel.height, greaterThan(150));

      // The date's wheels and the repeats' as well.
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      for (final (field, picker) in const [
        ('field-start', 'picker-day'),
        ('field-repeat', 'picker-repeat'),
      ]) {
        await tester.tap(key(field));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(key(picker)).bottom,
          closeTo(barOf(tester, 'reminder-save').top, 2),
        );
      }
    });

    testWidgets('on a phone the wheels keep their height', (tester) async {
      for (final size in const [phoneUpright, phoneSideways]) {
        await pump(tester, size, ReminderScreen(day: day));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(key('picker-hour')).height, lessThan(180));
      }
    });

    Future<void> anchor(WidgetTester tester, SunAnchor to) async {
      await tester.scrollUntilVisible(
        key('reminder-anchor-${to.name}'),
        60,
        scrollable: find.descendant(
          of: key('reminder-anchors'),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(key('reminder-anchor-${to.name}'));
      await tester.pumpAndSettle();
      await tester.tap(key('reminder-anchor-${to.name}'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    bool chosen(WidgetTester tester, String name) =>
        tester.widget<SearchChip>(key(name)).on;

    testWidgets('by the sun, the leads are one list down the column, rows '
        'as wide as it, the keyboard down or up', (tester) async {
      await pump(tester, tablet, ReminderScreen(day: day));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await anchor(tester, SunAnchor.sunset);
      expect(axisOf(tester, key('reminder-leads')), Axis.vertical);
      expect(key('reminder-planets'), findsNothing);
      final list = tester.getRect(key('reminder-leads'));
      expect(list.width, closeTo(FourParts.columnWidth, 1));
      expect(list.bottom, closeTo(barOf(tester, 'reminder-save').top, 2));
      final at = tester.getRect(key('reminder-lead-0'));
      final five = tester.getRect(key('reminder-lead-5'));
      expect(at.width, greaterThan(FourParts.columnWidth - 40));
      expect(five.top, greaterThan(at.bottom));
      expect(chosen(tester, 'reminder-lead-0'), isTrue);
      await tester.tap(key('reminder-lead-5'));
      await tester.pumpAndSettle();
      expect(chosen(tester, 'reminder-lead-5'), isTrue);
      expect(chosen(tester, 'reminder-lead-0'), isFalse);

      await tester.tap(key('reminder-title'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final up = tester.getRect(key('reminder-leads'));
      expect(up.top, greaterThanOrEqualTo(0));
      expect(up.bottom, lessThanOrEqualTo(keyboardTop));
      expect(key('reminder-lead-5').hitTestable(), findsOneWidget);
    });

    testWidgets('by the planetary hour, the planets and the leads are two '
        'lists side by side', (tester) async {
      await pump(tester, tablet, ReminderScreen(day: day));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await anchor(tester, SunAnchor.planetaryHour);
      expect(axisOf(tester, key('reminder-planets')), Axis.vertical);
      expect(axisOf(tester, key('reminder-leads')), Axis.vertical);
      final planets = tester.getRect(key('reminder-planets'));
      final leads = tester.getRect(key('reminder-leads'));
      expect(planets.right, lessThanOrEqualTo(leads.left + 1));
      expect(planets.top, closeTo(leads.top, 1));
      expect(planets.width, closeTo(FourParts.columnWidth / 2, 1));
      // The sun's first, as the weekdays go.
      final sun = tester.getRect(key('reminder-planet-sun'));
      final moon = tester.getRect(key('reminder-planet-moon'));
      expect(moon.top, greaterThan(sun.bottom));
      expect(chosen(tester, 'reminder-planet-sun'), isTrue);
      await tester.tap(key('reminder-planet-moon'));
      await tester.pumpAndSettle();
      expect(chosen(tester, 'reminder-planet-moon'), isTrue);

      await tester.tap(key('reminder-title'));
      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(key('reminder-planets')).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
    });

    group('on phones, upright and on their side', () {
      // The Pixel 4 XL and a large iPhone upright, the Pixel on its side.
      const phones = [Size(412, 869), Size(440, 956), Size(869, 412)];

      // Whether the row is wholly inside its list.
      void inSight(WidgetTester tester, String list, String row) {
        final within = tester.getRect(key(list));
        final rect = tester.getRect(key(row));
        expect(rect.top, greaterThanOrEqualTo(within.top), reason: row);
        expect(rect.bottom, lessThanOrEqualTo(within.bottom), reason: row);
      }

      Future<void> open(WidgetTester tester, Size size) async {
        await pump(tester, size, ReminderScreen(day: day));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      testWidgets('by the sun the leads are a list down the panel, rows as '
          'wide as it, the chosen one in sight', (tester) async {
        for (final size in phones) {
          await open(tester, size);
          await anchor(tester, SunAnchor.sunset);
          expect(axisOf(tester, key('reminder-leads')), Axis.vertical);
          expect(key('reminder-planets'), findsNothing);
          final list = tester.getRect(key('reminder-leads'));
          final at = tester.getRect(key('reminder-lead-0'));
          final five = tester.getRect(key('reminder-lead-5'));
          expect(at.width, greaterThan(list.width - 40));
          expect(five.top, greaterThan(at.bottom));
          expect(chosen(tester, 'reminder-lead-0'), isTrue);
          inSight(tester, 'reminder-leads', 'reminder-lead-0');

          // The last, chosen, and the anchor changed: still in sight.
          await tester.scrollUntilVisible(
            key('reminder-lead-120'),
            40,
            scrollable: find.descendant(
              of: key('reminder-leads'),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.ensureVisible(key('reminder-lead-120'));
          await tester.pumpAndSettle();
          await tester.tap(key('reminder-lead-120'));
          await tester.pumpAndSettle();
          expect(chosen(tester, 'reminder-lead-120'), isTrue);
          await anchor(tester, SunAnchor.eveningBlue);
          inSight(tester, 'reminder-leads', 'reminder-lead-120');

          // And when the panel opens on it again.
          await tester.tap(key('field-start'));
          await tester.pumpAndSettle();
          expect(key('reminder-leads'), findsNothing);
          await tester.tap(key('field-time'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          inSight(tester, 'reminder-leads', 'reminder-lead-120');
          expect(find.byType(PanelTabs<int>), findsNothing);
        }
      });

      testWidgets('by the planetary hour the planets and the leads are two '
          'lists side by side, the chosen ones in sight', (tester) async {
        for (final size in phones) {
          await open(tester, size);
          await anchor(tester, SunAnchor.planetaryHour);
          expect(axisOf(tester, key('reminder-planets')), Axis.vertical);
          expect(axisOf(tester, key('reminder-leads')), Axis.vertical);
          final planets = tester.getRect(key('reminder-planets'));
          final leads = tester.getRect(key('reminder-leads'));
          expect(planets.right, lessThanOrEqualTo(leads.left + 1));
          expect(planets.top, closeTo(leads.top, 1));
          expect(planets.width, closeTo(leads.width, 1));
          final sun = tester.getRect(key('reminder-planet-sun'));
          final moon = tester.getRect(key('reminder-planet-moon'));
          expect(moon.top, greaterThan(sun.bottom));
          expect(chosen(tester, 'reminder-planet-sun'), isTrue);
          inSight(tester, 'reminder-planets', 'reminder-planet-sun');
          inSight(tester, 'reminder-leads', 'reminder-lead-0');
          // The anchors' row is still a row of pills.
          expect(axisOf(tester, key('reminder-anchors')), Axis.horizontal);

          // The last planet and a late lead, chosen; the panel opened
          // again shows them both.
          for (final (list, row) in const [
            ('reminder-planets', 'reminder-planet-saturn'),
            ('reminder-leads', 'reminder-lead-90'),
          ]) {
            await tester.scrollUntilVisible(
              key(row),
              40,
              scrollable: find.descendant(
                of: key(list),
                matching: find.byType(Scrollable),
              ),
            );
            await tester.ensureVisible(key(row));
            await tester.pumpAndSettle();
            inSight(tester, list, row);
            await tester.tap(key(row));
            await tester.pumpAndSettle();
            expect(chosen(tester, row), isTrue);
          }
          await tester.tap(key('field-repeat'));
          await tester.pumpAndSettle();
          await tester.tap(key('field-time'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          inSight(tester, 'reminder-planets', 'reminder-planet-saturn');
          inSight(tester, 'reminder-leads', 'reminder-lead-90');
        }
      });
    });

    // A category's whole row opens it for editing: the first one's.
    Finder editButton() => find.byWidgetPredicate(
      (w) =>
          w is SmPressable &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('category-'),
    );

    testWidgets('a category being edited: the grid at the top, the folder '
        'under it as the journal draws it, following the name and colour, '
        'and what it holds', (tester) async {
      await pump(tester, tablet, const CategoriesScreen());
      await tester.tap(editButton().first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final grid = tester.getRect(key('swatch-grid'));
      expect(grid.top, lessThan(120));
      expect(grid.left, greaterThan(tablet.width - FourParts.columnWidth - 2));
      final preview = tester.getRect(key('category-preview'));
      expect(preview.top, greaterThanOrEqualTo(grid.bottom - 1));
      expect(find.byType(FolderPreview), findsOneWidget);
      expect(key('category-holds'), findsOneWidget);
      expect(find.text('0 entries · 0 reminders'), findsOneWidget);

      await tester.enterText(key('category-name'), 'Rituals');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: key('category-preview'),
          matching: find.text('RITUALS'),
        ),
        findsOneWidget,
      );
      await tester.tap(key('swatch-7'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FolderPreview>(find.byType(FolderPreview)).hue,
        categoryPalette[7],
      );

      raiseKeyboard(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final up = tester.getRect(key('swatch-grid'));
      expect(up.top, lessThan(10));
      expect(up.bottom, lessThanOrEqualTo(keyboardTop));
    });

    testWidgets('a new category shows its folder and no count', (tester) async {
      await pump(tester, tablet, const CategoriesScreen());
      await tester.tap(key('category-add'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FolderPreview), findsOneWidget);
      expect(key('category-holds'), findsNothing);
    });

    testWidgets('on a phone the category page has no preview', (tester) async {
      for (final size in const [phoneUpright, phoneSideways]) {
        await pump(tester, size, const CategoriesScreen());
        await tester.tap(editButton().first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(key('category-preview'), findsNothing);
        expect(key('swatch-grid'), findsOneWidget);
      }
    });

    group('the day on the main page', () {
      // The Pixel 4 XL upright, the phone the layout is measured on.
      const pixel = Size(412, 869);

      Future<({Rect page, Rect number, Rect weekday, Rect corner, double size})>
      dayOf(WidgetTester tester, Size size) async {
        sizeTo(tester, size);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          CalendarJournalApp(
            controller: SystemController(),
            language: LanguageController(saved: AppLanguage.en),
            home: MonthScreen(today: day, utcOffset: offset),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        for (
          var i = 0;
          i < 3 && key('day-page-number').evaluate().isEmpty;
          i++
        ) {
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
          size: tester
              .widget<Text>(inPage('day-page-weekday'))
              .style!
              .fontSize!,
        );
      }

      testWidgets('on a tablet on its side it is the phone\'s layout '
          'scaled whole', (tester) async {
        final phone = await dayOf(tester, pixel);
        final ipad = await dayOf(tester, tablet);
        // The number against the weekday, the gap between them and the
        // corners' text, all in the phone's proportion.
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
        // Larger by the ratio of the rooms' heights, which governs.
        final k = ipad.weekday.height / phone.weekday.height;
        expect(k, greaterThan(1.45));
        same(ipad.number.height, phone.number.height * k);
        expect(ipad.number.width, lessThan(ipad.page.width - 100));
        expect(ipad.weekday.center.dx, closeTo(ipad.number.center.dx, 1));
      });

      // A tablet upright is the phone's layout scaled too, since 19
      // October 2026 (tablet_upright_test.dart).
      testWidgets('on phones it is as it was', (tester) async {
        final title = const SmType().title.fontSize!;
        for (final size in const [phoneUpright, phoneSideways, pixel]) {
          final seen = await dayOf(tester, size);
          expect(seen.size, title);
        }
        // The two figures across the whole of the phone's room.
        final phone = await dayOf(tester, pixel);
        expect(phone.number.width, closeTo(DayPage.phoneRoom.width, 1));
      });
    });
  });

  group('an entry being read (19 October 2026)', () {
    // A sample as the journal keeps them: tagged, geotagged.
    Future<Entry> open(WidgetTester tester, Size size) async {
      final store = JournalStore();
      final tag = store.addTag('Klenteng')!;
      final kept = store.save(
        Entry(
          id: '',
          date: CivilDate(2026, 10, 12),
          minuteOfDay: 19 * 60 + 40,
          utcOffset: offset,
          categoryId: store.categories.first.id,
          title: "Before Kwan Im's sejit",
          content: 'Ordered the flowers and the fruit.',
          place: GeoTag.rounded(-6.137, 106.813, name: 'Vihara Dharma Bhakti'),
          tags: [tag.id],
        ),
      );
      sizeTo(tester, size);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(saved: AppLanguage.en),
          journal: store,
          home: EntryScreen(date: kept.date, utcOffset: offset, entry: kept),
        ),
      );
      await tester.pumpAndSettle();
      return kept;
    }

    testWidgets('on a tablet on its side the column reads its day, then its '
        'time, place, category and tags', (tester) async {
      final entry = await open(tester, tablet);
      expect(tester.takeException(), isNull);
      final aside = key('entry-aside');
      final rect = tester.getRect(aside);
      expect(rect.left, greaterThan(tablet.width - FourParts.columnWidth - 2));
      // At the top of the column, not down by the bar.
      expect(rect.top, lessThan(40));
      Finder inside(String text) =>
          find.descendant(of: aside, matching: find.text(text));
      final strings = Strings(AppLanguage.en);
      final date = entry.date;
      expect(inside(strings.gregorian(date)), findsOneWidget);
      final weton = Weton.of(date);
      expect(
        find.descendant(
          of: aside,
          matching: find.textContaining(
            '$weton · neptu ${weton.neptu}',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      for (final label in [
        strings.moon,
        strings.systemLabel(CalendarSystem.chinese),
        strings.systemLabel(CalendarSystem.hijri),
        strings.systemLabel(CalendarSystem.javanese),
        strings.mangsa,
        strings.systemLabel(CalendarSystem.weton),
      ]) {
        expect(inside(label.toUpperCase()), findsOneWidget, reason: label);
      }
      expect(
        find.descendant(
          of: key('entry-aside-time'),
          matching: find.text('19:40'),
        ),
        findsOneWidget,
      );
      expect(inside('Vihara Dharma Bhakti'), findsOneWidget);
      expect(
        find.descendant(
          of: key('entry-aside-category'),
          matching: find.text(
            JournalScope.of(tester.element(aside))
                .category(entry.categoryId)!
                .name,
          ),
        ),
        findsOneWidget,
      );
      final tag = find.descendant(of: aside, matching: find.byType(TagMark));
      expect(tag, findsOneWidget);
      expect(tester.widget<TagMark>(tag).name, 'Klenteng');
      expect(tester.widget<TagMark>(tag).on, isTrue);
      // The moment record stays hidden.
      expect(find.textContaining('moment_'), findsNothing);
      // Everything fits the column, over the bar.
      for (final part in [
        'entry-aside-time',
        'entry-aside-place',
        'entry-aside-category',
      ]) {
        final r = tester.getRect(key(part));
        expect(r.right, lessThanOrEqualTo(tablet.width + 0.5));
      }

      // Editing, it gives way to the kept tags; back, it returns.
      await tester.tap(key('entry-edit'));
      await tester.pumpAndSettle();
      expect(aside, findsNothing);
      expect(key('entry-kept-tags'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(aside, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on phones and upright the column is as it was', (
      tester,
    ) async {
      for (final size in const [phoneSideways, phoneUpright, tabletUpright]) {
        await open(tester, size);
        expect(tester.takeException(), isNull);
        expect(key('entry-aside'), findsNothing);
        expect(key('entry-tags').hitTestable(), findsOneWidget);
      }
    });
  });
}
