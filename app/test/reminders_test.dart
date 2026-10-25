import 'dart:io';

import 'package:candra/app_shell.dart';
import 'package:candra/day_reading.dart';
import 'package:candra/day_strip.dart';
import 'package:candra/dot_picker.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/journal/card_stack.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/parts.dart';
import 'package:candra/journal/journal_archive.dart';
import 'package:candra/main.dart';
import 'package:candra/month_grid.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/reading_screen.dart';
import 'package:candra/year_grid.dart';
import 'package:candra/reminders/announcer.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/search/query.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/reminders/reminder_screen.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/reminders/reminders_screen.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// Stands in for the phone: remembers what it was asked to announce.
class FakeAnnouncer implements Announcer {
  FakeAnnouncer({this.allowed = true});

  final bool allowed;
  var asked = 0;
  var waiting = <Announcement>[];

  @override
  Future<bool> askAllowed() async {
    asked++;
    return allowed;
  }

  @override
  Future<void> replaceAll(List<Announcement> announcements) async =>
      waiting = announcements;
}

void main() {
  const offset = Duration(hours: 7);
  final today = CivilDate(2026, 10, 11);
  // Noon on the 11th.
  DateTime now() => DateTime(2026, 10, 11, 12);

  setUp(() {
    HanziChoice.date.value = false;
    HanziChoice.zodiac.value = false;
  });

  Reminder draft(
    String title, {
    Repeat repeat = Repeat.once,
    int minute = 19 * 60 + 30,
    CivilDate? start,
  }) => Reminder(
    id: '',
    title: title,
    start: start ?? today,
    minuteOfDay: minute,
    repeat: repeat,
  );

  group('the store', () {
    late Directory root;
    late FakeAnnouncer phone;

    ReminderStore open() => ReminderStore(
      file: File('${root.path}/journal/reminders.json'),
      announcer: phone,
      utcOffset: offset,
      now: now,
    );

    setUp(() {
      root = Directory.systemTemp.createTempSync('reminders-test');
      phone = FakeAnnouncer();
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('keeps reminders in a file in the journal folder', () {
      final store = open();
      final saved = store.save(draft('Offering', repeat: Repeat.weton));
      expect(saved.id, matches(RegExp(r'^[0-9a-f]{6}$')));
      store.save(saved.copyWith(title: 'Evening offering'));
      store.save(draft('Fast'));

      final again = open();
      expect(again.reminders.map((r) => r.title), ['Evening offering', 'Fast']);
      expect(again.reminder(saved.id)!.repeat, Repeat.weton);

      again.delete(saved.id);
      expect(open().reminders.map((r) => r.title), ['Fast']);
    });

    test('knows which days have reminders, and which do not', () {
      final store = open();
      store.save(draft('Offering', repeat: Repeat.weton, minute: 20 * 60));
      store.save(draft('Fast', minute: 6 * 60));

      expect(store.on(today).map((r) => r.title), ['Fast', 'Offering']);
      expect(store.on(today.addDays(1)), isEmpty);
      expect(store.on(today.addDays(35)).map((r) => r.title), ['Offering']);

      // One switched off is on no day.
      final offering = store.reminders.first;
      store.save(offering.copyWith(enabled: false));
      expect(store.on(today.addDays(35)), isEmpty);
    });

    test('hands the phone the coming days of each reminder, soonest first', () {
      final store = open();
      // 19:30 today is still to come; 06:00 today has passed.
      store.save(draft('Offering', repeat: Repeat.weton));
      store.save(draft('Dawn', repeat: Repeat.daily, minute: 6 * 60));
      store.save(draft('Gone', minute: 6 * 60));

      final waiting = phone.waiting;
      expect(waiting.first.title, 'Offering');
      expect(waiting.first.when, DateTime(2026, 10, 11, 19, 30));
      expect(waiting.first.body, 'Minggu Legi · 19:30');
      // Dawn starts tomorrow; the one-off at six has gone by.
      expect(waiting[1].title, 'Dawn');
      expect(waiting[1].when, DateTime(2026, 10, 12, 6));
      expect(waiting.any((a) => a.title == 'Gone'), isFalse);
      // So many of each, in order of time, each with its own number.
      expect(
        waiting.where((a) => a.title == 'Dawn'),
        hasLength(ReminderStore.perReminder),
      );
      expect(
        waiting.where((a) => a.title == 'Offering'),
        hasLength(ReminderStore.perReminder),
      );
      for (var i = 1; i < waiting.length; i++) {
        expect(waiting[i].when.isBefore(waiting[i - 1].when), isFalse);
      }
      expect(waiting.map((a) => a.id).toSet(), hasLength(waiting.length));
    });

    test('a reminder by the sun is handed over at the place\'s sunset, '
        'less its lead, and only once there is a place', () {
      ({double latitude, double longitude})? place;
      final store = ReminderStore(
        file: File('${root.path}/journal/reminders.json'),
        announcer: phone,
        utcOffset: offset,
        now: now,
        placeOf: () => place,
      );
      final saved = store.save(
        draft(
          'Golden',
          repeat: Repeat.daily,
        ).copyWith(sun: SunAnchor.sunset, lead: 30),
      );
      expect(phone.waiting.any((a) => a.title == 'Golden'), isFalse);

      place = (latitude: -7.8, longitude: 110.4);
      store.announce();
      final first = phone.waiting.firstWhere((a) => a.title == 'Golden');
      final date = CivilDate(first.when.year, first.when.month, first.when.day);
      final minute = saved.minuteOn(
        date,
        place: place,
        utcOffset: DateTime(date.year, date.month, date.day, 12).timeZoneOffset,
      )!;
      expect(first.when.hour * 60 + first.when.minute, minute);
      expect(
        first.body,
        endsWith(
          '${(minute ~/ 60).toString().padLeft(2, '0')}:'
          '${(minute % 60).toString().padLeft(2, '0')}',
        ),
      );
    });

    test('the search reckons a sun reminder\'s evening by that day\'s '
        'sun, not the time it was last set to', () {
      const yogya = (latitude: -7.8, longitude: 110.4);
      final store = ReminderStore(
        file: File('${root.path}/journal/reminders.json'),
        announcer: phone,
        utcOffset: offset,
        now: now,
        placeOf: () => yogya,
      );
      // The evening blue hour comes after sunset, though the time kept
      // with it says noon.
      final blue = store.save(
        draft(
          'Blue',
          repeat: Repeat.daily,
          minute: 12 * 60,
        ).copyWith(sun: SunAnchor.eveningBlue),
      );
      expect(store.minuteOf(blue, today), greaterThan(17 * 60));
      int sunsetOn(CivilDate date) {
        final set = SkyNow.day(
          Body.sun,
          date,
          latitude: yogya.latitude,
          longitude: yogya.longitude,
          utcOffset: offset,
        ).set!.add(offset);
        return set.hour * 60 + set.minute;
      }

      // Asked for the next day's weekday, with the evening turning at
      // sunset: the blue hour counts as the next day.
      final query = SearchQuery(
        entries: false,
        reminders: true,
        evening: Evening.sunset,
        cycles: {
          CycleKind.weekday: {Weekday.of(today.addDays(1)).index},
        },
      );
      expect(query.remindersOn(store, today, sunset: sunsetOn), contains(blue));
    });

    test('tells the phone again after every change, and at the start', () {
      final store = open();
      final saved = store.save(draft('Offering'));
      expect(phone.waiting, hasLength(1));

      store.save(saved.copyWith(enabled: false));
      expect(phone.waiting, isEmpty);
      store.save(saved.copyWith(enabled: true));
      expect(phone.waiting, hasLength(1));

      store.delete(saved.id);
      expect(phone.waiting, isEmpty);

      // A fresh start, as after the app is opened again: the phone is told
      // what is waiting without anything having changed.
      store.save(draft('Fast'));
      phone = FakeAnnouncer();
      open();
      expect(phone.waiting, hasLength(1));
    });

    test('never hands over more than the phone will keep', () {
      final store = open();
      for (var i = 0; i < 20; i++) {
        store.save(draft('Daily $i', repeat: Repeat.daily, minute: i));
      }
      expect(phone.waiting, hasLength(ReminderStore.announcedAtMost));
    });

    test('goes out with the journal and comes back in, without doubles', () {
      final store = open();
      final saved = store.save(draft('Offering', repeat: Repeat.javaneseYear));
      final zip = JournalArchive.pack(
        '${root.path}/journal',
        exportedAt: 'now',
      );
      final contents = JournalArchive.unpack(zip);
      expect(contents.reminders.single.id, saved.id);
      expect(contents.reminders.single.repeat, Repeat.javaneseYear);

      final other = ReminderStore(utcOffset: offset, now: now);
      expect(other.merge(contents.reminders), 1);
      expect(other.merge(contents.reminders), 0);
      expect(other.reminders.single.title, 'Offering');
    });
  });

  group('the screen', () {
    Finder key(String name) => find.byKey(ValueKey(name));

    Future<(ReminderStore, FakeAnnouncer)> pump(
      WidgetTester tester, {
      bool allowed = true,
      AppLanguage language = AppLanguage.en,
      Widget? home,
    }) async {
      tester.view.physicalSize = const Size(1440, 3040);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      final phone = FakeAnnouncer(allowed: allowed);
      final store = ReminderStore(
        announcer: phone,
        utcOffset: offset,
        now: now,
      );
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(saved: language),
          reminders: store,
          home: home ?? RemindersScreen(day: today, today: today),
        ),
      );
      await tester.pumpAndSettle();
      return (store, phone);
    }

    Future<void> tap(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Finder titleField() => find.descendant(
      of: key('reminder-title'),
      matching: find.byType(EditableText),
    );

    // Turns the wheel of repeats, which must be in the lower panel, by
    // [items] places.
    Future<void> spinRepeat(WidgetTester tester, int items) async {
      await tester.drag(key('picker-repeat'), Offset(0, -36.0 * items));
      await tester.pumpAndSettle();
    }

    // What the top bar says of the reminder being written.
    Finder inTopBar(String words) => find.descendant(
      of: key('reminder-top-bar'),
      matching: find.textContaining(words),
    );

    test('a reminder can repeat in the words of every calendar', () {
      final strings = Strings(AppLanguage.en);
      final offered = Reminder.offeredFor(today, utcOffset: offset);
      // The ways the 11th of October 2026 can come round again.
      expect(
        [for (final r in offered) strings.repeatLabel(r, today, offset)],
        [
          'Once',
          'Every day',
          'Every Sunday',
          'Every Legi',
          'Every Minggu Legi',
          'Day 11 of every month',
          'Every 11 October',
          'Javanese: day 28 of every month',
          'Javanese: every 28 Bakdamulud',
          'Hijri: day 28 of every month',
          "Hijri: every 28 Rabi' al-Thani",
          'Chinese: day 2 of every month',
          'Chinese: every 2 Kau Gwee',
        ],
      );
    });

    testWidgets('making a reminder: a name, and how it repeats in the words '
        'of its day', (tester) async {
      final (store, phone) = await pump(tester);
      expect(find.text('No reminders yet.'), findsOneWidget);

      await tap(tester, key('reminder-add'));
      expect(find.byType(ReminderScreen), findsOneWidget);
      expect(find.text('New reminder'), findsOneWidget);
      // The time has the lower panel to begin with.
      expect(key('picker-hour'), findsOneWidget);

      // Saved with no name, nothing is saved: Save leaves as cancelling
      // would, the way out while the keyboard is up.
      await tap(tester, key('reminder-save'));
      expect(find.byType(ReminderScreen), findsNothing);
      expect(store.reminders, isEmpty);
      expect(find.text('No reminders yet.'), findsOneWidget);
      await tap(tester, key('reminder-add'));

      await tester.enterText(titleField(), 'Offering');
      // The line for the repeat brings its wheel into the lower panel.
      await tap(tester, key('field-repeat'));
      expect(key('picker-hour'), findsNothing);
      expect(inTopBar('Once'), findsOneWidget);
      await spinRepeat(tester, 4);
      expect(inTopBar('Every Minggu Legi'), findsOneWidget);
      // No moon: the 11th is not a day of its phases.
      await spinRepeat(tester, 20);
      expect(inTopBar('Chinese: every 2 Kau Gwee'), findsOneWidget);
      await spinRepeat(tester, -8);
      expect(inTopBar('Every Minggu Legi'), findsOneWidget);
      await tap(tester, key('reminder-save'));

      final saved = store.reminders.single;
      expect(saved.title, 'Offering');
      expect(saved.repeat, Repeat.weton);
      expect(saved.start, today);
      // It went into the category at the front: the first.
      expect(saved.categoryId, 'ritual');
      // The phone was asked whether it may, and told what to announce.
      expect(phone.asked, 1);
      expect(phone.waiting, isNotEmpty);
      // Back on the cards.
      expect(find.byType(ReminderScreen), findsNothing);
      expect(find.text('Offering'), findsOneWidget);
      expect(find.textContaining('Every Minggu Legi'), findsOneWidget);
      expect(find.textContaining('next'), findsOneWidget);
      expect(find.text('No reminders yet.'), findsNothing);
    });

    testWidgets('a reminder by the sun: the anchor and the lead from the '
        'time\'s panel', (tester) async {
      SkyPlace.current.value = (latitude: -7.8, longitude: 110.4);
      addTearDown(() => SkyPlace.current.value = null);
      final (store, _) = await pump(tester);
      await tap(tester, key('reminder-add'));
      await tester.enterText(titleField(), 'Golden light');
      await tester.scrollUntilVisible(
        key('reminder-anchor-sunset'),
        60,
        scrollable: find.descendant(
          of: key('reminder-anchors'),
          matching: find.byType(Scrollable),
        ),
      );
      await tap(tester, key('reminder-anchor-sunset'));
      expect(key('picker-hour'), findsNothing);
      expect(key('reminder-sun-note'), findsOneWidget);
      await tester.scrollUntilVisible(
        key('reminder-lead-20'),
        60,
        scrollable: find.descendant(
          of: key('reminder-leads'),
          matching: find.byType(Scrollable),
        ),
      );
      await tap(tester, key('reminder-lead-20'));
      expect(find.textContaining('Sunset · 20 min before'), findsWidgets);
      await tap(tester, key('reminder-save'));
      final saved = store.reminders.single;
      expect(saved.sun, SunAnchor.sunset);
      expect(saved.lead, 20);
    });

    testWidgets('is laid out as the journal is: cards by category, the '
        'category picker over the day strip', (tester) async {
      final (store, _) = await pump(tester);
      store.save(draft('Fast').copyWith(categoryId: 'dream'));
      store.save(
        draft('Offering', repeat: Repeat.pasaran).copyWith(categoryId: 'dream'),
      );
      store.save(draft('Water').copyWith(categoryId: 'plant'));
      // One from before reminders had categories goes under the first.
      store.save(draft('Old'));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(key('reminder-count')).data, 'REMINDERS · 4');
      // The rail has a page for every category, and opens on the first
      // with anything in it.
      expect(find.byType(CardStack), findsNothing);
      expect(key('rail-ritual'), findsOneWidget);
      expect(
        find.descendant(of: key('rail-ritual'), matching: find.text('Old')),
        findsOneWidget,
      );
      // The picker has every category; those with none are hollow.
      final picker = tester.widget<DotPicker>(key('category-picker'));
      expect(picker.dots, hasLength(5));
      expect(picker.hollow, {'observance', 'divination'});
      expect(picker.selected, 'ritual');

      // The four parts, top to bottom.
      final line = tester.getRect(key('panel-separator'));
      expect(
        tester.getRect(key('reminder-rail')).bottom,
        lessThanOrEqualTo(line.top),
      );
      expect(tester.getRect(key('category-picker')).top, greaterThan(line.top));
      expect(
        tester.getRect(key('day-strip')).top,
        greaterThanOrEqualTo(tester.getRect(key('category-picker')).bottom),
      );
      // The house's bar under the lower panel.
      expect(
        tester.getRect(key('reminder-button')).top,
        greaterThan(tester.getRect(key('day-strip')).bottom),
      );
      // As in the journal, along the panel's top: the dots' capsule from
      // the left, then the search, the categories and adding on the
      // right, each the same gap from the next.
      final search = tester.getRect(key('reminders-search'));
      final dots = tester.getRect(key('category-picker'));
      final categories = tester.getRect(key('categories'));
      final add = tester.getRect(key('reminder-add'));
      expect(search.top, greaterThan(line.top));
      expect(dots.left, closeTo(16, 0.1));
      expect(search.left - dots.right, closeTo(8, 0.1));
      expect(categories.left - search.right, closeTo(8, 0.1));
      expect(add.left - categories.right, closeTo(8, 0.1));
      expect(add.right, closeTo(411.43 - 16, 0.1));
      expect(add.center.dy, closeTo(search.center.dy, 0.1));
      // Delete is a red trash can at the top bar's right, over the
      // count of them all at the subtitle's right.
      final trash = tester.getRect(key('delete-card'));
      expect(
        tester.widget<GlyphButton>(key('delete-card')).glyph,
        Glyph.delete,
      );
      expect(trash.bottom, lessThan(line.top));
      expect(
        trash.center.dy,
        closeTo(tester.getCenter(key('reminders-date')).dy, 0.5),
      );
      final count = tester.getRect(key('reminder-count'));
      expect(count.top, greaterThan(trash.top));
      expect(count.right, closeTo(trash.right, 1));
      expect(count.bottom, lessThan(line.top));

      // A hollow dot brings an empty card to the front, and a new
      // reminder goes into it.
      await tap(tester, key('pick-observance'));
      expect(find.text('No reminders yet.'), findsOneWidget);
      await tap(tester, key('reminder-add'));
      await tester.enterText(titleField(), 'Vigil');
      await tap(tester, key('reminder-save'));
      expect(
        store.reminders.firstWhere((r) => r.title == 'Vigil').categoryId,
        'observance',
      );
    });

    testWidgets('the day strip walks the days; the days a reminder falls on '
        'wear its ring', (tester) async {
      final (store, _) = await pump(tester);
      final offering = store.save(
        draft('Offering', repeat: Repeat.pasaran).copyWith(categoryId: 'dream'),
      );
      await tester.pumpAndSettle();
      await tap(tester, key('pick-dream'));
      final strip = tester.widget<DayStrip>(find.byType(DayStrip));
      expect(strip.rings, isTrue);
      expect(strip.dotsOf(today), hasLength(1));
      expect(strip.dotsOf(today.addDays(1)), isEmpty);
      expect(strip.dotsOf(today.addDays(5)), hasLength(1));

      Color fill() =>
          (tester
                      .widget<AnimatedContainer>(
                        find
                            .descendant(
                              of: key('reminder-${offering.id}'),
                              matching: find.byType(AnimatedContainer),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(find.text('11 October 2026'), findsOneWidget);
      final lit = fill();

      // A day on, it does not fall, and its tile goes quiet; it is still
      // listed.
      final width = tester.getSize(key('day-strip')).width;
      await tester.drag(key('day-strip'), Offset(-width / 5, 0));
      await tester.pumpAndSettle();
      expect(find.text('12 October 2026'), findsOneWidget);
      expect(find.text('Offering'), findsOneWidget);
      expect(fill().a, lessThan(lit.a));
      expect(tester.widget<GlyphButton>(key('today-button')).lit, isFalse);

      // A new reminder starts on the day stood on.
      await tap(tester, key('reminder-add'));
      await tester.enterText(titleField(), 'Tomorrow');
      await tap(tester, key('reminder-save'));
      expect(
        store.reminders.firstWhere((r) => r.title == 'Tomorrow').start,
        today.addDays(1),
      );

      await tap(tester, key('today-button'));
      expect(find.text('11 October 2026'), findsOneWidget);
      expect(tester.widget<GlyphButton>(key('today-button')).lit, isTrue);
    });

    testWidgets('a flick carries the day strip on over several days', (
      tester,
    ) async {
      await pump(tester);
      await tester.fling(key('day-strip'), const Offset(-60, 0), 1500);
      await tester.pumpAndSettle();
      final landed = tester.widget<TopBarButton>(key('reminders-date')).label;
      final day = int.parse(landed.split(' ').first);
      // Well past the next day, and at rest on a day, not between two.
      expect(day, greaterThan(13));
      final strip = tester.widget<DayStrip>(find.byType(DayStrip));
      expect(strip.controller.page! % 1, closeTo(0, 0.001));
    });

    testWidgets('the top bar raises the date picker, as in the journal', (
      tester,
    ) async {
      await pump(tester);
      await tap(tester, key('reminders-date'));
      expect(key('day-strip'), findsNothing);
      await tester.drag(key('picker-day'), const Offset(0, -36 * 3));
      await tester.pumpAndSettle();
      expect(find.text('14 October 2026'), findsOneWidget);
      // The house's bar stays as it is meanwhile; the date button, tapped
      // again, puts the picker away.
      expect(key('reminder-button'), findsOneWidget);
      await tap(tester, key('reminders-date'));
      // The strip comes back on the day picked.
      expect(
        tester.widget<DayStrip>(find.byType(DayStrip)).controller.initialPage,
        CivilDate(2026, 10, 14).dayNumber,
      );
      expect(find.text('14 October 2026'), findsOneWidget);
    });

    testWidgets('the cross deletes all of a category\'s reminders, after '
        'asking', (tester) async {
      final (store, _) = await pump(tester);
      // Nothing to delete yet.
      await tester.tap(key('delete-card'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(key('confirm-delete'), findsNothing);

      store.save(draft('Fast').copyWith(categoryId: 'dream'));
      store.save(draft('Offering').copyWith(categoryId: 'dream'));
      store.save(draft('Water').copyWith(categoryId: 'plant'));
      await tester.pumpAndSettle();
      await tap(tester, key('pick-dream'));

      await tap(tester, key('delete-card'));
      expect(
        find.textContaining(
          'This deletes EVERY reminder in Dream, on every date: all 2 reminders.',
        ),
        findsOneWidget,
      );
      await tap(tester, key('confirm-cancel'));
      expect(store.reminders, hasLength(3));

      await tap(tester, key('delete-card'));
      await tap(tester, key('confirm-delete'));
      expect(store.reminders.map((r) => r.title), ['Water']);
    });

    testWidgets('the journal and the reminders switch places on the same '
        'day, and the calendar follows whichever is left', (tester) async {
      await pump(
        tester,
        home: MonthScreen(today: today, utcOffset: offset),
      );
      await tap(tester, key('reminder-button'));
      expect(find.byType(RemindersScreen), findsOneWidget);
      final width = tester.getSize(key('day-strip')).width;
      await tester.drag(key('day-strip'), Offset(-2 * width / 5, 0));
      await tester.pumpAndSettle();
      expect(find.text('13 October 2026'), findsOneWidget);

      // The journal's button, beside the reminders' in the house's bar.
      expect(
        tester.getRect(key('journal-button')).left,
        greaterThan(tester.getRect(key('reminder-button')).right),
      );
      await tap(tester, key('journal-button'));
      expect(find.byType(RemindersScreen), findsNothing);
      expect(find.byType(JournalScreen), findsOneWidget);
      expect(find.text('13 October 2026'), findsOneWidget);

      await tester.drag(key('day-strip'), Offset(-width / 5, 0));
      await tester.pumpAndSettle();
      await tap(tester, key('reminder-button'));
      expect(find.byType(JournalScreen), findsNothing);
      expect(find.byType(RemindersScreen), findsOneWidget);
      expect(find.text('14 October 2026'), findsOneWidget);

      // The system at the bar's centre, from whichever: one step, and the
      // calendar is on that day.
      await tap(tester, key('system-label'));
      expect(find.byType(RemindersScreen), findsNothing);
      expect(find.byType(JournalScreen), findsNothing);
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(find.text('14 October 2026'), findsOneWidget);
    });

    testWidgets('the bell stands under the time, as wide as it, on the line '
        'of the last words', (tester) async {
      final (store, _) = await pump(tester);
      final saved = store.save(draft('Offering', repeat: Repeat.daily));
      await tester.pumpAndSettle();
      final time = tester.getRect(key('reminder-time-${saved.id}'));
      final bell = tester.getRect(key('reminder-toggle-${saved.id}'));
      final next = tester.getRect(find.textContaining('next'));
      expect(bell.top, greaterThan(time.bottom));
      expect(bell.left, closeTo(time.left, 0.01));
      expect(bell.width, closeTo(time.width, 0.01));
      expect(bell.bottom, closeTo(next.bottom, 0.01));
      // In the category's colour while on.
      expect(
        tester.widget<GlyphButton>(key('reminder-toggle-${saved.id}')).tint,
        categoryPalette[2],
      );
    });

    testWidgets('says so when the phone will not show notifications', (
      tester,
    ) async {
      final (store, _) = await pump(tester, allowed: false);
      await tap(tester, key('reminder-add'));
      await tester.enterText(titleField(), 'Offering');
      await tester.tap(key('reminder-save'));
      await tester.pumpAndSettle();

      // Saved all the same.
      expect(store.reminders, hasLength(1));
      expect(find.textContaining('notifications are off'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('the bell on a tile switches a reminder off and on', (
      tester,
    ) async {
      final (store, phone) = await pump(tester);
      final saved = store.save(draft('Offering', repeat: Repeat.daily));
      await tester.pumpAndSettle();
      final bell = key('reminder-toggle-${saved.id}');
      expect(tester.widget<GlyphButton>(bell).lit, isTrue);

      await tap(tester, bell);
      expect(store.reminder(saved.id)!.enabled, isFalse);
      expect(tester.widget<GlyphButton>(bell).lit, isFalse);
      expect(find.text('off'), findsOneWidget);
      expect(phone.waiting, isEmpty);

      await tap(tester, bell);
      expect(store.reminder(saved.id)!.enabled, isTrue);
      expect(phone.waiting, isNotEmpty);
    });

    testWidgets('a tile opens for changes: each line has its instrument; '
        'the bin asks before deleting', (tester) async {
      final (store, _) = await pump(tester);
      final saved = store.save(draft('Offering'));
      await tester.pumpAndSettle();

      await tap(tester, key('reminder-${saved.id}'));
      expect(find.text('Edit reminder'), findsOneWidget);
      expect(
        tester.widget<EditableText>(titleField()).controller.text,
        'Offering',
      );
      await tester.enterText(titleField(), 'Evening offering');

      // The category: any of the journal's.
      await tap(tester, key('field-category'));
      expect(
        tester.widget<DotPicker>(key('reminder-category')).selected,
        'ritual',
      );
      await tap(tester, key('pick-dream'));
      // The first day: the date wheels.
      await tap(tester, key('field-start'));
      await tester.drag(key('picker-day'), const Offset(0, -36));
      await tester.pumpAndSettle();
      // The time.
      await tap(tester, key('field-time'));
      await tester.drag(key('picker-hour'), const Offset(0, -36));
      await tester.pumpAndSettle();
      // The repeat, now in the words of the 12th.
      await tap(tester, key('field-repeat'));
      await spinRepeat(tester, 3);
      expect(inTopBar('Every Pahing · 20:30'), findsOneWidget);
      await tap(tester, key('reminder-save'));

      final changed = store.reminder(saved.id)!;
      expect(changed.title, 'Evening offering');
      expect(changed.categoryId, 'dream');
      expect(changed.start, today.addDays(1));
      expect(changed.minuteOfDay, 20 * 60 + 30);
      expect(changed.repeat, Repeat.pasaran);
      // Back on the cards, its new category's card at the front.
      expect(
        tester.widget<DotPicker>(key('category-picker')).selected,
        'dream',
      );

      await tap(tester, key('reminder-${saved.id}'));
      await tap(tester, key('reminder-delete'));
      expect(
        find.text('Delete the reminder Evening offering?'),
        findsOneWidget,
      );
      expect(store.reminders, hasLength(1));
      // The lower panel steps aside for the question.
      expect(key('reminder-panel'), findsNothing);
      // The cross takes the question back.
      await tap(tester, key('confirm-cancel'));
      expect(find.byType(ReminderScreen), findsOneWidget);
      expect(key('reminder-panel'), findsOneWidget);

      await tap(tester, key('reminder-delete'));
      await tap(tester, key('confirm-delete'));
      expect(store.reminders, isEmpty);
      expect(find.byType(ReminderScreen), findsNothing);
      expect(find.text('No reminders yet.'), findsOneWidget);
    });

    testWidgets('back leaves the editor with nothing changed', (tester) async {
      final (store, _) = await pump(tester);
      await tap(tester, key('reminder-add'));
      await tester.enterText(titleField(), 'Never mind');
      // Back, with a name written, leaves without saving it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(store.reminders, isEmpty);
      expect(find.byType(ReminderScreen), findsNothing);

      await tap(tester, key('reminder-add'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ReminderScreen), findsNothing);
      expect(find.byType(RemindersScreen), findsOneWidget);
    });

    testWidgets('the lower panel steps aside for the keyboard', (tester) async {
      await pump(tester);
      await tap(tester, key('reminder-add'));
      expect(key('reminder-panel'), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();
      expect(key('reminder-panel'), findsNothing);
      // The bar stays above the keyboard.
      expect(
        tester.getRect(key('reminder-save')).bottom,
        lessThan(3040 / 3.5 - 900 / 3.5),
      );

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(key('reminder-panel'), findsOneWidget);
    });

    testWidgets('the moon is offered on a day of its phases', (tester) async {
      await pump(tester, home: RemindersScreen(day: CivilDate(2026, 10, 26)));
      await tap(tester, key('reminder-add'));
      await tap(tester, key('field-repeat'));
      await spinRepeat(tester, 20);
      expect(inTopBar('Every Full Moon'), findsOneWidget);
    });

    testWidgets('a category deleted takes its reminders with it, and says '
        'how many', (tester) async {
      final (store, _) = await pump(tester);
      store.save(draft('Offering').copyWith(categoryId: 'observance'));
      store.save(draft('Fast').copyWith(categoryId: 'observance'));
      store.save(draft('Water').copyWith(categoryId: 'plant'));
      await tester.pumpAndSettle();

      await tap(tester, key('categories'));
      await tap(tester, key('category-observance'));
      await tap(tester, key('category-delete'));
      await tap(tester, key('confirm-delete'));
      // Asked again, with the count.
      expect(find.textContaining('2 reminders'), findsOneWidget);
      expect(store.reminders, hasLength(3));
      await tap(tester, key('confirm-delete'));
      expect(store.reminders.map((r) => r.title), ['Water']);
    });

    testWidgets('speaks Indonesian too', (tester) async {
      await pump(tester, language: AppLanguage.id);
      expect(find.textContaining('PENGINGAT'), findsOneWidget);
      await tap(tester, key('reminder-add'));
      expect(find.text('Pengingat baru'), findsOneWidget);
      await tap(tester, key('field-repeat'));
      await spinRepeat(tester, 4);
      expect(inTopBar('Setiap Minggu Legi'), findsOneWidget);
      await spinRepeat(tester, 4);
      expect(inTopBar('Jawa: setiap 28 Bakdamulud'), findsOneWidget);
      await spinRepeat(tester, 4);
      expect(inTopBar('Imlek: setiap 2 Kau Gwee'), findsOneWidget);
    });

    testWidgets('the calendar\'s dots are reminders, one for each category '
        'with one that day; the journal is not shown there', (tester) async {
      final (store, _) = await pump(
        tester,
        home: MonthScreen(today: today, utcOffset: offset),
      );
      List<List<Color>> dots() => [
        for (final cell
            in tester
                .widget<EntryDots>(
                  find.descendant(
                    of: find.byWidgetPredicate(
                      (w) => w is MonthGrid && w.month == 10,
                    ),
                    matching: find.byType(EntryDots),
                  ),
                )
                .cells)
          cell.colors,
      ];
      // The stand-in journal has entries on every day but Thursdays, and
      // none of them is on the calendar.
      expect(dots().every((d) => d.isEmpty), isTrue);

      store.save(
        draft('Offering', repeat: Repeat.pasaran).copyWith(categoryId: 'dream'),
      );
      store.save(draft('Fast', minute: 6 * 60).copyWith(categoryId: 'plant'));
      store.save(draft('Tea', minute: 7 * 60).copyWith(categoryId: 'plant'));
      await tester.pumpAndSettle();

      // October 2026 starts on a Thursday: the 11th is the fourteenth
      // cell, and every fifth day after it has the pasaran reminder too.
      final cells = dots();
      // Two categories on the 11th, each once, in the order of their
      // colours round the wheel.
      expect(cells[13], [categoryPalette[8], categoryPalette[18]]);
      expect(cells[14], isEmpty);
      expect(cells[18], [categoryPalette[18]]);
      expect(cells[23], [categoryPalette[18]]);
      expect(cells[12], isEmpty);
      // The short reading stays three rows: no reminder is squeezed in.
      expect(find.text('REMINDER'), findsNothing);
      expect(find.textContaining('Fast ·'), findsNothing);
    });

    testWidgets('the year\'s months carry their reminders\' categories', (
      tester,
    ) async {
      final (store, _) = await pump(
        tester,
        home: MonthScreen(
          today: today,
          utcOffset: offset,
          lockedView: MonthScreenView.year,
        ),
      );
      store.save(draft('Fast').copyWith(categoryId: 'plant'));
      store.save(
        draft(
          'Imlek',
          start: CivilDate(2026, 2, 17),
          repeat: Repeat.once,
        ).copyWith(categoryId: 'dream'),
      );
      await tester.pumpAndSettle();
      final year = tester.widget<YearGrid>(
        find.byWidgetPredicate((w) => w is YearGrid && w.year == 2026),
      );
      expect(year.dotsOf!(10), [categoryPalette[8]]);
      expect(year.dotsOf!(2), [categoryPalette[18]]);
      expect(year.dotsOf!(5), isEmpty);
    });

    testWidgets('detailed mode lists a day\'s reminders in a sheet under '
        'the day, three rows at most', (tester) async {
      final (store, _) = await pump(
        tester,
        home: ReadingScreen(date: today, utcOffset: offset, today: today),
      );
      // No reminders: the day sheet has the screen above the bar, under
      // the row of copying and saving at the top right.
      expect(key('reminders-sheet'), findsNothing);
      final alone = tester.getRect(key('day-sheet'));
      final bar = tester.getRect(key('journal-button'));
      final copy = tester.getRect(key('copy-reading'));
      expect(copy.bottom, lessThanOrEqualTo(alone.top));
      expect(alone.top, lessThan(copy.bottom + 20));
      expect(alone.bottom, greaterThan(bar.top - 40));

      final offering = store.save(
        draft('Offering', repeat: Repeat.weton).copyWith(categoryId: 'dream'),
      );
      await tester.pumpAndSettle();
      // One reminder: a sheet one row tall, and the day sheet has the
      // rest.
      const row = ReadingScreen.reminderRowHeight;
      final one = tester.getRect(key('reminders-sheet'));
      expect(one.height, closeTo(row + 16, 2.1));
      expect(tester.getRect(key('day-sheet')).height, greaterThan(500));
      // No title on it, and a bell in the category's colour, not a dot.
      expect(
        find.descendant(
          of: key('reminders-sheet'),
          matching: find.text('Reminders'),
        ),
        findsNothing,
      );
      final bell = tester.widget<GlyphMark>(
        find.descendant(
          of: key('day-reminder-${offering.id}'),
          matching: find.byType(GlyphMark),
        ),
      );
      expect(bell.glyph, Glyph.reminder);
      expect(bell.color, categoryPalette[18]);

      store.save(draft('Fast', minute: 6 * 60));
      await tester.pumpAndSettle();
      final day = tester.getRect(key('day-sheet'));
      final list = tester.getRect(key('reminders-sheet'));
      expect(list.height, closeTo(2 * row + 16, 2.1));
      expect(list.top, greaterThan(day.bottom));
      expect(day.width, list.width);
      // Earliest first, each with its time and how it repeats.
      expect(
        tester.getTopLeft(find.text('Fast')).dy,
        lessThan(tester.getTopLeft(find.text('Offering')).dy),
      );
      expect(
        find.descendant(
          of: key('reminders-sheet'),
          matching: find.text('Every Minggu Legi'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('reminders-sheet'),
          matching: find.text('19:30'),
        ),
        findsOneWidget,
      );
      // Both scroll on their own.
      expect(
        find.descendant(
          of: key('day-sheet'),
          matching: find.byType(Scrollable),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: key('reminders-sheet'),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
      // Three rows at most: with five, the sheet is three tall and the
      // rest are reached by scrolling it.
      for (var i = 0; i < 3; i++) {
        store.save(draft('More $i', minute: 21 * 60 + i));
      }
      await tester.pumpAndSettle();
      expect(
        tester.getRect(key('reminders-sheet')).height,
        closeTo(3 * row + 16, 2.1),
      );
      expect(find.text('More 2').hitTestable(), findsNothing);
      await tester.drag(key('reminders-sheet'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('More 2').hitTestable(), findsOneWidget);
      // A tap opens the reminder.
      await tap(tester, key('day-reminder-${offering.id}'));
      expect(find.byType(ReminderScreen), findsOneWidget);
    });
  });
}
