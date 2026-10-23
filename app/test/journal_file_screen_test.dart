import 'dart:io';

import 'package:candra/app_shell.dart';
import 'package:candra/house.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/journal_archive.dart';
import 'package:candra/journal/journal_file_screen.dart';
import 'package:candra/journal/journal_files.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// Stands in for the phone's share sheet and file screens.
class FakeFiles extends JournalFiles {
  FakeFiles({this.picked, this.pickError, this.saves = true});

  final ArchiveContents? picked;
  final Object? pickError;
  final bool saves;
  final done = <String>[];

  @override
  Future<File> pack(JournalStore store) async {
    done.add('pack');
    return File('candra-test.zip');
  }

  @override
  Future<void> share(File file) async => done.add('share ${file.path}');

  @override
  Future<bool> saveAs(File file) async {
    done.add('saveAs ${file.path}');
    return saves;
  }

  @override
  Future<ArchiveContents?> pick() async {
    done.add('pick');
    if (pickError != null) throw pickError!;
    return picked;
  }
}

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));

  Future<JournalStore> pump(
    WidgetTester tester,
    FakeFiles files, {
    AppLanguage language = AppLanguage.en,
  }) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    final store = JournalStore();
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: language),
        journal: store,
        home: JournalFileScreen(files: files),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> tap(WidgetTester tester, String name) async {
    await tester.tap(key(name));
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

  // Brings an action to the centre of the strip, then does it: a tap on
  // the chosen card itself.
  Future<void> run(WidgetTester tester, String action) async {
    await choose(tester, action);
    await tap(tester, 'action-$action');
  }

  Future<void> letToastGo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Entry entry(String title, {int minute = 600, String category = 'dream'}) =>
      Entry(
        id: '',
        date: CivilDate(2030, 1, 1),
        minuteOfDay: minute,
        utcOffset: const Duration(hours: 7),
        categoryId: category,
        title: title,
        content: 'Words.',
      );

  testWidgets('says what is in the journal and offers the three things', (
    tester,
  ) async {
    final store = await pump(tester, FakeFiles());

    expect(find.text('Export and import'), findsOneWidget);
    expect(find.text('0 entries in 5 categories'), findsOneWidget);
    // The body lists every category and the reminders.
    for (final category in store.categories) {
      expect(
        find.descendant(
          of: key('journal-manifest'),
          matching: find.text(category.name),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: key('journal-manifest'),
        matching: find.text('Reminders'),
      ),
      findsOneWidget,
    );
    // The strip has a card for each; the first is at the centre, saying
    // what it does.
    expect(centred(tester), 'share');
    expect(key('action-save'), findsOneWidget);
    expect(
      find.descendant(
        of: key('action-share'),
        matching: find.text('Share a copy'),
      ),
      findsOneWidget,
    );
    // It says plainly that the copy is not encrypted.
    expect(
      find.descendant(
        of: key('action-share'),
        matching: find.textContaining('unencrypted'),
      ),
      findsOneWidget,
    );
    // Another action brought to the centre is the chosen one; the body
    // does not change.
    final manifest = tester.getRect(key('journal-manifest'));
    await choose(tester, 'import');
    expect(
      find.descendant(
        of: key('action-import'),
        matching: find.text('Import a file'),
      ),
      findsOneWidget,
    );
    expect(centred(tester), 'import');
    expect(key('note-import'), findsNothing);
    expect(tester.getRect(key('journal-manifest')), manifest);
  });

  testWidgets('a card beside the centre is only brought there by a tap; the '
      'one at the centre is done by it', (tester) async {
    final files = FakeFiles();
    await pump(tester, files);
    // The edge of the next card, showing beside the chosen one.
    final strip = tester.getRect(key('action-strip'));
    await tester.tapAt(Offset(strip.right - 8, strip.center.dy));
    await tester.pumpAndSettle();
    expect(centred(tester), 'save');
    expect(files.done, isEmpty);

    // Tapped again, now that it is at the centre: done.
    await tap(tester, 'action-save');
    expect(files.done, ['pack', 'saveAs candra-test.zip']);
    await letToastGo(tester);
  });

  testWidgets('swiping the strip chooses the action it comes to rest on', (
    tester,
  ) async {
    final files = FakeFiles();
    await pump(tester, files);
    final width = tester.getSize(key('action-strip')).width;
    await tester.drag(key('action-strip'), Offset(-width * 0.84, 0));
    await tester.pumpAndSettle();
    expect(centred(tester), 'save');

    await tap(tester, 'action-save');
    expect(files.done, ['pack', 'saveAs candra-test.zip']);
    await letToastGo(tester);
  });

  testWidgets('is laid out in the four parts', (tester) async {
    await pump(tester, FakeFiles());
    final manifest = tester.getRect(key('journal-manifest'));
    final line = tester.getRect(key('panel-separator'));
    final strip = tester.getRect(key('action-strip'));
    final bar = tester.getRect(find.byType(RoomBar));
    expect(
      tester.getRect(find.text('Export and import')).bottom,
      lessThan(manifest.top),
    );
    expect(manifest.bottom, lessThan(line.top));
    expect(line.bottom, lessThanOrEqualTo(strip.top));
    expect(strip.bottom, lessThanOrEqualTo(bar.top));
  });

  testWidgets('share packs the journal and opens the share sheet', (
    tester,
  ) async {
    final files = FakeFiles();
    await pump(tester, files);
    await run(tester, 'share');

    expect(files.done, ['pack', 'share candra-test.zip']);
  });

  testWidgets('save says so when the copy is saved, and nothing when backed '
      'out of', (tester) async {
    final files = FakeFiles();
    await pump(tester, files);
    await run(tester, 'save');
    expect(files.done, ['pack', 'saveAs candra-test.zip']);
    expect(find.text('Copy saved.'), findsOneWidget);
    await letToastGo(tester);

    await pump(tester, FakeFiles(saves: false));
    await run(tester, 'save');
    expect(find.text('Copy saved.'), findsNothing);
  });

  testWidgets('import adds what is in the file and says what it did', (
    tester,
  ) async {
    final store = await pump(
      tester,
      FakeFiles(
        picked: ArchiveContents(
          categories: const [
            JournalCategory(id: 'abc123', name: 'Walks', colorIndex: 5),
          ],
          entries: [
            entry('One'),
            entry('Two', minute: 700, category: 'abc123'),
          ],
          unreadable: 1,
        ),
      ),
    );
    await run(tester, 'import');

    expect(
      find.text('Added 2 entries and 1 category. 1 could not be read.'),
      findsOneWidget,
    );
    expect(store.category('abc123')!.name, 'Walks');
    expect(
      store
          .entriesFor(CivilDate(2030, 1, 1), utcOffset: Duration.zero)
          .map((e) => e.title),
      containsAll(['One', 'Two']),
    );
    // The count at the top follows.
    expect(find.text('6 categories', findRichText: true), findsNothing);
    expect(find.textContaining('in 6 categories'), findsOneWidget);
    await letToastGo(tester);

    // The same file again: nothing new.
    await tap(tester, 'action-import');
    expect(
      find.text(
        'Nothing new in that file. 2 were already here. '
        '1 could not be read.',
      ),
      findsOneWidget,
    );
    await letToastGo(tester);
  });

  testWidgets('a file that is not a journal is turned away', (tester) async {
    final store = await pump(
      tester,
      FakeFiles(pickError: const FormatException('Not a journal file')),
    );
    await run(tester, 'import');

    expect(find.text('That is not a journal file.'), findsOneWidget);
    expect(store.categories, hasLength(5));
    await letToastGo(tester);
  });

  testWidgets('backing out of choosing a file does nothing', (tester) async {
    final files = FakeFiles();
    await pump(tester, files);
    await run(tester, 'import');

    expect(files.done, ['pick']);
    expect(key('action-import').hitTestable(), findsOneWidget);
  });

  testWidgets('speaks Indonesian too', (tester) async {
    await pump(tester, FakeFiles(), language: AppLanguage.id);
    expect(find.text('Ekspor dan impor'), findsOneWidget);
    expect(find.text('Bagikan salinan'), findsOneWidget);
    await choose(tester, 'import');
    expect(find.text('Impor berkas'), findsOneWidget);
  });
}
