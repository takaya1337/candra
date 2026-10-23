import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/geo.dart';
import 'package:candra/journal/journal_archive.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 11);
  final roots = <Directory>[];
  final stores = <JournalStore>[];

  JournalStore journal() {
    final root = Directory.systemTemp.createTempSync('archive-test');
    roots.add(root);
    final store = JournalStore(FileJournalStorage.open(root));
    stores.add(store);
    return store;
  }

  String idOf(JournalStore store, String name) =>
      store.categories.firstWhere((c) => c.name == name).id;

  Entry write(
    JournalStore store,
    String category,
    String title, {
    int minute = 600,
    CivilDate? date,
    String content = 'Words.',
  }) => store.save(
    Entry(
      id: '',
      date: date ?? day,
      minuteOfDay: minute,
      utcOffset: offset,
      categoryId: idOf(store, category),
      title: title,
      content: content,
    ),
  );

  ArchiveContents exported(JournalStore store) => JournalArchive.unpack(
    JournalArchive.pack(store.journalPath!, exportedAt: '2026-10-11T12:00:00'),
  );

  Future<MergeResult> carry(JournalStore from, JournalStore to) {
    final contents = exported(from);
    return to.merge(contents.categories, contents.entries);
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

  test('the file is a zip of the journal folder as it is kept', () {
    final store = journal();
    final saved = write(store, 'Dream', 'Flying', content: 'Over **water**.');
    final zip = ZipDecoder().decodeBytes(
      JournalArchive.pack(store.journalPath!, exportedAt: 'now'),
    );

    final names = [for (final file in zip.files) file.name]..sort();
    expect(names, [
      'candra.json',
      'categories.json',
      'entries/2026/10/11/${saved.categoryId}/100000.md',
    ]);
    expect(jsonDecode(utf8.decode(zip.findFile('candra.json')!.content)), {
      'app': 'candra',
      'format': 1,
      'exported': 'now',
    });
    // The entry inside is the very file on disk.
    expect(
      utf8.decode(zip.files.last.content),
      File(
        '${store.journalPath}/entries/2026/10/11/${saved.categoryId}/100000.md',
      ).readAsStringSync(),
    );
    expect(
      JournalArchive.nameFor(DateTime(2026, 10, 11, 9, 5, 7)),
      'candra-20261011-090507.zip',
    );
  });

  test(
    'a journal carried to a new phone arrives whole, with no doubles',
    () async {
      final old = journal();
      old.renameCategory(idOf(old, 'Dream'), 'Dreams');
      final extra = old.addCategory('Night walks', colorIndex: 5)!;
      write(old, 'Occasion', 'Birthday');
      write(
        old,
        'Dreams',
        'Flying',
        minute: 700,
        content: 'Over **water**.\n\nTwice.',
      );
      write(old, 'Night walks', 'Cold', date: CivilDate(2027, 1, 1));

      // A fresh journal has its own five starting categories.
      final fresh = journal();
      final result = await carry(old, fresh);

      expect(result.entries, 3);
      expect(result.alreadyHere, 0);
      // The starting categories were empty, so the old ones of the same
      // name took their places. The one renamed on the old phone has no
      // namesake here, so the untouched starting Dream stays beside it:
      // seven in all, not eleven.
      expect(fresh.categories.map((c) => c.name), [
        'Occasion',
        'Observance',
        'Dream',
        'Divination',
        'Plant log',
        'Dreams',
        'Night walks',
      ]);
      expect(result.categories, 2);
      expect(fresh.category(extra.id)!.colorIndex, 5);
      expect(idOf(fresh, 'Occasion'), idOf(old, 'Occasion'));
      expect(
        fresh.categories.map((c) => c.colorIndex).toSet(),
        hasLength(fresh.categories.length),
      );

      final read = fresh.entriesFor(day, utcOffset: offset);
      expect(read.map((e) => e.title), unorderedEquals(['Birthday', 'Flying']));
      expect(
        read.firstWhere((e) => e.title == 'Flying').content,
        'Over **water**.\n\nTwice.',
      );
      expect(fresh.entryTotal, 3);
      // And it is all on disk: it survives a restart.
      final again = JournalStore(FileJournalStorage.open(roots[1]));
      stores.add(again);
      expect(again.entryTotal, 3);
      expect(again.categories, hasLength(7));
    },
  );

  test(
    'importing the same file twice changes nothing the second time',
    () async {
      final from = journal();
      write(from, 'Dream', 'Flying');
      write(from, 'Occasion', 'Birthday', minute: 700);
      final to = journal();
      await carry(from, to);
      final second = await carry(from, to);

      expect(second.entries, 0);
      expect(second.categories, 0);
      expect(second.alreadyHere, 2);
      expect(to.entryTotal, 2);
    },
  );

  test('nothing already here is lost or overwritten', () async {
    final from = journal();
    final to = journal();
    // Both wrote something at the very same second; the words differ.
    write(to, 'Dream', 'Mine', content: 'Kept.');
    write(to, 'Plant log', 'Also mine', minute: 800);
    write(from, 'Occasion', 'Theirs', content: 'Brought in.');
    final result = await carry(from, to);

    expect(result.entries, 1);
    expect(result.moved, 1);
    final read = to.entriesFor(day, utcOffset: offset);
    expect(read, hasLength(3));
    expect(read.firstWhere((e) => e.title == 'Mine').content, 'Kept.');
    expect(read.firstWhere((e) => e.title == 'Mine').secondOfDay, 36000);
    // The one coming in took the next second.
    expect(read.firstWhere((e) => e.title == 'Theirs').secondOfDay, 36001);
    // A category of mine with entries in it does not give way: there are
    // two Occasions only if both were in use; here theirs replaced my
    // empty one, and my Dream, in use, stayed beside theirs.
    expect(to.categories.where((c) => c.name == 'Dream'), hasLength(2));
    expect(to.categories.where((c) => c.name == 'Occasion'), hasLength(1));
  });

  test('an entry that differs only in its geotag is a second version, '
      'never dropped as already here', () async {
    final from = journal();
    final to = journal();
    final first = write(from, 'Dream', 'Flying');
    await carry(from, to);
    // On the other phone the same entry gets a geotag afterwards: same
    // category, title and content, same second.
    from.save(first.copyWith(place: GeoTag.rounded(-7.797, 110.369)));
    final result = await carry(from, to);

    expect(result.alreadyHere, 0);
    expect(result.entries, 1);
    expect(result.moved, 1);
    final read = to.entriesFor(day, utcOffset: offset);
    expect(read, hasLength(2));
    // Nothing here was overwritten, and nothing coming in vanished.
    expect(read.firstWhere((e) => e.secondOfDay == 36000).place, isNull);
    expect(
      read.firstWhere((e) => e.secondOfDay == 36001).place,
      GeoTag.rounded(-7.797, 110.369),
    );
  });

  test('a duration is part of the entry too', () async {
    final from = journal();
    final to = journal();
    final first = write(from, 'Dream', 'Sitting');
    await carry(from, to);
    from.save(
      Entry(
        id: first.id,
        date: first.date,
        minuteOfDay: first.minuteOfDay,
        second: first.second,
        utcOffset: first.utcOffset,
        categoryId: first.categoryId,
        title: first.title,
        content: first.content,
        duration: const Duration(minutes: 25),
      ),
    );
    final result = await carry(from, to);
    expect(result.alreadyHere, 0);
    expect(result.moved, 1);
  });

  test('a colour already taken here is swapped for a free one', () async {
    final from = journal();
    final to = journal();
    final theirs = from.addCategory('Theirs', colorIndex: 5)!;
    to.addCategory('Mine', colorIndex: 5);
    write(from, 'Theirs', 'x');
    await carry(from, to);

    expect(to.category(theirs.id)!.colorIndex, isNot(5));
    expect(
      to.categories.map((c) => c.colorIndex).toSet(),
      hasLength(to.categories.length),
    );
  });

  test(
    'more than twenty-four categories is refused, with nothing changed',
    () async {
      final from = journal();
      final to = journal();
      for (var i = 0; i < 12; i++) {
        write(from, from.addCategory('From $i')!.name, 'x', minute: i);
        to.addCategory('To $i');
      }
      // Seventeen here; twelve more that match nothing.
      final before = to.categories.map((c) => c.id).toList();
      await expectLater(carry(from, to), throwsA(isA<TooManyCategories>()));
      expect(to.categories.map((c) => c.id), before);
      expect(to.entryTotal, 0);
    },
  );

  test('a zip made by hand is taken too', () async {
    final store = journal();
    final zip = Archive()
      ..addFile(
        ArchiveFile.string(
          'my backup/entries/2026/10/11/abc123/090000.md',
          '---\ndate: 2026-10-11\ntime: 09:00\nutc_offset: +07:00\n'
              'category: whatever\ntitle: By hand\n---\nTyped in an editor.\n',
        ),
      )
      ..addFile(
        ArchiveFile.string('my backup/entries/2026/10/11/abc123/x.md', 'junk'),
      )
      ..addFile(ArchiveFile.string('my backup/notes.txt', 'ignored'));
    final contents = JournalArchive.unpack(ZipEncoder().encodeBytes(zip));

    expect(contents.unreadable, 1);
    // The folder decides the category, and with no list of categories it
    // is named after the folder.
    final result = await store.merge(contents.categories, contents.entries);
    expect(result.entries, 1);
    expect(store.category('abc123')!.name, 'abc123');
    final read = store.entriesFor(day, utcOffset: offset).single;
    expect(read.title, 'By hand');
    expect(read.content, 'Typed in an editor.');
    expect(read.categoryId, 'abc123');
  });

  test('anything else is turned away', () {
    expect(
      () => JournalArchive.unpack(utf8.encode('not a zip at all')),
      throwsFormatException,
    );
    final unrelated = Archive()
      ..addFile(ArchiveFile.string('holiday/photo.txt', 'x'));
    expect(
      () => JournalArchive.unpack(ZipEncoder().encodeBytes(unrelated)),
      throwsFormatException,
    );
  });
}
