import 'dart:io';

import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_file.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/journal/samples.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 11);

  late Directory root;
  late JournalStore store;

  JournalStore open() => JournalStore(FileJournalStorage.open(root));

  // The id, and folder, of the category called [name].
  String idOf(String name) =>
      store.categories.firstWhere((c) => c.name == name).id;

  Entry draft({
    String category = 'Occasion',
    String title = 'Evening offering',
    String content = 'Three flowers.\n\nIncense.',
    int minute = 19 * 60 + 30,
    int second = 5,
    CivilDate? date,
  }) => Entry(
    id: '',
    date: date ?? day,
    minuteOfDay: minute,
    second: second,
    utcOffset: offset,
    categoryId: idOf(category),
    title: title,
    content: content,
  );

  File fileAt(String path) => File('${root.path}/journal/entries/$path');

  List<String> files() => [
    for (final file in Directory(
      '${root.path}/journal',
    ).listSync(recursive: true))
      if (file is File) file.path.substring('${root.path}/journal/'.length),
  ]..sort();

  setUp(() {
    root = Directory.systemTemp.createTempSync('journal-test');
    store = open();
  });

  tearDown(() {
    store.dispose();
    root.deleteSync(recursive: true);
  });

  test('a new journal has the starting categories and no entries', () {
    expect(store.categories.map((c) => c.name), [
      'Occasion',
      'Observance',
      'Dream',
      'Divination',
      'Plant log',
    ]);
    // Their ids are six hex digits, nothing to do with their names.
    for (final category in store.categories) {
      expect(category.id, matches(RegExp(r'^[0-9a-f]{6}$')));
    }
    expect(store.categories.map((c) => c.id).toSet(), hasLength(5));
    expect(store.entriesFor(day, utcOffset: offset), isEmpty);
    expect(files(), ['categories.json']);
  });

  test('an entry is one Markdown file under year/month/day/category', () {
    final saved = store.save(draft());

    expect(saved.id, '20261011-193005');
    expect(files(), [
      'categories.json',
      'entries/2026/10/11/${idOf('Occasion')}/193005.md',
    ]);
    expect(
      fileAt('2026/10/11/${idOf('Occasion')}/193005.md').readAsStringSync(),
      '''
---
id: 20261011-193005
date: 2026-10-11
time: 19:30:05
utc_offset: +07:00
category: ${idOf('Occasion')}
category_name: Occasion
title: Evening offering
# The day as every calendar reads it. Written for searching; the app
# works these out from the date and ignores them when reading.
weekday: Sunday
pasaran: Legi
weton: Sunday Legi
neptu: 10
javanese: 28 Bakdamulud 1960 Be
javanese_day: 28
javanese_month: Bakdamulud
javanese_year: 1960
javanese_taun: Be
chinese: 2 Ninth Month 2577 Fire Horse
chinese_day: 2
chinese_month: 9
chinese_leap_month: false
chinese_year: 2577
chinese_zodiac: Horse
chinese_element: Fire
chinese_day_element: Yang Earth
hijri: 28 Rabi' al-Thani 1448
hijri_day: 28
hijri_month: Rabi' al-Thani
hijri_year: 1448
moon_phase: Waxing Crescent
moon_illumination: 0
---
Three flowers.

Incense.
''',
    );
  });

  test('what was written is what is read, after a restart too', () {
    final saved = store.save(
      draft(title: 'A title: with a colon', content: '---\n# not a title\n'),
    );
    store.dispose();
    store = open();

    final read = store.entriesFor(day, utcOffset: offset).single;
    expect(read.id, saved.id);
    expect(read.title, 'A title: with a colon');
    expect(read.content, '---\n# not a title\n');
    expect(read.categoryId, idOf('Occasion'));
    expect(read.minuteOfDay, 19 * 60 + 30);
    expect(read.second, 5);
    expect(read.utcOffset, offset);
    expect(read.date, day);
  });

  test('the calendar lines are ignored when reading', () {
    final text = EntryFile.encode(
      store.save(draft()),
      categoryName: 'Occasion',
    ).replaceFirst('weton: Sunday Legi', 'weton: Monday Kliwon');
    expect(EntryFile.decode(text)!.date, day);
    expect(EntryFile.decode('no fence here'), isNull);
  });

  test('no two entries of a day share a second', () {
    final first = store.save(draft());
    final second = store.save(draft(category: 'Dream', title: 'Other'));
    final third = store.save(draft(title: 'Third'));

    expect(first.id, '20261011-193005');
    expect(second.id, '20261011-193006');
    expect(third.id, '20261011-193007');
    expect(store.entriesFor(day, utcOffset: offset), hasLength(3));
    expect(
      fileAt('2026/10/11/${idOf('Dream')}/193006.md').existsSync(),
      isTrue,
    );
  });

  test('editing rewrites the same file', () {
    final saved = store.save(draft());
    store.save(saved.copyWith(title: 'Changed', content: 'New words.'));

    expect(files(), hasLength(2));
    final read = store.entriesFor(day, utcOffset: offset).single;
    expect(read.title, 'Changed');
    expect(
      fileAt('2026/10/11/${idOf('Occasion')}/193005.md').readAsStringSync(),
      contains('New words.'),
    );
  });

  test('moving to another category moves the file', () {
    final saved = store.save(draft());
    store.save(saved.copyWith(categoryId: idOf('Dream')));

    expect(files(), [
      'categories.json',
      'entries/2026/10/11/${idOf('Dream')}/193005.md',
    ]);
    expect(
      store.entriesFor(day, utcOffset: offset).single.categoryId,
      idOf('Dream'),
    );
    expect(store.entryCount(idOf('Occasion')), 0);
    expect(store.entryCount(idOf('Dream')), 1);
  });

  test('deleting removes the file and the folders it leaves empty', () {
    final saved = store.save(draft());
    final other = store.save(draft(date: CivilDate(2026, 10, 12)));
    store.delete(saved);

    expect(files(), [
      'categories.json',
      'entries/2026/10/12/${idOf('Occasion')}/193005.md',
    ]);
    store.delete(other);
    expect(files(), ['categories.json']);
    expect(Directory('${root.path}/journal/entries').existsSync(), isTrue);
  });

  test('deleting a card deletes that day\'s entries of the category', () {
    store
      ..save(draft())
      ..save(draft(title: 'Second'))
      ..save(draft(category: 'Dream'))
      ..save(draft(date: CivilDate(2026, 10, 12)));
    store.deleteCard(day, idOf('Occasion'), utcOffset: offset);

    expect(files(), [
      'categories.json',
      'entries/2026/10/11/${idOf('Dream')}/193007.md',
      'entries/2026/10/12/${idOf('Occasion')}/193005.md',
    ]);
  });

  test('deleting a category deletes its entries on every day', () {
    store
      ..save(draft())
      ..save(draft(category: 'Dream'))
      ..save(draft(date: CivilDate(2027, 1, 1)));
    expect(store.entryCount(idOf('Occasion')), 2);
    final occasion = idOf('Occasion');
    store.deleteCategory(occasion);

    expect(files(), [
      'categories.json',
      'entries/2026/10/11/${idOf('Dream')}/193006.md',
    ]);
    store.dispose();
    store = open();
    expect(store.category(occasion), isNull);
    expect(store.categories, hasLength(4));
  });

  test('categories are kept in order, with their colours', () {
    final occasion = idOf('Occasion');
    final made = store.addCategory('Night Walks!', colorIndex: 5)!;
    store.recolorCategory(occasion, 20);
    // The id owes nothing to the name, so two of one name are no trouble.
    expect(made.id, matches(RegExp(r'^[0-9a-f]{6}$')));
    final twin = store.addCategory('Night Walks!')!;
    expect(twin.id, isNot(made.id));
    store.dispose();
    store = open();

    expect(store.categories.map((c) => c.id).toList().sublist(5), [
      made.id,
      twin.id,
    ]);
    expect(store.category(made.id)!.name, 'Night Walks!');
    expect(store.category(made.id)!.colorIndex, 5);
    expect(store.category(occasion)!.colorIndex, 20);
  });

  test('renaming a category keeps its folder and rewrites its name in '
      'every entry', () {
    store.save(draft());
    final occasion = idOf('Occasion');
    store.renameCategory(occasion, 'Feast days');

    final text = fileAt('2026/10/11/$occasion/193005.md').readAsStringSync();
    expect(text, contains('category: $occasion\n'));
    expect(text, contains('category_name: Feast days\n'));
    // Nothing moved: only the name inside changed.
    expect(files(), hasLength(2));
    expect(store.entriesFor(day, utcOffset: offset), hasLength(1));
  });

  group('entry dots', () {
    List<String> names(Iterable<JournalCategory> categories) => [
      for (final category in categories) category.name,
    ];

    test('a day\'s are its categories, earliest entry first', () {
      store
        ..save(draft(category: 'Dream', minute: 21 * 60))
        ..save(draft(category: 'Occasion', minute: 6 * 60))
        ..save(draft(category: 'Plant log', minute: 12 * 60))
        // A second, later entry does not move its category forward.
        ..save(draft(category: 'Occasion', minute: 23 * 60));

      expect(names(store.marksOn(day, utcOffset: offset)), [
        'Occasion',
        'Plant log',
        'Dream',
      ]);
      expect(store.marksOn(day.addDays(1), utcOffset: offset), isEmpty);
    });

    test(
      'a month\'s are its categories, by their first entry of the month',
      () {
        store
          ..save(draft(category: 'Dream', date: CivilDate(2026, 10, 20)))
          ..save(draft(category: 'Plant log', date: CivilDate(2026, 10, 3)))
          ..save(
            draft(category: 'Dream', date: CivilDate(2026, 10, 3), minute: 5),
          )
          ..save(draft(category: 'Divination', date: CivilDate(2026, 10, 31)))
          // Other months do not count.
          ..save(draft(category: 'Observance', date: CivilDate(2026, 11, 1)))
          ..save(draft(category: 'Occasion', date: CivilDate(2026, 9, 30)));

        expect(names(store.marksIn(2026, 10, utcOffset: offset)), [
          'Dream',
          'Plant log',
          'Divination',
        ]);
        expect(names(store.marksIn(2026, 11, utcOffset: offset)), [
          'Observance',
        ]);
        expect(store.marksIn(2026, 12, utcOffset: offset), isEmpty);
      },
    );

    test('follow every change to the journal', () {
      final before = store.revision;
      final saved = store.save(draft());
      expect(store.revision, greaterThan(before));
      expect(names(store.marksOn(day, utcOffset: offset)), ['Occasion']);

      store.save(saved.copyWith(categoryId: idOf('Dream')));
      expect(names(store.marksOn(day, utcOffset: offset)), ['Dream']);

      store.deleteCategory(idOf('Dream'));
      expect(store.marksOn(day, utcOffset: offset), isEmpty);
      expect(store.marksIn(2026, 10, utcOffset: offset), isEmpty);
    });
  });

  test('samples can be written and taken out again, leaving the rest', () {
    final mine = store.save(draft(title: 'Mine'));
    // An ordinary build does neither.
    expect(Samples.mode, isEmpty);
    Samples.apply(store, root, offset);
    expect(File('${root.path}/samples.json').existsSync(), isFalse);

    Samples.seed(store, root, offset);
    expect(store.categories, hasLength(14));
    int marks(int d) =>
        store.marksOn(CivilDate(2026, 10, d), utcOffset: offset).length;
    expect([for (var d = 1; d <= 6; d++) marks(d)], [1, 2, 3, 4, 5, 6]);
    expect(marks(7), 1);
    expect(
      store.entriesFor(CivilDate(2026, 10, 7), utcOffset: offset),
      hasLength(14),
    );
    expect(marks(8), 13);
    // The latest-written categories lead on the sixth.
    expect(
      store.marksOn(CivilDate(2026, 10, 6), utcOffset: offset).first.id,
      store.categories[5].id,
    );
    int inMonth(int m) => store.marksIn(2026, m, utcOffset: offset).length;
    expect(
      [for (var m = 1; m <= 8; m++) inMonth(m)],
      [1, 0, 2, 4, 8, 9, 14, 0],
    );
    // Two entries asked for one second; both are there.
    expect(
      store
          .entriesFor(CivilDate(2026, 10, 10), utcOffset: offset)
          .map((e) => e.secondOfDay),
      containsAll([0, 43200, 43201, 86399]),
    );

    Samples.remove(store, root, offset);
    expect(store.categories, hasLength(5));
    expect(inMonth(7), 0);
    expect(store.entriesFor(day, utcOffset: offset).single.id, mine.id);
    expect(files(), hasLength(2));
    expect(File('${root.path}/samples.json').existsSync(), isFalse);
  });

  group('the index', () {
    test('is rebuilt from the files when it is missing', () {
      store
        ..save(draft())
        ..save(draft(category: 'Dream'));
      store.dispose();
      File('${root.path}/index.db').deleteSync();
      store = open();

      expect(store.entriesFor(day, utcOffset: offset), hasLength(2));
      expect(store.entryCount(idOf('Dream')), 1);
    });

    test('is rebuilt when a change was cut short', () {
      final saved = store.save(draft());
      store.dispose();
      // As if the app died between writing a file and indexing it.
      final lost = saved.at(saved.secondOfDay + 60).copyWith(title: 'Lost');
      fileAt(EntryFile.pathOf(lost))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(EntryFile.encode(lost, categoryName: 'Occasion'));
      File('${root.path}/index.dirty').writeAsStringSync('');
      store = open();

      expect(
        store.entriesFor(day, utcOffset: offset).map((e) => e.title),
        unorderedEquals(['Evening offering', 'Lost']),
      );
      expect(File('${root.path}/index.dirty').existsSync(), isFalse);
    });

    test('takes a file dropped into a folder as that category\'s', () {
      final saved = store.save(draft());
      store.dispose();
      final from = fileAt('2026/10/11/${idOf('Occasion')}/193005.md');
      final to = fileAt('2026/10/11/${idOf('Dream')}/193005.md')
        ..parent.createSync(recursive: true);
      from.renameSync(to.path);
      File('${root.path}/index.db').deleteSync();
      store = open();

      final read = store.entriesFor(day, utcOffset: offset).single;
      expect(read.id, saved.id);
      expect(read.categoryId, idOf('Dream'));
    });

    test('handles a large journal', () {
      final storage = FileJournalStorage.open(
        Directory('${root.path}/big')..createSync(),
      );
      final big = JournalStore(storage);
      final watch = Stopwatch()..start();
      for (var i = 0; i < 2000; i++) {
        big.save(
          draft(
            date: CivilDate.fromDayNumber(day.dayNumber + i ~/ 4),
            second: i % 60,
          ).copyWith(categoryId: big.categories[i % 4].id),
        );
      }
      final written = watch.elapsedMilliseconds;
      watch.reset();
      storage.rebuildIndex();
      final rebuilt = watch.elapsedMilliseconds;
      watch.reset();
      for (var i = 0; i < 500; i++) {
        big.entriesFor(
          CivilDate.fromDayNumber(day.dayNumber + i),
          utcOffset: offset,
        );
      }
      // ignore: avoid_print
      print(
        '2000 entries: written in $written ms, index rebuilt in $rebuilt ms, '
        '500 days read in ${watch.elapsedMilliseconds} ms',
      );
      expect(big.entryCount(big.categories.first.id), 500);
      big.dispose();
    });
  });
}
