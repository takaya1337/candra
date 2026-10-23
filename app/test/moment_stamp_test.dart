import 'dart:convert';
import 'dart:io';

import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_file.dart';
import 'package:candra/journal/geo.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/moment_stamp.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  const wib = Duration(hours: 7);
  const jakarta = (latitude: -6.2, longitude: 106.8);
  // Sunday 18 October 2026, 08:00 WIB.
  final now = DateTime.utc(2026, 10, 18, 1);

  test('the moment in every system, every key always there', () {
    final m = MomentStamp.of(now, utcOffset: wib);
    expect(m.keys.toList(), MomentStamp.keys);
    expect(m['utc'], '2026-10-18T01:00:00Z');
    expect(m['local'], '2026-10-18 08:00:00 +07:00');
    expect(m['weekday'], 'Sunday');
    expect(m['weton'], startsWith('Minggu '));
    expect(m['javanese'], isNotNull);
    expect(m['hijri'], isNotNull);
    expect(m['chinese'], isNotNull);
    expect(m['bazi'], matches(RegExp(r'^\S\S \S\S \S\S \S\S \(')));
    expect(m['mangsa'], startsWith('Kalima, day 6 of'));
    expect(m['moon_phase'], isNotNull);
    expect(m['weekday_planet'], 'Sun');
    // Without a geotag every key of the sky is there, and null.
    expect(m['geotag'], 'off');
    for (final key in MomentStamp.skyKeys) {
      expect(m.containsKey(key), isTrue, reason: key);
      expect(m[key], isNull, reason: key);
    }

    // With one, every key of the sky is read.
    final tagged = MomentStamp.of(now, utcOffset: wib, geotag: jakarta);
    expect(tagged.keys.toList(), MomentStamp.keys);
    expect(tagged['geotag'], 'on');
    // Sunrise near 05:31: 08:00 is the third day hour, Mercury's.
    expect(tagged['planetary_hour'], 'Mercury, day hour 3');
    expect(tagged['sun'], contains('° up'));
    expect(tagged['light'], 'Day');
    expect(tagged['moon'], contains('° up'));
    expect(tagged['planets_up'], isNotNull);

    // A day the calendars cannot read keeps its keys, null.
    final old = MomentStamp.of(DateTime.utc(1700, 1, 1), utcOffset: wib);
    expect(old.keys.toList(), MomentStamp.keys);
    expect(old['javanese'], isNull);
    expect(old['mangsa'], isNull);
  });

  test('a new entry takes the moment it was saved; its file keeps it; an '
      'edit read back from the index keeps it too', () {
    final root = Directory.systemTemp.createTempSync('moment-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = JournalStore(FileJournalStorage.open(root))
      ..stamp = (geotag) => MomentStamp.of(
        now,
        utcOffset: wib,
        geotag: geotag == null
            ? null
            : (latitude: geotag.latitude, longitude: geotag.longitude),
      );
    addTearDown(store.dispose);
    // Not geotagged: the sky's keys written as null, and read back so.
    final saved = store.save(
      Entry(
        id: '',
        date: CivilDate(2026, 10, 18),
        minuteOfDay: 480,
        utcOffset: wib,
        categoryId: store.categories.first.id,
        title: 'Morning',
        content: 'Words.',
      ),
    );
    expect(saved.moment.keys.toList(), MomentStamp.keys);
    expect(saved.moment['planetary_hour'], isNull);
    final text = EntryFile.encode(saved, categoryName: 'Dream');
    expect(text, contains('moment_planetary_hour: null'));
    expect(EntryFile.decode(text)!.moment, saved.moment);

    // Geotagged: the sky read from it.
    final tagged = store.save(
      Entry(
        id: '',
        date: CivilDate(2026, 10, 18),
        minuteOfDay: 481,
        utcOffset: wib,
        categoryId: store.categories.first.id,
        title: 'Tagged',
        content: 'Words.',
        place: GeoTag.rounded(-6.2, 106.8)!,
      ),
    );
    expect(tagged.moment['planetary_hour'], 'Mercury, day hour 3');
    expect(
      EntryFile.encode(tagged, categoryName: 'Dream'),
      contains('moment_planetary_hour: Mercury, day hour 3'),
    );

    // Read back (from the index), changed, saved: the moment stays.
    final read = store
        .entriesFor(CivilDate(2026, 10, 18), utcOffset: wib)
        .firstWhere((e) => e.title == 'Morning');
    expect(read.moment, saved.moment);
    store.save(read.copyWith(title: 'Morning, again'));
    final again = store
        .entriesFor(CivilDate(2026, 10, 18), utcOffset: wib)
        .firstWhere((e) => e.title == 'Morning, again');
    expect(again.title, 'Morning, again');
    expect(again.moment, saved.moment);
  });

  test('a reminder keeps its moment in the file', () {
    final reminder = Reminder(
      id: 'r1',
      title: 'Water',
      start: CivilDate(2026, 10, 18),
      minuteOfDay: 420,
      repeat: Repeat.daily,
      moment: MomentStamp.of(now, utcOffset: wib),
    );
    // Through JSON, nulls and all.
    final back = Reminder.fromJson(
      jsonDecode(jsonEncode(reminder.toJson())) as Map<String, dynamic>,
    )!;
    expect(back.moment, reminder.moment);
    expect(back.moment['weekday'], 'Sunday');
    expect(back.moment.containsKey('sun'), isTrue);
    expect(back.moment['sun'], isNull);
    expect(GeoTag.decimals, greaterThan(0));
  });

  test('the id: the hash of the rest, the same after the file, and two '
      'records of one second still two', () {
    final a = MomentStamp.of(now, utcOffset: wib);
    final b = MomentStamp.of(now, utcOffset: wib);
    expect(a['id'], hasLength(32));
    expect(MomentStamp.intact(a), isTrue);
    expect(a['id'], isNot(b['id']));
    // A record changed is no longer intact.
    expect(MomentStamp.intact({...a, 'weton': 'Senin Legi'}), isFalse);

    final entry = Entry(
      id: '20261018-080000',
      date: CivilDate(2026, 10, 18),
      minuteOfDay: 480,
      utcOffset: wib,
      categoryId: 'abc123',
      title: 'T',
      content: 'C',
      moment: a,
    );
    final back = EntryFile.decode(
      EntryFile.encode(entry, categoryName: 'Dream'),
    )!;
    expect(back.uid, a['id']);
    expect(MomentStamp.intact(back.moment), isTrue);
  });

  test('a new reminder is stamped when first saved, and keeps it', () {
    final store = ReminderStore(utcOffset: wib)
      ..stamp = () => MomentStamp.of(now, utcOffset: wib);
    final saved = store.save(
      Reminder(
        id: '',
        title: 'Water',
        start: CivilDate(2026, 10, 18),
        minuteOfDay: 420,
        repeat: Repeat.daily,
      ),
    );
    expect(saved.moment.keys.toList(), MomentStamp.keys);
    expect(saved.uid, isNotNull);
    expect(saved.moment['sun'], isNull);
    final edited = store.save(saved.copyWith(title: 'Water the chillies'));
    expect(edited.moment, saved.moment);
  });

  test('a moved entry keeps its record and its id; one from before '
      'records is not given one by moving', () {
    final root = Directory.systemTemp.createTempSync('moment-move');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = JournalStore(FileJournalStorage.open(root))
      ..stamp = (_) => MomentStamp.of(now, utcOffset: wib);
    addTearDown(store.dispose);
    final category = store.categories.first.id;
    final saved = store.save(
      Entry(
        id: '',
        date: CivilDate(2026, 10, 18),
        minuteOfDay: 480,
        utcOffset: wib,
        categoryId: category,
        title: 'Moving',
        content: 'Words.',
      ),
    );
    final moved = store.move(saved, CivilDate(2026, 10, 20), 21 * 3600);
    expect(moved.date, CivilDate(2026, 10, 20));
    expect(moved.minuteOfDay, 21 * 60);
    expect(moved.id, isNot(saved.id));
    expect(moved.uid, saved.uid);
    expect(moved.moment, saved.moment);
    expect(store.entriesFor(CivilDate(2026, 10, 18), utcOffset: wib), isEmpty);
    expect(
      store.entriesFor(CivilDate(2026, 10, 20), utcOffset: wib).single.uid,
      saved.uid,
    );

    // An entry from before: moved, still without a record.
    store.stamp = null;
    final old = store.save(
      Entry(
        id: '',
        date: CivilDate(2026, 10, 1),
        minuteOfDay: 600,
        utcOffset: wib,
        categoryId: category,
        title: 'Old',
        content: 'Words.',
      ),
    );
    store.stamp = (_) => MomentStamp.of(now, utcOffset: wib);
    final oldMoved = store.move(old, CivilDate(2026, 10, 2), 600 * 60);
    expect(oldMoved.moment, isEmpty);
  });
}
