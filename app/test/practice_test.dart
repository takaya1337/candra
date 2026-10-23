import 'package:candra/action_cards.dart';
import 'package:candra/app_shell.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_file.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/phone_surfaces.dart';
import 'package:candra/practice/practice.dart';
import 'package:candra/practice/practice_screen.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));
  var clock = DateTime(2026, 10, 11, 5, 0);

  setUp(() {
    clock = DateTime(2026, 10, 11, 5, 0);
    PracticeTimer.now = () => clock;
    PracticeTimer.running.value = null;
    PracticeTally.reset();
    SkyPlace.current.value = null;
  });
  tearDown(() {
    PracticeTimer.now = DateTime.now;
    PracticeTimer.running.value = null;
    PracticeTally.reset();
    SkyPlace.current.value = null;
  });

  group('an entry\'s duration', () {
    final entry = Entry(
      id: '',
      date: CivilDate(2026, 10, 11),
      minuteOfDay: 5 * 60,
      utcOffset: const Duration(hours: 7),
      categoryId: 'observance',
      title: 'Morning sitting',
      content: 'Quiet.',
      duration: const Duration(hours: 1, minutes: 5, seconds: 9),
    );

    test('is written into the file in plain words and read back', () {
      final text = EntryFile.encode(entry, categoryName: 'Observance');
      expect(text, contains('\nduration: 01:05:09\n'));
      expect(EntryFile.decode(text)!.duration, entry.duration);
      // An entry that was not timed has no such line.
      final plain = EntryFile.encode(
        entry.at(5 * 3600).copyWith(title: 'x'),
        categoryName: 'Observance',
      );
      expect(plain, contains('duration'));
      final untimed = Entry(
        id: '',
        date: entry.date,
        minuteOfDay: 300,
        utcOffset: entry.utcOffset,
        categoryId: 'observance',
        title: 'x',
        content: '',
      );
      expect(
        EntryFile.encode(untimed, categoryName: 'Observance'),
        isNot(contains('duration')),
      );
      expect(
        EntryFile.decode(EntryFile.encode(untimed, categoryName: 'Observance'))!
            .duration,
        isNull,
      );
    });

    test('is said in the app\'s words', () {
      const en = Strings(AppLanguage.en);
      expect(en.practiceLength(const Duration(seconds: 45)), '45 s');
      expect(en.practiceLength(const Duration(minutes: 25)), '25 min');
      expect(
        en.practiceLength(const Duration(hours: 1, minutes: 5)),
        '1 h 05 min',
      );
      expect(
        const Strings(AppLanguage.id)
            .practiceLength(const Duration(minutes: 25)),
        '25 mnt',
      );
    });
  });

  group('the practice timer', () {
    Future<void> pump(WidgetTester tester) async {
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
    }

    JournalStore journalOf(WidgetTester tester) =>
        tester.widget<JournalScope>(find.byType(JournalScope)).notifier!;

    String? chosenWay(WidgetTester tester) =>
        tester.widget<ActionCards>(find.byType(ActionCards)).chosen;

    double opacityOf(WidgetTester tester, String name) => tester
        .widget<Opacity>(
          find.ancestor(of: key(name), matching: find.byType(Opacity)).first,
        )
        .opacity;

    testWidgets('is started from the calendar\'s bar, counts, and when '
        'stopped asks, then is written into the journal with its length, '
        'opened here, and back comes to the practice', (tester) async {
      await pump(tester);
      expect(tester.widget<GlyphButton>(key('practice-button')).lit, isFalse);
      await tester.tap(key('practice-button'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(chosenWay(tester), 'practice-stopwatch');
      expect(tester.widget<Text>(key('practice-clock')).data, '00:00:00');
      expect(
        tester.widget<Text>(key('practice-hint')).data,
        'The stopwatch is chosen. Press start to begin counting.',
      );

      // The way's line stands at the top of the body.
      expect(
        tester.getRect(key('practice-hint')).top,
        lessThan(tester.getRect(key('practice-clock')).top),
      );
      // Started with no category: it is asked as it is written.
      final journal = journalOf(tester);
      final kind = journal.categories[1];
      await tester.tap(key('practice-start'));
      await tester.pump();
      expect(key('practice-stop'), findsOneWidget);

      clock = clock.add(const Duration(minutes: 25, seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Text>(key('practice-clock')).data, '00:25:10');
      expect(find.textContaining('Since 05:00'), findsOneWidget);

      // Stopped, it stands as it is and the panel asks.
      await tester.tap(key('practice-stop'));
      await tester.pumpAndSettle();
      expect(key('practice-ask'), findsOneWidget);
      expect(PracticeTimer.running.value!.finished(clock), isTrue);
      clock = clock.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Text>(key('practice-clock')).data, '00:25:10');

      // Written: first the category, down the panel; back from it is the
      // question again.
      await tester.tap(key('practice-write'));
      await tester.pumpAndSettle();
      expect(find.text('Under which category?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('practice-ask'), findsOneWidget);
      await tester.tap(key('practice-write'));
      await tester.pumpAndSettle();
      final rows = [
        for (final each in journal.categories.take(2))
          tester.getRect(key('practice-under-${each.id}')),
      ];
      expect(rows[1].top, greaterThan(rows[0].bottom));
      expect(rows[1].left, rows[0].left);
      // The entry it has become, to be read, opened here in the
      // practice's room, under the category chosen: its start, its end,
      // and a line left open.
      await tester.tap(key('practice-under-${kind.id}'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryScreen), findsOneWidget);
      expect(PracticeTimer.running.value, isNull);
      final entry = journal
          .entriesFor(
            CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          )
          .firstWhere((e) => e.duration != null);
      expect(entry.content, 'Start: 05:00:00\n\nEnd: 05:25:10\n\nLog: ');
      expect(entry.title, 'Practice');
      expect(entry.categoryId, kind.id);
      expect(find.textContaining('05:00 · 25 min'), findsOneWidget);
      expect(tester.widget<GlyphButton>(key('practice-button')).here, isTrue);
      // Editing puts the cursor after "Log: ".
      await tester.tap(key('entry-edit'));
      await tester.pumpAndSettle();
      final field = tester.widget<EditableText>(
        find.descendant(
          of: key('entry-content'),
          matching: find.byType(EditableText),
        ),
      );
      expect(
        field.controller.selection.baseOffset,
        field.controller.text.length,
      );
      expect(field.controller.text, endsWith('Log: '));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      // Back stops editing; back again comes to the practice, as the
      // bazi's chart does.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('entry-edit'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EntryScreen), findsNothing);
      expect(key('practice-start'), findsOneWidget);
    });

    testWidgets('timed down, shows what is left and, run out, asks', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(key('practice-button'));
      await tester.pumpAndSettle();
      await tester.tap(key('practice-countdown'));
      await tester.pumpAndSettle();
      expect(chosenWay(tester), 'practice-countdown');
      // The wheels at the body's centre, and the timer's own line.
      expect(key('practice-length'), findsOneWidget);
      expect(
        tester.widget<Text>(key('practice-hint')).data,
        contains('The timer is chosen.'),
      );
      await tester.tap(key('practice-start'));
      await tester.pumpAndSettle();
      expect(PracticeTimer.running.value!.length, const Duration(minutes: 20));
      // While it runs the other ways are faint and deaf; the wheels gone.
      expect(chosenWay(tester), 'practice-countdown');
      expect(opacityOf(tester, 'practice-stopwatch'), 0.3);
      expect(opacityOf(tester, 'practice-tally'), 0.3);
      expect(key('practice-length'), findsNothing);
      expect(tester.widget<Text>(key('practice-clock')).data, '00:20:00');

      clock = clock.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Text>(key('practice-clock')).data, '00:15:00');
      expect(find.textContaining('until 05:20'), findsOneWidget);

      // Looked at late: it ran out when it ran out, and asks.
      clock = clock.add(const Duration(minutes: 40));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(key('practice-ask'), findsOneWidget);
      expect(tester.widget<Text>(key('practice-clock')).data, '00:00:00');
      await tester.tap(key('practice-write'));
      await tester.pumpAndSettle();
      await tester.tap(
        key('practice-under-${journalOf(tester).categories.first.id}'),
      );
      await tester.pumpAndSettle();
      expect(PracticeTimer.running.value, isNull);
      expect(find.byType(EntryScreen), findsOneWidget);
      expect(find.textContaining('05:00 · 20 min'), findsOneWidget);
    });

    testWidgets('left running, lights its button and can be come back to; '
        'stopped and discarded, writes nothing', (tester) async {
      await pump(tester);
      final journal = journalOf(tester);
      int written() => journal
          .entriesFor(
            CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          )
          .length;
      final before = written();
      PracticeTimer.start(journal.categories.first.id);
      await tester.pump();
      expect(tester.widget<GlyphButton>(key('practice-button')).lit, isTrue);
      await tester.tap(key('practice-button'));
      await tester.pumpAndSettle();
      expect(key('practice-stop'), findsOneWidget);

      await tester.tap(key('practice-stop'));
      await tester.pumpAndSettle();
      await tester.tap(key('practice-discard'));
      await tester.pumpAndSettle();
      expect(PracticeTimer.running.value, isNull);
      // Nothing written, and the practice stays, ready to start again.
      expect(written(), before);
      expect(find.byType(EntryScreen), findsNothing);
      expect(key('practice-start'), findsOneWidget);
      expect(key('practice-ask'), findsNothing);
    });

    testWidgets('the tally: chosen, its count at the centre; a touch is one '
        'more, the reset sets it back to nothing', (tester) async {
      await pump(tester);
      await tester.tap(key('practice-button'));
      await tester.pumpAndSettle();
      expect(key('practice-tally-add'), findsNothing);
      await tester.tap(key('practice-tally'));
      await tester.pumpAndSettle();
      expect(chosenWay(tester), 'practice-tally');
      String shown() => tester.widget<Text>(key('practice-count')).data!;
      expect(shown(), '0');
      expect(
        tester.widget<Text>(key('practice-hint')).data,
        contains('The tally is chosen.'),
      );
      // The tally at the bottom right, the reset across from it at the
      // bottom left, writing at the centre.
      final add = tester.getRect(key('practice-tally-add'));
      final reset = tester.getRect(key('practice-tally-reset'));
      final write = tester.getRect(key('practice-tally-write'));
      expect(add.center.dy, moreOrLessEquals(reset.center.dy));
      expect(reset.right, lessThan(write.left));
      expect(write.right, lessThan(add.left));
      for (var i = 0; i < 3; i++) {
        await tester.tap(key('practice-tally-add'));
        await tester.pump();
      }
      expect(PracticeTally.count.value, 3);
      expect(shown(), '3');
      await tester.tap(key('practice-tally-reset'));
      await tester.pump();
      expect(PracticeTally.count.value, 0);
      expect(shown(), '0');
    });

    testWidgets('the tally written asks first, then becomes an entry of the '
        'moment and the count, and starts again; discarded, nothing is '
        'written', (tester) async {
      await pump(tester);
      await tester.tap(key('practice-button'));
      await tester.pumpAndSettle();
      await tester.tap(key('practice-tally'));
      await tester.pumpAndSettle();
      final journal = journalOf(tester);
      int written() => journal
          .entriesFor(
            CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          )
          .length;
      final before = written();

      for (var i = 0; i < 2; i++) {
        await tester.tap(key('practice-tally-add'));
        await tester.pump();
      }
      await tester.tap(key('practice-tally-write'));
      await tester.pumpAndSettle();
      expect(key('practice-ask'), findsOneWidget);
      await tester.tap(key('practice-discard'));
      await tester.pumpAndSettle();
      expect(PracticeTally.count.value, 0);
      expect(written(), before);

      for (var i = 0; i < 4; i++) {
        await tester.tap(key('practice-tally-add'));
        await tester.pump();
      }
      await tester.tap(key('practice-tally-write'));
      await tester.pumpAndSettle();
      await tester.tap(key('practice-write'));
      await tester.pumpAndSettle();
      await tester.tap(key('practice-under-${journal.categories.first.id}'));
      await tester.pumpAndSettle();
      expect(written(), before + 1);
      final entry = journal
          .entriesFor(
            CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          )
          .firstWhere((e) => e.title == 'Tally');
      expect(entry.content, 'Time: 05:00:00\n\nCounted: 4\n\nLog: ');
      expect(PracticeTally.count.value, 0);
      expect(find.byType(EntryScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('practice-count'), findsOneWidget);
    });

    test('stopped, dates the entry when it began and gives its length', () {
      final journal = JournalStore();
      final kind = journal.categories.first;
      final before = journal
          .entriesFor(
            CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          )
          .length;
      PracticeTimer.start(kind.id);
      clock = clock.add(const Duration(hours: 1, minutes: 2, seconds: 3));
      final entry = PracticeTimer.stop(journal, const Strings(AppLanguage.en))!;
      expect(entry.date, CivilDate(2026, 10, 11));
      expect(entry.time, '05:00');
      expect(entry.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(entry.categoryId, kind.id);
      expect(
        journal
            .entriesFor(
              CivilDate(2026, 10, 11),
              utcOffset: const Duration(hours: 7),
            )
            .length,
        before + 1,
      );
    });
  });

  group('the island', () {
    const strings = Strings(AppLanguage.en);
    PhoneSurfaces surfaces(JournalStore journal, ReminderStore reminders) =>
        PhoneSurfaces(
          journal: journal,
          reminders: reminders,
          language: LanguageController(),
        );

    test('is for a practice under way and nothing else', () {
      final journal = JournalStore();
      final reminders = ReminderStore(utcOffset: const Duration(hours: 7));
      final island = surfaces(journal, reminders);
      SkyPlace.current.value = (latitude: -7.6, longitude: 110.2);
      reminders.save(
        Reminder(
          id: '',
          title: 'Evening offering',
          start: CivilDate(2026, 10, 11),
          minuteOfDay: 6 * 60,
          repeat: Repeat.once,
          categoryId: journal.categories.first.id,
        ),
      );
      // A reminder an hour off and a sky to read: still nothing.
      expect(island.island(strings), isNull);

      PracticeTimer.start(journal.categories[1].id);
      final stopwatch = island.island(strings)!;
      expect(stopwatch['title'], journal.categories[1].name);
      expect(stopwatch['start'], clock.toUtc().millisecondsSinceEpoch);
      expect(stopwatch['end'], isNull);
      expect(stopwatch['color'], journal.categories[1].color.toARGB32());

      PracticeTimer.discard();
      PracticeTimer.start(
        journal.categories.first.id,
        length: const Duration(minutes: 30),
      );
      expect(
        island.island(strings)!['end'],
        clock.add(const Duration(minutes: 30)).toUtc().millisecondsSinceEpoch,
      );
    });

    test('the widgets are told the coming days as every calendar reads '
        'them', () {
      final days = surfaces(
        JournalStore(),
        ReminderStore(utcOffset: const Duration(hours: 7)),
      ).days(clock, strings);
      expect(days, hasLength(PhoneSurfaces.daysAhead));
      expect(days.first['date'], '2026-10-11');
      expect(days.first['weekday'], 'Sunday');
      expect(days.first['sunday'], isTrue);
      expect(days.first['weton'], 'Minggu Legi');
      expect(days.first['chineseHanzi'], '丙午年九月初二');
      expect(days.first['chineseDay'], '2 Kau Gwee');
      // 11 October 2026 is a 戊 day: yang earth.
      expect(days.first['element'], 'Yang Earth');
      expect(days.first['hijriDay'], "28 Rabi' al-Thani");
      expect(days.first['hijriYear'], '1448 AH');
      expect(days.first['dots'], isEmpty);
      expect(days[1]['date'], '2026-10-12');
    });
  });
}
