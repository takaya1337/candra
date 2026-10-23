import 'package:candra/app_shell.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// An entry open in the editor while a sync brings a change to it: saving
/// keeps both, never writing the editor's words over what the sync
/// brought (the audit of 23 October 2026, 1.4).
void main() {
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 11);
  Finder key(String name) => find.byKey(ValueKey(name));
  Finder field(String name) =>
      find.descendant(of: key(name), matching: find.byType(EditableText));

  Future<(JournalStore, Entry)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    final store = JournalStore();
    final kept = store.save(
      Entry(
        id: '',
        date: day,
        minuteOfDay: 600,
        utcOffset: offset,
        categoryId: store.categories.first.id,
        title: 'Offering',
        content: 'Words.',
      ),
    );
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        journal: store,
        home: EntryScreen(
          date: day,
          utcOffset: offset,
          entry: kept,
          categoryId: kept.categoryId,
          minuteOfDay: 600,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (store, kept);
  }

  testWidgets('an edit saved over a change a sync made keeps both', (
    tester,
  ) async {
    final (store, kept) = await pump(tester);
    await tester.tap(key('entry-edit'));
    await tester.pumpAndSettle();
    await tester.enterText(field('entry-title'), 'Mine');
    await tester.pumpAndSettle();

    // Meanwhile the sync writes the other phone's words into the entry.
    store.save(kept.copyWith(title: 'Theirs'), previous: kept);

    await tester.tap(key('entry-save'));
    await tester.pumpAndSettle();
    // (The journal in memory comes with entries of its own.)
    final titles = store
        .entriesFor(day, utcOffset: offset)
        .map((e) => e.title)
        .where(const {'Offering', 'Theirs', 'Mine'}.contains)
        .toList();
    expect(titles, unorderedEquals(['Theirs', 'Mine']));
    expect(find.textContaining('kept beside it'), findsOneWidget);
  });

  testWidgets('an edit with nothing changed underneath saves in place', (
    tester,
  ) async {
    final (store, _) = await pump(tester);
    await tester.tap(key('entry-edit'));
    await tester.pumpAndSettle();
    await tester.enterText(field('entry-title'), 'Mine');
    await tester.pumpAndSettle();
    await tester.tap(key('entry-save'));
    await tester.pumpAndSettle();
    expect(
      store
          .entriesFor(day, utcOffset: offset)
          .map((e) => e.title)
          .where(const {'Offering', 'Mine'}.contains),
      ['Mine'],
    );
  });
}
