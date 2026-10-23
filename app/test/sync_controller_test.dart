import 'dart:io';

import 'package:candra/app_shell.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/journal_file_screen.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/strings.dart';
import 'package:candra/sync/git_host.dart';
import 'package:candra/sync/sync_controller.dart';
import 'package:candra/sync/sync_engine.dart';
import 'package:candra/sync/sync_screens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

import 'support/fake_git_host.dart';

/// One phone, as the app sets it up: journal, reminders, and sync.
class Phone {
  Phone(this.repository, {Duration settle = const Duration(milliseconds: 5)})
    : root = Directory.systemTemp.createTempSync('sync-phone') {
    journal = JournalStore(FileJournalStorage.open(root));
    reminders = ReminderStore(
      file: File('${journal.journalPath}/reminders.json'),
      utcOffset: const Duration(hours: 7),
    );
    host = FakeGitHost(repository);
    sync = _controller(settle);
  }

  final FakeRepository repository;
  final Directory root;
  final secrets = MemorySecretStore();
  late final JournalStore journal;
  late final ReminderStore reminders;
  late final FakeGitHost host;
  late SyncController sync;

  /// What the phone was last asked to connect to.
  String? askedFor;

  SyncController _controller(Duration settle) => SyncController(
    root: root,
    journal: journal,
    reminders: reminders,
    secrets: secrets,
    settle: settle,
    hostFor: (owner, repository, token) {
      askedFor = '$owner/$repository with $token';
      return host;
    },
  );

  /// As if the app had been closed and opened again.
  Future<void> restart() async {
    sync.dispose();
    sync = _controller(const Duration(milliseconds: 5));
    await sync.start();
  }

  String idOf(String category) =>
      journal.categories.firstWhere((c) => c.name == category).id;

  Entry write(String title, {int minute = 600, String content = 'Words.'}) =>
      journal.save(
        Entry(
          id: '',
          date: CivilDate(2026, 10, 11),
          minuteOfDay: minute,
          utcOffset: const Duration(hours: 7),
          categoryId: idOf('Dream'),
          title: title,
          content: content,
        ),
      );

  List<String> get titles => [
    for (final entry in journal.entriesFor(
      CivilDate(2026, 10, 11),
      utcOffset: const Duration(hours: 7),
    ))
      entry.title,
  ]..sort();

  void dispose() {
    sync.dispose();
    journal.dispose();
    root.deleteSync(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRepository repository;
  final phones = <Phone>[];

  Phone phone({Duration settle = const Duration(milliseconds: 5)}) {
    final made = Phone(repository, settle: settle);
    phones.add(made);
    return made;
  }

  // Long enough for a sync set off by a change to have run.
  Future<void> settled() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  setUp(() => repository = FakeRepository());
  tearDown(() {
    for (final made in phones) {
      made.dispose();
    }
    phones.clear();
  });

  group('the controller', () {
    test('a repository can be given by name, web address or git address', () {
      for (final typed in [
        'me/journal',
        ' me/journal ',
        'https://github.com/me/journal',
        'https://github.com/me/journal.git',
        'https://github.com/me/journal/',
        'git@github.com:me/journal.git',
      ]) {
        expect(SyncController.repositoryFrom(typed), 'me/journal');
      }
      expect(SyncController.repositoryFrom('journal'), isNull);
      expect(SyncController.repositoryFrom(''), isNull);
    });

    test('connecting keeps the token safe, syncs, and remembers', () async {
      final a = phone()..write('Flying');
      expect(a.sync.phase, SyncPhase.off);

      final problem = await a.sync.connect(
        'https://github.com/me/journal.git',
        ' secret-token ',
      );
      expect(problem, isNull);
      expect(a.askedFor, 'me/journal with secret-token');
      expect(a.sync.repository, 'me/journal');
      expect(a.sync.phase, SyncPhase.idle);
      expect(a.sync.lastSynced, isNotNull);
      expect(a.secrets.secret, 'secret-token');
      expect(repository.files.keys, hasLength(2));
      // The token is not in the file that remembers the rest.
      final remembered = File('${a.root.path}/sync.json').readAsStringSync();
      expect(remembered, contains('me/journal'));
      expect(remembered, isNot(contains('secret-token')));
    });

    test('a connection that fails keeps nothing', () async {
      final a = phone();
      a.host.failure = const SyncDenied();
      expect(await a.sync.connect('me/journal', 'bad'), SyncProblem.denied);
      expect(a.sync.phase, SyncPhase.off);
      expect(a.secrets.secret, isNull);
      expect(File('${a.root.path}/sync.json').existsSync(), isFalse);

      a.host.failure = const SyncOffline();
      expect(await a.sync.connect('me/journal', 'x'), SyncProblem.offline);
      expect(await a.sync.connect('nonsense', 'x'), SyncProblem.notFound);
    });

    test('syncs by itself a moment after anything changes', () async {
      final a = phone();
      await a.sync.connect('me/journal', 'token');
      final before = repository.commits.length;

      a.write('Flying');
      a.reminders.save(
        Reminder(
          id: '',
          title: 'Offering',
          start: CivilDate(2026, 10, 11),
          minuteOfDay: 600,
          repeat: Repeat.weton,
        ),
      );
      await settled();

      expect(repository.commits.length, greaterThan(before));
      expect(repository.files.keys, contains('reminders.json'));
      expect(repository.read('reminders.json'), contains('Offering'));
      expect(
        repository.files.keys.where((p) => p.startsWith('entries/')),
        hasLength(1),
      );
    });

    test('a second phone gets it all, and the two then keep in step', () async {
      final a = phone()..write('Flying');
      a.reminders.save(
        Reminder(
          id: '',
          title: 'Offering',
          start: CivilDate(2026, 10, 11),
          minuteOfDay: 600,
          repeat: Repeat.weton,
        ),
      );
      await a.sync.connect('me/journal', 'token');
      await settled();

      final b = phone();
      await b.sync.connect('me/journal', 'token');
      // The stores were read afresh: no restart needed to see it.
      expect(b.titles, ['Flying']);
      expect(b.reminders.reminders.single.title, 'Offering');
      expect(b.journal.categories, hasLength(5));

      b.write('From b', minute: 700);
      await settled();
      await a.sync.syncNow();
      expect(a.titles, ['Flying', 'From b']);
    });

    test('picks up where it left off after the app is closed', () async {
      final a = phone()..write('Flying');
      await a.sync.connect('me/journal', 'token');
      final b = phone();
      await b.sync.connect('me/journal', 'token');

      b.write('While a was closed', minute: 700);
      await settled();
      await a.restart();
      await settled();

      expect(a.sync.phase, SyncPhase.idle);
      expect(a.sync.repository, 'me/journal');
      expect(a.titles, ['Flying', 'While a was closed']);
    });

    test('conflicts wait for the user, and say so', () async {
      final a = phone();
      final entry = a.write('Flying');
      await a.sync.connect('me/journal', 'token');
      final b = phone(settle: const Duration(days: 1));
      await b.sync.connect('me/journal', 'token');

      a.journal.save(entry.copyWith(content: 'As a wrote it.'));
      await settled();
      b.journal.save(
        b.journal
            .entriesFor(CivilDate(2026, 10, 11), utcOffset: Duration.zero)
            .single
            .copyWith(content: 'As b wrote it.'),
      );
      await b.sync.syncNow();

      expect(b.sync.phase, SyncPhase.conflicts);
      expect(b.sync.needsAttention, isTrue);
      expect(b.sync.conflicts, hasLength(1));

      await b.sync.resolve({b.sync.conflicts.single.path: Keep.both});
      expect(b.sync.phase, SyncPhase.idle);
      expect(b.sync.conflicts, isEmpty);
      expect(b.sync.needsAttention, isFalse);
      expect(b.titles, ['Flying', 'Flying']);
    });

    test('being offline is not an alarm, and mends itself', () async {
      final a = phone(settle: const Duration(days: 1));
      await a.sync.connect('me/journal', 'token');
      a.write('Flying');
      a.host.failure = const SyncOffline();
      await a.sync.syncNow();

      expect(a.sync.phase, SyncPhase.failed);
      expect(a.sync.problem, SyncProblem.offline);
      expect(a.sync.needsAttention, isFalse);

      a.host.failure = null;
      await a.sync.syncNow();
      expect(a.sync.phase, SyncPhase.idle);
      expect(
        repository.files.keys.where((p) => p.startsWith('entries/')),
        hasLength(1),
      );

      // A token GitHub refuses does want a look.
      a.host.failure = const SyncDenied();
      await a.sync.syncNow();
      expect(a.sync.problem, SyncProblem.denied);
      expect(a.sync.needsAttention, isTrue);
    });

    test('turning it off forgets the token and stops syncing', () async {
      final a = phone();
      await a.sync.connect('me/journal', 'token');
      await a.sync.disconnect();

      expect(a.sync.phase, SyncPhase.off);
      expect(a.sync.repository, isNull);
      expect(a.secrets.secret, isNull);
      expect(File('${a.root.path}/sync.json').existsSync(), isFalse);

      final before = repository.commits.length;
      a.write('After');
      await settled();
      expect(repository.commits, hasLength(before));
      // The journal here and the repository are both as they were.
      expect(a.titles, ['After']);
      expect(repository.files.keys, contains('categories.json'));
    });
  });

  group('the screens', () {
    Finder key(String name) => find.byKey(ValueKey(name));

    Future<void> pump(WidgetTester tester, Phone p, {Widget? home}) async {
      tester.view.physicalSize = const Size(1440, 3040);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(saved: AppLanguage.en),
          journal: p.journal,
          reminders: p.reminders,
          sync: p.sync,
          home: home ?? const JournalFileScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    const order = [
      'share',
      'save',
      'import',
      'connect',
      'resolve',
      'sync',
      'turnOff',
    ];

    // The action whose card is at the centre of the strip.
    String centred(WidgetTester tester) {
      final middle = tester.getCenter(key('action-strip')).dx;
      for (final name in order) {
        final card = key('action-$name');
        if (card.evaluate().isNotEmpty &&
            (tester.getCenter(card).dx - middle).abs() < 2) {
          return name;
        }
      }
      fail('no card at the centre');
    }

    // Brings an action to the centre of the strip, a card at a time: a
    // tap on a card beside the centre only brings it there.
    Future<void> choose(WidgetTester tester, String action) async {
      for (var steps = 0; centred(tester) != action; steps++) {
        if (steps > order.length) fail('no action $action on the strip');
        // Only its edge shows beside the chosen card: tap that.
        final strip = tester.getRect(key('action-strip'));
        final onward = order.indexOf(action) > order.indexOf(centred(tester));
        await tester.tapAt(
          Offset(onward ? strip.right - 8 : strip.left + 8, strip.center.dy),
        );
        await tester.pumpAndSettle();
      }
    }

    // Something in the setup's list, which may run past the body: the
    // list is drawn along to it first, [by] a step.
    Future<void> bringIn(WidgetTester tester, String name, Offset by) async {
      await tester.dragUntilVisible(
        key(name),
        find
            .descendant(
              of: find.byType(SyncSetupScreen),
              matching: find.byType(Scrollable),
            )
            .first,
        by,
      );
      await tester.pumpAndSettle();
    }

    // The connect button, under the how-to.
    Future<void> showConnect(WidgetTester tester) =>
        bringIn(tester, 'sync-connect', const Offset(0, -200));

    // The fields, at the top of the list.
    Future<void> showFields(WidgetTester tester) =>
        bringIn(tester, 'sync-repository', const Offset(0, 200));

    Finder fieldIn(String name) =>
        find.descendant(of: key(name), matching: find.byType(EditableText));

    test('a repository is taken as owner/name or as its address', () {
      for (final typed in [
        'someone/journal',
        'https://github.com/someone/journal',
        'https://github.com/someone/journal/',
        'https://github.com/someone/journal.git',
        'git@github.com:someone/journal.git',
        '  someone/journal  ',
      ]) {
        expect(SyncController.repositoryFrom(typed), 'someone/journal');
      }
      expect(SyncController.repositoryFrom('journal'), isNull);
      expect(SyncController.repositoryFrom('https://example.com/a/b'), isNull);
    });

    testWidgets('setting sync up from the export and import screen', (
      tester,
    ) async {
      final p = phone(settle: const Duration(days: 1));
      await pump(tester, p);
      await choose(tester, 'connect');
      expect(key('action-sync'), findsNothing);
      expect(find.text('Sync with GitHub'), findsOneWidget);

      // The chosen card, tapped, does it.
      await tap(tester, key('action-connect'));
      expect(find.byType(SyncSetupScreen), findsOneWidget);
      // It says where the journal will be, and that it is not encrypted.
      expect(find.textContaining('not encrypted'), findsOneWidget);
      expect(find.textContaining('fine-grained'), findsOneWidget);

      // Both are needed.
      await showConnect(tester);
      await tester.tap(key('sync-connect'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Both the repository and the token are needed.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      await showFields(tester);
      await tester.enterText(fieldIn('sync-repository'), 'me/journal');
      await tester.enterText(fieldIn('sync-token'), 'token');
      await showConnect(tester);
      await tester.runAsync(() async {
        await tester.tap(key('sync-connect'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Back on the export and import screen, now with sync on.
      expect(find.byType(SyncSetupScreen), findsNothing);
      expect(p.sync.phase, SyncPhase.idle);
      expect(
        find.descendant(
          of: key('action-sync'),
          matching: find.text('me/journal'),
        ),
        findsOneWidget,
      );
      expect(key('action-connect'), findsNothing);
      // Sync now has taken its place at the centre.
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.textContaining('In step as of'), findsOneWidget);
      expect(key('action-turnOff'), findsOneWidget);
    });

    testWidgets('a token GitHub refuses is said plainly, and nothing is kept', (
      tester,
    ) async {
      final p = phone(settle: const Duration(days: 1));
      p.host.failure = const SyncDenied();
      await pump(tester, p, home: const SyncSetupScreen());
      await tester.enterText(fieldIn('sync-repository'), 'me/journal');
      await tester.enterText(fieldIn('sync-token'), 'bad');
      await showConnect(tester);
      await tester.runAsync(() async {
        await tester.tap(key('sync-connect'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('GitHub refused the token'), findsOneWidget);
      expect(find.byType(SyncSetupScreen), findsOneWidget);
      expect(p.sync.phase, SyncPhase.off);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('settling a conflict: both versions shown, one tap each', (
      tester,
    ) async {
      late Phone a;
      late Phone b;
      await tester.runAsync(() async {
        a = phone(settle: const Duration(days: 1));
        final entry = a.write('Flying');
        await a.sync.connect('me/journal', 'token');
        b = phone(settle: const Duration(days: 1));
        await b.sync.connect('me/journal', 'token');
        a.journal.save(entry.copyWith(content: 'As **a** wrote it.'));
        await a.sync.syncNow();
        b.journal.save(
          b.journal
              .entriesFor(CivilDate(2026, 10, 11), utcOffset: Duration.zero)
              .single
              .copyWith(content: 'As b wrote it.'),
        );
        await b.sync.syncNow();
      });
      await pump(tester, b);

      // The screen opens on what sync wants.
      expect(find.text('Settle 1 conflict'), findsOneWidget);
      expect(centred(tester), 'resolve');
      await tap(tester, key('action-resolve'));
      expect(find.byType(ConflictsScreen), findsOneWidget);
      expect(find.text('Conflict 1 of 1'), findsOneWidget);
      expect(find.text('11 October 2026 · 10:00'), findsOneWidget);
      expect(find.text('ON THIS DEVICE'), findsOneWidget);
      expect(find.text('ON GITHUB'), findsOneWidget);
      expect(
        find.descendant(
          of: key('conflict-mine'),
          matching: find.textContaining('As b wrote it.', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('conflict-theirs'),
          matching: find.textContaining('wrote it.', findRichText: true),
        ),
        findsOneWidget,
      );
      for (final choice in ['keep-mine', 'keep-both', 'keep-theirs']) {
        expect(key(choice), findsOneWidget);
      }

      await tester.runAsync(() async {
        await tester.tap(key('keep-both'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ConflictsScreen), findsNothing);
      expect(b.sync.phase, SyncPhase.idle);
      expect(b.titles, ['Flying', 'Flying']);
      expect(key('action-resolve'), findsNothing);
    });

    testWidgets(
      'the box on the month screen is dotted when sync wants a look',
      (tester) async {
        final p = phone(settle: const Duration(days: 1));
        await tester.runAsync(() => p.sync.connect('me/journal', 'token'));
        await pump(
          tester,
          p,
          home: MonthScreen(today: CivilDate(2026, 10, 11)),
        );
        expect(tester.widget<GlyphButton>(key('menu-button')).marked, isFalse);

        p.host.failure = const SyncDenied();
        await tester.runAsync(() => p.sync.syncNow());
        await tester.pumpAndSettle();
        expect(tester.widget<GlyphButton>(key('menu-button')).marked, isTrue);
      },
    );

    testWidgets('turning sync off from the screen', (tester) async {
      final p = phone(settle: const Duration(days: 1));
      await tester.runAsync(() => p.sync.connect('me/journal', 'token'));
      await pump(tester, p);
      await choose(tester, 'turnOff');
      await tester.runAsync(() async {
        await tester.tap(key('action-turnOff'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(p.sync.phase, SyncPhase.off);
      expect(key('action-connect'), findsOneWidget);
      expect(key('action-sync'), findsNothing);
    });
  });
}
