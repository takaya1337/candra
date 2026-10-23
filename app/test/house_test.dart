import 'package:candra/app_shell.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/house.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/main.dart';
import 'package:candra/menu/colours_screen.dart';
import 'package:candra/menu/menu_screen.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/practice/practice_screen.dart';
import 'package:candra/reminders/reminders_screen.dart';
import 'package:candra/strings.dart';
import 'package:candra/system_button.dart';
import 'package:candra/system_picker.dart';
import 'package:candra/utilities.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// The house (owner, 20 October 2026): the calendar is the living room,
/// the menu, the practice, the reminders and the journal rooms round it,
/// and one bar over all of them that never changes.
void main() {
  final today = CivilDate(2026, 10, 15);
  final strings = Strings(AppLanguage.en);
  Finder key(String name) => find.byKey(ValueKey(name));

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: MonthScreen(today: today, utcOffset: const Duration(hours: 7)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String name) async {
    await tester.tap(key(name));
    await tester.pumpAndSettle();
  }

  // The bar's buttons, left to right, wherever the house is.
  const bar = [
    'menu-button',
    'today-button',
    'utilities-button',
    'system-label',
    'practice-button',
    'reminder-button',
    'journal-button',
  ];

  void expectBar(WidgetTester tester, {required String here}) {
    final xs = <double>[];
    for (final name in bar) {
      expect(key(name), findsOneWidget, reason: name);
      xs.add(tester.getCenter(key(name)).dx);
    }
    // In their order, and never more than these.
    expect(xs, orderedEquals([...xs]..sort()));
    for (final name in bar) {
      final widget = tester.widget(key(name));
      final lit = widget is GlyphButton
          ? widget.here
          : (widget as SystemButton).here;
      expect(lit, name == here, reason: '$name lit from behind');
    }
  }

  testWidgets('the bar is the same in every room, and lights the room the '
      'house is in', (tester) async {
    await open(tester);
    expectBar(tester, here: 'system-label');
    final where = {for (final name in bar) name: tester.getRect(key(name))};

    for (final (button, screen) in [
      ('journal-button', JournalScreen),
      ('reminder-button', RemindersScreen),
      ('practice-button', PracticeScreen),
      ('menu-button', MenuScreen),
    ]) {
      await tap(tester, button);
      expect(find.byType(screen), findsOneWidget);
      expectBar(tester, here: button);
      // Not a point moved.
      for (final name in bar) {
        expect(tester.getRect(key(name)), where[name], reason: name);
      }
    }
  });

  testWidgets('the rooms slide the way they lie: the journal comes in from '
      'the right, the menu from the left', (tester) async {
    await open(tester);
    await tester.tap(key('journal-button'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final coming = tester.getTopLeft(find.byType(JournalScreen)).dx;
    final going = tester.getTopLeft(find.byType(MonthScreen)).dx;
    expect(coming, greaterThan(0));
    expect(coming, lessThan(width));
    expect(going, lessThan(0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(JournalScreen)).dx, 0);

    await tester.tap(key('menu-button'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getTopLeft(find.byType(MenuScreen)).dx, lessThan(0));
    expect(tester.getTopLeft(find.byType(JournalScreen)).dx, greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('from another room the utilities go home with their cards '
      'up, in one tap; the system only goes home', (tester) async {
    await open(tester);
    await tap(tester, 'journal-button');
    await tap(tester, 'utilities-button');
    expect(
      House.maybeOf(tester.element(find.byType(MonthScreen)))!.room.value,
      Room.living,
    );
    expect(find.byType(UtilityPicker), findsOneWidget);
    expectBar(tester, here: 'utilities-button');
    // Drawn down, they go.
    await tester.drag(find.byType(UtilityPicker), const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(find.byType(UtilityPicker), findsNothing);

    await tap(tester, 'reminder-button');
    await tap(tester, 'system-label');
    expect(find.byType(SystemPicker), findsNothing);
    expect(key('picker-done'), findsNothing);
    await tap(tester, 'system-label');
    expect(find.byType(SystemPicker), findsOneWidget);
    // The centre is the tick while they are up, and only then.
    await tap(tester, 'picker-done');
    expect(find.byType(SystemPicker), findsNothing);
    expect(key('system-label'), findsOneWidget);
  });

  testWidgets('a page opened in a room goes back to the room, and a room '
      'to the living room', (tester) async {
    await open(tester);
    await tap(tester, 'menu-button');
    await tap(tester, 'menu-colours');
    expect(find.byType(ColoursScreen), findsOneWidget);
    // The room's own button goes back to the room itself.
    await tap(tester, 'menu-button');
    expect(find.byType(ColoursScreen), findsNothing);
    expect(find.byType(MenuScreen), findsOneWidget);

    await tap(tester, 'menu-colours');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ColoursScreen), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      House.maybeOf(tester.element(find.byType(MonthScreen)))!.room.value,
      Room.living,
    );
  });

  testWidgets('the day goes from room to room', (tester) async {
    await open(tester);
    await tap(tester, 'journal-button');
    expect(find.text(strings.gregorian(today)), findsOneWidget);
    // Another day in the journal, from its own calendar.
    await tap(tester, 'journal-date');
    await tester.tap(
      find.descendant(of: key('journal-calendar'), matching: find.text('20')),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'journal-date');
    final twentieth = CivilDate(2026, 10, 20);
    expect(find.text(strings.gregorian(twentieth)), findsOneWidget);

    // Home takes it up, and hands it on to the reminders.
    await tap(tester, 'system-label');
    await tap(tester, 'reminder-button');
    expect(
      find.descendant(
        of: key('reminders-date'),
        matching: find.text(strings.gregorian(twentieth)),
      ),
      findsOneWidget,
    );

    // Today, from the bar, in the room in front; lit once there.
    expect(tester.widget<GlyphButton>(key('today-button')).lit, isFalse);
    await tap(tester, 'today-button');
    expect(
      find.descendant(
        of: key('reminders-date'),
        matching: find.text(strings.gregorian(today)),
      ),
      findsOneWidget,
    );
    expect(tester.widget<GlyphButton>(key('today-button')).lit, isTrue);
  });

  testWidgets('a page without days leaves today faint', (tester) async {
    await open(tester);
    await tap(tester, 'menu-button');
    final faint = tester.widget<Opacity>(
      find
          .ancestor(of: key('today-button'), matching: find.byType(Opacity))
          .first,
    );
    expect(faint.opacity, lessThan(1));
  });

  testWidgets('a room entered by its button stands as it first does: what '
      'was left open in it is put away', (tester) async {
    await open(tester);
    await tap(tester, 'journal-button');
    await tap(tester, 'categories');
    expect(find.byKey(const ValueKey('category-add')), findsOneWidget);
    await tap(tester, 'system-label');
    await tap(tester, 'journal-button');
    expect(find.byKey(const ValueKey('category-add')), findsNothing);
    expect(find.byType(JournalScreen), findsOneWidget);
  });
}
