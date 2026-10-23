import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sacred_time/sacred_time.dart';

import '../reminders/reminder.dart';
import '../reminders/reminder_store.dart';
import 'entry.dart';
import 'geo.dart';
import 'journal_store.dart';
import 'showcase_text.dart';

/// Sample entries for looking at the app with something in it.
///
/// Only a build made with `--dart-define=SAMPLES=seed` writes them, once;
/// one made with `--dart-define=SAMPLES=remove` takes out exactly what was
/// written and nothing else. What was written is noted in `samples.json`
/// beside the journal.
///
/// The samples sit in and around October 2026 and are chosen for the odd
/// cases: days with one to thirteen categories, a category with fourteen
/// entries in a day, months with none, eight and more than eight
/// categories, days outside the month on screen, and entries with long,
/// short and missing text.
abstract final class Samples {
  // A screenshots build (`SHOTS`) writes the showcase by itself.
  static const mode = String.fromEnvironment('SHOTS') != ''
      ? 'showcase'
      : String.fromEnvironment('SAMPLES');

  static const _extraCategories = [
    'Fasting',
    'Offering',
    'Pilgrimage',
    'Reading',
    'Weather',
    'Health',
    'Garden',
    'Family',
    'Work',
  ];

  static File _note(Directory root) => File('${root.path}/samples.json');

  /// Does what [mode] asks, if anything. The showcase is laid out around
  /// [today] in [showcaseText]'s words, and needs both.
  static void apply(
    JournalStore store,
    Directory root,
    Duration utcOffset, {
    CivilDate? today,
    int? now,
    ShowcaseText? showcaseText,
  }) {
    if (mode == 'showcase' && !_note(root).existsSync()) {
      if (today == null || now == null || showcaseText == null) return;
      showcase(
        store,
        root,
        utcOffset,
        today: today,
        now: now,
        text: showcaseText,
      );
    } else if (mode == 'seed' && !_note(root).existsSync()) {
      seed(store, root, utcOffset);
    } else if (mode == 'remove' && _note(root).existsSync()) {
      remove(store, root, utcOffset);
    }
  }

  static void seed(JournalStore store, Directory root, Duration utcOffset) {
    final madeCategories = <String>[];
    for (final name in _extraCategories) {
      if (store.categories.any((c) => c.name == name)) continue;
      final made = store.addCategory(name);
      if (made != null) madeCategories.add(made.id);
    }
    final categories = store.categories;
    final written = <String>[];

    // An entry in the [category]th category, counting from the top.
    void add(
      CivilDate date,
      int category,
      int hour,
      int minute, {
      String? title,
      String? content,
      int second = 0,
    }) {
      final into = categories[category % categories.length];
      final saved = store.save(
        Entry(
          id: '',
          date: date,
          minuteOfDay: hour * 60 + minute,
          second: second,
          utcOffset: utcOffset,
          categoryId: into.id,
          title: title ?? '${into.name} at ${_two(hour)}:${_two(minute)}',
          content:
              content ??
              'Sample entry in ${into.name}, written to see how the '
                  'calendar and the cards look with something in them.',
        ),
      );
      written.add(saved.id);
    }

    CivilDate october(int day) => CivilDate(2026, 10, day);

    // One to six categories in a day: four dots is the most a cell shows.
    for (var count = 1; count <= 5; count++) {
      for (var i = 0; i < count; i++) {
        add(october(count), i, 7 + i * 2, 15);
      }
    }
    // Six categories, written latest-first down the list, so the four
    // dots shown are the bottom four categories and not the top four.
    for (var i = 0; i < 6; i++) {
      add(october(6), i, 20 - i * 3, 0);
    }
    // One category, fourteen entries: one dot, a card that scrolls, and
    // more entries than the entry picker shows at once.
    for (var i = 0; i < 14; i++) {
      add(october(7), 0, 6 + i, 10, title: 'Entry ${i + 1} of fourteen');
    }
    // Thirteen categories in a day: more than the category picker shows
    // at once, and far more than a cell.
    for (var i = 0; i < 13; i++) {
      add(october(8), i, 5 + i, 30);
    }
    // Text of every length.
    add(
      october(9),
      1,
      6,
      0,
      title:
          'A very long title that goes on well past the width of a card '
          'to show where it is cut and how it wraps when read',
      content: 'Short.',
    );
    add(october(9), 1, 9, 0, title: '', content: 'No title, only text.');
    add(october(9), 1, 12, 0, title: 'Only a title', content: '');
    add(
      october(9),
      2,
      21,
      45,
      title: 'Several paragraphs',
      content: [
        for (var i = 1; i <= 8; i++)
          'Paragraph $i. A longer piece of writing, so the card has to cut '
              'it after three lines and the entry screen has to scroll. '
              'Nothing here means anything; it is only here to take up '
              'room the way a real entry would.',
      ].join('\n\n'),
    );
    add(
      october(9),
      3,
      23,
      0,
      title: 'Markdown-looking text',
      content: '# Not a heading\n---\n- a list\n- of things\n\n> a quote',
    );
    // The first and the last second of a day, and two entries asking for
    // the same second.
    add(october(10), 2, 0, 0, title: 'First second of the day');
    add(october(10), 3, 23, 59, second: 59, title: 'Last second of the day');
    add(october(10), 4, 12, 0, title: 'Asked for 12:00:00');
    add(october(10), 4, 12, 0, title: 'Also asked for 12:00:00');
    // Today, and a week of one category a day.
    add(october(11), 0, 8, 0);
    add(october(11), 4, 19, 30);
    for (var i = 0; i < 7; i++) {
      add(october(12 + i), i, 10, 0);
    }
    for (var i = 0; i < 4; i++) {
      add(october(31), 6 + i, 9 + i, 0);
    }
    // Days of the neighbouring months that show, faint, in October.
    add(CivilDate(2026, 9, 28), 0, 9, 0);
    add(CivilDate(2026, 9, 29), 1, 9, 0);
    add(CivilDate(2026, 9, 29), 2, 10, 0);
    for (var i = 0; i < 4; i++) {
      add(CivilDate(2026, 9, 30), i, 9 + i, 0);
    }
    for (var i = 0; i < 3; i++) {
      add(CivilDate(2026, 11, 1), 5 + i, 9 + i, 0);
    }
    add(CivilDate(2026, 11, 5), 9, 9, 0);
    for (var i = 0; i < 5; i++) {
      add(CivilDate(2026, 11, 8), i, 9 + i, 0);
    }
    // The year: months with one, two, four, exactly eight, nine and every
    // category; February and August with none.
    void month(int month, int count, {int from = 0}) {
      for (var i = 0; i < count; i++) {
        add(CivilDate(2026, month, 2 + i * 2), from + i, 8, 0);
      }
    }

    month(1, 1, from: 4);
    month(3, 2, from: 6);
    month(4, 4, from: 2);
    month(5, 8);
    month(6, 9);
    month(7, categories.length);
    add(CivilDate(2026, 12, 31), 3, 23, 30, title: 'Last evening of the year');
    // The years either side.
    add(CivilDate(2025, 12, 31), 1, 22, 0);
    add(CivilDate(2027, 1, 1), 2, 6, 0);

    _note(root).writeAsStringSync(
      jsonEncode({'categories': madeCategories, 'entries': written}),
    );
  }

  /// A small, tidy journal for the store's screenshots, laid out around
  /// [today], the day it is written (the day the screenshots are taken,
  /// so the app agrees with the phone's own status bar), and [now], the
  /// minute of the day it is written, which no entry is later than: this
  /// morning's sitting and the basil, the jasmine repotted five days
  /// before, and a sitting a fortnight back. The rest of the fortnight
  /// and the months before went on 22 October 2026 (owner: they read too
  /// contrived); the occasions people keep (Kwan Im's sejit, malam satu
  /// Suro, Imlek) are the showcase's reminders. Every calendrical fact in
  /// the text is worked out for the day it lands on, never typed. The
  /// words are [text]'s, in its language.
  ///
  /// Written only by a build made with `--dart-define=SAMPLES=showcase`
  /// or `SHOTS`, which is meant for the separate screenshot copy of the
  /// app and never for a real journal.
  static void showcase(
    JournalStore store,
    Directory root,
    Duration utcOffset, {
    required CivilDate today,
    required int now,
    required ShowcaseText text,
  }) {
    final madeCategories = <String>[];
    final written = <String>[];

    void add(
      CivilDate date,
      String category,
      int hour,
      int minute,
      String title,
      String content, {
      GeoTag? place,
    }) => written.add(
      store
          .save(
            Entry(
              id: '',
              date: date,
              minuteOfDay: hour * 60 + minute,
              utcOffset: utcOffset,
              categoryId: _showcaseCategory(
                store,
                text,
                category,
                madeCategories,
              ),
              title: title,
              content: content,
              place: place,
            ),
          )
          .id,
    );

    CivilDate ago(int days) => today.addDays(-days);

    // Every starting category named in the showcase's language, those
    // with no entry too, so no folder keeps its English name.
    for (final english in _showcaseCategories.keys) {
      _showcaseCategory(store, text, english, madeCategories);
    }

    // Today's two, never later than the run: in their order and
    // spacing, moved earlier (never later, so the sitting stays before
    // sunrise) until the last is five minutes before [now]. One that
    // would then fall before 05:00 is yesterday's instead, at its own
    // time. What its text says is worked out for the day it lands on.
    const last = 7 * 60 + 15;
    final shift = min(0, now - 5 - last);
    (CivilDate, int, int) at(int hour, int minute) {
      final moved = hour * 60 + minute + shift;
      return moved >= 5 * 60
          ? (today, moved ~/ 60, moved % 60)
          : (today.addDays(-1), hour, minute);
    }

    void addAt(
      (CivilDate, int, int) when,
      String category,
      String title,
      String content,
    ) => add(when.$1, category, when.$2, when.$3, title, content);

    final sitting = at(5, 10);
    final weton = Weton.of(sitting.$1);
    addAt(
      sitting,
      'Observance',
      text('entry.morningSitting.title'),
      text('entry.morningSitting.body', {
        'weton': '$weton',
        'neptu': weton.neptu,
      }),
    );
    addAt(
      at(7, 15),
      'Plant log',
      text('entry.basilWeekThree.title'),
      text('entry.basilWeekThree.body'),
    );
    // The fortnight before (owner, 22 October 2026: the other entries
    // read too contrived, and went; the occasions stay as reminders).
    add(
      ago(5),
      'Plant log',
      6,
      50,
      text('entry.jasmine.title'),
      text('entry.jasmine.body'),
    );
    add(ago(14), 'Observance', 5, 30, text('entry.morningSitting.title'), '');

    _note(root).writeAsStringSync(
      jsonEncode({'categories': madeCategories, 'entries': written}),
    );
  }

  /// Writes [showcaseReminders] once, in a build that asked for the
  /// showcase, beside it.
  static void applyShowcaseReminders(
    ReminderStore reminders,
    JournalStore store, {
    required CivilDate today,
    required ShowcaseText? text,
    required Duration utcOffset,
  }) {
    if (mode != 'showcase' || text == null || reminders.reminders.isNotEmpty) {
      return;
    }
    showcaseReminders(
      reminders,
      store,
      today: today,
      text: text,
      utcOffset: utcOffset,
    );
  }

  /// The reminders that go with [showcase]: one for every way a reminder
  /// can come round that is worth showing, each starting on a day that
  /// is truly what its title says, found from [today].
  static void showcaseReminders(
    ReminderStore reminders,
    JournalStore store, {
    required CivilDate today,
    required ShowcaseText text,
    required Duration utcOffset,
  }) {
    void add(
      String title,
      String category,
      CivilDate start,
      int hour,
      int minute,
      Repeat repeat,
    ) => reminders.save(
      Reminder(
        id: '',
        title: title,
        start: start,
        minuteOfDay: hour * 60 + minute,
        repeat: repeat,
        categoryId: _showcaseCategory(store, text, category, null),
      ),
    );

    // The next of Kwan Im's three sejit; the last 1 Sura, the Javanese new year, whose
    // night is when the keris is bathed; the last Imlek; the next full
    // moon.
    add(
      text('reminder.sejit'),
      'Occasion',
      nextKwanImSejit(today),
      7,
      0,
      Repeat.chineseYear,
    );
    add(
      text('reminder.suro'),
      'Occasion',
      lastMalamSuro(today).addDays(1),
      0,
      0,
      Repeat.javaneseYear,
    );
    add(
      text('reminder.imlek'),
      'Occasion',
      lastImlek(today),
      8,
      0,
      Repeat.chineseYear,
    );
    add(
      text('reminder.fullMoon'),
      'Observance',
      nextFullMoon(today, utcOffset),
      20,
      0,
      Repeat.moon,
    );
    add(
      text('reminder.eveningOffering'),
      'Observance',
      today,
      18,
      0,
      Repeat.pasaran,
    );
  }

  static const _showcaseCategories = {
    'Occasion': 'category.occasion',
    'Observance': 'category.observance',
    'Dream': 'category.dream',
    'Divination': 'category.divination',
    'Plant log': 'category.plantLog',
  };

  // The id of the starting category named [english], under its name in
  // [text]'s language: renamed if it is there under the English, made
  // (and noted in [made]) if it is not there at all.
  static String _showcaseCategory(
    JournalStore store,
    ShowcaseText text,
    String english,
    List<String>? made,
  ) {
    final name = text(_showcaseCategories[english]!);
    final found =
        store.categories.where((c) => c.name == name).firstOrNull ??
        store.categories.where((c) => c.name == english).firstOrNull;
    if (found == null) {
      final added = store.addCategory(name) ?? store.categories.first;
      if (added.name == name) made?.add(added.id);
      return added.id;
    }
    if (found.name != name) store.renameCategory(found.id, name);
    return found.id;
  }

  // The nearest day from [from], stepping by [step], that [test] holds
  // for. The occasions looked for come round within two years.
  static CivilDate _seek(
    CivilDate from,
    int step,
    bool Function(CivilDate day) test,
  ) {
    var day = from;
    for (var i = 0; i < 800; i++, day = day.addDays(step)) {
      if (test(day)) return day;
    }
    throw StateError('no such day within 800 days of $from');
  }

  /// Whether [day] is one of Kwan Im's three sejit: the 19th of the
  /// second, sixth or ninth Chinese month (not a leap one).
  static bool isKwanImSejit(CivilDate day) {
    if (!ChineseDate.supports(day)) return false;
    final chinese = ChineseDate.of(day);
    return chinese.day == 19 &&
        !chinese.isLeapMonth &&
        const {2, 6, 9}.contains(chinese.month);
  }

  /// Kwan Im's next sejit after [today].
  static CivilDate nextKwanImSejit(CivilDate today) =>
      _seek(today.addDays(1), 1, isKwanImSejit);

  /// Kwan Im's last sejit before [today].
  static CivilDate lastKwanImSejit(CivilDate today) =>
      _seek(today.addDays(-1), -1, isKwanImSejit);

  /// The last malam satu Suro before [today]: the eve of 1 Sura.
  static CivilDate lastMalamSuro(CivilDate today) =>
      _seek(today.addDays(-1), -1, (eve) {
        final day = eve.addDays(1);
        if (!JavaneseDate.supports(day)) return false;
        final javanese = JavaneseDate.of(day);
        return javanese.month == JavaneseMonth.sura && javanese.day == 1;
      });

  /// The last first day of the Chinese year on or before [today].
  static CivilDate lastImlek(CivilDate today) => _seek(today, -1, (day) {
    if (!ChineseDate.supports(day)) return false;
    final chinese = ChineseDate.of(day);
    return chinese.month == 1 && chinese.day == 1 && !chinese.isLeapMonth;
  });

  /// The next day of full moon on or after [today].
  static CivilDate nextFullMoon(CivilDate today, Duration utcOffset) => _seek(
    today,
    1,
    (day) => Moon.of(day, utcOffset: utcOffset).phase == MoonPhase.fullMoon,
  );

  static File _searchNote(Directory root) =>
      File('${root.path}/samples-search.json');

  /// Does what [mode] asks of the search samples, if anything: `search`
  /// writes them once, `remove` takes out exactly them.
  static void applySearch(
    JournalStore store,
    ReminderStore reminders,
    Directory root,
    Duration utcOffset,
  ) {
    if (mode == 'search' && !_searchNote(root).existsSync()) {
      search(store, reminders, root, utcOffset);
    } else if (mode == 'remove' && _searchNote(root).existsSync()) {
      removeSearch(store, reminders, root, utcOffset);
    }
  }

  /// A year of a practising household's journal, January to 14 October
  /// 2026, for asking the search everything it can be asked: habits that
  /// fall on a cycle (a sitting every Kliwon, an offering every Thursday
  /// evening, the Monday and Thursday fasts, a card at every full moon),
  /// so each draws its own pattern on the year; the feasts found by the
  /// calendars themselves, not typed in; evening entries either side of
  /// sunset and of 18:00; tags alone and together; and words to find.
  /// With tagged reminders for every kind of coming round.
  ///
  /// Written only by a build made with `--dart-define=SAMPLES=search`,
  /// noted in `samples-search.json`, and taken out again by
  /// `--dart-define=SAMPLES=remove`.
  static void search(
    JournalStore store,
    ReminderStore reminders,
    Directory root,
    Duration utcOffset,
  ) {
    String category(String name) =>
        (store.categories.where((c) => c.name == name).firstOrNull ??
                store.categories.first)
            .id;
    final madeTags = <String>[];
    String tag(String name) {
      final before = store.tags.length;
      final made = store.addTag(name)!;
      if (store.tags.length > before) madeTags.add(made.id);
      return made.id;
    }

    final sitting = tag('sitting');
    final offering = tag('offering');
    final fasting = tag('fasting');
    final tarot = tag('tarot');
    final chilli = tag('chilli');
    final basil = tag('basil');
    final family = tag('family');
    final klenteng = tag('klenteng');
    final keris = tag('keris');
    final rain = tag('rain');

    final written = <String>[];
    void add(
      CivilDate date,
      String into,
      int hour,
      int minute,
      String title,
      String content, {
      List<String> tags = const [],
    }) => written.add(
      store
          .save(
            Entry(
              id: '',
              date: date,
              minuteOfDay: hour * 60 + minute,
              utcOffset: utcOffset,
              categoryId: category(into),
              title: title,
              content: content,
              tags: tags,
            ),
          )
          .id,
    );

    final first = CivilDate(2026, 1, 1);
    final last = CivilDate(2026, 10, 14);
    var n = 0;
    for (
      var day = first;
      day.dayNumber <= last.dayNumber;
      day = day.addDays(1), n++
    ) {
      final weekday = Weekday.of(day);
      final pasaran = Pasaran.of(day);
      final moon = Moon.of(day, utcOffset: utcOffset).phase;
      final yesterday = Moon.of(day.addDays(-1), utcOffset: utcOffset).phase;

      // A sitting before dawn on every Kliwon: diagonals on the year.
      if (pasaran == Pasaran.kliwon) {
        add(
          day,
          'Observance',
          4,
          50 + n % 9,
          'Kliwon sitting',
          n % 3 == 0
              ? 'Sat until the first birds. Breath steady, mind wandering '
                    'to the garden twice.'
              : 'Forty minutes before Subuh. Quiet house.',
          tags: [sitting],
        );
      }
      // The offering on Thursday evening, which is already malam Jumat
      // to anyone who turns the day at sunset; some just before 18:00,
      // some just after, so sunset and 18:00 can be told apart.
      if (weekday == Weekday.kamis) {
        final minute = switch (n % 4) {
          0 => 17 * 60 + 52,
          1 => 18 * 60 + 5,
          2 => 18 * 60 + 40,
          _ => 19 * 60 + 30,
        };
        add(
          day,
          'Observance',
          minute ~/ 60,
          minute % 60,
          pasaran == Pasaran.kliwon
              ? 'Malam Jumat Kliwon offering'
              : 'Thursday evening offering',
          pasaran == Pasaran.kliwon
              ? 'Kembang setaman, incense, and the lamp left burning till '
                    'late. The neighbours did the same.'
              : 'Three flowers, incense, a little rice on the shelf.',
          tags: [offering],
        );
      }
      // Monday and Thursday fasts, from February to May.
      if ((weekday == Weekday.senin || weekday == Weekday.kamis) &&
          day.month >= 2 &&
          day.month <= 5) {
        add(
          day,
          'Observance',
          18,
          n % 2 == 0 ? 2 : 12,
          'Broke the fast',
          'Water and three dates, then rice. ${n % 5 == 0 ? 'Headache by noon, gone by Asar.' : 'An easy day.'}',
          tags: [fasting],
        );
      }
      // One card on the first day of every full moon.
      if (moon == MoonPhase.fullMoon && yesterday != MoonPhase.fullMoon) {
        add(
          day,
          'Divination',
          21,
          15,
          'Full moon card',
          const [
            'The Star, upright. Patience; what was planted will come.',
            'The Tower, reversed. Something avoided, for now.',
            'Three of Cups. Company, and a table full.',
            'The Hermit. Fewer words this month.',
            'Wheel of Fortune. Turning, whether asked or not.',
          ][n % 5],
          tags: [tarot],
        );
      }
      // The chillies every fourth day from March, the basil every
      // Sunday, and now and then both in one entry.
      if (day.month >= 3 && n % 4 == 0) {
        final both = n % 12 == 0;
        add(
          day,
          'Plant log',
          6,
          45,
          both ? 'Chillies and basil' : 'Chillies',
          [
            if (n % 8 == 0) 'Aphids under the leaves again; washed them off.',
            if (n % 8 != 0) 'Watered the three pots, about a glass each.',
            if (both) 'Pinched the basil flowers off before they set.',
            if (day.month >= 7) 'Fruit turning red on the big plant.',
          ].join(' '),
          tags: [chilli, if (both) basil],
        );
      }
      if (weekday == Weekday.minggu && day.month >= 4 && n % 12 != 0) {
        add(
          day,
          'Plant log',
          7,
          30,
          'Basil',
          'Cut a handful for the soup. ${day.month >= 8 ? 'Going woody now.' : 'Still soft.'}',
          tags: [basil],
        );
      }
      // Rain days in the wet months, an odd dream now and then.
      if (day.month <= 3 && n % 6 == 1) {
        add(
          day,
          'Dream',
          4,
          10,
          'Rain on a tin roof',
          'Dreamt of the river behind the old house rising to the steps. '
              'Woke to real rain.',
          tags: [rain],
        );
      }
      if (n % 23 == 5) {
        add(
          day,
          'Dream',
          5,
          20,
          const ['The old house', 'Flying, low', 'A letter'][n % 3],
          const [
            'The house I grew up in, with a room that was never there. '
                'My grandmother was in it, sorting rice.',
            'Low over the sawah, the way a heron goes.',
            'Someone handed me a letter in a script I could almost read.',
          ][n % 3],
          tags: [if (n % 3 == 0) family],
        );
      }

      // The feasts, found by the calendars rather than typed in.
      if (ChineseDate.supports(day)) {
        final chinese = ChineseDate.of(day);
        if (chinese.month == 1 && chinese.day == 1 && !chinese.isLeapMonth) {
          add(
            day,
            'Occasion',
            9,
            0,
            'Imlek',
            'To the klenteng first, then the whole family at Ma\'s. Angpao '
                'for the little ones.',
            tags: [klenteng, family],
          );
        }
        if (chinese.month == 1 && chinese.day == 15 && !chinese.isLeapMonth) {
          add(
            day,
            'Occasion',
            19,
            0,
            'Cap Go Meh',
            'Lontong Cap Go Meh at home, then out to see the lanterns.',
            tags: [family],
          );
        }
        if (chinese.day == 19 &&
            !chinese.isLeapMonth &&
            (chinese.month == 2 || chinese.month == 6 || chinese.month == 9)) {
          add(
            day,
            'Occasion',
            8,
            30,
            "Kwan Im's sejit",
            'Vegetarian all day. The klenteng was full before nine.',
            tags: [klenteng],
          );
        }
      }
      if (JavaneseDate.supports(day)) {
        final javanese = JavaneseDate.of(day);
        if (javanese.month == JavaneseMonth.sura && javanese.day == 1) {
          // The night before 1 Sura is malam satu Suro.
          add(
            day.addDays(-1),
            'Occasion',
            22,
            30,
            'Malam satu Suro',
            'Bathed the keris after dark: lime, then warangan, then '
                'sandalwood oil. Back in its sheath before midnight.',
            tags: [keris],
          );
        }
      }
      if (HijriDate.supports(day)) {
        final hijri = HijriDate.of(day);
        if (hijri.month == HijriMonth.syawal && hijri.day == 1) {
          add(
            day,
            'Occasion',
            10,
            0,
            'Lebaran',
            'Sungkem to Ma and Pa, then visiting till dark. Too much '
                'opor.',
            tags: [family],
          );
        }
      }
    }

    // The reminders: one for each kind of coming round, tagged as the
    // entries are, and one switched off.
    final madeReminders = <String>[];
    void remind(
      String title,
      String into,
      CivilDate start,
      int hour,
      int minute,
      Repeat repeat, {
      List<String> tags = const [],
      bool enabled = true,
    }) => madeReminders.add(
      reminders
          .save(
            Reminder(
              id: '',
              title: title,
              start: start,
              minuteOfDay: hour * 60 + minute,
              repeat: repeat,
              categoryId: category(into),
              tags: tags,
              enabled: enabled,
            ),
          )
          .id,
    );

    // 15 October 2026 is a Kamis Kliwon.
    final kliwon = CivilDate(2026, 10, 15);
    remind(
      'Kliwon sitting',
      'Observance',
      kliwon,
      4,
      45,
      Repeat.pasaran,
      tags: [sitting],
    );
    remind(
      'Malam Jumat offering',
      'Observance',
      kliwon,
      18,
      0,
      Repeat.weekday,
      tags: [offering],
    );
    remind(
      'Monday fast: sahur',
      'Observance',
      CivilDate(2026, 10, 19),
      3,
      30,
      Repeat.weekday,
      tags: [fasting],
    );
    remind(
      'Full moon card',
      'Divination',
      CivilDate(2026, 10, 26),
      21,
      0,
      Repeat.moon,
      tags: [tarot],
    );
    remind(
      'Water the chillies',
      'Plant log',
      kliwon,
      6,
      30,
      Repeat.daily,
      tags: [chilli],
    );
    remind(
      'Feed the basil',
      'Plant log',
      CivilDate(2026, 10, 18),
      7,
      0,
      Repeat.weekday,
      tags: [basil],
    );
    remind(
      "Kwan Im's sejit",
      'Occasion',
      CivilDate(2026, 10, 28),
      7,
      0,
      Repeat.chineseYear,
      tags: [klenteng],
    );
    remind(
      'Malam satu Suro: the keris',
      'Occasion',
      CivilDate(2026, 6, 16),
      21,
      0,
      Repeat.javaneseYear,
      tags: [keris],
    );
    remind(
      'Ma\'s weton',
      'Occasion',
      CivilDate(2026, 10, 20),
      8,
      0,
      Repeat.weton,
      tags: [family],
    );
    remind(
      'Lebaran visits',
      'Occasion',
      CivilDate(2026, 3, 20),
      9,
      0,
      Repeat.hijriYear,
      tags: [family],
    );
    remind(
      'Old rain-day reminder',
      'Dream',
      kliwon,
      5,
      0,
      Repeat.weekday,
      tags: [rain],
      enabled: false,
    );

    _searchNote(root).writeAsStringSync(
      jsonEncode({
        'entries': written,
        'reminders': madeReminders,
        'tags': madeTags,
      }),
    );
  }

  static void removeSearch(
    JournalStore store,
    ReminderStore reminders,
    Directory root,
    Duration utcOffset,
  ) {
    final note = jsonDecode(
      _searchNote(root).readAsStringSync(),
    ) as Map<String, dynamic>;
    _removeEntries(store, (note['entries'] as List).cast<String>(), utcOffset);
    for (final id in (note['reminders'] as List).cast<String>()) {
      reminders.delete(id);
    }
    // A sample tag goes only if nothing else carries it.
    for (final id in (note['tags'] as List).cast<String>()) {
      if (store.tag(id) != null &&
          store.countTagged(id) == 0 &&
          reminders.countTagged(id) == 0) {
        store.deleteTag(id);
      }
    }
    _searchNote(root).deleteSync();
  }

  static void _removeEntries(
    JournalStore store,
    List<String> ids,
    Duration utcOffset,
  ) {
    for (final id in ids) {
      final date = CivilDate(
        int.parse(id.substring(0, 4)),
        int.parse(id.substring(4, 6)),
        int.parse(id.substring(6, 8)),
      );
      store
          .entriesFor(date, utcOffset: utcOffset)
          .where((e) => e.id == id)
          .toList()
          .forEach(store.delete);
    }
  }

  static void remove(JournalStore store, Directory root, Duration utcOffset) {
    final note =
        jsonDecode(_note(root).readAsStringSync()) as Map<String, dynamic>;
    _removeEntries(store, (note['entries'] as List).cast<String>(), utcOffset);
    // A sample category goes only if nothing else was written in it.
    for (final id in (note['categories'] as List).cast<String>()) {
      if (store.category(id) != null && store.entryCount(id) == 0) {
        store.deleteCategory(id);
      }
    }
    _note(root).deleteSync();
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
