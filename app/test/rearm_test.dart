import 'dart:convert';
import 'dart:io';

import 'package:candra/reminders/announcer.dart';
import 'package:candra/reminders/rearm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the background task hands the phone, worked out from the files
/// alone against a fixed clock: the same days the app would hand over,
/// for every kind of repeat, and the same again however often it runs.
void main() {
  // 14 October 2026, eight in the morning: a Rabu Wage.
  DateTime clock() => DateTime(2026, 10, 14, 8);
  final today = CivilDate(2026, 10, 14);
  late Directory root;

  Map<String, Object> reminder(
    String id,
    String repeat, {
    CivilDate? start,
    String time = '20:00',
    bool enabled = true,
  }) {
    final day = start ?? today;
    return {
      'id': id,
      'title': id,
      'start':
          '${day.year}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}',
      'time': time,
      'repeat': repeat,
      'enabled': enabled,
      'category': 'abc123',
    };
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('rearm');
    final journal = Directory('${root.path}/journal')..createSync();
    File('${journal.path}/categories.json').writeAsStringSync(
      jsonEncode([
        {'id': 'abc123', 'name': 'Observance', 'color': 14},
      ]),
    );
    File('${journal.path}/reminders.json').writeAsStringSync(
      jsonEncode([
        reminder('daily', 'daily', time: '09:00'),
        reminder('weekday', 'weekday'),
        reminder('pasaran', 'pasaran'),
        // Today's has already gone by at eight: the next is in 35 days.
        reminder('weton', 'weton', time: '07:00'),
        reminder('month', 'gregorianMonth'),
        reminder('javanese', 'javaneseMonth'),
        reminder('hijri', 'hijriMonth'),
        reminder('chinese', 'chineseMonth'),
        // 26 October 2026 is a full moon.
        reminder('moon', 'moon', start: CivilDate(2026, 10, 26)),
        reminder('off', 'daily', enabled: false),
      ]),
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<List<Announcement>> run([
    Map<String, Object> settings = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(settings);
    return announcementsFor(
      root: root,
      preferences: await SharedPreferences.getInstance(),
      now: clock,
    );
  }

  List<CivilDate> daysOf(List<Announcement> all, String title) => [
    for (final a in all)
      if (a.title == title) CivilDate(a.when.year, a.when.month, a.when.day),
  ];

  test('every kind of repeat gets its next six days, at its time', () async {
    final all = await run();

    expect(daysOf(all, 'daily'), [
      for (var i = 0; i < 6; i++) today.addDays(i),
    ]);
    expect(daysOf(all, 'weekday'), [
      for (var i = 0; i < 6; i++) today.addDays(7 * i),
    ]);
    expect(daysOf(all, 'pasaran'), [
      for (var i = 0; i < 6; i++) today.addDays(5 * i),
    ]);
    expect(daysOf(all, 'weton'), [
      for (var i = 1; i <= 6; i++) today.addDays(35 * i),
    ]);
    for (final day in daysOf(all, 'weton')) {
      expect(Weton.of(day), Weton.of(today));
    }
    expect(daysOf(all, 'month'), [
      for (var i = 0; i < 6; i++)
        CivilDate(2026 + (9 + i) ~/ 12, (9 + i) % 12 + 1, 14),
    ]);
    for (final (name, dayOf) in [
      ('javanese', (CivilDate d) => JavaneseDate.of(d).day),
      ('hijri', (CivilDate d) => HijriDate.of(d).day),
      ('chinese', (CivilDate d) => ChineseDate.of(d).day),
    ]) {
      final days = daysOf(all, name);
      expect(days, hasLength(6), reason: name);
      for (final day in days) {
        expect(dayOf(day), dayOf(today), reason: '$name on $day');
      }
    }
    final moons = daysOf(all, 'moon');
    expect(moons, hasLength(6));
    for (final day in moons) {
      expect(
        Moon.of(day, utcOffset: clock().timeZoneOffset).phase,
        MoonPhase.fullMoon,
      );
    }
    expect(daysOf(all, 'off'), isEmpty);

    // At the minute set, soonest first.
    expect(
      all.where((a) => a.title == 'pasaran').map((a) => a.when.hour).toSet(),
      {20},
    );
    expect(
      all.map((a) => a.when).toList(),
      [...all.map((a) => a.when)]..sort(),
    );
  });

  test('running it again hands over exactly the same', () async {
    String fingerprint(List<Announcement> all) =>
        [for (final a in all) '${a.id} ${a.when} ${a.title} ${a.body}']
            .join('\n');
    final first = await run();
    final second = await run();
    expect(fingerprint(second), fingerprint(first));
    // One id for one reminder on one day, never two.
    expect(first.map((a) => a.id).toSet(), hasLength(first.length));
  });

  test('a practice being timed down still has its end announced', () async {
    final started = clock().subtract(const Duration(minutes: 10));
    final all = await run({
      practiceStartedKey: started.toUtc().millisecondsSinceEpoch,
      practiceCategoryKey: 'abc123',
      practiceLengthKey: 25 * 60,
      languageKey: 'id',
    });
    final end = all.singleWhere((a) => a.id == 1);
    expect(end.when, started.add(const Duration(minutes: 25)));
    expect(end.title, 'Laku selesai');
    expect(end.body, 'Observance');
  });
}
