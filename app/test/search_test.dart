import 'dart:io';

import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_file.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/moment_stamp.dart';
import 'package:candra/search/query.dart';
import 'package:candra/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// Tags as the journal keeps them, and the search over entries and
/// reminders: categories any of, tags all of, cycles all of (two of one
/// cycle either), and the evening counted as the next day.
void main() {
  const offset = Duration(hours: 7);
  final roots = <Directory>[];
  final stores = <JournalStore>[];

  JournalStore journal() {
    final root = Directory.systemTemp.createTempSync('search-test');
    roots.add(root);
    final store = JournalStore(FileJournalStorage.open(root));
    stores.add(store);
    return store;
  }

  tearDown(() {
    for (final store in stores) {
      store.dispose();
    }
    for (final root in roots) {
      root.deleteSync(recursive: true);
    }
    stores.clear();
    roots.clear();
  });

  String idOf(JournalStore store, String name) =>
      store.categories.firstWhere((c) => c.name == name).id;

  Entry write(
    JournalStore store,
    CivilDate date,
    String title, {
    String category = 'Dream',
    int minute = 600,
    List<String> tags = const [],
  }) => store.save(
    Entry(
      id: '',
      date: date,
      minuteOfDay: minute,
      utcOffset: offset,
      categoryId: idOf(store, category),
      title: title,
      content: 'Words.',
      tags: tags,
    ),
  );

  group('tags', () {
    test('an entry\'s tags are in its file, with their names beside them, '
        'and come back from it', () {
      final entry = Entry(
        id: '20261015-100000',
        date: CivilDate(2026, 10, 15),
        minuteOfDay: 600,
        utcOffset: offset,
        categoryId: 'abc123',
        title: 'Garden',
        content: 'Watered.',
        tags: const ['aaaaaa', 'bbbbbb'],
      );
      final text = EntryFile.encode(
        entry,
        categoryName: 'Plant log',
        tagNames: const ['chilli', 'morning'],
      );
      expect(text, contains('tags: aaaaaa, bbbbbb'));
      expect(text, contains('tag_names: chilli · morning'));
      expect(EntryFile.decode(text)!.tags, ['aaaaaa', 'bbbbbb']);
      expect(EntryFile.decode(text)!.sameAs(entry), isTrue);
    });

    test('a tag is made once per name, kept, and deleting it takes it off '
        'every entry', () {
      final store = journal();
      final chilli = store.addTag('Chilli')!;
      expect(store.addTag('  chilli ')!.id, chilli.id);
      expect(store.addTag('   '), isNull);
      final day = CivilDate(2026, 10, 15);
      write(store, day, 'One', tags: [chilli.id]);
      write(store, day, 'Two', minute: 700, tags: [chilli.id]);
      expect(store.countTagged(chilli.id), 2);

      // Kept on disk: a store opened afresh has it.
      final again = JournalStore(FileJournalStorage.open(roots.last));
      stores.add(again);
      expect(again.tags.single.name, 'Chilli');
      again.dispose();
      stores.remove(again);

      store.deleteTag(chilli.id);
      expect(store.tags, isEmpty);
      expect(store.countTagged(chilli.id), 0);
      for (final entry in store.entriesFor(day, utcOffset: offset)) {
        expect(entry.tags, isEmpty);
      }
    });

    test('a reminder\'s tags are kept, and taken off when the tag goes', () {
      final reminder = Reminder(
        id: 'r1',
        title: 'Kliwon offering',
        start: CivilDate(2026, 10, 15),
        minuteOfDay: 1140,
        repeat: Repeat.pasaran,
        tags: const ['aaaaaa'],
      );
      expect(Reminder.fromJson(reminder.toJson())!.tags, ['aaaaaa']);
      final store = ReminderStore(utcOffset: offset)..save(reminder);
      expect(store.countTagged('aaaaaa'), 1);
      store.untag('aaaaaa');
      expect(store.reminder('r1')!.tags, isEmpty);
    });
  });

  group('the search', () {
    // 15 October 2026 is a Kamis Kliwon.
    final kliwon = CivilDate(2026, 10, 15);

    test('a cycle finds only the days that have it', () {
      expect(Weton.of(kliwon).pasaran, Pasaran.kliwon);
      final store = journal();
      write(store, kliwon, 'On Kliwon');
      write(store, kliwon.addDays(1), 'On Legi');
      write(store, kliwon.addDays(5), 'Kliwon again');

      final query = const SearchQuery().toggleCycle(
        CycleKind.pasaran,
        Pasaran.kliwon.index,
      );
      expect(
        [for (final hit in query.searchEntries(store)) hit.entry!.title],
        // Newest first.
        ['Kliwon again', 'On Kliwon'],
      );
      // Two of one cycle: either.
      final either = query.toggleCycle(CycleKind.pasaran, Pasaran.legi.index);
      expect(either.searchEntries(store), hasLength(3));
      // Two cycles: both. Kamis Kliwon is one day in 35.
      final both = query.toggleCycle(CycleKind.weekday, Weekday.kamis.index);
      expect(
        [for (final hit in both.searchEntries(store)) hit.entry!.title],
        ['On Kliwon'],
      );
    });

    test(
      'categories are any of, tags all of: category A with tags C and D',
      () {
        final store = journal();
        final c = store.addTag('C')!.id;
        final d = store.addTag('D')!.id;
        write(store, kliwon, 'A, C and D', category: 'Occasion', tags: [c, d]);
        write(
          store,
          kliwon,
          'A, C only',
          category: 'Occasion',
          minute: 610,
          tags: [c],
        );
        write(
          store,
          kliwon,
          'B, C and D',
          category: 'Dream',
          minute: 620,
          tags: [c, d],
        );

        final query = SearchQuery(
          categories: {idOf(store, 'Occasion')},
          tags: {c, d},
        );
        expect(
          [for (final hit in query.searchEntries(store)) hit.entry!.title],
          ['A, C and D'],
        );
        final anyCategory = SearchQuery(tags: {c, d});
        expect(anyCategory.searchEntries(store), hasLength(2));
        final two = SearchQuery(
          categories: {idOf(store, 'Occasion'), idOf(store, 'Dream')},
          tags: {c},
        );
        expect(two.searchEntries(store), hasLength(3));
      },
    );

    test('the evening counts as the next day when asked: Wednesday night '
        'is malam Kamis', () {
      final store = journal();
      final wednesday = kliwon.addDays(-1);
      write(store, wednesday, 'Wednesday evening', minute: 20 * 60);
      write(store, wednesday, 'Wednesday morning', minute: 8 * 60);

      final kamis = const SearchQuery().toggleCycle(
        CycleKind.weekday,
        Weekday.kamis.index,
      );
      // At midnight, neither is Thursday.
      expect(kamis.searchEntries(store), isEmpty);
      // From six in the evening, the evening one is.
      final six = kamis.copyWith(evening: Evening.six);
      final found = six.searchEntries(store);
      expect(
        [for (final hit in found) hit.entry!.title],
        ['Wednesday evening'],
      );
      expect(found.single.date, wednesday);
      expect(found.single.day, kliwon);
      // By the sun: a sunset given for the day.
      final sunset = kamis.copyWith(evening: Evening.sunset);
      expect(
        sunset.searchEntries(store, sunset: (_) => 17 * 60 + 50),
        hasLength(1),
      );
      expect(sunset.searchEntries(store, sunset: (_) => 20 * 60 + 30), isEmpty);
    });

    test('words are all required, in the title or the text', () {
      final store = journal();
      write(store, kliwon, 'Chilli seedlings');
      expect(
        const SearchQuery(words: 'chilli WORDS').searchEntries(store),
        hasLength(1),
      );
      expect(
        const SearchQuery(words: 'chilli tomato').searchEntries(store),
        isEmpty,
      );
    });

    test('a reminder is found at the first of its coming days that fits', () {
      final reminders = ReminderStore(utcOffset: offset)
        ..save(
          Reminder(
            id: 'daily',
            title: 'Every day',
            start: kliwon,
            minuteOfDay: 600,
            repeat: Repeat.daily,
          ),
        );
      final query = const SearchQuery(
        entries: false,
        reminders: true,
      ).toggleCycle(CycleKind.pasaran, Pasaran.legi.index);
      final hit = query.searchReminders(reminders, from: kliwon).single;
      expect(hit.date, kliwon.addDays(1));
      expect(Weton.of(hit.date).pasaran, Pasaran.legi);
      // Switched off, it is not found.
      reminders.save(
        Reminder(
          id: 'off',
          title: 'Off',
          start: kliwon,
          minuteOfDay: 600,
          repeat: Repeat.daily,
          enabled: false,
        ),
      );
      expect(query.searchReminders(reminders, from: kliwon), hasLength(1));
    });

    test('every cycle reads a day and names its values', () {
      final strings = Strings(AppLanguage.en);
      for (final kind in CycleKind.values) {
        // An hour's cycle is read off a moment, not a day.
        if (kind.ofTheHour) {
          expect(kind.valueOf(kliwon, utcOffset: offset), isNull);
          for (var v = 0; v < kind.count; v++) {
            expect(kind.label(v, strings), isNotEmpty);
          }
          continue;
        }
        final value = kind.valueOf(kliwon, utcOffset: offset);
        expect(value, isNotNull, reason: '$kind');
        expect(value, inInclusiveRange(0, kind.count - 1), reason: '$kind');
        for (var v = 0; v < kind.count; v++) {
          expect(kind.label(v, strings), isNotEmpty, reason: '$kind $v');
        }
      }
      expect(
        CycleKind.weton.label(
          CycleKind.weton.valueOf(kliwon, utcOffset: offset)!,
          strings,
        ),
        'Kamis Kliwon',
      );
    });
  });

  test('the planetary hour narrows entries by their moment, at the place, '
      'and never the days', () {
    final store = journal();
    // Sunday 18 October 2026 at Jakarta: sunrise near 05:31, so 08:00 is
    // in the third day hour, Mercury's; 06:10, the first, the sun's.
    final sunday = CivilDate(2026, 10, 18);
    write(store, sunday, 'Mercury', minute: 8 * 60);
    write(store, sunday, 'Sun', minute: 6 * 60 + 10);
    const jakarta = (latitude: -6.2, longitude: 106.8);
    final mercury = CycleKind.planets.indexOf(Body.mercury);
    final query = const SearchQuery().toggleCycle(
      CycleKind.planetaryHour,
      mercury,
    );
    expect(
      query.searchEntries(store, place: jakarta).map((h) => h.entry!.title),
      ['Mercury'],
    );
    // With no place there are no hours to read.
    expect(query.searchEntries(store), isEmpty);
    // Every day has every hour: the days are not narrowed.
    expect(query.dayMatches(sunday, utcOffset: offset), isTrue);
    expect(
      CycleKind.planetaryHour.label(mercury, Strings(AppLanguage.id)),
      'Merkurius',
    );
  });

  test('by when it was written: the cycles of its moment record, not of '
      'the day it is about', () {
    final store = journal();
    // Written on Sunday 18 October 2026 at 08:00 WIB, geotagged at
    // Jakarta, about Friday the 16th.
    final moment = MomentStamp.of(
      DateTime.utc(2026, 10, 18, 1),
      utcOffset: offset,
      geotag: (latitude: -6.2, longitude: 106.8),
    );
    store.save(
      Entry(
        id: '',
        date: CivilDate(2026, 10, 16),
        minuteOfDay: 600,
        utcOffset: offset,
        categoryId: idOf(store, 'Dream'),
        title: 'About Friday',
        content: 'Words.',
        moment: moment,
      ),
    );
    // One from before records: never found by the moment.
    write(store, CivilDate(2026, 10, 18), 'Old Sunday');
    final sunday = Weekday.minggu.index;
    final friday = Weekday.jumat.index;
    var query = const SearchQuery().toggleCycle(CycleKind.weekday, sunday);
    List<String> titles(SearchQuery q) => [
      for (final h in q.searchEntries(store)) h.entry!.title,
    ];
    expect(titles(query), ['Old Sunday']);
    query = query.copyWith(byMoment: true);
    expect(titles(query), ['About Friday']);
    expect(
      titles(
        const SearchQuery(byMoment: true)
            .toggleCycle(CycleKind.weekday, friday),
      ),
      isEmpty,
    );
    // Its recorded planetary hour: Mercury's.
    expect(
      titles(
        const SearchQuery(byMoment: true).toggleCycle(
          CycleKind.planetaryHour,
          CycleKind.planets.indexOf(Body.mercury),
        ),
      ),
      ['About Friday'],
    );
  });
}
