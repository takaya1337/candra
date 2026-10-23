import 'dart:io';

import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/journal/samples.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/search/query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// The search samples: what they write is what the search can be asked
/// of, the feasts fall where the calendars put them, and removing them
/// leaves the journal as it was.
void main() {
  const offset = Duration(hours: 7);

  test('the search samples are written, found by their cycles and tags, '
      'and taken out again', () {
    final root = Directory.systemTemp.createTempSync('search-samples');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = JournalStore(FileJournalStorage.open(root));
    addTearDown(store.dispose);
    final reminders = ReminderStore(utcOffset: offset);
    final before = store.allEntries().length;

    Samples.search(store, reminders, root, offset);
    final all = store.allEntries();
    String tag(String name) => store.tags.firstWhere((t) => t.name == name).id;
    List<String> titles(SearchQuery query) => [
      for (final hit in query.searchEntries(store)) hit.entry!.title,
    ];

    // Every Kliwon sitting is on a Kliwon, and the sittings are all of
    // the entries on Kliwon tagged sitting.
    final kliwon = const SearchQuery().toggleCycle(
      CycleKind.pasaran,
      Pasaran.kliwon.index,
    );
    final sittings = titles(kliwon.copyWith(tags: {tag('sitting')}));
    expect(sittings.length, greaterThan(50));
    expect(sittings.toSet(), {'Kliwon sitting'});

    // Thursday evenings: on Friday once the day turns at 18:00, only
    // those at or after six.
    final jumat = const SearchQuery()
        .toggleCycle(CycleKind.weekday, Weekday.jumat.index)
        .copyWith(tags: {tag('offering')}, evening: Evening.six);
    final evenings = jumat.searchEntries(store);
    expect(evenings, isNotEmpty);
    for (final hit in evenings) {
      expect(Weekday.of(hit.date), Weekday.kamis);
      expect(hit.entry!.minuteOfDay, greaterThanOrEqualTo(18 * 60));
    }

    // The feasts, where the calendars put them in 2026.
    String? on(CivilDate date, String title) =>
        all.where((e) => e.date == date && e.title == title).firstOrNull?.title;
    expect(on(CivilDate(2026, 2, 17), 'Imlek'), 'Imlek');
    expect(on(CivilDate(2026, 3, 3), 'Cap Go Meh'), 'Cap Go Meh');

    // Tags all of: chilli and basil together is fewer than chilli.
    final chilli = titles(SearchQuery(tags: {tag('chilli')}));
    final both = titles(SearchQuery(tags: {tag('chilli'), tag('basil')}));
    expect(both, isNotEmpty);
    expect(both.length, lessThan(chilli.length));
    expect(both.toSet(), {'Chillies and basil'});

    // Words.
    expect(titles(const SearchQuery(words: 'aphids')), isNotEmpty);

    // Reminders: ten on, one off.
    expect(reminders.reminders, hasLength(11));
    final found = const SearchQuery(
      entries: false,
      reminders: true,
    ).searchReminders(reminders, from: CivilDate(2026, 10, 15));
    expect(found, hasLength(10));

    Samples.removeSearch(store, reminders, root, offset);
    expect(store.allEntries(), hasLength(before));
    expect(reminders.reminders, isEmpty);
    expect(store.tags, isEmpty);
  });
}
