import 'package:candra/app_shell.dart';
import 'package:candra/bar_button.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_screen.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/reminders/reminders_screen.dart';
import 'package:candra/search/search_screen.dart';
import 'package:candra/scroll_bars.dart';
import 'package:candra/strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// The search and the tags on screen: where their buttons stand, what the
/// panels do, and that a query narrows what is found.
void main() {
  Finder key(String name) => find.byKey(ValueKey(name));
  const offset = Duration(hours: 7);
  // A Kamis Kliwon, and not today.
  final day = CivilDate(2026, 10, 15);

  Future<(JournalStore, ReminderStore)> pump(
    WidgetTester tester,
    Widget home, {
    JournalStore? journal,
  }) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    final store = journal ?? JournalStore();
    final reminders = ReminderStore(utcOffset: offset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        journal: store,
        reminders: reminders,
        home: home,
      ),
    );
    await tester.pumpAndSettle();
    return (store, reminders);
  }

  Entry write(
    JournalStore store,
    CivilDate date,
    String title, {
    int minute = 600,
    List<String> tags = const [],
  }) => store.save(
    Entry(
      id: '',
      date: date,
      minuteOfDay: minute,
      utcOffset: offset,
      categoryId: store.categories.first.id,
      title: title,
      content: 'Words.',
      tags: tags,
    ),
  );

  testWidgets('the journal\'s search stands in the panel\'s top row, right '
      'of the categories\' capsule, and opens the search', (tester) async {
    await pump(
      tester,
      JournalScreen(date: day, utcOffset: offset, today: day.addDays(3)),
    );
    final line = tester.getRect(key('panel-separator'));
    final add = tester.getRect(key('new-entry'));
    final search = tester.getRect(key('journal-search'));
    expect(search.top, greaterThan(line.top));
    final dots = tester.getRect(key('category-picker'));
    expect(dots.left, moreOrLessEquals(16, epsilon: 0.1));
    expect(search.left - dots.right, moreOrLessEquals(8, epsilon: 0.1));
    expect(add.right, moreOrLessEquals(411.4 - 16, epsilon: 0.1));
    expect(search.center.dy, moreOrLessEquals(add.center.dy, epsilon: 0.1));

    await tester.tap(key('journal-search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('the search stays while the journal\'s and the reminders\' date '
      'pickers are up', (tester) async {
    await pump(
      tester,
      JournalScreen(date: day, utcOffset: offset, today: day.addDays(3)),
    );
    await tester.tap(key('journal-date'));
    await tester.pumpAndSettle();
    expect(key('journal-calendar'), findsOneWidget);
    expect(key('journal-search'), findsOneWidget);
    await tester.tap(key('journal-search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    // The reminders' room, through the house's bar.
    await tester.tap(key('reminder-button'));
    await tester.pumpAndSettle();
    await tester.tap(key('reminders-date'));
    await tester.pumpAndSettle();
    expect(key('reminders-calendar'), findsOneWidget);
    expect(key('reminders-search'), findsOneWidget);
  });

  testWidgets('the reminders\' date picker brings up their month, as the '
      'journal\'s does', (tester) async {
    await pump(tester, RemindersScreen(day: day, today: day.addDays(3)));
    expect(key('reminders-search'), findsOneWidget);
    await tester.tap(key('reminders-date'));
    await tester.pumpAndSettle();
    expect(key('reminders-calendar'), findsOneWidget);
  });

  testWidgets('a cycle chosen on the wheels narrows what is found; the view '
      'goes list, month, year', (tester) async {
    final journal = JournalStore();
    write(journal, day, 'On Kliwon');
    write(journal, day.addDays(1), 'On Legi');
    await pump(
      tester,
      SearchScreen(date: day, utcOffset: offset, today: day),
      journal: journal,
    );
    expect(find.text('On Kliwon'), findsOneWidget);
    expect(find.text('On Legi'), findsOneWidget);

    // The wheels open on the pasaran; turn the value to Kliwon (the fifth).
    await tester.drag(
      key('search-day-second-${0 + 1}'),
      const Offset(0, -36 * 4),
    );
    await tester.pumpAndSettle();
    await tester.tap(key('search-day-add'));
    await tester.pumpAndSettle();
    expect(key('search-cycle-pasaran-4'), findsOneWidget);
    expect(find.text('On Kliwon'), findsOneWidget);
    expect(find.text('On Legi'), findsNothing);
    expect(find.text('1 found'), findsOneWidget);

    // Touched, it comes off.
    await tester.tap(key('search-cycle-pasaran-4'));
    await tester.pumpAndSettle();
    expect(find.text('On Legi'), findsOneWidget);

    Glyph view() => tester.widget<GlyphButton>(key('search-view')).glyph;
    expect(view(), Glyph.monthView);
    await tester.tap(key('search-view'));
    await tester.pumpAndSettle();
    expect(key('search-month'), findsOneWidget);
    await tester.tap(key('search-view'));
    await tester.pumpAndSettle();
    expect(key('search-year-grid'), findsOneWidget);
    expect(view(), Glyph.list);
  });

  testWidgets('moving off the words puts the keyboard away and keeps '
      'what was typed', (tester) async {
    await pump(tester, SearchScreen(date: day, utcOffset: offset, today: day));
    // The words are at the far end of the row: along it first.
    await tester.drag(key('search-fields'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(key('search-field-words'));
    await tester.pumpAndSettle();
    expect(key('search-words-bar'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    // With the keyboard up the panel gives way to it, down to the fields
    // and the hint.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3.5);
    await tester.pumpAndSettle();
    expect(tester.getRect(key('search-panel')).height, lessThan(130));
    await tester.enterText(key('search-words'), 'garden');
    await tester.tap(key('search-field-evening'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(key('search-words-bar'), findsNothing);
    expect(find.textContaining('"garden"'), findsOneWidget);
  });

  testWidgets('on an iPhone or iPad the words keep their keyboard as their '
      'bar comes to be drawn over the glass', (tester) async {
    // The bar is the phone's own until it holds a field, when the app
    // draws it over a view of the system's glass. Going over, the field
    // was made anew: the one given the keyboard was thrown away, taking
    // the keyboard with it (19 October 2026).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    await pump(tester, SearchScreen(date: day, utcOffset: offset, today: day));
    await tester.drag(key('search-fields'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(key('search-field-words'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    final field = tester.state(find.byType(EditableText));
    tester.testTextInput.log.clear();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Drawn over the glass now, with the same field, and the keyboard
    // never sent away.
    expect(find.byType(UiKitView), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(field));
    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(contains('TextInput.clearClient')),
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pumpAndSettle();
    // Put away by its tick, it goes, and the bar is the phone's again.
    tester.widget<GlyphButton>(key('search-words-done')).onTap();
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(key('search-words-bar'), findsNothing);
    expect(find.byType(UiKitView), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the panel has more room than elsewhere, and a row that '
      'runs past the edge shows its bar', (tester) async {
    await pump(tester, SearchScreen(date: day, utcOffset: offset, today: day));
    final fields = tester.getRect(key('search-fields'));
    final separator = tester.getRect(key('panel-separator'));
    final bar = tester.getRect(key('journal-button'));
    // The panel has 9 parts to the upper area's 13. The parts start at
    // the top of the screen; the house bar's buttons stand 16 inside it.
    final barTop = bar.top - 16;
    expect(
      (barTop - separator.bottom) / (separator.top),
      moreOrLessEquals(9 / 13, epsilon: 0.03),
    );
    expect(fields.height, greaterThan(40));
    expect(find.byType(ScrollHint), findsWidgets);
  });

  testWidgets('a day on the year is picked through the glass: a touch puts '
      'it down with the date, a touch on it lists the day; held, it '
      'follows the finger and letting go lists that day', (tester) async {
    final journal = JournalStore();
    write(journal, day, 'On the day');
    await pump(
      tester,
      SearchScreen(date: day, utcOffset: offset, today: day),
      journal: journal,
    );
    await tester.tap(key('search-view'));
    await tester.pumpAndSettle();
    await tester.tap(key('search-view'));
    await tester.pumpAndSettle();
    final grid = tester.getRect(key('search-year-grid'));
    // Months by three letters.
    expect(find.byType(SearchScreen), findsOneWidget);

    Offset at(int month, int date) {
      const label = 30.0;
      final cell = (grid.width - label) / 31;
      return Offset(
        grid.left + label + (date - 0.5) * cell,
        grid.top + (month - 0.5) * grid.height / 12,
      );
    }

    // A touch: the glass, no list yet.
    await tester.tapAt(at(10, 15));
    await tester.pumpAndSettle();
    expect(key('search-year-glass'), findsOneWidget);
    expect(key('search-year-grid'), findsOneWidget);
    final glass = tester.widget<CustomPaint>(key('search-year-glass'));
    // ignore: invalid_use_of_protected_member
    expect((glass.painter as dynamic).date, contains('15 October 2026'));

    // Held and moved to the 15th of October from the 3rd of March.
    final gesture = await tester.startGesture(at(3, 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      (tester.widget<CustomPaint>(key('search-year-glass')).painter as dynamic)
          .date,
      contains('3 March 2026'),
    );
    await gesture.moveTo(at(10, 15));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(key('search-list'), findsOneWidget);
    expect(find.text('On the day'), findsOneWidget);
    expect(find.text('15 October 2026'), findsOneWidget);
  });

  testWidgets('look in is its own button, going round entries, reminders '
      'and both, with nothing under it; the evening uses half the panel', (
    tester,
  ) async {
    await pump(tester, SearchScreen(date: day, utcOffset: offset, today: day));
    String label() =>
        tester.widget<BarButton>(key('search-field-lookIn')).label;
    expect(label(), 'Entries');
    await tester.tap(key('search-field-lookIn'));
    await tester.pumpAndSettle();
    expect(label(), 'Reminders');
    final cover = tester.getRect(key('search-cover'));
    final panel = tester.getRect(key('search-panel'));
    expect(cover.bottom, moreOrLessEquals(panel.bottom, epsilon: 1));
    expect(cover.top, lessThan(panel.top + 70));
    await tester.tap(key('search-field-lookIn'));
    await tester.pumpAndSettle();
    expect(label(), 'Both');
    await tester.tap(key('search-field-lookIn'));
    await tester.pumpAndSettle();
    expect(label(), 'Entries');

    await tester.drag(key('search-fields'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(key('search-field-evening'));
    await tester.pumpAndSettle();
    final half = tester.getRect(key('search-cover'));
    final strip = tester.getRect(key('search-fields'));
    expect(
      half.height,
      moreOrLessEquals((panel.bottom - strip.bottom) / 2, epsilon: 1),
    );
    expect(key('search-evening-sunset'), findsOneWidget);
  });

  testWidgets('a row of a wheel touched turns the wheel to it', (tester) async {
    await pump(tester, SearchScreen(date: day, utcOffset: offset, today: day));
    // The cycle wheel opens on the pasaran; Weton is the row under it.
    await tester.tap(find.text('Weton'));
    await tester.pumpAndSettle();
    await tester.tap(key('search-day-add'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-cycle-weton-0')), findsOneWidget);
  });

  testWidgets('an entry being read takes a new tag from its tag button, '
      'saved at once', (tester) async {
    final journal = JournalStore();
    final entry = write(journal, day, 'Garden');
    await pump(
      tester,
      EntryScreen(date: day, utcOffset: offset, entry: entry),
      journal: journal,
    );
    // At the sheet's bottom right: the tags, then editing.
    final tags = tester.getRect(key('entry-tags'));
    final edit = tester.getRect(key('entry-edit'));
    final sheet = tester.getRect(key('entry-sheet'));
    expect(tags.right, lessThan(edit.left));
    expect(tags.center.dy, moreOrLessEquals(edit.center.dy, epsilon: 0.1));
    expect(edit.right, lessThan(sheet.right));
    expect(edit.right, greaterThan(sheet.right - 40));
    expect(edit.bottom, lessThan(sheet.bottom));
    expect(edit.bottom, greaterThan(sheet.bottom - 40));

    await tester.tap(key('entry-tags'));
    await tester.pumpAndSettle();
    expect(key('tag-panel'), findsOneWidget);
    await tester.tap(key('tag-new'));
    await tester.pumpAndSettle();
    expect(key('tag-name-bar'), findsOneWidget);
    await tester.enterText(key('tag-name'), 'chilli');
    await tester.tap(key('tag-name-done'));
    await tester.pumpAndSettle();

    final tag = journal.tags.single;
    expect(tag.name, 'chilli');
    final saved = journal
        .entriesFor(day, utcOffset: offset)
        .firstWhere((e) => e.title == 'Garden');
    expect(saved.tags, [tag.id]);
    // Touched again, it comes off.
    await tester.tap(key('tag-${tag.id}'));
    await tester.pumpAndSettle();
    expect(
      journal
          .entriesFor(day, utcOffset: offset)
          .firstWhere((e) => e.title == 'Garden')
          .tags,
      isEmpty,
    );
  });

  testWidgets('a reminder takes tags from its tag button, kept on Save', (
    tester,
  ) async {
    final journal = JournalStore();
    final chilli = journal.addTag('chilli')!;
    final (_, reminders) = await pump(
      tester,
      ReminderScreen(
        day: day,
        reminder: Reminder(
          id: 'r1',
          title: 'Water',
          start: day,
          minuteOfDay: 420,
          repeat: Repeat.daily,
          categoryId: journal.categories.first.id,
        ),
      ),
      journal: journal,
    );
    final tags = tester.getRect(key('reminder-tags'));
    expect(tags.right, lessThan(tester.getRect(key('reminder-save')).left));
    await tester.tap(key('reminder-tags'));
    await tester.pumpAndSettle();
    await tester.tap(key('tag-${chilli.id}'));
    await tester.pumpAndSettle();
    await tester.tap(key('reminder-save'));
    await tester.pumpAndSettle();
    expect(reminders.reminder('r1')!.tags, [chilli.id]);
  });

  testWidgets('a reminder makes a new category from its category, named '
      'over the keyboard and chosen at once', (tester) async {
    final journal = JournalStore();
    final before = journal.categories.length;
    final (_, reminders) = await pump(
      tester,
      ReminderScreen(
        day: day,
        reminder: Reminder(
          id: 'r1',
          title: 'Water',
          start: day,
          minuteOfDay: 420,
          repeat: Repeat.daily,
          categoryId: journal.categories.first.id,
        ),
      ),
      journal: journal,
    );
    await tester.tap(key('field-category'));
    await tester.pumpAndSettle();
    await tester.tap(key('reminder-category-new'));
    await tester.pumpAndSettle();
    expect(key('tag-name-bar'), findsOneWidget);
    expect(find.text('Category name'), findsOneWidget);

    // No name: nothing made, and it says so.
    await tester.tap(key('tag-name-done'));
    await tester.pump();
    expect(find.text('Give it a name first.'), findsOneWidget);
    expect(journal.categories, hasLength(before));

    await tester.enterText(key('tag-name'), 'Garden');
    await tester.tap(key('tag-name-done'));
    await tester.pumpAndSettle();
    expect(key('tag-name-bar'), findsNothing);
    final garden = journal.categories.last;
    expect(garden.name, 'Garden');
    expect(journal.categories, hasLength(before + 1));
    await tester.tap(key('reminder-save'));
    await tester.pumpAndSettle();
    expect(reminders.reminder('r1')!.categoryId, garden.id);
  });

  testWidgets('back while a new category is named puts the name away, not '
      'the reminder', (tester) async {
    final journal = JournalStore();
    final before = journal.categories.length;
    await pump(
      tester,
      ReminderScreen(day: day, categoryId: journal.categories.first.id),
      journal: journal,
    );
    await tester.tap(key('field-category'));
    await tester.pumpAndSettle();
    await tester.tap(key('reminder-category-new'));
    await tester.pumpAndSettle();
    await tester.enterText(key('tag-name'), 'Half');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(key('tag-name-bar'), findsNothing);
    expect(key('reminder-save'), findsOneWidget);
    expect(journal.categories, hasLength(before));
  });

  testWidgets('an entry\'s date and time are changed from its top line while '
      'editing, and saved with the tick', (tester) async {
    final journal = JournalStore();
    final entry = write(journal, day, 'Moving', minute: 600);
    await pump(
      tester,
      EntryScreen(date: day, utcOffset: offset, entry: entry),
      journal: journal,
    );
    // Reading: the top line is folded away; editing, it shows.
    await tester.tap(key('entry-edit'));
    await tester.pumpAndSettle();
    await tester.tap(key('entry-when-change'));
    await tester.pumpAndSettle();
    expect(key('entry-when-panel'), findsOneWidget);
    // An hour on, by the time wheel.
    await tester.tap(key('entry-when-time'));
    await tester.pumpAndSettle();
    await tester.drag(
      find
          .descendant(
            of: key('entry-when-panel'),
            matching: find.byType(ListWheelScrollView),
          )
          .first,
      const Offset(0, -36),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('11:00'), findsWidgets);
    // Not yet saved.
    expect(journal.entriesFor(day, utcOffset: offset).single.minuteOfDay, 600);
    await tester.tap(key('entry-done'));
    await tester.pumpAndSettle();
    final moved = journal.entriesFor(day, utcOffset: offset).single;
    expect(moved.minuteOfDay, 660);
    expect(moved.title, 'Moving');
  });
}
