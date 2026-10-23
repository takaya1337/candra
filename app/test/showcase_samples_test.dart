import 'dart:convert';
import 'dart:io';

import 'package:candra/journal/entry.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/journal/samples.dart';
import 'package:candra/journal/showcase_text.dart';
import 'package:candra/reminders/reminder.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// The showcase (the store screenshots' samples): laid out around any
/// day, every calendrical fact in its text is the engine's for the day
/// the entry lands on, and every word comes from the owner's file.
void main() {
  const offset = Duration(hours: 7);
  final source = File(ShowcaseText.asset).readAsStringSync();

  // The file with every Indonesian text filled as "ID " and the English,
  // to tell the file's words from any typed in the code.
  String filled() {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return jsonEncode({
      for (final MapEntry(:key, :value) in json.entries)
        key: key.startsWith('_')
            ? value
            : {'en': value['en'], 'id': 'ID ${value['en']}'},
    });
  }

  ({
    JournalStore store,
    ReminderStore reminders,
    ShowcaseText text,
    List<Entry> entries,
  })
  write(CivilDate today, ShowcaseText text, {int now = 21 * 60 + 30}) {
    final root = Directory.systemTemp.createTempSync('showcase');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = JournalStore(FileJournalStorage.open(root));
    addTearDown(store.dispose);
    final reminders = ReminderStore(utcOffset: offset);
    Samples.showcase(store, root, offset, today: today, now: now, text: text);
    Samples.showcaseReminders(
      reminders,
      store,
      today: today,
      text: text,
      utcOffset: offset,
    );
    return (
      store: store,
      reminders: reminders,
      text: text,
      entries: store.allEntries(),
    );
  }

  bool isSejit(CivilDate day) {
    final chinese = ChineseDate.of(day);
    return chinese.day == 19 &&
        !chinese.isLeapMonth &&
        [2, 6, 9].contains(chinese.month);
  }

  final days = [
    CivilDate(2026, 10, 12),
    CivilDate(2026, 10, 19),
    CivilDate(2027, 1, 4),
    CivilDate(2027, 2, 6),
    CivilDate(2027, 6, 1),
    CivilDate(2028, 3, 15),
    CivilDate(2031, 8, 30),
  ];

  // Late evening, early morning, mid-day, just after five.
  const nows = [21 * 60 + 30, 6 * 60 + 30, 12 * 60, 5 * 60 + 6];
  for (final (i, today) in days.indexed) {
    final now = nows[i % nows.length];
    final clock = '${now ~/ 60}:${(now % 60).toString().padLeft(2, '0')}';
    test('anchored to $today at $clock, the facts in the text are the '
        'engine\'s', () {
      final made = write(
        today,
        ShowcaseText.parse(source, AppLanguage.en),
        now: now,
      );
      final entries = made.entries;

      // Nothing later than the run, and all of it within the fortnight.
      expect(entries, hasLength(4));
      for (final entry in entries) {
        expect(entry.date.dayNumber, lessThanOrEqualTo(today.dayNumber));
        expect(today.dayNumber - entry.date.dayNumber, lessThanOrEqualTo(14));
        if (entry.date == today) {
          expect(entry.minuteOfDay, lessThan(now));
          expect(entry.minuteOfDay, greaterThanOrEqualTo(5 * 60));
        }
        expect('${entry.title}${entry.content}', isNot(contains('{')));
      }

      // The weton and neptu of the day the sitting landed on.
      final sitting = entries.firstWhere(
        (e) => e.title == 'Morning sitting' && e.content.contains('neptu'),
      );
      final weton = Weton.of(sitting.date);
      expect(sitting.content, contains('$weton, neptu ${weton.neptu}.'));

      // The reminders start on the days their titles name, and each
      // comes round again from today.
      Reminder reminder(String title) =>
          made.reminders.reminders.firstWhere((r) => r.title == title);
      expect(made.reminders.reminders, hasLength(5));
      // Kwan Im's sejit: the next after today, none between.
      final kwanIm = reminder('Sejit Kwan Im');
      expect(isSejit(kwanIm.start), isTrue);
      expect(kwanIm.start.dayNumber, greaterThan(today.dayNumber));
      for (var d = today.addDays(1); d != kwanIm.start; d = d.addDays(1)) {
        expect(isSejit(d), isFalse, reason: '$d comes first');
      }
      expect(kwanIm.repeat, Repeat.chineseYear);
      final sura = JavaneseDate.of(
        reminder('Malam 1 Suro: bathe the keris').start,
      );
      expect((sura.month, sura.day), (JavaneseMonth.sura, 1));
      final imlek = ChineseDate.of(reminder('Imlek').start);
      expect((imlek.month, imlek.day, imlek.isLeapMonth), (1, 1, false));
      final fullMoon = reminder('Full moon sitting');
      expect(
        Moon.of(fullMoon.start, utcOffset: offset).phase,
        MoonPhase.fullMoon,
      );
      for (final r in made.reminders.reminders) {
        expect(r.occurrences(today, utcOffset: offset), isNotEmpty);
      }
    });
  }

  test('anchored to 12 October 2026, the occasions fall where they were '
      'cross-checked by hand', () {
    final today = CivilDate(2026, 10, 12);
    final made = write(today, ShowcaseText.parse(source, AppLanguage.en));
    expect(
      made.entries
          .firstWhere((e) => e.title == 'Morning sitting' && e.date == today)
          .content,
      contains('Senin Pahing, neptu 13.'),
    );
    CivilDate starts(String title) =>
        made.reminders.reminders.firstWhere((r) => r.title == title).start;
    expect(starts('Sejit Kwan Im'), CivilDate(2026, 10, 28));
    expect(starts('Malam 1 Suro: bathe the keris'), CivilDate(2026, 6, 17));
    expect(starts('Imlek'), CivilDate(2026, 2, 17));
    expect(starts('Full moon sitting'), CivilDate(2026, 10, 26));
  });

  // Today's two: where each landed, as (day, "hh:mm").
  Map<String, (CivilDate, String)> todays(List<Entry> entries) {
    String clock(Entry e) =>
        '${(e.minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
        '${(e.minuteOfDay % 60).toString().padLeft(2, '0')}';
    final basil = entries.firstWhere((e) => e.title == 'Basil, week three');
    final sitting = entries.firstWhere(
      (e) => e.title == 'Morning sitting' && e.content.contains('neptu'),
    );
    return {
      'Morning sitting': (sitting.date, clock(sitting)),
      'Basil, week three': (basil.date, clock(basil)),
    };
  }

  test('run after the morning, today\'s entries keep their own times', () {
    final today = CivilDate(2026, 10, 12);
    for (final now in [12 * 60, 21 * 60 + 30]) {
      final made = write(
        today,
        ShowcaseText.parse(source, AppLanguage.en),
        now: now,
      );
      expect(todays(made.entries), {
        'Morning sitting': (today, '05:10'),
        'Basil, week three': (today, '07:15'),
      }, reason: 'run at $now');
    }
  });

  for (final (now, basil) in [
    (7 * 60, '06:55'),
    (6 * 60 + 30, '06:25'),
    (5 * 60 + 6, '05:01'),
  ]) {
    test('run at ${now ~/ 60}:${(now % 60).toString().padLeft(2, '0')}, '
        'today\'s entries move earlier, keeping their spacing, and the one '
        'that would fall before five is yesterday\'s', () {
      final today = CivilDate(2026, 10, 12);
      final made = write(
        today,
        ShowcaseText.parse(source, AppLanguage.en),
        now: now,
      );
      final yesterday = today.addDays(-1);
      expect(todays(made.entries), {
        'Morning sitting': (yesterday, '05:10'),
        'Basil, week three': (today, basil),
      });
      // Yesterday's weton, for the sitting that moved there.
      expect(
        made.entries
            .firstWhere(
              (e) =>
                  e.title == 'Morning sitting' && e.content.contains('neptu'),
            )
            .content,
        contains('Minggu Legi, neptu 10.'),
      );
      for (final e in made.entries.where((e) => e.date == today)) {
        expect(e.minuteOfDay, lessThan(now));
      }
    });
  }

  test('every showcase word comes from the file, and every key in the file '
      'is used', () {
    final text = ShowcaseText.parse(filled(), AppLanguage.id);
    final made = write(CivilDate(2027, 3, 9), text);

    // The manual's words (manual.*) and the iPhone's permission prompts
    // (ios.*) live in the same file for the owner to write, and are not
    // the samples'.
    expect(
      text.asked,
      text.keys
          .where((key) => !key.startsWith('manual.') && !key.startsWith('ios.'))
          .toSet(),
    );
    for (final entry in made.entries) {
      if (entry.title.isNotEmpty) expect(entry.title, startsWith('ID '));
      if (entry.content.isNotEmpty) expect(entry.content, startsWith('ID '));
      if (entry.place != null) expect(entry.place!.name, startsWith('ID '));
    }
    for (final reminder in made.reminders.reminders) {
      expect(reminder.title, startsWith('ID '));
    }
    // The starting categories, renamed into the language.
    for (final category in made.store.categories) {
      expect(category.name, startsWith('ID '));
    }
  });

  test('the file is well formed, and an empty Indonesian text falls back '
      'to the English and is named as missing', () {
    final json = jsonDecode(source) as Map<String, dynamic>;
    expect(json['_note'], isA<String>());
    final text = ShowcaseText.parse(source, AppLanguage.id);
    final empty = [
      for (final MapEntry(:key, :value) in json.entries)
        if (!key.startsWith('_') && (value['id'] as String).trim().isEmpty) key,
    ];
    expect(text.missing, empty);
    if (empty.isNotEmpty) {
      expect(text(empty.first), json[empty.first]['en']);
    }
    expect(ShowcaseText.parse(filled(), AppLanguage.id).missing, isEmpty);
    expect(
      () => ShowcaseText.parse('{"a": {"en": "x"}}', AppLanguage.en),
      throwsFormatException,
    );
  });
}
