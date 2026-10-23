import 'dart:convert';
import 'dart:io';

import 'package:candra/journal/entry.dart';
import 'package:candra/journal/geo.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/sync/git_host.dart';
import 'package:candra/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

import 'support/fake_git_host.dart';

/// One phone: a journal on disk, and what it remembers of the branch.
class Device {
  Device(this.name, FakeRepository repository)
    : root = Directory.systemTemp.createTempSync('sync-$name') {
    host = FakeGitHost(repository);
    store = JournalStore(FileJournalStorage.open(root));
    engine = SyncEngine(
      journal: Directory(store.journalPath!),
      host: host,
      device: name,
    );
  }

  final String name;
  final Directory root;
  late final FakeGitHost host;
  late JournalStore store;
  late final SyncEngine engine;
  var state = const SyncState();

  Future<SyncResult> sync([Map<String, Keep> resolutions = const {}]) async {
    final result = await engine.sync(state, resolutions: resolutions);
    state = result.state;
    // As the app does after a sync that changed files: read them afresh.
    if (result.changedHere) {
      store.dispose();
      File('${root.path}/index.db').deleteSync();
      store = JournalStore(FileJournalStorage.open(root));
    }
    return result;
  }

  String idOf(String category) =>
      store.categories.firstWhere((c) => c.name == category).id;

  Entry write(
    String title, {
    String category = 'Dream',
    int minute = 600,
    CivilDate? date,
    String content = 'Words.',
  }) => store.save(
    Entry(
      id: '',
      date: date ?? CivilDate(2026, 10, 11),
      minuteOfDay: minute,
      utcOffset: const Duration(hours: 7),
      categoryId: idOf(category),
      title: title,
      content: content,
    ),
  );

  List<String> titles([CivilDate? date]) => [
    for (final entry in store.entriesFor(
      date ?? CivilDate(2026, 10, 11),
      utcOffset: const Duration(hours: 7),
    ))
      entry.title,
  ]..sort();

  void dispose() {
    store.dispose();
    root.deleteSync(recursive: true);
  }
}

void main() {
  late FakeRepository repository;
  final devices = <Device>[];

  Device device(String name) {
    final made = Device(name, repository);
    devices.add(made);
    return made;
  }

  // Two phones that have met through the branch and agree on everything.
  Future<(Device, Device)> pair() async {
    final a = device('a');
    final b = device('b');
    await a.sync();
    await b.sync();
    await a.sync();
    return (a, b);
  }

  setUp(() => repository = FakeRepository());
  tearDown(() {
    for (final made in devices) {
      made.dispose();
    }
    devices.clear();
  });

  test('git names contents the way git does', () {
    // `printf 'hello\n' | git hash-object --stdin`
    expect(
      blobSha(utf8.encode('hello\n')),
      'ce013625030ba8dba906f756967f9e9ca394464a',
    );
    expect(blobSha(const []), 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
  });

  test('the first sync puts the whole journal on an empty branch', () async {
    final a = device('a');
    final saved = a.write('Flying');
    final result = await a.sync();

    expect(result.pushed, 2);
    expect(result.pulled, 0);
    expect(result.conflicts, isEmpty);
    expect(repository.commits, hasLength(1));
    expect(repository.commits.single.message, contains('from a'));
    expect(repository.files.keys, [
      'categories.json',
      'entries/2026/10/11/${saved.categoryId}/100000.md',
    ]);
    // What is there is the file as kept, byte for byte.
    expect(
      repository.read('entries/2026/10/11/${saved.categoryId}/100000.md'),
      File(
        '${a.store.journalPath}/entries/2026/10/11/${saved.categoryId}/100000.md',
      ).readAsStringSync(),
    );
  });

  test('a sync with nothing to do does nothing at all', () async {
    final a = device('a')..write('Flying');
    await a.sync();
    final before = repository.commits.length;
    repository
      ..headReads = 0
      ..blobReads = 0;

    final result = await a.sync();
    expect(result.pushed, 0);
    expect(result.pulled, 0);
    expect(repository.commits, hasLength(before));
    // It did not even read the branch's files: the head had not moved.
    expect(repository.headReads, 0);
    expect(repository.blobReads, 0);
  });

  test(
    'a second phone joins: it gets everything, and no category twice',
    () async {
      final a = device('a');
      a
        ..write('Flying')
        ..write('Birthday', category: 'Occasion', minute: 700);
      await a.sync();

      // A fresh install, with its own five starting categories.
      final b = device('b');
      final result = await b.sync();

      expect(result.conflicts, isEmpty);
      expect(b.titles(), ['Birthday', 'Flying']);
      // Its empty starting categories gave way to the ones of the same name.
      expect(b.store.categories.map((c) => c.name), [
        'Occasion',
        'Observance',
        'Dream',
        'Divination',
        'Plant log',
      ]);
      expect(b.idOf('Dream'), a.idOf('Dream'));
      expect(
        repository.files.keys.where((p) => p.startsWith('entries/')),
        hasLength(2),
      );
      // And the first phone has nothing to take back.
      final back = await a.sync();
      expect(back.pulled, 0);
      expect(back.pushed, 0);
    },
  );

  test('what one writes the other gets, both ways', () async {
    final (a, b) = await pair();
    a.write('From a');
    b.write('From b', minute: 700);
    await a.sync();
    final atB = await b.sync();
    expect(atB.pulled, 1);
    expect(atB.pushed, 1);
    await a.sync();

    expect(a.titles(), ['From a', 'From b']);
    expect(b.titles(), ['From a', 'From b']);
  });

  test('an edit and a delete travel too', () async {
    final (a, b) = await pair();
    final first = a.write('First');
    final second = a.write('Second', minute: 700);
    await a.sync();
    await b.sync();

    a.store.save(first.copyWith(title: 'First, edited'));
    a.store.delete(second);
    await a.sync();
    final result = await b.sync();

    expect(result.pulled, 2);
    expect(result.conflicts, isEmpty);
    expect(b.titles(), ['First, edited']);
    // Nothing is left of the deleted one, on disk or on the branch.
    expect(
      repository.files.keys.where((p) => p.endsWith('110000.md')),
      isEmpty,
    );
  });

  test(
    'moving an entry to another category moves its file everywhere',
    () async {
      final (a, b) = await pair();
      final entry = a.write('Flying');
      await a.sync();
      await b.sync();

      a.store.save(entry.copyWith(categoryId: a.idOf('Occasion')));
      await a.sync();
      await b.sync();

      expect(b.titles(), ['Flying']);
      expect(
        b.store
            .entriesFor(CivilDate(2026, 10, 11), utcOffset: Duration.zero)
            .single
            .categoryId,
        b.idOf('Occasion'),
      );
    },
  );

  group('the same entry changed on both phones', () {
    late Device a;
    late Device b;
    late String path;

    setUp(() async {
      (a, b) = await pair();
      final entry = a.write('Flying');
      path = 'entries/2026/10/11/${entry.categoryId}/100000.md';
      await a.sync();
      await b.sync();
      a.store.save(entry.copyWith(content: 'As a wrote it.'));
      b.store.save(
        b.store
            .entriesFor(CivilDate(2026, 10, 11), utcOffset: Duration.zero)
            .single
            .copyWith(content: 'As b wrote it.'),
      );
      // b also wrote something that has nothing to do with the quarrel.
      b.write('Unrelated', minute: 900);
      await a.sync();
    });

    test(
      'is reported and left alone on both sides; the rest still syncs',
      () async {
        final result = await b.sync();

        expect(result.conflicts.single.path, path);
        expect(
          utf8.decode(result.conflicts.single.mine!),
          contains('As b wrote it.'),
        );
        expect(
          utf8.decode(result.conflicts.single.theirs!),
          contains('As a wrote it.'),
        );
        expect(result.conflicts.single.canKeepBoth, isTrue);
        // Untouched here and there.
        expect(
          File('${b.store.journalPath}/$path').readAsStringSync(),
          contains('As b wrote it.'),
        );
        expect(repository.read(path), contains('As a wrote it.'));
        // The unrelated entry went up all the same.
        expect(result.pushed, 1);
        await a.sync();
        expect(a.titles(), ['Flying', 'Unrelated']);

        // And it is still a conflict the next time, not quietly overwritten.
        final again = await b.sync();
        expect(again.conflicts.single.path, path);
        expect(again.pushed, 0);
        expect(repository.read(path), contains('As a wrote it.'));
      },
    );

    test('keep mine: this phone\'s words go to the branch', () async {
      await b.sync();
      final result = await b.sync({path: Keep.mine});
      expect(result.conflicts, isEmpty);
      expect(repository.read(path), contains('As b wrote it.'));
      await a.sync();
      expect(
        File('${a.store.journalPath}/$path').readAsStringSync(),
        contains('As b wrote it.'),
      );
    });

    test('keep theirs: the branch\'s words come here', () async {
      await b.sync();
      final result = await b.sync({path: Keep.theirs});
      expect(result.conflicts, isEmpty);
      expect(
        File('${b.store.journalPath}/$path').readAsStringSync(),
        contains('As a wrote it.'),
      );
      expect(repository.read(path), contains('As a wrote it.'));
    });

    test('keep both: theirs is set beside mine, a second later', () async {
      await b.sync();
      final result = await b.sync({path: Keep.both});
      expect(result.conflicts, isEmpty);

      final beside = path.replaceFirst('100000.md', '100001.md');
      expect(repository.read(path), contains('As b wrote it.'));
      expect(repository.read(beside), contains('As a wrote it.'));
      // The copy is a proper entry of its own, named for its new second.
      expect(repository.read(beside), contains('id: 20261011-100001'));
      expect(repository.read(beside), contains('time: 10:00:01'));
      expect(repository.read(beside), contains('category_name: Dream'));

      await a.sync();
      for (final phone in [a, b]) {
        expect(phone.titles(), ['Flying', 'Flying', 'Unrelated']);
      }
    });
  });

  group('the geotag is part of the entry', () {
    late Device a;
    late Device b;
    late Entry entry;
    late String path;
    final here = GeoTag.rounded(-7.797, 110.369);
    final there = GeoTag.rounded(-6.175, 106.827);

    setUp(() async {
      (a, b) = await pair();
      entry = a.write('Flying');
      await a.sync();
      await b.sync();
      path = 'entries/2026/10/11/${a.idOf('Dream')}/100000.md';
    });

    GeoTag? placeOn(Device phone) => phone.store
        .entriesFor(
          CivilDate(2026, 10, 11),
          utcOffset: const Duration(hours: 7),
        )
        .single
        .place;

    test('a geotag added on one phone reaches the other', () async {
      a.store.save(entry.copyWith(place: here));
      await a.sync();
      final result = await b.sync();
      expect(result.conflicts, isEmpty);
      expect(placeOn(b), here);
    });

    test('different geotags on each phone are a conflict, and settling it '
        'keeps the chosen one', () async {
      a.store.save(entry.copyWith(place: here));
      b.store.save(entry.copyWith(place: there));
      await a.sync();
      final result = await b.sync();
      expect(result.conflicts.single.path, path);

      final settled = await b.sync({path: Keep.theirs});
      expect(settled.conflicts, isEmpty);
      expect(placeOn(b), here);
    });

    test('files apart only in their calendar lines are no conflict', () async {
      // As two versions of the app might word the lines for searching:
      // the entry itself is the same on both phones.
      void reword(Device phone, String moon) {
        final file = File('${phone.store.journalPath}/$path');
        file.writeAsStringSync(
          file.readAsStringSync().replaceFirst(
            RegExp(r'moon_phase: .*'),
            'moon_phase: $moon',
          ),
        );
      }

      reword(a, 'Waxing Crescent (a)');
      reword(b, 'Waxing Crescent (b)');
      await a.sync();
      final result = await b.sync();
      expect(result.conflicts, isEmpty);
      // The two agree byte for byte again.
      expect(
        File('${b.store.journalPath}/$path').readAsStringSync(),
        repository.read(path),
      );
    });
  });

  test('one phone edits what the other deleted: the user decides', () async {
    final (a, b) = await pair();
    final entry = a.write('Flying');
    final path = 'entries/2026/10/11/${entry.categoryId}/100000.md';
    await a.sync();
    await b.sync();

    a.store.delete(entry);
    b.store.save(
      b.store
          .entriesFor(CivilDate(2026, 10, 11), utcOffset: Duration.zero)
          .single
          .copyWith(content: 'Still wanted.'),
    );
    await a.sync();
    final result = await b.sync();

    final conflict = result.conflicts.single;
    expect(conflict.theirs, isNull);
    expect(conflict.mine, isNotNull);
    expect(conflict.canKeepBoth, isFalse);

    // Keeping mine brings it back for everyone.
    await b.sync({path: Keep.mine});
    await a.sync();
    expect(a.titles(), ['Flying']);
  });

  test(
    'both write at the very same second: neither is lost without asking',
    () async {
      final (a, b) = await pair();
      a.write('From a');
      b.write('From b');
      await a.sync();
      final result = await b.sync();

      expect(result.conflicts, hasLength(1));
      await b.sync({result.conflicts.single.path: Keep.both});
      await a.sync();
      expect(a.titles(), ['From a', 'From b']);
      expect(b.titles(), ['From a', 'From b']);
    },
  );

  group('categories', () {
    test('made, renamed and deleted on different phones all arrive', () async {
      final (a, b) = await pair();
      final walks = a.store.addCategory('Walks', colorIndex: 5)!;
      b.store.renameCategory(b.idOf('Dream'), 'Dreams');
      b.store.deleteCategory(b.idOf('Divination'));
      await a.sync();
      final result = await b.sync();
      await a.sync();

      expect(result.conflicts, isEmpty);
      for (final phone in [a, b]) {
        expect(phone.store.categories.map((c) => c.name), [
          'Occasion',
          'Observance',
          'Dreams',
          'Plant log',
          'Walks',
        ]);
        expect(phone.store.category(walks.id)!.colorIndex, 5);
      }
    });

    test('two made with one colour end up with two', () async {
      final (a, b) = await pair();
      a.store.addCategory('From a', colorIndex: 5);
      b.store.addCategory('From b', colorIndex: 5);
      await a.sync();
      await b.sync();
      await a.sync();

      for (final phone in [a, b]) {
        final colours = phone.store.categories.map((c) => c.colorIndex);
        expect(colours.toSet(), hasLength(colours.length));
        expect(phone.store.categories, hasLength(7));
      }
    });
  });

  test(
    'someone pushes in the middle of a sync: it starts over and gets it right',
    () async {
      final (a, b) = await pair();
      a.write('From a');
      b.write('From b', minute: 700);
      // Just as b is about to commit, a gets in first.
      b.host.beforeCommit = () => a.sync();

      final result = await b.sync();
      expect(result.conflicts, isEmpty);
      await a.sync();
      expect(a.titles(), ['From a', 'From b']);
      expect(b.titles(), ['From a', 'From b']);
    },
  );

  test('a failure leaves everything as it was', () async {
    final (a, _) = await pair();
    a.write('Flying');
    final before = a.state;
    a.host.failure = const SyncOffline();

    await expectLater(a.sync(), throwsA(isA<SyncOffline>()));
    expect(a.state, same(before));
    expect(a.titles(), ['Flying']);
    // Once the host is back it goes through.
    a.host.failure = null;
    expect((await a.sync()).pushed, 1);
  });

  test('what a phone remembers survives being written down', () async {
    final a = device('a')..write('Flying');
    await a.sync();
    final read = SyncState.fromJson(
      jsonDecode(jsonEncode(a.state.toJson())) as Map<String, dynamic>,
    );
    expect(read.commit, a.state.commit);
    expect(read.tree, a.state.tree);
    expect(read.files, a.state.files);
    a.state = read;
    expect((await a.sync()).pushed, 0);
  });
}
