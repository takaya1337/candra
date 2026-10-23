import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

Map<String, Object?> _item(String id, String start) => {
  'id': id,
  'title': 'Offering $id',
  'start': start,
  'time': '19:30',
  'repeat': 'daily',
};

void main() {
  late Directory root;
  late File file;

  ReminderStore open() => ReminderStore(
    file: file,
    utcOffset: const Duration(hours: 7),
    now: () => DateTime(2026, 10, 11, 9),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('reminder-robustness');
    file = File('${root.path}/journal/reminders.json')
      ..parent.createSync(recursive: true);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('a day that does not exist is no reminder, not an error', () {
    expect(Reminder.fromJson(_item('a', '2026-02-30')), isNull);
    final list = Reminder.listFrom([
      _item('a', '2026-10-11'),
      _item('b', '2026-02-30'),
      'not a reminder',
      _item('c', '2026-10-12'),
    ]);
    expect([for (final r in list) r.id], ['a', 'c']);
  });

  test('one spoilt reminder costs only itself, and is never saved away', () {
    file.writeAsStringSync(
      jsonEncode([
        _item('a', '2026-10-11'),
        _item('b', '2026-02-30'),
        _item('c', '2026-10-12'),
      ]),
    );
    final store = open();
    expect([for (final r in store.reminders) r.id], ['a', 'c']);
    expect(store.skipped, 1);

    store.delete('a');
    final saved = jsonDecode(file.readAsStringSync()) as List;
    expect(saved, hasLength(2));
    expect([for (final item in saved) (item as Map)['id']], ['c', 'b']);
    expect([for (final r in open().reminders) r.id], ['c']);
  });

  test('a file that cannot be read at all is set aside before a save', () {
    const spoilt = '[{"id": "a", ';
    file.writeAsStringSync(spoilt);
    final store = open();
    expect(store.reminders, isEmpty);
    expect(file.readAsStringSync(), spoilt);

    store.save(
      Reminder(
        id: 'n',
        title: 'New',
        start: CivilDate(2026, 10, 11),
        minuteOfDay: 8 * 60,
        repeat: Repeat.daily,
      ),
    );
    expect(File('${file.path}.bad').readAsStringSync(), spoilt);
    expect([for (final r in open().reminders) r.id], ['n']);
  });

  test('an announcement id is the same in every isolate', () async {
    final here = ReminderStore.announcementId('3fa2c1', 2461325);
    final there = await Isolate.run(
      () => ReminderStore.announcementId('3fa2c1', 2461325),
    );
    expect(there, here);
    expect(ReminderStore.announcementId('3fa2c1', 2461326), isNot(here));
    expect(ReminderStore.announcementId('3fa2c2', 2461325), isNot(here));
    expect(here, inInclusiveRange(16, 0x7fffffff));
  });
}
