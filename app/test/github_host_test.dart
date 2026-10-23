import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:candra/journal/entry.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/sync/git_host.dart';
import 'package:candra/sync/github_host.dart';
import 'package:candra/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

import 'support/fake_github_server.dart';

void main() {
  late FakeGitHubServer github;
  final roots = <Directory>[];

  GitHubHost host({String token = 'good', String repository = 'journal'}) =>
      GitHubHost(
        owner: 'me',
        repository: repository,
        token: token,
        api: github.url,
      );

  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  setUp(() async => github = await FakeGitHubServer.start());
  tearDown(() async {
    await github.stop();
    for (final root in roots) {
      root.deleteSync(recursive: true);
    }
    roots.clear();
  });

  test('finds the repository\'s own branch', () async {
    final connected = host();
    await connected.connect();
    expect(connected.branch, 'main');
  });

  test(
    'an empty repository has no head, and the first commit starts it',
    () async {
      final h = host();
      expect(await h.headCommit(), isNull);
      expect((await h.head()).files, isEmpty);

      final made = await h.commit(
        parent: const RemoteHead(),
        changes: {
          'categories.json': bytes('[]\n'),
          'entries/a.md': bytes('é ✓\n'),
        },
        message: 'First',
      );
      expect(made.commit, github.head);
      expect(github.read('categories.json'), '[]\n');
      // Text that is not plain ASCII arrives whole.
      expect(github.read('entries/a.md'), 'é ✓\n');
      expect(await h.headCommit(), made.commit);
    },
  );

  test('reads back the files and their contents', () async {
    final h = host();
    await h.commit(
      parent: const RemoteHead(),
      changes: {'entries/a.md': bytes('${'long line ' * 40}\n')},
      message: 'First',
    );
    final head = await h.head();
    expect(head.files.keys, containsAll(['entries/a.md']));
    // Folders in GitHub's listing are not files.
    expect(head.files.containsKey('entries'), isFalse);
    expect(
      head.files['entries/a.md'],
      blobSha(bytes('${'long line ' * 40}\n')),
    );
    expect(
      utf8.decode(await h.blob(head.files['entries/a.md']!)),
      '${'long line ' * 40}\n',
    );
  });

  test('changes and deletes files in later commits', () async {
    final h = host();
    var head = await h.commit(
      parent: const RemoteHead(),
      changes: {'a.md': bytes('one\n'), 'b.md': bytes('two\n')},
      message: 'First',
    );
    head = await h.commit(
      parent: await h.head(),
      changes: {'a.md': bytes('one, changed\n'), 'b.md': null},
      message: 'Second',
    );
    expect(github.read('a.md'), 'one, changed\n');
    expect(github.read('b.md'), isNull);
    expect(github.head, head.commit);
  });

  test('a commit on an old head is refused as stale', () async {
    final h = host();
    await h.commit(
      parent: const RemoteHead(),
      changes: {'a.md': bytes('one\n')},
      message: 'First',
    );
    final old = await h.head();
    await h.commit(
      parent: old,
      changes: {'b.md': bytes('two\n')},
      message: 'b',
    );

    await expectLater(
      h.commit(parent: old, changes: {'c.md': bytes('three\n')}, message: 'c'),
      throwsA(isA<StaleHead>()),
    );
    expect(github.read('c.md'), isNull);
  });

  test('many files go up in batches', () async {
    final h = host();
    await h.commit(
      parent: const RemoteHead(),
      changes: {for (var i = 0; i < 250; i++) 'entries/$i.md': bytes('$i\n')},
      message: 'Many',
    );
    expect(
      github.files.keys.where((p) => p.startsWith('entries/')),
      hasLength(250),
    );
    expect(github.read('entries/249.md'), '249\n');
  });

  test(
    'a bad token, a missing repository and no network each say so',
    () async {
      await expectLater(
        host(token: 'bad').headCommit(),
        throwsA(isA<SyncDenied>()),
      );
      await expectLater(
        host(repository: 'nowhere').connect(),
        throwsA(isA<SyncNotFound>()),
      );
      github.mayPush = false;
      await expectLater(host().connect(), throwsA(isA<SyncDenied>()));

      final unreachable = GitHubHost(
        owner: 'me',
        repository: 'journal',
        token: 'good',
        branch: 'main',
        api: Uri.parse('http://127.0.0.1:1'),
      );
      await expectLater(unreachable.headCommit(), throwsA(isA<SyncOffline>()));
    },
  );

  test('GitHub\'s rate limit is told apart from a refused token', () async {
    // The hour's requests used up: until the time GitHub gives.
    github.refusal = (
      status: 403,
      headers: {
        'x-ratelimit-remaining': '0',
        'x-ratelimit-reset': '1800000000',
      },
      message: 'API rate limit exceeded',
    );
    await expectLater(
      host().headCommit(),
      throwsA(
        isA<SyncRateLimited>().having(
          (limited) => limited.until,
          'until',
          DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000),
        ),
      ),
    );

    // Told to wait so many seconds.
    github.refusal = (
      status: 429,
      headers: {'retry-after': '60'},
      message: 'Too many requests',
    );
    final before = DateTime.now();
    await expectLater(
      host().headCommit(),
      throwsA(
        isA<SyncRateLimited>().having(
          (limited) => limited.until!.difference(before).inSeconds,
          'seconds to wait',
          inInclusiveRange(59, 61),
        ),
      ),
    );

    // The secondary limit, said only in the message.
    github.refusal = (
      status: 403,
      headers: {},
      message: 'You have exceeded a secondary rate limit.',
    );
    await expectLater(
      host().headCommit(),
      throwsA(isA<SyncRateLimited>().having((l) => l.until, 'until', isNull)),
    );

    // A 403 that is none of these is still a refusal.
    github.refusal = (
      status: 403,
      headers: {'x-ratelimit-remaining': '4999'},
      message: 'Resource not accessible by personal access token',
    );
    await expectLater(host().headCommit(), throwsA(isA<SyncDenied>()));
  });

  test('two journals sync through it, over real HTTP', () async {
    (JournalStore, SyncEngine) phone(String name) {
      final root = Directory.systemTemp.createTempSync('github-$name');
      roots.add(root);
      final store = JournalStore(FileJournalStorage.open(root));
      return (
        store,
        SyncEngine(
          journal: Directory(store.journalPath!),
          host: host(),
          device: name,
        ),
      );
    }

    final (a, aEngine) = phone('a');
    final (b, bEngine) = phone('b');
    final dream = a.categories.firstWhere((c) => c.name == 'Dream').id;
    a.save(
      Entry(
        id: '',
        date: CivilDate(2026, 10, 11),
        minuteOfDay: 600,
        utcOffset: const Duration(hours: 7),
        categoryId: dream,
        title: 'Flying',
        content: 'Over **water**.',
      ),
    );

    final first = await aEngine.sync(const SyncState());
    expect(first.pushed, 2);
    final path = 'entries/2026/10/11/$dream/100000.md';
    expect(github.read(path), contains('Over **water**.'));
    // The file that started the repository stays there and is not brought
    // into anyone's journal.
    expect(github.files.containsKey('.candra'), isTrue);

    final second = await bEngine.sync(const SyncState());
    expect(second.conflicts, isEmpty);
    expect(
      File('${b.journalPath}/$path').readAsStringSync(),
      File('${a.journalPath}/$path').readAsStringSync(),
    );
    expect(File('${b.journalPath}/.candra').existsSync(), isFalse);

    // Nothing more to do either way.
    final again = await aEngine.sync(first.state);
    expect(again.pushed, 0);
    a.dispose();
    b.dispose();
  });
}
